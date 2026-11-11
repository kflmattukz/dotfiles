-- Keep volume/mute global across sessions (PotPlayer-like), stored in ~~state/volume

local mp = require 'mp'
local utils = require 'mp.utils'
local path = mp.command_native({ 'expand-path', '~~state/volume' })

local f = io.open(path, 'r')
if f then
    local vol, mute = (f:read('*l') or ''):match('^(%S+)%s+(%S+)')
    f:close()
    if tonumber(vol) then mp.set_property_number('volume', tonumber(vol)) end
    if mute then mp.set_property('mute', mute) end
end

mp.register_event('shutdown', function()
    local dir = utils.split_path(path)
    mp.command_native({ name = 'subprocess', args = { 'mkdir', '-p', dir }, playback_only = false })
    local out = io.open(path, 'w')
    if not out then return end
    out:write(string.format('%s %s\n', mp.get_property('volume'), mp.get_property('mute')))
    out:close()
end)
