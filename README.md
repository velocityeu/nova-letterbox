# NOVA Letterbox

Display-only telemetry shell for a Raspberry Pi 5 driving a Waveshare 8.8" IPS side monitor over HDMI. The panel's native timing is portrait **480×1920**. This project runs landscape **1920×480**, fullscreen on the Pi.

The UI is a Godot 4 scene shell. Numbers are stubs in `scripts/demo_telemetry.gd` — there is no live network, sensor, or VPN client yet. The clock in Complete view reads the system time.

Design references (the locked mocks) are in [`docs/design/`](docs/design/).

## Views

| View | When | What you see |
| --- | --- | --- |
| **Simple** | Default | Three copper dials — Download Mbps, Upload Mbps, Ping ms — plus a bottom status line: Wi-Fi Connected and Ethernet Link. |
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

3. Press **F5** (or the Play button) to run. The window is fixed at **1920×480**.

`project.godot` sets:

- viewport `1920×480`
- stretch mode `canvas_items` and aspect `keep` (uniform scale, bars in charcoal if the window is not exactly 4:1)
- hiDPI scaling off, so one viewport pixel is one window pixel on the panel
- GL Compatibility for desktop and mobile

## Raspberry Pi 5 kiosk

High-level only. Follow Waveshare's HDMI guide for your exact 8.8" side-monitor revision — timings differ by panel and are not stored in this repo.

1. Use 64-bit Raspberry Pi OS with a desktop session.
2. Configure the HDMI output so the desktop framebuffer is **landscape 1920×480**. The panel enumerates as portrait 480×1920; rotate or transpose it in the compositor (or with the panel's documented timing) before launching NOVA. Godot does not rotate the buffer itself.
3. Turn screen blanking off in the desktop power settings so the panel stays lit.
4. Run fullscreen from the compositor autostart (labwc, wayfire, or similar):

```bash
godot --fullscreen --path /home/pi/nova-letterbox
```

Install a Godot 4 Linux build on the Pi, or export a Linux binary from the editor. No credentials, API tokens, or device secrets belong in this project.

## Layout

```
project.godot              1920×480 window, GL Compatibility, main scene
scenes/main.tscn           boots Simple; switches views
scenes/simple_view.tscn    default letterbox
scenes/complete_view.tscn  alternate letterbox
scripts/demo_telemetry.gd  stub numbers
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
