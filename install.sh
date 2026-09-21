#!/usr/bin/env bash
# Install the NOVA Letterbox Linux release binary.
#
#   curl -fsSL https://raw.githubusercontent.com/velocityeu/nova-letterbox/main/install.sh | bash
#
# A terminal (stdin is a TTY) runs a short text wizard: dependencies, PATH,
# and an autostart question. A pipe, --yes, or NOVA_NONINTERACTIVE=1 skips
# every prompt and does not enable autostart unless --autostart is set.
#
# This repository is private. Anonymous curl of this script and of Release
# assets fails until the repo is public. Export GH_TOKEN (or GITHUB_TOKEN),
# or log in with `gh auth login`, before running. See the README.
#
#   NOVA_VERSION=v0.1.0     pin a tag (0.1.0 is accepted; a leading v is added)
#   NOVA_VERSION=continuous rolling prerelease built from main
#   NOVA_FROM_SOURCE=1      export with a local Godot 4.3.stable instead
#   NOVA_REPO=owner/name    override the GitHub repo
#   NOVA_NONINTERACTIVE=1   same as --yes
set -euo pipefail

REPO="${NOVA_REPO:-velocityeu/nova-letterbox}"
ASSET_X86_64="nova-letterbox-linux-x86_64"
ASSET_ARM64="nova-letterbox-linux-arm64"

PREFIX=""
SYSTEM=0
FULLSCREEN=0
OMARCHY=0
AUTOSTART=0
YES=0
DISTRO=""
AUTOSTART_KIND=""
PATH_RC=""

# Global so the EXIT trap can still see it after main returns. A local
# disappears first, and set -u then aborts a successful install.
_NOVA_INSTALL_TMP=""

cleanup_install_tmp() {
	if [[ -n "${_NOVA_INSTALL_TMP:-}" ]]; then
		rm -f "${_NOVA_INSTALL_TMP}"
	fi
	_NOVA_INSTALL_TMP=""
}

begin_install_tmp() {
	_NOVA_INSTALL_TMP="$(mktemp)"
	trap cleanup_install_tmp EXIT
}

end_install_tmp() {
	cleanup_install_tmp
	trap - EXIT
}

die() {
	echo "error: $*" >&2
	exit 1
}

