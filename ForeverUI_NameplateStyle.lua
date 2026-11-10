local _, ui = ...
local wfn, API = ui.wfn, WoWForeverNameplates
local art = [[Interface\AddOns\ForeverUI\Art\Nameplates\]]
local font = [[Fonts\FRIZQT__.TTF]]
local question = [[Interface\Icons\INV_Misc_QuestionMark]]
local gold = {1, 0.84, 0.30}
local boxSprites = { PlateBox = 2, PlateBoxMask = 68, PlateBoxSteel = 134 }

function wfn.Visible(region, shown)
    if shown then region:Show() else region:Hide() end
end
local Visible = wfn.Visible

function wfn.Sprite(parent, name, layer, sublevel)
    local tex = parent:CreateTexture(nil, layer, nil, sublevel or 0)
    local x = boxSprites[name]
    tex:SetTexture(art .. (x and "PlateBoxes30300" or name))
    if x then tex:SetTexCoord(x / 256, (x + 64) / 256, 2 / 64, 50 / 64) end
    return tex
end

function wfn.MakeRim(top, bottom, kind, steel)
    local box = kind == "box"
    local mask = box and "PlateBoxMask" or "PlateMask"
    local parts = {
        halo = wfn.Sprite(bottom, box and "PlateBoxGlow" or "PlateGlow", "BACKGROUND", -7),
        outline = wfn.Sprite(bottom, mask, "BACKGROUND", -6),
        fill = wfn.Sprite(bottom, mask, "BACKGROUND", -5),
        rim = wfn.Sprite(top, steel and "PlateBoxSteel" or box and "PlateBox" or "PlateFrame", "BORDER"),
        box = box,
    }
    parts.outline:SetVertexColor(0, 0, 0, 1)
    parts.fill:SetVertexColor(0.05, 0.05, 0.05, 1)
    parts.halo:Hide()
    return parts
end

local function PlaceTexture(tex, anchor, width, height)
    tex:SetPoint("CENTER", anchor, "CENTER")
    tex:SetSize(width, height)
end

function wfn.LayoutRim(parts, anchor, width, height, pixel)
    local db = wfn.db
    local grow, edge = db.frameThickness * pixel, db.outerLine * pixel
    local rw, rh = width + 2 * grow, height + 2 * grow
    PlaceTexture(parts.rim, anchor, rw, rh)
    PlaceTexture(parts.fill, anchor, rw, rh)
    PlaceTexture(parts.outline, anchor, rw + 2 * edge, rh + 2 * edge)
    Visible(parts.outline, edge > 0)
    local band = 3 * pixel
    local gw = math.max(rw * (parts.box and 1.778 or 1.123), rw + 2 * band)
    local gh = math.max(rh * 1.778, rh + 2 * band)
    local haloWidth, haloHeight = rw + (gw - rw) * db.glowSize, rh + (gh - rh) * db.glowSize
    PlaceTexture(parts.halo, anchor, haloWidth, haloHeight)
    return haloWidth, haloHeight
end

function wfn.StyleRim(parts, target, friendly)
    local db = wfn.db
    local r, g, b, a = 1, 1, 1, nil
    if target then r, g, b = unpack(gold) end
    parts.rim:SetVertexColor(r, g, b, 1)
    if target and db.targetGlow then
        a = db.targetGlowStrength
    elseif friendly and db.sideGlow then
        r, g, b = unpack(db.sideGlowFriend)
        a = db.sideGlowStrength
    end
    parts.halo:SetBlendMode(db.glowBlend == "colour" and "BLEND" or "ADD")
    if a and a > 0 then parts.halo:SetVertexColor(r, g, b, a); parts.halo:Show() else parts.halo:Hide() end
end

local function MakeText(parent, size)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont(font, size, "OUTLINE")
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
    return text
end

