local visuals_tab = menu.add_tab("Scripts", "Visuals")

local ind_group = visuals_tab:add_child("Crosshair Indicators", 200, 200)
local ctrl_enable, val_enable = ind_group:add_checkbox("Enable",     "lua_ind_enable")
local ctrl_md,     val_md     = ind_group:add_checkbox("Min Damage", "lua_ind_md")
local ctrl_hc,     val_hc     = ind_group:add_checkbox("Hitchance",  "lua_ind_hc")

local function update_visibility()
    local enabled = val_enable:get() == true
    ctrl_md:set_should_show(enabled)
    ctrl_hc:set_should_show(enabled)
end
update_visibility()
ctrl_enable:add_callback(update_visibility)

local cheat_md = menu.find_control("::Aimbot::Rage::SSG 08::General sliderint:Mindamage")
local cheat_hc = menu.find_control("::Aimbot::Rage::SSG 08::General sliderint:Hitchance")

local font = renderer.create_font_from_file("C:/Windows/Fonts/segoeui.ttf", 15, 0)
if not font then
    font = renderer.create_font_from_file("C:/Windows/Fonts/arial.ttf", 15, 0)
end

local line_h = 15

local COL_NORMAL = { 220, 220, 220, 200 }
local COL_ACCENT = color(180, 120, 220, 180)
local COL_CLUB   = color(233, 143, 255, 255)

local FADE_SPEED = 6.0
local function lerp(a, b, t) return a + (b - a) * t end

local function step_color(cur, dt, target)
    local s = math.min(FADE_SPEED * dt, 1.0)
    for i = 1, 4 do cur[i] = lerp(cur[i], target[i], s) end
end

local function get_color(cur)
    return color(math.floor(cur[1]), math.floor(cur[2]),
                 math.floor(cur[3]), math.floor(cur[4]))
end

local CHARS         = "abcdefghijklmnopqrstuvwxyz"
local SETTLE_DELAY  = 0.1
local REPEAT_EVERY  = 5.0
local club_target   = "club"
local club_display  = "club"
local scrambling    = false
local settle_timers = {}
local repeat_t      = 0

local function start_scramble()
    scrambling = true
    settle_timers = {}
    for i = 1, #club_target do
        settle_timers[i] = SETTLE_DELAY * i
    end
end

local function update_scramble(dt)
    if not scrambling then
        repeat_t = repeat_t + dt
        if repeat_t >= REPEAT_EVERY then
            repeat_t = 0
            start_scramble()
        end
        return
    end
    local result, all_done = "", true
    for i = 1, #club_target do
        settle_timers[i] = settle_timers[i] - dt
        if settle_timers[i] <= 0 then
            result = result .. club_target:sub(i, i)
        else
            all_done = false
            local ri = math.random(1, #CHARS)
            result = result .. CHARS:sub(ri, ri)
        end
    end
    club_display = result
    if all_done then
        club_display = club_target
        scrambling = false
    end
end

local SPEED = 300.0
local function make_val() return { displayed = nil, target = nil, prev = nil } end

local function update_val(v, dt)
    if v.displayed == nil or v.displayed == v.target then return end
    local diff = v.target - v.displayed
    local step = SPEED * dt
    if math.abs(diff) <= step then
        v.displayed = v.target
    else
        v.displayed = v.displayed + (diff > 0 and step or -step)
    end
end

local function sync_val(v, new_val)
    if new_val == nil then return end
    if v.prev == nil then
        v.displayed = new_val; v.target = new_val; v.prev = new_val
    elseif new_val ~= v.prev then
        v.target = new_val; v.prev = new_val
    end
end

local md_val = make_val()
local hc_val = make_val()
local md_cur = { 220, 220, 220, 200 }
local hc_cur = { 220, 220, 220, 200 }

local prefix_w = nil

local init_t    = 0
local init_done = false

client.add_callback("on_paint", function()
    local dt = math.min(renderer.get_frametime(), 0.05)

    if not init_done then
        init_t = init_t + dt
        if init_t >= 0.3 then start_scramble(); init_done = true end
    end
    update_scramble(dt)

    if not game.is_in_game() then return end
    local lp = entity_list.get_local_player()
    if not lp then return end
    if not lp.m_iHealth or lp.m_iHealth <= 0 then return end
    if not val_enable:get() then return end

    local screen = renderer.get_screen_size()
    local base_x = screen.x / 2 + 5
    local base_y = screen.y / 2 + 5

    if not prefix_w then
        local sz = renderer.get_text_size("monolith.", font)
        prefix_w = sz.x
    end

    renderer.add_text(vec2(base_x,            base_y), COL_ACCENT, "monolith.", font)
    renderer.add_text(vec2(base_x + prefix_w, base_y), COL_CLUB,   club_display, font)

    local row = 1

    if val_md:get() and cheat_md then
        local raw = cheat_md:get()
        if raw ~= nil then
            sync_val(md_val, raw)
            update_val(md_val, dt)
            step_color(md_cur, dt, COL_NORMAL)
            renderer.add_text(
                vec2(base_x, base_y + row * line_h),
                get_color(md_cur),
                "md   " .. tostring(math.floor(md_val.displayed + 0.5)),
                font)
            row = row + 1
        end
    end

    if val_hc:get() and cheat_hc then
        local raw = cheat_hc:get()
        if raw ~= nil then
            sync_val(hc_val, raw)
            update_val(hc_val, dt)
            step_color(hc_cur, dt, COL_NORMAL)
            renderer.add_text(
                vec2(base_x, base_y + row * line_h),
                get_color(hc_cur),
                "hc   " .. tostring(math.floor(hc_val.displayed + 0.5)),
                font)
        end
    end
end)

client.add_callback("on_unload", function()
    client.log("[Indicators] unloaded")
end)

client.log("[Indicators] loaded")
