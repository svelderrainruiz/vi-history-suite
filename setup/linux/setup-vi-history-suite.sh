#!/usr/bin/env bash
set -euo pipefail

release_tag="v0.2.0"
manifest_path=""
manifest_url=""
work_root="${XDG_STATE_HOME:-$HOME/.local/state}/vi-history-suite/setup/linux"
install_root="${XDG_DATA_HOME:-$HOME/.local/share}/vi-history-suite"
open_workspace="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest-path)
      manifest_path="$2"
      shift 2
      ;;
    --manifest-url)
      manifest_url="$2"
      shift 2
      ;;
    --release-tag)
      release_tag="$2"
      shift 2
      ;;
    --work-root)
      work_root="$2"
      shift 2
      ;;
    --install-root)
      install_root="$2"
      shift 2
      ;;
    --open-workspace)
      open_workspace="1"
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

for command_name in curl git code python3; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command '$command_name' was not found." >&2
    exit 1
  fi
done

downloads_root="$work_root/downloads"
logs_root="$work_root/logs"
contracts_root="$install_root/contracts"
payload_root="$install_root/payload"
fixtures_root="$install_root/fixtures"
workspace_root="$install_root/fixtures-workspace"
mkdir -p "$downloads_root" "$logs_root" "$contracts_root" "$payload_root" "$fixtures_root" "$workspace_root"

if [[ -z "$manifest_path" ]]; then
  if [[ -z "$manifest_url" ]]; then
    manifest_url="https://github.com/svelderrainruiz/vi-history-suite/releases/download/${release_tag}/public-setup-manifest.json"
  fi
  manifest_path="$downloads_root/public-setup-manifest.json"
  curl -fsSL "$manifest_url" -o "$manifest_path"
fi

cp "$manifest_path" "$contracts_root/public-setup-manifest.json"

eval "$(python3 <<'PY' "$manifest_path"
import json, shlex, sys
with open(sys.argv[1], 'r', encoding='utf-8') as handle:
    manifest = json.load(handle)
def emit(name, value):
    print(f"{name}={shlex.quote(value)}")
emit("release_id", manifest["release"]["id"])
emit("release_version", manifest["release"]["version"])
emit("extension_identifier", manifest["release"]["extensionIdentifier"])
emit("vsix_url", manifest["assets"]["vsix"]["downloadUrl"])
emit("vsix_sha", manifest["assets"]["vsix"]["sha256"])
emit("vsix_file", manifest["assets"]["vsix"]["fileName"])
emit("bundle_url", manifest["fixture"]["bundle"]["downloadUrl"])
emit("bundle_sha", manifest["fixture"]["bundle"]["sha256"])
emit("bundle_file", manifest["fixture"]["bundle"]["fileName"])
emit("repo_name", manifest["fixture"]["repositoryName"])
emit("repo_url", manifest["fixture"]["repositoryUrl"])
emit("commit_sha", manifest["fixture"]["commitSha"])
emit("selection_path", manifest["fixture"]["selectionPath"])
PY
)"

vsix_path="$payload_root/$vsix_file"
bundle_path="$fixtures_root/$bundle_file"

curl -fsSL "$vsix_url" -o "$vsix_path"
curl -fsSL "$bundle_url" -o "$bundle_path"

echo "$vsix_sha  $vsix_path" | sha256sum --check --status
echo "$bundle_sha  $bundle_path" | sha256sum --check --status

code --version > "$logs_root/code-version.txt" 2>&1
git --version > "$logs_root/git-version.txt" 2>&1
code --install-extension "$vsix_path" --force > "$logs_root/extensions.txt" 2>&1
code --list-extensions --show-versions >> "$logs_root/extensions.txt" 2>&1

expected_token="${extension_identifier}@${release_version}"
if ! grep -Fq "$expected_token" "$logs_root/extensions.txt"; then
  echo "Expected installed extension token '$expected_token' was not found in VS Code CLI output." >&2
  exit 1
fi

workspace_path="$workspace_root/$repo_name"
rm -rf "$workspace_path"
git clone "$bundle_path" "$workspace_path" > "$logs_root/fixture-workspace.txt" 2>&1
git -C "$workspace_path" checkout --detach "$commit_sha" >> "$logs_root/fixture-workspace.txt" 2>&1

resolved_head="$(git -C "$workspace_path" rev-parse HEAD)"
if [[ "$resolved_head" != "$commit_sha" ]]; then
  echo "Materialized fixture workspace resolved HEAD $resolved_head but expected $commit_sha." >&2
  exit 1
fi

selection_abs="$workspace_path/$selection_path"
if [[ ! -f "$selection_abs" ]]; then
  echo "Pinned fixture selection was not found at $selection_abs." >&2
  exit 1
fi

workspace_exit=0
selection_exit=0
if [[ "$open_workspace" == "1" ]]; then
  code --new-window "$workspace_path" > "$logs_root/workspace-launch.txt" 2>&1 || workspace_exit=$?
  code --goto "$selection_abs" > "$logs_root/selection-launch.txt" 2>&1 || selection_exit=$?
fi

python3 <<'PY' "$work_root/setup-record.json" "$release_id" "$release_tag" "$release_version" "$extension_identifier" "$manifest_path" "$install_root" "$work_root" "$repo_name" "$repo_url" "$commit_sha" "$workspace_path" "$selection_abs" "$expected_token" "$workspace_exit" "$selection_exit"
import json, sys
(
    record_path,
    release_id,
    release_tag,
    release_version,
    extension_identifier,
    manifest_path,
    install_root,
    work_root,
    repo_name,
    repo_url,
    commit_sha,
    workspace_path,
    selection_abs,
    expected_token,
    workspace_exit,
    selection_exit,
) = sys.argv[1:]
record = {
    "setupManifestId": release_id,
    "executionEnvironment": {
        "target": "linux",
        "workRoot": work_root,
        "installRoot": install_root,
        "manifestPath": manifest_path,
    },
    "release": {
        "tag": release_tag,
        "version": release_version,
        "extensionIdentifier": extension_identifier,
    },
    "fixture": {
        "repositoryName": repo_name,
        "repositoryUrl": repo_url,
        "commitSha": commit_sha,
        "workspacePath": workspace_path,
        "selectionPath": selection_abs,
    },
    "verification": {
        "installedExtensionToken": expected_token,
        "workspaceLaunchExitCode": int(workspace_exit),
        "selectionLaunchExitCode": int(selection_exit),
    },
}
with open(record_path, 'w', encoding='ascii') as handle:
    json.dump(record, handle, indent=2)
PY

echo "Linux setup completed. Record: $work_root/setup-record.json"
