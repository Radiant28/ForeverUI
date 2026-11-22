-- ForeverUI widget factory: native WoW Forever (Camelot) bronze/parchment styling for options controls.
-- Only 3.3.5a API: SetBackdrop, template-free CreateFrame, CreateFont; no Retail mixins or pools.
local addonName, ui = ...
local L = ui.L
local W = {}
ui.Widgets = W

local white = "Interface\\Buttons\\WHITE8X8"
local floor, max, min = math.floor, math.max, math.min

local ART_ROOT = "Interface\\AddOns\\" .. (addonName or "ForeverUI") .. "\\Art\\Forever\\"
local ART = {
    metal = ART_ROOT .. "Window-Metal",
    metalH = ART_ROOT .. "Window-MetalH",
    metalV = ART_ROOT .. "Window-MetalV",
    ground = ART_ROOT .. "Window-InsetGround",
    close = ART_ROOT .. "Window-Close",
    panelButton = ART_ROOT .. "Panel-Button",
    slot = ART_ROOT .. "Slot-Frame",
    optionsC60 = ART_ROOT .. "Options\\optionsc60",
    options = ART_ROOT .. "Options\\options",
    checkBox = ART_ROOT .. "Options\\minimalcheckboxc60",
    checkMark = ART_ROOT .. "Options\\minimalcheckbox-hd",
    dropdown = ART_ROOT .. "Options\\commondropdownc60",
    search = ART_ROOT .. "Options\\commonsearch",
    slider = ART_ROOT .. "Bars_And_Gradients\\buttons\\minimalsliderbarc60-hd",
    scrollProp = ART_ROOT .. "Bars_And_Gradients\\buttons\\minimalscrollbarproportionalc60",
    scrollVert = ART_ROOT .. "Bars_And_Gradients\\buttons\\minimalscrollbarverticalc60",
}
W.Art = ART

local UV = {
    listActive = { ART.options, 0.589844, 0.772461, 0.000977, 0.021484 },
    listHover = { ART.optionsC60, 0.000977, 0.183594, 0.891602, 0.912109 },
    divider = { ART.optionsC60, 0.197266, 0.812500, 0.606445, 0.607422 },
    innerFrame = { ART.optionsC60, 0.000977, 0.866211, 0.000977, 0.604492, 886, 618 },
    checkBox = { ART.checkBox, 0.031250, 0.968750, 0.031250, 0.937500 },
    checkMark = { ART.checkMark, 0.015625, 0.484375, 0.500000, 0.953125 },
    checkMarkDisabled = { ART.checkMark, 0.515625, 0.984375, 0.015625, 0.468750 },
    sliderLeft = { ART.slider, 0.437500, 0.781250, 0.320312, 0.453125 },
    sliderMid = { ART.slider, 0.000000, 0.031250, 0.007812, 0.140625 },
    sliderRight = { ART.slider, 0.031250, 0.375000, 0.484375, 0.617188 },
    sliderThumb = { ART.slider, 0.031250, 0.656250, 0.156250, 0.304688 },
    ddNormal = { ART.dropdown, 0.281250, 0.357422, 0.664062, 0.968750, 39, 39, 12, 12 },
    ddHover = { ART.dropdown, 0.501953, 0.578125, 0.226562, 0.531250, 39, 39, 12, 12 },
    ddPressed = { ART.dropdown, 0.921875, 0.998047, 0.226562, 0.531250, 39, 39, 14, 12 },
    ddOpen = { ART.dropdown, 0.582031, 0.658203, 0.226562, 0.531250, 39, 39, 12, 12 },
    ddDisabled = { ART.dropdown, 0.501953, 0.578125, 0.546875, 0.851562, 39, 39, 12, 12 },
    ddArrow = { ART.dropdown, 0.001953, 0.025391, 0.914062, 0.953125 },
    ddBg = { ART.dropdown, 0.365234, 0.498047, 0.226562, 0.757812, 68, 68, 18 },
    searchLeft = { ART.search, 0.886719, 0.949219, 0.335938, 0.648438 },
    searchMid = { ART.search, 0.003906, 0.878906, 0.335938, 0.648438 },
    searchRight = { ART.search, 0.003906, 0.066406, 0.664062, 0.976562 },
    searchIcon = { ART.search, 0.074219, 0.167969, 0.664062, 0.851562 },
    searchClear = { ART.search, 0.175781, 0.253906, 0.664062, 0.820312 },
    slotRim = { ART.slot, 4 / 128, 108 / 128, 4 / 128, 110 / 128 },
    sbArrowTop = { ART.scrollProp, 0.687500, 0.820312, 0.015625, 0.187500 },
    sbArrowTopOver = { ART.scrollProp, 0.835938, 0.968750, 0.015625, 0.187500 },
    sbArrowBot = { ART.scrollProp, 0.242188, 0.375000, 0.812500, 0.984375 },
    sbArrowBotOver = { ART.scrollProp, 0.539062, 0.671875, 0.015625, 0.187500 },
    sbTrackTop = { ART.scrollProp, 0.164062, 0.226562, 0.609375, 0.734375 },
    sbTrackBot = { ART.scrollProp, 0.085938, 0.148438, 0.765625, 0.890625 },
    sbTrackMid = { ART.scrollVert, 0.015625, 0.140625, 0.000000, 0.000977 },
    sbThumbTop = { ART.scrollProp, 0.007812, 0.070312, 0.609375, 0.734375 },
    sbThumbTopOver = { ART.scrollProp, 0.085938, 0.148438, 0.609375, 0.734375 },
    sbThumbTopDown = { ART.scrollProp, 0.007812, 0.070312, 0.765625, 0.890625 },
    sbThumbMid = { ART.scrollVert, 0.171875, 0.296875, 0.000977, 0.503906 },
    sbThumbMidOver = { ART.scrollVert, 0.484375, 0.609375, 0.000977, 0.503906 },
    sbThumbMidDown = { ART.scrollVert, 0.328125, 0.453125, 0.000977, 0.503906 },
}
W.UV = UV

local S = {
    font = STANDARD_TEXT_FONT,
    window = { 0.082, 0.063, 0.047, 0.96 },
    sidebar = { 0.055, 0.040, 0.028, 0.55 },
    surface = { 0.16, 0.12, 0.085, 0.78 },
    surfaceHover = { 0.24, 0.18, 0.12, 0.86 },
    surfaceActive = { 0.30, 0.22, 0.13, 0.92 },
    border = { 0.48, 0.37, 0.23, 0.72 },
    borderHover = { 0.78, 0.62, 0.36, 0.92 },
    accent = { 0.96, 0.78, 0.34 },
    accentText = { 1.0, 0.85, 0.40 },
    gold = { 1.0, 0.82, 0.0 },
    text = { 0.95, 0.91, 0.83 },
    muted = { 0.70, 0.63, 0.52 },
    danger = { 1.0, 0.40, 0.34 },
    success = { 0.42, 0.86, 0.48 },
    disabledAlpha = 0.35,
    padding = 16,
    columnGap = 24,
    rowGap = 10,
    sectionGap = 22,
}
ui.Style = S

local function rgba(color, alpha)
    return color[1], color[2], color[3], alpha or color[4] or 1
end
W.rgba = rgba

local function applyUV(tex, uv)
    tex:SetTexture(uv[1])
    tex:SetTexCoord(uv[2], uv[3], uv[4], uv[5])
end
W.ApplyUV = applyUV

local fonts = {}
local function font(name, size, flags, color)
    if fonts[name] then return fonts[name] end
    local object = CreateFont("ForeverUIFont" .. name)
    object:SetFont(S.font, size, flags or "")
    object:SetShadowColor(0, 0, 0, 0.85)
    object:SetShadowOffset(1, -1)
    object:SetTextColor(rgba(color or S.text))
    fonts[name] = object
    return object
end
W.fonts = {
    title = font("Title", 17, nil, S.gold),
    heading = font("Heading", 13, nil, S.accentText),
    label = font("Label", 12, nil, S.text),
    small = font("Small", 11, nil, S.muted),
    value = font("Value", 11, nil, S.text),
    group = font("Group", 10, nil, S.accentText),
}

local flat = { bgFile = white, edgeFile = white, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }

function W.Skin(frame, background, border)
    frame:SetBackdrop(flat)
    frame:SetBackdropColor(rgba(background or S.surface))
    frame:SetBackdropBorderColor(rgba(border or S.border))
end

function W.Text(parent, fontObject, layer)
    local text = parent:CreateFontString(nil, layer or "OVERLAY")
    text:SetFontObject(fontObject or W.fonts.label)
    text:SetJustifyH("LEFT")
    return text
end

function W.Line(parent, color, layer)
    local line = parent:CreateTexture(nil, layer or "ARTWORK")
    line:SetTexture(white)
    line:SetVertexColor(rgba(color or S.border))
    return line
end

function W.Divider(parent, layer)
    local line = parent:CreateTexture(nil, layer or "ARTWORK")
    applyUV(line, UV.divider)
    line:SetHeight(1)
    return line
