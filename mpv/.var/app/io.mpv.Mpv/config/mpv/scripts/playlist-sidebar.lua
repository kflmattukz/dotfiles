-- Playlist sidebar: slides in from the right edge on hover (or Tab to pin).
-- Click a row to play it, wheel to scroll, Up/Down + Enter to pick with the keyboard. Options: script-opts/playlist_sidebar.conf
-- Header sort button: click label = name/date/size/length, click arrow = asc/desc.
-- Sorting reorders the real playlist, so next/prev follow it. Choice is saved in ~~state.

local mp = require 'mp'
local utils = require 'mp.utils'
local options = {
    width = 360,      -- panel width (osd px)
    edge = 60,        -- distance from right edge that opens the panel
    row_height = 34,
    font_size = 17,
    min_items = 2,    -- don't open on hover for single-file playlists
    title_gap = 12,   -- gap between the panel and uosc's top-bar title
}
require('mp.options').read_options(options, 'playlist_sidebar')

-- TokyoNight, ASS colors are BGR
local BG, BG_ALPHA = '261B1A', '30'
local HOVER = '573428'
local FG, DIM, ACCENT = 'F5CAC0', '8C6A56', 'F7A27A'
local HEADER = 52

local overlay = mp.create_osd_overlay('ass-events')
local visible, pinned = false, false
local w, h, mx, my = 0, 0, -1, -1
local scroll, hover_row = 0, nil
local selected = nil -- keyboard cursor (playlist index, 1-based)
local offset, anim = 0, nil -- slide-in offset (px), animation timer

local function esc(s)
    return s:gsub('\\', '\\\226\129\160'):gsub('{', '\\{'):gsub('\n', ' ')
end

local function truncate(s, max)
    local out, n = {}, 0
    for ch in s:gmatch('[%z\1-\127\194-\244][\128-\191]*') do
        n = n + 1
        if n > max then return table.concat(out) .. '…' end
        out[n] = ch
    end
    return s
end

local function label(item)
    if item.title and item.title ~= '' then return item.title end
    local name = item.filename:match('([^/\\]+)$') or item.filename
    return (name:gsub('%.[%w]+$', ''))
end

-- ---------- Sorting ----------
local MODES = { 'name', 'date', 'size', 'length' }
local LABELS = { name = 'Name', date = 'Date', size = 'Size', length = 'Length' }
local SORT_FILE = mp.command_native({ 'expand-path', '~~state/playlist-sort' })
local sort = { mode = 'name', desc = false }
local durations, queue, probing, sorting = {}, {}, 0, false
local hover_btn = nil -- 'mode' | 'dir'

do
    local f = io.open(SORT_FILE, 'r')
    if f then
        local mode, desc = (f:read('*l') or ''):match('^(%a+)%s+(%a+)')
        f:close()
        if LABELS[mode] then sort.mode, sort.desc = mode, desc == 'desc' end
    end
end

local function save_sort()
    local dir = utils.split_path(SORT_FILE)
    mp.command_native({ name = 'subprocess', args = { 'mkdir', '-p', dir }, playback_only = false })
    local f = io.open(SORT_FILE, 'w')
    if f then f:write(sort.mode, ' ', sort.desc and 'desc' or 'asc', '\n'); f:close() end
end

local function abspath(f)
    if f:find('://') then return f end
    return mp.command_native({ 'normalize-path', f }) or f
end

