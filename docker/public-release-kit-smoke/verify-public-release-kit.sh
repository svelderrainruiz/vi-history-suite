#!/usr/bin/env bash
set -euo pipefail

release_tag="${VIHS_RELEASE_TAG:-v0.2.0}"
github_repository="${VIHS_GITHUB_REPOSITORY:-svelderrainruiz/vi-history-suite}"
base_url="https://github.com/${github_repository}/releases/download/${release_tag}"
output_root="${VIHS_OUTPUT_ROOT:-/workspace/output}"
asset_root="${output_root}/asset-tree"
downloads_root="${output_root}/downloads"
workspace_root="${output_root}/workspace"
report_path="${output_root}/public-release-kit-smoke.json"

mkdir -p "${asset_root}/setup/windows" \
  "${asset_root}/setup/linux" \
  "${asset_root}/acceptance/windows11" \
  "${downloads_root}" \
  "${workspace_root}"

download() {
  local url="$1"
  local destination="$2"
  curl -fsSL "$url" -o "$destination"
}

download "${base_url}/public-setup-manifest.json" "${asset_root}/public-setup-manifest.json"
download "${base_url}/SHA256SUMS-public-setup.txt" "${asset_root}/SHA256SUMS-public-setup.txt"
download "${base_url}/vi-history-suite-0.2.0.vsix" "${downloads_root}/vi-history-suite-0.2.0.vsix"
download "${base_url}/vi-history-suite-0.2.0.vsix.sha256" "${downloads_root}/vi-history-suite-0.2.0.vsix.sha256"

python3 - <<'PY' "${asset_root}/public-setup-manifest.json" "${asset_root}" "${downloads_root}" "${base_url}"
import json
import pathlib
import sys
import urllib.request

manifest_path = pathlib.Path(sys.argv[1])
asset_root = pathlib.Path(sys.argv[2])
downloads_root = pathlib.Path(sys.argv[3])
base_url = sys.argv[4]
manifest = json.loads(manifest_path.read_text())

assets = [
    ("setup/windows/Setup-VIHistorySuite.ps1", manifest["assets"]["windowsSetupScript"]["downloadUrl"]),
    ("setup/linux/setup-vi-history-suite.sh", manifest["assets"]["linuxSetupScript"]["downloadUrl"]),
    ("acceptance/windows11/Invoke-Windows11Acceptance.ps1", manifest["acceptance"]["windows11"]["automationScript"]["downloadUrl"]),
    ("acceptance/windows11/Invoke-Windows11HumanGate.ps1", manifest["acceptance"]["windows11"]["humanGateScript"]["downloadUrl"]),
    ("acceptance/windows11/manual-right-click-checklist.md", manifest["acceptance"]["windows11"]["manualChecklist"]["downloadUrl"]),
    ("acceptance/windows11/acceptance-record.template.json", manifest["acceptance"]["windows11"]["acceptanceRecordTemplate"]["downloadUrl"]),
    ("labview-icon-editor.manifest.json", manifest["fixture"]["manifest"]["downloadUrl"]),
    ("labview-icon-editor-develop-e8945de7.bundle", manifest["fixture"]["bundle"]["downloadUrl"]),
    ("labview-icon-editor-develop-e8945de7.json", manifest["fixture"]["metadata"]["downloadUrl"]),
]

for relative_path, url in assets:
    destination = asset_root / relative_path
    destination.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(url) as response:
        destination.write_bytes(response.read())
PY

( cd "${asset_root}" && sha256sum -c SHA256SUMS-public-setup.txt )
( cd "${downloads_root}" && sha256sum -c vi-history-suite-0.2.0.vsix.sha256 )

fixture_bundle="${asset_root}/labview-icon-editor-develop-e8945de7.bundle"
fixture_workspace="${workspace_root}/labview-icon-editor"
git clone "${fixture_bundle}" "${fixture_workspace}" >/dev/null 2>&1

fixture_commit="$(python3 - <<'PY' "${asset_root}/public-setup-manifest.json"
import json, pathlib, sys
manifest = json.loads(pathlib.Path(sys.argv[1]).read_text())
print(manifest["fixture"]["commitSha"])
PY
)"

selection_relative_path="$(python3 - <<'PY' "${asset_root}/public-setup-manifest.json"
import json, pathlib, sys
manifest = json.loads(pathlib.Path(sys.argv[1]).read_text())
print(manifest["fixture"]["selectionPath"])
PY
)"

git -C "${fixture_workspace}" checkout "${fixture_commit}" >/dev/null 2>&1
resolved_commit="$(git -C "${fixture_workspace}" rev-parse HEAD)"

if [[ "${resolved_commit}" != "${fixture_commit}" ]]; then
  echo "Fixture checkout mismatch: expected ${fixture_commit} but found ${resolved_commit}" >&2
  exit 1
fi

selection_path="${fixture_workspace}/${selection_relative_path}"
if [[ ! -f "${selection_path}" ]]; then
  echo "Canonical VI was not found at ${selection_path}" >&2
  exit 1
fi

python3 - <<'PY' "${report_path}" "${release_tag}" "${asset_root}/public-setup-manifest.json" "${fixture_workspace}" "${selection_path}" "${fixture_commit}"
import json
import pathlib
import sys
from datetime import datetime, timezone

report = {
    "releaseTag": sys.argv[2],
    "manifestPath": sys.argv[3],
    "fixtureWorkspacePath": sys.argv[4],
    "selectionPath": sys.argv[5],
    "fixtureCommitSha": sys.argv[6],
    "status": "pass",
    "verifiedAtUtc": datetime.now(timezone.utc).isoformat(),
}

pathlib.Path(sys.argv[1]).write_text(json.dumps(report, indent=2))
PY

echo "Public release-kit container smoke passed. Report: ${report_path}"
