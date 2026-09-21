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

# Wizard stays off for a pipe, --yes, and NOVA_NONINTERACTIVE=1.
# should_prompt takes an explicit tty bit so this does not depend on the runner.
if should_prompt 0; then
	fail "a non-tty stdin should not prompt"
fi
YES=1
if should_prompt 1; then
	fail "--yes should not prompt"
fi
YES=0
NOVA_NONINTERACTIVE=1
if should_prompt 1; then
	fail "NOVA_NONINTERACTIVE=1 should not prompt"
fi
unset NOVA_NONINTERACTIVE
should_prompt 1 || fail "a tty without --yes should prompt"
if bash -c 'source ./install.sh; parse_args; interactive_mode' </dev/null; then
	fail "redirected stdin should not be interactive"
fi
if bash -c 'source ./install.sh; parse_args --yes; interactive_mode'; then
	fail "--yes should not be interactive"
fi

parse_args --yes --fullscreen
[[ "$YES" == 1 && "$FULLSCREEN" == 1 && "$AUTOSTART" == 0 && "$OMARCHY" == 0 ]] || fail "--yes flags"
parse_args --yes --autostart --omarchy
[[ "$YES" == 1 && "$AUTOSTART" == 1 && "$OMARCHY" == 1 ]] || fail "--yes --autostart"
if should_prompt 1; then
	fail "--yes still set after parse_args"
fi
parse_args
[[ "$YES" == 0 && "$AUTOSTART" == 0 ]] || fail "parse_args resets --yes"
help_text="$(bash ./install.sh --help 2>&1)"
[[ "$help_text" == *"--yes"* ]] || fail "help missing --yes"
[[ "$help_text" == *"NOVA_NONINTERACTIVE"* ]] || fail "help missing NOVA_NONINTERACTIVE"

[[ "$(package_for ping apt)" == "iputils-ping" ]] || fail "apt ping package"
[[ "$(package_for ping pacman)" == "iputils" ]] || fail "pacman ping package"
[[ "$(package_for iwgetid apt)" == "wireless-tools" ]] || fail "apt iwgetid package"
[[ "$(package_for iwgetid pacman)" == "wireless_tools" ]] || fail "pacman iwgetid package"
[[ "$(package_for nmcli apt)" == "network-manager" ]] || fail "apt nmcli package"
[[ "$(package_for nmcli pacman)" == "networkmanager" ]] || fail "pacman nmcli package"
[[ "$(package_for python3 apt)" == "python3" ]] || fail "apt python package"
[[ "$(package_for python3 pacman)" == "python" ]] || fail "pacman python package"
if package_for not-a-command apt >/dev/null 2>&1; then
	fail "unknown command should not have a package"
fi

present=$'python3\ncurl\nping'
got="$(collect_packages apt recommended "$present" 0)"
[[ "$got" == $'iw\nwireless-tools\nethtool' ]] || fail "ping present still offered: ${got}"
[[ "$(collect_packages apt recommended $'python3\ncurl' 0)" == $'iputils-ping\niw\nwireless-tools\nethtool' ]] || fail "apt recommended"
[[ "$(collect_packages pacman recommended "" 0)" == $'iputils\niw\nwireless_tools\nethtool' ]] || fail "pacman recommended"
[[ "$(collect_packages apt optional "" 0)" == "network-manager" ]] || fail "apt optional"
[[ "$(collect_packages pacman optional "" 0)" == "networkmanager" ]] || fail "pacman optional"
[[ "$(collect_packages apt required $'python3' 0)" == "curl" ]] || fail "curl required without gh"
[[ -z "$(collect_packages apt required $'python3' 1)" ]] || fail "curl skipped when gh can download"
[[ "$(collect_packages pacman required "" 0)" == $'python\ncurl' ]] || fail "pacman required"

[[ "$(package_manager_for_distro omarchy)" == "pacman" ]] || fail "omarchy pm"
[[ "$(package_manager_for_distro arch)" == "pacman" ]] || fail "arch pm"
[[ "$(package_manager_for_distro pi)" == "apt" ]] || fail "pi pm"
[[ "$(package_manager_for_distro debian)" == "apt" ]] || fail "debian pm"
[[ "$(distro_label pi)" == "Raspberry Pi OS" ]] || fail "pi label"
[[ "$(distro_label omarchy)" == "Omarchy" ]] || fail "omarchy label"

