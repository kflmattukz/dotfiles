-- PotPlayer-style ESC: fullscreen/maximized → normal window; normal window → minimize + pause.
-- Any minimize mpv sees (ESC, uosc's minimize button) also pauses, and restoring the window
-- resumes playback, but only if it was playing when hidden.

local auto_paused = false -- we paused it on hide, so we may resume it on restore

local function pause_for_hide()
    if not mp.get_property_bool("pause") then
        mp.set_property_bool("pause", true)
        auto_paused = true
    end
end

local function hide()
    pause_for_hide()
    -- Wayland never tells apps they were un-minimized, so the flag can still read "yes"
    -- from last time; flip it so mpv sends the minimize request again.
    mp.set_property_bool("window-minimized", false)
    mp.set_property_bool("window-minimized", true)
end

mp.add_key_binding(nil, "esc", function()
    if mp.get_property_bool("fullscreen") then
        mp.set_property_bool("fullscreen", false)
        mp.osd_message("Window")
    elseif mp.get_property_bool("window-maximized") then
        mp.set_property_bool("window-maximized", false)
        mp.osd_message("Window")
    else
        hide()
    end
end)

mp.observe_property("window-minimized", "bool", function(_, minimized)
    if minimized then pause_for_hide() end
end)

-- Play pressed while hidden (media key / MPRIS): the user took over, don't touch it on restore.
mp.observe_property("pause", "bool", function(_, paused)
    if not paused then auto_paused = false end
end)

-- Wayland has no "restored" event; regaining focus while flagged minimized is the restore.
mp.observe_property("focused", "bool", function(_, focused)
    if focused and mp.get_property_bool("window-minimized") then
        mp.set_property_bool("window-minimized", false)
        if auto_paused then
            auto_paused = false
            mp.set_property_bool("pause", false)
            mp.osd_message("▶  Play")
        end
    end
end)
