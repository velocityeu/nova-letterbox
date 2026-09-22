#!/usr/bin/env bash
# Offline checks for uninstall.sh. Uses a temporary HOME. Does not download.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

bash -n uninstall.sh
bash -n install.sh
bash -n install-omarchy.sh

# shellcheck disable=SC1091
source ./uninstall.sh

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

parse_args --yes --user
[[ "$YES" == 1 && "$USER_ONLY" == 1 && "$SYSTEM" == 0 && -z "$PREFIX" ]] || fail "--yes --user"
parse_args --system
[[ "$SYSTEM" == 1 && "$USER_ONLY" == 0 && "$YES" == 0 ]] || fail "parse resets --yes"
parse_args --prefix /opt/nova-letterbox
[[ "$PREFIX" == /opt/nova-letterbox ]] || fail "prefix"
if bash -c 'source ./uninstall.sh; parse_args --system --user' >/dev/null 2>&1; then
	fail "combined --system --user should fail"
fi
if bash -c 'source ./uninstall.sh; parse_args --prefix /tmp' >/dev/null 2>&1; then
	fail "prefix /tmp should be refused"
fi
if bash -c 'source ./uninstall.sh; parse_args --prefix relative' >/dev/null 2>&1; then
	fail "relative prefix should be refused"
fi

help_text="$(HOME=/tmp bash ./uninstall.sh --help 2>&1)"
[[ "$help_text" == *Usage:* ]] || fail "help missing usage"
[[ "$help_text" == *"--yes"* ]] || fail "help missing --yes"
[[ "$help_text" == *"--system"* ]] || fail "help missing --system"
[[ "$help_text" == *"raw.githubusercontent.com/velocityeu/nova-letterbox/main/uninstall.sh"* ]] || fail "help missing public uninstall URL"
if [[ "$help_text" == *"private"* ]]; then
	fail "uninstall help still says private"
fi

# --help must not delete a payload.
help_home="$(mktemp -d)"
mkdir -p "${help_home}/.local/share/nova-letterbox"
echo keep >"${help_home}/.local/share/nova-letterbox/nova-letterbox"
HOME="$help_home" bash ./uninstall.sh --help >/dev/null
[[ -f "${help_home}/.local/share/nova-letterbox/nova-letterbox" ]] || fail "--help removed a binary"
rm -rf "$help_home"

pipe_help="$(HOME=/tmp bash -c 'cat ./uninstall.sh | bash -s -- --help' 2>&1)" || fail "piped uninstall help: ${pipe_help}"
[[ "$pipe_help" == *Usage:* ]] || fail "piped uninstall did not print help"
if [[ "$pipe_help" == *"unbound variable"* ]]; then
	fail "piped uninstall.sh unbound variable"
fi

omarchy_help="$(bash ./install-omarchy.sh --uninstall --help 2>&1)" || fail "omarchy uninstall help failed: ${omarchy_help}"
[[ "$omarchy_help" == *Usage:* && "$omarchy_help" == *"uninstall.sh"* ]] || fail "omarchy --uninstall did not show uninstall help"

install_help="$(bash ./install.sh --help 2>&1)"
[[ "$install_help" == *"uninstall.sh"* ]] || fail "install help should point at uninstall.sh"

# A pipe of install-omarchy.sh --help must still not trip set -u.
set +e
omarchy_pipe="$(cat ./install-omarchy.sh | bash -s -- --help 2>&1)"
omarchy_pipe_status=$?
set -e
if [[ "$omarchy_pipe" == *"unbound variable"* ]]; then
	fail "piped install-omarchy.sh: ${omarchy_pipe}"
fi
if [[ "$omarchy_pipe_status" -eq 0 ]]; then
	[[ "$omarchy_pipe" == *Usage:* ]] || fail "piped install-omarchy help missing"
fi

# Filter: keep unrelated lines, drop installer blocks.
filter_home="$(mktemp -d)"
cat >"${filter_home}/autostart.conf" <<'EOF'
exec-once = waybar

# nova-letterbox-begin
exec-once = nova-letterbox
windowrule {
    name = nova-letterbox
    match:class = ^(NOVA Letterbox)$
    fullscreen = true
    monitor = HDMI-A-1
}
# nova-letterbox-end