osrel="$(mktemp)"
model="$(mktemp)"
printf '%s\n' 'NAME="Omarchy"' 'ID=arch' >"$osrel"
[[ "$(detect_distro "$osrel" "")" == "omarchy" ]] || fail "detect omarchy"
printf '%s\n' 'ID=debian' 'NAME="Debian GNU/Linux"' >"$osrel"
printf 'Raspberry Pi 5 Model B\0' >"$model"
[[ "$(detect_distro "$osrel" "$model")" == "pi" ]] || fail "detect pi from model"
[[ "$(detect_distro "$osrel" "")" == "debian" ]] || fail "debian is not pi without a model"
printf '%s\n' 'ID=ubuntu' 'ID_LIKE=debian' >"$osrel"
[[ "$(detect_distro "$osrel" "")" == "debian" ]] || fail "ubuntu family"
printf '%s\n' 'ID=raspbian' >"$osrel"
[[ "$(detect_distro "$osrel" "")" == "pi" ]] || fail "raspbian id"
printf '%s\n' 'ID=arch' 'NAME="Arch Linux"' >"$osrel"
[[ "$(detect_distro "$osrel" "")" == "arch" ]] || fail "arch id"
printf '%s\n' 'ID=fedora' >"$osrel"
[[ "$(detect_distro "$osrel" "")" == "linux" ]] || fail "fedora is generic linux"
[[ "$(detect_distro /tmp/does-not-exist-nova-os-release "")" == "linux" ]] || fail "missing os-release distro"
rm -f "$osrel" "$model"

path_has_dir "/home/u/.local/bin" "/usr/bin:/home/u/.local/bin:/bin" || fail "path has dir"
path_has_dir "/home/u/.local/bin/" "/usr/bin:/home/u/.local/bin" || fail "path trailing slash"
if path_has_dir "/home/u/.local/bin" "/usr/bin:/home/u/.local/bin-extra"; then
	fail "path prefix must not match"
fi
if path_has_dir "/home/u/.local/bin" "/usr/bin"; then
	fail "path missing dir"
fi
[[ "$(shell_rc_file /h /bin/bash)" == "/h/.bashrc" ]] || fail "bash rc"
[[ "$(shell_rc_file /h /usr/bin/zsh)" == "/h/.zshrc" ]] || fail "zsh rc"
[[ "$(shell_rc_file /h /bin/sh)" == "/h/.profile" ]] || fail "sh rc"
[[ "$(shell_rc_file /h "")" == "/h/.profile" ]] || fail "empty shell rc"
[[ "$(path_export_line /home/u/.local/bin)" == 'export PATH="/home/u/.local/bin:$PATH"' ]] || fail "export line"

rc="$(mktemp)"
ensure_path_line "$rc" "/home/u/.local/bin" >/dev/null
grep -F 'export PATH="/home/u/.local/bin:$PATH"' "$rc" >/dev/null || fail "rc export"
# The dollar must stay literal so a later shell expands PATH, not this installer.
grep -F '$PATH' "$rc" >/dev/null || fail "rc ate PATH"
ensure_path_line "$rc" "/home/u/.local/bin" >/dev/null
[[ "$(grep -c 'nova-letterbox-path-begin' "$rc")" == "1" ]] || fail "path block duplicated"
rm -f "$rc"