local function Drag(box)
    if not API:IsPreviewing() then box:SetScript("OnUpdate", nil); return end
    local x, y = GetCursorPosition()
    local scale = box:GetEffectiveScale()
    if scale > 0 then
        API:SetBoxOffset(box.id, math.floor(box.offsetX + (x - box.cursorX) / scale + 0.5),
            math.floor(box.offsetY + (y - box.cursorY) / scale + 0.5))
    end
end

local function StopDrag(box) box:SetScript("OnUpdate", nil) end

local function MakeBox(view, id)
    local box = CreateFrame("Frame", nil, view.boxRow)
    box.view, box.id = view, id
    box.art = wfn.MakeRim(box, box, "box")
    box.icon = box:CreateTexture(nil, "ARTWORK")
    box.text = MakeText(box, 11)
    box.text:SetPoint("CENTER", box, "CENTER", 0, 0)
    local cooldown = CreateFrame("Cooldown", nil, box, "CooldownFrameTemplate")
    cooldown:SetAllPoints(box.icon)
    cooldown:EnableMouse(false)
    if cooldown.SetDrawEdge then cooldown:SetDrawEdge(false) end
    if cooldown.SetDrawBling then cooldown:SetDrawBling(false) end
    if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(false) end
    if cooldown.SetSwipeColor then cooldown:SetSwipeColor(0, 0, 0, 0.7) end
    box.cooldown = cooldown
    box:EnableMouse(false)
    box:RegisterForDrag("LeftButton")
    box:SetScript("OnDragStart", function(self)
        if not self.view.previewing then return end
        self.cursorX, self.cursorY = GetCursorPosition()
        self.offsetX, self.offsetY = API:BoxOffset(self.id)
        self:SetScript("OnUpdate", Drag)
    end)
    box:SetScript("OnDragStop", StopDrag)
    box:SetScript("OnHide", StopDrag)
    box:Hide()
    return box
end

local function FillBox(box, want)
    local icon = (type(want.icon) == "string" or type(want.icon) == "number") and want.icon
    local label = (type(want.text) == "string" or type(want.text) == "number") and want.text
    if icon then box.icon:SetTexture(type(icon) == "string" and icon or question) end
    Visible(box.icon, icon)
    Visible(box.text, not icon and label)
    if not icon and label then
        box.text:SetText(label)
        local c = type(want.colour) == "table" and want.colour or gold
        box.text:SetTextColor(tonumber(c[1]) or 1, tonumber(c[2]) or 1, tonumber(c[3]) or 1)
    end
    local start, length = want.start, want.length
    if type(start) == "number" and start >= 0 and start < math.huge
        and type(length) == "number" and length > 0 and length < math.huge then
        if box.start ~= start or box.length ~= length then box.cooldown:SetCooldown(start, length) end
        box.start, box.length = start, length
        box.cooldown:Show()
    elseif box.start then
        box.start, box.length = nil, nil
        box.cooldown:SetCooldown(0, 0)
        box.cooldown:Hide()
    end
end

