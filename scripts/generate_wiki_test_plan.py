#!/usr/bin/env python3
"""Generate the file-level evidence blocks, test-plan rows and stub reasons that feed the canonical wiki test pages.

Run it at the repository root after `observations.py evidence` wrote `wiki-evidence.json` (see
`docs/testing/test-plan.md`, "Wiki Canonical Test Pages"). It is deterministic and idempotent for a given repository
and evidence file, and it rewrites only generated text:

- an `Evidence Files` block in every requirement of docs/requirements/srs.md, which the wiki generator reads as the
  artifact section of the test pages. It lists the test files that the requirement's Verification References name,
  that passed in the evidence and, for a requirement without a per-case row, that cite its ID. The generic
  `requirementsDocs.test.ts` and `packageManifest.test.ts` are never evidence for a specific requirement;
- a row of the Critical-Path Verification Evidence table of docs/testing/test-plan.md for each requirement that has
  none by hand: "evidence granularity: file" when a specific file qualifies, otherwise a stub row;
- docs/testing/wiki-stub-reasons.json: the stub requirements with a reason code, the expected page counts and every
  file omitted by the page-margin cap.

Page-margin cap: every test page keeps at least MARGIN bytes below the 16,384-byte page budget. While a test page
is closer than that, the file with the most test cases is omitted from its requirement's block (ties: the file cited
last); each omission is recorded in the JSON file and counted in the block, never dropped silently.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
import tempfile
from collections import Counter
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_wiki_canonical as checker  # noqa: E402

SRS = Path("docs/requirements/srs.md")
PLAN = Path("docs/testing/test-plan.md")
REASONS = Path(checker.REASONS_FILE)
GENERIC = checker.GENERIC_FILES
MARKER = "evidence granularity: file"
STUB_TITLE = "stub, generic files only"
REASON_CODE = "generic-evidence-only"
SECTION = "Evidence Files"
TABLE_HEADING = "## Critical-Path Verification Evidence"
BLOCK = re.compile(r"^### (VHS-REQ-\d+):", re.M)
LABEL = re.compile(r"^- ([A-Za-z ]+):")
TICKS = re.compile(r"`([^`\n]+)`")


def parse_srs(text: str) -> tuple[list[str], dict[str, dict]]:
    lines = text.split("\n")
    requirements: dict[str, dict] = {}
    current = None
    for number, line in enumerate(lines):
        heading = BLOCK.match(line)
        if heading:
            current = requirements.setdefault(heading.group(1), {"lines": [number], "labels": {}})
            continue
        if current is None:
            continue
        label = LABEL.match(line)
        if label:
            current["labels"][label.group(1)] = [number, number]
        elif current["labels"] and line.startswith(" "):
            list(current["labels"].values())[-1][1] = number
    return lines, requirements


def references(lines: list[str], requirement: dict, label: str) -> list[str]:
    span = requirement["labels"].get(label)
    return [] if span is None else [t for line in lines[span[0]:span[1] + 1] for t in TICKS.findall(line)]


def evidence_of(path: str) -> tuple[set[str], dict[str, int]]:
    document = json.loads(Path(path).read_text(encoding="utf-8"))
    cases = Counter(c["file"] for c in document["cases"])
    failing = {c["file"] for c in document["cases"] if c["status"] != "passed"}
    return set(cases) - failing, dict(cases)


def cites(file: str, identifier: str) -> bool:
    return re.search(re.escape(identifier) + r"(?!\d)", Path(file).read_text(encoding="utf-8")) is not None


def plan_rows(text: str) -> tuple[list[str], int, int]:
    lines = text.split("\n")
    start = lines.index(TABLE_HEADING)
    first = next(i for i in range(start, len(lines)) if lines[i].startswith("| --- "))
    last = first
    while last + 1 < len(lines) and lines[last + 1].startswith("|"):
        last += 1
    return lines, first, last


def row_of(identifier: str, files: list[str], impl: list[str], omitted: list[str]) -> str:
    number = identifier.rsplit("-", 1)[1]
    if files:
        note = (f"File-level evidence: the listed test files pass at the commit and cite {identifier}; no per-requirement "
                f"test exists. Evidence cap: {len(omitted)} further cited file(s) are listed in {checker.REASONS_FILE}."
                if omitted else
                f"File-level evidence: the listed test files pass at the commit and cite {identifier}; no per-requirement test exists.")
        return f"| {identifier} | TEST-{number} {MARKER} | {'; '.join(impl)} | {'; '.join(files)} | {note} |"
    return (f"| {identifier} | TEST-{number}: {STUB_TITLE} | {'; '.join(impl)} | none | Stub: only generic files cite "
            f"{identifier} ({REASON_CODE}, see {checker.REASONS_FILE}). |")


def block_lines(files: list[str], omitted: int) -> list[str]:
    if not files:
        return [f"- {SECTION}:", f"  - None: reason code {REASON_CODE}, see {checker.REASONS_FILE}."]
    lines = [f"- {SECTION}:", *[f"  - `{f}`" for f in files]]
    if omitted:
        lines.append(f"  - {omitted} further cited test file(s) are omitted by the page-margin cap, see {checker.REASONS_FILE}.")
    return lines


def render_srs(lines: list[str], requirements: dict, chosen: dict[str, tuple[list[str], int]]) -> str:
    out = list(lines)
    # Edit from the bottom so earlier line numbers stay valid.
    for identifier, entry in sorted(requirements.items(), key=lambda item: -item[1]["lines"][0]):
        labels = entry["labels"]
        if SECTION in labels:
            start, end = labels[SECTION]
            del out[start:end + 1]
        end = labels["Verification References"][1]
        files, omitted = chosen[identifier]
        out[end + 1:end + 1] = block_lines(files, omitted)
    return "\n".join(out)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--evidence", default="wiki-evidence.json")
    options = parser.parse_args()
    passing, cases = evidence_of(options.evidence)
    srs_lines, requirements = parse_srs(SRS.read_text(encoding="utf-8"))
    plan_text = PLAN.read_text(encoding="utf-8")
    plan_lines, first, last = plan_rows(plan_text)
    generated = [i for i in range(first + 1, last + 1) if MARKER in plan_lines[i] or STUB_TITLE in plan_lines[i]]
    by_hand = [plan_lines[i] for i in range(first + 1, last + 1) if i not in generated]
    per_case = sorted({m for row in by_hand for m in re.findall(r"^\| (VHS-REQ-\d+) \|", row)})

    candidates: dict[str, list[str]] = {}
    for identifier in requirements:
        named = [f for f in dict.fromkeys(references(srs_lines, requirements[identifier], "Verification References"))
                 if f in passing and f not in GENERIC]
        candidates[identifier] = named if identifier in per_case else [f for f in named if cites(f, identifier)]
    omitted: dict[str, list[str]] = {i: [] for i in requirements}
    new = sorted(i for i in requirements if i not in per_case)

    def write() -> None:
        chosen = {i: ([f for f in candidates[i] if f not in omitted[i]], len(omitted[i])) for i in requirements}
        SRS.write_text(render_srs(srs_lines, requirements, chosen), encoding="utf-8")
        rows = [row_of(i, chosen[i][0], references(srs_lines, requirements[i], "Implementation References"), omitted[i]) for i in new]
        PLAN.write_text("\n".join(plan_lines[:first + 1] + by_hand + rows + plan_lines[last + 1:]), encoding="utf-8")

    for _ in range(200):
        write()
        with tempfile.TemporaryDirectory() as temp:
            sizes = checker.test_page_sizes(Path(temp) / "wiki", options.evidence)
        tight = sorted(page for page, (_, margin) in sizes.items() if margin < checker.MARGIN)
        if not tight:
            break
        for page in tight:
            identifier = f"VHS-REQ-{page.split('-')[1]}"
            remaining = [f for f in candidates[identifier] if f not in omitted[identifier]]
            if len(remaining) < 2:
                sys.exit(f"FAIL: {page} stays within {checker.MARGIN} bytes of the page budget with a single file")
            drop = max(reversed(remaining), key=lambda f: cases[f])
            omitted[identifier].append(drop)
    else:
        sys.exit("FAIL: the page-margin cap did not settle")

    stubs = [{"requirement": i, "test": f"TEST-{i.rsplit('-', 1)[1]}", "reason": REASON_CODE,
              "genericFilesCited": [f for f in references(srs_lines, requirements[i], "Verification References") if f in GENERIC]}
             for i in new if not candidates[i]]
    file_level = len(new) - len(stubs)
    document = {
        "schema": "vi-history-suite/wiki-stub-reasons@1",
        "reasonCodes": {REASON_CODE: "Only the generic requirementsDocs.test.ts or packageManifest.test.ts cites the requirement; neither is evidence for a specific requirement."},
        "expectedCounts": {"perCaseCanonical": len(per_case), "fileLevelCanonical": file_level, "stub": len(stubs)},
        "stubs": stubs,
        "pageMarginCap": {"minimumMarginBytes": checker.MARGIN,
                          "omittedFiles": {i: sorted(v) for i, v in sorted(omitted.items()) if v}},
    }
    REASONS.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"{len(per_case)} per-case rows kept, {file_level} file-level rows and {len(stubs)} stub rows written; "
          f"{sum(len(v) for v in omitted.values())} files omitted by the page-margin cap on {sum(1 for v in omitted.values() if v)} requirements")
    return 0


if __name__ == "__main__":
    sys.exit(main())
