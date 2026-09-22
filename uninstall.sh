#!/usr/bin/env bash
# Remove a NOVA Letterbox install and the files the installer added.
#
#   ./uninstall.sh
#   ./uninstall.sh --yes
#   ./uninstall.sh --system
#   ./install-omarchy.sh --uninstall
#
# A terminal asks before removing anything, before sudo, before shell
# startup edits, and before deleting Godot app data. --yes,
# NOVA_NONINTERACTIVE=1, or a pipe skips those questions and removes the
# install, autostart lines, installer PATH blocks, and Godot app data.
#
# An unmarked export PATH="$HOME/.local/bin:$PATH" is not removed unless
# you accept that prompt. That directory is shared with other programs.
# The installer writes its own line inside a nova-letterbox-path block;
# that block is removed with the PATH prompt, or with --yes.
#
# Linux PC, Raspberry Pi, and Omarchy use this same script.
set -euo pipefail

YES=0
SYSTEM=0
USER_ONLY=0
PREFIX=""
SUDO_OK=0
ONLYBIN=""
REMOVE_USER=0
REMOVE_SYSTEM=0
REMOVE_CUSTOM=""

REMOVED=()
LEFT=()
FAILED=()

die() {
	echo "error: $*" >&2
	exit 1
}

usage() {
	cat <<EOF
Usage: uninstall.sh [--system] [--user] [--prefix DIR] [--yes]

Remove NOVA Letterbox and the autostart lines, desktop entry, and icons
the installer added. The default removes a user install under ~/.local.
If a system install is also present in /usr/local, it is removed too.

A terminal asks before each destructive step. --yes, NOVA_NONINTERACTIVE=1,
or a pipe skips the questions.

  --system       remove /usr/local only (sudo when that tree is not writable)
  --user         remove the current user's install only
  --prefix DIR   remove DIR/share and DIR/bin only
  --yes          non-interactive removal, including installer PATH blocks
  -h, --help     show this help

--system, --user, and --prefix cannot be combined. Autostart files live in
the home directory and are cleaned for whichever install is being removed.
If another install is left in place, only lines that name the removed
command path are edited. A generic Hyprland exec-once stays so the copy
that is still installed can keep starting.

Shell startup files (~/.bashrc, ~/.zshrc, ~/.profile) lose only the
nova-letterbox-path block and export lines that contain nova-letterbox.
An unmarked export of ~/.local/bin is offered separately and is kept when
you say no, or when --yes is set.

Not removed: distro packages, Hyprland monitor modes, Pi blanking, and a
running nova-letterbox process (quit that window yourself).

Environment:
  NOVA_NONINTERACTIVE=1   same as --yes
EOF
}

note_removed() {
	REMOVED+=("$1")
}

note_left() {
	LEFT+=("$1")
}

note_failed() {
	FAILED+=("$1")
	echo "failed: $*" >&2
}

parse_args() {
	PREFIX=""
	SYSTEM=0
	USER_ONLY=0
	YES=0
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--system) SYSTEM=1 ;;
			--user) USER_ONLY=1 ;;
			--prefix)
				[[ $# -ge 2 ]] || die "--prefix needs a directory"
				PREFIX="$2"
				shift
				;;
			--prefix=*)
				PREFIX="${1#--prefix=}"
				[[ -n "$PREFIX" ]] || die "--prefix needs a directory"
				;;
			--yes) YES=1 ;;
			-h|--help) usage; exit 0 ;;
			*) die "unknown argument: $1 (try --help)" ;;
		esac
		shift
	done
	local chosen=0
	[[ -n "$PREFIX" ]] && chosen=$((chosen + 1))
	[[ "$SYSTEM" == 1 ]] && chosen=$((chosen + 1))
	[[ "$USER_ONLY" == 1 ]] && chosen=$((chosen + 1))
	if [[ "$chosen" -gt 1 ]]; then
		die "--system, --user, and --prefix cannot be combined"
	fi
	if [[ -n "$PREFIX" ]]; then
		validate_prefix "$PREFIX"
	fi
}