function wfn.DrawBoxes(view, plate, unit, target, team, now)
    if view.boxRevision == wfn.revision and view.boxUnit == unit and view.boxTarget == target
        and view.boxPreview == view.previewing and now < (view.boxAt or 0) then return end
    view.boxRevision, view.boxUnit, view.boxTarget, view.boxPreview = wfn.revision, unit, target, view.previewing
    view.boxAt = now + 0.2
    local pixel = view.pixel or 1
    local height = view.chromeHeight or 17
    local width = math.max(16, height * 1.3)
    local left, right, above = view, view, nil
    for _, box in pairs(view.boxes) do box.keep = false end
    for i = 1, #wfn.order do
        local id = wfn.order[i]
        local spec = id and wfn.specs[id]
        if spec and (view.previewing and API:IsBoxEnabled(id) or wfn.ShowsHere(id, wfn.place)) then
            local box = view.boxes[id]
            if not box then box = MakeBox(view, id); view.boxes[id] = box end
            local ok, want = pcall(spec.update, box, unit, plate)
            if not ok and not spec.reported then spec.reported = true; wfn.Print(spec.label .. ": " .. tostring(want)) end
            if ok and type(want) == "table" and wfn.specs[id] == spec then
                local dx, dy = API:BoxOffset(id)
                box:ClearAllPoints()
                if spec.side == "left" then
                    box:SetPoint("RIGHT", left, "LEFT", dx - pixel, dy); left = box
                elseif spec.side == "above" then
                    local anchor = view.nameUnder and view or view.auraRow
                    box:SetPoint("BOTTOMLEFT", above or anchor, above and "BOTTOMRIGHT" or "TOPLEFT", dx + pixel, dy + pixel)
                    above = box
                else
                    box:SetPoint("LEFT", right, "RIGHT", dx + pixel, dy); right = box
                end
                box:SetSize(width, height)
                box.text:SetFont(font, math.max(7, math.floor(height * 0.72)), "OUTLINE")
                local edge = math.max(2, height * 0.15)
                local iconWidth, iconHeight = width - 2 * edge, height - 2 * edge
                box.icon:SetPoint("TOPLEFT", box, "TOPLEFT", edge, -edge)
                box.icon:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -edge, edge)
                local v = 0.42 * iconHeight / iconWidth
                box.icon:SetTexCoord(0.08, 0.92, 0.5 - v, 0.5 + v)
                wfn.LayoutRim(box.art, box, width, height, pixel)
                wfn.StyleRim(box.art, target, team)
                FillBox(box, want)
                box:EnableMouse(not not view.previewing)
                if not view.previewing then StopDrag(box) end
                box.keep = true
                box:Show()
            end
        end
    end
    for _, box in pairs(view.boxes) do if not box.keep then box:Hide() end end
end

local interrupts = {6552, 72, 1766, 2139, 47528, 57994, 15487, 19647, 26679, 32747, 34490}
local interruptSpell, searched
function wfn.ResetInterrupt() searched = nil end

local function InterruptReady()
    if not searched then
        searched, interruptSpell = true, nil
        for _, id in ipairs(interrupts) do
            if IsSpellKnown(id) then interruptSpell = GetSpellInfo(id); break end
        end
    end
    if not interruptSpell then return false end
    local start, duration, enabled = GetSpellCooldown(interruptSpell)
    return enabled ~= 0 and start ~= nil and (start == 0 or duration == 0)
end

function wfn.MakeCast(view)
    local cast = CreateFrame("Frame", nil, view)
    cast:SetFrameLevel(view:GetFrameLevel() + 1)
    local status = CreateFrame("StatusBar", nil, cast)
    status:SetPoint("TOPLEFT", cast, "TOPLEFT", 2, -2)
    status:SetPoint("BOTTOMRIGHT", cast, "BOTTOMRIGHT", -2, 2)
    cast.barTexture = wfn.db.castTexture
    status:SetStatusBarTexture(cast.barTexture)
    local top = CreateFrame("Frame", nil, cast)
    top:SetAllPoints(cast)
    top:SetFrameLevel(status:GetFrameLevel() + 1)
    cast.status, cast.art = status, wfn.MakeRim(top, status, "bar")
    local icon = CreateFrame("Frame", nil, top)
    icon:SetPoint("RIGHT", cast, "LEFT", -2, 0)
    cast.icon, cast.iconArt = icon, wfn.MakeRim(icon, icon, "box", true)
    cast.spell = icon:CreateTexture(nil, "ARTWORK")
    cast.spell:SetPoint("TOPLEFT", icon, "TOPLEFT", 2, -2)
    cast.spell:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
    cast.spell:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cast.BorderShield = top:CreateTexture(nil, "OVERLAY")
    cast.BorderShield:SetTexture([[Interface\Icons\INV_Shield_06]])
    cast.BorderShield:SetSize(11, 11)
    cast.BorderShield:SetPoint("RIGHT", cast, "RIGHT", -3, 0)
    cast.text = MakeText(top, 9)
    cast.text:SetWordWrap(false)
    cast:Hide()
    return cast
