local visuals_tab = menu.add_tab("Scripts", "Visuals")

local ind_group  = visuals_tab:add_child("Crosshair Indicators", 200, 200)
ind_group:add_checkbox("Enable",     "lua_ind_enable")
ind_group:add_checkbox("Min Damage", "lua_ind_md")
ind_group:add_checkbox("Hitchance",  "lua_ind_hc")

local ctrl_enable = menu.find_control("::Scripts::Visuals::Crosshair Indicators checkbox:Enable")
local ctrl_md     = menu.find_control("::Scripts::Visuals::Crosshair Indicators checkbox:Min Damage")
local ctrl_hc     = menu.find_control("::Scripts::Visuals::Crosshair Indicators checkbox:Hitchance")

local md_ref     = menu.find_control("::Aimbot::Rage::SSG 08::General sliderint:Mindamage")
local md_default = md_ref and md_ref:get() or nil
local hc_ref     = menu.find_control("::Aimbot::Rage::SSG 08::General sliderint:Hitchance")
local hc_default = hc_ref and hc_ref:get() or nil

local screen = util.get_screen_size()
local sw, sh = screen.x, screen.y
local gvars  = globals()

local font = renderer.create_font_from_file("C:/Windows/Fonts/segoeui.ttf", 13, 0)
if not font then
    font = renderer.create_font_from_file("C:/Windows/Fonts/arial.ttf", 13, 0)
end

local f_scale = 1.0
local line_h  = 13

local char_width = {
    ["|"]=0.22,["!"]=0.28,["."]=0.28,[","]=0.28,[";"]=0.28,[":"]=0.28,
    ["'"]=0.28,["`"]=0.28,["1"]=0.38,["i"]=0.32,["j"]=0.32,["l"]=0.32,
    [" "]=0.28,["-"]=0.38,["r"]=0.42,["t"]=0.44,["f"]=0.44,["I"]=0.38,
    ["a"]=0.56,["b"]=0.58,["c"]=0.52,["d"]=0.58,["e"]=0.56,["g"]=0.58,
    ["h"]=0.58,["k"]=0.54,["n"]=0.58,["o"]=0.58,["p"]=0.58,["q"]=0.58,
    ["s"]=0.50,["u"]=0.58,["v"]=0.54,["x"]=0.54,["y"]=0.54,["z"]=0.52,
    ["A"]=0.64,["B"]=0.62,["C"]=0.62,["D"]=0.66,["E"]=0.58,["F"]=0.54,
    ["G"]=0.66,["H"]=0.66,["J"]=0.44,["K"]=0.62,["L"]=0.54,["N"]=0.66,
    ["O"]=0.70,["P"]=0.60,["Q"]=0.70,["R"]=0.64,["S"]=0.58,["T"]=0.58,
    ["U"]=0.66,["V"]=0.64,["X"]=0.62,["Y"]=0.60,["Z"]=0.60,
    ["w"]=0.82,["m"]=0.84,["W"]=0.88,["M"]=0.88,["@"]=1.0,
}

local FONT_SIZE = 11.7
local tw_cache  = {}
local function text_width(str)
    if tw_cache[str] then return tw_cache[str] end
    local w = 0
    for i = 1, #str do w = w + (char_width[str:sub(i,i)] or 0.58) end
    tw_cache[str] = w * FONT_SIZE
    return tw_cache[str]
end

local COL_NORMAL = { 220, 220, 220, 200 }
local COL_CHANGE = { 255, 255, 255, 255 }
local COL_ACCENT = color.new(180, 120, 220, 180)
local COL_CLUB   = color.new(233, 143, 255, 255)

local FADE_SPEED = 6.0
local function lerp(a, b, t) return a + (b - a) * t end

local function step_color(cur, dt, target)
    local s = math.min(FADE_SPEED * dt, 1.0)
    for i = 1, 4 do cur[i] = lerp(cur[i], target[i], s) end
end

local function get_color(cur)
    return color.new(math.floor(cur[1]), math.floor(cur[2]),
                     math.floor(cur[3]), math.floor(cur[4]))
end