end

local function setVisible(region, visible)
    if visible then region:Show() else region:Hide() end
end
W.SetVisible = setVisible

---------------------------------------------------------------------------------------------------
-- WoW Forever (Camelot) composite art helpers
---------------------------------------------------------------------------------------------------
function W.ThreeSlice(parent, uv, layer, outsetX, outsetY, cropPx)
    layer = layer or "BACKGROUND"
    local ox, oy, crop = outsetX or 0, outsetY or 0, cropPx or 0
    local left = parent:CreateTexture(nil, layer)
    local mid = parent:CreateTexture(nil, layer)
    local right = parent:CreateTexture(nil, layer)
    local obj = { left = left, mid = mid, right = right }
    function obj:SetUV(entry)
        local texW, texH = entry[6] or 39, entry[7] or 39
        local du = (entry[3] - entry[2]) / texW
        local dv = (entry[5] - entry[4]) / texH
        local u1, u2 = entry[2] + crop * du, entry[3] - crop * du
        local v1, v2 = entry[4] + crop * dv, entry[5] - crop * dv
        local capL = max(1, (entry[8] or 12) - crop)
        local capR = max(1, (entry[9] or entry[8] or 12) - crop)
        local uMidL, uMidR = u1 + capL * du, u2 - capR * du
        left:SetTexture(entry[1])
        left:SetTexCoord(u1, uMidL, v1, v2)
        left:ClearAllPoints()
        left:SetPoint("TOPLEFT", parent, "TOPLEFT", -ox, oy)
        left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -ox, -oy)
        left:SetWidth(capL)
        right:SetTexture(entry[1])
        right:SetTexCoord(uMidR, u2, v1, v2)
        right:ClearAllPoints()
        right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", ox, oy)
        right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", ox, -oy)
        right:SetWidth(capR)
        mid:SetTexture(entry[1])
        mid:SetTexCoord(uMidL, uMidR, v1, v2)
        mid:ClearAllPoints()
        mid:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
        mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
    end
    function obj:SetVertexColor(r, g, b, a)
        left:SetVertexColor(r, g, b, a or 1)
        mid:SetVertexColor(r, g, b, a or 1)
        right:SetVertexColor(r, g, b, a or 1)
    end
    obj:SetUV(uv)
    return obj
end

function W.NineSlice(parent, uv, margins, layer)
    layer = layer or "BACKGROUND"
    margins = margins or { 0, 0, 0, 0 }
    local mL, mT, mR, mB = margins[1] or 0, margins[2] or 0, margins[3] or 0, margins[4] or 0
    local texW, texH, c = uv[6] or 68, uv[7] or 68, uv[8] or 18
    local du = (uv[3] - uv[2]) / texW
    local dv = (uv[5] - uv[4]) / texH
    local us = { uv[2], uv[2] + c * du, uv[3] - c * du, uv[3] }
    local vs = { uv[4], uv[4] + c * dv, uv[5] - c * dv, uv[5] }
    local tl = parent:CreateTexture(nil, layer)
    local tr = parent:CreateTexture(nil, layer)
    local bl = parent:CreateTexture(nil, layer)
    local br = parent:CreateTexture(nil, layer)
    local top = parent:CreateTexture(nil, layer)
    local bot = parent:CreateTexture(nil, layer)
    local left = parent:CreateTexture(nil, layer)
    local right = parent:CreateTexture(nil, layer)
    local center = parent:CreateTexture(nil, layer)
    local function slice(t, col, row)
        t:SetTexture(uv[1])
        t:SetTexCoord(us[col], us[col + 1], vs[row], vs[row + 1])
    end
    slice(tl, 1, 1); tl:SetSize(c, c); tl:SetPoint("TOPLEFT", parent, "TOPLEFT", -mL, mT)
    slice(tr, 3, 1); tr:SetSize(c, c); tr:SetPoint("TOPRIGHT", parent, "TOPRIGHT", mR, mT)
    slice(bl, 1, 3); bl:SetSize(c, c); bl:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -mL, -mB)
    slice(br, 3, 3); br:SetSize(c, c); br:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", mR, -mB)
    slice(top, 2, 1); top:SetPoint("TOPLEFT", tl, "TOPRIGHT"); top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
    slice(bot, 2, 3); bot:SetPoint("TOPLEFT", bl, "TOPRIGHT"); bot:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
    slice(left, 1, 2); left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
    slice(right, 3, 2); right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT"); right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
    slice(center, 2, 2); center:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT"); center:SetPoint("BOTTOMRIGHT", br, "TOPLEFT")
    return { tl, tr, bl, br, top, bot, left, right, center }
end

local CHROME = {
    sheetW = 1024, sheetH = 512,
    ringX = 461, ringY = 266, ringSize = 100,
    groundSide = 12, groundTop = 40, groundBottom = 12,
    headerCenter = 31, titleNudge = 1,
    corners = {
        TopLeft     = { 213, 22, 384, 192, 213, 22 },
        TopLeftRing = { 396, 204, 576, 384, 405, 214 },
        TopRight    = { 192, 214, 384, 384, 384, 214 },
        BottomLeft  = { 21, 0, 192, 197, 21, 197 },
        BottomRight = { 0, 202, 192, 399, 192, 399 },
    },
    edges = {
        Top    = { ART.metalH, 224, 289, 256, 512 },
        Bottom = { ART.metalH, 169, 197, 256, 512 },
        Left   = { ART.metalV, 21, 42, 512, 256 },
        Right  = { ART.metalV, 362, 384, 512, 256 },
    },
}

local function chromeCorner(pieces, key, cx, cy, s)
    local c = CHROME.corners[key]
    pieces[#pieces + 1] = {
        file = ART.metal,
        x = cx - (c[5] - c[1]) * s, y = cy - (c[6] - c[2]) * s,
        w = (c[3] - c[1]) * s, h = (c[4] - c[2]) * s,
        l = c[1] / CHROME.sheetW, r = c[3] / CHROME.sheetW,
        t = c[2] / CHROME.sheetH, b = c[4] / CHROME.sheetH,
    }
end

