-- PotPlayer-style mirror/flip toggles with an on/off message.
-- Bound in input.conf: script-binding flip/hflip, script-binding flip/vflip
--
-- The flip filters can't read GPU-only (vaapi) frames, so while a flip is
-- active hwdec is switched to a copy-back mode, and restored when none is.
-- A flip added before the decoder finishes switching fails and mpv silently
-- stops running it (the vf list still shows it enabled), so active flips are
-- rebuilt once frames reach system memory.

local LABELS = {"hflip", "vflip"}
local hwdec_normal = mp.get_property("hwdec")

local function has(label)
    for _, f in ipairs(mp.get_property_native("vf")) do
        if f.label == label then return true end
    end
    return false
end

local function rebuild(_, cur)
    if not (cur == "no" or (cur and cur:find("copy"))) then return end
    for _, label in ipairs(LABELS) do
        if has(label) then
            mp.command("no-osd vf remove @" .. label)
            mp.command("no-osd vf add @" .. label .. ":" .. label)
        end
    end
end

-- Also runs when vf is restored from watch_later on file load.
mp.observe_property("vf", "native", function()
    local want = (has("hflip") or has("vflip")) and "auto-copy-safe" or hwdec_normal
    if mp.get_property("hwdec") ~= want then mp.set_property("hwdec", want) end
end)

mp.observe_property("hwdec-current", "string", rebuild)

local function toggle(label, name)
    if has(label) then
        mp.command("no-osd vf remove @" .. label)
        mp.osd_message(name .. "  off")
    else
        mp.command("no-osd vf add @" .. label .. ":" .. label)
        mp.osd_message(name .. "  on")
        -- hwdec-current may not change again (e.g. paused), so retry once.
        mp.add_timeout(0.5, function() rebuild(nil, mp.get_property("hwdec-current")) end)
    end
end

mp.add_key_binding(nil, "hflip", function() toggle("hflip", "Mirror horizontal") end)
mp.add_key_binding(nil, "vflip", function() toggle("vflip", "Flip vertical") end)
