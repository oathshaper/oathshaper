#!/usr/bin/env python3
"""Run the chapter's independent continuity checks and retain inspectable evidence."""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
PREFIX = "CONTINUITY_JSON:"
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")


def engine_diagnostics(output):
    """Retain known Godot 4.3 headless/exit diagnostics; reject other errors."""
    lines = ANSI.sub("", output).splitlines()
    known, unexpected = [], []
    for index, line in enumerate(lines):
        if "ERROR:" not in line:
            continue
        message = line.strip()
        location = lines[index + 1].strip() if index + 1 < len(lines) else ""
        dummy_mesh = message == 'ERROR: Parameter "m" is null.' and location == "at: mesh_get_surface_count (servers/rendering/dummy/storage/mesh_storage.h:120)"
        exit_resource = re.fullmatch(r"ERROR: \d+ resources still in use at exit \(run with --verbose for details\)\.", message) and location == "at: clear (core/io/resource.cpp:604)"
        (known if dummy_mesh or exit_resource else unexpected).append({"message": message, "location": location})
    return {"known_count": len(known), "unexpected_count": len(unexpected),
            "known": list({(e["message"], e["location"]): e for e in known}.values()), "unexpected": unexpected}


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def in_repo(value):
    path = (ROOT / value).resolve()
    if not path.is_relative_to(ROOT) or not path.is_file():
        raise ValueError("Missing or outside-project input: " + value)
    return path


def read_manifest(path):
    data = json.loads(path.read_text())
    if data.get("schema") != 1 or not data.get("id") or not data.get("suites"):
        raise ValueError("Manifest needs schema 1, id and suites")
    for key in ["story", "rules", "journeys", "voices"]:
        in_repo(data[key])
    ids = {"matrix", "replay", "dialogue-script", "host-build", "import", "setup"}
    for suite in data["suites"]:
        if not re.fullmatch(r"[a-z0-9-]+", suite["id"]) or suite["id"] in ids:
            raise ValueError("Suite ids must be unique lowercase names")
        ids.add(suite["id"])
        if not suite["script"].startswith("res://tests/"):
            raise ValueError("Suite script must be in res://tests/")
        in_repo("godot/" + suite["script"][6:])
        if not all(isinstance(arg, str) for arg in suite.get("args", [])):
            raise ValueError("Suite arguments must be strings")
    return data


def classify(kind, code, output):
    """Treat missing evidence, timeouts and script errors as non-passes."""
    output = ANSI.sub("", output)
    if code is None:
        return "incomplete", None
    if "SCRIPT ERROR:" in output or "Parse Error:" in output or engine_diagnostics(output)["unexpected_count"]:
        return "failed", None
    if kind == "command":
        return ("passed" if code == 0 else "failed"), None
    try:
        if kind == "engine":
            receipts = [json.loads(line[len(PREFIX):]) for line in output.splitlines() if line.startswith(PREFIX)]
            if len(receipts) != 1:
                return ("failed" if code != 0 else "incomplete"), None
            receipt = receipts[0]
            if not isinstance(receipt, dict) or receipt.get("schema") != 1 or receipt.get("checks", 0) <= 0:
                return "incomplete", receipt
            observations = receipt.get("observations")
            if not isinstance(observations, list) or not observations or any(not isinstance(item, dict) for item in observations):
                return "incomplete", receipt
            if sum(item["samples"] for item in observations) != receipt["checks"] or sum(item["failures"] for item in observations) != receipt["failures"]:
                return "incomplete", receipt
            ok = receipt.get("status") == "passed" and receipt.get("failures") == 0
        else:
            receipt = json.loads(output)
            if not isinstance(receipt, dict):
                return "incomplete", receipt
            if kind in ["matrix", "dialogue-script"]:
                if not receipt.get("complete_within_scope"):
                    return "incomplete", receipt
                ok = not any(f["certainty"] == "contract_violation" for f in receipt["findings"])
            else:
                if receipt.get("status") == "incomplete":
                    return "incomplete", receipt
                ok = receipt.get("status") == "passed"
        return ("passed" if code == 0 and ok else "failed"), receipt
    except (ValueError, KeyError, TypeError):
        return "incomplete", None


def run_stage(out, identity, command, kind="command", timeout=180):
    print("Checking " + identity + "…", flush=True)
    began = time.monotonic()
    try:
        result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=timeout)
        code, stdout, stderr = result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired as error:
        code = None
        stdout = (error.stdout or b"").decode(errors="replace") if isinstance(error.stdout, bytes) else error.stdout or ""
        stderr = "Timed out; scope is incomplete."
    except OSError as error:
        code, stdout, stderr = None, "", str(error)
    (out / (identity + ".txt")).write_text(stdout + "\n" + stderr)
    status, receipt = classify(kind, code, stdout)
    diagnostics = engine_diagnostics(stdout + "\n" + stderr)
    if diagnostics["unexpected_count"] or "Parse Error:" in ANSI.sub("", stderr):
        status = "failed"
    stage = {"id": identity, "status": status, "exit_code": code, "seconds": round(time.monotonic() - began, 2),
             "command": command, "log": identity + ".txt", "engine_error_lines": diagnostics["known_count"] + diagnostics["unexpected_count"], "diagnostics": diagnostics}
    if receipt is not None:
        write_json(out / (identity + ".json"), receipt)
        stage["evidence"] = identity + ".json"
        stage["review_findings"] = len(receipt.get("findings", []))
    print("  " + status, flush=True)
    return stage


