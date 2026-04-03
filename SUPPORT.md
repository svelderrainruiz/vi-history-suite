# Support

## Public Support Surface

This repository is the public issue and release-facing surface for `vi-history-suite`.

Internal implementation work, governed requirements, and private engineering evidence remain on a private GitLab control plane.

## Before Filing An Issue

Please include:
- VS Code version
- operating system
- installed extension version
- whether the workspace was trusted
- whether the target file was an eligible LabVIEW VI
- the command or action you used
- what you expected
- what happened instead

Useful VS Code CLI output:

```bash
code --version
code --list-extensions --show-versions
```

## Good Issue Topics

- extension command behavior
- comparison report generation issues
- dashboard review issues
- documentation problems
- installation and upgrade problems

## Not In Scope For Public Issues

- requests for private engineering artifacts
- requests for private GitLab access
- private repository contents that should not be disclosed publicly

## Future Support Direction

Planned future hardening includes an extension-side support-bundle export so issue reports can include bounded product evidence without requiring private repo access.
