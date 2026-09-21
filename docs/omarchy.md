# Omarchy

[Omarchy](https://omarchy.org/) is the Arch-based Hyprland desktop. NOVA Letterbox uses the same Linux x86_64 (or aarch64) release binary as the Pi.

The repo is private. `GH_TOKEN` or `gh auth login` is required before any of the commands below.

## Install

From a checkout:

```bash
./install-omarchy.sh
```

Fullscreen immediately:

```bash
./install-omarchy.sh --fullscreen
```

Start the letterbox on every Hyprland login (appends one line to `~/.config/hypr/autostart.lua`):

```bash
./install-omarchy.sh --autostart
```

The piped form, after `gh auth login`:

```bash
gh api repos/velocityeu/nova-letterbox/contents/install-omarchy.sh \
  -H "Accept: application/vnd.github.raw" | bash -s -- --autostart
```

`install.sh` on its own detects Omarchy (`NAME` or `ID` in `/etc/os-release` contains `omarchy`) and prints these next steps. It does not edit Hyprland config unless you pass `--omarchy` / `--autostart`.

What `--omarchy` writes:

- Binary: `~/.local/bin/nova-letterbox` (or `/usr/local/bin` with `--system`)
- Desktop entry: `~/.local/share/applications/nova-letterbox.desktop`  
  The launcher runs `nova-letterbox --fullscreen`. A copy of the entry lives in `packaging/omarchy/nova-letterbox.desktop`.

What `--autostart` appends, once, to `~/.config/hypr/autostart.lua`:

```lua
o.launch_on_start("/home/you/.local/bin/nova-letterbox --fullscreen")
```

That is the current Omarchy hook (`o.launch_on_start` in the user autostart file). It is not an edit under `/usr/share/omarchy`, which the pacman package overwrites. The example file is `packaging/omarchy/autostart.lua`. Reload Hyprland, or log in again, after adding it.

## Monitor

The letterbox is 1920×480. Put the side panel on its own output in `~/.config/hypr/monitors.lua`:

```lua
hl.monitor({ output = "HDMI-A-1", mode = "1920x480@60", position = "auto", scale = 1 })
```

`hyprctl monitors all` shows the output name and the modes the panel actually advertises. This project does not rotate a portrait 480×1920 mode; set a landscape mode, or a transform, in that file.

Keys, with the window focused: `1` Simple, `2` Complete, `Tab` toggles. Renderer is GL Compatibility. If the window does not map, try `nova-letterbox --fullscreen --display-driver x11`.

## pacman

`packaging/omarchy/PKGBUILD` installs the prebuilt binary to `/usr/bin/nova-letterbox` and the desktop file to `/usr/share/applications`. It is a local package, not an AUR package. Set `pkgver` to a published tag (without the `v`), then:

```bash
cd packaging/omarchy
makepkg -si
```

`makepkg` calls `gh release download` for `nova-letterbox-linux-x86_64` or `nova-letterbox-linux-arm64`. Until a `v*` release exists, point `pkgver` at a tag you have published, or use `install-omarchy.sh` instead.