def summarize(out, report):
    statuses = [stage["status"] for stage in report["stages"]]
    report["status"] = "failed" if "failed" in statuses else "incomplete" if "incomplete" in statuses else "passed"
    write_json(out / "report.json", report)
    lines = ["# Continuity run", "", f"Status: **{report['status']}** within **{report['requested_scope']}**.", "",
             "| Check | Result | Known / unexpected diagnostics | Evidence |", "|---|---|---|---|"]
    for stage in report["stages"]:
        evidence = stage.get("evidence", stage.get("log", "report.json"))
        diagnostics = stage.get("diagnostics", {})
        counts = f"{diagnostics.get('known_count', 0)} / {diagnostics.get('unexpected_count', 0)}"
        lines.append(f"| {stage['id']} | {stage['status']} | {counts} | [Open]({evidence}) |")
    for stage in report["stages"]:
        if stage.get("review_findings", 0):
            lines += ["", f"**{stage['id']}: {stage['review_findings']} findings to review.** A passed scope does not mean the writing was approved."]
    lines += ["", "## Coverage limits", ""] + ["- " + note for note in report["limits"]]
    (out / "README.md").write_text("\n".join(lines) + "\n")
    return report["status"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", default="godot/content/lantern_quay.checks.json")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--logic-only", action="store_true", help="Run narrative checks only; engine checks are explicitly outside scope")
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN"))
    args = parser.parse_args()
    now = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    out = args.output or ROOT / ".artifacts/continuity" / now
    out = out.resolve()
    try:
        out.mkdir(parents=True, exist_ok=False)
    except OSError as error:
        parser.error(f"Choose a new writable output directory: {error}")
    report = {"schema": 1, "created_utc": now, "requested_scope": "narrative only" if args.logic_only else "narrative and current Godot fixtures",
              "stages": [], "limits": [
                  "No LLM, Humanizer or Obelus is required. Authored rules still need human review.",
                  "Menu-state matrix is not reachability proof. Narrative journeys assume host entry access.",
                  "Command fixtures earn combat outcomes but position the player at some approaches; this is not a navigation bot.",
                  "Camera checks are geometric samples. Headless checks do not judge appearance, acting or physical controls.",
                  "No exhaustive scene/branch coverage or labor-saving percentage is claimed.",
                  "Known Godot 4.3 dummy-renderer null-mesh and exit resource diagnostics are counted and retained; these checks do not establish clean resource teardown. Unexpected errors fail the run."]}
    try:
        manifest = read_manifest(in_repo(args.manifest))
        report["chapter"] = manifest["id"]
        report["git_head"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        report["working_tree"] = subprocess.check_output(["git", "status", "--short"], cwd=ROOT, text=True).splitlines()
        sources = set(ROOT.glob("crates/**/*.rs")) | set(ROOT.glob("godot/scripts/**/*.gd")) | set(ROOT.glob("godot/tests/**/*.gd")) | set(ROOT.glob("godot/content/**/*.json")) | set(ROOT.glob("godot/scenes/**/*.tscn")) | set(ROOT.glob("crates/*/Cargo.toml"))
        sources.update([ROOT / "godot/project.godot", ROOT / "Cargo.lock", ROOT / "Cargo.toml", ROOT / "scripts/build-host.sh", in_repo(args.manifest), Path(__file__).resolve()])
        report["source_sha256"] = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(sources)}
        for binary, kind, files in [("check_continuity", "matrix", [manifest["story"], manifest["rules"]]),
                                    ("check_dialogue_script", "dialogue-script", [manifest["story"], manifest["voices"]]),
                                    ("replay_continuity", "replay", [manifest["story"], manifest["rules"], manifest["journeys"]])]:
            report["stages"].append(run_stage(out, kind, ["cargo", "run", "--quiet", "--locked", "-p", "oathshaper-core", "--bin", binary, "--", *files], kind))
        if args.logic_only:
            report["limits"].insert(0, "Engine stages were not requested or executed; this result is narrative-only.")
        else:
            godot = args.godot or shutil.which("godot")
            if not godot and Path("/Applications/Godot.app/Contents/MacOS/Godot").is_file():
                godot = "/Applications/Godot.app/Contents/MacOS/Godot"
            if not godot:
                raise ValueError("Godot not found. Set GODOT_BIN or pass --godot; narrative evidence was retained.")
            version = subprocess.check_output([godot, "--version"], text=True, timeout=15).strip()
            report["godot"] = version
            if not version.startswith("4.3.stable."):
                raise ValueError("This project requires Godot 4.3.stable; found " + version)
            for identity, command in [("host-build", ["sh", "scripts/build-host.sh"]), ("import", [godot, "--headless", "--path", "godot", "--import"])]:
                stage = run_stage(out, identity, command)
                report["stages"].append(stage)
                if stage["status"] != "passed":
                    raise ValueError("Engine preparation failed; gameplay checks were not run.")
            for suite in manifest["suites"]:
                report["stages"].append(run_stage(out, suite["id"], [godot, "--headless", "--path", "godot", "--script", suite["script"], "--", *suite.get("args", [])], "engine", 100))
    except (ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
        report["stages"].append({"id": "setup", "status": "incomplete", "error": str(error)})
    status = summarize(out, report)
    print(f"Continuity {status}: {out / 'README.md'}")
    return {"passed": 0, "failed": 1, "incomplete": 2}[status]


if __name__ == "__main__":
    sys.exit(main())