validate_prefix() {
	local prefix="$1"
	[[ "$prefix" == /* ]] || die "--prefix must be an absolute path"
	case "$prefix" in
		*..*) die "refusing --prefix ${prefix}" ;;
		/|/usr|/bin|/etc|/home|/root|/var|/tmp|/opt)
			die "refusing --prefix ${prefix}"
			;;
	esac
}

require_linux() {
	local os
	os="$(uname -s)"
	if [[ "$os" != "Linux" ]]; then
		die "NOVA Letterbox uninstalls on Linux only (this machine reports ${os})."
	fi
}

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

read_reply() {
	local prompt="$1"
	local reply=""
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

# Default is no.
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

user_share() {
	printf '%s' "${XDG_DATA_HOME:-${HOME}/.local/share}"
}

user_prefix() {
	printf '%s' "${HOME}/.local"
}

path_in_home() {
	local path="$1"
	local home="${HOME%/}"
	[[ -n "$home" && "$home" != "/" ]] || return 1
	[[ "$path" == "$home" || "$path" == "$home"/* ]]
}

# Prints icon paths under one share, one per line.
list_icons() {
	local share="$1"
	local root="${share}/icons/hicolor"
	[[ -d "$root" ]] || return 0
	find "$root" -mindepth 1 \( -type f -o -type l \) \
		\( -name 'nova-letterbox' -o -name 'nova-letterbox.*' \) -print
}

payload_present() {
	local prefix="$1"
	local share="$2"
	local icon=""
	if [[ -e "${share}/nova-letterbox" || -L "${share}/nova-letterbox" ]]; then
		return 0
	fi
	if [[ -e "${prefix}/bin/nova-letterbox" || -L "${prefix}/bin/nova-letterbox" ]]; then
		return 0
	fi
	if [[ -e "${share}/applications/nova-letterbox.desktop" ]]; then
		return 0
	fi
	icon="$(list_icons "$share" | head -n 1 || true)"
	[[ -n "$icon" ]]
}

user_install_present() {
	payload_present "$(user_prefix)" "$(user_share)"
}

system_install_present() {
	payload_present /usr/local /usr/local/share
}

decide_scope() {
	REMOVE_USER=0
	REMOVE_SYSTEM=0
	REMOVE_CUSTOM=""
	ONLYBIN=""
	if [[ -n "$PREFIX" ]]; then
		if [[ "$PREFIX" == "$(user_prefix)" ]]; then
			REMOVE_USER=1
		elif [[ "$PREFIX" == /usr/local ]]; then
			REMOVE_SYSTEM=1
		else
			REMOVE_CUSTOM="$PREFIX"
		fi
	elif [[ "$SYSTEM" == 1 ]]; then
		REMOVE_SYSTEM=1
	elif [[ "$USER_ONLY" == 1 ]]; then
		REMOVE_USER=1
	else
		REMOVE_USER=1
		if system_install_present; then
			REMOVE_SYSTEM=1
		fi
	fi

	local other=0
	if [[ "$REMOVE_USER" == 0 ]] && user_install_present; then
		other=1
	fi
	if [[ "$REMOVE_SYSTEM" == 0 ]] && system_install_present; then
		other=1
	fi
	if [[ "$other" != 1 ]]; then
		return 0
	fi
	if [[ -n "$REMOVE_CUSTOM" ]]; then
		ONLYBIN="${REMOVE_CUSTOM}/bin"
	elif [[ "$REMOVE_USER" == 1 ]]; then
		ONLYBIN="$(user_prefix)/bin"
	elif [[ "$REMOVE_SYSTEM" == 1 ]]; then
		ONLYBIN="/usr/local/bin"
	fi
}

# kind is path, wayfire, labwc, hypr-conf, or hypr-lua.
# onlybin empty: drop every installer block and known launch line.
# onlybin set: drop a block or line only when it names that bin directory.
filter_config() {
	local kind="$1"
	local onlybin="$2"
	local file="$3"
	awk -v kind="$kind" -v onlybin="$onlybin" '
		function is_begin(s) {
			return s ~ /nova-letterbox-begin[[:space:]]*$/ || s ~ /nova-letterbox-path-begin[[:space:]]*$/
		}
		function is_end(s) {
			return s ~ /nova-letterbox-end[[:space:]]*$/ || s ~ /nova-letterbox-path-end[[:space:]]*$/
		}
		function has_bin(s, b,    pos, rest) {
			if (b == "") return 0
			pos = index(s, b)
			if (pos == 0) return 0
			rest = substr(s, pos + length(b), 1)
			return (rest == "" || rest == ":" || rest == "/" || rest == " ")
		}
		function mentions_nova(s) {
			return index(s, "nova-letterbox") > 0 || index(s, "nova_letterbox") > 0 || index(s, "NOVA Letterbox") > 0
		}
		function emit(s) {
			n++
			lines[n] = s
		}
		function pop_blank() {
			if (n >= 1 && lines[n] ~ /^[[:space:]]*$/) n--
		}
		function emit_text(buf,    m, i, parts) {
			if (buf == "") return
			m = split(buf, parts, "\n")
			for (i = 1; i < m; i++) emit(parts[i])
		}
		function drop_plain(s) {
			if (onlybin != "" && !has_bin(s, onlybin)) return 0
			if (kind == "path") {
				if (s ~ /^[[:space:]]*export[[:space:]]+PATH=/ && index(s, "nova-letterbox") > 0) return 1
				if (onlybin != "" && s ~ /^[[:space:]]*export[[:space:]]+PATH=/ && has_bin(s, onlybin)) return 1
				return 0
			}
			if (kind == "wayfire") {
				return s ~ /^[[:space:]]*nova_letterbox[[:space:]]*=/
			}
			if (kind == "labwc") {
				return s ~ /(^|[[:space:]/])nova-letterbox([[:space:]]|$)/ && s !~ /^[[:space:]]*#/
			}
			if (kind == "hypr-conf") {
				return s ~ /^[[:space:]]*exec-once[[:space:]]*=/ && index(s, "nova-letterbox") > 0
			}
			if (kind == "hypr-lua") {
				if (index(s, "launch_on_start") > 0 && index(s, "nova-letterbox") > 0) return 1
				if (index(s, "o.window") > 0 && index(s, "NOVA Letterbox") > 0) return 1
				return 0
			}
			return 0
		}
		function drop_block(buf) {
			if (onlybin == "") return 1
			return has_bin(buf, onlybin)
		}
		function drop_rule(buf) {
			if (!mentions_nova(buf)) return 0
			if (onlybin == "") return 1
			return has_bin(buf, onlybin)
		}
		BEGIN { inblock = 0; inrule = 0; hold = ""; n = 0 }
		{
			if (inblock) {
				hold = hold $0 "\n"
				if (is_end($0)) {
					inblock = 0
					if (drop_block(hold)) pop_blank()
					else emit_text(hold)
					hold = ""
				}
				next
			}
			if (inrule) {
				hold = hold $0 "\n"
				if ($0 ~ /^[[:space:]]*}[[:space:]]*$/) {
					inrule = 0
					if (!drop_rule(hold)) emit_text(hold)
					hold = ""
				}
				next
			}
			if (is_begin($0)) {
				inblock = 1
				hold = $0 "\n"
				next
			}
			if (kind == "hypr-conf" && $0 ~ /^[[:space:]]*windowrule[[:space:]]*\{[[:space:]]*$/) {
				inrule = 1
				hold = $0 "\n"
				next
			}
			if (drop_plain($0)) next
			emit($0)
		}
		END {
			if (hold != "") emit_text(hold)
			for (i = 1; i <= n; i++) print lines[i]
		}
	' "$file"
}

config_kind() {
	local file="$1"
	case "$file" in
		*/wayfire.ini) printf 'wayfire' ;;
		*/labwc/autostart) printf 'labwc' ;;
		*.lua) printf 'hypr-lua' ;;
		*.bashrc|*.zshrc|*.profile|*.bash_profile) printf 'path' ;;
		*) printf 'hypr-conf' ;;
	esac
}

