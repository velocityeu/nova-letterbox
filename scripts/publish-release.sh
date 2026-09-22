#!/usr/bin/env bash
# Upload dist/nova-letterbox-linux-* to a GitHub Release.
# Tag pushes (v*) become the latest stable release.
# Any other run replaces the continuous prerelease.
# Requires GH_TOKEN and the GitHub Actions env (GITHUB_REF_TYPE, GITHUB_SHA, GITHUB_REPOSITORY).
set -euo pipefail

repo="${GITHUB_REPOSITORY:?}"
sha="${GITHUB_SHA:?}"
ref_type="${GITHUB_REF_TYPE:?}"
x86="dist/nova-letterbox-linux-x86_64"
arm="dist/nova-letterbox-linux-arm64"
notes="$(mktemp)"
trap 'rm -f "$notes"' EXIT

[[ -f "$x86" && -f "$arm" ]] || { echo "error: missing dist binaries" >&2; exit 1; }

if [[ "$ref_type" == "tag" ]]; then
	tag="${GITHUB_REF_NAME:?}"
	[[ "$tag" == v* ]] || { echo "error: tag ${tag} must start with v" >&2; exit 1; }
	cat >"$notes" <<EOF
Stable Linux release. Both binaries embed the PCK.

- nova-letterbox-linux-x86_64
- nova-letterbox-linux-arm64

The repository is public. Install with:

  curl -fsSL https://raw.githubusercontent.com/velocityeu/nova-letterbox/main/install.sh | bash

Pin this release with NOVA_VERSION=${tag}. If the anonymous GitHub API rate limit (60/hour) blocks the latest-release lookup, run gh auth login or export GH_TOKEN. A token is optional for the public repository.
EOF
	if gh release view "$tag" --repo "$repo" >/dev/null 2>&1; then
		gh release upload "$tag" "$x86" "$arm" --repo "$repo" --clobber
		gh release edit "$tag" --repo "$repo" --latest --title "NOVA Letterbox ${tag}" --notes-file "$notes"
	else
		gh release create "$tag" "$x86" "$arm" \
			--repo "$repo" \
			--verify-tag \
			--target "$sha" \
			--latest \
			--title "NOVA Letterbox ${tag}" \
			--notes-file "$notes"
	fi
else
	tag="continuous"
	cat >"$notes" <<EOF
Rolling build from main. This is a prerelease, not the latest stable release.

- nova-letterbox-linux-x86_64
- nova-letterbox-linux-arm64

install.sh uses the latest stable release when one exists (v0.1.0 is the current stable), and falls back to this tag otherwise.
The repository is public:

  curl -fsSL https://raw.githubusercontent.com/velocityeu/nova-letterbox/main/install.sh | NOVA_VERSION=continuous bash

Push a v* tag for a stable release. A token is optional; use gh auth login or GH_TOKEN if the anonymous API rate limit (60/hour) blocks the lookup.
EOF
	if gh release view "$tag" --repo "$repo" >/dev/null 2>&1; then
		gh release delete "$tag" --repo "$repo" --yes --cleanup-tag
	fi
	gh release create "$tag" "$x86" "$arm" \
		--repo "$repo" \
		--target "$sha" \
		--prerelease \
		--latest=false \
		--title "NOVA Letterbox continuous" \
		--notes-file "$notes"
fi

echo "Published ${tag}"
