local _, ui = ...
local Cursor = {}
ui.cursor = Cursor

Cursor.defaults = {
    outlineEnabled = true, trailEnabled = true, outlineStyle = "ring", trailStyle = "smooth", mode = "always",
    size = 36, thickness = 2, outlineAlpha = 0.85, glow = 0.45, softness = 3, offsetX = 0, offsetY = 0,
    outlineR = 0.85, outlineG = 0.72, outlineB = 0.42,
    width = 16, trailAlpha = 0.55, length = 400, lifetime = 0.55, fade = 1.5, taper = 0.8,
    edge = 1, density = 0.8, smoke = 0.65, trailR = 0.35, trailG = 0.75, trailB = 1,
}
Cursor.ranges = {
    size = {16, 100, 1}, thickness = {1, 8, 0.5}, outlineAlpha = {0, 1, 0.05},
    glow = {0, 1, 0.05}, softness = {0, 12, 0.5}, offsetX = {-60, 60, 1}, offsetY = {-60, 60, 1},
    width = {4, 60, 1}, trailAlpha = {0, 1, 0.05}, length = {40, 1200, 10}, lifetime = {0.1, 3, 0.05},
    fade = {0.5, 4, 0.1}, taper = {0, 1, 0.05}, edge = {0, 1, 0.5},
    density = {0.1, 1, 0.05}, smoke = {0, 1, 0.05},
}
Cursor.choices = {outlineStyle = {ring = true, halo = true, arrow = true},
    trailStyle = {smooth = true, smoke = true}, mode = {always = true, combat = true, peace = true}}
local colors = {"outlineR", "outlineG", "outlineB", "trailR", "trailG", "trailB"}
for _, key in ipairs(colors) do Cursor.ranges[key] = {0, 1, 0.01} end

local sqrt, abs, min, max = math.sqrt, math.abs, math.min, math.max
local path = "Interface\\AddOns\\ForeverUI\\Art\\Cursor\\"
local images = {}
for _, name in ipairs({"beam-hard.tga", "beam-medium.tga", "beam-soft.tga", "smoke.tga"}) do images[name] = path .. name end
local MAX_POINTS = 256
local points, beams, outlines = {}, {}, {}
local head, count, used = 0, 0, 0
local tip = {}
local lastX, lastY, lastScale
local db, standalone
local root = CreateFrame("Frame", "ForeverStockCursorEffects", UIParent)
root:SetAllPoints(UIParent)
root:SetFrameStrata("TOOLTIP")
root:SetFrameLevel(100)
root:EnableMouse(false)
root:Hide()

local function NewTexture(layer)
    local tex = root:CreateTexture(nil, layer or "ARTWORK")
    tex:SetBlendMode("BLEND")
    tex:Hide()
    return tex
end
local halo = NewTexture("OVERLAY")
halo:SetTexture(path .. "halo.tga")

local function Clear()
    head, count, used = 0, 0, 0
    lastX, lastY, lastScale = nil, nil, nil
    halo:Hide()
    for _, pair in ipairs(beams) do pair[1]:Hide(); pair[2]:Hide() end
    for _, pair in ipairs(outlines) do pair[1]:Hide(); pair[2]:Hide() end
end

-- Inverse UV mapping draws rotated strips using the 3.3.5 texture API.
local function Beam(tex, x1, y1, x2, y2, width, r, g, b, alpha, image, overlap)
    local dx, dy = x2 - x1, y2 - y1
    local distance = sqrt(dx * dx + dy * dy)
    if distance < 0.01 or width < 0.05 or alpha <= 0.001 then tex:Hide(); return end
    local c, s = dx / distance, dy / distance
    local length = distance + (overlap or 0)
    local w, h = abs(c) * length + abs(s) * width, abs(s) * length + abs(c) * width
    local ux, uy = c * w / (2 * length), s * h / (2 * length)
    local vx, vy = s * w / (2 * width), c * h / (2 * width)
    if tex.cursorUZImage ~= image then
        tex:SetTexture(images[image])
        tex.cursorUZImage = image
    end
    tex:SetSize(w, h)
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", root, "BOTTOMLEFT", (x1 + x2) / 2, (y1 + y2) / 2)
    tex:SetTexCoord(0.5 - ux + uy, 0.5 - vx - vy, 0.5 - ux - uy, 0.5 - vx + vy,
        0.5 + ux + uy, 0.5 + vx - vy, 0.5 + ux - uy, 0.5 + vx + vy)
    tex:SetVertexColor(r, g, b, alpha)
    tex:Show()