allow_delete_file() {
	local file="$1"
	case "$file" in
		*.bashrc|*.zshrc|*.profile|*.bash_profile) return 1 ;;
		*/hyprland.conf|*/hyprland.lua|*/looknfeel.lua|*/autostart.lua) return 1 ;;
		*) return 0 ;;
	esac
}

file_mentions_nova() {
	local file="$1"
	grep -qE 'nova-letterbox|nova_letterbox|NOVA Letterbox' "$file"
}

disposable_content() {
	local tmp="$1"
	local kind="$2"
	if [[ "$kind" == "wayfire" ]]; then
		if grep -E -v '^[[:space:]]*$|^[[:space:]]*[#;]' "$tmp" \
			| grep -E -v '^[[:space:]]*\[[^]]+\][[:space:]]*$' \
			| grep -q .; then
			return 1
		fi
		return 0
	fi
	if grep -q '[^[:space:]]' "$tmp"; then
		return 1
	fi
	return 0
}

rewrite_config() {
	local file="$1"
	local onlybin="$2"
	local kind tmp
	if [[ -d "$file" ]]; then
		note_left "${file} is a directory; not edited"
		return 0
	fi
	[[ -f "$file" ]] || return 0
	if ! file_mentions_nova "$file"; then
		return 0
	fi
	kind="$(config_kind "$file")"
	tmp="$(mktemp)"
	if ! filter_config "$kind" "$onlybin" "$file" >"$tmp"; then
		rm -f "$tmp"
		note_failed "$file"
		return 1
	fi
	if cmp -s "$file" "$tmp"; then
		if [[ -n "$onlybin" ]]; then
			note_left "${file} kept lines that do not name ${onlybin} (another install is still present)"
		else
			note_left "${file} still mentions NOVA Letterbox; no marked block or known launch line was removed"
		fi
		rm -f "$tmp"
		return 0
	fi
	# Session files stay on disk even if the installer block was the only text.
	# Autostart snippets the installer created can disappear once they are empty.
	if allow_delete_file "$file" && disposable_content "$tmp" "$kind"; then
		rm -f "$tmp"
		if ! path_in_home "$file"; then
			note_failed "$file"
			return 1
		fi
		rm -f -- "$file" || {
			note_failed "$file"
			return 1
		}
		if [[ -e "$file" ]]; then
			note_failed "$file"
			return 1
		fi
		note_removed "$file"
		return 0
	fi
	if [[ ! -w "$file" ]]; then
		rm -f "$tmp"
		note_failed "$file"
		return 1
	fi
	cat "$tmp" >"$file"
	rm -f "$tmp"
	note_removed "updated ${file}"
	if [[ -f "$file" ]] && file_mentions_nova "$file"; then
		note_left "${file} still mentions NOVA Letterbox after the installer lines were removed"
	fi
	return 0
}

