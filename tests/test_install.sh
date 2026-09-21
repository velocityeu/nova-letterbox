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
[[ "$FULLSCREEN" == 1 && "$SYSTEM" == 1 && "$AUTOSTART" == 1 && "$OMARCHY" == 0 ]] || fail "flags"
[[ "$PREFIX" == /tmp/nova-prefix ]] || fail "prefix"
[[ "$(resolve_prefix)" == /tmp/nova-prefix ]] || fail "prefix wins"
parse_args --omarchy
[[ "$OMARCHY" == 1 && "$AUTOSTART" == 0 ]] || fail "omarchy flag"
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

# Stdin has no BASH_SOURCE. set -u must not abort before --help.
pipe_help="$(cat ./install.sh | bash -s -- --help 2>&1)" || fail "piped install.sh: ${pipe_help}"
[[ "$pipe_help" == *Usage:* ]] || fail "piped install.sh did not print help"

# install-omarchy.sh may download install.sh after the guard. Either --help
# succeeds, or a later fetch fails. An unbound BASH_SOURCE is the regression.
set +e
omarchy_pipe="$(cat ./install-omarchy.sh | bash -s -- --help 2>&1)"
omarchy_pipe_status=$?
set -e
if [[ "$omarchy_pipe" == *"unbound variable"* ]]; then
	fail "piped install-omarchy.sh: ${omarchy_pipe}"
fi
if [[ "$omarchy_pipe_status" -eq 0 ]]; then
	[[ "$omarchy_pipe" == *Usage:* ]] || fail "piped install-omarchy.sh help missing"
fi

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
payload="$(mktemp)"
printf 'not-really-an-elf\n' >"$payload"
HOME="$home" bash -c '
	set -euo pipefail
	source ./install.sh
	parse_args
	install_payload "$1"
	OMARCHY=0
	write_icon
	write_desktop
	OMARCHY=1
	write_desktop
' bash "$payload"
[[ -f "${home}/.local/share/nova-letterbox/nova-letterbox" ]] || fail "payload missing"
[[ -L "${home}/.local/bin/nova-letterbox" ]] || fail "cli is not a symlink"
[[ "$(readlink "${home}/.local/bin/nova-letterbox")" == "${home}/.local/share/nova-letterbox/nova-letterbox" ]] || fail "symlink target"
desktop="${home}/.local/share/applications/nova-letterbox.desktop"
icon="${home}/.local/share/icons/hicolor/scalable/apps/nova-letterbox.svg"
[[ -f "$desktop" ]] || fail "desktop entry missing"
[[ -f "$icon" ]] || fail "icon missing"
grep -q '^Name=NOVA Letterbox$' "$desktop" || fail "desktop name"
grep -q '^StartupWMClass=NOVA Letterbox$' "$desktop" || fail "wm class"
grep -q '^Icon=nova-letterbox$' "$desktop" || fail "icon key"
grep -q "omarchy-launch-or-focus" "$desktop" || fail "launch-or-focus exec"
grep -q "${home}/.local/bin/nova-letterbox --fullscreen" "$desktop" || fail "desktop exec path"
grep -q '<svg' "$icon" || fail "icon svg"

# Default Hyprland: exec-once in autostart.conf, written once.
HOME="$home" bash -c '
	set -euo pipefail
	source ./install.sh
	parse_args
	install_hypr_autostart "$HOME"
	install_hypr_autostart "$HOME"
'
conf="${home}/.config/hypr/autostart.conf"
grep -q '^exec-once = nova-letterbox$' "$conf" || fail "exec-once"
grep -q 'fullscreen = true' "$conf" || fail "window rule"
[[ "$(grep -c 'nova-letterbox-begin' "$conf")" == 1 ]] || fail "conf autostart duplicated"

# Existing Omarchy-managed conf wins over a lua session file.
mkdir -p "${home}/.config/omarchy" "${home}/.config/hypr"
printf '%s\n' '-- existing' >"${home}/.config/hypr/autostart.lua"
printf '%s\n' '# managed' >"${home}/.config/omarchy/autostart.conf"
HOME="$home" bash -c '
	set -euo pipefail
	source ./install.sh
	parse_args
	install_hypr_autostart "$HOME"
'
grep -q '^exec-once = nova-letterbox$' "${home}/.config/omarchy/autostart.conf" || fail "omarchy conf"
if grep -q 'nova-letterbox-begin' "${home}/.config/hypr/autostart.lua"; then
	fail "lua autostart should stay untouched when omarchy conf exists"
fi

# Current Omarchy lua session: launch line plus looknfeel window rule.
rm -f "${home}/.config/omarchy/autostart.conf"
printf '%s\n' 'require("hypr.autostart")' >"${home}/.config/hypr/hyprland.lua"
HOME="$home" bash -c '
	set -euo pipefail
	source ./install.sh
	parse_args
	install_hypr_autostart "$HOME"
	install_hypr_autostart "$HOME"
'
grep -q 'o.launch_on_start("nova-letterbox")' "${home}/.config/hypr/autostart.lua" || fail "lua launch"
grep -q 'monitor = "HDMI-A-1"' "${home}/.config/hypr/looknfeel.lua" || fail "lua window rule"
[[ "$(grep -c 'nova-letterbox-begin' "${home}/.config/hypr/autostart.lua")" == 1 ]] || fail "lua duplicated"
rm -rf "$home" "$payload"

if GITHUB_REPOSITORY=velocityeu/nova-letterbox GITHUB_SHA=abc GITHUB_REF_TYPE=branch \
	bash ./scripts/publish-release.sh >/dev/null 2>&1; then
	fail "publish should fail without dist binaries"
fi

# Success must exit 0. The old EXIT trap expanded a local after main returned.
kept="$(mktemp)"
printf 'keep\n' >"$kept"
bash -c '
	set -euo pipefail
	source ./install.sh
	begin_install_tmp
	printf x > "$_NOVA_INSTALL_TMP"
	path="$_NOVA_INSTALL_TMP"
	end_install_tmp
	[[ -z "${_NOVA_INSTALL_TMP}" ]] || exit 2
	[[ ! -e "$path" ]] || exit 3
' || fail "successful cleanup exited non-zero"
[[ -f "$kept" ]] || fail "cleanup removed an unrelated file"

early="$(mktemp)"
printf 'gone\n' >"$early"
set +e
bash -c '
	set -euo pipefail
	source ./install.sh
	_NOVA_INSTALL_TMP="$1"
	trap cleanup_install_tmp EXIT
	exit 1
' bash "$early" >/dev/null
early_status=$?
set -e
[[ "$early_status" -eq 1 ]] || fail "early exit status ${early_status}"
[[ ! -e "$early" ]] || fail "early exit left the temp file"
rm -f "$kept"

echo "OK"