windowrule {
    name = waybar
    match:class = waybar
}
exec-once = nova-letterbox
exec-once = mako
EOF
filtered="$(filter_config hypr-conf "" "${filter_home}/autostart.conf")"
[[ "$filtered" == *"exec-once = waybar"* ]] || fail "waybar removed"
[[ "$filtered" == *"name = waybar"* ]] || fail "waybar windowrule removed"
[[ "$filtered" == *"exec-once = mako"* ]] || fail "mako removed"
if [[ "$filtered" == *"nova-letterbox"* || "$filtered" == *"NOVA Letterbox"* ]]; then
	fail "hypr filter left nova lines: ${filtered}"
fi

cat >"${filter_home}/open.conf" <<'EOF'
exec-once = waybar
# nova-letterbox-begin
exec-once = nova-letterbox
EOF
open_filtered="$(filter_config hypr-conf "" "${filter_home}/open.conf")"
[[ "$open_filtered" == *'nova-letterbox-begin'* ]] || fail "unclosed block should stay"
[[ "$open_filtered" == *'exec-once = waybar'* ]] || fail "unclosed block ate earlier lines"

rm -rf "$filter_home"

run_uninstall() {
	local home="$1"
	shift
	HOME="$home" XDG_DATA_HOME="${home}/.local/share" bash ./uninstall.sh "$@"
}

# Full user fixture. Unrelated lines and an unmarked shared PATH export stay.
home="$(mktemp -d)"
bin="${home}/.local/bin"
share="${home}/.local/share"
mkdir -p "${share}/nova-letterbox" "${bin}" \
	"${share}/applications" \
	"${share}/icons/hicolor/scalable/apps" \
	"${home}/.config/hypr" \
	"${home}/.config/omarchy" \
	"${home}/.config/labwc" \
	"${home}/.config/autostart" \
	"${home}/.config/systemd/user/graphical-session.target.wants" \
	"${share}/godot/app_userdata/NOVA Letterbox/logs" \
	"${share}/godot/app_userdata/NOVA Letterbox/shader_cache" \
	"${share}/godot/app_userdata/Other Project"
printf 'binary\n' >"${share}/nova-letterbox/nova-letterbox"
ln -s "${share}/nova-letterbox/nova-letterbox" "${bin}/nova-letterbox"
cat >"${share}/applications/nova-letterbox.desktop" <<'EOF'
[Desktop Entry]
Name=NOVA Letterbox
Exec=nova-letterbox --fullscreen
EOF
cat >"${share}/applications/other.desktop" <<'EOF'
[Desktop Entry]
Name=Other
EOF
printf '<svg></svg>\n' >"${share}/icons/hicolor/scalable/apps/nova-letterbox.svg"
printf '<svg></svg>\n' >"${share}/icons/hicolor/scalable/apps/other.svg"
cat >"${home}/.config/autostart/nova-letterbox.desktop" <<EOF
[Desktop Entry]
Name=NOVA Letterbox
Exec=${bin}/nova-letterbox --fullscreen
EOF
cat >"${home}/.config/autostart/other.desktop" <<'EOF'
[Desktop Entry]
Name=Other Autostart
EOF
cat >"${home}/.config/hypr/autostart.conf" <<'EOF'
exec-once = waybar

# nova-letterbox-begin
exec-once = nova-letterbox
windowrule {
    name = nova-letterbox
    match:class = ^(NOVA Letterbox)$
    fullscreen = true
    monitor = HDMI-A-1
}
# nova-letterbox-end
exec-once = mako
EOF
cat >"${home}/.config/hypr/autostart.lua" <<'EOF'
-- keep lua
-- nova-letterbox-begin
o.launch_on_start("nova-letterbox")
-- nova-letterbox-end
o.launch_on_start("waybar")
EOF
cat >"${home}/.config/hypr/looknfeel.lua" <<'EOF'
-- keep look
-- nova-letterbox-begin
o.window({ class = "^NOVA Letterbox$" }, { fullscreen = true, monitor = "HDMI-A-1" })
-- nova-letterbox-end
EOF
cat >"${home}/.config/omarchy/autostart.conf" <<'EOF'
# managed
# nova-letterbox-begin
exec-once = nova-letterbox
# nova-letterbox-end
exec-once = elephant
EOF
cat >"${home}/.config/labwc/autostart" <<EOF
swayidle
# nova-letterbox-begin
# packaging/pi/labwc-autostart (full path, so PATH is not required)
${bin}/nova-letterbox --fullscreen &
# nova-letterbox-end
pcmanfm-pi &
EOF
cat >"${home}/.config/wayfire.ini" <<EOF
[autostart]
foo = 1
nova_letterbox = ${bin}/nova-letterbox --fullscreen

