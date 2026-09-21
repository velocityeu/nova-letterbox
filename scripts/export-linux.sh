#!/usr/bin/env bash
# Export NOVA Letterbox Linux release binaries.
# Requires Godot 4.3.stable on PATH as `godot`, plus the official 4.3.stable
# Linux export templates (linux_release.x86_64 and linux_release.arm64).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

if ! command -v godot >/dev/null 2>&1; then
	echo "error: godot is not on PATH (need Godot 4.3.stable and Linux export templates)" >&2
	exit 1
fi

stage_release() {
	local src="$1"
	local name="$2"
	mkdir -p "$root/dist"
	cp -f "$src" "$root/dist/$name"
	chmod +x "$root/dist/$name"
	echo "release asset: dist/${name}"
}

export_one() {
	local name="$1"
	local out="$2"
	local asset="$3"
	mkdir -p "$(dirname "$out")"
	echo "export-release: ${name} -> ${out}"
	godot --headless --path "$root" --export-release "$name" "$out"
	if [[ ! -f "$out" ]]; then
		echo "error: export did not write ${out}" >&2
		exit 1
	fi
	# Release presets embed the PCK. A sibling .pck means the binary is not the artifact.
	local pck="${out%.*}.pck"
	if [[ -f "$pck" ]]; then
		echo "error: ${pck} exists; release export must embed the PCK" >&2
		exit 1
	fi
	stage_release "$out" "$asset"
}

if [[ $# -eq 0 ]]; then
	set -- "Linux Desktop" "Linux Pi ARM64"
fi

for name in "$@"; do
	case "$name" in
		"Linux Desktop")
			export_one "$name" "$root/build/linux-x86_64/nova-letterbox.x86_64" "nova-letterbox-linux-x86_64"
			;;
		"Linux Pi ARM64")
			export_one "$name" "$root/build/linux-arm64/nova-letterbox.arm64" "nova-letterbox-linux-arm64"
			;;
		*)
			echo "error: unknown preset: ${name}" >&2
			echo "presets: \"Linux Desktop\" \"Linux Pi ARM64\"" >&2
			exit 1
			;;
	esac
done