local CHARS        = "abcdefghijklmnopqrstuvwxyz"
local SETTLE_DELAY = 0.1
local REPEAT_EVERY = 5.0
local club_target   = "club"
local club_display  = "club"
local scrambling    = false
local settle_timers = {}
local repeat_t      = 0

local function rand_char()
    local i = math.random(1, #CHARS)
    return CHARS:sub(i, i)
end

local function start_scramble()
    scrambling = true
    settle_timers = {}
    for i = 1, #club_target do settle_timers[i] = SETTLE_DELAY * i end
end

local function update_scramble(dt)
    if not scrambling then
        repeat_t = repeat_t + dt
        if repeat_t >= REPEAT_EVERY then repeat_t = 0; start_scramble() end
        return
    end
    local result, all_done = "", true
    for i = 1, #club_target do
        settle_timers[i] = settle_timers[i] - dt
        if settle_timers[i] <= 0 then
            result = result .. club_target:sub(i, i)
        else
            all_done = false
            result   = result .. rand_char()
        end
    end
    club_display = result
    if all_done then club_display = club_target; scrambling = false end
end

local SPEED = 300.0

local function make_val() return { displayed = nil, target = nil, prev = nil } end

local function update_val(v, dt)
    if v.displayed == nil or v.displayed == v.target then return end
    local diff = v.target - v.displayed
    local step = SPEED * dt
    if math.abs(diff) <= step then v.displayed = v.target
    else v.displayed = v.displayed + (diff > 0 and step or -step) end
end

local function sync_val(v, ref)
    if not ref then return end
    local val = ref:get()
    if v.prev == nil then
        v.displayed = val; v.target = val; v.prev = val
    elseif val ~= v.prev then
        v.target = val; v.prev = val
    end
end

local md_val = make_val()
local hc_val = make_val()
local md_cur = { 220, 220, 220, 200 }
local hc_cur = { 220, 220, 220, 200 }

local init_t    = 0
local init_done = false

local function on_render_start()
    local dt = gvars.frametime

    if not init_done then
        init_t = init_t + dt
        if init_t >= 0.3 then start_scramble(); init_done = true end
    end
    update_scramble(dt)

    local in_game = game.is_in_game()
    local lp      = in_game and entity_list.get_local_player() or nil
    local alive   = lp ~= nil and lp:is_alive() or false

    if not alive then return end

    local base_x = sw / 2 + 5
    local base_y = sh / 2 + 5

    if ctrl_enable:get() then
        local prefix_px = text_width("monolith.")
        renderer.add_text(vec2.new(base_x, base_y), COL_ACCENT, f_scale, 0, "monolith.", font)
        renderer.add_text(vec2.new(base_x + prefix_px, base_y), COL_CLUB, f_scale, 0, club_display, font)

        local row = 1

        if ctrl_md:get() then
            sync_val(md_val, md_ref)
            update_val(md_val, dt)
            step_color(md_cur, dt, (md_default ~= nil and md_val.prev ~= md_default) and COL_CHANGE or COL_NORMAL)
            if md_val.displayed ~= nil then
                renderer.add_text(vec2.new(base_x, base_y + row * line_h),
                    get_color(md_cur), f_scale, 0,
                    "md   " .. tostring(math.floor(md_val.displayed + 0.5)), font)
                row = row + 1
            end
        end

        if ctrl_hc:get() then
            sync_val(hc_val, hc_ref)
            update_val(hc_val, dt)
            step_color(hc_cur, dt, (hc_default ~= nil and hc_val.prev ~= hc_default) and COL_CHANGE or COL_NORMAL)
            if hc_val.displayed ~= nil then
                renderer.add_text(vec2.new(base_x, base_y + row * line_h),
                    get_color(hc_cur), f_scale, 0,
                    "hc   " .. tostring(math.floor(hc_val.displayed + 0.5)), font)
            end
        end
    end
end

client.add_callback("on_render_start", on_render_start)

client.add_callback("on_unload", function()
    game.client_cmd("echo [Indicators] unloaded")
end)

game.client_cmd("echo [Indicators] loaded")