[idle]
dpms_timeout = -1
EOF
cat >"${home}/.bashrc" <<EOF
export EDITOR=vi

# nova-letterbox-path-begin
export PATH="${bin}:\$PATH"
# nova-letterbox-path-end

alias ll='ls'
export PATH="${bin}:\$PATH"
export PATH="/opt/nova-letterbox/bin:\$PATH"
export PATH="\$HOME/bin:\$PATH"
EOF
cat >"${home}/.config/systemd/user/nova-letterbox.service" <<EOF
[Service]
ExecStart=%h/.local/bin/nova-letterbox --fullscreen
EOF
ln -s "${home}/.config/systemd/user/nova-letterbox.service" \
	"${home}/.config/systemd/user/graphical-session.target.wants/nova-letterbox.service"
printf 'other\n' >"${home}/.config/systemd/user/other.service"
printf 'log\n' >"${share}/godot/app_userdata/NOVA Letterbox/logs/godot.log"
printf 'cache\n' >"${share}/godot/app_userdata/NOVA Letterbox/shader_cache/entry"
printf 'keep\n' >"${share}/godot/app_userdata/Other Project/keep.txt"

sudo_log="$(mktemp)"
sudo_bin="$(mktemp -d)"
cat >"${sudo_bin}/sudo" <<EOF
#!/bin/sh
echo "\$*" >>"${sudo_log}"
exit 1
EOF
chmod +x "${sudo_bin}/sudo"

set +e
out="$(PATH="${sudo_bin}:${PATH}" run_uninstall "$home" --yes 2>"${home}/err")"
status=$?
set -e
[[ "$status" -eq 0 ]] || fail "user uninstall status ${status}: ${out} $(cat "${home}/err")"
if [[ -s "$sudo_log" ]]; then
	fail "user uninstall called sudo: $(cat "$sudo_log")"
fi
[[ ! -e "${share}/nova-letterbox" ]] || fail "app dir remains"
[[ ! -e "${bin}/nova-letterbox" && ! -L "${bin}/nova-letterbox" ]] || fail "cli link remains"
[[ ! -e "${share}/applications/nova-letterbox.desktop" ]] || fail "desktop entry remains"
[[ -f "${share}/applications/other.desktop" ]] || fail "other desktop removed"
[[ ! -e "${share}/icons/hicolor/scalable/apps/nova-letterbox.svg" ]] || fail "icon remains"
[[ -f "${share}/icons/hicolor/scalable/apps/other.svg" ]] || fail "other icon removed"
[[ ! -e "${home}/.config/autostart/nova-letterbox.desktop" ]] || fail "xdg autostart remains"
[[ -f "${home}/.config/autostart/other.desktop" ]] || fail "other autostart removed"
grep -q 'exec-once = waybar' "${home}/.config/hypr/autostart.conf" || fail "waybar missing"
grep -q 'exec-once = mako' "${home}/.config/hypr/autostart.conf" || fail "mako missing"
if grep -q 'nova-letterbox' "${home}/.config/hypr/autostart.conf"; then
	fail "hypr autostart still names nova-letterbox"
fi
grep -q 'keep lua' "${home}/.config/hypr/autostart.lua" || fail "lua keep line missing"
grep -q 'o.launch_on_start("waybar")' "${home}/.config/hypr/autostart.lua" || fail "waybar lua missing"
if grep -q 'nova-letterbox' "${home}/.config/hypr/autostart.lua"; then
	fail "lua launch remains"
fi
grep -q 'keep look' "${home}/.config/hypr/looknfeel.lua" || fail "looknfeel keep missing"
if grep -q 'NOVA Letterbox' "${home}/.config/hypr/looknfeel.lua"; then
	fail "looknfeel rule remains"
