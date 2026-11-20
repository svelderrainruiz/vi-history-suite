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
ARTIFACT_SECTION = "Verification References"
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


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--evidence", default="wiki-evidence.json", help="evidence file named by testPlan.canonical (default: wiki-evidence.json)")
    options = parser.parse_args()
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
        for warning in summary["warnings"]:
            print(f"NOTE: {warning}")
        run("git", "-C", str(first), "add", "-A")
        run("git", "-C", str(first), "commit", "-q", "--no-verify", "-m", "wiki")
        commit = run("git", "rev-parse", "HEAD").stdout.strip()
        checked = run(sys.executable, str(KIT / "observations.py"), "check", "--wiki", str(first), "--member-commit", commit,
                      "--evidence", options.evidence)
        print(checked.stdout.strip())
    print(f"PASS: {summary['canonical_test_pages']} canonical, {summary['stub_test_pages']} stub test pages; two builds are byte-identical")
    return 0


if __name__ == "__main__":
    sys.exit(main())
