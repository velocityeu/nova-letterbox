#!/usr/bin/env bash
# Omarchy (Arch + Hyprland) install. Same release binary and paths as install.sh.
# A terminal runs the text wizard (dependencies, PATH, autostart question).
# Pass --autostart to enable Hyprland login autostart without asking.
# --yes, NOVA_NONINTERACTIVE=1, or a pipe skips the wizard.
#
#   ./install-omarchy.sh
#   ./install-omarchy.sh --autostart
#   curl -fsSL https://raw.githubusercontent.com/velocityeu/nova-letterbox/main/install-omarchy.sh | bash -s -- --autostart
#
# Remove the same install (user or /usr/local) with:
#   ./install-omarchy.sh --uninstall
#   ./install-omarchy.sh --uninstall --yes
# That runs uninstall.sh. See the README.
#
# The repository is public. GH_TOKEN or `gh auth login` is optional: use it
# when the GitHub API rate limit (60 anonymous requests/hour) is hit, or when
# this is a private fork. See docs/omarchy.md.
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

# Print the path of a sibling script, or a temp download of that file.
locate_repo_script() {
	local name="$1"
	local self dir token tmp url
	# Unset when this file is piped to bash. Do not touch BASH_SOURCE[0] then.
	self="${BASH_SOURCE[0]:-}"
	if [[ -n "$self" && -f "$self" ]]; then
		dir="$(cd "$(dirname "$self")" && pwd)"
		if [[ -f "${dir}/${name}" ]]; then
			printf '%s' "${dir}/${name}"
			return 0
		fi
	fi
	token="$(resolve_token)"
	tmp="$(mktemp)"
	url="https://api.github.com/repos/${REPO}/contents/${name}?ref=${REF}"
	if [[ -n "$token" ]]; then
		curl -fsSL \
			-H "Authorization: Bearer ${token}" \
			-H "Accept: application/vnd.github.raw" \
			-o "$tmp" \
			"$url" || die "could not download ${name}. Check GH_TOKEN or gh auth for ${REPO}. A public install does not need a token."
	else
		curl -fsSL -o "$tmp" "https://raw.githubusercontent.com/${REPO}/${REF}/${name}" \
			|| die "could not download ${name} from raw.githubusercontent.com. Check the network. A private fork needs GH_TOKEN or gh auth login."
	fi
	chmod +x "$tmp"
	printf '%s' "$tmp"
}

forward=()
uninstall=0
for arg in "$@"; do
	if [[ "$arg" == "--uninstall" ]]; then
		uninstall=1
		continue
	fi
	forward+=("$arg")
done

if [[ "$uninstall" == 1 ]]; then
	script="$(locate_repo_script uninstall.sh)"
	if [[ ${#forward[@]} -eq 0 ]]; then
		exec bash "$script"
	fi
	exec bash "$script" "${forward[@]}"
fi

script="$(locate_repo_script install.sh)"
if [[ ${#forward[@]} -eq 0 ]]; then
	exec bash "$script" --omarchy
fi
exec bash "$script" --omarchy "${forward[@]}"
