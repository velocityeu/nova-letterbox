#!/usr/bin/env bash
# Download Godot 4.3.stable and the official Linux export templates.
# Used by GitHub Actions. Safe to re-run.
set -euo pipefail

VERSION="${GODOT_VERSION:-4.3-stable}"
TEMPLATE_DIR="${GODOT_TEMPLATE_DIR:-${HOME}/.local/share/godot/export_templates/4.3.stable}"
BIN_DIR="${HOME}/.local/bin"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

mkdir -p "$TEMPLATE_DIR" "$BIN_DIR"

echo "Downloading Godot ${VERSION} editor"
curl -fsSL -o "$workdir/editor.zip" \
	"https://github.com/godotengine/godot/releases/download/${VERSION}/Godot_v4.3-stable_linux.x86_64.zip"
unzip -q "$workdir/editor.zip" -d "$workdir/editor"
editor="$(find "$workdir/editor" -type f -name 'Godot_v4.3-stable_linux.x86_64' | head -n 1)"
[[ -n "$editor" ]] || { echo "error: editor binary missing from zip" >&2; exit 1; }
install -m 0755 "$editor" "${BIN_DIR}/godot"

echo "Downloading Godot ${VERSION} export templates"
curl -fsSL -o "$workdir/templates.tpz" \
	"https://github.com/godotengine/godot/releases/download/${VERSION}/Godot_v4.3-stable_export_templates.tpz"
unzip -q "$workdir/templates.tpz" -d "$workdir/templates"
[[ -d "$workdir/templates/templates" ]] || { echo "error: templates/ missing from tpz" >&2; exit 1; }
cp -a "$workdir/templates/templates/." "$TEMPLATE_DIR/"
[[ -f "${TEMPLATE_DIR}/linux_release.x86_64" ]] || { echo "error: linux_release.x86_64 missing" >&2; exit 1; }
[[ -f "${TEMPLATE_DIR}/linux_release.arm64" ]] || { echo "error: linux_release.arm64 missing" >&2; exit 1; }

echo "Godot ready: ${BIN_DIR}/godot"
echo "Templates: ${TEMPLATE_DIR}"
