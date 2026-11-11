-- Live subtitle styling through a uosc menu: font, weight, size, color, border,
-- shadow, position, letter spacing and (optional) word spacing.
-- Bound in input.conf: script-binding sub_style/menu
-- Style is saved to ~~state/sub-style.json and restored on startup.
--
-- Weights are picked by the face's full name (e.g. "MonoLisa Light"), which
-- libass matches exactly, so sub-bold stays off.
--
-- mpv has no word-spacing option. "Word spacing mode" hides the native subs and
-- redraws sub-text in an OSD overlay where every space gets extra \fsp. The
-- subtitle file's own styling (italics, colors, positioning) is lost while on.

local mp = require 'mp'
local utils = require 'mp.utils'
local input = require 'mp.input'

local state_path = mp.command_native({ 'expand-path', '~~state/sub-style.json' })
local MENU = 'sub-style'

local COLORS = {
    { 'White', '#FFFFFF' }, { 'Off-white', '#E6E6E6' }, { 'Yellow', '#FFE14D' },
    { 'Soft yellow', '#F5E6A3' }, { 'Cyan', '#7DCFFF' }, { 'Green', '#9ECE6A' },
    { 'Pink', '#F7768E' }, { 'Lavender', '#C0CAF5' }, { 'Black', '#000000' },
    { 'Dark gray', '#1A1B26' },
}

-- Defaults mirror mpv's own sub-* defaults.
local DEFAULT = {
    family = 'sans-serif', face = '', size = 55, color = '#FFFFFF',
    border = 3, border_color = '#000000', shadow = 0, shadow_color = '#000000',
    pos = 100, margin_y = 22, align_x = 'center', align_y = 'bottom',
    spacing = 0, word_spacing = 0, word_mode = false, override = false,
}

-- Numeric settings adjusted with left/right (shift = fine step) in the menu.
local NUMERIC = {
    size = { title = 'Size', step = 2, fine = 1, min = 10, max = 150 },
    border = { title = 'Border', step = 0.5, fine = 0.1, min = 0, max = 10 },
    shadow = { title = 'Shadow', step = 0.5, fine = 0.1, min = 0, max = 10 },
    pos = { title = 'Vertical position', step = 2, fine = 1, min = 0, max = 150, unit = '%' },
    margin_y = { title = 'Edge margin', step = 4, fine = 1, min = 0, max = 300 },
    spacing = { title = 'Letter spacing', step = 0.5, fine = 0.1, min = -10, max = 30 },
    word_spacing = { title = 'Word spacing', step = 2, fine = 0.5, min = 0, max = 100 },
}

local style = {}
for k, v in pairs(DEFAULT) do style[k] = v end

local fonts -- family -> { {style=, fullname=, weight=, italic=}, ... }, sorted
local family_names

