-- Hyprland keybindings (loaded via wayland.windowManager.hyprland.extraLuaFiles).
-- Host-dynamic config (monitors, lockscreen) lives in hyprland.nix extraConfig.

local mainMod = "SUPER"
local terminal = "foot"
local browser = "env LIBVA_DRIVER_NAME=iHD qutebrowser"

hl.exec_cmd("hyprctl setcursor macOS-White 28")
hl.exec_cmd("systemctl start docker")

-- HYPRLAND
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + CTRL + RETURN", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("obsidian daily"))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())

hl.bind(mainMod .. " + PRINT", hl.dsp.exec_cmd("hyprshot -m window -m active"))
hl.bind(mainMod .. " + O",
  hl.dsp.exec_cmd(
    [[bash -lc 'text="$(hyprshot -m region --raw | tesseract stdin stdout -l deu 2>/dev/null)"; wl-copy <<< "$text"; notify-send "📸 OCR copied" "$(echo "$text" | head -c 300)"']]))
hl.bind(mainMod .. " + SHIFT + PRINT", hl.dsp.exec_cmd("hyprshot -m output -m active"))
hl.bind("PRINT", hl.dsp.exec_cmd("hyprshot -m region"))

-- WINDOW MANAGEMENT (hy3)
hl.bind(mainMod .. " + A", hl.plugin.hy3.change_focus("raise"))
hl.bind(mainMod .. " + E", hl.plugin.hy3.change_group("opposite"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + H", hl.plugin.hy3.make_group("h"))
hl.bind(mainMod .. " + W", hl.plugin.hy3.change_group("tab"))
hl.bind(mainMod .. " + SHIFT + W", hl.plugin.hy3.make_group("tab", { toggle = true }))
hl.bind(mainMod .. " + V", hl.plugin.hy3.make_group("v"))

-- FOCUS / MOVE WINDOWS (hy3)
for _, d in ipairs({ "left", "right", "up", "down" }) do
  local dir = d:sub(1, 1)
  hl.bind(mainMod .. " + " .. d, hl.plugin.hy3.move_focus(dir))
  hl.bind(mainMod .. " + SHIFT + " .. d, hl.plugin.hy3.move_window(dir))
end

-- RESIZE / MOVE: small by default, SHIFT forces big; ALT switches resize -> move.
-- Same direction keys + step tiers drive both the ijkl cluster and the numpad.
local resizeSmall, resizeBig = 15, 100
local moveSmall, moveBig = 100, 300
local tiers = {
  { mods = mainMod,                     dispatch = "resize", step = resizeSmall },
  { mods = mainMod .. " + SHIFT",       dispatch = "resize", step = resizeBig },
  { mods = mainMod .. " + ALT",         dispatch = "move",   step = moveSmall },
  { mods = mainMod .. " + ALT + SHIFT", dispatch = "move",   step = moveBig },
}

local ijklKeys = {
  { key = "i", x = 0,  y = 1 },
  { key = "j", x = -1, y = 0 },
  { key = "k", x = 0,  y = -1 },
  { key = "l", x = 1,  y = 0 },
}
local kpKeys = {
  { key = "KP_Left",  x = -1, y = 0 },
  { key = "KP_Right", x = 1,  y = 0 },
  { key = "KP_Up",    x = 0,  y = 1 },
  { key = "KP_Down",  x = 0,  y = -1 },
  { key = "KP_Begin", x = 0,  y = -1 },
  { key = "KP_Home",  x = -1, y = 1 },
  { key = "KP_Prior", x = 1,  y = 1 },
  { key = "KP_End",   x = -1, y = -1 },
  { key = "KP_Next",  x = 1,  y = -1 },
}

local function bindGrid(keys)
  for _, tier in ipairs(tiers) do
    for _, k in ipairs(keys) do
      hl.bind(
        tier.mods .. " + " .. k.key,
        hl.dsp.window[tier.dispatch]({ x = k.x * tier.step, y = k.y * tier.step, relative = true })
      )
    end
  end
end

bindGrid(ijklKeys)
bindGrid(kpKeys)

-- MONITOR SCALE (of the active window's monitor)
for _, s in ipairs({
  { keys = { "plus", "KP_Add" },       delta = "up" },
  { keys = { "minus", "KP_Subtract" }, delta = "down" },
}) do
  for _, key in ipairs(s.keys) do
    hl.bind(mainMod .. " + " .. key, hl.dsp.exec_cmd("hypr-scale " .. s.delta))
  end
end
hl.bind(mainMod .. " + CTRL + 0", hl.dsp.exec_cmd("hypr-scale reset"))

-- WORKSPACES (1-9 -> 1-9, 0 -> 10)
for i = 0, 9 do
  local ws = (i == 0) and 10 or i
  hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = ws }))
  hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = ws, follow = false }))
end

hl.bind(mainMod .. " + CTRL + left", hl.dsp.workspace.move({ monitor = "l" }))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.workspace.move({ monitor = "r" }))

-- MOUSE
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- AUDIO / BRIGHTNESS (locked, repeating)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
  { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
  { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
  { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

-- MEDIA (locked)
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
