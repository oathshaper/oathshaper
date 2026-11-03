#!/usr/bin/env python3
"""Check design packet structure only; this is not a combat behavior test."""
import argparse
import json
from pathlib import Path
import re
import sys

HEADINGS = (
    "Identity and reference boundary", "Play loop and time",
    "Archetypes, skills and progression", "Equipment, inventory and economy",
    "Abilities, resources and resolution", "Party and companion behavior",
    "Native UX and input", "Worked examples", "LCD mapping and persistence",
    "Acceptance and implementation slice", "Sources and research gaps",
)
CATEGORIES = {"timing", "equipment", "progression", "ability", "party", "ui", "persistence", "failure"}


def verify(directory: Path) -> list[str]:
    errors = []
    for name in ("design.md", "evaluation.md", "scenarios.json"):
        if not (directory / name).is_file():
            errors.append(f"{directory}: missing {name}")
    if errors:
        return errors
    design = (directory / "design.md").read_text()
    for heading in HEADINGS:
        if f"## {heading}\n" not in design:
            errors.append(f"{directory}: missing section {heading}")
    if "research/NOTICE.md" not in design:
        errors.append(f"{directory}: missing research notice")
    for file in (directory / "design.md", directory / "evaluation.md"):
        text = file.read_text()
        if text.count("```") % 2:
            errors.append(f"{file}: unbalanced fenced blocks")
        for link in re.findall(r"\]\(([^)]+)\)", text):
            if "://" not in link and not link.startswith("#"):
                if not (file.parent / link.split("#")[0]).exists():
                    errors.append(f"{file}: unresolved relative link {link}")
    try:
        packet = json.loads((directory / "scenarios.json").read_text())
    except (ValueError, OSError) as error:
        return errors + [f"{directory}: invalid JSON: {error}"]
    if not isinstance(packet, dict):
        return errors + [f"{directory}: scenario packet must be an object"]
    for key, expected in (("schema", "oathshaper.design-scenarios/v1"),
                          ("profile", directory.name), ("status", "proposed_acceptance")):
        if packet.get(key) != expected:
            errors.append(f"{directory}: {key} must equal {expected}")
    cases = packet.get("cases")
    if not isinstance(cases, list):
        return errors + [f"{directory}: cases must be an array"]
    if len(cases) < 8:
        errors.append(f"{directory}: fewer than eight acceptance cases")
    seen, categories = set(), set()
    for index, case in enumerate(cases):
        prefix = f"{directory}: case {index}"
        if not isinstance(case, dict):
            errors.append(prefix + " must be an object")
            continue
        for key in ("id", "category", "given", "failure_probe"):
            if not isinstance(case.get(key), str) or not case[key].strip():
                errors.append(prefix + f" needs nonempty string {key}")
        for key in ("when", "then", "invariants"):
            values = case.get(key)
            if not isinstance(values, list) or not values or any(not isinstance(x, str) or not x.strip() for x in values):
                errors.append(prefix + f" needs nonempty string array {key}")
        ident = case.get("id")
        if isinstance(ident, str):
            if ident in seen:
                errors.append(prefix + f" duplicates ID {ident}")
            seen.add(ident)
        if isinstance(case.get("category"), str):
            categories.add(case["category"])
    if CATEGORIES - categories:
        errors.append(f"{directory}: missing case categories {sorted(CATEGORIES - categories)}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directories", type=Path, nargs="+")
    args = parser.parse_args()
    errors = [error for directory in args.directories for error in verify(directory)]
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"DESIGN_STRUCTURE_OK: {len(args.directories)} packets; no behavioral/runtime claim")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
