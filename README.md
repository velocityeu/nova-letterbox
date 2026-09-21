# NOVA Letterbox

Display-only telemetry shell for a Raspberry Pi 5 driving a Waveshare 8.8" IPS side monitor over HDMI. The panel's native timing is portrait **480×1920**. This project runs landscape **1920×480**, fullscreen on the Pi.

The UI is a Godot 4 scene shell. Gauges, the sparkline, and the status ribbon read the Linux host through the `Telemetry` autoload (`scripts/telemetry.gd`). The clock in Complete view reads the system time.

Design references (the locked mocks) are in [`docs/design/`](docs/design/).

## Install

Linux only. Three layouts today, one installer: a generic desktop, a Raspberry Pi 5 HDMI kiosk, and Omarchy (Arch + Hyprland). The script reads `uname -m` and downloads `nova-letterbox-linux-x86_64` or `nova-letterbox-linux-arm64`. The PCK is embedded in that binary.

### Private repo

The repository is **private**. Log in with `gh auth login` (an account that can read this repo), then:

```bash
gh api repos/velocityeu/nova-letterbox/contents/install.sh --jq .content | base64 -d | bash
```

With a token that can read this repo, in `GH_TOKEN` or `GITHUB_TOKEN`:

```bash
curl -fsSL \
  -H "Authorization: Bearer ${GH_TOKEN:-$GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.raw" \
  https://api.github.com/repos/velocityeu/nova-letterbox/contents/install.sh | bash
```

Anonymous `curl -fsSL https://raw.githubusercontent.com/velocityeu/nova-letterbox/main/install.sh | bash` works only once the repo is public (the script and the release assets). Until then that URL is not available.

### Text wizard or one-liner

In a terminal, `bash install.sh` (and `./install-omarchy.sh`) runs a plain-text wizard. It names the architecture and distro, offers to install missing packages, downloads the binary, offers to put the command directory on `PATH`, and asks whether to enable autostart. Prompts are `[y/N]` (the welcome continue prompt is `[Y/n]`). The wizard does not need `dialog` or `whiptail`.

`bash install.sh --yes`, `NOVA_NONINTERACTIVE=1`, or a pipe (the one-liner above) skips every prompt. That path does not install packages, does not edit shell startup files, and does not enable autostart unless you also pass `--autostart`.

### After install

The command is `~/.local/bin/nova-letterbox`, a symlink to `~/.local/share/nova-letterbox/nova-letterbox`. No sudo unless you accept a package install, or `--system` cannot write `/usr/local`. A desktop entry and icon land under `~/.local/share`. If `~/.local/bin` is not on `PATH`, the wizard can append an `export` to `~/.bashrc`, `~/.zshrc`, or `~/.profile` after you confirm. The one-liner only prints the `export` line.

```bash
nova-letterbox
nova-letterbox --fullscreen
```

With the window focused:

- `1` Simple · `2` Complete · `Tab` toggle
- `Esc` or `Q` quit · `F11` toggle fullscreen

```bash
NOVA_PRINT_VERSION=1 nova-letterbox
```

That prints `NOVA Letterbox continuous` for the rolling build, or `NOVA Letterbox` plus the tag version (`NOVA Letterbox 0.1.0` for `v0.1.0`). The window may flash before it exits.

### Linux PC (x86_64)

