#!/usr/bin/env bash
# Offline checks for the installer. Does not download a release.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

bash -n install.sh
bash -n install-omarchy.sh
bash -n scripts/export-linux.sh
bash -n scripts/ci-install-godot.sh
bash -n scripts/publish-release.sh

# shellcheck disable=SC1091
source ./install.sh

[[ "$(normalize_arch x86_64)" == "x86_64" ]] || fail "x86_64"
[[ "$(normalize_arch amd64)" == "x86_64" ]] || fail "amd64"
[[ "$(normalize_arch aarch64)" == "aarch64" ]] || fail "aarch64"
[[ "$(normalize_arch arm64)" == "aarch64" ]] || fail "arm64"
if normalize_arch ppc64 >/dev/null 2>&1; then
	fail "ppc64 should be rejected"
fi

[[ "$(asset_for_arch x86_64)" == "nova-letterbox-linux-x86_64" ]] || fail "asset x86"
[[ "$(asset_for_arch aarch64)" == "nova-letterbox-linux-arm64" ]] || fail "asset arm"
[[ "$(preset_for_arch x86_64)" == "Linux Desktop" ]] || fail "preset x86"
[[ "$(preset_for_arch aarch64)" == "Linux Pi ARM64" ]] || fail "preset arm"

[[ -z "$(normalize_version_tag "")" ]] || fail "empty version"
[[ -z "$(normalize_version_tag latest)" ]] || fail "latest"
[[ "$(normalize_version_tag continuous)" == "continuous" ]] || fail "continuous"
[[ "$(normalize_version_tag v0.1.0)" == "v0.1.0" ]] || fail "v tag"
[[ "$(normalize_version_tag 0.1.0)" == "v0.1.0" ]] || fail "bare tag"

omarchy="$(mktemp)"
arch="$(mktemp)"
printf '%s\n' 'NAME="Omarchy"' 'ID=omarchy' >"$omarchy"
printf '%s\n' 'NAME="Arch Linux"' 'ID=arch' >"$arch"
os_release_is_omarchy "$omarchy" || fail "omarchy os-release"
if os_release_is_omarchy "$arch"; then
	fail "arch should not look like omarchy"
fi
if os_release_is_omarchy /tmp/does-not-exist-nova-os-release; then
	fail "missing os-release"
fi
rm -f "$omarchy" "$arch"

parse_args --fullscreen --system --autostart --prefix /tmp/nova-prefix
[[ "$FULLSCREEN" == 1 && "$SYSTEM" == 1 && "$OMARCHY" == 1 && "$AUTOSTART" == 1 ]] || fail "flags"
[[ "$PREFIX" == /tmp/nova-prefix ]] || fail "prefix"
[[ "$(resolve_prefix)" == /tmp/nova-prefix ]] || fail "prefix wins"
parse_args --system
[[ "$(resolve_prefix)" == /usr/local ]] || fail "system prefix"
PREFIX=""
SYSTEM=0
[[ "$(resolve_prefix)" == "${HOME}/.local" ]] || fail "default prefix"

if bash ./install.sh --not-a-flag >/dev/null 2>&1; then
	fail "unknown flag should fail"
fi
bash ./install.sh --help >/dev/null
bash ./install-omarchy.sh --help >/dev/null

mapfile -t elfs < <(python3 - <<'PY'
import struct, pathlib, tempfile, os
def write(machine, path):
    header = bytearray(64)
    header[0:4] = b"\x7fELF"
    header[4] = 2
    header[5] = 1
    struct.pack_into("<H", header, 18, machine)
    pathlib.Path(path).write_bytes(header)
tmpdir = tempfile.mkdtemp()
x86 = os.path.join(tmpdir, "x86")
arm = os.path.join(tmpdir, "arm")
bad = os.path.join(tmpdir, "bad")
write(62, x86)
write(183, arm)
pathlib.Path(bad).write_text("not elf")
print(x86)
print(arm)
print(bad)
PY
)
verify_elf "${elfs[0]}" x86_64
verify_elf "${elfs[1]}" aarch64
if verify_elf "${elfs[0]}" aarch64 >/dev/null 2>&1; then
	fail "x86 elf accepted as arm"
fi
if verify_elf "${elfs[2]}" x86_64 >/dev/null 2>&1; then
	fail "text accepted as elf"
fi
rm -f "${elfs[@]}"

json="$(mktemp)"
cat >"$json" <<'EOF'
{"assets":[{"id":42,"name":"nova-letterbox-linux-x86_64","browser_download_url":"https://example.invalid/x86"}]}
EOF
fields="$(release_asset_fields "$json" nova-letterbox-linux-x86_64)"
[[ "$(printf '%s\n' "$fields" | head -n 1)" == "42" ]] || fail "asset id"
if release_asset_fields "$json" missing >/dev/null 2>&1; then
	fail "missing asset should fail"
fi
rm -f "$json"

require_linux

home="$(mktemp -d)"
HOME="$home" bash -c '
	source ./install.sh
	AUTOSTART=1
	install_omarchy_extras "$1"
	install_omarchy_extras "$1"
' bash "${home}/bin/nova-letterbox"
desktop="${home}/.local/share/applications/nova-letterbox.desktop"
autostart="${home}/.config/hypr/autostart.lua"
[[ -f "$desktop" ]] || fail "desktop entry missing"
grep -q "Exec=${home}/bin/nova-letterbox --fullscreen" "$desktop" || fail "desktop exec"
count="$(grep -c 'nova-letterbox' "$autostart")"
[[ "$count" == 1 ]] || fail "autostart should be written once, got ${count}"
rm -rf "$home"

if GITHUB_REPOSITORY=velocityeu/nova-letterbox GITHUB_SHA=abc GITHUB_REF_TYPE=branch \
	bash ./scripts/publish-release.sh >/dev/null 2>&1; then
	fail "publish should fail without dist binaries"
fi

echo "OK"