fi
grep -q 'exec-once = elephant' "${home}/.config/omarchy/autostart.conf" || fail "omarchy other line missing"
if grep -q 'nova-letterbox' "${home}/.config/omarchy/autostart.conf"; then
	fail "omarchy block remains"
fi
grep -q 'swayidle' "${home}/.config/labwc/autostart" || fail "swayidle removed"
grep -q 'pcmanfm-pi &' "${home}/.config/labwc/autostart" || fail "labwc other line removed"
if grep -q 'nova-letterbox' "${home}/.config/labwc/autostart"; then
	fail "labwc launch remains"
fi
grep -q '^foo = 1$' "${home}/.config/wayfire.ini" || fail "wayfire foo missing"
grep -q '^dpms_timeout = -1$' "${home}/.config/wayfire.ini" || fail "wayfire idle removed"
if grep -q 'nova_letterbox' "${home}/.config/wayfire.ini"; then
	fail "wayfire key remains"
fi
grep -q 'export EDITOR=vi' "${home}/.bashrc" || fail "bashrc editor missing"
grep -q 'alias ll=' "${home}/.bashrc" || fail "bashrc alias missing"
grep -F 'export PATH="$HOME/bin:$PATH"' "${home}/.bashrc" >/dev/null || fail "unrelated PATH removed"
grep -F "export PATH=\"${bin}:\$PATH\"" "${home}/.bashrc" >/dev/null || fail "shared bin PATH should stay"
if grep -q 'nova-letterbox-path-begin' "${home}/.bashrc"; then
	fail "path block remains"
fi
if grep -q '/opt/nova-letterbox/bin' "${home}/.bashrc"; then
	fail "nova-letterbox PATH export remains"
fi
[[ ! -e "${home}/.config/systemd/user/nova-letterbox.service" ]] || fail "unit remains"
[[ ! -e "${home}/.config/systemd/user/graphical-session.target.wants/nova-letterbox.service" ]] || fail "unit enable symlink remains"
[[ -f "${home}/.config/systemd/user/other.service" ]] || fail "other unit removed"
[[ ! -e "${share}/godot/app_userdata/NOVA Letterbox" ]] || fail "godot data remains"
[[ -d "${share}/godot/app_userdata" ]] || fail "godot app_userdata tree was removed"
[[ -f "${share}/godot/app_userdata/Other Project/keep.txt" ]] || fail "other Godot project was removed"
[[ "$out" == *"Removed:"* && "$out" == *"${share}/nova-letterbox"* ]] || fail "summary missing app dir: ${out}"
[[ "$out" == *"updated ${home}/.bashrc"* ]] || fail "summary missing bashrc: ${out}"
[[ "$out" == *"still exports PATH for ${bin}"* ]] || fail "summary should keep shared PATH: ${out}"
[[ "$out" == *"Not changed:"* ]] || fail "summary missing shared-package note"
[[ "$out" == *"Could not remove:"* ]] && fail "clean uninstall reported failures: ${out}"

# Second run is safe. The shared PATH line is still reported and nothing else returns.
set +e
out2="$(run_uninstall "$home" --yes 2>"${home}/err2")"
status2=$?
set -e
[[ "$status2" -eq 0 ]] || fail "second uninstall status ${status2}: ${out2}"
grep -F "export PATH=\"${bin}:\$PATH\"" "${home}/.bashrc" >/dev/null || fail "second run removed shared PATH"
[[ ! -e "${share}/nova-letterbox" ]] || fail "second run recreated app dir"
rm -rf "$home" "$sudo_bin"
rm -f "$sudo_log"

# Nothing installed.
empty="$(mktemp -d)"
empty_out="$(run_uninstall "$empty" --yes)"
[[ "$empty_out" == *"NOVA Letterbox is not installed."* ]] || fail "empty install text: ${empty_out}"
rm -rf "$empty"