The one-liner above. It needs a display. Gauges, the sparkline, and the status ribbon read live host metrics ([Live telemetry](#live-telemetry)).

### Raspberry Pi 5 (aarch64)

The same one-liner. On the Pi it downloads `nova-letterbox-linux-arm64` for the Waveshare 8.8″ HDMI panel. Landscape **1920×480**, blanking off, and labwc, wayfire, or systemd autostart: [`docs/pi-kiosk.md`](docs/pi-kiosk.md).

In a terminal the wizard asks before enabling autostart. On Pi OS the default is labwc (`~/.config/labwc/autostart`). A wayfire session, or an existing `~/.config/wayfire.ini`, updates that file instead. The systemd user unit is not enabled for you. `--yes` and a pipe leave autostart off unless you pass `--autostart`.

`iputils-ping`, `iw`, and `ethtool` improve ping, Wi-Fi, and link-speed readings when they are installed. The shell still runs without them.

### Omarchy Linux

Same binary as the Linux PC and the Pi. `install-omarchy.sh`, or `install.sh --omarchy`, writes the desktop entry (Super+Space → **NOVA Letterbox**). In a terminal the wizard asks before Hyprland autostart. `--autostart` adds it without asking. `--yes` and a pipe do not. Notes: [`docs/omarchy.md`](docs/omarchy.md).

```bash
gh api repos/velocityeu/nova-letterbox/contents/install-omarchy.sh --jq .content | base64 -d | bash
```

Hyprland autostart:

```bash
gh api repos/velocityeu/nova-letterbox/contents/install-omarchy.sh --jq .content | base64 -d | bash -s -- --autostart
```

From a checkout: `./install-omarchy.sh` or `bash install.sh --omarchy`. On a machine whose `/etc/os-release` already says Omarchy, plain `install.sh` writes the same desktop entry.

### Releases

The installer prefers the latest **stable** `v*` release. If none exists, it falls back to the **`continuous`** prerelease from `main` and says so. A push to `main` updates `continuous`. A `v*` tag is the stable release. The download needs that workflow to have succeeded at least once.

Pin a release by exporting `NOVA_VERSION` in the shell that runs the script, then use the same one-liner:

```bash
export NOVA_VERSION=v0.1.0      # stable tag (0.1.0 is accepted; a leading v is added)
export NOVA_VERSION=continuous  # rolling build from main
```

## Views

| View | When | What you see |
| --- | --- | --- |
| **Simple** | Default | Three copper dials — Download Mbps, Upload Mbps, Ping ms — plus a bottom status line for Wi-Fi and Ethernet. |
| **Complete** | Alternate | The same three dials, with a throughput sparkline, Pi → Router → Internet path, CPU and RAM rings, a top bar (clock, NOVA, public and local IP, VPN badge), and a status ribbon (Wi-Fi, Ethernet, Pi temperature, disk). |

With the window focused:

- `1` Simple · `2` Complete · `Tab` toggle
- `Esc` or `Q` quit · `F11` toggle fullscreen

The cursor hides while the window is fullscreen.

## Open and run on the desktop

Requires **Godot 4.3 or newer** (4.x). The project uses the GL Compatibility renderer so the same 2D shell is a reasonable fit for a Pi kiosk.

1. Install Godot 4 from [godotengine.org](https://godotengine.org/download).
2. Open this folder: **Project → Open** and choose `project.godot`. The first open imports the bundled fonts. You can also launch it from a terminal after that import:

```bash
godot --path .
```

3. Press **F5** (or the Play button) to run. The window is fixed at **1920×480**. The runnable export preset is **Linux Desktop** (x86_64).

`project.godot` sets:

- viewport `1920×480`
- stretch mode `canvas_items` and aspect `keep` (uniform scale, bars in charcoal if the window is not exactly 4:1)
- hiDPI scaling off, so one viewport pixel is one window pixel on the panel
- GL Compatibility for desktop and mobile

## Export release binaries

Presets are in `export_presets.cfg`. Both embed the PCK. Rebuilds need **Godot 4.3.stable** and the matching Linux export templates (`linux_release.x86_64` and `linux_release.arm64`). Editor output goes under `build/`. The installer names are copied to `dist/`. Both directories are gitignored.

| Preset | Architecture | Export | Release asset |
| --- | --- | --- | --- |
| **Linux Desktop** | x86_64 | `build/linux-x86_64/nova-letterbox.x86_64` | `dist/nova-letterbox-linux-x86_64` |
| **Linux Pi ARM64** | arm64 | `build/linux-arm64/nova-letterbox.arm64` | `dist/nova-letterbox-linux-arm64` |

With `godot` (4.3.stable) on `PATH`:

```bash
./scripts/export-linux.sh
```

One preset at a time (the output directory must exist; Godot 4.3 will not create it):

```bash
mkdir -p build/linux-x86_64 build/linux-arm64
godot --headless --path . --export-release "Linux Desktop" build/linux-x86_64/nova-letterbox.x86_64
godot --headless --path . --export-release "Linux Pi ARM64" build/linux-arm64/nova-letterbox.arm64
```

The Pi preset embeds the PCK and includes **ETC2/ASTC** (GLES on the Pi) with **S3TC/BPTC** as a secondary. Godot 4.3 does not split those pairs into separate checkboxes.

[`.github/workflows/release.yml`](.github/workflows/release.yml) runs this export on `main` and on `v*` tags, then uploads the two `dist/` names as GitHub Release assets. `main` updates the `continuous` prerelease. A `v*` tag is the latest stable release.

## Raspberry Pi 5 kiosk

Install from the section above (`nova-letterbox-linux-arm64`). HDMI landscape **1920×480** (panel native **480×1920**), blanking off, and labwc, wayfire, or systemd autostart are in [`docs/pi-kiosk.md`](docs/pi-kiosk.md).

```bash
nova-letterbox --fullscreen
```

No credentials, API tokens, or device secrets belong in this project.

The shell still runs on a headless dev machine with no Wi-Fi card. That card then reads as not connected. `network-manager` (`nmcli`) is an optional Wi-Fi fallback, used when it is present and skipped when it is not.

## Live telemetry

`Telemetry` samples the host on a 1 second tick. Costlier probes are slower. Nothing here is a scripted animation: a missing sensor stays at an explicit offline or N/A state.

| Field | How it is read | If it cannot be read |
| --- | --- | --- |
| Download / Upload Mbps | Byte counters in `/proc/net/dev` on the default-route interface (`/proc/net/route`), turned into Mbps from the delta | `0` until the second sample, then real idle traffic |
| Ping ms | `ping -c 1 -W 1` to the default gateway, then to `1.1.1.1`. If ICMP fails, a TCP connect to `1.1.1.1:443` | Last good RTT stays on the dial. `0` until the first success |
| Throughput sparkline | Rolling ~24 samples of **download** Mbps. The Y axis grows with the peak | Empty until two samples exist |
| Local IP | Godot `IP.get_local_interfaces()` on that same interface | `—` |
| Public IP | HTTPS `https://1.1.1.1/cdn-cgi/trace` (4s timeout), then `https://api.ipify.org`. Cached 5 minutes; retry 1 minute after a miss | `—`, or the last address that succeeded |
| VPN | Interface up (`IFF_UP`) whose name starts with `tun`, `tap`, `wg`, `tailscale`, `zt`, `nordlynx`, `proton`, `mullvad`, `warp`, or similar | Badge **OFF** |
| Wi-Fi | `iw dev <iface> link`, then `iwgetid`, then `nmcli` without a rescan. dBm also comes from `/proc/net/wireless` | **Not connected** / **N/A**. No card is the same state |
| Ethernet | Carrier and speed from `/sys/class/net/<iface>`. `ethtool` only if sysfs has no positive speed | **N/A** if there is no physical NIC. **LINK: up** when the carrier is up but the speed is unknown — the UI does not invent 1 Gbps |
| CPU / RAM | `/proc/stat` deltas and `/proc/meminfo` (`MemAvailable`) | Rings stay empty until a real ratio exists |
| Disk | `df -P /` capacity of the root filesystem | **N/A** |
| Pi temp | `/sys/class/thermal/thermal_zone0/temp` in milli-°C, and only when the device-tree model contains "Raspberry Pi" | **N/A** on desktops and VMs |
| Clock | System clock | — |

Dial faces keep the mock scale (175 Mbps / 175 ms on Simple, 100 on Complete) until a live sample exceeds it, then the scale steps up so the needle is not stuck at the end. Parser fixtures live in `tests/test_linux_metrics.gd`:

```bash
godot --headless --path . -s res://tests/test_linux_metrics.gd
```

On a Linux machine with a default route, `res://tests/probe_live.tscn` prints one live snapshot after a few seconds. It expects ping and a public-address lookup to succeed. Idle throughput can sit near zero; that is real, not a placeholder.

## Layout

```
project.godot              1920×480 window, GL Compatibility, main scene
export_presets.cfg         Linux Desktop (x86_64) and Linux Pi ARM64
install.sh                 text wizard, or a one-line install with --yes
install-omarchy.sh         same install, Omarchy desktop entry forced
scripts/export-linux.sh    headless release export when godot is on PATH
scripts/ci-install-godot.sh  Godot 4.3.stable editor and export templates
scripts/publish-release.sh   upload dist/ binaries to a GitHub Release
.github/workflows/release.yml  build on main and v* tags
docs/pi-kiosk.md           HDMI, blanking, labwc/wayfire
docs/omarchy.md            Omarchy desktop entry and optional Hyprland autostart
packaging/                 Pi session snippets and Omarchy desktop/autostart examples
scenes/main.tscn           boots Simple; switches views
scenes/simple_view.tscn    default letterbox
scenes/complete_view.tscn  alternate letterbox
scripts/telemetry.gd       autoload: live Linux sampler
scripts/linux_metrics.gd   /proc and command parsers
scripts/nova_palette.gd    charcoal / copper / amber / steel constants
scripts/nova_theme.gd      fonts and style boxes
themes/nova_theme.tres     project Theme (IBM Plex Sans)
scripts/dial_gauge.gd      shared rotary dial
docs/design/               locked mocks (not imported as textures)
fonts/                     IBM Plex Sans, SIL Open Font License
```

Type is [IBM Plex Sans](https://github.com/IBM/plex) (copyright © 2017 IBM Corp.), latin subset, under the SIL Open Font License. See `fonts/OFL.txt`.

## Palette

Matte charcoal background, copper bezels and captions, amber needles and bars, soft steel-blue secondary text. Do not introduce purple or neon magenta when extending the shell.
