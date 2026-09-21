# Raspberry Pi 5 kiosk

Run the ARM64 release binary on 64-bit Raspberry Pi OS with a desktop session (labwc or wayfire). Do not install the Godot editor on the Pi for day-to-day use. The binary embeds the PCK. No credentials, API tokens, or device secrets belong in this project.

The window is **1920×480**, fullscreen, GL Compatibility. With the window focused: `1` Simple, `2` Complete, `Tab` toggles. The cursor hides while fullscreen. Missing Wi-Fi or the Pi temperature sensor stays at an explicit offline or N/A state; the shell still starts.

## Install on the Pi

The repo is private. Log in first (`gh auth login`) or export `GH_TOKEN`, then:

```bash
gh api repos/velocityeu/nova-letterbox/contents/install.sh \
  -H "Accept: application/vnd.github.raw" | bash
```

That writes the binary to `~/.local/share/nova-letterbox/nova-letterbox` and a symlink at `~/.local/bin/nova-letterbox`. A `v*` release is the default download. Until one exists, the script uses the `continuous` prerelease built from `main` and says so.

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

## Rebuild

GitHub Actions (`.github/workflows/release.yml`) exports both Linux binaries on `main` and on `v*` tags. A local rebuild needs Godot 4.3.stable and the matching export templates:

```bash
./scripts/ci-install-godot.sh
export PATH="$HOME/.local/bin:$PATH"
./scripts/export-linux.sh
```

Release names are `dist/nova-letterbox-linux-x86_64` and `dist/nova-letterbox-linux-arm64`.
