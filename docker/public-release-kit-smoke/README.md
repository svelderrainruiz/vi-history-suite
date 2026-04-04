# Public Release-Kit Container Smoke

This directory defines the first slice of the future reproducible container
automation lane for the public `vi-history-suite` facade.

Current scope:

- build a Linux container image
- download the live public release-kit assets from GitHub Releases
- verify the public setup checksums and VSIX checksum
- materialize the pinned `ni/labview-icon-editor` fixture from the published Git
  bundle
- verify the pinned fixture commit and canonical VI path
- write a machine-readable smoke report

This lane does not replace the host-machine click UX proof. It is a
reproducible automation surface for release-kit contract verification.

Local example:

```bash
docker build docker/public-release-kit-smoke -t vi-history-suite-public-release-kit-smoke:local
docker run --rm -e VIHS_RELEASE_TAG=v0.2.0 -v "$PWD/.cache/public-release-kit-smoke:/workspace/output" vi-history-suite-public-release-kit-smoke:local
```

The current smoke report is written to `/workspace/output/public-release-kit-smoke.json`
inside the container.