autostart_files() {
	local c="${HOME}/.config"
	printf '%s\n' \
		"${c}/hypr/autostart.conf" \
		"${c}/hypr/hyprland.conf" \
		"${c}/hypr/autostart.lua" \
		"${c}/hypr/looknfeel.lua" \
		"${c}/hypr/hyprland.lua" \
		"${c}/omarchy/autostart.conf" \
		"${c}/omarchy/hypr/autostart.conf" \
		"${c}/labwc/autostart" \
		"${c}/wayfire.ini"
}

rc_files() {
	printf '%s\n' \
		"${HOME}/.bashrc" \
		"${HOME}/.zshrc" \
		"${HOME}/.profile"
}

safe_path() {
	local path="$1"
	[[ -n "$path" && "$path" == /* ]] || return 1
	case "$path" in
		*"/../"*|*/..|../*) return 1 ;;
	esac
	return 0
}

assert_app_dir() {
	local path="$1"
	local share="$2"
	safe_path "$path" || return 1
	safe_path "$share" || return 1
	[[ "$path" == "${share}/nova-letterbox" ]] || return 1
	case "$share" in
		/|/usr|/bin|/etc|/home|/root|/var|/tmp|/opt|/usr/local) return 1 ;;
	esac
	return 0
}

assert_cli() {
	local path="$1"
	local prefix="$2"
	safe_path "$path" || return 1
	[[ "$path" == "${prefix}/bin/nova-letterbox" ]] || return 1
	case "$prefix" in
		/|/usr|/bin|/etc|/home|/root|/var|/tmp|/opt) return 1 ;;
	esac
	return 0
}

assert_icon() {
	local path="$1"
	local share="$2"
	local base
	safe_path "$path" || return 1
	[[ "$path" == "${share}/icons/"* ]] || return 1
	base="$(basename "$path")"
	[[ "$base" == "nova-letterbox" || "$base" == nova-letterbox.* ]] || return 1
	return 0
}

privilege_needed() {
	local path="$1"
	local parent
	[[ -e "$path" || -L "$path" ]] || return 1
	path_in_home "$path" && return 1
	parent="$(dirname "$path")"
	if [[ ! -w "$parent" || ! -x "$parent" ]]; then
		return 0
	fi
	if [[ -d "$path" && ! -L "$path" && ! -w "$path" ]]; then
		return 0
	fi
	return 1
}

path_still_there() {
	local path="$1"
	[[ -e "$path" || -L "$path" ]]
}

try_rm() {
	local path="$1"
	local mode="$2"
	if [[ "$mode" == "tree" ]]; then
		rm -rf -- "$path"
	else
		rm -f -- "$path"
	fi
}

remove_path() {
	local path="$1"
	local mode="$2"
	if path_in_home "$path"; then
		try_rm "$path" "$mode" || true
		if path_still_there "$path"; then
			note_failed "$path"
			return 1
		fi
		note_removed "$path"
		return 0
	fi
	try_rm "$path" "$mode" || true
	if path_still_there "$path"; then
		if [[ "$SUDO_OK" != 1 ]]; then
			note_left "${path} (not removed; sudo was not used)"
			return 0
		fi
		if ! command -v sudo >/dev/null 2>&1; then
			note_failed "${path} (sudo is not available)"
			return 1
		fi
		echo "Using sudo to remove ${path}"
		if [[ "$mode" == "tree" ]]; then
			sudo rm -rf -- "$path" || true
		else
			sudo rm -f -- "$path" || true
		fi
	fi
	if path_still_there "$path"; then
		note_failed "$path"
		return 1
	fi
	note_removed "$path"
	return 0
}

remove_app_dir() {
	local share="$1"
	local dir="${share}/nova-letterbox"
	[[ -e "$dir" || -L "$dir" ]] || return 0
	if ! assert_app_dir "$dir" "$share"; then
		note_failed "${dir} (refusing an unexpected install path)"
		return 1
	fi
	remove_path "$dir" tree
}

remove_cli() {
	local prefix="$1"
	local link="${prefix}/bin/nova-letterbox"
	[[ -e "$link" || -L "$link" ]] || return 0
	if ! assert_cli "$link" "$prefix"; then
		note_failed "${link} (refusing an unexpected command path)"
		return 1
	fi
	if [[ -d "$link" && ! -L "$link" ]]; then
		note_failed "${link} is a directory"
		return 1
	fi
	remove_path "$link" file
}

remove_desktop_file() {
	local path="$1"
	[[ -e "$path" || -L "$path" ]] || return 0
	if [[ -d "$path" && ! -L "$path" ]]; then
		note_failed "${path} is a directory"
		return 1
	fi
	remove_path "$path" file
}

remove_icons() {
	local share="$1"
	local icon
	while IFS= read -r icon; do
		[[ -n "$icon" ]] || continue
		if ! assert_icon "$icon" "$share"; then
			note_failed "${icon} (refusing an unexpected icon path)"
			continue
		fi
		remove_path "$icon" file || true
		if [[ ! -e "$icon" && ! -L "$icon" ]]; then
			rmdir "$(dirname "$icon")" 2>/dev/null || true
		fi
	done < <(list_icons "$share")
}

remove_prefix_payload() {
	local prefix="$1"
	local share="$2"
	remove_cli "$prefix" || true
	remove_app_dir "$share" || true
	remove_desktop_file "${share}/applications/nova-letterbox.desktop" || true
	remove_icons "$share" || true
}

refresh_caches() {
	local share="$1"
	if command -v update-desktop-database >/dev/null 2>&1 && [[ -d "${share}/applications" ]]; then
		update-desktop-database "${share}/applications" >/dev/null 2>&1 || true
	fi
	if command -v gtk-update-icon-cache >/dev/null 2>&1 && [[ -d "${share}/icons/hicolor" ]]; then
		gtk-update-icon-cache -f -t "${share}/icons/hicolor" >/dev/null 2>&1 || true
	fi
}

godot_data_dir() {
	printf '%s/godot/app_userdata/NOVA Letterbox' "$(user_share)"
}

systemd_unit() {
	printf '%s/.config/systemd/user/nova-letterbox.service' "$HOME"
}

real_home() {
	getent passwd "$(id -u)" 2>/dev/null | awk -F: '{print $6; exit}'
}

stop_user_service() {
	local unit home_now
	unit="$(systemd_unit)"
	[[ -f "$unit" ]] || return 0
	home_now="$(real_home)"
	[[ -n "$home_now" && "$HOME" == "$home_now" ]] || return 0
	command -v systemctl >/dev/null 2>&1 || return 0
	systemctl --user disable --now nova-letterbox.service >/dev/null 2>&1 || true
	systemctl --user daemon-reload >/dev/null 2>&1 || true
}

remove_systemd_unit() {
	local unit="$1"
	local link
	[[ -f "$unit" ]] || return 0
	if ! grep -q 'nova-letterbox' "$unit"; then
		note_left "${unit} does not look like the NOVA Letterbox unit; left in place"
		return 0
	fi
	if [[ -n "$ONLYBIN" ]] && ! grep -qF "$ONLYBIN" "$unit"; then
		note_left "${unit} kept because it does not start the removed command"
		return 0
	fi
	stop_user_service
	remove_path "$unit" file || true
	if [[ -d "${HOME}/.config/systemd/user" ]]; then
		while IFS= read -r link; do
			[[ -n "$link" ]] || continue
			case "$link" in
				"${HOME}/.config/systemd/user/"*) ;;
				*) continue ;;
			esac
			[[ "$(basename "$link")" == "nova-letterbox.service" ]] || continue
			remove_path "$link" file || true
		done < <(find "${HOME}/.config/systemd/user" -type l -name 'nova-letterbox.service' -print)
	fi
}

xdg_autostart() {
	printf '%s/.config/autostart/nova-letterbox.desktop' "$HOME"
}

remove_xdg_autostart() {
	local dest
	dest="$(xdg_autostart)"
	[[ -e "$dest" || -L "$dest" ]] || return 0
	if [[ -n "$ONLYBIN" ]] && ! grep -qF "$ONLYBIN" "$dest" 2>/dev/null; then
		note_left "${dest} kept because another install is still present"
		return 0
	fi
	if ! grep -qE 'nova-letterbox|NOVA Letterbox' "$dest" 2>/dev/null; then
		note_left "${dest} does not look like NOVA Letterbox; left in place"
		return 0
	fi
	remove_path "$dest" file || true
}

exact_export_line() {
	local dir="$1"
	printf 'export PATH="%s:$PATH"' "$dir"
}

rc_has_safe_path() {
	local file="$1"
	[[ -f "$file" ]] || return 1
	if grep -qE 'nova-letterbox-path-begin|nova-letterbox-path-end' "$file"; then
		return 0
	fi
	grep -qE '^[[:space:]]*export[[:space:]]+PATH=.*nova-letterbox' "$file"
}

bins_for_exact_lines() {
	if [[ "$REMOVE_USER" == 1 ]]; then
		printf '%s\n' "$(user_prefix)/bin"
	fi
	if [[ -n "$REMOVE_CUSTOM" && "$REMOVE_CUSTOM" != /usr/local ]]; then
		printf '%s\n' "${REMOVE_CUSTOM}/bin"
	fi
}

line_is_exact_export() {
	local row="$1"
	local dir="$2"
	local line trimmed
	line="$(exact_export_line "$dir")"
	trimmed="${row%"${row##*[![:space:]]}"}"
	[[ "$trimmed" == "$line" ]]
}

marker_begin_line() {
	local row="$1"
	local begin_re='nova-letterbox-begin[[:space:]]*$'
	local path_re='nova-letterbox-path-begin[[:space:]]*$'
	[[ "$row" =~ $begin_re || "$row" =~ $path_re ]]
}

marker_end_line() {
	local row="$1"
	local end_re='nova-letterbox-end[[:space:]]*$'
	local path_re='nova-letterbox-path-end[[:space:]]*$'
	[[ "$row" =~ $end_re || "$row" =~ $path_re ]]
}

# True when the installer's exact export is present and is not inside a
# nova-letterbox marker block. Lines inside a block are removed with the block.
file_has_exact_outside_block() {
	local file="$1"
	local dir="$2"
	local row inblock=0
	[[ -f "$file" ]] || return 1
	while IFS= read -r row || [[ -n "$row" ]]; do
		if marker_begin_line "$row"; then
			inblock=1
			continue
		fi
		if marker_end_line "$row"; then
			inblock=0
			continue
		fi
		if [[ "$inblock" == 0 ]] && line_is_exact_export "$row" "$dir"; then
			return 0
		fi
	done <"$file"
	return 1
}

strip_exact_exports() {
	local file="$1"
	local dir="$2"
	local tmp row inblock=0 changed=0
	[[ -f "$file" ]] || return 0
	tmp="$(mktemp)"
	while IFS= read -r row || [[ -n "$row" ]]; do
		if marker_begin_line "$row"; then
			inblock=1
			printf '%s\n' "$row" >>"$tmp"
			continue
		fi
		if marker_end_line "$row"; then
			inblock=0
			printf '%s\n' "$row" >>"$tmp"
			continue
		fi
		if [[ "$inblock" == 0 ]] && line_is_exact_export "$row" "$dir"; then
			changed=1
			continue
		fi
		printf '%s\n' "$row" >>"$tmp"
	done <"$file"
	if [[ "$changed" == 0 ]]; then
		rm -f "$tmp"
		return 0
	fi
	if [[ ! -w "$file" ]]; then
		rm -f "$tmp"
		note_failed "$file"
		return 1
	fi
	cat "$tmp" >"$file"
	rm -f "$tmp"
	note_removed "updated ${file}"
}

report_exact_exports() {
	local file dir
	while IFS= read -r dir; do
		[[ -n "$dir" ]] || continue
		# /usr/local/bin is shared with the whole machine. A marked block
		# that added it is already gone. An unmarked line is not ours to drop.
		[[ "$dir" == /usr/local/bin ]] && continue
		while IFS= read -r file; do
			if file_has_exact_outside_block "$file" "$dir"; then
				note_left "${file} still exports PATH for ${dir} outside a nova-letterbox block. That directory is shared, so the line was kept."
			fi
		done < <(rc_files)
	done < <(bins_for_exact_lines)
}

any_safe_path() {
	local file
	while IFS= read -r file; do
		if rc_has_safe_path "$file"; then
			return 0
		fi
	done < <(rc_files)
	return 1
}

any_autostart_mention() {
	local file
	while IFS= read -r file; do
		if [[ -f "$file" ]] && file_mentions_nova "$file"; then
			return 0
		fi
	done < <(autostart_files)
	if [[ -f "$(xdg_autostart)" ]] && file_mentions_nova "$(xdg_autostart)"; then
		return 0
	fi
	return 1
}

core_work_present() {
	if [[ "$REMOVE_USER" == 1 ]] && user_install_present; then
		return 0
	fi
	if [[ "$REMOVE_SYSTEM" == 1 ]] && system_install_present; then
		return 0
	fi
	if [[ -n "$REMOVE_CUSTOM" ]] && payload_present "$REMOVE_CUSTOM" "${REMOVE_CUSTOM}/share"; then
		return 0
	fi
	if any_autostart_mention; then
		return 0
	fi
	if [[ -z "$ONLYBIN" && -d "$(godot_data_dir)" ]]; then
		return 0
	fi
	if [[ -f "$(systemd_unit)" ]]; then
		return 0
	fi
	if any_safe_path; then
		return 0
	fi
	return 1
}

clean_autostart() {
	local file
	while IFS= read -r file; do
		rewrite_config "$file" "$ONLYBIN" || true
	done < <(autostart_files)
	remove_xdg_autostart || true
}

clean_path_blocks() {
	local file
	while IFS= read -r file; do
		rewrite_config "$file" "$ONLYBIN" || true
	done < <(rc_files)
}

remove_selected_payloads() {
	local share
	if [[ "$REMOVE_USER" == 1 ]]; then
		remove_prefix_payload "$(user_prefix)" "$(user_share)"
		if [[ -n "${XDG_DATA_HOME:-}" && "${XDG_DATA_HOME}" != "${HOME}/.local/share" ]]; then
			remove_prefix_payload "$(user_prefix)" "${HOME}/.local/share"
		fi
		share="$(user_share)"
		refresh_caches "$share"
		refresh_caches "${HOME}/.local/share"
	fi
	if [[ "$REMOVE_SYSTEM" == 1 ]]; then
		remove_prefix_payload /usr/local /usr/local/share
		refresh_caches /usr/local/share
	fi
	if [[ -n "$REMOVE_CUSTOM" ]]; then
		remove_prefix_payload "$REMOVE_CUSTOM" "${REMOVE_CUSTOM}/share"
		refresh_caches "${REMOVE_CUSTOM}/share"
	fi
}

sudo_targets() {
	local path
	if [[ "$REMOVE_SYSTEM" == 1 ]]; then
		printf '%s\n' \
			/usr/local/share/nova-letterbox \
			/usr/local/bin/nova-letterbox \
			/usr/local/share/applications/nova-letterbox.desktop
		if [[ -d /usr/local/share/icons/hicolor ]]; then
			list_icons /usr/local/share
		fi
	fi
	if [[ -n "$REMOVE_CUSTOM" ]]; then
		printf '%s\n' \
			"${REMOVE_CUSTOM}/share/nova-letterbox" \
			"${REMOVE_CUSTOM}/bin/nova-letterbox" \
			"${REMOVE_CUSTOM}/share/applications/nova-letterbox.desktop"
		list_icons "${REMOVE_CUSTOM}/share"
	fi
}

needs_sudo() {
	local path
	while IFS= read -r path; do
		[[ -n "$path" ]] || continue
		if privilege_needed "$path"; then
			return 0
		fi
	done < <(sudo_targets)
	return 1
}

print_plan() {
	ui_heading "NOVA Letterbox uninstall"
	echo
	if [[ "$REMOVE_USER" == 1 ]]; then
		echo "User install: $(user_share)/nova-letterbox"
		echo "Command: $(user_prefix)/bin/nova-letterbox"
	fi
	if [[ "$REMOVE_SYSTEM" == 1 ]]; then
		echo "System install: /usr/local/share/nova-letterbox"
		echo "Command: /usr/local/bin/nova-letterbox"
	fi
	if [[ -n "$REMOVE_CUSTOM" ]]; then
		echo "Prefix install: ${REMOVE_CUSTOM}/share/nova-letterbox"
		echo "Command: ${REMOVE_CUSTOM}/bin/nova-letterbox"
	fi
	if [[ -n "$ONLYBIN" ]]; then
		echo "Another install is still present. Autostart lines that do not name ${ONLYBIN} are kept."
	fi
	echo
	echo "Also checks autostart under ~/.config (Hyprland, Omarchy, labwc, wayfire),"
	echo "the desktop autostart entry, and a user systemd unit named nova-letterbox.service."
}

print_summary() {
	local item
	echo
	ui_heading "Summary"
	if [[ ${#REMOVED[@]} -eq 0 && ${#LEFT[@]} -eq 0 && ${#FAILED[@]} -eq 0 ]]; then
		echo "NOVA Letterbox is not installed."
		return
	fi
	if [[ ${#REMOVED[@]} -eq 0 ]]; then
		echo "Removed: nothing"
	else
		echo "Removed:"
		for item in "${REMOVED[@]}"; do
			printf '  %s\n' "$item"
		done
	fi
	if [[ ${#LEFT[@]} -gt 0 ]]; then
		echo "Left in place:"
		for item in "${LEFT[@]}"; do
			printf '  %s\n' "$item"
		done
	fi
	if [[ ${#FAILED[@]} -gt 0 ]]; then
		echo "Could not remove:"
		for item in "${FAILED[@]}"; do
			printf '  %s\n' "$item"
		done
	fi
	if [[ ${#REMOVED[@]} -gt 0 ]]; then
		echo
		echo "Not changed:"
		echo "  Packages the installer may have added (python3, curl, iputils, iw, wireless tools, ethtool, network-manager) are shared and were left installed."
		echo "  Hyprland monitor modes and Pi blanking (raspi-config, swayidle, wayfire dpms_timeout) were not changed."
		if ! command -v update-desktop-database >/dev/null 2>&1 && ! command -v gtk-update-icon-cache >/dev/null 2>&1; then
			echo "  Desktop and icon caches were not refreshed (update-desktop-database and gtk-update-icon-cache are not installed). A stale menu entry can linger until the next login."
		fi
	fi
}

remove_godot_data() {
	local dir
	dir="$(godot_data_dir)"
	[[ -d "$dir" ]] || return 0
	if [[ -n "$ONLYBIN" ]]; then
		note_left "${dir} kept because another install is still present"
		return 0
	fi
	if ! safe_path "$dir"; then
		note_failed "${dir} (refusing an unexpected app-data path)"
		return 1
	fi
	[[ "$dir" == */godot/app_userdata/NOVA\ Letterbox ]] || {
		note_failed "${dir} (refusing an unexpected app-data path)"
		return 1
	}
	if interactive_mode; then
		if ! ask_yn "Remove Godot app data at ${dir}?"; then
			note_left "${dir} kept"
			return 0
		fi
	fi
	remove_path "$dir" tree || true
}