local function chromeEdge(pieces, side, from, to, s, w, h)
    local e = CHROME.edges[side]
    local band = (e[3] - e[2]) * s
    local horizontal = side == "Top" or side == "Bottom"
    local step = (horizontal and e[4] or e[5]) * s
    local pos = from
    while to - pos > 0.01 do
        local len = min(step, to - pos)
        local p = { file = e[1] }
        if horizontal then
            p.x, p.w, p.h = pos, len, band
            p.y = side == "Top" and 0 or h - band
            p.l, p.r, p.t, p.b = 0, len / step, e[2] / e[5], e[3] / e[5]
        else
            p.y, p.h, p.w = pos, len, band
            p.x = side == "Left" and 0 or w - band
            p.l, p.r, p.t, p.b = e[2] / e[4], e[3] / e[4], 0, len / step
        end
        pieces[#pieces + 1] = p
        pos = pos + len
    end
end

function W.BuildBronzeChrome(window, scale, ring)
    local s = scale or 0.5
    local ground = window:CreateTexture(nil, "BACKGROUND")
    if ground.SetDrawLayer then ground:SetDrawLayer("BACKGROUND", -8) end
    ground:SetTexture(ART.ground)
    local chrome = CreateFrame("Frame", nil, window)
    chrome:SetAllPoints(window)
    chrome:SetFrameLevel(window:GetFrameLevel() + 6)
    local portrait = chrome:CreateTexture(nil, "BACKGROUND")
    local obj = {
        chrome = chrome, ground = ground, portrait = portrait, tex = {},
        headerY = -(CHROME.headerCenter * s + CHROME.titleNudge),
    }
    local tlKey = ring and "TopLeftRing" or "TopLeft"
    local cTL = CHROME.corners[tlKey]
    local cTR = CHROME.corners.TopRight
    local cBL = CHROME.corners.BottomLeft
    local cBR = CHROME.corners.BottomRight
    function obj:Update(explicitW, explicitH)
        local w = explicitW or window:GetWidth() or chrome:GetWidth() or 0
        local h = explicitH or window:GetHeight() or chrome:GetHeight() or 0
        if w <= 0 or h <= 0 then return end
        local pieces = {}
        chromeCorner(pieces, tlKey, 0, 0, s)
        chromeCorner(pieces, "TopRight", w, 0, s)
        chromeCorner(pieces, "BottomLeft", 0, h, s)
        chromeCorner(pieces, "BottomRight", w, h, s)
        chromeEdge(pieces, "Top", (cTL[3] - cTL[5]) * s, w - (cTR[5] - cTR[1]) * s, s, w, h)
        chromeEdge(pieces, "Bottom", (cBL[3] - cBL[5]) * s, w - (cBR[5] - cBR[1]) * s, s, w, h)
        chromeEdge(pieces, "Left", (cTL[4] - cTL[6]) * s, h - (cBL[6] - cBL[2]) * s, s, w, h)
        chromeEdge(pieces, "Right", (cTR[4] - cTR[6]) * s, h - (cBR[6] - cBR[2]) * s, s, w, h)
        for i, p in ipairs(pieces) do
            local tex = self.tex[i]
            if not tex then
                tex = chrome:CreateTexture(nil, "BORDER")
                self.tex[i] = tex
            end
            tex:SetTexture(p.file)
            tex:SetTexCoord(p.l, p.r, p.t, p.b)
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", chrome, "TOPLEFT", p.x, -p.y)
            tex:SetWidth(p.w)
            tex:SetHeight(p.h)
            tex:Show()
        end
        for i = #pieces + 1, #self.tex do self.tex[i]:Hide() end
        if ring then
            local pSize = CHROME.ringSize * s
            local px = (CHROME.ringX - cTL[5]) * s - pSize / 2
            local py = (CHROME.ringY - cTL[6]) * s - pSize / 2
            portrait:ClearAllPoints()
            portrait:SetPoint("TOPLEFT", chrome, "TOPLEFT", px, -py)
            portrait:SetSize(pSize, pSize)
            portrait:Show()
        else
            portrait:Hide()
        end
        local gx, gy = CHROME.groundSide * s, CHROME.groundTop * s
        ground:ClearAllPoints()
        ground:SetPoint("TOPLEFT", chrome, "TOPLEFT", gx, -gy)
        ground:SetSize(max(w - 2 * gx, 1), max(h - gy - CHROME.groundBottom * s, 1))
    end
    function obj:SetPortrait(icon)
        if not ring then return end
        if SetPortraitToTexture then
            SetPortraitToTexture(portrait, icon)
        else
            portrait:SetTexture(icon)
        end
        portrait:Show()
    end
    chrome:SetScript("OnSizeChanged", function(_, w, h) obj:Update(w, h) end)
    obj:Update()
    return obj
end

local INNER_SLICES = {
    cols = { 0, 29, 199, 201, 857, 886 },
    ranks = { 0, 82, 451, 618 },
}

function W.InnerFrame(parent, sidebarWidth)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetFrameLevel(parent:GetFrameLevel() + 1)
    local fill = frame:CreateTexture(nil, "BACKGROUND")
    fill:SetTexture(white)
    fill:SetVertexColor(0.035, 0.024, 0.016, 0.52)
    fill:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    frame.pieces = {}
    for i = 1, 15 do
        frame.pieces[i] = frame:CreateTexture(nil, "BORDER")
    end
    function frame:Layout(explicitW, explicitH)
        local w = explicitW or self:GetWidth() or 0
        local h = explicitH or self:GetHeight() or 0
        if w <= 0 or h <= 0 then return end
        local e = UV.innerFrame
        local du, dv = (e[3] - e[2]) / e[6], (e[5] - e[4]) / e[7]
        local cols, ranks = INNER_SLICES.cols, INNER_SLICES.ranks
        local leftW = min(cols[2], floor(w * 0.2))
        local rightW = min(cols[6] - cols[5], floor(w * 0.2))
        local sep = min(sidebarWidth or 208, max(leftW + 10, w - rightW - 10))
        local topH = min(ranks[2], floor(h * 0.45))
        local botH = min(ranks[4] - ranks[3], max(0, h - topH))
        local xs = { 0, leftW, sep, sep + 2, w - rightW, w }
        local ys = { 0, topH, h - botH, h }
        local idx = 0
        for c = 1, 5 do
            for r = 1, 3 do
                idx = idx + 1
                local t = self.pieces[idx]
                local pw, ph = max(0, xs[c + 1] - xs[c]), max(0, ys[r + 1] - ys[r])
                t:SetTexture(e[1])
                t:SetTexCoord(e[2] + cols[c] * du, e[2] + cols[c + 1] * du,
                    e[4] + ranks[r] * dv, e[4] + ranks[r + 1] * dv)
                t:ClearAllPoints()
                if pw > 0 and ph > 0 then
                    t:SetPoint("TOPLEFT", self, "TOPLEFT", xs[c], -ys[r])
                    t:SetSize(pw, ph)
                    t:Show()
                else
                    t:Hide()
                end
            end
        end
    end
    frame:SetScript("OnSizeChanged", function(self, w, h) self:Layout(w, h) end)
    return frame
end

function W.StyleInput(editBox, withMagnifier, onClear)
    if editBox.SetBackdrop then editBox:SetBackdrop(nil) end
    local back = editBox:CreateTexture(nil, "BACKGROUND")
    back:SetTexture(white)
    back:SetVertexColor(0.04, 0.03, 0.02, 0.55)
    back:SetPoint("TOPLEFT", editBox, "TOPLEFT", 2, -2)
    back:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", -2, 2)

    local left = editBox:CreateTexture(nil, "BORDER")
    applyUV(left, UV.searchLeft)
    left:SetWidth(8)
    left:SetPoint("TOPLEFT", editBox, "TOPLEFT", -2, 0)
    left:SetPoint("BOTTOMLEFT", editBox, "BOTTOMLEFT", -2, 0)

    local right = editBox:CreateTexture(nil, "BORDER")
    applyUV(right, UV.searchRight)
    right:SetWidth(8)
    right:SetPoint("TOPRIGHT", editBox, "TOPRIGHT", 2, 0)
    right:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", 2, 0)

    local mid = editBox:CreateTexture(nil, "BORDER")
    applyUV(mid, UV.searchMid)
    mid:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
    mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)

    local function paintBorder(focused)
        local r = focused and 1 or 0.82
        local g = focused and 1 or 0.78
        local b = focused and 1 or 0.72
        left:SetVertexColor(r, g, b)
        mid:SetVertexColor(r, g, b)
        right:SetVertexColor(r, g, b)
    end
    paintBorder(false)
    editBox:HookScript("OnEditFocusGained", function() paintBorder(true) end)
    editBox:HookScript("OnEditFocusLost", function() paintBorder(false) end)

    if withMagnifier then
        local magnifier = editBox:CreateTexture(nil, "OVERLAY")
        applyUV(magnifier, UV.searchIcon)
        magnifier:SetSize(12, 12)
        magnifier:SetPoint("LEFT", editBox, "LEFT", 7, 0)
        editBox.magnifier = magnifier

        local clear = CreateFrame("Button", nil, editBox)
        clear:SetSize(14, 14)
        clear:SetPoint("RIGHT", editBox, "RIGHT", -4, 0)
        local clearTex = clear:CreateTexture(nil, "ARTWORK")
        applyUV(clearTex, UV.searchClear)
        clearTex:SetSize(10, 10)
        clearTex:SetPoint("CENTER", 0, 0)
        clearTex:SetAlpha(0.6)
        clear:SetScript("OnEnter", function() clearTex:SetAlpha(1) end)
        clear:SetScript("OnLeave", function() clearTex:SetAlpha(0.6) end)
        clear:SetScript("OnClick", function()
            PlaySound("igMainMenuOptionCheckBoxOn")
            editBox:SetText("")
            editBox:ClearFocus()
            if onClear then onClear(editBox) end
        end)
        clear:Hide()
        editBox.clearButton = clear
        editBox:SetTextInsets(22, 22, 0, 0)

        local function updateSearchIcons()
            local hasText = (editBox:GetText() or "") ~= ""
            local active = hasText or (editBox.HasFocus and editBox:HasFocus())
            local c = active and 1 or 0.65
            magnifier:SetVertexColor(c, c, c)
            setVisible(clear, hasText)
        end
        editBox:HookScript("OnTextChanged", updateSearchIcons)
        editBox:HookScript("OnEditFocusGained", updateSearchIcons)
        editBox:HookScript("OnEditFocusLost", updateSearchIcons)
        updateSearchIcons()
    end
    editBox.borderPieces = { left, mid, right, back }
    return editBox.borderPieces
end

---------------------------------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------------------------------
function W.ShowTooltip(owner, title, text, opt)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(title or "", 1, 0.82, 0)
    if text and text ~= "" then GameTooltip:AddLine(text, 0.90, 0.86, 0.78, true) end
    if opt then
        if opt.reload then
            GameTooltip:AddLine(L("Требует перезагрузки интерфейса (/reload).", "Requires a UI reload (/reload)."),
                1, 0.55, 0.35, true)
        end
        if opt.protected or (opt.module and opt.module.protected) then
            GameTooltip:AddLine(L("В бою применится после выхода из боя.", "In combat it applies after combat ends."),
                0.55, 0.75, 1, true)
        end
        if opt.module and opt.key and opt.type ~= "button" then
            local default = ui.GetDefault(opt.module.id, opt.key)
            local shown
            if opt.type == "toggle" then
                shown = default and L("вкл.", "on") or L("выкл.", "off")
            elseif opt.type == "range" then
                shown = tostring(default) .. (opt.suffix or "")
            elseif opt.type == "select" then
                for _, item in ipairs(ui.OptionValues(opt)) do
                    if item[1] == default then shown = item[2] end
                end
            end
            if shown then GameTooltip:AddLine(L("По умолчанию: ", "Default: ") .. shown, 0.68, 0.62, 0.52) end
        end
    end
    GameTooltip:Show()