wiz_home="$(mktemp -d)"
[[ "$(choose_autostart_kind "$wiz_home" debian 0 "" "")" == "xdg" ]] || fail "generic autostart"
[[ "$(choose_autostart_kind "$wiz_home" pi 0 "" "")" == "labwc" ]] || fail "pi defaults to labwc"
[[ "$(choose_autostart_kind "$wiz_home" debian 1 "" "")" == "hypr" ]] || fail "omarchy flag is hypr"
[[ "$(choose_autostart_kind "$wiz_home" omarchy 0 "" "")" == "hypr" ]] || fail "omarchy distro is hypr"
[[ "$(choose_autostart_kind "$wiz_home" debian 0 "labwc:wlroots" "")" == "labwc" ]] || fail "desktop labwc"
[[ "$(choose_autostart_kind "$wiz_home" debian 0 "" "labwc")" == "labwc" ]] || fail "labwc hint"
mkdir -p "${wiz_home}/.config"
printf '%s\n' '[autostart]' 'foo = 1' >"${wiz_home}/.config/wayfire.ini"
[[ "$(choose_autostart_kind "$wiz_home" pi 0 "" "")" == "wayfire" ]] || fail "wayfire.ini wins on pi"
[[ "$(choose_autostart_kind "$wiz_home" pi 0 "labwc:wlroots" "")" == "labwc" ]] || fail "live labwc beats leftover wayfire.ini"
mkdir -p "${wiz_home}/.config/hypr"
printf '%s\n' 'exec-once = something' >"${wiz_home}/.config/hypr/hyprland.conf"
[[ "$(choose_autostart_kind "$wiz_home" debian 0 "" "")" == "hypr" ]] || fail "hyprland.conf"

install_labwc_autostart "$wiz_home" "/home/u/.local/bin/nova-letterbox"
install_labwc_autostart "$wiz_home" "/home/u/.local/bin/nova-letterbox"
labwc_file="${wiz_home}/.config/labwc/autostart"
grep -F '/home/u/.local/bin/nova-letterbox --fullscreen &' "$labwc_file" >/dev/null || fail "labwc line"
[[ "$(grep -c 'nova-letterbox-begin' "$labwc_file")" == "1" ]] || fail "labwc duplicated"

install_wayfire_autostart "$wiz_home" "/home/u/.local/bin/nova-letterbox"
install_wayfire_autostart "$wiz_home" "/home/u/.local/bin/nova-letterbox"
wayfire_file="${wiz_home}/.config/wayfire.ini"
grep -F 'nova_letterbox = /home/u/.local/bin/nova-letterbox --fullscreen' "$wayfire_file" >/dev/null || fail "wayfire line"
[[ "$(grep -c '^nova_letterbox' "$wayfire_file")" == "1" ]] || fail "wayfire duplicated"
grep -q '^foo = 1$' "$wayfire_file" || fail "wayfire kept existing key"

rm -f "$wayfire_file"
install_wayfire_autostart "$wiz_home" "/opt/nova-letterbox"
grep -F 'nova_letterbox = /opt/nova-letterbox --fullscreen' "$wayfire_file" >/dev/null || fail "new wayfire file"

HOME="$wiz_home" bash -c '
	set -euo pipefail
	source ./install.sh
	parse_args
	install_xdg_autostart "$HOME" "$HOME/.local/bin/nova-letterbox"
	OMARCHY=1
	install_session_autostart "$HOME" debian "" ""
'
xdg="${wiz_home}/.config/autostart/nova-letterbox.desktop"
[[ -f "$xdg" ]] || fail "xdg autostart missing"
grep -F "Exec=${wiz_home}/.local/bin/nova-letterbox --fullscreen" "$xdg" >/dev/null || fail "xdg exec"
grep -q '^Name=NOVA Letterbox$' "$xdg" || fail "xdg name"
grep -q '^exec-once = nova-letterbox$' "${wiz_home}/.config/hypr/autostart.conf" || fail "session autostart hypr"
rm -rf "$wiz_home"

keys_home="$(mktemp -d)"
keys_out="$(HOME="$keys_home" bash -c '
	set -euo pipefail
	source ./install.sh
	parse_args
	print_next_steps
')"
[[ "$keys_out" == *"1 Simple"* && "$keys_out" == *"2 Complete"* && "$keys_out" == *"Tab toggle"* ]] || fail "done view keys"
[[ "$keys_out" == *"Esc or Q quit"* ]] || fail "done quit key"
[[ "$keys_out" == *"F11 fullscreen"* ]] || fail "done fullscreen key"
rm -rf "$keys_home"

echo "OK"