end

function wfn.DrawCast(view, unit, friendly, now)
    local cast, native, db = view.cast, view.nativeCast, wfn.db
    local nativeShown = native and native:IsShown()
    if not db.cast then cast:Hide(); return false end
    local name, _, text, icon, startMS, endMS, trade, castID, shield, channel
    if unit then
        name, _, text, icon, startMS, endMS, trade, castID, shield = UnitCastingInfo(unit)
        if not name then
            name, _, text, icon, startMS, endMS, trade, shield = UnitChannelInfo(unit)
            channel = name ~= nil
        end
    end
    local demo = view.previewing and db.previewCast and not name and not nativeShown
    if not name and not nativeShown and not demo then cast:Hide(); return false end
    if cast.barTexture ~= db.castTexture then
        cast.barTexture = db.castTexture
        cast.status:SetStatusBarTexture(db.castTexture)
    end
    local width = friendly and db.castWidthFriend or db.castWidthEnemy
    local height = friendly and db.castHeightFriend or db.castHeightEnemy
    width = width > 0 and math.max(32, width) or view.chromeWidth or 120
    local pixel = view.pixel or 1
    if cast.width ~= width or cast.height ~= height or cast.pixel ~= pixel or cast.revision ~= wfn.revision then
        cast.width, cast.height, cast.pixel, cast.revision = width, height, pixel, wfn.revision
        cast:SetSize(width, height)
        cast:SetPoint("TOP", view, "BOTTOM", db.castX, -db.castY)
        wfn.LayoutRim(cast.art, cast, width, height, pixel)
        local size = db.castIconSize
        cast.icon:SetSize(size, size)
        wfn.LayoutRim(cast.iconArt, cast.icon, size, size, pixel)
        cast.text:SetFont(wfn.Font(db.castFont), db.castTextSize, "OUTLINE")
        cast.text:SetJustifyH(db.castTextAlign:upper())
        cast.text:ClearAllPoints()
        local point = db.castTextPlace == "below" and "BOTTOM" or "CENTER"
        local y = point == "BOTTOM" and -6 or 0
        cast.text:SetPoint("LEFT", cast, point .. (point == "CENTER" and "" or "LEFT"), point == "CENTER" and -width / 2 + 4 or 4, y)
        cast.text:SetPoint("RIGHT", cast, point .. (point == "CENTER" and "" or "RIGHT"), point == "CENTER" and width / 2 - 16 or -4, y)
    end
    local lo, hi, value = 0, 1, 0
    if nativeShown then
        lo, hi = native:GetMinMaxValues()
        value = native:GetValue()
        if not name then
            text = view.nativeCastText and view.nativeCastText:GetText()
            icon = view.nativeCastIcon and view.nativeCastIcon:GetTexture()
            -- The stock 3.3.5 plate cast bar carries no spell text: take it from the combat log.
            if (not text or text == "") and wfn.CastLabel then text = wfn.CastLabel(view, icon) end
            shield = view.nativeCastShield and view.nativeCastShield:IsShown()
        end
    elseif demo then
        text, icon, value = ui.russian and "Пример заклинания" or "Example spell", question, now % 3 / 3
    elseif startMS and endMS and endMS > startMS then
        hi = (endMS - startMS) / 1000
        value = channel and endMS / 1000 - now or now - startMS / 1000
    end
    cast.status:SetMinMaxValues(lo, hi)
    cast.status:SetValue(math.max(lo, math.min(hi, value)))
    local c = db.castColour and (shield and db.castColourShut or InterruptReady() and db.castColourOpen or db.castColourBusy)
    if c then cast.status:SetStatusBarColor(unpack(c)) else cast.status:SetStatusBarColor(1, 0.7, 0) end
    cast.text:SetText(text or name or "")
    if icon then cast.spell:SetTexture(icon) end
    Visible(cast.icon, db.castIcon and icon)
    Visible(cast.BorderShield, shield)
    cast:Show()
    return true
end
