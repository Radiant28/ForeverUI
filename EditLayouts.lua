local _, ui = ...

-- Layout presets for Edit Mode. The geometry is pure: EditMode.lua measures the frames and applies the result.
--
-- Measures m[key] (UIParent units): shown, w/h = size of the visible content, ox/oy = content offset from the
-- frame's left/bottom edge, fw/fh = frame size, scale = frame scale.
-- Result out[key]: left/bottom = frame position, width/height = frame size; resizeWidth for the XP bars.
local GAP, MARGIN, SIDE = 4, 6, 10

-- Retail arrangement: XP bar at the very bottom, the main bar and the two bottom bars stacked above it and
-- centred, stance/pet/totem bars on top of the stack, the micro menu in the bottom-right corner with the bags above it.
function ui.ComputeRetailLayout(m, screenWidth)
    local out = {}
    local center = screenWidth / 2
    local stackWidth = 0
    for _, key in ipairs({ "main", "bl", "br" }) do
        local entry = m[key]
        if entry and (key == "main" or entry.shown) and entry.w > 0 then stackWidth = math.max(stackWidth, entry.w) end
    end
    if stackWidth == 0 then return out end

    local function place(key, contentLeft, contentBottom, scale)
        local entry = m[key]
        local k = scale and scale / entry.scale or 1
        out[key] = {
            left = contentLeft - entry.ox * k, bottom = contentBottom - entry.oy * k,
            width = entry.fw * k, height = entry.fh * k, scale = scale,
        }
        return entry.h * k
    end

    local y = MARGIN
    local barHeight = 0
    -- The XP bar is resized to the stack width (never scaled, so its text keeps its size).
    for _, key in ipairs({ "xp", "xpMax" }) do
        local entry = m[key]
        if entry then
            out[key] = { left = center - stackWidth / 2, bottom = y, width = stackWidth, height = entry.h,
                resizeWidth = stackWidth }
            if entry.shown or barHeight == 0 then barHeight = entry.h end
        end
    end
    if barHeight > 0 then y = y + barHeight + GAP end

    for _, key in ipairs({ "main", "bl", "br" }) do
        local entry = m[key]
        if entry and entry.w > 0 and (key == "main" or entry.shown) then
            y = y + place(key, center - entry.w / 2, y) + GAP
        end
    end

    if m.stance and m.stance.w > 0 then place("stance", center - stackWidth / 2, y) end
    if m.pet and m.pet.w > 0 then place("pet", center + stackWidth / 2 - m.pet.w, y) end
    if m.totem and m.totem.w > 0 then place("totem", center - m.totem.w / 2, y) end

    -- Bottom-right corner: the micro menu on the bottom edge, the bag bar right above it.
    local right = screenWidth - SIDE
    local bagBottom = MARGIN
    if m.micro and m.micro.w > 0 then
        place("micro", right - m.micro.w, MARGIN)
        bagBottom = MARGIN + m.micro.h + GAP
    end
    if m.bags and m.bags.w > 0 then place("bags", right - m.bags.w, bagBottom) end
    return out
end

-- Grid for an action bar of up to 12 buttons. Returns cols and, per button index, its offset from the first
-- button (x grows right, or left when `leftward`; y grows up for horizontal bars and down for vertical ones).
-- Indexes above `count` are absent: those buttons are parked off screen.
function ui.ComputeBarGrid(count, rows, vertical, leftward, step)
    count = math.max(1, math.min(12, math.floor(count or 12)))
    rows = math.max(1, math.min(count, math.floor(rows or 1)))
    local cols = math.ceil(count / rows)
    local offsets = {}
    for index = 1, count do
        local row, col = math.floor((index - 1) / cols), (index - 1) % cols
        local x = col * step * (leftward and -1 or 1)
        offsets[index] = { x = x, y = vertical and -row * step or row * step }
    end
    return cols, offsets, count, rows
end