end

local function bindTooltip(frame, row)
    frame:HookScript("OnEnter", function()
        if row.opt and (row.opt.tooltip or row.opt.reload or row.opt.label) then
            W.ShowTooltip(frame, row.opt.label, row.opt.tooltip, row.opt.module and row.opt)
        end
        if row.OnHover then row:OnHover(true) end
        if W.onRowHover then W.onRowHover(row, true) end
        W.Redraw(frame)
    end)
    frame:HookScript("OnLeave", function()
        GameTooltip:Hide()
        if row.OnHover then row:OnHover(false) end
        if W.onRowHover then W.onRowHover(row, false) end
        W.Redraw(frame)
    end)
end
W.BindTooltip = bindTooltip

---------------------------------------------------------------------------------------------------
-- Scroll container used by the window, pages and the dropdown list (WoW Forever MinimalScrollBar)
---------------------------------------------------------------------------------------------------
function W.Scroll(parent, barWidth, barGap)
    barWidth, barGap = barWidth or 8, barGap or 5
    local tw = min(8, barWidth)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    scroll.child = child
    scroll:EnableMouseWheel(true)

    local bar = CreateFrame("Button", nil, scroll)
    bar:SetWidth(barWidth)
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", barGap, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", barGap, 0)
    bar:EnableMouse(true)
    bar:EnableMouseWheel(true)
    bar:RegisterForClicks("LeftButtonUp")

    local trackTop = bar:CreateTexture(nil, "BACKGROUND")
    applyUV(trackTop, UV.sbTrackTop)
    trackTop:SetSize(tw, 8)
    trackTop:SetPoint("TOP", bar, "TOP", 0, 0)

    local trackBot = bar:CreateTexture(nil, "BACKGROUND")
    applyUV(trackBot, UV.sbTrackBot)
    trackBot:SetSize(tw, 8)
    trackBot:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)

    local trackMid = bar:CreateTexture(nil, "BACKGROUND")
    applyUV(trackMid, UV.sbTrackMid)
    trackMid:SetPoint("TOPLEFT", trackTop, "BOTTOMLEFT", 0, 0)
    trackMid:SetPoint("BOTTOMRIGHT", trackBot, "TOPRIGHT", 0, 0)

    local thumb = CreateFrame("Frame", nil, bar)
    thumb:SetWidth(tw)
    local thumbTop = thumb:CreateTexture(nil, "ARTWORK")
    thumbTop:SetSize(tw, 8)
    thumbTop:SetPoint("TOP", thumb, "TOP", 0, 0)
    local thumbBot = thumb:CreateTexture(nil, "ARTWORK")
    thumbBot:SetSize(tw, 8)
    thumbBot:SetPoint("BOTTOM", thumb, "BOTTOM", 0, 0)
    local thumbMid = thumb:CreateTexture(nil, "ARTWORK")
    thumbMid:SetPoint("TOPLEFT", thumbTop, "BOTTOMLEFT", 0, 0)
    thumbMid:SetPoint("BOTTOMRIGHT", thumbBot, "TOPRIGHT", 0, 0)

    local upArrow = CreateFrame("Button", nil, bar)
    upArrow:SetSize(17, 11)
    upArrow:SetPoint("BOTTOM", bar, "TOP", 0, 1)
    local upTex = upArrow:CreateTexture(nil, "ARTWORK")
    applyUV(upTex, UV.sbArrowTop)
    upTex:SetAllPoints(upArrow)
    upArrow:SetScript("OnEnter", function() applyUV(upTex, UV.sbArrowTopOver) end)
    upArrow:SetScript("OnLeave", function() applyUV(upTex, UV.sbArrowTop) end)
    upArrow:SetScript("OnClick", function() scroll:ForeverScroll(1) end)

    local downArrow = CreateFrame("Button", nil, bar)
    downArrow:SetSize(17, 11)
    downArrow:SetPoint("TOP", bar, "BOTTOM", 0, -1)
    local downTex = downArrow:CreateTexture(nil, "ARTWORK")
    applyUV(downTex, UV.sbArrowBot)
    downTex:SetAllPoints(downArrow)
    downArrow:SetScript("OnEnter", function() applyUV(downTex, UV.sbArrowBotOver) end)
    downArrow:SetScript("OnLeave", function() applyUV(downTex, UV.sbArrowBot) end)
    downArrow:SetScript("OnClick", function() scroll:ForeverScroll(-1) end)

    scroll.bar, scroll.thumb = bar, thumb
    bar.upArrow, bar.downArrow = upArrow, downArrow
    bar.trackTop, bar.thumbTop, bar.thumbMid, bar.thumbBot = trackTop, thumbTop, thumbMid, thumbBot

    local hover, grab = false, nil
    local function paint()
        local topUV = grab and UV.sbThumbTopDown or hover and UV.sbThumbTopOver or UV.sbThumbTop
        local midUV = grab and UV.sbThumbMidDown or hover and UV.sbThumbMidOver or UV.sbThumbMid
        applyUV(thumbTop, topUV)
        thumbBot:SetTexture(topUV[1])
        thumbBot:SetTexCoord(topUV[2], topUV[3], topUV[5], topUV[4])
        applyUV(thumbMid, midUV)
    end
    paint()

    local function geometry()
        local height = scroll:GetHeight() or 0
        local content = scroll.contentHeight or 0
        local range = max(0, content - height)
        local size = range > 0 and max(24, height * height / content) or height
        return height, range, size
    end

    function scroll:Update()
        local height, range, size = geometry()
        local offset = max(0, min(self:GetVerticalScroll() or 0, range))
        self:SetVerticalScroll(offset)
        if range <= 0 or height <= 0 then
            thumb:Hide()
            bar:Hide()
        else
            bar:Show()
            thumb:ClearAllPoints()
            thumb:SetHeight(size)
            thumb:SetPoint("TOP", bar, "TOP", 0, -(height - size) * offset / range)
            thumb:Show()
        end
        if self.onScroll and self.lastOffset ~= offset then
            self.lastOffset = offset
            self.onScroll(self, offset)
        end
    end

    function scroll:SetContentHeight(height)
        self.contentHeight = height
        child:SetHeight(max(1, height))
        self:UpdateScrollChildRect()
        self:Update()
    end

    function scroll:ScrollTo(offset)
        local _, range = geometry()
        self:SetVerticalScroll(max(0, min(range, offset or 0)))
        self:Update()
    end

    function scroll:ForeverScroll(delta)
        self:ScrollTo((self:GetVerticalScroll() or 0) - delta * 48)
    end

    local function cursorDepth()
        local _, y = GetCursorPosition()
        local scale = bar:GetEffectiveScale() or 1
        return (bar:GetTop() or 0) - y / scale
    end
    local function follow()
        local height, range, size = geometry()
        if range <= 0 or height <= size then return end
        local top = max(0, min(height - size, cursorDepth() - grab))
        scroll:ScrollTo(range * top / (height - size))
    end
    bar:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        local height, range, size = geometry()
        if range <= 0 then return end
        local thumbTopOffset = (height - size) * (scroll:GetVerticalScroll() or 0) / range
        local depth = cursorDepth()
        if depth >= thumbTopOffset and depth <= thumbTopOffset + size then
            grab = depth - thumbTopOffset
        else
            grab = size / 2
            follow()
        end
        paint()
        bar:SetScript("OnUpdate", follow)
    end)
    local function release()
        if not grab then return end
        grab = nil
        bar:SetScript("OnUpdate", nil)
        paint()
        W.Redraw(scroll)
    end
    bar:SetScript("OnMouseUp", release)
    bar:SetScript("OnHide", release)
    bar:SetScript("OnEnter", function() hover = true paint() end)
    bar:SetScript("OnLeave", function() hover = false paint() end)
    bar:SetScript("OnMouseWheel", function(_, delta) scroll:ForeverScroll(delta) end)

    scroll:SetScript("OnMouseWheel", scroll.ForeverScroll)
    scroll:SetScript("OnSizeChanged", function(self, width)
        child:SetWidth(width)
        self:Update()
    end)
    return scroll
end

local redrawQueue = {}
local redrawDriver = CreateFrame("Frame")
local function redrawStep(self)
    for scroll, phase in pairs(redrawQueue) do
        if phase == 1 then
            local offset = scroll:GetVerticalScroll() or 0
            scroll.redrawOffset = offset
            scroll:UpdateScrollChildRect()
            scroll:SetVerticalScroll(offset >= 0.5 and offset - 0.5 or offset + 0.5)
            redrawQueue[scroll] = 2
        else
            scroll:SetVerticalScroll(scroll.redrawOffset or 0)
            if scroll.Update then scroll:Update() end
            redrawQueue[scroll] = nil
        end
    end
    if not next(redrawQueue) then self:SetScript("OnUpdate", nil) end
end

