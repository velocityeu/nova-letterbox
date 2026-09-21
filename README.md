# NOVA Letterbox

Display-only telemetry shell for a Raspberry Pi 5 driving a Waveshare 8.8" IPS side monitor over HDMI. The panel's native timing is portrait **480×1920**. This project runs landscape **1920×480**, fullscreen on the Pi.

The UI is a Godot 4 scene shell. Gauges, the sparkline, and the status ribbon read the Linux host through the `Telemetry` autoload (`scripts/telemetry.gd`). The clock in Complete view reads the system time.

Design references (the locked mocks) are in [`docs/design/`](docs/design/).

## Views

| View | When | What you see |
| --- | --- | --- |
| **Simple** | Default | Three copper dials — Download Mbps, Upload Mbps, Ping ms — plus a bottom status line for Wi-Fi and Ethernet. |
| **Complete** | Alternate | The same three dials, with a throughput sparkline, Pi → Router → Internet path, CPU and RAM rings, a top bar (clock, NOVA, public and local IP, VPN badge), and a status ribbon (Wi-Fi, Ethernet, Pi temperature, disk). |

With the window focused:

- `1` — Simple view
- `2` — Complete view
- `Tab` — toggle

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

Presets are in `export_presets.cfg`. Rebuilds need **Godot 4.3.stable** and the matching Linux export templates (`linux_release.x86_64` and `linux_release.arm64`). Output goes under `build/`, which is gitignored.

| Preset | Architecture | Binary | Editor Play |
| --- | --- | --- | --- |
| **Linux Desktop** | x86_64 | `build/linux-x86_64/nova-letterbox.x86_64` | yes |
| **Linux Pi ARM64** | arm64 | `build/linux-arm64/nova-letterbox.arm64` | no |

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

## Raspberry Pi 5 kiosk

Copy `build/linux-arm64/nova-letterbox.arm64` to the Pi, `chmod +x`, and run it fullscreen. Full steps — landscape **1920×480** (panel native **480×1920**), blanking off, keys, and the 4.3.stable rebuild command — are in [`docs/pi-kiosk.md`](docs/pi-kiosk.md).

```bash
./nova-letterbox.arm64 --fullscreen
```

No credentials, API tokens, or device secrets belong in this project.

Optional packages, used when present and skipped when they are not:

```bash
sudo apt install iputils-ping iw ethtool network-manager
```

The shell still runs on a headless dev machine with no Wi-Fi card. That card then reads as not connected.

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
scripts/export-linux.sh    headless release export when godot is on PATH
docs/pi-kiosk.md           copy, chmod, HDMI, blanking, fullscreen
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