end

local function Pair(pool, index, layer)
    if not pool[index] then pool[index] = {NewTexture(layer), NewTexture(layer)} end
    return pool[index]
end

local ring = {}
for i = 0, 48 do
    local angle = i * math.pi * 2 / 48
    ring[i + 1] = {math.cos(angle) * 0.5, math.sin(angle) * 0.5}
end
-- shortcut: decorative arrow, calibrate size/offset for the native pointer; it does not track hand/sword cursors.
local arrow = {{0, 0}, {0.04, -0.85}, {0.27, -0.64}, {0.45, -1},
    {0.62, -0.91}, {0.43, -0.56}, {0.75, -0.55}, {0, 0}}

local function Outline(x, y)
    local n = 0
    halo:Hide()
    if db.outlineEnabled then
        x, y = x + db.offsetX, y + db.offsetY
        if db.outlineStyle == "halo" then
            halo:ClearAllPoints()
            halo:SetPoint("CENTER", root, "BOTTOMLEFT", x, y)
            halo:SetSize(db.size + db.softness * 2, db.size + db.softness * 2)
            halo:SetVertexColor(db.outlineR, db.outlineG, db.outlineB, db.outlineAlpha * (0.35 + db.glow * 0.65))
            halo:Show()
        else
            local shape = db.outlineStyle == "arrow" and arrow or ring
            local image = db.softness > 0 and "beam-soft.tga" or "beam-hard.tga"
            for i = 1, #shape - 1 do
                n = n + 1
                local pair = Pair(outlines, n, "OVERLAY")
                local a, b = shape[i], shape[i + 1]
                local x1, y1, x2, y2 = x + a[1] * db.size, y + a[2] * db.size,
                    x + b[1] * db.size, y + b[2] * db.size
                Beam(pair[1], x1, y1, x2, y2, db.thickness + db.softness * 2,
                    db.outlineR, db.outlineG, db.outlineB, db.outlineAlpha * db.glow * 0.35, "beam-soft.tga", db.softness)
                Beam(pair[2], x1, y1, x2, y2, db.thickness,
                    db.outlineR, db.outlineG, db.outlineB, db.outlineAlpha, image, db.thickness * 0.5)
            end
        end
    end
    for i = n + 1, #outlines do outlines[i][1]:Hide(); outlines[i][2]:Hide() end
end

local function Push(x, y, time)
    head = head % MAX_POINTS + 1
    local point = points[head]
    if not point then point = {}; points[head] = point end
    point.x, point.y, point.time = x, y, time
    count = min(count + 1, MAX_POINTS)
end

local function Trail(now)
    local drawn, distance = 0, 0
    if db.trailEnabled then
        for i = -1, count - 2 do
            local a = i == -1 and tip or points[(head - i - 1) % MAX_POINTS + 1]
            local b = points[(head - i - 2) % MAX_POINTS + 1]
            if now - b.time >= db.lifetime then break end
            local dx, dy = b.x - a.x, b.y - a.y
            local segment = sqrt(dx * dx + dy * dy)
            if distance >= db.length then break end
            local fraction = min(1, (db.length - distance) / max(segment, 0.01))
            local age = max(0, min(1, (now - (a.time + b.time) / 2) / db.lifetime))
            local remaining = 1 - age
            local width = db.width * (1 - db.taper * max(age, distance / db.length))
            local alpha = db.trailAlpha * remaining ^ db.fade
            drawn = drawn + 1
            local pair = Pair(beams, drawn)
            local image = db.edge > 0.66 and "beam-soft.tga" or (db.edge > 0.33 and "beam-medium.tga" or "beam-hard.tga")
            local smoky = db.trailStyle == "smoke"
            -- Normalize overlapping brushes so joins stay smooth without increasing brightness.
            local coverage = segment / max(0.01, (segment + width * 1.5) * 0.86)
            local stripAlpha = 1 - (1 - alpha) ^ coverage
            Beam(pair[1], a.x, a.y, a.x + dx * fraction, a.y + dy * fraction, width,
                db.trailR, db.trailG, db.trailB, stripAlpha * (smoky and (1 - db.smoke * 0.55) or 1), image, width * 1.5)
            if smoky then
                Beam(pair[2], a.x, a.y, a.x + dx * fraction, a.y + dy * fraction,
                    width * (1 + db.smoke * 0.5), db.trailR, db.trailG, db.trailB,
                    alpha * db.smoke * db.density * min(1, segment / max(1, width * 2)), "smoke.tga", width * 2)
            else pair[2]:Hide() end
            distance = distance + segment
        end
    end
    for i = drawn + 1, used do beams[i][1]:Hide(); beams[i][2]:Hide() end
    used = drawn