local function load_fonts()
    if fonts then return end
    fonts, family_names = {}, {}
    local res = mp.command_native({
        name = 'subprocess', capture_stdout = true, playback_only = false,
        args = { 'fc-list', '--format', '%{family[0]}\t%{style[0]}\t%{fullname[0]}\t%{weight}\t%{slant}\t%{variable}\n' },
    })
    local seen = {}
    for line in (res.stdout or ''):gmatch('[^\n]+') do
        local fam, sty, full, weight, slant, var = line:match('^(.-)\t(.-)\t(.-)\t(.-)\t(.-)\t(.-)$')
        if fam and fam ~= '' and full ~= '' and var ~= 'True' and not seen[full] then
            seen[full] = true
            if not fonts[fam] then
                fonts[fam] = {}
                family_names[#family_names + 1] = fam
            end
            table.insert(fonts[fam], {
                style = sty, fullname = full,
                weight = tonumber(weight) or 80, italic = (tonumber(slant) or 0) > 0,
            })
        end
    end
    table.sort(family_names, function(a, b) return a:lower() < b:lower() end)
    for _, faces in pairs(fonts) do
        table.sort(faces, function(a, b)
            if a.italic ~= b.italic then return not a.italic end
            return a.weight < b.weight
        end)
    end
end

local function face_label()
    if style.face == '' then return 'Regular' end
    for _, f in ipairs((fonts and fonts[style.family]) or {}) do
        if f.fullname == style.face then return f.style end
    end
    return style.face
end

-- Native subtitle properties --------------------------------------------------

local overlay = mp.create_osd_overlay('ass-events')
local word_mode_applied = false

local function hex_to_ass(hex)
    local r, g, b = hex:match('#(%x%x)(%x%x)(%x%x)')
    return string.format('&H%s%s%s&', b, g, r)
end

local function ass_escape(s)
    return s:gsub('\\', '\\\226\129\160'):gsub('{', '\\{'):gsub('\n', '\\N')
end

local function draw_overlay()
    local text = style.word_mode and mp.get_property('sub-text') or ''
    if text == '' then
        overlay:remove()
        return
    end
    local dim = mp.get_property_native('osd-dimensions')
    if not dim or dim.h == 0 then return end
    -- mpv scales subtitle sizes against a 720px-tall canvas.
    local res_y = 720
    local res_x = math.floor(res_y * dim.w / dim.h)
    local an = ({ left = 1, center = 2, right = 3 })[style.align_x]
    local x = ({ left = 25, center = res_x / 2, right = res_x - 25 })[style.align_x]
    local y
    if style.align_y == 'top' then
        an, y = an + 6, style.margin_y
    elseif style.align_y == 'center' then
        an, y = an + 3, res_y / 2
    else
        y = res_y * style.pos / 100 - style.margin_y
    end
    local base = string.format(
        '{\\an%d\\pos(%d,%d)\\fn%s\\fs%s\\fsp%s\\1c%s\\3c%s\\4c%s\\bord%s\\shad%s\\b0\\q2}',
        an, x, y, style.face ~= '' and style.face or style.family, style.size, style.spacing,
        hex_to_ass(style.color), hex_to_ass(style.border_color), hex_to_ass(style.shadow_color),
        style.border, style.shadow)
    local wide = string.format('{\\fsp%s} {\\fsp%s}', style.spacing + style.word_spacing, style.spacing)
    overlay.res_x, overlay.res_y = res_x, res_y
    overlay.data = base .. ass_escape(text):gsub(' ', wide)
    overlay:update()
end

local function apply()
    mp.set_property('sub-font', style.face ~= '' and style.face or style.family)
    mp.set_property('sub-bold', 'no')
    mp.set_property('sub-italic', 'no')
    mp.set_property_number('sub-font-size', style.size)
    mp.set_property('sub-color', style.color)
    mp.set_property_number('sub-border-size', style.border)
    mp.set_property('sub-border-color', style.border_color)
    mp.set_property_number('sub-shadow-offset', style.shadow)
    mp.set_property('sub-shadow-color', style.shadow_color)
    mp.set_property_number('sub-pos', style.pos)
    mp.set_property_number('sub-margin-y', style.margin_y)
    mp.set_property('sub-align-x', style.align_x)
    mp.set_property('sub-align-y', style.align_y)
    mp.set_property_number('sub-spacing', style.spacing)
    mp.set_property('sub-ass-override', style.override and 'force' or 'yes')
    -- Word mode draws the primary subtitle itself, so the native one is hidden.
    -- Only touched when the mode flips, so a manual hide (Alt+h) survives edits.
    if style.word_mode ~= word_mode_applied then
        mp.set_property('sub-visibility', style.word_mode and 'no' or 'yes')
        word_mode_applied = style.word_mode
    end
    draw_overlay()
end

-- Persistence ------------------------------------------------------------------

local function save()
    local dir = utils.split_path(state_path)
    mp.command_native({ name = 'subprocess', args = { 'mkdir', '-p', dir }, playback_only = false })
    local f = io.open(state_path, 'w')
    if not f then return end
    f:write(utils.format_json(style))
    f:close()
end
local save_timer = mp.add_timeout(1, save, true)

local function changed()
    apply()
    save_timer:kill()
    save_timer:resume()
end

do
    local f = io.open(state_path, 'r')
    if f then
        local saved = utils.parse_json(f:read('*a') or '')
        f:close()
        if type(saved) == 'table' then
            for k, v in pairs(saved) do
                if DEFAULT[k] ~= nil and type(v) == type(DEFAULT[k]) then style[k] = v end
            end
        end
    end
end

-- These are restored per file by watch_later and would undo the global style.
for _, opt in ipairs({ 'sub-pos', 'sub-ass-override', 'sub-visibility' }) do
    mp.commandv('change-list', 'watch-later-options', 'remove', opt)
end

apply()
mp.register_event('shutdown', function()
    save_timer:kill()
    save()
end)
mp.observe_property('sub-text', 'string', draw_overlay)
mp.observe_property('osd-dimensions', 'native', draw_overlay)

-- Menu -------------------------------------------------------------------------

local function fmt(v) return (string.format('%.1f', v):gsub('%.0$', '')) end

local function color_menu(title, key)
    local items = {}
    for _, c in ipairs(COLORS) do
        items[#items + 1] = { title = c[1], hint = c[2], value = { 'set', key, c[2] }, active = style[key] == c[2] }
    end
    items[#items + 1] = { title = 'Custom hex…', value = { 'hex', key } }
    return { title = title, hint = style[key], items = items }
end

local function numeric_item(key)
    local n = NUMERIC[key]
    return {
        title = n.title, hint = fmt(style[key]) .. (n.unit or ''), value = { 'num', key },
        actions = { { name = 'dec', icon = 'remove', label = 'Decrease (←)' }, { name = 'inc', icon = 'add', label = 'Increase (→)' } },
        actions_place = 'inside',
    }
end

local function choice_menu(title, key, choices)
    local items, hint = {}, style[key]
    for _, c in ipairs(choices) do
        items[#items + 1] = { title = c[1], value = { 'set', key, c[2] }, active = style[key] == c[2] }
        if style[key] == c[2] then hint = c[1] end
    end
    return { title = title, hint = hint, items = items }
end

local function build_menu()
    load_fonts()
    local font_items = { { title = 'Default (sans-serif)', value = { 'family', 'sans-serif' }, active = style.family == 'sans-serif' } }
    for _, fam in ipairs(family_names) do
        font_items[#font_items + 1] = { title = fam, hint = #fonts[fam] .. ' styles', value = { 'family', fam }, active = style.family == fam }
    end
    local weight_items = { { title = 'Regular (family default)', value = { 'face', '' }, active = style.face == '' } }
    for _, f in ipairs(fonts[style.family] or {}) do
        weight_items[#weight_items + 1] = { title = f.style, hint = f.fullname, value = { 'face', f.fullname }, active = style.face == f.fullname }
    end

    local items = {
        { title = 'Font', hint = style.family, items = font_items, search_style = 'on_demand' },
        { title = 'Weight', hint = face_label(), items = weight_items },
        numeric_item('size'),
        color_menu('Color', 'color'),
        numeric_item('border'),
        color_menu('Border color', 'border_color'),
        numeric_item('shadow'),
        color_menu('Shadow color', 'shadow_color'),
        choice_menu('Alignment', 'align_y', { { 'Bottom', 'bottom' }, { 'Middle', 'center' }, { 'Top', 'top' } }),
        choice_menu('Horizontal', 'align_x', { { 'Left', 'left' }, { 'Center', 'center' }, { 'Right', 'right' } }),
        numeric_item('pos'),
        numeric_item('margin_y'),
        numeric_item('spacing'),
        { title = 'Word spacing mode', hint = style.word_mode and 'on' or 'off', value = { 'toggle', 'word_mode' }, active = style.word_mode },
    }
    if style.word_mode then items[#items + 1] = numeric_item('word_spacing') end
    items[#items + 1] = { title = 'Force on styled (ASS) subs', hint = style.override and 'on' or 'off', value = { 'toggle', 'override' }, active = style.override }
    items[#items + 1] = { title = 'Reset to defaults', value = { 'reset' }, muted = true }

    return {
        type = MENU, title = 'Subtitle style', items = items, keep_open = true,
        callback = { mp.get_script_name(), 'menu-event' },
        footnote = '←/→ adjust · shift+←/→ fine · enter resets a value',
    }
end

local function refresh()
    mp.commandv('script-message-to', 'uosc', 'update-menu', utils.format_json(build_menu()))
end

local function nudge(key, dir, fine)
    local n = NUMERIC[key]
    local v = style[key] + dir * (fine and n.fine or n.step)
    style[key] = math.max(n.min, math.min(n.max, math.floor(v * 10 + 0.5) / 10))
    mp.osd_message(n.title .. '  ' .. fmt(style[key]) .. (n.unit or ''))
end

local function handle(value, action, fine)
    if type(value) ~= 'table' then return end
    local kind, key, arg = value[1], value[2], value[3]
    if kind == 'num' then
        if action == 'inc' or action == 'dec' then
            nudge(key, action == 'inc' and 1 or -1, fine)
        else
            style[key] = DEFAULT[key]
        end
    elseif kind == 'set' then
        style[key] = arg
    elseif kind == 'family' then
        style.family, style.face = key, ''
    elseif kind == 'face' then
        style.face = key
    elseif kind == 'toggle' then
        style[key] = not style[key]
    elseif kind == 'reset' then
        for k, v in pairs(DEFAULT) do style[k] = v end
    elseif kind == 'hex' then
        input.get({
            prompt = 'Hex color (#RRGGBB):', default_text = style[key],
            submit = function(text)
                input.terminate()
                text = text:gsub('%s', ''):upper()
                if not text:match('^#') then text = '#' .. text end
                if text:match('^#%x%x%x%x%x%x$') then
                    style[key] = text
                    changed()
                    refresh()
                else
                    mp.osd_message('Invalid color: ' .. text)
                end
            end,
        })
        return
    end
    changed()
    refresh()
end

mp.register_script_message('menu-event', function(json)
    local e = utils.parse_json(json)
    if not e then return end
    if e.type == 'activate' then
        handle(e.value, e.action, e.shift)
    elseif e.type == 'key' and (e.key == 'left' or e.key == 'right') and e.selected_item then
        local v = e.selected_item.value
        if type(v) == 'table' and v[1] == 'num' then
            handle(v, e.key == 'right' and 'inc' or 'dec', e.modifiers == 'shift')
        end
    end
end)

mp.add_key_binding(nil, 'menu', function()
    local json = utils.format_json(build_menu())
    mp.commandv('script-message-to', 'uosc', 'open-menu', json)
end)
