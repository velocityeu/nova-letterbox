#!/usr/bin/env bash
# Install the NOVA Letterbox Linux release binary.
#
#   curl -fsSL https://raw.githubusercontent.com/velocityeu/nova-letterbox/main/install.sh | bash
#
# This repository is private. Anonymous curl of this script and of Release
# assets fails until the repo is public. Export GH_TOKEN (or GITHUB_TOKEN),
# or log in with `gh auth login`, before running. See the README.
#
#   NOVA_VERSION=v0.1.0     pin a tag (0.1.0 is accepted; a leading v is added)
#   NOVA_VERSION=continuous rolling prerelease built from main
#   NOVA_FROM_SOURCE=1      export with a local Godot 4.3.stable instead
#   NOVA_REPO=owner/name    override the GitHub repo
set -euo pipefail

REPO="${NOVA_REPO:-velocityeu/nova-letterbox}"
ASSET_X86_64="nova-letterbox-linux-x86_64"
ASSET_ARM64="nova-letterbox-linux-arm64"

PREFIX=""
SYSTEM=0
FULLSCREEN=0
OMARCHY=0
AUTOSTART=0

die() {
	echo "error: $*" >&2
	exit 1
}

usage() {
	cat <<EOF
Usage: install.sh [--fullscreen] [--system] [--prefix DIR] [--omarchy] [--autostart]

Install the matching Linux release binary from the latest GitHub Release.
The binary is ~/.local/share/nova-letterbox/nova-letterbox.
~/.local/bin/nova-letterbox is a symlink to it. No sudo unless --system
cannot write /usr/local.

  --fullscreen   launch fullscreen when install finishes
  --system       use /usr/local/share and /usr/local/bin (sudo only if needed)
  --prefix DIR   use DIR/share and DIR/bin
  --omarchy      write the Omarchy desktop entry (also implied by /etc/os-release)
  --autostart    Hyprland login autostart and a 1920x480 fullscreen window rule
  -h, --help     show this help

Environment:
  GH_TOKEN or GITHUB_TOKEN   required for this private repo if \`gh\` is not logged in
  NOVA_VERSION               tag to download (v0.1.0, 0.1.0, or continuous)
  NOVA_FROM_SOURCE=1         build with Godot 4.3.stable instead of downloading
EOF
}

parse_args() {
	PREFIX=""
	SYSTEM=0
	FULLSCREEN=0
	OMARCHY=0
	AUTOSTART=0
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
}

main() {
	local arch asset tag tmp
	parse_args "$@"
	require_linux
	if os_release_is_omarchy /etc/os-release; then
		OMARCHY=1
	fi
	command -v python3 >/dev/null 2>&1 || die "python3 is required to check the downloaded ELF"
	arch="$(detect_arch)"
	asset="$(asset_for_arch "$arch")"
	tag="$(normalize_version_tag "${NOVA_VERSION:-}")"
	tmp="$(mktemp)"
	trap 'rm -f "$tmp"' EXIT

	echo "Installing NOVA Letterbox for ${arch}"
	echo "  binary: $(app_binary)"
	echo "  command: $(cli_link)"
	if [[ "${NOVA_FROM_SOURCE:-}" == "1" ]]; then
		install_from_source "$arch" "$tmp"
	else
		if ! download_asset "$tag" "$asset" "$tmp"; then
			auth_hint
			die "could not download ${asset}"
		fi
	fi
	[[ -s "$tmp" ]] || die "download was empty"
	verify_elf "$tmp" "$arch"
	install_payload "$tmp"
	verify_installed "$(app_binary)" "$arch"
	if [[ ! -L "$(cli_link)" ]]; then
		die "expected a symlink at $(cli_link)"
	fi
	write_icon
	write_desktop
	refresh_desktop_caches
	if [[ "$AUTOSTART" == 1 ]]; then
		install_hypr_autostart "$HOME"
	fi
	print_next_steps
	rm -f "$tmp"
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
