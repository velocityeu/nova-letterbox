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

Install with the README one-liner. This repo is private, so GH_TOKEN or gh auth login is required.
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

install.sh uses the latest stable release when one exists, and falls back to this tag otherwise.
Push a v* tag for a stable release.
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