end

local function Update(self, elapsed)
    local now, scale = GetTime(), root:GetEffectiveScale()
    local x, y = GetCursorPosition()
    x, y = x / scale, y / scale
    local focused = not IsWindowFocused or IsWindowFocused()
    if not focused or IsMouselooking() or x <= 0 or y <= 0 or x >= root:GetWidth() or y >= root:GetHeight() then
        Clear(); return
    end
    local dx, dy = lastX and x - lastX or 0, lastY and y - lastY or 0
    local distance = sqrt(dx * dx + dy * dy)
    if lastScale ~= scale or elapsed > 0.15 or distance > min(root:GetWidth(), root:GetHeight()) * 0.45 then
        Clear()
    end
    if db.trailEnabled then
        if not lastX or (count > 0 and now - points[head].time >= db.lifetime) then
            head, count = 0, 0
            Push(x, y, now)
            tip.x, tip.y, tip.time = x, y, now
        elseif distance > 0.01 then
            local anchor = points[head]
            local ax, ay, at = anchor.x, anchor.y, anchor.time
            local sx, sy = x - ax, y - ay
            local sampleDistance = sqrt(sx * sx + sy * sy)
            local spacing = max(2, db.width * 0.3, db.length / 220)
            local steps = min(MAX_POINTS - 1, math.floor(sampleDistance / spacing))
            for i = 1, steps do
                local f = i * spacing / sampleDistance
                Push(ax + sx * f, ay + sy * f, at + (now - at) * f)
            end
            tip.x, tip.y, tip.time = x, y, now
        end
    end
    lastX, lastY, lastScale = x, y, scale
    Outline(x, y)
    Trail(now)
end

function Cursor.Apply()
    if not db then return end
    Clear()
    local combat = not not UnitAffectingCombat("player")
    local active = ui.Settings().cursorEnabled ~= false and (db.outlineEnabled or db.trailEnabled) and
        (db.mode == "always" or (db.mode == "combat" and combat) or (db.mode == "peace" and not combat))
    root:SetScript("OnUpdate", active and Update or nil)
    if active then root:Show() else root:Hide() end
end

function Cursor.Normalize()
    local settings = ui.Settings()
    if type(settings.cursor) ~= "table" then
        settings.cursor = {}
        if type(CursorUZDB) == "table" then
            for key in pairs(Cursor.defaults) do settings.cursor[key] = CursorUZDB[key] end
        end
    end
    db = settings.cursor
    Cursor.settings = db
    for key, default in pairs(Cursor.defaults) do
        local value = db[key]
        if type(value) ~= type(default) or (type(value) == "number" and (value ~= value or abs(value) == math.huge))
            or (Cursor.choices[key] and not Cursor.choices[key][value]) then value = default end
        local range = Cursor.ranges[key]
        if range then value = max(range[1], min(range[2], value)) end
        db[key] = value
    end
end

function Cursor.Reset()
    ui.Settings().cursor = {}
    Cursor.Normalize()
    Cursor.Apply()
end

local function hideStandalone(frame)
    frame:SetScript("OnUpdate", nil)
    frame:Hide()
end

local function suppressStandalone()
    local frame = CursorUZEffects
    if not frame or frame == standalone then return end
    standalone = frame
    -- The original addon's event handlers can show its frame again after login.
    frame:HookScript("OnShow", hideStandalone)
    hideStandalone(frame)
end

root:SetScript("OnHide", Clear)
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_LEAVING_WORLD")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("UI_SCALE_CHANGED")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name == "CursorUZ" then suppressStandalone() end
        return
    elseif event == "PLAYER_LOGIN" then
        suppressStandalone()
        Cursor.Normalize()
        self:UnregisterEvent(event)
    elseif event == "PLAYER_LEAVING_WORLD" then
        root:SetScript("OnUpdate", nil)
        root:Hide()
        return
    end
    Cursor.Apply()
end)