finish() {
	local status=0
	print_summary
	if [[ ${#FAILED[@]} -gt 0 ]]; then
		status=1
	fi
	exit "$status"
}

main() {
	parse_args "$@"
	require_linux
	decide_scope
	if ! interactive_mode; then
		SUDO_OK=1
	fi

	if ! core_work_present; then
		report_exact_exports
		finish
	fi

	print_plan
	if interactive_mode; then
		echo
		if ! ask_yn "Remove NOVA Letterbox?"; then
			echo "Uninstall cancelled."
			exit 0
		fi
	else
		echo "No prompts: removing the install, autostart entries, installer PATH blocks, and app data."
	fi

	if needs_sudo; then
		if interactive_mode; then
			echo
			echo "Some files are outside ${HOME} and are not writable."
			if ask_yn "Remove those files with sudo?"; then
				SUDO_OK=1
			else
				SUDO_OK=0
				echo "System files will be left in place."
			fi
		else
			echo "Some files are outside ${HOME} and are not writable. Using sudo where it is needed."
			SUDO_OK=1
		fi
	fi

	remove_selected_payloads
	clean_autostart
	if [[ -z "$ONLYBIN" || -f "$(systemd_unit)" ]]; then
		remove_systemd_unit "$(systemd_unit)" || true
	fi

	if any_safe_path; then
		echo
		if interactive_mode; then
			echo "Shell startup files contain a nova-letterbox PATH block, or an export PATH line that names nova-letterbox."
			if ask_yn "Remove those PATH lines?"; then
				clean_path_blocks
			else
				local rc
				while IFS= read -r rc; do
					if rc_has_safe_path "$rc"; then
						note_left "${rc} PATH lines kept"
					fi
				done < <(rc_files)
			fi
		else
			clean_path_blocks
		fi
	fi

	if interactive_mode; then
		local dir rc
		while IFS= read -r dir; do
			[[ -n "$dir" ]] || continue
			[[ "$dir" == /usr/local/bin ]] && continue
			local offered=0
			while IFS= read -r rc; do
				if file_has_exact_outside_block "$rc" "$dir"; then
					offered=1
					break
				fi
			done < <(rc_files)
			if [[ "$offered" == 1 ]]; then
				echo
				echo "Unmarked line: $(exact_export_line "$dir")"
				if ask_yn "Remove that PATH line? Other programs may use ${dir}."; then
					while IFS= read -r rc; do
						strip_exact_exports "$rc" "$dir" || true
					done < <(rc_files)
				fi
			fi
		done < <(bins_for_exact_lines)
	fi
	report_exact_exports

	remove_godot_data || true

	if pgrep -x nova-letterbox >/dev/null 2>&1; then
		note_left "nova-letterbox is still running. Quit it (Esc or Q). The removed files will not start it again."
	fi

	finish
}

_nova_self="${BASH_SOURCE[0]:-}"
if [[ -z "$_nova_self" || "$_nova_self" == "$0" ]]; then
	main "$@"
fi
unset -v _nova_self
