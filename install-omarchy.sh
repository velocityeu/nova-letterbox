#!/usr/bin/env bash
# Omarchy (Arch + Hyprland) install. Same release binary and paths as install.sh.
# Pass --autostart for Hyprland login autostart and the 1920x480 window rule.
#
#   ./install-omarchy.sh
#   ./install-omarchy.sh --autostart
#   curl -fsSL .../install-omarchy.sh | bash -s -- --autostart
#
# Private repo: GH_TOKEN or `gh auth login` is required. See docs/omarchy.md.
set -euo pipefail

REPO="${NOVA_REPO:-velocityeu/nova-letterbox}"
REF="${NOVA_REF:-main}"

die() {
	echo "error: $*" >&2
	exit 1
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

# Print the path of install.sh: the sibling in a checkout, or a temp download.
locate_install_sh() {
	local self dir token tmp url
	self="${BASH_SOURCE[0]}"
	if [[ -n "$self" && -f "$self" ]]; then
		dir="$(cd "$(dirname "$self")" && pwd)"
		if [[ -f "${dir}/install.sh" ]]; then
			printf '%s' "${dir}/install.sh"
			return 0
		fi
	fi
	token="$(resolve_token)"
	tmp="$(mktemp)"
	url="https://api.github.com/repos/${REPO}/contents/install.sh?ref=${REF}"
	if [[ -n "$token" ]]; then
		curl -fsSL \
			-H "Authorization: Bearer ${token}" \
			-H "Accept: application/vnd.github.raw" \
			-o "$tmp" \
			"$url" || die "could not download install.sh (private repo: set GH_TOKEN or run gh auth login)"
	else
		curl -fsSL -o "$tmp" "https://raw.githubusercontent.com/${REPO}/${REF}/install.sh" \
			|| die "could not download install.sh. This repo is private; set GH_TOKEN or run gh auth login."
	fi
	chmod +x "$tmp"
	printf '%s' "$tmp"
}

script="$(locate_install_sh)"
exec bash "$script" --omarchy "$@"
