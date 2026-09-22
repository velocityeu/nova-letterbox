# Raspberry Pi 5 kiosk

Run the ARM64 release binary on 64-bit Raspberry Pi OS with a desktop session (labwc or wayfire). Do not install the Godot editor on the Pi for day-to-day use. The binary embeds the PCK. No credentials, API tokens, or device secrets belong in this project.

The window is **1920×480**, fullscreen, GL Compatibility. With the window focused: `1` Simple, `2` Complete, `Tab` toggles, `Esc` or `Q` quits, `F11` toggles fullscreen. The cursor hides while fullscreen. Missing Wi-Fi or the Pi temperature sensor stays at an explicit offline or N/A state; the shell still starts.

Live captures: [Simple view](images/docs-app-simple.png) and [Complete view](images/docs-app-complete.png).

## Install on the Pi

The repository is public. The current stable release is **v0.1.0** (`NOVA Letterbox 0.1.0`).

```bash
curl -fsSL https://raw.githubusercontent.com/velocityeu/nova-letterbox/main/install.sh | bash
```

Noninteractive:

```bash
curl -fsSL https://raw.githubusercontent.com/velocityeu/nova-letterbox/main/install.sh | bash -s -- --yes
```

That writes the binary to `~/.local/share/nova-letterbox/nova-letterbox` and a symlink at `~/.local/bin/nova-letterbox`. The installer prefers the latest stable `v*` release (v0.1.0 today). If none exists, it uses the `continuous` prerelease built from `main` and says so. Anonymous GitHub API lookups are limited to 60 per hour. If that delays `releases/latest`, rerun after `gh auth login` or with `GH_TOKEN` set, or pin `NOVA_VERSION=v0.1.0` (or `continuous`). A private fork needs that token.

On a terminal the installer is a text wizard. It can install missing telemetry packages (`iputils-ping`, `iw`, `wireless-tools`, `ethtool`, and optionally `network-manager`) after you confirm, and it asks before autostart. The Pi default is the labwc line below, written with the full path to `~/.local/bin/nova-letterbox` so the session does not depend on `PATH`. If the session is wayfire, or `~/.config/wayfire.ini` already exists, it updates that file instead. The systemd user unit below is not enabled automatically. `bash install.sh --yes` and a pipe do not install packages, edit `PATH`, or enable autostart unless you also pass `--autostart`.

```bash
nova-letterbox --fullscreen
nova-letterbox --version
```

`--version` prints the Godot engine version and does not open a window. `NOVA_PRINT_VERSION=1 nova-letterbox` prints the letterbox version and exits (it may open a window first).

Copying a binary by hand still works. From a machine that has exported **Linux Pi ARM64** (or downloaded `nova-letterbox-linux-arm64`):

```bash
ssh pi@raspberrypi 'mkdir -p ~/.local/share/nova-letterbox ~/.local/bin'
scp dist/nova-letterbox-linux-arm64 pi@raspberrypi:~/.local/share/nova-letterbox/nova-letterbox
ssh pi@raspberrypi 'chmod +x ~/.local/share/nova-letterbox/nova-letterbox && ln -sfn ~/.local/share/nova-letterbox/nova-letterbox ~/.local/bin/nova-letterbox'
```

## HDMI: landscape 1920×480

The Waveshare 8.8" side monitor enumerates as portrait **480×1920**. This project does not rotate the buffer. Set the HDMI output to landscape **1920×480** before launch (compositor transform, or the timing from Waveshare's HDMI guide for that panel revision). Timings differ by revision and are not stored in this repo.

## Blanking off

Turn screen blanking off so the panel stays lit.

- Desktop: **Preferences → Control Centre → Display → Screen Blanking → Off**, or `sudo raspi-config` → Display Options → Screen Blanking → No.
- Command line, same switch: `sudo raspi-config nonint do_blanking 1` (`1` disables blanking, `0` enables it). On labwc this removes the `swayidle` line from `~/.config/labwc/autostart`. On wayfire it sets `dpms_timeout=-1` under `[idle]`.

If the panel still blanks, check that `swayidle` is not left in `~/.config/labwc/autostart`.

## Run from the session

Prefer the compositor autostart over a user service. Raspberry Pi OS does not always start `graphical-session.target`, so a systemd unit can launch before `WAYLAND_DISPLAY` exists.

labwc — append this line to `~/.config/labwc/autostart` (do not replace the file):

```bash
nova-letterbox --fullscreen &
```

The same line is in `packaging/pi/labwc-autostart`.

wayfire — add to `~/.config/wayfire.ini` (snippet in `packaging/pi/wayfire.ini.snippet`):

```ini
[autostart]
nova_letterbox = nova-letterbox --fullscreen

[idle]
dpms_timeout = -1
```

If the window never appears on Wayland, try XWayland: `nova-letterbox --fullscreen --display-driver x11`.

## Optional systemd user unit

Prefer the compositor autostart above. Use the user service only when the panel should come back after a crash and the session has already imported `WAYLAND_DISPLAY` or `DISPLAY`. The unit is `packaging/pi/nova-letterbox.service`. It starts the symlink.

```bash
mkdir -p ~/.config/systemd/user
cp packaging/pi/nova-letterbox.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now nova-letterbox.service
```

## Uninstall

The same `uninstall.sh` as a Linux PC or Omarchy. In a terminal it asks first. `--yes` skips the questions and also removes the installer PATH block and Godot app data.

```bash
curl -fsSL https://raw.githubusercontent.com/velocityeu/nova-letterbox/main/uninstall.sh | bash -s -- --yes
```

From a checkout:

```bash
./uninstall.sh
./uninstall.sh --yes
```

It removes `~/.local/share/nova-letterbox/`, the `~/.local/bin/nova-letterbox` symlink, the desktop entry, and icons. Installer lines in `~/.config/labwc/autostart` and `nova_letterbox` in `~/.config/wayfire.ini` are removed. Other lines in those files stay, including `swayidle` and wayfire `dpms_timeout`. A hand-copied `~/.config/systemd/user/nova-letterbox.service` is removed when it starts this command. Godot's runtime folder `~/.local/share/godot/app_userdata/NOVA Letterbox` (logs and shader cache) is removed with `--yes`, or after a prompt. Other Godot projects in `app_userdata` stay. The same folder under `$XDG_DATA_HOME` is removed when that variable is set. HDMI timing and screen blanking are not changed. `--system` removes a `/usr/local` copy instead, and asks for `sudo` when those files are not writable.

## Rebuild

GitHub Actions (`.github/workflows/release.yml`) exports both Linux binaries on `main` and on `v*` tags. A local rebuild needs Godot 4.3.stable and the matching export templates:

```bash
./scripts/ci-install-godot.sh
export PATH="$HOME/.local/bin:$PATH"
./scripts/export-linux.sh
```

Release names are `dist/nova-letterbox-linux-x86_64` and `dist/nova-letterbox-linux-arm64`.