# Unclosed marker is left in place and is not a failed delete.
open_home="$(mktemp -d)"
mkdir -p "${open_home}/.config/hypr"
cat >"${open_home}/.config/hypr/autostart.conf" <<'EOF'
exec-once = waybar
# nova-letterbox-begin
exec-once = nova-letterbox
EOF
open_out="$(run_uninstall "$open_home" --yes)"
grep -q 'nova-letterbox-begin' "${open_home}/.config/hypr/autostart.conf" || fail "unclosed marker was deleted"
grep -q 'exec-once = waybar' "${open_home}/.config/hypr/autostart.conf" || fail "unclosed marker ate waybar"
[[ "$open_out" == *"no marked block or known launch line was removed"* ]] || fail "unclosed marker not reported: ${open_out}"
rm -rf "$open_home"

# Home files that cannot be deleted fail the run and stay on disk.
locked="$(mktemp -d)"
mkdir -p "${locked}/.local/share/nova-letterbox"
printf 'keep\n' >"${locked}/.local/share/nova-letterbox/nova-letterbox"
chmod a-w "${locked}/.local/share/nova-letterbox" "${locked}/.local/share"
set +e
locked_out="$(run_uninstall "$locked" --yes 2>"${locked}/err")"
locked_status=$?
set -e
[[ "$locked_status" -ne 0 ]] || fail "unwritable app dir should fail"
[[ -f "${locked}/.local/share/nova-letterbox/nova-letterbox" ]] || fail "unwritable binary was removed"
[[ "$locked_out" == *"Could not remove:"* || "$(cat "${locked}/err")" == *failed:* ]] || fail "missing failure report"
chmod u+w "${locked}/.local/share/nova-letterbox" "${locked}/.local/share"
rm -rf "$locked"

# Custom prefix is removed. A remaining user install keeps generic autostart.
custom_home="$(mktemp -d)"
custom="$(mktemp -d)"
mkdir -p "${custom}/share/nova-letterbox" "${custom}/bin" \
	"${custom_home}/.local/share/nova-letterbox" "${custom_home}/.local/bin" \
	"${custom_home}/.config/hypr" "${custom_home}/.config/labwc"
printf 'custom\n' >"${custom}/share/nova-letterbox/nova-letterbox"
ln -s "${custom}/share/nova-letterbox/nova-letterbox" "${custom}/bin/nova-letterbox"
printf 'user\n' >"${custom_home}/.local/share/nova-letterbox/nova-letterbox"
ln -s "${custom_home}/.local/share/nova-letterbox/nova-letterbox" "${custom_home}/.local/bin/nova-letterbox"
cat >"${custom_home}/.config/hypr/autostart.conf" <<'EOF'
exec-once = waybar
# nova-letterbox-begin
exec-once = nova-letterbox
# nova-letterbox-end
EOF
cat >"${custom_home}/.config/labwc/autostart" <<EOF
${custom_home}/.local/bin/nova-letterbox --fullscreen &
${custom}/bin/nova-letterbox --fullscreen &
EOF
run_uninstall "$custom_home" --yes --prefix "$custom" >/dev/null
[[ ! -e "${custom}/share/nova-letterbox" ]] || fail "custom app dir remains"
[[ ! -e "${custom}/bin/nova-letterbox" && ! -L "${custom}/bin/nova-letterbox" ]] || fail "custom cli remains"
[[ -f "${custom_home}/.local/share/nova-letterbox/nova-letterbox" ]] || fail "user binary removed with --prefix"
grep -q 'exec-once = nova-letterbox' "${custom_home}/.config/hypr/autostart.conf" || fail "generic exec-once should stay"
grep -q 'exec-once = waybar' "${custom_home}/.config/hypr/autostart.conf" || fail "waybar dropped in selective uninstall"
grep -F "${custom_home}/.local/bin/nova-letterbox" "${custom_home}/.config/labwc/autostart" >/dev/null || fail "user labwc line removed"
if grep -F "${custom}/bin/nova-letterbox" "${custom_home}/.config/labwc/autostart"; then
	fail "custom labwc line remains"
fi
rm -rf "$custom_home" "$custom"

# --system does not remove a user install, and does not call sudo when
# /usr/local has no NOVA Letterbox files.
if [[ -e /usr/local/share/nova-letterbox || -e /usr/local/bin/nova-letterbox || -L /usr/local/bin/nova-letterbox ]]; then
	echo "SKIP system-empty test; this machine already has /usr/local nova-letterbox files" >&2
