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
Default location is ~/.local/bin/nova-letterbox. No sudo unless --system
cannot write /usr/local/bin.

  --fullscreen   launch the installed binary fullscreen when install finishes
  --system       install to /usr/local/bin (sudo only if that directory is not writable)
  --prefix DIR   install to DIR/bin/nova-letterbox
  --omarchy      also write an Omarchy/Hyprland desktop entry
  --autostart    with --omarchy, add o.launch_on_start to ~/.config/hypr/autostart.lua
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
			--autostart) AUTOSTART=1; OMARCHY=1 ;;
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

place_binary() {
	local src="$1"
	local dest="$2"
	local dir
	dir="$(dirname "$dest")"
	if [[ ! -d "$dir" ]]; then
		if ! mkdir -p "$dir"; then
			[[ "$SYSTEM" == 1 ]] || die "cannot create ${dir}"
			sudo mkdir -p "$dir"
		fi
	fi
	if [[ -w "$dir" ]]; then
		install -m 0755 "$src" "$dest"
	elif [[ "$SYSTEM" == 1 ]]; then
		echo "Copying to ${dest} with sudo."
		sudo install -m 0755 "$src" "$dest"
	else
		die "cannot write ${dest}. Use a writable --prefix, or --system."
	fi
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

install_omarchy_extras() {
	local dest="$1"
	local apps="${XDG_DATA_HOME:-${HOME}/.local/share}/applications"
	local autostart="${HOME}/.config/hypr/autostart.lua"
	local line
	mkdir -p "$apps"
	cat >"${apps}/nova-letterbox.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=NOVA Letterbox
Comment=1920x480 telemetry letterbox
Exec=${dest} --fullscreen
Terminal=false
Categories=Utility;
StartupNotify=false
EOF
	echo "Desktop entry: ${apps}/nova-letterbox.desktop"
	line="o.launch_on_start(\"${dest} --fullscreen\")"
	if [[ "$AUTOSTART" == 1 ]]; then
		mkdir -p "$(dirname "$autostart")"
		if [[ -f "$autostart" ]] && grep -qF 'nova-letterbox' "$autostart"; then
			echo "Autostart already mentions nova-letterbox: ${autostart}"
		else
			if [[ ! -f "$autostart" ]]; then
				printf '%s\n' '-- Extra autostart processes.' >"$autostart"
			fi
			printf '\n%s\n' "$line" >>"$autostart"
			echo "Added Hyprland autostart: ${autostart}"
			echo "Reload Hyprland, or log in again, to start the letterbox."
		fi
	else
		echo "Login autostart was not changed. Add this to ~/.config/hypr/autostart.lua, or re-run with --autostart:"
		echo "  ${line}"
	fi
}

print_next_steps() {
	local dest="$1"
	cat <<EOF

Installed: ${dest}

Fullscreen:
  ${dest} --fullscreen

Engine health check (no window):
  ${dest} --version

Letterbox version line, then exit:
  NOVA_PRINT_VERSION=1 ${dest}

Keys, with the window focused: 1 Simple, 2 Complete, Tab toggles.
The project uses the GL Compatibility renderer.

Pi HDMI 1920×480, blanking, labwc/wayfire, and a systemd user unit:
  https://github.com/${REPO}/blob/main/docs/pi-kiosk.md
EOF
	if os_release_is_omarchy /etc/os-release; then
		if [[ "$OMARCHY" != 1 ]]; then
			cat <<EOF

Omarchy detected. For a desktop entry and optional Hyprland autostart, see
  https://github.com/${REPO}/blob/main/docs/omarchy.md
or run install-omarchy.sh (same binary, plus the Omarchy files).
EOF
		fi
	fi
	case ":${PATH}:" in
		*":$(dirname "$dest"):"*) ;;
		*)
			echo
			echo "That directory is not on PATH. For this shell:"
			echo "  export PATH=\"$(dirname "$dest"):\$PATH\""
			;;
	esac
}

main() {
	local arch asset dest tag tmp prefix
	parse_args "$@"
	require_linux
	command -v python3 >/dev/null 2>&1 || die "python3 is required to check the downloaded ELF"
	arch="$(detect_arch)"
	asset="$(asset_for_arch "$arch")"
	prefix="$(resolve_prefix)"
	dest="${prefix}/bin/nova-letterbox"
	tag="$(normalize_version_tag "${NOVA_VERSION:-}")"
	tmp="$(mktemp)"
	trap 'rm -f "$tmp"' EXIT

	echo "Installing NOVA Letterbox for ${arch} to ${dest}"
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
	place_binary "$tmp" "$dest"
	verify_installed "$dest" "$arch"
	if [[ "$OMARCHY" == 1 ]]; then
		install_omarchy_extras "$dest"
	fi
	print_next_steps "$dest"
	rm -f "$tmp"
	if [[ "$FULLSCREEN" == 1 ]]; then
		echo "Launching fullscreen."
		exec "$dest" --fullscreen
	fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
fi
