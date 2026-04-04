# Release Evidence Staging

This directory is the bounded staging root for the immutable `v0.2.0` release
artifacts that the public Windows installer scaffold is allowed to consume.

Expected staged files before the public installer build runs:

- `vi-history-suite-0.2.0.vsix`
- `release-manifest.json`
- `release-record.md`
- `coverage.xml`
- `coverage/`

Rules:

- stage only the exact immutable release artifacts retained from private GitLab
- do not substitute preview packages or working-tree outputs
- keep the VSIX SHA-256 aligned with
  [`release-ingestion.json`](../release-ingestion.json)
- keep this directory fail-closed when the public GitHub release asset has not
  yet been published