else
	sys_home="$(mktemp -d)"
	mkdir -p "${sys_home}/.local/share/nova-letterbox" "${sys_home}/.config/hypr"
	printf 'user\n' >"${sys_home}/.local/share/nova-letterbox/nova-letterbox"
	printf '%s\n' 'exec-once = waybar' '# nova-letterbox-begin' 'exec-once = nova-letterbox' '# nova-letterbox-end' \
		>"${sys_home}/.config/hypr/autostart.conf"
	sys_log="$(mktemp)"
	sys_bin="$(mktemp -d)"
	cat >"${sys_bin}/sudo" <<EOF
#!/bin/sh
echo called >>"${sys_log}"
exit 1
EOF
	chmod +x "${sys_bin}/sudo"
	PATH="${sys_bin}:${PATH}" run_uninstall "$sys_home" --yes --system >/dev/null
	[[ -f "${sys_home}/.local/share/nova-letterbox/nova-letterbox" ]] || fail "--system removed the user binary"
	grep -q 'exec-once = nova-letterbox' "${sys_home}/.config/hypr/autostart.conf" || fail "--system removed generic autostart while a user install remains"
	if [[ -s "$sys_log" ]]; then
		fail "--system called sudo with nothing under /usr/local"
	fi
	rm -rf "$sys_home" "$sys_bin"
	rm -f "$sys_log"
fi

# Root-owned prefix: real sudo removes it. A failing sudo leaves it and exits non-zero.
if [[ -e /usr/local/share/nova-letterbox || -e /usr/local/bin/nova-letterbox || -L /usr/local/bin/nova-letterbox ]]; then
	echo "SKIP sudo prefix test; this machine already has /usr/local nova-letterbox files" >&2
else
	owned="$(mktemp -d)"
	sudo mkdir -p "${owned}/share/nova-letterbox" "${owned}/bin"
	printf 'root-owned\n' | sudo tee "${owned}/share/nova-letterbox/nova-letterbox" >/dev/null
	sudo ln -s "${owned}/share/nova-letterbox/nova-letterbox" "${owned}/bin/nova-letterbox"
	sudo chown -R root:root "$owned"
	sudo chmod 755 "$owned" "${owned}/share" "${owned}/share/nova-letterbox" "${owned}/bin"
	owned_home="$(mktemp -d)"
	owned_out="$(run_uninstall "$owned_home" --yes --prefix "$owned" 2>"${owned_home}/err")" || {
		sudo rm -rf "$owned"
		fail "sudo prefix uninstall failed: ${owned_out} $(cat "${owned_home}/err")"
	}
	[[ ! -e "${owned}/share/nova-letterbox" ]] || fail "sudo did not remove the app dir"
	[[ ! -e "${owned}/bin/nova-letterbox" && ! -L "${owned}/bin/nova-letterbox" ]] || fail "sudo did not remove the cli link"
	[[ "$owned_out" == *"Using sudo to remove"* ]] || fail "sudo uninstall did not say it was using sudo: ${owned_out}"
	sudo rm -rf "$owned"

	owned="$(mktemp -d)"
	sudo mkdir -p "${owned}/share/nova-letterbox"
	printf 'root-owned\n' | sudo tee "${owned}/share/nova-letterbox/nova-letterbox" >/dev/null
	sudo chown -R root:root "$owned"
	sudo chmod 755 "$owned" "${owned}/share" "${owned}/share/nova-letterbox"
	bad_sudo="$(mktemp -d)"
	cat >"${bad_sudo}/sudo" <<'EOF'
#!/bin/sh
echo "sudo refused" >&2
exit 1
EOF
	chmod +x "${bad_sudo}/sudo"
	set +e
	bad_out="$(PATH="${bad_sudo}:${PATH}" run_uninstall "$owned_home" --yes --prefix "$owned" 2>"${owned_home}/bad.err")"
	bad_status=$?
	set -e
	[[ "$bad_status" -ne 0 ]] || fail "failing sudo should be non-zero"
	[[ -f "${owned}/share/nova-letterbox/nova-letterbox" ]] || fail "failing sudo removed the binary"
	[[ "$bad_out" == *"Could not remove:"* || "$(cat "${owned_home}/bad.err")" == *failed:* ]] || fail "failing sudo missing report: ${bad_out}"
	sudo rm -rf "$owned"
	rm -rf "$owned_home" "$bad_sudo"
