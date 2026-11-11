-- Alt+i cycles motion mode: Off → Smooth (frame blending) → RIFE (AI interpolation) → Off.
-- Modes are the [smooth] / [rife] profiles in mpv.conf; leaving a mode restores the previous settings.
local utils = require "mp.utils"

local modes = { "off", "smooth", "rife" }
local labels = { off = "Motion  off", smooth = "Motion  smooth (blend)", rife = "Motion  RIFE" }
local plugin = (os.getenv("HOME") or "") .. "/.local/lib/vapoursynth-flatpak/rife/librife.so"
local current = "off"

local function set(mode)
    if mode == "rife" and not utils.file_info(plugin) then
        mp.osd_message("RIFE plugin missing  ·  run mpv-rife-setup", 3)
        mode = "off"
    end
    if current ~= "off" then mp.commandv("apply-profile", current, "restore") end
    if mode ~= "off" then mp.commandv("apply-profile", mode) end
    current = mode
    mp.osd_message(labels[mode])
end

mp.add_key_binding(nil, "cycle", function()
    for i, m in ipairs(modes) do
        if m == current then return set(modes[i % #modes + 1]) end
    end
end)