local function natural(s)
    return s:lower():gsub('%d+', function(d) return ('0'):rep(math.max(0, 12 - #d)) .. d end)
end

local function sort_key(path)
    if sort.mode == 'length' then return durations[path] or 0 end
    if sort.mode == 'name' then return 0 end -- tie-breaker below does the work
    local info = utils.file_info(path)
    if not info then return 0 end
    return sort.mode == 'date' and info.mtime or info.size
end

local apply_sort, render

local function probe_next()
    while probing < 4 and #queue > 0 do
        local path = table.remove(queue, 1)
        probing = probing + 1
        mp.command_native_async({
            name = 'subprocess', playback_only = false, capture_stdout = true,
            args = { 'ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', path },
        }, function(ok, res)
            durations[path] = ok and tonumber(res.stdout) or 0
            probing = probing - 1
            if probing == 0 and #queue == 0 then apply_sort() else probe_next() end
        end)
    end
end

-- Returns true while durations are still being probed
local function need_lengths(list)
    for _, item in ipairs(list) do
        local path = abspath(item.filename)
        if durations[path] == nil then
            durations[path] = false
            if path:find('://') then durations[path] = 0 else queue[#queue + 1] = path end
        end
    end
    probe_next()
    return probing > 0 or #queue > 0
end

function apply_sort()
    local list = mp.get_property_native('playlist', {})
    if #list < 2 then return end
    if sort.mode == 'length' and need_lengths(list) then render(); return end

    local items = {}
    for i, item in ipairs(list) do
        local path = abspath(item.filename)
        items[i] = { file = item.filename, key = sort_key(path), name = natural(path:match('([^/]+)$') or path) }
    end
    table.sort(items, function(a, b)
        if a.key ~= b.key then
            if sort.desc then return a.key > b.key end
            return a.key < b.key
        end
        if sort.mode == 'name' and sort.desc then return a.name > b.name end
        return a.name < b.name
    end)

    -- Move entries into place, mirroring the moves on a local copy
    local current = {}
    for i, item in ipairs(list) do current[i] = item.filename end
    sorting = true
    for target, item in ipairs(items) do
        for from = target, #current do
            if current[from] == item.file then
                if from ~= target then
                    mp.commandv('playlist-move', from - 1, target - 1)
                    table.insert(current, target, table.remove(current, from))
                end
                break
            end
        end
    end
    sorting = false
    render()
end

local function cycle_mode()
    for i, m in ipairs(MODES) do
        if m == sort.mode then sort.mode = MODES[i % #MODES + 1]; break end
    end
    save_sort()
    apply_sort()
end

local function flip_direction()
    sort.desc = not sort.desc
    save_sort()
    apply_sort()
end

-- input.conf: KEY script-message-to playlist_sidebar sort length desc
mp.register_script_message('sort', function(mode, dir)
    if not LABELS[mode] then return end
    sort.mode, sort.desc = mode, dir == 'desc'
    save_sort()
    apply_sort()
end)

-- Header button hit zones (relative to the panel's right edge)
local function button_at(x, y)
    if y >= HEADER or x < w - options.width then return nil end
    if x >= w - 44 then return 'dir' end
    if x >= w - 150 then return 'mode' end
    return nil
end

local function rows_fit() return math.max(1, math.floor((h - HEADER - 8) / options.row_height)) end

local function clamp_scroll(count)
    scroll = math.max(0, math.min(scroll, count - rows_fit()))
end

local function rect(x1, y1, x2, y2, color, alpha)
    return string.format('{\\an7\\pos(0,0)\\bord0\\shad0\\1c&H%s&\\1a&H%s&\\p1}m %d %d l %d %d l %d %d l %d %d{\\p0}',
        color, alpha, x1, y1, x2, y1, x2, y2, x1, y2)
end

function render()
    if not visible or w == 0 then overlay:remove() return end
    local list = mp.get_property_native('playlist', {})
    local count = #list
    clamp_scroll(count)
    local x0 = w - options.width + offset
    local ev = { rect(x0, 0, w, h, BG, BG_ALPHA) }

    local pos = mp.get_property_number('playlist-pos', -1) + 1
    ev[#ev + 1] = string.format('{\\an4\\pos(%d,%d)\\fs%d\\b1\\bord0\\shad0\\1c&H%s&}Playlist{\\b0\\1c&H%s&}  %d / %d',
        x0 + 18, HEADER / 2, options.font_size + 2, FG, DIM, math.max(pos, 0), count)

    -- Sort button: [ ⇅ Name ][ ↑ ]
    local mode_label = LABELS[sort.mode] .. ((probing > 0 or #queue > 0) and '…' or '')
    local x1 = w - 150 + offset
    local x2 = w - 44 + offset
    if hover_btn == 'mode' then ev[#ev + 1] = rect(x1, 12, x2 - 4, HEADER - 12, HOVER, '20') end
    if hover_btn == 'dir' then ev[#ev + 1] = rect(x2, 12, w - 10 + offset, HEADER - 12, HOVER, '20') end
    ev[#ev + 1] = string.format('{\\an6\\pos(%d,%d)\\fs%d\\bord0\\shad0\\1c&H%s&}⇅ {\\1c&H%s&}%s',
        x2 - 12, HEADER / 2, options.font_size - 1, DIM, hover_btn == 'mode' and ACCENT or FG, mode_label)
    ev[#ev + 1] = string.format('{\\an5\\pos(%d,%d)\\fs%d\\bord0\\shad0\\1c&H%s&}%s',
        x2 + 17, HEADER / 2, options.font_size + 1, hover_btn == 'dir' and ACCENT or FG, sort.desc and '↓' or '↑')

    local max_chars = math.floor((options.width - 56) / (options.font_size * 0.52))
    for i = 1, math.min(rows_fit(), count - scroll) do
        local idx = i + scroll
        local y = HEADER + (i - 1) * options.row_height
        local current = idx == pos
        if idx == selected then
            ev[#ev + 1] = rect(x0 + 8, y, w - 8, y + options.row_height - 2, HOVER, '00')
        elseif idx == hover_row then
            ev[#ev + 1] = rect(x0 + 8, y, w - 8, y + options.row_height - 2, HOVER, '60')
        end
        if current then
            ev[#ev + 1] = rect(x0 + 8, y + 6, x0 + 11, y + options.row_height - 8, ACCENT, '00')
        end
        ev[#ev + 1] = string.format('{\\an4\\pos(%d,%d)\\fs%d\\bord0\\shad0\\1c&H%s&}%s{\\1c&H%s&}%s',
            x0 + 20, y + options.row_height / 2, options.font_size,
            DIM, string.format('%2d  ', idx),
            current and ACCENT or FG, esc(truncate(label(list[idx]), max_chars)))
    end

    overlay.res_x, overlay.res_y = w, h
    overlay.data = table.concat(ev, '\n')
    overlay:update()
end

local function row_at(x, y)
    if x < w - options.width or y < HEADER then return nil end
    local idx = math.floor((y - HEADER) / options.row_height) + 1 + scroll
    if idx > mp.get_property_number('playlist-count', 0) then return nil end
    return idx
end

local show, hide

local function on_click()
    local btn = button_at(mx, my)
    if btn == 'mode' then return cycle_mode() end
    if btn == 'dir' then return flip_direction() end
    local idx = row_at(mx, my)
    if idx then
        mp.commandv('playlist-play-index', idx - 1)
    elseif mx < w - options.width then
        pinned = false
        hide()
    end
end

local function on_wheel(dir)
    scroll = scroll + dir * 3
    hover_row = row_at(mx, my)
    render()
end

-- Keyboard: Up/Down move the cursor (list scrolls to follow), Enter plays it
local function move_selection(dir)
    local count = mp.get_property_number('playlist-count', 0)
    if count == 0 then return end
    selected = math.max(1, math.min(count, (selected or 1) + dir))
    if selected <= scroll then scroll = selected - 1 end
    if selected > scroll + rows_fit() then scroll = selected - rows_fit() end
    render()
end

local function play_selection()
    if selected then mp.commandv('playlist-play-index', selected - 1) end
end

local function animate()
    if anim then anim:kill() end
    offset = options.width
    anim = mp.add_periodic_timer(1 / 60, function()
        offset = math.floor(offset * 0.6)
        if offset <= 1 then offset = 0; anim:kill(); anim = nil end
        render()
    end)
end

function show()
    if visible then return end
    visible = true
    -- center current file in view
    scroll = mp.get_property_number('playlist-pos', 0) - math.floor(rows_fit() / 2)
    selected = mp.get_property_number('playlist-pos', 0) + 1
    mp.set_property_native('user-data/playlist_sidebar/width', options.width + options.title_gap)
    mp.add_forced_key_binding('UP', 'sidebar-key-up', function() move_selection(-1) end, { repeatable = true })
    mp.add_forced_key_binding('DOWN', 'sidebar-key-down', function() move_selection(1) end, { repeatable = true })
    mp.add_forced_key_binding('ENTER', 'sidebar-enter', play_selection)
    mp.add_forced_key_binding('KP_ENTER', 'sidebar-kp-enter', play_selection)
    mp.add_forced_key_binding('MBTN_LEFT', 'sidebar-click', on_click)
    mp.add_forced_key_binding('MBTN_LEFT_DBL', 'sidebar-dbl', function() end)
    mp.add_forced_key_binding('WHEEL_UP', 'sidebar-up', function() on_wheel(-1) end)
    mp.add_forced_key_binding('WHEEL_DOWN', 'sidebar-down', function() on_wheel(1) end)
    mp.add_forced_key_binding('ESC', 'sidebar-esc', function() pinned = false; hide() end)
    animate()
end

function hide()
    if not visible then return end
    visible, hover_row, selected = false, nil, nil
    mp.set_property_native('user-data/playlist_sidebar/width', 0)
    if anim then anim:kill(); anim = nil end
    for _, name in ipairs({ 'sidebar-click', 'sidebar-dbl', 'sidebar-up', 'sidebar-down', 'sidebar-esc',
        'sidebar-key-up', 'sidebar-key-down', 'sidebar-enter', 'sidebar-kp-enter' }) do
        mp.remove_key_binding(name)
    end
    overlay:remove()
end

mp.observe_property('osd-dimensions', 'native', function(_, d)
    if d then w, h = d.w, d.h end
    render()
end)

mp.observe_property('mouse-pos', 'native', function(_, m)
    if not m then return end
    mx, my = m.x, m.y
    if not m.hover then
        if not pinned then hide() end
        return
    end
    if not visible then
        if w > 0 and mx >= w - options.edge
            and mp.get_property_number('playlist-count', 0) >= options.min_items then
            show()
        end
        return
    end
    if not pinned and mx < w - options.width - 20 then
        hide()
        return
    end
    local r, b = row_at(mx, my), button_at(mx, my)
    if r ~= hover_row or b ~= hover_btn then hover_row, hover_btn = r, b; render() end
end)

-- Re-apply the saved sort when a new playlist appears (e.g. folder autoload).
-- mpv's own order is already name ascending, so skip that case.
local last_count = 0
mp.observe_property('playlist-count', 'number', function(_, count)
    if sorting or not count or count == last_count then return end
    last_count = count
    if count >= 2 and (sort.mode ~= 'name' or sort.desc) then apply_sort() end
end)

mp.observe_property('playlist', 'native', function() if visible then render() end end)
mp.observe_property('playlist-pos', 'number', function() if visible then render() end end)

mp.add_key_binding(nil, 'toggle', function()
    if visible then
        pinned = false
        hide()
    else
        pinned = true
        show()
    end
end)
