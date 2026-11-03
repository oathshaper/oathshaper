#!/usr/bin/env python3
"""Supervise one ACE-Step audition. Refuse low headroom; never kill other apps."""
import argparse
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import time
import uuid

import psutil

GIB = 1024 ** 3


def snapshot():
    return {"available_bytes": psutil.virtual_memory().available,
            "swap_used_bytes": psutil.swap_memory().used,
            "system_disk_free_bytes": shutil.disk_usage(Path.home()).free,
            "pressure": int(subprocess.check_output(["sysctl", "-n", "kern.memorystatus_vm_pressure_level"], text=True))}


def preflight_reasons(state, quantized=False):
    reasons = []
    available_floor = 4 if quantized else 14
    disk_floor = 30 if quantized else 20
    if state["available_bytes"] < available_floor * GIB:
        reasons.append(f"Less than {available_floor} GiB available memory")
    if state["system_disk_free_bytes"] < disk_floor * GIB:
        reasons.append(f"Less than {disk_floor} GiB free on the system disk for swap headroom")
    swap_ceiling = 12 if quantized else 8
    if state["swap_used_bytes"] > swap_ceiling * GIB:
        reasons.append(f"Existing swap usage exceeds {swap_ceiling} GiB")
    if state["pressure"] not in ((1, 2) if quantized else (1,)):
        reasons.append("macOS memory pressure exceeds this trial's policy")
    return reasons


def stop_trial(child):
    """Stop the dedicated session only, including any workers it started."""
    try:
        os.killpg(child.pid, signal.SIGTERM)
        child.wait(timeout=3)
    except subprocess.TimeoutExpired:
        os.killpg(child.pid, signal.SIGKILL)
        child.wait()
    except ProcessLookupError:
        child.wait()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--data", type=Path, required=True)
    parser.add_argument("--seconds", type=float, default=5)
    parser.add_argument("--preflight-only", action="store_true")
    parser.add_argument("--quantized-mlx", action="store_true")
    parser.add_argument("--checkpoint-dir", type=Path)
    args = parser.parse_args()
    args.repo = args.repo.resolve()
    args.data = args.data.resolve()
    if args.checkpoint_dir:
        args.checkpoint_dir = args.checkpoint_dir.resolve()
    if not 1 <= args.seconds <= 30:
        parser.error("The guarded audition supports 1–30 seconds")
    if args.quantized_mlx and args.checkpoint_dir is None:
        parser.error("--quantized-mlx requires the reviewed --checkpoint-dir")
    output = args.data / "outputs" / (time.strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:6])
    output.mkdir(parents=True, exist_ok=True)
    limits = {"process_rss_gib": 12 if args.quantized_mlx else 10,
              "available_floor_gib": 1 if args.quantized_mlx else 3,
              "swap_growth_gib": 4 if args.quantized_mlx else 1,
              "swap_total_gib": 12 if args.quantized_mlx else 9,
              "disk_reserve_gib": 25 if args.quantized_mlx else 15,
              # The 8-bit retry permits compression/swap under WARNING while
              # bounding RSS, available RAM, swap growth and disk reserve.
              # CRITICAL still stops immediately. Full precision stays strict.
              "warning_grace_seconds": None if args.quantized_mlx else 0,
              "timeout_seconds": 600, "sample_interval_seconds": .5}
    before = snapshot()
    report = {"started": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "preflight": before,
              "reasons": preflight_reasons(before, args.quantized_mlx), "status": "preflight", "peak_rss_bytes": 0,
              "quantized_mlx": args.quantized_mlx, "limits": limits, "output": str(output)}
    report_path = output / "guard.json"

    def save():
        report_path.write_text(json.dumps(report, indent=2) + "\n")

    if report["reasons"] or args.preflight_only:
        report["status"] = "refused" if report["reasons"] else "preflight_passed"
        save()
        print(json.dumps(report, indent=2))
        return 2 if report["reasons"] else 0
    env = dict(os.environ, OMP_NUM_THREADS="4", VECLIB_MAXIMUM_THREADS="4",
               TOKENIZERS_PARALLELISM="false", PYTHONUNBUFFERED="1", OATH_AUDIO_GUARDED="1", LC_ALL="C")
    command = [sys.executable, "-u", str(Path(__file__).resolve().with_name("ace_step_trial.py")),
               "--repo", str(args.repo), "--data", str(args.data), "--seconds", str(args.seconds), "--output", str(output)]
    if args.quantized_mlx: command.append("--quantized-mlx")
    if args.checkpoint_dir: command.extend(["--checkpoint-dir", str(args.checkpoint_dir)])
    report["status"] = "running"
    report["command"] = command
    save()
    print(f"Trial logs: {output}", flush=True)
    with (output / "trial.log").open("w") as log, (output / "resources.jsonl").open("w") as samples:
        child = subprocess.Popen(command, cwd=args.data.resolve(), env=env, stdout=log,
                                 stderr=subprocess.STDOUT, start_new_session=True)
        process = psutil.Process(child.pid)
        start = time.monotonic()
        warning_since = None
        try:
            while child.poll() is None:
                state = snapshot()
                try:
                    rss = process.memory_info().rss + sum(p.memory_info().rss for p in process.children(recursive=True))
                except psutil.NoSuchProcess:
                    # macOS may drop process accounting just before waitpid
                    # reports completion; a descendant may also have exited.
                    try:
                        child.wait(timeout=1)
                        break
                    except subprocess.TimeoutExpired:
                        continue
                elapsed = time.monotonic() - start
                report["peak_rss_bytes"] = max(report["peak_rss_bytes"], rss)
                samples.write(json.dumps(dict(state, rss_bytes=rss, elapsed_seconds=elapsed)) + "\n")
                samples.flush()
                reasons = []
                if rss > limits["process_rss_gib"] * GIB: reasons.append("Trial process exceeded RSS limit")
                if state["available_bytes"] < limits["available_floor_gib"] * GIB: reasons.append("Available memory fell below reserve")
                if state["swap_used_bytes"] - before["swap_used_bytes"] > limits["swap_growth_gib"] * GIB: reasons.append("Swap growth exceeded limit")
                if state["swap_used_bytes"] > limits["swap_total_gib"] * GIB: reasons.append("Total swap exceeded limit")
                if state["pressure"] == 2:
                    if warning_since is None: warning_since = elapsed
                    grace = limits["warning_grace_seconds"]
                    if grace is not None and elapsed - warning_since >= grace: reasons.append("Sustained memory pressure warning")
                elif state["pressure"] != 1:
                    reasons.append("Critical or unknown system memory pressure")
                else:
                    warning_since = None
                if state["system_disk_free_bytes"] < limits["disk_reserve_gib"] * GIB: reasons.append("System disk reserve depleted")
                if elapsed > limits["timeout_seconds"]: reasons.append("Trial exceeded ten minutes")
                if reasons:
                    report.update(status="stopped", reasons=reasons)
                    save()
                    stop_trial(child)
                    break
                time.sleep(.5)
        except Exception as exc:
            report.update(status="monitor_error", reasons=[f"{type(exc).__name__}: {exc}"])
            raise
        finally:
            if child.poll() is None:
                stop_trial(child)
            report["exit_code"] = child.returncode
            report["elapsed_seconds"] = time.monotonic() - start
            report["final"] = snapshot()
            if report["status"] == "running": report["status"] = "completed" if child.returncode == 0 else "failed"
            save()
    print(json.dumps(report, indent=2))
    return 0 if report["status"] == "completed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