usage() {
	cat <<EOF
Usage: install.sh [--fullscreen] [--system] [--prefix DIR] [--omarchy] [--autostart] [--yes]

Install the matching Linux release binary from the latest GitHub Release.
The binary is ~/.local/share/nova-letterbox/nova-letterbox.
~/.local/bin/nova-letterbox is a symlink to it. No sudo unless --system
cannot write /usr/local, or you agree to install missing packages.

In a terminal this is a text wizard (dependencies, PATH, autostart).
--yes, NOVA_NONINTERACTIVE=1, or a pipe skips the wizard.

  --fullscreen   launch fullscreen when install finishes
  --system       use /usr/local/share and /usr/local/bin (sudo only if needed)
  --prefix DIR   use DIR/share and DIR/bin
  --omarchy      write the Omarchy desktop entry (also implied by /etc/os-release)
  --autostart    enable login autostart without asking
  --yes          non-interactive: no prompts, no package installs, no PATH edit
  -h, --help     show this help

Environment:
  GH_TOKEN or GITHUB_TOKEN   required for this private repo if \`gh\` is not logged in
  NOVA_VERSION               tag to download (v0.1.0, 0.1.0, or continuous)
  NOVA_FROM_SOURCE=1         build with Godot 4.3.stable instead of downloading
  NOVA_NONINTERACTIVE=1      same as --yes
EOF
}

parse_args() {
	PREFIX=""
	SYSTEM=0
	FULLSCREEN=0
	OMARCHY=0
	AUTOSTART=0
	YES=0
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--fullscreen) FULLSCREEN=1 ;;
			--system) SYSTEM=1 ;;
			--prefix)
				[[ $# -ge 2 ]] || die "--prefix needs a directory"
				PREFIX="$2"
				shift
				;;
			--prefix=*)
				PREFIX="${1#--prefix=}"
				[[ -n "$PREFIX" ]] || die "--prefix needs a directory"
				;;
			--omarchy) OMARCHY=1 ;;
			--autostart) AUTOSTART=1 ;;
			--yes) YES=1 ;;
			-h|--help) usage; exit 0 ;;
			*) die "unknown argument: $1 (try --help)" ;;
		esac
		shift
	done
}

require_linux() {
	local os
	os="$(uname -s)"
	if [[ "$os" != "Linux" ]]; then
		die "NOVA Letterbox installs on Linux only (this machine reports ${os})."
	fi
}

normalize_arch() {
	case "$1" in
		x86_64|amd64) printf 'x86_64' ;;
		aarch64|arm64) printf 'aarch64' ;;
		*) return 1 ;;
	esac
}

detect_arch() {
	local raw norm
	raw="$(uname -m)"
	norm="$(normalize_arch "$raw")" || die "unsupported architecture: ${raw} (need x86_64 or aarch64)."
	printf '%s' "$norm"
}

asset_for_arch() {
	case "$1" in
		x86_64) printf '%s' "$ASSET_X86_64" ;;
		aarch64) printf '%s' "$ASSET_ARM64" ;;
		*) return 1 ;;
	esac
}

preset_for_arch() {
	case "$1" in
		x86_64) printf '%s' "Linux Desktop" ;;
		aarch64) printf '%s' "Linux Pi ARM64" ;;
		*) return 1 ;;
	esac
}

normalize_version_tag() {
	local version="${1:-}"
	if [[ -z "$version" || "$version" == "latest" ]]; then
		printf ''
		return 0
	fi
	case "$version" in
		continuous) printf 'continuous' ;;
		v*) printf '%s' "$version" ;;
		*) printf 'v%s' "$version" ;;
	esac
}

os_release_is_omarchy() {
	local file="$1"
	[[ -f "$file" ]] || return 1
	grep -qi 'omarchy' "$file"
}

resolve_token() {
	if [[ -n "${GH_TOKEN:-}" ]]; then
		printf '%s' "$GH_TOKEN"
		return 0
	fi
	if [[ -n "${GITHUB_TOKEN:-}" ]]; then
		printf '%s' "$GITHUB_TOKEN"
		return 0
	fi
	if command -v gh >/dev/null 2>&1; then
		gh auth token 2>/dev/null || true
		return 0
	fi
	printf ''
}

gh_logged_in() {
	command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1
}

resolve_prefix() {
	if [[ -n "$PREFIX" ]]; then
		printf '%s' "$PREFIX"
	elif [[ "$SYSTEM" == 1 ]]; then
		printf '%s' "/usr/local"
	else
		printf '%s' "${HOME}/.local"
	fi
}

share_root() {
	if [[ -n "$PREFIX" || "$SYSTEM" == 1 ]]; then
		printf '%s' "$(resolve_prefix)/share"
	else
		printf '%s' "${XDG_DATA_HOME:-${HOME}/.local/share}"
	fi
}

bin_dir() {
	printf '%s' "$(resolve_prefix)/bin"
}

app_dir() {
	printf '%s' "$(share_root)/nova-letterbox"
}

app_binary() {
	printf '%s' "$(app_dir)/nova-letterbox"
}

cli_link() {
	printf '%s' "$(bin_dir)/nova-letterbox"
}

# Read ELF64 class and e_machine. arch is x86_64 or aarch64.
verify_elf() {
	local path="$1"
	local arch="$2"
	python3 - "$path" "$arch" <<'PY'
import struct
import sys

path, arch = sys.argv[1], sys.argv[2]
expected = {"x86_64": 62, "aarch64": 183}
with open(path, "rb") as handle:
    header = handle.read(20)
if len(header) < 20 or header[:4] != b"\x7fELF":
    sys.exit("not an ELF file")
if header[4] != 2:
    sys.exit("not a 64-bit ELF")
machine = struct.unpack_from("<H", header, 18)[0]
if machine != expected[arch]:
    sys.exit("ELF machine %s is not %s" % (machine, arch))
PY
}

release_asset_fields() {
	local json_path="$1"
	local asset_name="$2"
	python3 - "$json_path" "$asset_name" <<'PY'
import json
import sys

document = json.load(open(sys.argv[1], encoding="utf-8"))
want = sys.argv[2]
for asset in document.get("assets") or []:
    if asset.get("name") == want:
        print(asset["id"])
        print(asset.get("browser_download_url") or "")
        raise SystemExit(0)
sys.exit(1)
PY
}

auth_hint() {
	if gh_logged_in || [[ -n "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ]]; then
		cat >&2 <<EOF
No matching GitHub Release asset for this repo.
install.sh uses the latest stable release, then the continuous prerelease.
Those assets appear after the release workflow runs on main (continuous)
or on a v* tag (the stable release install.sh prefers).
EOF
		return 0
	fi
	cat >&2 <<EOF
This repo is private, so release downloads need an authenticated GitHub account.
  gh auth login
  gh release download --repo ${REPO} --pattern 'nova-letterbox-linux-*'
or export GH_TOKEN (classic or fine-grained token that can read this repo's
contents and release assets) and run the installer again.
If no Release exists yet, the release workflow publishes a continuous
prerelease from main, and a v* tag publishes the stable release.
EOF
}

download_with_gh() {
	local tag="$1"
	local asset="$2"
	local dest="$3"
	if [[ -n "$tag" ]]; then
		gh release download "$tag" --repo "$REPO" --pattern "$asset" --output "$dest" --clobber
		return
	fi
	if gh release download --repo "$REPO" --pattern "$asset" --output "$dest" --clobber; then
		echo "Downloaded ${asset} from the latest stable release."
		return 0
	fi
	echo "No stable GitHub Release. Trying the continuous prerelease from main." >&2
	echo "Push a v* tag when you want install.sh to prefer a stable latest release." >&2
	gh release download continuous --repo "$REPO" --pattern "$asset" --output "$dest" --clobber
}

fetch_release_json() {
	local token="$1"
	local tag="$2"
	local out="$3"
	local url
	local -a args
	if [[ -z "$tag" ]]; then
		url="https://api.github.com/repos/${REPO}/releases/latest"
	else
		url="https://api.github.com/repos/${REPO}/releases/tags/${tag}"
	fi
	args=(-fsSL -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28")
	if [[ -n "$token" ]]; then
		args+=(-H "Authorization: Bearer ${token}")
	fi
	curl "${args[@]}" -o "$out" "$url"
}

download_with_curl() {
	local token="$1"
	local tag="$2"
	local asset="$3"
	local dest="$4"
	local json fields id url
	json="$(mktemp)"
	if [[ -z "$tag" ]]; then
		if ! fetch_release_json "$token" "" "$json"; then
			echo "No stable GitHub Release. Trying the continuous prerelease from main." >&2
			echo "Push a v* tag when you want install.sh to prefer a stable latest release." >&2
			if ! fetch_release_json "$token" "continuous" "$json"; then
				rm -f "$json"
				return 1
			fi
		else
			echo "Using the latest stable release."
		fi
	elif ! fetch_release_json "$token" "$tag" "$json"; then
		rm -f "$json"
		return 1
	fi
	if ! fields="$(release_asset_fields "$json" "$asset")"; then
		rm -f "$json"
		echo "error: release has no asset named ${asset}" >&2
		return 1
	fi
	rm -f "$json"
	id="$(printf '%s\n' "$fields" | head -n 1)"
	url="$(printf '%s\n' "$fields" | sed -n '2p')"
	[[ -n "$id" ]] || return 1
	if [[ -n "$token" ]]; then
		# First hop is the API (needs the token). The redirect is a signed URL.
		curl -fL \
			-H "Accept: application/octet-stream" \
			-H "Authorization: Bearer ${token}" \
			-H "X-GitHub-Api-Version: 2022-11-28" \
			-o "$dest" \
			"https://api.github.com/repos/${REPO}/releases/assets/${id}"
	else
		[[ -n "$url" ]] || return 1
		curl -fL -o "$dest" "$url"
	fi
}

download_asset() {
	local tag="$1"
	local asset="$2"
	local dest="$3"
	if gh_logged_in; then
		download_with_gh "$tag" "$asset" "$dest" || {
			auth_hint
			die "could not download ${asset}"
		}
		return 0
	fi
	local token
	token="$(resolve_token)"
	if [[ -z "$token" ]]; then
		echo "No GH_TOKEN and gh is not logged in. Trying an anonymous download." >&2
	fi
	if ! download_with_curl "$token" "$tag" "$asset" "$dest"; then
		auth_hint
		die "could not download ${asset}"
	fi
}

install_from_source() {
	local arch="$1"
	local dest="$2"
	local work preset built
	command -v godot >/dev/null 2>&1 || die "NOVA_FROM_SOURCE=1 needs Godot 4.3.stable on PATH as 'godot', plus Linux export templates"
	command -v git >/dev/null 2>&1 || die "NOVA_FROM_SOURCE=1 needs git"
	work="$(mktemp -d)"
	preset="$(preset_for_arch "$arch")"
	echo "Building ${preset} from source into ${work}"
	if gh_logged_in; then
		gh repo clone "$REPO" "$work/src" -- --depth 1
	else
		git clone --depth 1 "https://github.com/${REPO}.git" "$work/src"
	fi
	if [[ -n "${NOVA_VERSION:-}" && "${NOVA_VERSION}" != "latest" && "${NOVA_VERSION}" != "continuous" ]]; then
		git -C "$work/src" fetch --depth 1 origin "refs/tags/$(normalize_version_tag "$NOVA_VERSION"):refs/tags/$(normalize_version_tag "$NOVA_VERSION")"
		git -C "$work/src" checkout "$(normalize_version_tag "$NOVA_VERSION")"
	fi
	(cd "$work/src" && ./scripts/export-linux.sh "$preset")
	built="$(asset_for_arch "$arch")"
	[[ -f "$work/src/dist/${built}" ]] || die "source export did not produce dist/${built}"
	cp -f "$work/src/dist/${built}" "$dest"
	rm -rf "$work"
}

ensure_dir() {
	local dir="$1"
	if mkdir -p "$dir" 2>/dev/null && [[ -w "$dir" ]]; then
		return 0
	fi
	if [[ "$SYSTEM" == 1 ]]; then
		echo "Creating ${dir} with sudo."
		sudo mkdir -p "$dir"
		return 0
	fi
	die "cannot create ${dir}. Use a writable --prefix, or --system."
}

install_file() {
	local src="$1"
	local dest="$2"
	local dir
	dir="$(dirname "$dest")"
	ensure_dir "$dir"
	if [[ -w "$dir" ]]; then
		install -m 0755 "$src" "$dest"
	elif [[ "$SYSTEM" == 1 ]]; then
		echo "Copying to ${dest} with sudo."
		sudo install -m 0755 "$src" "$dest"
	else
		die "cannot write ${dest}. Use a writable --prefix, or --system."
	fi
}

link_cli() {
	local target="$1"
	local link="$2"
	local dir
	dir="$(dirname "$link")"
	ensure_dir "$dir"
	if [[ -w "$dir" ]]; then
		ln -sfn "$target" "$link"
	elif [[ "$SYSTEM" == 1 ]]; then
		sudo ln -sfn "$target" "$link"
	else
		die "cannot write ${link}. Use a writable --prefix, or --system."
	fi
}

install_payload() {
	local src="$1"
	install_file "$src" "$(app_binary)"
	link_cli "$(app_binary)" "$(cli_link)"
}

verify_installed() {
	local dest="$1"
	local arch="$2"
	local err
	verify_elf "$dest" "$arch"
	err="$(mktemp)"
	if "$dest" --version >"$err" 2>&1; then
		echo "Binary check: $(head -n 1 "$err")"
		rm -f "$err"
		return 0
	fi
	echo "Installed ${dest}, but --version did not run:" >&2
	cat "$err" >&2
	rm -f "$err"
	cat >&2 <<EOF
The file is a valid ${arch} ELF. Godot still needs the usual GUI libraries
(libX11, libXcursor, libXinerama, libXrandr, libXi, libGL, ALSA).
On Debian, Raspberry Pi OS, or Ubuntu those come from the desktop session.
On Arch / Omarchy they are already installed with Hyprland.
EOF
	exit 1
}

# Godot 4.3 uses application/config/name as the Wayland app_id and the X11
# WM_CLASS class. That name is "NOVA Letterbox".
WM_CLASS="NOVA Letterbox"

desktop_exec_line() {
	local omarchy="${1:-0}"
	local bin
	bin="$(cli_link)"
	if [[ "$omarchy" == 1 ]]; then
		printf '%s' "omarchy-launch-or-focus \"${WM_CLASS}\" \"${bin} --fullscreen\""
	else
		printf '%s' "${bin} --fullscreen"
	fi
}

write_icon() {
	local dest
	dest="$(share_root)/icons/hicolor/scalable/apps/nova-letterbox.svg"
	ensure_dir "$(dirname "$dest")"
	cat >"$dest" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <rect width="128" height="128" rx="18" fill="#191a1c"/>
  <circle cx="64" cy="64" r="46" fill="none" stroke="#c17d52" stroke-width="8"/>
  <circle cx="64" cy="64" r="34" fill="#101114"/>
  <line x1="64" y1="64" x2="98" y2="46" stroke="#e6a45a" stroke-width="4" stroke-linecap="round"/>
  <circle cx="64" cy="64" r="5" fill="#e6a45a"/>
  <circle cx="64" cy="64" r="2.2" fill="#101114"/>
</svg>
EOF
	echo "Icon: ${dest}"
}

write_desktop() {
	local exec_line dest
	exec_line="$(desktop_exec_line "$OMARCHY")"
	dest="$(share_root)/applications/nova-letterbox.desktop"
	ensure_dir "$(dirname "$dest")"
	cat >"$dest" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=NOVA Letterbox
Comment=1920x480 telemetry letterbox
Exec=${exec_line}
Icon=nova-letterbox
Terminal=false
Categories=Utility;
StartupNotify=false
StartupWMClass=${WM_CLASS}
EOF
	echo "Desktop entry: ${dest}"
}

refresh_desktop_caches() {
	local share apps icons
	share="$(share_root)"
	apps="${share}/applications"
	icons="${share}/icons/hicolor"
	if command -v update-desktop-database >/dev/null 2>&1; then
		update-desktop-database "$apps" >/dev/null 2>&1 || true
	fi
	if [[ -f "${icons}/index.theme" ]] && command -v gtk-update-icon-cache >/dev/null 2>&1; then
		gtk-update-icon-cache -f -t "$icons" >/dev/null 2>&1 || true
	fi
}

# kind and path of the Hyprland autostart file this machine will actually load.
# Prints two lines: kind, then path.
choose_autostart_target() {
	local home="${1:-$HOME}"
	local candidate
	for candidate in \
		"${home}/.config/omarchy/autostart.conf" \
		"${home}/.config/omarchy/hypr/autostart.conf"
	do
		if [[ -f "$candidate" ]]; then
			printf '%s\n%s\n' conf "$candidate"
			return 0
		fi
	done
	if [[ -f "${home}/.config/hypr/autostart.lua" || -f "${home}/.config/hypr/hyprland.lua" ]]; then
		printf '%s\n%s\n' lua "${home}/.config/hypr/autostart.lua"
		return 0
	fi
	printf '%s\n%s\n' conf "${home}/.config/hypr/autostart.conf"
}

append_marked_block() {
	local file="$1"
	local block="$2"
	mkdir -p "$(dirname "$file")"
	if [[ -f "$file" ]] && grep -qF 'nova-letterbox-begin' "$file"; then
		echo "Already present: ${file}"
		return 0
	fi
	if [[ ! -f "$file" ]]; then
		: >"$file"
	fi
	printf '\n%s\n' "$block" >>"$file"
	echo "Updated ${file}"
}

install_hypr_autostart() {
	local home="${1:-$HOME}"
	local kind path
	local -a target
	mapfile -t target < <(choose_autostart_target "$home")
	kind="${target[0]}"
	path="${target[1]}"
	if [[ "$kind" == "lua" ]]; then
		append_marked_block "$path" "$(cat <<'EOF'
-- nova-letterbox-begin
o.launch_on_start("nova-letterbox")
-- nova-letterbox-end
EOF
)"
		append_marked_block "${home}/.config/hypr/looknfeel.lua" "$(cat <<'EOF'
-- nova-letterbox-begin
-- Fullscreen on the 1920x480 HDMI output. Change the monitor name if hyprctl differs.
o.window({ class = "^NOVA Letterbox$" }, { fullscreen = true, monitor = "HDMI-A-1" })
-- nova-letterbox-end
EOF
)"
		echo "Omarchy loads ~/.config/hypr/autostart.lua. Reload Hyprland, or log in again."
		return 0
	fi
	append_marked_block "$path" "$(cat <<'EOF'
# nova-letterbox-begin
exec-once = nova-letterbox
windowrule {
    name = nova-letterbox
    match:class = ^(NOVA Letterbox)$
    fullscreen = true
    monitor = HDMI-A-1
}
# nova-letterbox-end
EOF
)"
	echo "Reload Hyprland, or log in again. The monitor name in the window rule is HDMI-A-1."
}

print_next_steps() {
	local bin
	bin="$(cli_link)"
	cat <<EOF

Installed: $(app_binary)
Command: ${bin}

Fullscreen:
  ${bin} --fullscreen

Engine health check (no window):
  ${bin} --version

Letterbox version line, then exit:
  NOVA_PRINT_VERSION=1 ${bin}

Keys, with the window focused: 1 Simple, 2 Complete, Tab toggles.
The project uses the GL Compatibility renderer.

Pi HDMI 1920×480, blanking, and labwc/wayfire:
  https://github.com/${REPO}/blob/main/docs/pi-kiosk.md
EOF
	if [[ "$OMARCHY" == 1 ]]; then
		cat <<EOF

Omarchy: Super+Space, then NOVA Letterbox.
The desktop entry focuses the existing window when it is already open.
EOF
		if [[ "$AUTOSTART" != 1 ]]; then
			echo "Login autostart was not added. Re-run with --autostart to start it with Hyprland."
		fi
		echo "Notes: https://github.com/${REPO}/blob/main/docs/omarchy.md"
	elif os_release_is_omarchy /etc/os-release; then
		echo "Omarchy detected. See https://github.com/${REPO}/blob/main/docs/omarchy.md"
	fi
	case ":${PATH}:" in
		*":$(dirname "$bin"):"*) ;;
		*)
			echo
			echo "That directory is not on PATH. For this shell:"
			echo "  export PATH=\"$(dirname "$bin"):\$PATH\""
			;;
	esac
	if [[ -n "${PATH_RC:-}" ]]; then
		echo
		echo "PATH line written to ${PATH_RC}. Open a new terminal so the shell reads it."
	fi
	case "${AUTOSTART_KIND:-}" in
		labwc)
			echo "Autostart appends to ~/.config/labwc/autostart."
			echo "wayfire.ini and the systemd user unit: https://github.com/${REPO}/blob/main/docs/pi-kiosk.md"
			;;
		wayfire)
			echo "Autostart updates ~/.config/wayfire.ini."
			echo "labwc and the systemd user unit: https://github.com/${REPO}/blob/main/docs/pi-kiosk.md"
			;;
		xdg)
			echo "Autostart: ~/.config/autostart/nova-letterbox.desktop"
			;;
	esac
}

# stdin_is_tty is 1 or 0 so tests do not depend on the runner's terminal.
# 0 means: do not prompt (pipe, --yes, or NOVA_NONINTERACTIVE=1).
should_prompt() {
	local stdin_is_tty="${1:-0}"
	if [[ "${NOVA_NONINTERACTIVE:-}" == "1" ]]; then
		return 1
	fi
	if [[ "${YES:-0}" == "1" ]]; then
		return 1
	fi
	[[ "$stdin_is_tty" == "1" ]]
}

interactive_mode() {
	local tty=0
	if [[ -t 0 ]]; then
		tty=1
	fi
	should_prompt "$tty"
}

ui_heading() {
	if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
		printf '\033[1m%s\033[0m\n' "$*"
	else
		printf '%s\n' "$*"
	fi
}

ui_step() {
	echo
	ui_heading "[$1/6] $2"
}

# Read one answer from the terminal. /dev/tty is preferred so a pipe is not
# consumed. If this process has no controlling terminal, stdin is used;
# interactive_mode already required stdin to be a TTY.
read_reply() {
	local prompt="$1"
	local reply=""
	# -r /dev/tty can be true when open still fails (no controlling terminal).
	if ( : </dev/tty ) 2>/dev/null && read -r -p "$prompt" reply </dev/tty; then
		printf '%s' "$reply"
		return 0
	fi
	if [[ -t 0 ]] && read -r -p "$prompt" reply; then
		printf '%s' "$reply"
		return 0
	fi
	return 1
}

# Default is yes. Used for the welcome continue prompt.
ask_default_yes() {
	local prompt="$1"
	local reply=""
	if ! interactive_mode; then
		return 0
	fi
	if ! reply="$(read_reply "${prompt} [Y/n] ")"; then
		printf '\n'
		return 0
	fi
	case "${reply,,}" in
		n|no) return 1 ;;
		*) return 0 ;;
	esac
}

# Default is no. Used before sudo, PATH edits, and autostart.
ask_yn() {
	local prompt="$1"
	local reply=""
	if ! interactive_mode; then
		return 1
	fi
	if ! reply="$(read_reply "${prompt} [y/N] ")"; then
		printf '\n'
		return 1
	fi
	case "${reply,,}" in
		y|yes) return 0 ;;
		*) return 1 ;;
	esac
}

read_model() {
	local f
	for f in /proc/device-tree/model /sys/firmware/devicetree/base/model; do
		if [[ -r "$f" ]]; then
			tr -d '\0' <"$f" || true
			return 0
		fi
	done
	printf ''
}

os_release_field() {
	local file="$1"
	local key="$2"
	local line=""
	[[ -f "$file" ]] || return 0
	line="$(grep -E "^${key}=" "$file" | head -n 1 || true)"
	line="${line#*=}"
	line="${line#\"}"
	line="${line%\"}"
	printf '%s' "$line"
}

# Prints omarchy, pi, debian, arch, or linux.
# Pass an os-release path. Omit the model path to read this machine.
# Pass an empty model path to ignore the live device tree (tests).
detect_distro() {
	local os_file="$1"
	local model_file="${2-__live__}"
	local model="" id="" id_like="" pretty="" name="" blob=""
	if [[ "$model_file" == "__live__" ]]; then
		model="$(read_model)"
		if [[ -f /etc/rpi-issue ]]; then
			model="${model} Raspberry"
		fi
	elif [[ -n "$model_file" && -f "$model_file" ]]; then
		model="$(tr -d '\0' <"$model_file")"
	fi
	if [[ -f "$os_file" ]] && os_release_is_omarchy "$os_file"; then
		printf 'omarchy'
		return 0
	fi
	id="$(os_release_field "$os_file" ID)"
	id_like="$(os_release_field "$os_file" ID_LIKE)"
	pretty="$(os_release_field "$os_file" PRETTY_NAME)"
	name="$(os_release_field "$os_file" NAME)"
	blob="${id} ${id_like} ${pretty} ${name} ${model}"
	if [[ "$id" == "raspbian" || "$id" == "raspios" ]] || printf '%s' "$blob" | grep -qi 'raspberry'; then
		printf 'pi'
		return 0
	fi
	case "$id" in
		ubuntu|debian|linuxmint|pop) printf 'debian'; return 0 ;;
		arch|endeavouros|manjaro) printf 'arch'; return 0 ;;
	esac
	if [[ "$id_like" == *debian* || "$id_like" == *ubuntu* ]]; then
		printf 'debian'
		return 0
	fi
	if [[ "$id_like" == *arch* ]]; then
		printf 'arch'
		return 0
	fi
	printf 'linux'
}

distro_label() {
	case "$1" in
		omarchy) printf 'Omarchy' ;;
		pi) printf 'Raspberry Pi OS' ;;
		debian) printf 'Debian/Ubuntu' ;;
		arch) printf 'Arch Linux' ;;
		*) printf 'Linux' ;;
	esac
}

package_manager_for_distro() {
	case "$1" in
		omarchy|arch) printf 'pacman' ;;
		pi|debian) printf 'apt' ;;
		*)
			if command -v pacman >/dev/null 2>&1; then
				printf 'pacman'
			elif command -v apt-get >/dev/null 2>&1; then
				printf 'apt'
			else
				printf 'none'
			fi
			;;
	esac
}

package_manager_label() {
	case "$1" in
		apt) printf 'apt' ;;
		pacman) printf 'pacman' ;;
		*) printf 'no package manager' ;;
	esac
}

# command|apt package|pacman package|level
# Names are the real distro packages. ping is iputils (the -W flag the
# shell uses). Arch calls the wireless tools package wireless_tools;
# Debian calls it wireless-tools. nmcli is optional.
dep_table() {
	cat <<'EOF'
python3|python3|python|required
curl|curl|curl|required
ping|iputils-ping|iputils|recommended
iw|iw|iw|recommended
iwgetid|wireless-tools|wireless_tools|recommended
ethtool|ethtool|ethtool|recommended
nmcli|network-manager|networkmanager|optional
EOF
}

package_for() {
	local cmd="$1"
	local pm="$2"
	local c a p lvl
	while IFS='|' read -r c a p lvl; do
		[[ "$c" == "$cmd" ]] || continue
		if [[ "$pm" == "pacman" ]]; then
			printf '%s' "$p"
		else
			printf '%s' "$a"
		fi
		return 0
	done < <(dep_table)
	return 1
}

# present is a newline-separated list of commands that already exist.
# gh_ok=1 skips curl (gh can download the release).
collect_packages() {
	local pm="$1"
	local level="$2"
	local present="$3"
	local gh_ok="${4:-0}"
	local c a p lvl
	while IFS='|' read -r c a p lvl; do
		[[ "$lvl" == "$level" ]] || continue
		if [[ "$c" == "curl" && "$gh_ok" == "1" ]]; then
			continue
		fi
		if printf '%s\n' "$present" | grep -F -qx "$c"; then
			continue
		fi
		if [[ "$pm" == "pacman" ]]; then
			printf '%s\n' "$p"
		elif [[ "$pm" == "none" ]]; then
			printf '%s\n' "$c"
		else
			printf '%s\n' "$a"
		fi
	done < <(dep_table)
}

present_commands() {
	local c rest
	while IFS='|' read -r c rest; do
		if command -v "$c" >/dev/null 2>&1; then
			printf '%s\n' "$c"
		fi
	done < <(dep_table)
}

print_dep_report() {
	local pm="$1"
	local present="$2"
	local gh_ok="$3"
	local c a p lvl pkg state
	printf '  %-12s %-12s %s\n' "Command" "Status" "Package"
	while IFS='|' read -r c a p lvl; do
		if [[ "$pm" == "pacman" ]]; then
			pkg="$p"
		elif [[ "$pm" == "none" ]]; then
			pkg="n/a"
		else
			pkg="$a"
		fi
		state="missing"
		if printf '%s\n' "$present" | grep -F -qx "$c"; then
			state="ok"
		elif [[ "$c" == "curl" && "$gh_ok" == "1" ]]; then
			state="ok (gh)"
		fi
		printf '  %-12s %-12s %s (%s)\n' "$c" "$state" "$pkg" "$lvl"
	done < <(dep_table)
}

install_with_package_manager() {
	local pm="$1"
	local status=0
	shift
	if [[ "$#" -eq 0 ]]; then
		return 0
	fi
	if [[ "$pm" == "apt" ]]; then
		if [[ "$(id -u)" -eq 0 ]]; then
			DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" || status=$?
		else
			sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" || status=$?
		fi
	elif [[ "$pm" == "pacman" ]]; then
		if [[ "$(id -u)" -eq 0 ]]; then
			pacman -S --needed --noconfirm "$@" || status=$?
		else
			sudo pacman -S --needed --noconfirm "$@" || status=$?
		fi
	else
		echo "No apt or pacman. Install by hand: $*" >&2
		return 1
	fi
	return "$status"
}

offer_package_level() {
	local pm="$1"
	local level="$2"
	local present gh_ok pkgs joined how
	local -a arr=()
	present="$(present_commands)"
	gh_ok=0
	if gh_logged_in; then
		gh_ok=1
	fi
	pkgs="$(collect_packages "$pm" "$level" "$present" "$gh_ok")"
	if [[ -z "$pkgs" ]]; then
		return 0
	fi
	joined="${pkgs//$'\n'/ }"
	echo "Missing ${level}: ${joined}"
	if [[ "$pm" == "none" ]]; then
		echo "No apt or pacman here. Install these commands yourself if you want them."
		return 0
	fi
	if [[ "$(id -u)" -ne 0 ]] && ! command -v sudo >/dev/null 2>&1; then
		echo "sudo is not available. Install them yourself and re-run if a later step needs them."
		return 0
	fi
	if [[ "$(id -u)" -eq 0 ]]; then
		how="Install"
	else
		how="Install with sudo"
	fi
	if ! ask_yn "${how} missing ${level} packages (${joined})?"; then
		echo "Skipped ${level} packages."
		return 0
	fi
	mapfile -t arr <<< "$pkgs"
	if ! install_with_package_manager "$pm" "${arr[@]}"; then
		echo "warning: ${level} package install did not succeed. Continuing." >&2
		return 0
	fi
	hash -r || true
}

wizard_welcome() {
	local arch="$1"
	local distro="$2"
	local pm="$3"
	echo
	ui_heading "NOVA Letterbox"
	echo "  Architecture: ${arch}"
	echo "  System: $(distro_label "$distro") ($(package_manager_label "$pm"))"
	echo "  Binary: $(app_binary)"
	echo "  Command: $(cli_link)"
	if [[ "$OMARCHY" == 1 ]]; then
		echo "  Desktop entry: Omarchy (Hyprland)"
	fi
	echo
	echo "This downloads the GitHub Release for this machine and installs it for the current user."
	if ! ask_default_yes "Continue?"; then
		echo "Install cancelled."
		exit 0
	fi
}

wizard_dependencies() {
	local pm="$1"
	local present gh_ok
	present="$(present_commands)"
	gh_ok=0
	if gh_logged_in; then
		gh_ok=1
	fi
	echo "A desktop session is assumed. OpenGL libraries stay with that image."
	echo "Recommended commands improve ping, Wi-Fi, and link speed. nmcli is optional."
	print_dep_report "$pm" "$present" "$gh_ok"
	echo
	offer_package_level "$pm" required
	offer_package_level "$pm" recommended
	offer_package_level "$pm" optional
}

path_has_dir() {
	local dir="$1"
	local path="$2"
	dir="${dir%/}"
	case ":${path}:" in
		*":${dir}:"*) return 0 ;;
		*) return 1 ;;
	esac
}

shell_rc_file() {
	local home="$1"
	local shell_path="$2"
	local base
	base="$(basename -- "$shell_path")"
	case "$base" in
		zsh) printf '%s/.zshrc' "$home" ;;
		bash) printf '%s/.bashrc' "$home" ;;
		*) printf '%s/.profile' "$home" ;;
	esac
}

path_export_line() {
	local dir="$1"
	printf 'export PATH="%s:$PATH"' "$dir"
}

ensure_path_line() {
	local rc="$1"
	local dir="$2"
	local line
	line="$(path_export_line "$dir")"
	if [[ -d "$rc" ]]; then
		echo "warning: ${rc} is a directory. Not writing PATH." >&2
		return 1
	fi
	if [[ -f "$rc" ]] && grep -qF "$line" "$rc"; then
		echo "PATH already set in ${rc}"
		return 0
	fi
	if [[ -f "$rc" ]] && grep -qF 'nova-letterbox-path-begin' "$rc"; then
		echo "PATH block already in ${rc}"
		return 0
	fi
	mkdir -p "$(dirname "$rc")"
	touch "$rc"
	cat >>"$rc" <<EOF

# nova-letterbox-path-begin
${line}
# nova-letterbox-path-end
EOF
	echo "Updated ${rc}"
}

wizard_path() {
	local dir rc line
	dir="$(bin_dir)"
	if path_has_dir "$dir" "${PATH}"; then
		echo "${dir} is already on PATH."
		return 0
	fi
	rc="$(shell_rc_file "$HOME" "${SHELL:-}")"
	line="$(path_export_line "$dir")"
	echo "${dir} is not on PATH."
	echo "Proposed line for ${rc}:"
	echo "  ${line}"
	if ! ask_yn "Write that line to ${rc}?"; then
		echo "Left ${rc} unchanged. For this shell:"
		echo "  ${line}"
		return 0
	fi
	if ensure_path_line "$rc" "$dir"; then
		PATH_RC="$rc"
		echo "Open a new terminal so the shell reads ${rc}."
	fi
}

hint_has() {
	local needle="$1"
	local hay="$2"
	case " ${hay} " in
		*" ${needle} "*) return 0 ;;
		*) return 1 ;;
	esac
}

session_hints() {
	local hints=""
	if command -v hyprctl >/dev/null 2>&1 || command -v Hyprland >/dev/null 2>&1; then
		hints="${hints} hypr"
	fi
	if command -v wayfire >/dev/null 2>&1; then
		hints="${hints} wayfire"
	fi
	if command -v labwc >/dev/null 2>&1; then
		hints="${hints} labwc"
	fi
	printf '%s' "${hints# }"
}

# Prints hypr, labwc, wayfire, or xdg.
# desktop and hints default to this machine when omitted.
# Pass empty strings to ignore the live session (tests).
choose_autostart_kind() {
	local home="$1"
	local distro="$2"
	local omarchy_flag="$3"
	local desktop="${4-__env__}"
	local hints="${5-__env__}"
	if [[ "$desktop" == "__env__" ]]; then
		desktop="${XDG_CURRENT_DESKTOP:-} ${XDG_SESSION_DESKTOP:-}"
	fi
	if [[ "$hints" == "__env__" ]]; then
		hints="$(session_hints)"
	fi
	if [[ "$omarchy_flag" == "1" || "$distro" == "omarchy" ]]; then
		printf 'hypr'
		return 0
	fi
	# The running session wins over a leftover config from another compositor.
	if [[ "$desktop" == *[Hh]ypr* ]]; then
		printf 'hypr'
		return 0
	fi
	if [[ "$desktop" == *[Ww]ayfire* ]]; then
		printf 'wayfire'
		return 0
	fi
	if [[ "$desktop" == *[Ll]abwc* ]]; then
		printf 'labwc'
		return 0
	fi
	if [[ -f "${home}/.config/hypr/hyprland.conf" || -f "${home}/.config/hypr/hyprland.lua" || -f "${home}/.config/hypr/autostart.conf" || -f "${home}/.config/hypr/autostart.lua" || -f "${home}/.config/omarchy/autostart.conf" ]]; then
		printf 'hypr'
		return 0
	fi
	if [[ -f "${home}/.config/wayfire.ini" ]]; then
		printf 'wayfire'
		return 0
	fi
	if [[ -d "${home}/.config/labwc" ]]; then
		printf 'labwc'
		return 0
	fi
	if hint_has hypr "$hints"; then
		printf 'hypr'
		return 0
	fi
	if hint_has wayfire "$hints"; then
		printf 'wayfire'
		return 0
	fi
	if hint_has labwc "$hints"; then
		printf 'labwc'
		return 0
	fi
	if [[ "$distro" == "pi" ]]; then
		printf 'labwc'
		return 0
	fi
	printf 'xdg'
}

install_labwc_autostart() {
	local home="$1"
	local bin="$2"
	local file="${home}/.config/labwc/autostart"
	local line="${bin} --fullscreen &"
	mkdir -p "$(dirname "$file")"
	if [[ -f "$file" ]] && grep -qF 'nova-letterbox' "$file"; then
		echo "Already present: ${file}"
		return 0
	fi
	touch "$file"
	printf '\n# nova-letterbox-begin\n# packaging/pi/labwc-autostart (full path, so PATH is not required)\n%s\n# nova-letterbox-end\n' "$line" >>"$file"
	echo "Updated ${file}"
}

install_wayfire_autostart() {
	local home="$1"
	local bin="$2"
	local file="${home}/.config/wayfire.ini"
	local line="nova_letterbox = ${bin} --fullscreen"
	local tmp
	mkdir -p "$(dirname "$file")"
	if [[ -f "$file" ]] && grep -qE '^[[:space:]]*nova_letterbox[[:space:]]*=' "$file"; then
		echo "Already present: ${file}"
		return 0
	fi
	if [[ ! -f "$file" ]]; then
		cat >"$file" <<EOF
[autostart]
${line}
EOF
		echo "Wrote ${file}"
		echo "Blanking: set dpms_timeout=-1 under [idle] if the panel sleeps. See docs/pi-kiosk.md."
		return 0
	fi
	if grep -q '^\[autostart\]' "$file"; then
		tmp="$(mktemp)"
		if awk -v line="$line" '
			BEGIN { done = 0 }
			/^\[autostart\]/ && !done {
				print
				print line
				done = 1
				next
			}
			{ print }
		' "$file" >"$tmp"; then
			mv "$tmp" "$file"
			echo "Updated ${file}"
			return 0
		fi
		rm -f "$tmp"
		echo "warning: could not update ${file}" >&2
		return 1
	fi
	printf '\n# nova-letterbox-begin\n[autostart]\n%s\n# nova-letterbox-end\n' "$line" >>"$file"
	echo "Updated ${file}"
}

install_xdg_autostart() {
	local home="$1"
	local bin="$2"
	local dest="${home}/.config/autostart/nova-letterbox.desktop"
	mkdir -p "$(dirname "$dest")"
	cat >"$dest" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=NOVA Letterbox
Comment=1920x480 telemetry letterbox
Exec=${bin} --fullscreen
Icon=nova-letterbox
Terminal=false
Categories=Utility;
StartupNotify=false
X-GNOME-Autostart-enabled=true
EOF
	echo "Autostart: ${dest}"
}

install_session_autostart() {
	local home="$1"
	local distro="$2"
	local desktop="${3-__env__}"
	local hints="${4-__env__}"
	local kind
	kind="$(choose_autostart_kind "$home" "$distro" "$OMARCHY" "$desktop" "$hints")"
	AUTOSTART_KIND="$kind"
	case "$kind" in
		hypr) install_hypr_autostart "$home" ;;
		labwc) install_labwc_autostart "$home" "$(cli_link)" ;;
		wayfire) install_wayfire_autostart "$home" "$(cli_link)" ;;
		xdg) install_xdg_autostart "$home" "$(cli_link)" ;;
		*)
			echo "warning: unknown autostart kind ${kind}" >&2
			return 1
			;;
	esac
}

autostart_blurb() {
	local kind="$1"
	case "$kind" in
		hypr)
			printf '%s' "Hyprland exec-once and a fullscreen rule on monitor HDMI-A-1"
			;;
		labwc)
			printf '%s' "labwc (~/.config/labwc/autostart). wayfire and the systemd user unit stay in docs/pi-kiosk.md"
			;;
		wayfire)
			printf '%s' "wayfire (~/.config/wayfire.ini). labwc and the systemd user unit stay in docs/pi-kiosk.md"
			;;
		xdg)
			printf '%s' "a desktop autostart entry at ~/.config/autostart/nova-letterbox.desktop"
			;;
		*)
			printf '%s' "login autostart"
			;;
	esac
}

wizard_autostart() {
	local distro="$1"
	local kind
	if [[ "$AUTOSTART" == "1" ]]; then
		echo "Autostart requested by --autostart."
		install_session_autostart "$HOME" "$distro"
		return 0
	fi
	kind="$(choose_autostart_kind "$HOME" "$distro" "$OMARCHY")"
	echo "Would enable: $(autostart_blurb "$kind")"
	if ! ask_yn "Enable autostart?"; then
		echo "Autostart left off. Re-run with --autostart to add it."
		return 0
	fi
	AUTOSTART=1
	install_session_autostart "$HOME" "$distro"
}

main() {
	local arch asset tag pm
	parse_args "$@"
	require_linux
	if os_release_is_omarchy /etc/os-release; then
		OMARCHY=1
	fi
	arch="$(detect_arch)"
	DISTRO="$(detect_distro /etc/os-release)"
	pm="$(package_manager_for_distro "$DISTRO")"
	if interactive_mode; then
		ui_step 1 "Welcome"
		wizard_welcome "$arch" "$DISTRO" "$pm"
		ui_step 2 "Dependencies"
		wizard_dependencies "$pm"
	fi
	command -v python3 >/dev/null 2>&1 || die "python3 is required to check the downloaded ELF"
	asset="$(asset_for_arch "$arch")"
	tag="$(normalize_version_tag "${NOVA_VERSION:-}")"
	begin_install_tmp

	if interactive_mode; then
		ui_step 3 "Download and install"
	fi
	echo "Installing NOVA Letterbox for ${arch}"
	echo "  binary: $(app_binary)"
	echo "  command: $(cli_link)"
	if [[ "${NOVA_FROM_SOURCE:-}" == "1" ]]; then
		install_from_source "$arch" "$_NOVA_INSTALL_TMP"
	else
		if ! download_asset "$tag" "$asset" "$_NOVA_INSTALL_TMP"; then
			auth_hint
			die "could not download ${asset}"
		fi
	fi
	[[ -s "$_NOVA_INSTALL_TMP" ]] || die "download was empty"
	verify_elf "$_NOVA_INSTALL_TMP" "$arch"
	install_payload "$_NOVA_INSTALL_TMP"
	verify_installed "$(app_binary)" "$arch"
	if [[ ! -L "$(cli_link)" ]]; then
		die "expected a symlink at $(cli_link)"
	fi
	write_icon
	write_desktop
	refresh_desktop_caches
	if interactive_mode; then
		ui_step 4 "PATH"
		wizard_path
		ui_step 5 "Autostart"
		wizard_autostart "$DISTRO"
	elif [[ "$AUTOSTART" == 1 ]]; then
		install_session_autostart "$HOME" "$DISTRO"
	fi
	if interactive_mode; then
		ui_step 6 "Done"
	fi
	print_next_steps
	end_install_tmp
	if [[ "$FULLSCREEN" == 1 ]]; then
		echo "Launching fullscreen."
		exec "$(cli_link)" --fullscreen
	fi
}

# A file sets BASH_SOURCE. Stdin (`curl … | bash`) leaves it unset, and
# `set -u` then rejects BASH_SOURCE[0]. Run main when executed or piped,
# and skip it when this file is sourced.
_nova_self="${BASH_SOURCE[0]:-}"
if [[ -z "$_nova_self" || "$_nova_self" == "$0" ]]; then
	main "$@"
fi
unset -v _nova_self
