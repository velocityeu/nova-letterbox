# Omarchy

[Omarchy](https://omarchy.org/) is the Arch-based Hyprland desktop. The install is the same Linux binary as the Pi: no pacman package and no AUR package.

The repo is private. `GH_TOKEN` or `gh auth login` is required before any of the commands below.

## Install

```bash
./install-omarchy.sh
```

That is `install.sh --omarchy`. On a machine whose `/etc/os-release` already says Omarchy, plain `install.sh` does the same layout.

What it writes:

| Path | What |
| --- | --- |
| `~/.local/share/nova-letterbox/nova-letterbox` | Release binary, PCK embedded |
| `~/.local/bin/nova-letterbox` | Symlink to that binary |
| `~/.local/share/applications/nova-letterbox.desktop` | Native desktop entry |
| `~/.local/share/icons/hicolor/scalable/apps/nova-letterbox.svg` | Icon |

The desktop entry is named **NOVA Letterbox**. `Exec` calls `omarchy-launch-or-focus` so Super+Space focuses the window when it is already open, and launches it otherwise. It is not a Chromium webapp. `StartupWMClass=NOVA Letterbox` matches the Godot 4.3 window class (`application/config/name`, also the Wayland app id).

After install, open it from the launcher: **Super+Space**, then NOVA Letterbox. Nothing starts at login unless you say yes in the terminal wizard or pass `--autostart`. `--yes` and a pipe do not ask and do not enable autostart unless `--autostart` is present.

A noninteractive run of the same installer: [install.sh --yes](images/docs-install-run.png).

In a terminal the same script also offers recommended packages (`iputils`, `iw`, `wireless_tools`, `ethtool`, and optionally `networkmanager`) and can append `~/.local/bin` to your shell rc if it is not on `PATH`.

```bash
./install-omarchy.sh --fullscreen
./install-omarchy.sh --autostart
```

The piped form, after `gh auth login`:

```bash
gh api repos/velocityeu/nova-letterbox/contents/install-omarchy.sh \
  -H "Accept: application/vnd.github.raw" | bash -s -- --autostart
```

## Autostart and the 1920×480 output

`--autostart` is optional. It does not install a systemd user service.

- If `~/.config/omarchy/autostart.conf` or `~/.config/omarchy/hypr/autostart.conf` already exists, it appends `exec-once = nova-letterbox` and a fullscreen window rule on monitor `HDMI-A-1`.
- If the session is current Omarchy (`~/.config/hypr/hyprland.lua` / `autostart.lua`), that `.conf` file is not what Hyprland loads. The installer appends `o.launch_on_start("nova-letterbox")` to `~/.config/hypr/autostart.lua` and the window rule to `~/.config/hypr/looknfeel.lua`.
- Otherwise it appends the `exec-once` block to `~/.config/hypr/autostart.conf`.

The window rule is fullscreen on `HDMI-A-1`. Check the real name with `hyprctl monitors` and edit the monitor if it differs. The panel mode belongs in `~/.config/hypr/monitors.lua`:

```lua
hl.monitor({ output = "HDMI-A-1", mode = "1920x480@60", position = "auto", scale = 1 })
```

`hyprctl monitors all` lists the modes the panel advertises. This project does not rotate a portrait 480×1920 mode.

Keys, with the window focused: `1` Simple, `2` Complete, `Tab` toggles, `Esc` or `Q` quits, `F11` toggles fullscreen. Renderer is GL Compatibility. If the window does not map, try `nova-letterbox --fullscreen --display-driver x11`.

Examples of the lines the installer appends are in `packaging/omarchy/`.

## Uninstall

The same `uninstall.sh` as a Linux PC or a Pi. `./install-omarchy.sh --uninstall` runs it. `--yes` skips the questions.

It removes the user binary, symlink, desktop entry, and icon. If `/usr/local` also has a copy, that tree is removed too, with `sudo` when it is not writable. `--system` limits the binary, desktop entry, and icons to `/usr/local`.

Hyprland and Omarchy autostart blocks (`nova-letterbox-begin` through `nova-letterbox-end` in `autostart.conf`, `autostart.lua`, and `looknfeel.lua`) are removed. Other lines in those files stay. A generic `exec-once = nova-letterbox` is kept when another install is still on disk.

`~/.config/hypr/monitors.lua` is not edited. Packages the wizard installed are not removed. Godot's runtime folder `~/.local/share/godot/app_userdata/NOVA Letterbox` (and the same folder under `$XDG_DATA_HOME` when that is set) is removed with `--yes` or after a prompt. Other projects in `app_userdata` stay. Details and the private-repo one-liner are in the README.