fi

# Refusing an unexpected tree is a failed check, not a recursive delete.
# shellcheck disable=SC1091
HOME=/tmp bash -c '
	set -euo pipefail
	source ./uninstall.sh
	if assert_app_dir /usr/local/nova-letterbox /usr/local; then
		exit 2
	fi
	if assert_app_dir /usr/local/share/nova-letterbox /usr/local; then
		exit 3
	fi
	if assert_cli /bin/nova-letterbox /; then
		exit 4
	fi
	if assert_cli /usr/bin/nova-letterbox /usr; then
		exit 5
	fi
	if assert_icon /usr/local/share/icons/hicolor/scalable/apps/other.svg /usr/local/share; then
		exit 6
	fi
	assert_app_dir /usr/local/share/nova-letterbox /usr/local/share
	assert_cli /usr/local/bin/nova-letterbox /usr/local
	assert_icon /usr/local/share/icons/hicolor/scalable/apps/nova-letterbox.svg /usr/local/share
	assert_godot_app_dir "${HOME}/.local/share/godot/app_userdata/NOVA Letterbox"
	if assert_godot_app_dir "${HOME}/.local/share/godot/app_userdata"; then
		exit 7
	fi
	if assert_godot_app_dir "${HOME}/.local/share/godot"; then
		exit 8
	fi
	if XDG_DATA_HOME=/ assert_godot_app_dir "/godot/app_userdata/NOVA Letterbox"; then
		exit 9
	fi
	XDG_DATA_HOME=/tmp/xdg-nova assert_godot_app_dir "/tmp/xdg-nova/godot/app_userdata/NOVA Letterbox"
	if XDG_DATA_HOME=/tmp/xdg-nova assert_godot_app_dir "/tmp/xdg-nova/godot/app_userdata/Other Project"; then
		exit 10
	fi
	exit 0
' || fail "path checks rejected a real install path or allowed an unsafe one"

# Runtime Godot data is not part of the install. --yes removes only the
# NOVA Letterbox folder under ~/.local/share and under XDG_DATA_HOME.
xdg_home="$(mktemp -d)"
xdg_root="$(mktemp -d)"
mkdir -p \
	"${xdg_home}/.local/share/godot/app_userdata/NOVA Letterbox/logs" \
	"${xdg_home}/.local/share/godot/app_userdata/NOVA Letterbox/shader_cache" \
	"${xdg_home}/.local/share/godot/app_userdata/Other Project" \
	"${xdg_root}/godot/app_userdata/NOVA Letterbox/shader_cache" \
	"${xdg_root}/godot/app_userdata/Other Project"
printf 'log\n' >"${xdg_home}/.local/share/godot/app_userdata/NOVA Letterbox/logs/godot.log"
printf 'cache\n' >"${xdg_home}/.local/share/godot/app_userdata/NOVA Letterbox/shader_cache/entry"
printf 'keep\n' >"${xdg_home}/.local/share/godot/app_userdata/Other Project/keep.txt"
printf 'xdg-cache\n' >"${xdg_root}/godot/app_userdata/NOVA Letterbox/shader_cache/entry"
printf 'xdg-keep\n' >"${xdg_root}/godot/app_userdata/Other Project/keep.txt"
xdg_out="$(HOME="$xdg_home" XDG_DATA_HOME="$xdg_root" bash ./uninstall.sh --yes)"
[[ ! -e "${xdg_home}/.local/share/godot/app_userdata/NOVA Letterbox" ]] || fail "default godot data remains"
[[ ! -e "${xdg_root}/godot/app_userdata/NOVA Letterbox" ]] || fail "XDG godot data remains"
[[ -d "${xdg_home}/.local/share/godot/app_userdata" ]] || fail "default app_userdata removed"
[[ -d "${xdg_root}/godot/app_userdata" ]] || fail "XDG app_userdata removed"
[[ -f "${xdg_home}/.local/share/godot/app_userdata/Other Project/keep.txt" ]] || fail "default sibling project removed"
[[ -f "${xdg_root}/godot/app_userdata/Other Project/keep.txt" ]] || fail "XDG sibling project removed"
[[ -d "${xdg_root}/godot" ]] || fail "XDG godot directory removed"
[[ "$xdg_out" == *"${xdg_home}/.local/share/godot/app_userdata/NOVA Letterbox"* ]] || fail "summary missing default godot path: ${xdg_out}"
[[ "$xdg_out" == *"${xdg_root}/godot/app_userdata/NOVA Letterbox"* ]] || fail "summary missing XDG godot path: ${xdg_out}"
rm -rf "$xdg_home" "$xdg_root"

