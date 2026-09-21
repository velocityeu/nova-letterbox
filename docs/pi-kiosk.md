# Raspberry Pi 5 kiosk

Run the exported ARM64 binary on 64-bit Raspberry Pi OS with a desktop session (labwc, wayfire, or similar). Do not install the Godot editor on the Pi for day-to-day use. No credentials, API tokens, or device secrets belong in this project.

Export steps for this binary and for the desktop build are in the [README](../README.md#export-release-binaries).

## Copy the binary

From a machine that has already exported **Linux Pi ARM64**, copy the single file (the PCK is embedded):

```bash
scp build/linux-arm64/nova-letterbox.arm64 pi@raspberrypi:~/nova-letterbox.arm64
```

On the Pi:

```bash
chmod +x nova-letterbox.arm64
```

## HDMI: landscape 1920×480

The Waveshare 8.8" side monitor enumerates as portrait **480×1920**. This project does not rotate the buffer. Set the HDMI desktop framebuffer to landscape **1920×480** before launch — rotate or transpose in the compositor, or apply the timing from Waveshare's HDMI guide for your exact panel revision. Timings differ by revision and are not stored in this repo.

## Blanking off

Turn screen blanking off so the panel stays lit. In Raspberry Pi OS: **Raspberry Pi Configuration → Display → Screen Blanking → Off** (or `sudo raspi-config`, Display Options, Screen Blanking, No).

## Run

From the compositor autostart, or a terminal in the desktop session:

```bash
./nova-letterbox.arm64 --fullscreen
```

The window is fixed at **1920×480**. The cursor hides while fullscreen.

With the window focused:

- `1` — Simple view
- `2` — Complete view
- `Tab` — toggle

## Rebuild with Godot 4.3.stable

On a host (or CI runner) that has the **Godot 4.3.stable** editor and the matching Linux export templates, including `linux_release.arm64` under the `4.3.stable` templates directory:

```bash
mkdir -p build/linux-arm64
godot --headless --path . --export-release "Linux Pi ARM64" build/linux-arm64/nova-letterbox.arm64
```

`godot` must be 4.3.stable on `PATH`. The official editor binary is `Godot_v4.3-stable_linux.x86_64`; a symlink named `godot` is enough. `./scripts/export-linux.sh` exports this preset and the x86_64 desktop preset. Binaries land in `build/` and are not committed.