function W.Redraw(frame)
    local node, any = frame, false
    while node do
        if node.ForeverScroll and not redrawQueue[node] then
            redrawQueue[node] = 1
            any = true
        end
        node = node.GetParent and node:GetParent()
    end
    if any then redrawDriver:SetScript("OnUpdate", redrawStep) end
end

local function forwardWheel(frame, delta)
    local parent = frame:GetParent()
    while parent do
        if parent.ForeverScroll then
            parent:ForeverScroll(delta)
            return
        end
        parent = parent:GetParent()
    end
end
W.ForwardWheel = forwardWheel

---------------------------------------------------------------------------------------------------
-- Buttons (WoW Forever 3-slice crimson panel buttons and red metal close button)
---------------------------------------------------------------------------------------------------
function W.Button(parent, text, width, onClick, height)
    local w, h = width or 120, height or 24
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(w, h)

    local left = button:CreateTexture(nil, "BACKGROUND")
    local right = button:CreateTexture(nil, "BACKGROUND")
    local mid = button:CreateTexture(nil, "BACKGROUND")
    left:SetTexture(ART.panelButton)
    right:SetTexture(ART.panelButton)
    mid:SetTexture(ART.panelButton)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture(ART.panelButton)
    highlight:SetTexCoord(0, 1, 3 / 4, 1)
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.7)
    highlight:SetAllPoints(button)

    local activeGlow = button:CreateTexture(nil, "OVERLAY")
    activeGlow:SetTexture(ART.panelButton)
    activeGlow:SetTexCoord(0, 1, 3 / 4, 1)
    activeGlow:SetBlendMode("ADD")
    activeGlow:SetVertexColor(1, 0.85, 0.35, 0.65)
    activeGlow:SetAllPoints(button)
    activeGlow:Hide()

    local function layoutSlices()
        local bw = button:GetWidth() or w
        local bh = button:GetHeight() or h
        local cap = min(floor(bw / 2), max(8, floor(bh * 0.42 + 0.5)))
        left:ClearAllPoints()
        left:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        left:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
        left:SetWidth(cap)
        right:ClearAllPoints()
        right:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
        right:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        right:SetWidth(cap)
        mid:ClearAllPoints()
        mid:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
        mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
    end

    local function setRow(row)
        local t, b = row / 4, (row + 1) / 4
        left:SetTexCoord(0, 20 / 256, t, b)
        mid:SetTexCoord(20 / 256, 236 / 256, t, b)
        right:SetTexCoord(236 / 256, 1, t, b)
    end

    layoutSlices()
    setRow(0)

    local label = W.Text(button, W.fonts.label)
    label:SetPoint("LEFT", 8, 0)
    label:SetPoint("RIGHT", -8, 0)
    label:SetJustifyH("CENTER")
    label:SetTextColor(1, 0.85, 0.25)
    label:SetText(text or "")
    button.text = label
    button.slices = { left, mid, right }
    button.activeGlow = activeGlow

    function button:SetText(value) label:SetText(value) end
    function button:SetActive(active)
        self.active = active and true or false
        setVisible(activeGlow, self.active)
    end

    local function syncState(pressed)
        local enabled = button:IsEnabled()
        enabled = enabled == 1 or enabled == true
        if not enabled then
            setRow(2)
            button:SetAlpha(S.disabledAlpha)
        elseif pressed then
            setRow(1)
            button:SetAlpha(1)
        else
            setRow(0)
            button:SetAlpha(1)
        end
    end

    button:SetScript("OnSizeChanged", layoutSlices)
    button:SetScript("OnMouseDown", function(self)
        local enabled = self:IsEnabled()
        if enabled == 1 or enabled == true then
            syncState(true)
            label:SetPoint("LEFT", 9, -1)
            label:SetPoint("RIGHT", -7, -1)
            W.Redraw(self)
        end
    end)
    button:SetScript("OnMouseUp", function(self)
        syncState(false)
        label:SetPoint("LEFT", 8, 0)
        label:SetPoint("RIGHT", -8, 0)
        W.Redraw(self)
    end)
    button:HookScript("OnEnter", function(self) W.Redraw(self) end)
    button:HookScript("OnLeave", function(self)
        syncState(false)
        label:SetPoint("LEFT", 8, 0)
        label:SetPoint("RIGHT", -8, 0)
        W.Redraw(self)
    end)
    button:SetScript("OnDisable", function() syncState(false) end)
    button:SetScript("OnEnable", function() syncState(false) end)
    if onClick then
        button:SetScript("OnClick", function(self, ...)
            PlaySound("igMainMenuOptionCheckBoxOn")
            onClick(self, ...)
        end)
    end
    return button
end

function W.IconButton(parent, size, texture, onClick, coords)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size, size)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    icon:SetTexture(texture)
    if coords then icon:SetTexCoord(unpack(coords)) end
    icon:SetVertexColor(rgba(S.muted))
    button.icon = icon
    button:SetScript("OnEnter", function() icon:SetVertexColor(rgba(S.accentText)) end)
    button:SetScript("OnLeave", function() icon:SetVertexColor(rgba(S.muted)) end)
    if onClick then button:SetScript("OnClick", onClick) end
    return button
end

local function closeCoords(cell)
    local cx, cy = (cell % 2) * 128, floor(cell / 2) * 128
    return (cx + 4) / 256, (cx + 125) / 256, (cy + 2) / 256, (cy + 122) / 256
end

function W.CloseButton(parent, onClick, size)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size or 24, size or 24)
    local face = button:CreateTexture(nil, "ARTWORK")
    face:SetTexture(ART.close)
    face:SetTexCoord(closeCoords(0))
    face:SetAllPoints(button)
    local glow = button:CreateTexture(nil, "HIGHLIGHT")
    glow:SetTexture(ART.close)
    glow:SetTexCoord(closeCoords(2))
    glow:SetBlendMode("ADD")
    glow:SetAllPoints(button)
    button.face, button.glow = face, glow
    button:SetScript("OnMouseDown", function() face:SetTexCoord(closeCoords(1)) end)
    button:SetScript("OnMouseUp", function() face:SetTexCoord(closeCoords(0)) end)
    button:SetScript("OnLeave", function() face:SetTexCoord(closeCoords(0)) end)
    if onClick then button:SetScript("OnClick", onClick) end
    return button
end

local undoIcon = "Interface\\PaperDollInfoFrame\\UI-GearManager-Undo"
local function resetButton(row)
    local button = W.IconButton(row, 14, undoIcon, function()
        if row.enabled ~= false and row.access.reset then
            PlaySound("igMainMenuOptionCheckBoxOff")
            row.access.reset()
        end
    end)
    button:HookScript("OnEnter", function(self)
        W.ShowTooltip(self, L("Сбросить", "Reset"), L("Вернуть значение по умолчанию.", "Restore the default value."))
    end)
    button:HookScript("OnLeave", GameTooltip_Hide)
    button:SetFrameLevel(row:GetFrameLevel() + 5)
    button:Hide()
    row.resetButton = button
    return button
end

local function updateReset(row)
    local button = row.resetButton
    if not button then return end
    local access = row.access
    local show = access.reset and row.enabled ~= false and access.isDefault and not access.isDefault()
    setVisible(button, show)
end

---------------------------------------------------------------------------------------------------
-- Rows. Every control is a row frame with :Refresh() and :SetEnabled(enabled).
-- access = { get(), set(value), reset(), isDefault() }
---------------------------------------------------------------------------------------------------
local function newRow(parent, opt, access, width, height, kind)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(width, height)
    row.opt, row.access, row.kind, row.enabled = opt, access, kind, true
    function row:SetEnabled(enabled)
        self.enabled = enabled and true or false
        self:SetAlpha(enabled and 1 or S.disabledAlpha)
        if self.OnEnabledChanged then self:OnEnabledChanged(self.enabled) end
        updateReset(self)
    end
    return row
end

