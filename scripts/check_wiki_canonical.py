#!/usr/bin/env python3
"""Check this repository's wiki, generated with canonical test pages from vitest evidence.

Needs only Python 3.9+ and Git. Run it at the repository root, in a clean checkout, after
`.repo-standards-review/observations.py evidence` wrote `wiki-evidence.json` from `vitest run --reporter=json`
(the `wiki-canonical-evidence` CI job does both). It builds the wiki twice (generate, then `observations.py
stimulus` and `generate`), requires the two builds to be byte-identical, requires at least one canonical page and
no `Pending:` placeholder, and runs `observations.py check --member-commit` on the committed result. A test stays a
stub, with a note printed, when a linked file has a skipped or failing case. Exit 0 when all hold.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
KIT = Path(".repo-standards-review")
STEPS = ["npm ci"]
COMMAND = "npx vitest run {files}"
ARTIFACT_SECTION = "Evidence Files"
REASONS_FILE = "docs/testing/wiki-stub-reasons.json"
GENERIC_FILES = {"tests/unit/requirementsDocs.test.ts", "tests/unit/packageManifest.test.ts"}
BUDGET = 16384
MARGIN = 2048
GRANULARITY = "evidence granularity: file"
ENVIRONMENT = {**os.environ, "PYTHONUTF8": "1", "GIT_CONFIG_NOSYSTEM": "1", "GIT_AUTHOR_NAME": "wiki", "GIT_AUTHOR_EMAIL": "wiki@example.invalid",
               "GIT_COMMITTER_NAME": "wiki", "GIT_COMMITTER_EMAIL": "wiki@example.invalid"}


def run(*command: str) -> subprocess.CompletedProcess[str]:
    done = subprocess.run(command, capture_output=True, text=True, env=ENVIRONMENT, check=False)
    if done.returncode != 0:
        sys.exit(f"FAIL: {' '.join(command[:4])} exited {done.returncode}\n{done.stdout}{done.stderr}")
    return done


def build(wiki: Path, evidence: str) -> dict:
    wiki.mkdir()
    run("git", "-C", str(wiki), "init", "-q", "-b", "main")
    generated = run(sys.executable, str(KIT / "wiki_generate.py"), "--member-root", ".", "--out", str(wiki))
    summary = json.loads(generated.stdout)
    run(sys.executable, str(KIT / "observations.py"), "stimulus", "--wiki", str(wiki), "--evidence", evidence,
        "--member", "vi-history-suite", "--artifact-section", ARTIFACT_SECTION,
        *[x for step in STEPS for x in ("--step", step)], "--command", COMMAND)
    run(sys.executable, str(KIT / "observations.py"), "generate", "--wiki", str(wiki), "--evidence", evidence)
    return summary


def tree(wiki: Path) -> dict[str, bytes]:
    return {p.relative_to(wiki).as_posix(): p.read_bytes() for p in sorted(wiki.rglob("*"))
            if p.is_file() and ".git" not in p.relative_to(wiki).parts}


def page_margin(text: str, identifier: str) -> int:
    """Bytes left below the page budget, or below the registry-text budget when that is closer."""
    sys.path.insert(0, str(KIT))
    import observations
    spans = observations.parse_page(text, identifier, ["Stimulus", "Required observation"])
    fields = {"ID": identifier}
    after = text.split("\n", 1)[0][2 + len(identifier):]
    if after.startswith(": "):
        fields["Title"] = after[2:]
    for heading, (start, end) in zip(["Stimulus", "Required observation"], spans or []):
        fields[heading] = text[start:end]
    registry = json.dumps(fields, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return min(BUDGET - len(text.encode("utf-8")), BUDGET - len(registry))


def margins(files: dict[str, bytes], wiki_tests: str = "tests/") -> dict[str, tuple[int, int]]:
    """Test page -> (bytes, margin); a page that is not a canonical section page keeps its byte margin."""
    found = {}
    for path, data in files.items():
        if path.startswith(wiki_tests) and path.endswith(".md"):
            identifier = path[len(wiki_tests):-3]
            text = data.decode("utf-8")
            found[identifier] = (len(data), page_margin(text, identifier) if "page-kind: stub" not in text else BUDGET - len(data))
    return found


def test_page_sizes(wiki: Path, evidence: str) -> dict[str, tuple[int, int]]:
    build(wiki, evidence)
    return margins(tree(wiki))


def self_test() -> int:
    """Negative control: pages closer than MARGIN to the budget must be reported, pages with MARGIN or more must not."""
    def page(size: int) -> bytes:
        head = "# TEST-001: t\n\n## Stimulus\n\nRun.\n\n## Required observation\n\n"
        return (head + "x" * (size - len(head) - 1) + "\n").encode()
    tight, roomy = page(BUDGET - MARGIN + 1), page(BUDGET - MARGIN - 200)
    assert len(tight) == BUDGET - MARGIN + 1 and len(roomy) == BUDGET - MARGIN - 200
    assert margins({"tests/TEST-001.md": tight})["TEST-001"][1] < MARGIN, "a page 1 byte inside the margin must fail"
    assert margins({"tests/TEST-001.md": roomy})["TEST-001"][1] >= MARGIN, "a page with enough margin must pass"
    escaped = b"# TEST-001: t\n\n## Stimulus\n\nRun.\n\n## Required observation\n\n" + b"x\n" * 6200
    assert margins({"tests/TEST-001.md": escaped})["TEST-001"][1] < MARGIN, "newline escapes in the registry text count"
    print("PASS: the margin check rejects pages within 2048 bytes of the budget")
    return 0


def check_counts(first: Path, summary: dict, files: dict[str, bytes]) -> str:
    reasons = json.loads(Path(REASONS_FILE).read_text(encoding="utf-8"))
    pages = {p[len("tests/"):-3]: d.decode("utf-8") for p, d in files.items() if p.startswith("tests/") and p.endswith(".md")}
    file_level = [i for i, t in pages.items() if GRANULARITY in t.split("\n", 1)[0]]
    stubs = [i for i, t in pages.items() if "page-kind: stub" in t]
    counts = {"perCaseCanonical": summary["canonical_test_pages"] - len(file_level), "fileLevelCanonical": len(file_level), "stub": len(stubs)}
    if counts != reasons["expectedCounts"]:
        sys.exit(f"FAIL: counts {counts} differ from {REASONS_FILE} {reasons['expectedCounts']}")
    listed = sorted(s["test"] for s in reasons["stubs"])
    if sorted(stubs) != listed or any(s["reason"] not in reasons["reasonCodes"] for s in reasons["stubs"]):
        sys.exit(f"FAIL: the stub pages {sorted(stubs)} differ from the reasons in {REASONS_FILE} {listed}")
    leaked = [i for i, t in pages.items() if "page-kind: stub" not in t and any(g in t for g in GENERIC_FILES)]
    if leaked:
        sys.exit(f"FAIL: a generic file counts as evidence on {', '.join(sorted(leaked))}")
    return (f"{counts['perCaseCanonical']} per-case plus {counts['fileLevelCanonical']} file-level canonical, {counts['stub']} stub")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--evidence", default="wiki-evidence.json", help="evidence file named by testPlan.canonical (default: wiki-evidence.json)")
    parser.add_argument("--self-test", action="store_true", help="run the negative control of the margin check and exit")
    options = parser.parse_args()
    if options.self_test:
        return self_test()
    with tempfile.TemporaryDirectory() as temp:
        first, second = Path(temp) / "first", Path(temp) / "second"
        summary = build(first, options.evidence)
        build(second, options.evidence)
        if tree(first) != tree(second):
            sys.exit("FAIL: two builds of the wiki differ")
        pending = [path for path, data in tree(first).items() if b"Pending:" in data]
        if pending:
            sys.exit(f"FAIL: pages still hold a placeholder: {', '.join(pending)}")
        if summary["problem_count"] or not summary["canonical_test_pages"]:
            sys.exit(f"FAIL: {json.dumps({k: summary[k] for k in ('canonical_test_pages', 'stub_test_pages', 'warnings', 'problem_count')})}")
        files = tree(first)
        counted = check_counts(first, summary, files)
        sizes = margins(files)
        tight = sorted(page for page, (_, margin) in sizes.items() if margin < MARGIN)
        if tight:
            sys.exit(f"FAIL: test pages within {MARGIN} bytes of the {BUDGET}-byte page budget: "
                     + ", ".join(f"{p} ({sizes[p][0]} bytes, margin {sizes[p][1]})" for p in tight))
        largest = max(sizes, key=lambda p: sizes[p][0])
        others = {p: len(d) for p, d in files.items() if p.endswith(".md") and not p.startswith("tests/")}
        widest = max(others, key=others.get)
        print(f"NOTE: largest test page {largest}: {sizes[largest][0]} bytes, margin {sizes[largest][1]}; "
              f"largest other page {widest}: {others[widest]} bytes, margin {BUDGET - others[widest]} (kit split target)")
        for warning in summary["warnings"]:
            print(f"NOTE: {warning}")
        run("git", "-C", str(first), "add", "-A")
        run("git", "-C", str(first), "commit", "-q", "--no-verify", "-m", "wiki")
        commit = run("git", "rev-parse", "HEAD").stdout.strip()
        checked = run(sys.executable, str(KIT / "observations.py"), "check", "--wiki", str(first), "--member-commit", commit,
                      "--evidence", options.evidence)
        print(checked.stdout.strip())
    print(f"PASS: {counted} test pages; two builds are byte-identical")
    return 0


if __name__ == "__main__":
    sys.exit(main())
