# ADR-0036: Verify Fork Wiki Submissions As Data

- Status: Accepted
- Date: 2026-11-20

> This ADR is the design record for requirement VHS-REQ-720 under system
> requirement VHS-SYS-REQ-011 (GitHub-First Source).

## Context

Forks publish their own wiki and may send evidence upstream (issue #31). Fork
content is untrusted: running it, or checking it out beside upstream
privileges, would let a fork act as upstream.

## Decision

A submission is an issue whose body is one `rsr/wiki-submission@1` JSON
document. An upstream-owned verifier (`scripts/wiki_submission.py`) treats it as
data. The gate job, the only job that reads the repository Actions secret
`SUBMISSION_ALLOWLIST` (comma-separated `login` or `login:numeric-id` entries,
so partner names are neither in the tree nor in public logs), requires the fork
owner to be listed and the issue author to be that owner or a public member of
the owning organisation. Every authorization failure is the same
`not-authorized` outcome, so nobody can enumerate partners; an unset, empty or
unparsable list rejects everything. The verifier then fetches the evidence
files as bytes through the API at the pinned fork commit, recomputes their
sha256, and compares test ids, results and platform with this repository's own
test files and the canonical evidence rules (`testPlan.canonical` in
`.wiki-generator.json`, and the kit's `evidence_problem`). The result is
`attested` or `not-attested`, a reason from a fixed vocabulary, and the
verifying upstream commit. The verify job has `contents: read` and no secrets;
a separate report job with `issues: write` takes only the enum outputs. No
`pull_request_target`. A `pull_request` path and the accept step are follow-ups.

## Consequences

Attested means only that the evidence matched upstream's definitions at that
commit. The operator decides partners by setting the secret. API rate limits
can turn a submission into `fetch-failed`, which is re-run by editing the
issue.
