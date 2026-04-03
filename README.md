# VI History Suite

Public support and release surface for the `vi-history-suite` Visual Studio Code extension.

This repository is intended for:
- public issue intake
- public install and support guidance
- public release notes and VSIX distribution links
- public installer and Windows acceptance scaffolding

This repository is not the private engineering source of truth. Internal source, governed requirements, design gates, and retained engineering evidence stay on the private GitLab control plane.

## Current Status

`vi-history-suite` is under active product and release hardening.

Public SemVer releases for extension users are planned for this repository, but a public release has not been published here yet.

## Planned User Flows

- Install a released `.vsix` from GitHub Releases or the VS Code Marketplace.
- Open a trusted Git repository in VS Code.
- Right-click an eligible LabVIEW VI and use `VI History`.
- Generate or open retained comparison reports.
- Open the review dashboard for multi-commit VI review.
- Open bundled documentation from inside the extension.

## Documentation

- [Install](INSTALL.md)
- [Support](SUPPORT.md)
- [Windows Installer Build Scaffold](docker/windows-installer-builder/README.md)
- [NSIS Installer Scaffold](installer/nsis/README.md)
- [Windows 11 Acceptance Scaffold](acceptance/windows11/README.md)

## Public Support Scope

Use this repository for:
- bugs in the installed extension experience
- product feedback
- documentation feedback
- release-facing requests

Do not use this repository to request private engineering artifacts, internal gate evidence, or private GitLab access.

## Public Installer Direction

This facade repo is the intended public surface for:
- Windows installer artifacts built from immutable released VSIX packages
- release-facing documentation
- installed-user acceptance guidance

Trust boundary:
- private GitLab release remains the engineering source of truth for the exact released VSIX
- this public repo is the consumer-facing distribution and support facade
- Windows Docker is the installer build surface
- a fresh Windows 11 VM is the installed-user proof surface
