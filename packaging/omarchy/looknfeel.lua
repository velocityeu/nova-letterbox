-- Appended to ~/.config/hypr/looknfeel.lua on current Omarchy.
-- Fullscreen on the 1920x480 HDMI output. Rename the monitor if hyprctl differs.
-- nova-letterbox-begin
o.window({ class = "^NOVA Letterbox$" }, { fullscreen = true, monitor = "HDMI-A-1" })
-- nova-letterbox-end