-- Toggle checkbox (minimalcheckboxc60 + minimalcheckbox-hd)
function W.Toggle(parent, opt, access, width)
    local row = newRow(parent, opt, access, width, 24, "toggle")
    local hit = CreateFrame("Button", nil, row)
    hit:SetAllPoints(row)
    local box = CreateFrame("Frame", nil, hit)
    box:SetSize(20, 20)
    box:SetPoint("LEFT", 0, 0)
    local boxTex = box:CreateTexture(nil, "ARTWORK")
    applyUV(boxTex, UV.checkBox)
    boxTex:SetAllPoints(box)
    boxTex:SetVertexColor(0.92, 0.88, 0.82)
    local check = box:CreateTexture(nil, "OVERLAY")
    applyUV(check, UV.checkMark)
    check:SetSize(20, 20)
    check:SetPoint("CENTER", box, "CENTER", 0, 0)
    local label = W.Text(hit, W.fonts.label)
    label:SetPoint("LEFT", box, "RIGHT", 8, 0)
    label:SetPoint("RIGHT", row, "RIGHT", -20, 0)
    label:SetHeight(20)
    label:SetText(opt.label or "")
    row.label, row.checkBox, row.checkMark = label, boxTex, check
    local reset = resetButton(row)
    reset:SetPoint("RIGHT", row, "RIGHT", 0, 0)

    local hovered
    local function paint()
        local on = access.get() and true or false
        applyUV(check, row.enabled and UV.checkMark or UV.checkMarkDisabled)
        setVisible(check, on)
        if hovered then
            boxTex:SetVertexColor(1, 1, 1)
            label:SetTextColor(rgba(S.accentText))
        else
            boxTex:SetVertexColor(0.92, 0.88, 0.82)
            label:SetTextColor(rgba(S.text))
        end
    end
    function row:OnHover(state)
        hovered = state and self.enabled
        paint()
    end
    hit:SetScript("OnClick", function()
        if not row.enabled then return end
        local on = not access.get()
        PlaySound(on and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
        access.set(on)
    end)
    bindTooltip(hit, row)
    function row:OnEnabledChanged(enabled)
        hit:EnableMouse(enabled)
        paint()
    end
    function row:Refresh()
        paint()
        updateReset(self)
    end
    row:Refresh()
    return row
end

local function decimals(step)
    if not step or step >= 1 then return 0 end
    local text = tostring(step)
    local fraction = text:match("%.(%d+)")
    return fraction and #fraction or 2
end

local function limit(value)
    if type(value) == "function" then return value() end
    return value
end

-- Slider with an exact value input (minimalsliderbarc60-hd).
function W.Range(parent, opt, access, width)
    local row = newRow(parent, opt, access, width, 42, "range")
    local label = W.Text(row, W.fonts.label)
    label:SetPoint("TOPLEFT", 0, -2)
    label:SetPoint("RIGHT", row, "RIGHT", -82, 0)
    label:SetHeight(16)
    label:SetText(opt.label or "")
    row.label = label

    local input = CreateFrame("EditBox", nil, row)
    input:SetSize(56, 20)
    input:SetPoint("TOPRIGHT", 0, 0)
    input:SetFontObject(W.fonts.value)
    input:SetJustifyH("CENTER")
    input:SetAutoFocus(false)
    input:SetMaxLetters(10)
    input:SetTextInsets(3, 3, 0, 0)
    W.StyleInput(input, false)
    local reset = resetButton(row)
    reset:SetPoint("RIGHT", input, "LEFT", -6, 0)

    local slider = CreateFrame("Slider", nil, row)
    slider:SetOrientation("HORIZONTAL")
    slider:SetHeight(17)
    slider:SetPoint("BOTTOMLEFT", 0, 0)
    slider:SetPoint("BOTTOMRIGHT", 0, 0)
    slider:SetHitRectInsets(0, 0, -4, -4)

    local trackLeft = slider:CreateTexture(nil, "BACKGROUND")
    applyUV(trackLeft, UV.sliderLeft)
    trackLeft:SetSize(11, 17)
    trackLeft:SetPoint("LEFT", slider, "LEFT", 0, 0)

    local trackRight = slider:CreateTexture(nil, "BACKGROUND")
    applyUV(trackRight, UV.sliderRight)
    trackRight:SetSize(11, 17)
    trackRight:SetPoint("RIGHT", slider, "RIGHT", 0, 0)

    local trackMid = slider:CreateTexture(nil, "BACKGROUND")
    applyUV(trackMid, UV.sliderMid)
    trackMid:SetPoint("TOPLEFT", trackLeft, "TOPRIGHT", 0, 0)
    trackMid:SetPoint("BOTTOMRIGHT", trackRight, "BOTTOMLEFT", 0, 0)

    slider:SetThumbTexture(ART.slider)
    local thumb = slider:GetThumbTexture()
    applyUV(thumb, UV.sliderThumb)
    thumb:SetSize(16, 15)
    thumb:SetVertexColor(0.92, 0.88, 0.82)

    local fill = slider:CreateTexture(nil, "ARTWORK")
    fill:SetTexture(white)
    fill:SetVertexColor(0.88, 0.68, 0.26, 0.72)
    fill:SetHeight(3)
    fill:SetPoint("LEFT", trackLeft, "LEFT", 4, 0)
    fill:SetPoint("RIGHT", thumb, "CENTER", 0, 0)

    local places = decimals(opt.step)
    local updating
    local function bounds()
        return limit(opt.min) or 0, limit(opt.max) or 1, opt.step or 1
    end
    local function format(value)
        if opt.format then return opt.format(value) end
        return ("%." .. places .. "f"):format(value) .. (opt.suffix or "")
    end
    local function commit(value)
        local low, high, step = bounds()
        value = max(low, min(high, low + floor((value - low) / step + 0.5) * step))
        if not ui.SameValue(value, access.get()) then access.set(value) else row:Refresh() end
    end

    slider:SetScript("OnValueChanged", function(_, value)
        if updating or not row.enabled then return end
        commit(value)
    end)
    slider:EnableMouseWheel(true)
    slider:SetScript("OnMouseWheel", function(self, delta)
        if IsShiftKeyDown() and row.enabled then
            local _, _, step = bounds()
            commit(access.get() + delta * step)
        else
            forwardWheel(self, delta)
        end
    end)
    input:SetScript("OnEditFocusGained", function(self)
        self.focused = true
        self:SetText(("%." .. places .. "f"):format(access.get()))
        self:HighlightText()
    end)
    input:SetScript("OnEditFocusLost", function(self)
        self.focused = nil
        self:HighlightText(0, 0)
        row:Refresh()
    end)
    input:SetScript("OnEnterPressed", function(self)
        local value = tonumber((self:GetText() or ""):gsub(",", "."):match("%-?[%d%.]+") or "")
        if value then commit(value) end
        self:ClearFocus()
    end)
    input:SetScript("OnEscapePressed", input.ClearFocus)
    bindTooltip(slider, row)
    bindTooltip(input, row)

    function row:OnHover(state)
        local bright = state and self.enabled
        thumb:SetVertexColor(bright and 1 or 0.92, bright and 1 or 0.88, bright and 1 or 0.82)
    end
    function row:OnEnabledChanged(enabled)
        slider:EnableMouse(enabled)
        input:EnableMouse(enabled)
        thumb:SetAlpha(enabled and 1 or 0.7)
        if not enabled then input:ClearFocus() end
    end
    function row:Refresh()
        local low, high, step = bounds()
        updating = true
        slider:SetMinMaxValues(low, high)
        slider:SetValueStep(step)
        local value = access.get() or low
        slider:SetValue(value)
        updating = false
        if not input.focused then input:SetText(format(value)) end
        updateReset(self)
    end
    row.slider, row.input = slider, input
    row:Refresh()
    return row
end

---------------------------------------------------------------------------------------------------
-- Dropdown list (shared popup with search, previews and wheel scrolling)
---------------------------------------------------------------------------------------------------
local list
local LIST_ROWS, LIST_ROW_HEIGHT = 12, 20

local function fold(value)
    value = (value or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    local ascii = value:gsub("[A-Z]", string.lower)
    return (ascii:gsub("\208([\129\144-\175])", function(byte)
        local n = byte:byte()
        if n == 129 then return "\209\145" end
        if n >= 160 then return "\209" .. string.char(n - 32) end
        return "\208" .. string.char(n + 32)
    end))
end
W.Fold = fold

local function buildList()
    list = CreateFrame("Frame", "ForeverUIDropdownList", UIParent)
    list:SetFrameStrata("FULLSCREEN_DIALOG")
    list:SetClampedToScreen(true)
    list:EnableMouse(true)
    list:EnableMouseWheel(true)
    local slices = W.NineSlice(list, UV.ddBg, { 9, 6, 9, 12 }, "BACKGROUND")
    for _, slice in ipairs(slices) do slice:SetAlpha(0.96) end
    list.slices = slices
    list:Hide()
    tinsert(UISpecialFrames, list:GetName())

    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:RegisterForClicks("AnyUp")
    catcher:SetScript("OnClick", function() list:Hide() end)
    catcher:Hide()
    list.catcher = catcher

    local search = CreateFrame("EditBox", nil, list)
    search:SetHeight(22)
    search:SetPoint("TOPLEFT", 6, -6)
    search:SetPoint("TOPRIGHT", -6, -6)
    search:SetFontObject(W.fonts.value)
    search:SetAutoFocus(false)
    search:SetTextInsets(22, 22, 0, 0)
    local hint = W.Text(search, W.fonts.small)
    hint:SetPoint("LEFT", 22, 0)
    hint:SetText(L("Поиск…", "Search…"))
    search:SetScript("OnEscapePressed", function() list:Hide() end)
    search:SetScript("OnEnterPressed", search.ClearFocus)
    search:SetScript("OnTextChanged", function(self)
        setVisible(hint, (self:GetText() or "") == "")
        list.offset = 0
        list:Filter()
    end)
    W.StyleInput(search, true, function()
        setVisible(hint, true)
        list.offset = 0
        list:Filter()
    end)
    list.search = search

    list.rows = {}
    for i = 1, LIST_ROWS do
        local row = CreateFrame("Button", nil, list)
        row:SetHeight(LIST_ROW_HEIGHT)
        local activeBg = row:CreateTexture(nil, "BACKGROUND")
        applyUV(activeBg, UV.listActive)
        activeBg:SetAllPoints(row)
        activeBg:Hide()
        row.activeBg = activeBg
        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        applyUV(highlight, UV.listHover)
        highlight:SetAllPoints(row)
        local marker = row:CreateTexture(nil, "ARTWORK")
        marker:SetTexture(white)
        marker:SetVertexColor(rgba(S.accent))
        marker:SetSize(2, LIST_ROW_HEIGHT - 6)
        marker:SetPoint("LEFT", 3, 0)
        row.marker = marker
        local text = W.Text(row, W.fonts.label)
        text:SetPoint("LEFT", 10, 0)
        text:SetPoint("RIGHT", -8, 0)
        text:SetHeight(LIST_ROW_HEIGHT)
        row.text = text
        local swatch = row:CreateTexture(nil, "ARTWORK")
        swatch:SetSize(72, 10)
        swatch:SetPoint("RIGHT", -8, 0)
        row.swatch = swatch
        row:SetScript("OnClick", function(self)
            if not self.item then return end
            local callback = list.onSelect
            list:Hide()
            PlaySound("igMainMenuOptionCheckBoxOn")
            callback(self.item[1])
        end)
        list.rows[i] = row
    end

    local thumb = list:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(white)
    thumb:SetVertexColor(rgba(S.accent, 0.72))
    thumb:SetWidth(2)
    list.thumb = thumb

    function list:Filter()
        local needle = fold(self.search:GetText())
        local matches = {}
        for _, item in ipairs(self.items) do
            if needle == "" or fold(item[2]):find(needle, 1, true) then matches[#matches + 1] = item end
        end
        self.matches = matches
        self:Draw()
    end

    function list:Draw()
        local matches = self.matches
        local visible = min(LIST_ROWS, #matches)
        self.offset = max(0, min(self.offset or 0, #matches - visible))
        local top = self.searchShown and 32 or 4
        for i, row in ipairs(self.rows) do
            local item = matches[self.offset + i]
            row.item = item
            if item and i <= visible then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 4, -top - (i - 1) * LIST_ROW_HEIGHT)
                row:SetPoint("TOPRIGHT", -6, -top - (i - 1) * LIST_ROW_HEIGHT)
                row.text:SetFontObject(W.fonts.label)
                if item.font then
                    row.text:SetFont(S.font, 12)
                    row.text:SetFont(item.font, 13)
                end
                row.text:SetText(item[2])
                local current = ui.SameValue(item[1], self.current)
                row.text:SetTextColor(rgba(current and { 1, 1, 1 } or S.text))
                setVisible(row.marker, current)
                setVisible(row.activeBg, current)
                if item.texture then
                    row.swatch:SetTexture(item.texture)
                    row.swatch:SetVertexColor(1, 1, 1, 1)
                    row.swatch:Show()
                    row.text:SetPoint("RIGHT", -86, 0)
                else
                    row.swatch:Hide()
                    row.text:SetPoint("RIGHT", -8, 0)
                end
                row:Show()
            else
                row:Hide()
            end
        end
        local height = top + max(1, visible) * LIST_ROW_HEIGHT + 4
        self:SetHeight(height)
        if #matches > visible and visible > 0 then
            local span = visible * LIST_ROW_HEIGHT
            local size = max(16, span * visible / #matches)
            thumb:ClearAllPoints()
            thumb:SetHeight(size)
            thumb:SetPoint("TOPRIGHT", -2, -top - (span - size) * self.offset / (#matches - visible))
            thumb:Show()
        else
            thumb:Hide()
        end
    end

    list:SetScript("OnMouseWheel", function(self, delta)
        self.offset = (self.offset or 0) - delta * 3
        self:Draw()
    end)
    list:SetScript("OnHide", function(self)
        self.catcher:Hide()
        self.search:ClearFocus()
        if self.owner and self.owner.OnListClosed then self.owner:OnListClosed() end
        self.owner = nil
    end)
end

function W.OpenList(owner, items, current, onSelect, width)
    if not list then buildList() end
    if list:IsShown() and list.owner == owner then
        list:Hide()
        return
    end
    list:Hide()
    list.owner, list.items, list.current, list.onSelect = owner, items, current, onSelect
    list.offset = 0
    list.searchShown = #items > LIST_ROWS
    setVisible(list.search, list.searchShown)
    list.search:SetText("")
    list:SetWidth(max(width or owner:GetWidth(), 160))
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    list:SetScale(owner:GetEffectiveScale() / UIParent:GetEffectiveScale())
    list:Filter()
    for i, item in ipairs(list.matches) do
        if ui.SameValue(item[1], current) then
            list.offset = max(0, i - floor(LIST_ROWS / 2))
            list:Draw()
            break
        end
    end
    list.catcher:Show()
    list:Show()
    list:SetFrameLevel(list.catcher:GetFrameLevel() + 10)
    for _, row in ipairs(list.rows) do row:SetFrameLevel(list:GetFrameLevel() + 1) end
    list.search:SetFrameLevel(list:GetFrameLevel() + 1)
end

function W.CloseList()
    if list then list:Hide() end
end

-- Select box (commondropdownc60)
function W.Select(parent, opt, access, width)
    local row = newRow(parent, opt, access, width, 46, "select")
    local label = W.Text(row, W.fonts.label)
    label:SetPoint("TOPLEFT", 0, -2)
    label:SetPoint("RIGHT", row, "RIGHT", -20, 0)
    label:SetHeight(16)
    label:SetText(opt.label or "")
    row.label = label
    local reset = resetButton(row)
    reset:SetPoint("TOPRIGHT", 0, -1)

    local box = CreateFrame("Button", nil, row)
    box:SetHeight(24)
    box:SetPoint("BOTTOMLEFT", 0, 0)
    box:SetPoint("BOTTOMRIGHT", 0, 0)
    local art = W.ThreeSlice(box, UV.ddNormal, "BACKGROUND", 6, 6)
    box.art = art
    local text = W.Text(box, W.fonts.label)
    text:SetPoint("LEFT", 10, 0)
    text:SetPoint("RIGHT", -24, 0)
    text:SetHeight(20)
    local swatch = box:CreateTexture(nil, "ARTWORK")
    swatch:SetSize(56, 8)
    swatch:SetPoint("RIGHT", -22, 0)
    swatch:Hide()
    local arrow = box:CreateTexture(nil, "OVERLAY")
    applyUV(arrow, UV.ddArrow)
    arrow:SetSize(12, 5)
    arrow:SetPoint("RIGHT", -9, 0)
    arrow:SetVertexColor(0.78, 0.66, 0.45)

    local function items()
        if opt.type == "media" then return ui.MediaItems(opt.kind, opt.ignoreGlobal) end
        return ui.OptionValues(opt)
    end
    local hovered, pressed = false, false
    local function paintBox()
        local isOpen = list and list:IsShown() and list.owner == box
        if not row.enabled then
            art:SetUV(UV.ddDisabled)
            arrow:SetVertexColor(0.45, 0.42, 0.38)
            text:SetTextColor(rgba(S.muted))
        elseif pressed then
            art:SetUV(UV.ddPressed)
            arrow:SetVertexColor(1, 0.88, 0.45)
            text:SetTextColor(rgba(S.text))
        elseif isOpen then
            art:SetUV(UV.ddOpen)
            arrow:SetVertexColor(1, 0.88, 0.45)
            text:SetTextColor(rgba(S.accentText))
        elseif hovered then
            art:SetUV(UV.ddHover)
            arrow:SetVertexColor(1, 0.88, 0.45)
            text:SetTextColor(rgba(S.text))
        else
            art:SetUV(UV.ddNormal)
            arrow:SetVertexColor(0.78, 0.66, 0.45)
            text:SetTextColor(rgba(S.text))
        end
    end
    function row:OnHover(state)
        hovered = state and self.enabled
        paintBox()
    end
    function box:OnListClosed()
        pressed = false
        paintBox()
    end
    box:SetScript("OnMouseDown", function()
        if not row.enabled then return end
        pressed = true
        paintBox()
    end)
    box:SetScript("OnMouseUp", function()
        pressed = false
        paintBox()
    end)
    box:SetScript("OnClick", function(self)
        if not row.enabled then return end
        W.OpenList(self, items(), access.get(), function(value) access.set(value) end)
        paintBox()
    end)
    bindTooltip(box, row)
    function row:OnEnabledChanged(enabled)
        box:EnableMouse(enabled)
        if not enabled and list and list.owner == box then list:Hide() end
        paintBox()
    end
    function row:Refresh()
        local value = access.get()
        local shown, preview
        if opt.type == "media" then
            shown, preview = ui.MediaLabel(opt.kind, value, opt.ignoreGlobal), ui.MediaPreview(opt.kind, value)
        else
            for _, item in ipairs(items()) do
                if ui.SameValue(item[1], value) then
                    shown, preview = item[2], item
                    break
                end
            end
        end
        text:SetFontObject(W.fonts.label)
        if preview and preview.font then
            text:SetFont(S.font, 12)
            text:SetFont(preview.font, 12)
        end
        text:SetText(shown or tostring(value or ""))
        if preview and preview.texture then
            swatch:SetTexture(preview.texture)
            swatch:Show()
            text:SetPoint("RIGHT", -84, 0)
        else
            swatch:Hide()
            text:SetPoint("RIGHT", -24, 0)
        end
        paintBox()
        updateReset(self)
    end
    row.box = box
    row:Refresh()
    return row
end

---------------------------------------------------------------------------------------------------
-- Colour swatch with optional alpha (framed by WoW Forever Slot-Frame)
---------------------------------------------------------------------------------------------------
local pickerStrata
local function restorePicker()
    if pickerStrata then
        ColorPickerFrame:SetFrameStrata(pickerStrata)
        pickerStrata = nil
    end
end

function W.OpenColorPicker(value, hasAlpha, onChange)
    local picker = ColorPickerFrame
    picker:Hide()
    local r, g, b, a = value[1], value[2], value[3], value[4] or 1
    picker.func, picker.opacityFunc, picker.cancelFunc = nil, nil, nil
    picker.hasOpacity = hasAlpha and true or false
    picker.opacity = 1 - a
    picker.previousValues = { r, g, b, a }
    picker:SetColorRGB(r, g, b)
    local function current()
        local nr, ng, nb = picker:GetColorRGB()
        local na = hasAlpha and (1 - (OpacitySliderFrame and OpacitySliderFrame:GetValue() or 0)) or nil
        return { nr, ng, nb, na }
    end
    picker.func = function() onChange(current()) end
    picker.opacityFunc = picker.func
    picker.cancelFunc = function() onChange({ r, g, b, hasAlpha and a or nil }) end
    if not pickerStrata then
        pickerStrata = picker:GetFrameStrata()
        picker:HookScript("OnHide", restorePicker)
    end
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:Show()
    picker:Raise()
end

function W.Color(parent, opt, access, width)
    local row = newRow(parent, opt, access, width, 24, "color")
    local hit = CreateFrame("Button", nil, row)
    hit:SetAllPoints(row)
    local frame = CreateFrame("Frame", nil, hit)
    frame:SetSize(28, 18)
    frame:SetPoint("LEFT", 0, 0)
    W.Skin(frame, { 0.2, 0.2, 0.2, 1 }, S.border)
    local checker = frame:CreateTexture(nil, "BORDER")
    checker:SetTexture(white)
    checker:SetVertexColor(0.55, 0.55, 0.55, 1)
    checker:SetPoint("TOPLEFT", 1, -1)
    checker:SetPoint("BOTTOMRIGHT", frame, "CENTER", 0, 0)
    local checker2 = frame:CreateTexture(nil, "BORDER")
    checker2:SetTexture(white)
    checker2:SetVertexColor(0.55, 0.55, 0.55, 1)
    checker2:SetPoint("TOPLEFT", frame, "CENTER", 0, 0)
    checker2:SetPoint("BOTTOMRIGHT", -1, 1)
    local swatch = frame:CreateTexture(nil, "ARTWORK")
    swatch:SetTexture(white)
    swatch:SetPoint("TOPLEFT", 1, -1)
    swatch:SetPoint("BOTTOMRIGHT", -1, 1)
    local rim = frame:CreateTexture(nil, "OVERLAY")
    applyUV(rim, UV.slotRim)
    rim:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
    rim:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
    rim:SetVertexColor(0.85, 0.78, 0.68)
    local label = W.Text(hit, W.fonts.label)
    label:SetPoint("LEFT", frame, "RIGHT", 9, 0)
    label:SetPoint("RIGHT", row, "RIGHT", -20, 0)
    label:SetHeight(20)
    label:SetText(opt.label or "")
    row.label = label
    local reset = resetButton(row)
    reset:SetPoint("RIGHT", 0, 0)

    hit:SetScript("OnClick", function()
        if not row.enabled then return end
        W.OpenColorPicker(access.get(), opt.alpha, function(color) access.set(color) end)
    end)
    bindTooltip(hit, row)
    function row:OnHover(state)
        local lit = state and self.enabled
        rim:SetVertexColor(lit and 1 or 0.85, lit and 0.92 or 0.78, lit and 0.65 or 0.68)
        frame:SetBackdropBorderColor(rgba(lit and S.accent or S.border))
    end
    function row:OnEnabledChanged(enabled) hit:EnableMouse(enabled) end
    function row:Refresh()
        local color = access.get() or { 1, 1, 1 }
        swatch:SetVertexColor(color[1], color[2], color[3], opt.alpha and (color[4] or 1) or 1)
        updateReset(self)
    end
    row:Refresh()
    return row
end

---------------------------------------------------------------------------------------------------
-- Text input (commonsearch bronze border)
---------------------------------------------------------------------------------------------------
function W.Input(parent, opt, access, width)
    local row = newRow(parent, opt, access, width, 46, "text")
    local label = W.Text(row, W.fonts.label)
    label:SetPoint("TOPLEFT", 0, -2)
    label:SetText(opt.label or "")
    row.label = label
    local reset = resetButton(row)
    reset:SetPoint("TOPRIGHT", 0, -1)
    local input = CreateFrame("EditBox", nil, row)
    input:SetHeight(24)
    input:SetPoint("BOTTOMLEFT", 0, 0)
    input:SetPoint("BOTTOMRIGHT", 0, 0)
    input:SetFontObject(W.fonts.label)
    input:SetAutoFocus(false)
    input:SetTextInsets(8, 8, 0, 0)
    input:SetScript("OnEnterPressed", function(self)
        access.set(self:GetText() or "")
        self:ClearFocus()
    end)
    input:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        row:Refresh()
    end)
    input:SetScript("OnEditFocusGained", function(self)
        self.focused = true
    end)
    input:SetScript("OnEditFocusLost", function(self)
        self.focused = nil
    end)
    W.StyleInput(input, false)
    bindTooltip(input, row)
    row.input = input
    if opt.spellDrop and ui.SpellID then
        local drop = type(opt.spellDrop) == "table" and opt.spellDrop or {}
        ui.SpellID.Attach(input, { list = drop.list, items = drop.items, as = drop.as, commit = function(_, text)
            if row.enabled == false then return end
            access.set(text)
            row:Refresh()
        end })
    end
    function row:OnEnabledChanged(enabled) input:EnableMouse(enabled) end
    function row:Refresh()
        if not input.focused then input:SetText(access.get() or "") end
        updateReset(self)
    end
    row:Refresh()
    return row
end

---------------------------------------------------------------------------------------------------
-- Static content
---------------------------------------------------------------------------------------------------
function W.Header(parent, text, width)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(width, 22)
    local label = W.Text(row, W.fonts.heading)
    label:SetPoint("LEFT", 0, 0)
    label:SetText(text or "")
    local line = W.Divider(row)
    line:SetHeight(2)
    line:SetPoint("LEFT", label, "RIGHT", 10, 0)
    line:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.label = label
    return row
end

function W.Description(parent, text, width)
    local row = CreateFrame("Frame", nil, parent)
    local label = W.Text(row, W.fonts.small)
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetWidth(width)
    label:SetJustifyV("TOP")
    label:SetText(text or "")
    row:SetSize(width, max(14, label:GetStringHeight() + 2))
    row.label = label
    return row
end

function W.ActionButton(parent, opt, width)
    local row = newRow(parent, opt, {}, width, 26, "button")
    local button = W.Button(row, opt.label, min(width, opt.buttonWidth or 220), function()
        if row.enabled and opt.func then opt.func() end
    end, 24)
    button:SetPoint("LEFT", 0, 0)
    if opt.tooltip then
        button:HookScript("OnEnter", function(self) W.ShowTooltip(self, opt.label, opt.tooltip) end)
        button:HookScript("OnLeave", GameTooltip_Hide)
    end
    function row:OnEnabledChanged(enabled)
        if enabled then button:Enable() else button:Disable() end
        self:SetAlpha(1)
    end
    function row:Refresh() end
    row.button = button
    return row
end

-- Builds the right control for an option description.
function W.Create(parent, opt, access, width)
    local kind = opt.type
    if kind == "toggle" then return W.Toggle(parent, opt, access, width) end
    if kind == "range" then return W.Range(parent, opt, access, width) end
    if kind == "select" or kind == "media" then return W.Select(parent, opt, access, width) end
    if kind == "color" then return W.Color(parent, opt, access, width) end
    if kind == "text" then return W.Input(parent, opt, access, width) end
    if kind == "button" then return W.ActionButton(parent, opt, width) end
    if kind == "header" then return W.Header(parent, opt.label, width) end
    if kind == "description" then return W.Description(parent, opt.label, width) end
end
