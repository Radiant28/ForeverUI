-- WoW Forever window chrome (WindowSkin.lua): atlas geometry and hiding / restoring the client's chrome.
local forbidden = { "C_Timer", "BackdropTemplate", "FramePool", "SetColorTexture", "SetAtlas", "C_AddOns", "SetShown(" }
local file = assert(io.open("WindowSkin.lua", "r"))
local source = file:read("*a")
file:close()
for _, keyword in ipairs(forbidden) do assert(not source:find(keyword, 1, true), "WindowSkin.lua: " .. keyword) end

-- Minimal frame mock.
local events = {}
local function region(kind, parent)
    local r = { kind = kind, parent = parent, alpha = 1, shown = true, level = 1, w = 0, h = 0, points = {}, scripts = {},
        children = {}, regions = {} }
    if parent and parent.regions and kind ~= "Frame" and kind ~= "Button" and kind ~= "PlayerModel" then
        parent.regions[#parent.regions + 1] = r
    end
    function r:GetChildren() return unpack(self.children) end
    function r:GetRegions() return unpack(self.regions) end
    function r:GetParent() return self.parent end
    function r:SetBlendMode(mode) self.blend = mode end
    function r:SetAllPoints(target) self.points = { { "TOPLEFT", target }, { "BOTTOMRIGHT", target } } end
    function r:SetDrawLayer(layer, sub) self.layer, self.sublevel = layer, sub end
    function r:SetDesaturated(d) self.desaturated = d end
    function r:SetScale(s) self.scale = s end
    function r:GetScale() return self.scale or 1 end
    function r:SetVertexColor(red, g, b) self.color = { red, g, b } end
    function r:GetTexCoord()
        if self.coords then return unpack(self.coords) end
        return 0, 0, 0, 1, 1, 0, 1, 1
    end
    function r:GetFrameStrata() return self.strata or (self.parent and self.parent.GetFrameStrata and self.parent:GetFrameStrata()) or "MEDIUM" end
    function r:SetFrameStrata(s) self.strata = s end
    function r:SetParent(p) self.parent = p end
    function r:IsEnabled() return 1 end
    function r:GetTop() return self.top end
    function r:GetLeft() return self.left end
    function r:GetBottom() return self.bottom end
    function r:GetDrawLayer() return self.layer or "ARTWORK" end
    function r:GetText() return self.text end
    function r:GetCenter() return 0, self.centerY end
    function r:GetObjectType() return self.kind end
    function r:SetAlpha(a) self.alpha = a end
    function r:GetAlpha() return self.alpha end
    function r:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function r:Hide() self.shown = false end
    function r:IsShown() return self.shown end
    function r:SetTexture(path) self.texture = path end
    function r:GetTexture() return self.texture end
    function r:SetTexCoord(...) self.coords = { ... } end
    function r:ClearAllPoints() self.points = {} end
    function r:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function r:GetNumPoints() return #self.points end
    function r:GetPoint(i) return unpack(self.points[i]) end
    function r:SetWidth(w) self.w = w end
    function r:SetHeight(h) self.h = h end
    function r:GetWidth() return self.w end
    function r:GetHeight() return self.h end
    function r:SetFrameLevel(l) self.level = l end
    function r:GetFrameLevel() return self.level end
    function r:GetEffectiveScale() return 1 end
    function r:GetName() return self.name end
    function r:SetScript(name, fn) self.scripts[name] = fn end
    function r:HookScript(name, fn)
        local old = self.scripts[name]
        self.scripts[name] = function(...) if old then old(...) end fn(...) end
    end
    function r:RegisterEvent(e) events[e] = events[e] or {}; events[e][#events[e] + 1] = self end
    function r:CreateTexture() local t = region("Texture", self); return t end
    return r
end
function CreateFrame(kind, name, parent)
    local f = region(kind, parent)
    f.name = name
    if parent then
        f.level = parent.level + 1
        parent.children[#parent.children + 1] = f
    end
    if name then _G[name] = f end
    return f
end
function hooksecurefunc(target, name, fn)
    if type(target) == "table" then
        local old = target[name]
        target[name] = function(...) local a, b = old(...); fn(...); return a, b end
        return
    end
    name, fn = target, name
    local old = _G[name]
    _G[name] = function(...) local a, b = old(...); fn(...); return a, b end
end
function SetPortraitTexture(tex, unit) tex.portraitUnit = unit end
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { lines = {}, AddMessage = function(self, text) self.lines[#self.lines + 1] = text end }
local function fire(event, ...)
    for _, f in ipairs(events[event] or {}) do f.scripts.OnEvent(f, event, ...) end
end

-- A Nozdor-style character window: client metal chrome on the MetalBorder child, ring portrait, 3D model.
local window = CreateFrame("Frame", "CharacterFrame")
window.w, window.h, window.level = 384, 424, 5
local border = CreateFrame("Frame", nil, window)
border.level = 7
window.MetalBorder = border
for _, key in ipairs({ "CornerTopLeft", "CornerTopRight", "CornerBottomLeft", "CornerBottomRight",
    "BorderTop", "BorderBottom", "BorderLeft", "BorderRight", "TitleText" }) do
    border[key] = region("Texture", border)
end
window.ringPortrait = region("Texture", window)
window.CloseButton = CreateFrame("Button", "CharacterFrameCloseButton", window)
window.CloseButton.level = 6
local closeRed = region("Texture", window.CloseButton)       -- the client's red close art
local bg = region("Texture", window); _G.CharacterFrameBg = bg
-- The client's title bar of the metal chrome lies on the window itself (Nozdor: alpha 0.5).
local titleBar = region("Texture", window); titleBar.texture = "Interface\\FrameGeneral\\UIFrameHorizontal"; titleBar.alpha = 0.5
local model = CreateFrame("PlayerModel", "CharacterFramePortraitModel", window)
-- Inner panel reaching the bottom edge, with a deeper child: the chrome must lie above both.
local panel = CreateFrame("Frame", "PaperDollFrameNewPanel", window)
panel.level = 9
local panelRow = CreateFrame("Frame", nil, panel)
panelRow.level = 12
local panelFill = region("Texture", panel); panelFill.texture = "Interface\\CharacterFrame\\StatsPanelFill"
local panelCorner = region("Texture", panel); panelCorner.texture = "Interface\\CharacterFrame\\StatsPanelCorner"
local rowArt = region("Texture", panelRow); rowArt.texture = "Interface\\CharacterFrame\\StatRow"
-- Category headers: one with .Background, one with only a texture.
-- Category headers: unnamed, found by their titles; one with .Background, one with only a texture.
local header1 = CreateFrame("Frame", nil, panelRow)
header1.Background = region("Texture", header1); header1.Background.h = 24
local h1text = region("FontString", header1); h1text.text = "Характеристики"
-- Nozdor's header: a button with two caps and a middle, the same three on HIGHLIGHT, and the dropdown arrow.
local header2 = CreateFrame("Button", nil, panelRow)
header2.w, header2.h = 234, 22
local header2Plate = region("Texture", header2); header2Plate.w, header2Plate.h = 1024, 30
local header2CapL = region("Texture", header2); header2CapL.w, header2CapL.h = 21, 30
local header2CapR = region("Texture", header2); header2CapR.w, header2CapR.h = 21, 30
local header2Glow = region("Texture", header2); header2Glow.alpha, header2Glow.w, header2Glow.layer = 0.25, 21, "HIGHLIGHT"
header2CapL.left, header2CapR.left = 100, 313        -- laid out: the left cap is the one further left
for _, t in ipairs({ header2Plate, header2CapL, header2CapR, header2Glow }) do
    t.texture = "Interface\\PaperDollInfoFrame\\PaperDollInfoPart1"
end
local header2Arrow = region("Texture", header2); header2Arrow.texture = "Interface\\Buttons\\MinimalScrollbarProportional"
local h2text = region("FontString", header2); h2text.text = "Item Level"
header1.level, header2.level = 11, 11
-- The visible stats panel (Nozdor: PaperDollFrameStrengthenFrame), a decoration frame (no text) and a row.
local statsPane = CreateFrame("Frame", "PaperDollFrameStrengthenFrame", window)
statsPane.w, statsPane.h, statsPane.level = 220, 330, 6
local paneFill = region("Texture", statsPane); paneFill.texture = "Interface\\Nozdor\\StatsPane"
local paneDecor = CreateFrame("Frame", nil, statsPane); paneDecor.level = 6
local decorTex = region("Texture", paneDecor); decorTex.texture = "Interface\\Nozdor\\Corner"
local paneHeader = CreateFrame("Frame", nil, statsPane); paneHeader.w, paneHeader.h, paneHeader.level = 200, 24, 7
local paneHeaderTex = region("Texture", paneHeader); paneHeaderTex.w, paneHeaderTex.h = 200, 24
paneHeaderTex.texture = "Interface\\PaperDollInfoFrame\\PaperDollInfoPart1"
local paneHeaderText = region("FontString", paneHeader); paneHeaderText.text = "Заклинания"
local paneRow = CreateFrame("Frame", nil, statsPane); paneRow.level = 7
local paneRowTex = region("Texture", paneRow)
local paneRowText = region("FontString", paneRow); paneRowText.text = "Сила"
PaperDollFrame = CreateFrame("Frame", "PaperDollFrame", window)
-- ForeverUI's "Labels" button, anchored next to the client's close button.
local labels = CreateFrame("Button", "ForeverStockUI_CharacterLabels", PaperDollFrame)
labels.points = { { "RIGHT", window.CloseButton, "LEFT", -4, 0 } }
labels.level = 7
PaperDollFrame_UpdateStats = function() end
-- Item slot with the client's grey frame and its empty-slot icon.
local slot = CreateFrame("Button", "CharacterHeadSlot", panel)
slot.level = 10
local slotFrame = region("Texture", slot); slotFrame.texture = "Interface\\CharacterFrame\\Char-Paperdoll-Parts"
local slotIcon = region("Texture", slot); slotIcon.texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Head"
slot.w, slot.h, slotIcon.w, slotIcon.h = 37, 37, 37, 37
local qualityBorder = region("Texture", slot); qualityBorder.texture = "Interface\\Common\\WhiteIconFrame"
qualityBorder.w, qualityBorder.h = 37, 37
-- Icons larger than the button (this client): an item picture and the named IconTexture region.
local bigIcon = region("Texture", slot); bigIcon.texture = "Interface\\Icons\\INV_Helmet_01"
bigIcon.w, bigIcon.h = 44, 44
local namedIcon = region("Texture", slot); namedIcon.texture = "Some\\Odd\\Path"
namedIcon.w, namedIcon.h = 44, 44
_G.CharacterHeadSlotIconTexture = namedIcon
-- Ammo slot: its frame is a larger texture with its own file.
local ammo = CreateFrame("Button", "CharacterAmmoSlot", panel)
ammo.w, ammo.h = 30, 30
local ammoBorder = region("Texture", ammo); ammoBorder.texture = "Interface\\PaperDoll\\UI-Ammo-Frame"
ammoBorder.w, ammoBorder.h = 40, 40
local ammoIcon = region("Texture", ammo); ammoIcon.texture = "Interface\\Icons\\INV_Ammo_Arrow_01"
ammoIcon.w, ammoIcon.h = 30, 30
-- A slot the recipe does not name: its grey frame is a texture on a holder frame.
local holder = CreateFrame("Frame", nil, panel)
local ammoFrame = region("Texture", holder); ammoFrame.texture = "Interface\\CharacterFrame\\Char-Paperdoll-Parts"
ammoFrame.w, ammoFrame.h = 40, 40
local bigPart = region("Texture", holder); bigPart.texture = "Interface\\CharacterFrame\\Char-Paperdoll-Parts"
bigPart.w, bigPart.h = 200, 300
local tinyPart = region("Texture", holder); tinyPart.texture = "Interface\\CharacterFrame\\Char-Paperdoll-Parts"
tinyPart.w, tinyPart.h = 8, 9
-- The client's close button: 20 px, at the window's top-right corner.
window.CloseButton.w, window.CloseButton.h = 20, 20
window.CloseButton.points = { { "TOPRIGHT", window, "TOPRIGHT", 2, 3 } }
-- Title 12 px below the window top; the header centre at scale 0.5 is 15.5 px (+1 nudge).
window.top = 500
border.TitleText.centerY = 488
border.TitleText.points = { { "TOP", border, "TOP", 0, -6 } }
MetalFrame2X_Decorate = function(frame) frame.decorated = (frame.decorated or 0) + 1 end
CloseButton2X_Apply = function(button) end

local db = {}
local ui = { Settings = function() return db end }
assert(loadfile("WindowSkin.lua"))("ForeverUI", ui)
local WS = ui.WindowSkin

local function near(a, b) return math.abs(a - b) < 0.001 end

-- Geometry: corners sit on the frame corners, edges join them without gaps, bands match the corner bars.
for _, ring in ipairs({ false, true }) do
    for _, s in ipairs({ 0.5, 0.35, 0.75 }) do
        local w, h = 384, 424
        local pieces, extra = WS.Layout(w, h, s, ring)
        local byName = {}
        for _, p in ipairs(pieces) do
            byName[p.name] = byName[p.name] or {}
            table.insert(byName[p.name], p)
            assert(p.l >= 0 and p.r <= 1.0001 and p.t >= 0 and p.b <= 1.0001, "coords stay inside the file")
            assert(p.w > 0 and p.h > 0)
        end
        local tl, tr = byName.TopLeft[1], byName.TopRight[1]
        local bl, br = byName.BottomLeft[1], byName.BottomRight[1]
        -- Outer metal corner of each corner piece is the frame corner.
        assert(near(tl.x + (ring and 9 or 0) * s, 0) and near(tl.y + (ring and 10 or 0) * s, 0), "top-left on the corner")
        assert(near(tr.x + tr.w, w) and near(tr.y, 0), "top-right on the corner")
        assert(near(bl.x, 0) and near(bl.y + bl.h, h), "bottom-left on the corner")
        assert(near(br.x + br.w, w) and near(br.y + br.h, h), "bottom-right on the corner")
        -- Edges run continuously from corner to corner.
        local function span(list, axis)
            local from, to = math.huge, -math.huge
            local total = 0
            for _, p in ipairs(list) do
                local a = axis == "x" and p.x or p.y
                local len = axis == "x" and p.w or p.h
                from, to, total = math.min(from, a), math.max(to, a + len), total + len
            end
            assert(near(to - from, total), "edge strips leave no gap")
            return from, to
        end
        local a, b = span(byName.Top, "x")
        assert(near(a, tl.x + tl.w) and near(b, tr.x), "top edge joins the top corners")
        assert(near(byName.Top[1].h, 65 * s), "top band = header height")
        a, b = span(byName.Bottom, "x")
        assert(near(a, bl.x + bl.w) and near(b, br.x), "bottom edge joins the bottom corners")
        assert(near(byName.Bottom[1].y + byName.Bottom[1].h, h))
        a, b = span(byName.Left, "y")
        assert(near(a, tl.y + tl.h) and near(b, bl.y), "left edge joins the left corners")
        assert(near(byName.Left[1].x, 0) and near(byName.Left[1].w, 21 * s))
        a, b = span(byName.Right, "y")
        assert(near(a, tr.y + tr.h) and near(b, br.y), "right edge joins the right corners")
        assert(near(byName.Right[1].x + byName.Right[1].w, w))
        if ring then
            local p = extra.portrait
            assert(near(p.x + p.w / 2, 56 * s) and near(p.y + p.h / 2, 52 * s), "portrait centred in the bright rim of the ring")
        else
            assert(not extra.portrait)
        end
        assert(extra.ground.w > 0 and extra.ground.r <= 1)
    end
end

-- Login hooks the window; showing it hides the client's chrome and draws the new one. Values saved by the
-- sliders of earlier versions are dropped (the page has only checkboxes now).
db.foreverWindowOutsetBottom, db.foreverWindowStats = 3, false
fire("PLAYER_LOGIN")
assert(SlashCmdList.FUIFRAME, "/fuiframe registered")
window.CloseButton.level = 6
window.scripts.OnShow(window)
local st = WS.skins[window]
assert(st and st.active, "chrome on")
assert(st.chrome.shown and st.chrome.level == 13, "chrome above every inner panel")
assert(border.level == 14, "client chrome (title) lifted above")
assert(window.CloseButton.level == 15, "close button above the title")
assert(closeRed.alpha == 0 and st.closeFace.shown and st.closeGlow.blend == "ADD", "Forever close button")
assert(slotFrame.alpha == 0 and slotIcon.alpha == 1, "grey slot frame hidden, empty-slot icon kept")
assert(st.rims[slot] and st.rims[slot].shown, "slot rim")
assert(qualityBorder.alpha == 1, "quality border kept")
-- Stats panel: client fill and corners hidden, Forever ground and nine-slice frame drawn; rows untouched.
local art = st.panels[statsPane]
assert(not st.panels[panel] and panelFill.alpha == 1, "the empty 64 px holder is not skinned")
assert(paneFill.alpha == 0 and rowArt.alpha == 1, "panel's own art replaced, rows kept")
assert(art.ground.shown and #art.pieces == 8, "ground and inset frame")
for _, tex in ipairs(art.pieces) do
    for _, c in ipairs(tex.coords) do assert(c >= 0 and c <= 1) end
end
-- Headers: plate in three slices over the client's plate; caps keep the plate proportions.
local plate1, plate2 = st.headers[header1], st.headers[header2]
assert(header1.Background.alpha == 0 and plate1.mid.shown and plate1.left.points[1][2] == header1.Background, "plate over .Background")
assert(near(plate1.left.w, 24 * 16 / 30), "cap width follows the header height")
assert(plate2.left.points[1][2] == header2CapL and plate2.right.points[1][2] == header2CapR,
    "plate spans the client plate: left cap to right cap")
assert(plate2.glow.left.points[1][2] == header2CapL, "highlight plate the same size")
assert(header2Plate.alpha == 0 and header2CapL.alpha == 0 and header2CapR.alpha == 0 and header2Glow.alpha == 0,
    "every client plate piece hidden, highlight too")
assert(header2Arrow.alpha == 1, "dropdown arrow kept")
assert(plate2.glow.mid.shown and plate2.glow.mid.blend == "ADD", "Forever plate highlight")
assert(near(plate2.left.w, 30 * 16 / 30), "caps follow the client plate height (30)")
-- Found by title text: panel art and its decoration replaced, header plate replaced, the row untouched.
assert(decorTex.alpha == 0, "decoration frame without text cleared")
assert(st.headers[paneHeader] and paneHeaderTex.alpha == 0, "header found by its title")
assert(tinyPart.alpha == 1 and not st.rims[tinyPart], "small divider pieces are not slots")
assert(paneRowTex.alpha == 1, "rows with text untouched")
-- The client re-dresses the panel (new art on the fill): skinned again after the stats update.
paneFill.alpha = 1
PaperDollFrame_UpdateStats()
assert(paneFill.alpha == 0, "re-dressed panel hidden again")
assert(bigIcon.alpha == 1 and namedIcon.alpha == 1, "icons larger than the button kept")
assert(ammoBorder.alpha == 0 and ammoIcon.alpha == 1 and st.rims[ammo].shown, "ammo frame replaced, icon kept")
assert(ammoFrame.alpha == 0 and st.rims[ammoFrame] and st.rims[ammoFrame].shown, "unnamed slot frame gets the rim")
assert(st.rims[ammoFrame].points[1][2] == ammoFrame, "rim over the client's frame")
assert(bigPart.alpha == 1 and not st.rims[bigPart], "large paperdoll art untouched")
local cp = window.CloseButton.points[1]
assert(cp[1] == "TOPRIGHT" and cp[2] == st.chrome and cp[3] == "TOPRIGHT", "close button on the corner")
assert(cp[4] == -2 and cp[5] == 0, "2 px in from the right edge, flush with the top, not outside")
assert(window.CloseButton.w == 28 and st.closeFace.points[1][2] == window.CloseButton, "as tall as the band")
assert(labels.points[1][2] == window.CloseButton and labels.level == 15, "labels button in the header, above the chrome")
assert(labels.points[1][4] == -4 and labels.points[1][5] == -2, "labels button a little lower than the close button")
assert(st.chrome.points[1][4] == -1, "sides 1 px outward by default")
assert(db.foreverWindowOutsetBottom == nil and db.foreverWindowStats == nil, "old slider and toggle values dropped at login")
local tp = border.TitleText.points[1]
assert(near(tp[5], -6 + (12 - 15.5 - 1 + 12)), "title centred in the raised header: " .. tostring(tp[5]))
-- The client re-dresses the close button with new red art: it is hidden again.
local closeRed2 = region("Texture", window.CloseButton)
CloseButton2X_Apply(window.CloseButton)
assert(closeRed2.alpha == 0, "re-dressed close button hidden again")
assert(border.CornerTopLeft.alpha == 0 and border.BorderRight.alpha == 0, "client metal hidden")
assert(border.TitleText.alpha == 1, "title kept")
assert(not window.ringPortrait.shown and not model.shown, "client portrait hidden")
assert(bg.alpha == 0 and st.ground.shown, "rock ground")
assert(titleBar.alpha == 0, "client title bar hidden (its line crossed the ring)")
assert(st.portrait.portraitUnit == "player" and st.portrait.shown, "portrait in the ring")
-- The mock has no layout engine: the size arrives the way the client delivers a late one.
st.chrome.w, st.chrome.h = 384, 424
st.chrome.scripts.OnSizeChanged(st.chrome)
local drawn = 0
for _, t in ipairs(st.tex) do if t.shown then drawn = drawn + 1 end end
assert(drawn >= 8, "corners and edges drawn")

-- The client re-shows its 3D portrait: it stays hidden while the ring is on.
model:Show()
assert(not model.shown, "model kept hidden")

-- Re-applying (options changed, client rebuild) does not stack levels or lose the originals.
MetalFrame2X_Decorate(window)
WS.Apply()
assert(border.level == 14 and window.CloseButton.level == 15 and st.chrome.level == 13, "levels stable on re-apply")
assert(near(border.TitleText.points[1][5], 1.5), "title shift not stacked")

-- Outsets move the chrome around the window.
db.foreverWindowOutsetX, db.foreverWindowOutsetTop = 4, 6
WS.Apply()
local p = st.chrome.points[1]
assert(p[1] == "TOPLEFT" and p[4] == -4 and p[5] == 6 + 12, "outsets (plus the 12 px header raise)")
local pb = st.chrome.points[2]
assert(pb[1] == "BOTTOMRIGHT" and pb[5] == -6, "bottom edge 6 px below the window by default")

-- Without the ring the client's portrait stays.
db.foreverWindowPortrait = false
WS.Apply()
assert(window.ringPortrait.shown and not st.portrait.shown, "client portrait kept without the ring")
db.foreverWindowPortrait = nil

-- Turning the option off restores everything.
db.foreverWindows = false
WS.Apply()
assert(not st.active and not st.chrome.shown and not st.ground.shown, "chrome off")
assert(border.CornerTopLeft.alpha == 1 and bg.alpha == 1, "client chrome back")
assert(border.level == 7 and window.CloseButton.level == 6, "levels back")
assert(window.ringPortrait.shown and model.shown, "client portrait back")
assert(closeRed.alpha == 1 and not st.closeFace.shown, "client close button back")
assert(window.CloseButton.points[1][1] == "TOPRIGHT" and window.CloseButton.w == 20, "close button back in place")
assert(labels.level == 7 and labels.points[1][1] == "RIGHT", "labels button back")
assert(slotFrame.alpha == 1 and not st.rims[slot].shown, "client slot frame back")
assert(ammoFrame.alpha == 1 and not st.rims[ammoFrame].shown, "unnamed slot frame back")
assert(paneFill.alpha == 1 and header1.Background.alpha == 1 and not art.ground.shown and not plate1.mid.shown,
    "stats panel back")
assert(border.TitleText.points[1][5] == -6, "title back")

-- Diagnostics print without errors.
db.foreverWindows = true
WS.Apply()
SlashCmdList.FUIFRAME("")
assert(#DEFAULT_CHAT_FRAME.lines >= 10, "dump printed")
SlashCmdList.FUIFRAME("tree")
assert(type(db.frameDump) == "table" and #db.frameDump > 20, "tree saved")
local found = false
for _, line in ipairs(db.frameDump) do if line:find("Характеристики", 1, true) then found = true end end
assert(found, "texts in the tree")

-- The window's own checkbox on the Skins page turns only that window off, and back on.
db.skinCharacter = false
WS.Apply()
assert(not st.active and border.CornerTopLeft.alpha == 1, "window checkbox off: client chrome back")
db.skinCharacter = nil
WS.Apply()
assert(st.active, "window checkbox on again")
assert(WS.Recipes.CharacterFrame.key == "skinCharacter" and WS.Order[1] == "CharacterFrame", "recipe exposed for the page")

-- Every listed window is on the page, each with its own key.
assert(#WS.Order >= 30 and WS.Recipes.FriendsFrame.key == "skinFriendsFrame", "all windows listed")

-- An old 3.3.5 window (art painted into the window): the art goes, the chrome takes ElvUI's rect, the portrait
-- moves into the ring, the title rises above the chrome into the header band, the close button is the Forever one.
local friends = CreateFrame("Frame", "FriendsFrame", UIParent)
friends.w, friends.h, friends.level = 384, 512, 3
local friendsArt = region("Texture", friends); friendsArt.texture = "Interface\\FriendsFrame\\UI-FriendsFrame-TopLeft"
local friendsPortrait = region("Texture", friends); friendsPortrait.points = { { "TOPLEFT", friends, "TOPLEFT", 7, -6 } }
friendsPortrait.texture = "Interface\\FriendsFrame\\FriendsFrameScrollIcon"
_G.FriendsFramePortrait = friendsPortrait
local friendsTitle = region("FontString", friends); friendsTitle.points = { { "TOP", friends, "TOP", 0, -17 } }
_G.FriendsFrameTitleText = friendsTitle
local friendsClose = CreateFrame("Button", "FriendsFrameCloseButton", friends)
local friendsCloseArt = region("Texture", friendsClose)
local friendsList = CreateFrame("Frame", nil, friends); friendsList.level = 6
local addFriend = CreateFrame("Button", "FriendsFrameAddFriendButton", friends); addFriend.level = 5
local friendsListArt = region("Texture", friendsList); friendsListArt.texture = "Interface\\FriendsFrame\\List"
friends.shown = true
fire("ADDON_LOADED", "Blizzard_Anything")
local fs = WS.skins[friends]
assert(fs and fs.active, "old window skinned")
local fp1, fp2 = fs.chrome.points[1], fs.chrome.points[2]
assert(fp1[4] == 11 - 4 and fp1[5] == -12 + 12 and fp2[4] == -32 + 4 and fp2[5] == 76,
    "chrome on ElvUI's rect, a little wider, bottom on the tabs, header 12 px higher")
assert(friendsArt.alpha == 0 and friendsListArt.alpha == 1, "window art hidden, children untouched")
assert(friendsPortrait.alpha == 1 and friendsPortrait.points[1][2] == fs.portrait, "portrait moved into the ring")
assert(fs.ring and not fs.portrait.shown, "ring corner, own portrait not drawn")
assert(friendsTitle.parent == fs.titleHolder and friendsTitle.points[1][1] == "CENTER", "title above the chrome, centred")
assert(fs.titleHolder.level > fs.chrome.level, "title holder above the chrome")
assert(friendsCloseArt.alpha == 0 and fs.closeFace.shown, "Forever close button")
assert(fs.chrome.level > friendsList.level, "chrome above the inner frames")
assert(addFriend.level > fs.chrome.level, "bottom buttons drawn above the frame's bottom edge")
assert(fs.ground.sublevel == -8, "ground under everything")
-- Guild bank: the money row sits right above the bottom tabs, so the bottom edge goes 10 px into the tabs (behind
-- it); the side tabs are drawn over the chrome; its close button has no usual name and is found among the children.
local gbank = CreateFrame("Frame", "GuildBankFrame", UIParent)
gbank.w, gbank.h, gbank.level, gbank.top, gbank.bottom = 769, 512, 3, 612, 100
local gbTab = CreateFrame("Button", "GuildBankFrameTab1", gbank); gbTab.level = 5; gbTab.top = 112
local gbSide = CreateFrame("Frame", "GuildBankTab1", gbank); gbSide.level = 4
local gbClose = CreateFrame("Button", "GuildBankFrameXCloseButton", gbank)
gbank.shown = true
fire("ADDON_LOADED", "Blizzard_GuildBankUI")
local gst = WS.skins[gbank]
assert(gst and gst.active, "guild bank skinned")
assert(gst.chrome.points[2][5] == (112 - 100) - 10, "bottom edge 10 px into the tabs: clear of the money row")
assert(gst.chrome.level > gbTab.level, "bottom tabs behind the bottom edge")
assert(gbSide.level > gst.chrome.level, "side tabs over the chrome")
assert(gst.closeButton == gbClose and gbClose.level > gst.chrome.level and gst.closeFace.shown,
    "close button found among the children, WoW Forever face, over the chrome")
assert(not WS.Recipes.AuctionFrame, "no auction house skin")
-- A window without any close button gets one of its own; it goes with the chrome.
local noClose = CreateFrame("Frame", "PetitionFrame", UIParent)
noClose.w, noClose.h, noClose.level = 384, 512, 3
noClose.shown = true
fire("ADDON_LOADED", "Blizzard_Anything")
local nst = WS.skins[noClose]
assert(nst and nst.ownClose and nst.closeButton == nst.ownClose and nst.ownClose.shown, "own close button")
local hidden
HideUIPanel = function(frame) hidden = frame end
nst.ownClose.scripts.OnClick(nst.ownClose)
assert(hidden == noClose, "it closes the window")
db.skinPetitionFrame = false
WS.Apply()
assert(not nst.ownClose.shown, "gone with the chrome")
db.skinPetitionFrame = nil
-- Its checkbox off: everything back.
db.skinFriendsFrame = false
WS.Apply()
assert(not fs.active and friendsArt.alpha == 1 and friendsTitle.parent == friends, "old window back")
assert(friendsPortrait.points[1][2] == friends and friendsTitle.points[1][1] == "TOP", "portrait and title back in place")
db.skinFriendsFrame = nil

-- A Nozdor metal window: skinned like the character window, its own ring portrait moves into the new ring.
local book = CreateFrame("Frame", "SpellBookFrame", UIParent)
book.w, book.h, book.level = 700, 500, 3
book.MetalBorder = CreateFrame("Frame", nil, book)
for _, key in ipairs({ "CornerTopLeft", "BorderTop", "TitleText" }) do book.MetalBorder[key] = region("Texture", book.MetalBorder) end
book.ringPortrait = region("Texture", book)
book.ringPortrait.texture = "Interface\\Icons\\INV_Misc_Book_09"
book.ringPortrait.w, book.ringPortrait.h = 60, 60
local bookBg = region("Texture", book); _G.SpellBookFrameBg = bookBg
book.shown = true
fire("ADDON_LOADED", "Blizzard_Anything")
local bs = WS.skins[book]
assert(bs and bs.active and book.MetalBorder.CornerTopLeft.alpha == 0, "metal window skinned")
-- The mock lays nothing out: the ring hole is 50 px at the default thickness.
bs.portrait.w = 50
WS.Apply()
assert(book.ringPortrait.shown and book.ringPortrait.points[1][1] == "CENTER"
    and book.ringPortrait.points[1][2] == bs.portrait, "square icon centred in the ring")
assert(near(book.ringPortrait.w, 42.5), "square icon: corners under the metal of the rim")
-- An empty portrait slot (the talent window): the player's portrait instead.
local emptyRing = CreateFrame("Frame", "LFDParentFrame", UIParent)
emptyRing.MetalBorder = CreateFrame("Frame", nil, emptyRing)
emptyRing.ringPortrait = region("Texture", emptyRing)
emptyRing.shown = true
fire("ADDON_LOADED", "Blizzard_Anything")
local es = WS.skins[emptyRing]
assert(es.ring and es.portrait.portraitUnit == "player" and es.portrait.shown,
    "empty portrait slot: player portrait")
assert(bookBg.alpha == 0 and bs.ground.shown, "metal window ground")
assert(bs.chrome.points[2][5] == -6, "metal window uses the tuned outsets")
local outsetTop = db.foreverWindowOutsetTop or 0
assert(bs.chrome.points[1][5] == outsetTop + 12, "metal window header 12 px higher")
assert(WS.skins[window].chrome.points[1][5] == outsetTop + 12, "character window header raised like the others")

-- Mail: Postal's Refresh button joins the header, left of the close button.
local mail = CreateFrame("Frame", "MailFrame", UIParent)
local mailClose = CreateFrame("Button", "MailFrameCloseButton", mail)
local refresh = CreateFrame("Button", "PostalRefreshButton", mail)
refresh.points = { { "TOPRIGHT", mail, "TOPRIGHT", -30, -42 } }
mail.shown = true
fire("ADDON_LOADED", "Postal")
assert(refresh.points[1][1] == "RIGHT" and refresh.points[1][2] == mailClose, "Postal button left of the close button")

-- A listed window with neither metal chrome nor a rect keeps the client's look.
local talents = CreateFrame("Frame", "PlayerTalentFrame", UIParent)
talents.shown = true
fire("ADDON_LOADED", "Blizzard_TalentUI")
assert(not (WS.skins[talents] and WS.skins[talents].active), "no metal, no rect: untouched")

-- The map: its metal chrome sits in a child of another name; the portrait is a frame holding the picture; the
-- maximize button joins the header.
local map = CreateFrame("Frame", "WorldMapFrame", UIParent)
local mapBorder = CreateFrame("Frame", "WorldMapFrameBorder", map)
local mapCorner = region("Texture", mapBorder); mapCorner.texture = "Interface\\FrameGeneral\\UIFrameMetal2x"
local mapTitle = region("FontString", mapBorder); mapTitle.text = "Карта и журнал заданий"
mapTitle.points = { { "TOP", mapBorder, "TOP", 0, -5 } }
local mapPortrait = CreateFrame("Frame", "WorldMapFramePortrait", map)
local mapPortraitTex = region("Texture", mapPortrait); mapPortraitTex.texture = "Portrait2"
local mapBack = region("Texture", map); _G.WorldMapFrameBackground = mapBack
local mapClose = CreateFrame("Button", "WorldMapFrameCloseButton", map)
local sizeUp = CreateFrame("Button", "WorldMapFrameSizeUpButton", map)
local sizeDown = CreateFrame("Button", "WorldMapFrameSizeDownButton", map); sizeDown.shown = false
map.shown = true
fire("ADDON_LOADED", "Blizzard_Anything")
local ms = WS.skins[map]
assert(ms and ms.active and mapCorner.alpha == 0, "metal chrome found in a child of another name")
assert(mapPortraitTex.points[1][2] == ms.portrait and #mapPortrait.points == 0, "the portrait frame's picture moved into the ring")
assert(mapBack.alpha == 0, "map background replaced by the rock")
assert(sizeUp.points[1][2] == mapClose and sizeDown.points[1][2] == mapClose, "maximize / minimize share one place")

-- Watchdog: the client re-places the close button and drops it under the chrome (map maximized): the skin is
-- laid again; a window left as the skin put it is not touched.
mapClose.points = { { "TOPRIGHT", map, "TOPRIGHT", -5, -5 } }
mapClose.level = 1
WS.Repair()
assert(mapClose.points[1][2] == ms.chrome and mapClose.level > ms.chrome.level, "watchdog puts the close button back")
local levelBefore = mapClose.level
WS.Repair()
assert(mapClose.level == levelBefore, "nothing to repair: nothing changes")
-- Maximized map: the window moves to a higher stratum, the buttons keep their own one and vanished under the
-- chrome; the watchdog lifts them into the chrome's stratum.
map.strata = "FULLSCREEN"
mapClose.strata, sizeUp.strata = "HIGH", "HIGH"
WS.Repair()
assert(mapClose:GetFrameStrata() == "FULLSCREEN" and sizeUp:GetFrameStrata() == "FULLSCREEN", "buttons follow the chrome's stratum")
-- The maximize button wears the WoW Forever face, as large as the close button, level with it.
local art = ms.arts and ms.arts[sizeUp]
assert(art and art.face.shown and art.face.texture:find("Window%-Buttons"), "Forever maximize button")
assert(sizeUp.w == mapClose.w and sizeUp.points[1][5] == 0, "maximize button the close button's twin")

-- The map's chrome sits at the client's chrome level (an offset from the window), not above all its inner
-- frames: a high absolute level drew it over other windows opened on top of the map.
local mapPoi = CreateFrame("Frame", nil, map); mapPoi.level = map.level + 40
WS.Apply()
assert(ms.chrome.level == map.level + ms.chromeOffset and ms.chrome.level < mapPoi.level, "map chrome at the client's chrome level")
-- A toplevel window clicked moves up: levels are fixed in place, the skin is not laid again (no flicker).
local closePoints = mapClose.points
map.level = map.level + 30
WS.Repair()
assert(ms.chrome.level == map.level + ms.chromeOffset, "chrome follows the raised window")
assert(mapClose.level > ms.chrome.level and mapClose.points == closePoints, "close above it, not re-laid")

-- The map's title sits in the very centre of the header band.
assert(mapTitle.points[1][1] == "CENTER" and mapTitle.points[1][2] == ms.chrome and mapTitle.points[1][3] == "TOP",
    "map title centred in the band")
-- Maximized: the portrait frame follows the chrome into its stratum (it stayed under the rock ground).
map.strata = "FULLSCREEN"
mapPortrait.strata = "HIGH"
WS.Repair()
assert(mapPortrait:GetFrameStrata() == "FULLSCREEN", "map portrait frame in the chrome's stratum")
map.strata = nil

-- Maximized to the whole screen: the resize lays the skin again and the chrome is pulled in so the ring corner
-- stays on the screen (it went past the top edge).
UIParent = CreateFrame("Frame")
UIParent.top = 768
function UIParent:GetEffectiveScale() return 1 end
map.top, map.left, map.w, map.h = 768, 0, 1366, 768
WS.Repair()
local mt = ms.chrome.points[1]
assert(mt[1] == "TOPLEFT" and near(mt[5], -5) and near(mt[4], 4.5), "maximized map: ring kept on the screen")
UIParent = nil

-- Spellbook: its tabs are <Name>TabButtonN; they hang behind the bottom edge too.
local bookTab = CreateFrame("Button", "SpellBookFrameTabButton1", book)
bookTab.level = book.level + 20
WS.skins[book].chromeOffset = nil
WS.Apply()
assert(bookTab.level < WS.skins[book].chrome.level, "spellbook tabs behind the frame")

-- Dungeon finder: its portrait frame (a different picture on each tab) goes into the ring whole, scaled; when the
-- client re-anchors it on a tab switch, it is put back at once. A tab the client raises stays behind the frame.
local hk = CreateFrame("Frame", "HK_LFDPortraitFrame", emptyRing); hk.w = 75
local eye = CreateFrame("Frame", nil, hk)
local eyeTex = region("Texture", eye); eyeTex.texture = "Interface\\LFGFRAME\\uigroupfinderflipbook"
-- The eye sits off the frame's centre: 6.5 px right, 7.5 px down.
function hk:GetCenter() return 100, 100 end
function eyeTex:GetCenter() return 106.5, 92.5 end
local pvpTab = CreateFrame("Button", "HK_LFDTopTabPvp", emptyRing)
es.portrait.w = 50
WS.Apply()
assert(hk.points[1][1] == "CENTER" and hk.points[1][2] == es.portrait and near(hk.scale, 50 * 1.15 / 75),
    "finder portrait frame whole and scaled in the ring")
assert(near(hk.points[1][4], -6.5) and near(hk.points[1][5], 7.5), "the eye, not the frame, centred in the ring")
hk:SetPoint("TOPLEFT", emptyRing, "TOPLEFT", -16, 20)
assert(#hk.points == 1 and hk.points[1][2] == es.portrait, "client re-anchor: back in the ring at once")
pvpTab.level = es.chrome.level + 3
WS.Repair()
assert(pvpTab.level < es.chrome.level, "selected tab raised by the client: still behind the frame")

-- ForeverUI's own backpack window: its header art and ring give way, the backpack icon goes into the ring, the
-- title rises into the band, the close button is the WoW Forever one in the corner.
function SetPortraitToTexture(tex, path) tex.portraitIcon = path end
local bagWin = CreateFrame("Frame", "ForeverStockInventory", UIParent)
local bagHeader = region("Texture", bagWin); bagHeader.texture = "Interface\\AddOns\\ForeverUI\\Art\\BagForever-Header"
local bagRing = CreateFrame("Frame", "ForeverStockInventoryPortraitFrame", bagWin)
local bagTitle = region("FontString", bagWin); _G.ForeverStockInventoryTitleText = bagTitle
bagTitle.points = { { "LEFT", bagWin, "LEFT", 44, 0 } }
local bagClose = CreateFrame("Button", "ForeverStockInventoryCloseButton", bagWin)
local bagCloseArt = region("Texture", bagClose)
bagWin.shown = true
fire("ADDON_LOADED", "ForeverUI")
local bs2 = WS.skins[bagWin]
assert(bs2 and bs2.active and bagHeader.alpha == 0 and not bagRing.shown, "bag header and ring replaced")
assert(bs2.portrait.portraitIcon == "Interface\\Buttons\\Button-Backpack-Up" and bs2.portrait.shown, "backpack icon in the ring")
assert(bagTitle.parent == bs2.titleHolder and bagTitle.points[1][1] == "CENTER", "bag title in the band")
assert(bagCloseArt.alpha == 0 and bagClose.points[1][2] == bs2.chrome, "bag close button: Forever, in the corner")

-- Collections: a square icon, even a portrait icon, fits inside the circle.
local coll = CreateFrame("Frame", "NozdorCollectionsFrame", UIParent)
coll.MetalBorder = CreateFrame("Frame", nil, coll)
local collPortrait = CreateFrame("Frame", "NozdorCollectionsFramePortraitFrame", coll)
local collIcon = region("Texture", collPortrait); collIcon.texture = "Interface\\ICONS\\mountjournalportrait"
coll.shown = true
fire("ADDON_LOADED", "Blizzard_Anything")
local cs = WS.skins[coll]
cs.portrait.w = 50
WS.Apply()
assert(collIcon.points[1][1] == "CENTER" and near(collIcon.w, 42.5), "square portrait icon: corners under the rim")
assert(collIcon.coords and near(collIcon.coords[1], 0.08), "icon border cropped")

-- Merchant on Nozdor: the client's metal chrome is a smaller rect inside the window (345 x 456 at 15, 17), the
-- tabs sit just under it; the new chrome follows that rect and ends right on top of the tabs.
local merchant = CreateFrame("Frame", "MerchantFrame", UIParent)
merchant.w, merchant.h, merchant.top, merchant.bottom = 384, 512, 612, 100
local merchantHolder = CreateFrame("Frame", nil, merchant)
merchantHolder.w, merchantHolder.h, merchantHolder.top, merchantHolder.bottom = 345, 456, 595, 139
local merchantMetal = region("Texture", merchantHolder); merchantMetal.texture = "Interface\\FrameGeneral\\UIFrameMetal2x"
local merchantInset = CreateFrame("Frame", "MerchantFrameInset", merchant)
local merchantInsetBg = region("Texture", merchantInset); merchantInsetBg.texture = "Interface\\FrameGeneral\\UI-Background-Marble"
local repairButton = CreateFrame("Button", "MerchantRepairItemButton", merchant)
local repairIcon = region("Texture", repairButton)
repairIcon.texture = "Interface\\MerchantFrame\\UI-Merchant-RepairIcons"
repairIcon.coords = { 0.28, 0, 0.28, 0.56, 0.56, 0, 0.56, 0.56 }
local merchantTab = CreateFrame("Button", "MerchantFrameTab1", merchant)
merchantTab.level = merchant.level + 5        -- Nozdor: above the client's chrome level
merchantTab.top = 141
merchant.shown = true
fire("ADDON_LOADED", "Blizzard_Anything")
local mst = WS.skins[merchant]
assert(merchantInsetBg.texture:find("Window%-InsetGround"), "merchant insets on the warm WoW Forever ground")
-- Repair unavailable: the WoW Forever icon goes grey with its button; available again: in colour.
assert(not repairIcon.desaturated, "repair icon in colour while the button works")
function repairButton:IsEnabled() return nil end
WS.Repair()
assert(repairIcon.desaturated and repairIcon.color[1] < 1, "disabled repair button: grey icon")
function repairButton:IsEnabled() return 1 end
WS.Repair()
assert(not repairIcon.desaturated and repairIcon.color[1] == 1, "enabled again: colour back")
-- Another merchant: the client sets its marble again; the warm stone comes back at once.
merchantInsetBg:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble")
assert(merchantInsetBg.texture:find("Window%-InsetGround"), "client's marble re-set: warm stone again")
assert(mst.ground.texture:find("Window%-InsetGround"), "merchant window ground warm too")
assert(WS.skins[friends].ground.texture:find("Window%-InsetGround"), "every window on the warm stone")
assert(repairIcon.texture:find("Window%-Merchant") and near(repairIcon.coords[1], 74 / 512), "Forever repair hammer")
db.skinMerchantFrame = false
WS.Apply()
assert(repairIcon.texture:find("RepairIcons") and near(repairIcon.coords[1], 0.28), "client repair icon back")
assert(merchantInsetBg.texture:find("UI%-Background%-Marble"), "client inset ground back")
db.skinMerchantFrame = nil
WS.Apply()
local m1, m2 = mst.chrome.points[1], mst.chrome.points[2]
assert(m1[2] == merchantHolder and m2[2] == merchantHolder, "merchant chrome on the client's metal rect")
assert(m2[5] == -6, "merchant: bottom edge on top of the tabs, 8 px over them")
assert(merchantTab.level < mst.chrome.level, "merchant tabs behind the frame's bottom edge")

-- Shop: a portrait frame whose picture has wide margins is enlarged in the ring.
local shop = CreateFrame("Frame", "StoreFrame", UIParent)
shop.MetalBorder = CreateFrame("Frame", nil, shop)
local shopPortrait = CreateFrame("Frame", "StoreFramePortraitFrame", shop)
local shopCoin = region("Texture", shopPortrait); shopCoin.texture = "Interface\\Store\\store-head-buttons"
shop.shown = true
fire("ADDON_LOADED", "Blizzard_Anything")
local ss = WS.skins[shop]
ss.portrait.w = 50
WS.Apply()
assert(shopCoin.points[1][1] == "CENTER" and near(shopCoin.w, 75), "shop coin enlarged 1.5 times in the ring")


-- SkinExtras.lua: stock panel buttons get the WoW Forever button; other buttons are left alone.
assert(loadfile("SkinExtras.lua"))("ForeverUI", ui)
local function stockButton(path)
    local b = CreateFrame("Button", nil, window)
    local n, p, d, h = region("Texture", b), region("Texture", b), region("Texture", b), region("Texture", b)
    n.texture = path
    function b:GetNormalTexture() return n end
    function b:GetPushedTexture() return p end
    function b:GetDisabledTexture() return d end
    function b:GetHighlightTexture() return h end
    return b, n, h
end
local panelButton, panelNormal, panelHighlight = stockButton("Interface\\Buttons\\UI-Panel-Button-Up")
local otherButton, otherNormal = stockButton("Interface\\Buttons\\UI-Quickslot2")
ui.SkinExtras.SkinButton(panelButton)
ui.SkinExtras.SkinButton(otherButton)
assert(panelNormal.texture:find("Panel%-Button") and panelHighlight.blend == "ADD", "panel button reskinned")
assert(otherNormal.texture == "Interface\\Buttons\\UI-Quickslot2", "other buttons untouched")
db.characterSkin = true
fire("PLAYER_LOGIN")
assert(db.characterSkin == nil, "old warm tint switch dropped")
assert(not io.open("CharacterSkin.lua", "r"), "warm tint module removed")

print("WindowSkin tests passed")