# Interactive prompts: decline leaves the install; a later no keeps PATH and app data.
python3 - "$root" <<'PY'
import os, pty, select, subprocess, sys, tempfile, shutil

root = sys.argv[1]

def prepare():
    home = tempfile.mkdtemp()
    share = os.path.join(home, ".local/share/nova-letterbox")
    os.makedirs(share)
    with open(os.path.join(share, "nova-letterbox"), "w", encoding="utf-8") as handle:
        handle.write("bin\n")
    data = os.path.join(home, ".local/share/godot/app_userdata/NOVA Letterbox")
    os.makedirs(data)
    with open(os.path.join(data, "note"), "w", encoding="utf-8") as handle:
        handle.write("x\n")
    rc = os.path.join(home, ".bashrc")
    with open(rc, "w", encoding="utf-8") as handle:
        handle.write(
            "export EDITOR=vi\n"
            "# nova-letterbox-path-begin\n"
            f'export PATH="{home}/.local/bin:$PATH"\n'
            "# nova-letterbox-path-end\n"
        )
    return home

def run(home, replies):
    master, slave = pty.openpty()
    env = os.environ.copy()
    env["HOME"] = home
    env["XDG_DATA_HOME"] = os.path.join(home, ".local/share")
    env.pop("NOVA_NONINTERACTIVE", None)
    proc = subprocess.Popen(
        ["bash", os.path.join(root, "uninstall.sh")],
        stdin=slave,
        stdout=slave,
        stderr=slave,
        env=env,
        cwd=root,
        close_fds=True,
    )
    os.close(slave)
    buf = b""
    sent = 0
    import time
    deadline = time.time() + 8
    while time.time() < deadline and proc.poll() is None:
        ready, _, _ = select.select([master], [], [], 0.2)
        if master in ready:
            try:
                buf += os.read(master, 4096)
            except OSError:
                break
        if sent < len(replies) and buf.count(b"[y/N]") > sent:
            os.write(master, replies[sent])
            sent += 1
    while True:
        ready, _, _ = select.select([master], [], [], 0.2)
        if not ready:
            break
        try:
            chunk = os.read(master, 4096)
        except OSError:
            break
        if not chunk:
            break
        buf += chunk
    code = proc.wait(timeout=5)
    os.close(master)
    return code, sent, buf.decode(errors="replace")

home = prepare()
code, sent, text = run(home, [b"n\n"])
binary = os.path.join(home, ".local/share/nova-letterbox/nova-letterbox")
if code != 0 or sent != 1 or not os.path.exists(binary) or "Uninstall cancelled." not in text:
    sys.stderr.write(f"cancel failed code={code} sent={sent}\n{text}\n")
    shutil.rmtree(home)
    sys.exit(1)
shutil.rmtree(home)

home = prepare()
code, sent, text = run(home, [b"y\n", b"n\n", b"n\n"])
binary = os.path.join(home, ".local/share/nova-letterbox/nova-letterbox")
godot = os.path.join(home, ".local/share/godot/app_userdata/NOVA Letterbox")
rc = os.path.join(home, ".bashrc")
rc_text = open(rc, encoding="utf-8").read()
ok = (
    code == 0
    and sent == 3
    and not os.path.exists(binary)
    and os.path.isdir(godot)
    and "nova-letterbox-path-begin" in rc_text
    and "PATH lines kept" in text
    and "kept" in text
)
if not ok:
    sys.stderr.write(f"partial decline failed code={code} sent={sent}\n{text}\n{rc_text}\n")
    shutil.rmtree(home)
    sys.exit(1)
shutil.rmtree(home)
PY

echo "OK"
