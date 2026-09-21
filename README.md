# NOVA Letterbox

Godot 4 display for a Raspberry Pi 5 driving a [Waveshare 8.8" IPS Side Monitor](https://www.waveshare.com/wiki/8.8inch_Side_Monitor) over HDMI. The panel's native scan is portrait **480×1920**. NOVA runs landscape **1920×480**, fullscreen, display-only.

Numbers on screen are design stubs in `scripts/demo_telemetry.gd`. There is no speed test, socket, or Pi sensor API yet. The complete-view clock is the exception: at runtime it reads the local system clock. In the editor it stays on the mock timestamp (10:24:37, Sat, 24 May 2025).

## Views

| View | How to open | What it shows |
| --- | --- | --- |
| **Simple** (default) | `1` | Three copper dials — Download Mbps, Upload Mbps, Ping ms — plus Wi-Fi Connected and Ethernet Link. Matches `docs/design/simple.png`. |
| **Complete** | `2` | The same three dials, a throughput sparkline, a Pi → router → internet path, CPU/RAM rings, a top bar (clock, NOVA, public and local IP, VPN), and a status ribbon (SSID, Ethernet, Pi temp, disk). Matches `docs/design/complete.png`. |

`Tab` toggles between them. The palette is shared: matte charcoal, copper bezels, amber needles and values, soft steel-blue secondary text. No purple and no neon magenta. Constants live in `scripts/nova_colors.gd`. `scripts/nova_theme.gd` builds the Godot `Theme` applied to the root.

## Open and run on the desktop

Requires **Godot 4.3 or newer**. The project uses the GL Compatibility renderer so the same project is the one you export for the Pi.

1. Install Godot 4.3+ from [godotengine.org](https://godotengine.org/download).
2. Open `project.godot` (Project → Open, or pass the folder to the editor).
3. Press **F5**. The window is 1920×480.

From a terminal, in this directory:

```bash
godot --path .
```

The design canvas is fixed at 1920×480. Stretch mode is `canvas_items` with aspect `keep`, so a differently shaped window letterboxes the UI instead of stretching it. On a normal 16:9 monitor the window is a short strip; that is the panel shape, not a layout bug.

Headless smoke test (imports, loads the main scene, checks both modes, then quits):

```bash
godot --headless --path . -- --self-check
```

Save both views as PNG files (useful when comparing against the mocks):

```bash
mkdir -p /tmp/nova-shots
godot --path . -- --shot-dir /tmp/nova-shots
```

## Raspberry Pi 5 kiosk

High-level only. Follow the current Waveshare wiki if a step below disagrees with it; Pi OS Bookworm on a Pi 5 uses KMS, and the legacy `display_hdmi_rotate` / `gpu_mem` advice from older images does not belong on a Pi 5.

1. The panel will not sync to a generic TV mode. Waveshare documents this custom mode in `/boot/firmware/config.txt` (older images use `/boot/config.txt`):

   ```
   max_framebuffer_height=1920
   hdmi_group=2
   hdmi_mode=87
   hdmi_force_mode=1
   hdmi_timings=480 0 30 30 30 1920 0 18 6 6 0 0 0 60 0 66280000 3
   ```

   Leave `dtoverlay=vc4-kms-v3d` enabled. Pi 5 needs KMS.

2. Rotate the output to landscape so the desktop is **1920×480**. On the Raspberry Pi OS desktop: Preferences → Screen Configuration → the HDMI output → Orientation → Right or Left, whichever matches how the panel is mounted. The NOVA project does not rotate itself.

3. Export a Linux release from Godot (arm64 templates for the Pi) or copy a Godot 4 arm64 build and this project. Launch fullscreen with the cursor hidden:

   ```bash
   NOVA_KIOSK=1 ./NOVA
   ```

   `NOVA_KIOSK=1` switches to fullscreen and hides the pointer. There is no touch input. `1`, `2`, and `Tab` on a keyboard still switch views.

4. Autostart that command from the desktop session once the HDMI output is up. The scaffold does not install a service or store credentials.

The project runs in low-processor mode: the complete view redraws the clock once a second, and the simple view stays still.

## Project layout

```
project.godot
scenes/main.tscn            # mode switch, kiosk hook
scenes/simple_view.tscn     # default view
scenes/complete_view.tscn   # alternate view
scenes/dial.tscn            # shared rotary dial
scripts/nova_colors.gd      # palette
scripts/nova_theme.gd       # Theme
scripts/demo_telemetry.gd   # stub readings
docs/design/                # locked mocks (not imported by Godot)
fonts/                      # Barlow, SIL Open Font License
```

## Font

UI type is [Barlow](https://github.com/jpt/barlow), copyright The Barlow Project Authors, used under the SIL Open Font License. See `fonts/OFL.txt`.
