-- Automated Lua 5.1 tests for ForeverUI BagAero (run with lupa.luajit21 from ForeverUI dir).
local function checkSource(path)
    local srcFile = assert(io.open(path, "r"))
    local source = srcFile:read("*a")
    srcFile:close()
    for _, keyword in ipairs({
        "C_Timer", "BackdropTemplate", "FramePool", "CreateFramePool", "Settings.RegisterCanvas",
        "SetColorTexture", "SetAtlas", "C_AddOns", "SetShown(", "CreateMaskTexture", "C_NamePlate",
    }) do
        assert(not source:find(keyword, 1, true), path .. ": Forbidden API found: " .. keyword)
    end
    for _, badChar in ipairs({ "\194\183", "\226\134\146", "\195\151", "\226\136\146", "\226\128\162" }) do
        local n = 0
        for line in source:gmatch("[^\r\n]+") do
            n = n + 1
            if not line:match("^%s*%-%-") then
                assert(not line:find(badChar, 1, true), path .. ": Unsupported ruRU glyph on L" .. n)
            end
        end
    end
end

checkSource("BagAero.lua")
checkSource("Options/Bags.lua")
checkSource("Options/Skins.lua")

-- Verify all 9 TGA assets exist and have valid 32-bit uncompressed headers with power-of-two dimensions.
local function isPow2(v)
    if v < 1 then return false end
    while v > 1 do
        if v % 2 ~= 0 then return false end
        v = v / 2
    end
    return true
end

local expectedArt = {
    "Aero-Backdrop.tga", "Aero-Bubbles.tga", "Aero-Close.tga", "Aero-Divider.tga",
    "Aero-Frame.tga", "Aero-Header.tga", "Aero-Orb.tga", "Aero-Pill.tga", "Aero-Slot.tga",
}
for _, fileName in ipairs(expectedArt) do
    local f = assert(io.open("Art/Aero/" .. fileName, "rb"), "Missing TGA asset: " .. fileName)
    local hdr = f:read(18)
    f:close()
    assert(hdr and #hdr == 18, "Truncated TGA header: " .. fileName)
    local imgT = hdr:byte(3)
    local w = hdr:byte(13) + hdr:byte(14) * 256
    local h = hdr:byte(15) + hdr:byte(16) * 256
    local bits = hdr:byte(17)
    local d = hdr:byte(18)
    assert(imgT == 2 and bits == 32 and d == 8 and isPow2(w) and isPow2(h),
        ("Invalid TGA header in %s: type=%d bpp=%d desc=%d size=%dx%d"):format(fileName, imgT, bits, d, w, h))
end

-- Minimal WoW 3.3.5a frame mock
local events = {}
local function region(kind, parent)
    local r = {
        kind = kind, parent = parent, alpha = 1, shown = true, level = 1, w = 0, h = 0,
        points = {}, scripts = {}, children = {}, regions = {}, color = { 1, 1, 1, 1 },
        shadowColor = { 0, 0, 0, 1 }, shadowOffset = { 1, -1 },
    }
    if parent and parent.regions and kind ~= "Frame" and kind ~= "Button" and kind ~= "EditBox" then
        parent.regions[#parent.regions + 1] = r
    end
    function r:GetObjectType() return self.kind end
    function r:GetParent() return self.parent end
    function r:GetChildren() return unpack(self.children) end
    function r:GetRegions() return unpack(self.regions) end
    function r:GetName() return self.name end
    function r:SetParent(p) self.parent = p end
    function r:SetAlpha(a) self.alpha = a end
    function r:GetAlpha() return self.alpha end
    function r:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function r:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
    function r:IsShown() return self.shown end
    function r:IsVisible() return self.shown end
    function r:SetTexture(p) self.texture = p end
    function r:GetTexture() return self.texture end
    function r:SetTexCoord(...) self.coords = { ... } end
    function r:SetBlendMode(m) self.blend = m end
    function r:SetVertexColor(red, g, b, a) self.vertex = { red, g, b, a or 1 } end
    function r:GetVertexColor() local v = self.vertex or { 1, 1, 1, 1 }; return unpack(v) end
    function r:SetTextColor(red, g, b, a) self.color = { red, g, b, a or 1 } end
    function r:GetTextColor() return unpack(self.color) end
    function r:SetShadowColor(red, g, b, a) self.shadowColor = { red, g, b, a or 1 } end
    function r:GetShadowColor() return unpack(self.shadowColor) end
    function r:SetShadowOffset(x, y) self.shadowOffset = { x, y } end
    function r:GetShadowOffset() return unpack(self.shadowOffset) end
    function r:ClearAllPoints() self.points = {} end
    function r:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function r:SetAllPoints(target) self.points = { { "TOPLEFT", target }, { "BOTTOMRIGHT", target } } end
    function r:GetNumPoints() return #self.points end
    function r:GetPoint(i) return unpack(self.points[i]) end
    function r:SetWidth(w) self.w = w end
    function r:SetHeight(h) self.h = h end
    function r:SetSize(w, h) self.w, self.h = w, h end
    function r:GetWidth() return self.w end
    function r:GetHeight() return self.h end
    function r:SetFrameLevel(l) self.level = l end
    function r:GetFrameLevel() return self.level end
    function r:EnableMouse(v) self.mouse = v end
    function r:IsMouseOver() return self.mouseOver end
    function r:SetBackdrop(b) self.backdrop = b end
    function r:GetBackdrop() return self.backdrop end
    function r:SetBackdropColor(r0, g0, b0, a0) self.backdropColor = { r0, g0, b0, a0 or 1 } end
    function r:GetBackdropColor() if self.backdropColor then return unpack(self.backdropColor) end end
    function r:SetBackdropBorderColor(r0, g0, b0, a0) self.backdropBorder = { r0, g0, b0, a0 or 1 } end
    function r:GetBackdropBorderColor() if self.backdropBorder then return unpack(self.backdropBorder) end end
    function r:GetNormalTexture() return self.normalTex end
    function r:GetHighlightTexture() return self.hiliteTex end
    function r:SetScript(name, fn) self.scripts[name] = fn end
    function r:HookScript(name, fn)
        local old = self.scripts[name]
        self.scripts[name] = function(...) if old then old(...) end fn(...) end
    end
    function r:RegisterEvent(e) events[e] = events[e] or {}; events[e][#events[e] + 1] = self end
    function r:CreateTexture() return region("Texture", self) end
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

function SetPortraitToTexture(tex, path) tex.portraitIcon = path end
function GetLocale() return "ruRU" end
function IsAddOnLoaded() return false end

local function fire(event, ...)
    for _, f in ipairs(events[event] or {}) do
        if f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end

-- Build ForeverStockInventory mock (with WindowSkin chrome active)
UIParent = CreateFrame("Frame", "UIParent")
local inv = CreateFrame("Frame", "ForeverStockInventory", UIParent)
inv.w, inv.h, inv.level = 460, 420, 2
inv.backdrop = { bgFile = "WHITE8X8", edgeFile = "BagForever-Edge", edgeSize = 14 }
inv.backdropColor = { 0.108, 0.098, 0.088, 0.97 }

local invHeader = region("Texture", inv); invHeader.texture = "Interface\\AddOns\\ForeverUI\\Art\\BagForever-Header"
local invDivider = region("Texture", inv); invDivider.texture = "Interface\\Buttons\\WHITE8X8"
local invGround = region("Texture", inv); invGround.texture = "Interface\\AddOns\\ForeverUI\\Art\\Forever\\Window-InsetGround"

local wsChrome = CreateFrame("Frame", nil, inv)
wsChrome.level = 12
local wsPiece = region("Texture", wsChrome); wsPiece.texture = "Interface\\AddOns\\ForeverUI\\Art\\Forever\\Window-Metal"

local titleHolder = CreateFrame("Frame", nil, inv); titleHolder.level = 13
local titleText = region("FontString", titleHolder); titleText.text = "Объединённый рюкзак"
_G.ForeverStockInventoryTitleText = titleText

local portraitFrame = CreateFrame("Frame", "ForeverStockInventoryPortraitFrame", inv)

local closeBtn = CreateFrame("Button", "ForeverStockInventoryCloseButton", inv)
closeBtn.level = 14
local closeStock = region("Texture", closeBtn); closeStock.texture = "Interface\\AddOns\\ForeverUI\\Art\\Backpack-Chrome"
local closeWsFace = region("Texture", closeBtn); closeWsFace.texture = "Interface\\AddOns\\ForeverUI\\Art\\Forever\\Window-Close"
closeBtn.points = { { "TOPRIGHT", wsChrome, "TOPRIGHT", -2, 0 } }

local searchBox = CreateFrame("EditBox", "ForeverStockInventorySearchBox", inv)
searchBox.backdrop = { bgFile = "WHITE8X8", edgeFile = "UnitFrame-Edge" }
searchBox.backdropColor = { 0.04, 0.04, 0.04, 0.98 }
searchBox.backdropBorder = { 0.67, 0.77, 0.98, 1 }
local searchMag = region("Texture", searchBox); searchMag.texture = "Interface\\AddOns\\ForeverUI\\Art\\Backpack-Chrome"
local searchHint = region("FontString", searchBox); searchHint.color = { 0.5, 0.5, 0.5, 1 }

local sortBtn = CreateFrame("Button", "ForeverStockInventorySort", inv)
local sortFill = region("Texture", sortBtn); sortFill.texture = "Interface\\AddOns\\ForeverUI\\Art\\Forever\\Bag-Slot"
local sortEdge = region("Texture", sortBtn); sortEdge.texture = "Interface\\AddOns\\ForeverUI\\Art\\Backpack-Chrome"
local sortIcon = region("Texture", sortBtn); sortIcon.texture = "Interface\\Icons\\INV_Misc_Broom"

local tray = CreateFrame("Frame", "ForeverStockInventoryBagTray", inv)
local bagSlot0 = CreateFrame("Button", "ForeverStockInventoryBagSlot0", tray)
bagSlot0.normalTex = region("Texture", bagSlot0)
local trayFill = region("Texture", bagSlot0); trayFill.texture = "Interface\\AddOns\\ForeverUI\\Art\\Forever\\Bag-Slot"

local grid = CreateFrame("Frame", "ForeverStockInventoryGrid", inv)
local bag0 = CreateFrame("Frame", "ForeverStockInventoryBag0", grid)
local bag1 = CreateFrame("Frame", "ForeverStockInventoryBag1", grid)
bag1.separator = region("Texture", bag1); bag1.separator.texture = "Interface\\Buttons\\WHITE8X8"; bag1.separator.h = 1

local function makeSlotBtn(parent, name)
    local b = CreateFrame("Button", name, parent)
    b.normalTex = region("Texture", b)
    b.hiliteTex = region("Texture", b)
    local fill = region("Texture", b); fill.texture = "Interface\\AddOns\\ForeverUI\\Art\\Forever\\Bag-Slot"
    local edge = region("Texture", b); edge.texture = "Interface\\AddOns\\ForeverUI\\Art\\Backpack-Chrome"
    local icon = region("Texture", b); icon.texture = "Interface\\Icons\\INV_Misc_QuestionMark"
    return b, fill, edge, icon
end
local item0_1, fill0_1, edge0_1, icon0_1 = makeSlotBtn(bag0, "ForeverStockInventoryBag0Item1")
local item1_1 = makeSlotBtn(bag1, "ForeverStockInventoryBag1Item1")

local footer = CreateFrame("Frame", "ForeverStockInventoryFooter", inv)
footer.backdrop = { bgFile = "WHITE8X8", edgeFile = "UnitFrame-Edge" }
footer.backdropColor = { 0.09, 0.087, 0.086, 0.98 }

local curToggle = CreateFrame("Button", "ForeverStockInventoryCurrencyToggle", footer)
local curArrow = region("Texture", curToggle); curArrow.texture = "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up"
local curPanel = CreateFrame("Frame", "ForeverStockInventoryCurrencies", inv)
curPanel.backdrop = { bgFile = "WHITE8X8", edgeFile = "UnitFrame-Edge" }
curPanel.backdropColor = { 0.07, 0.068, 0.066, 0.98 }
local curRow = CreateFrame("Frame", nil, curPanel)
curRow.line = region("Texture", curRow); curRow.line.texture = "Interface\\Buttons\\WHITE8X8"

-- Build ForeverStockBank mock WITHOUT WindowSkin (standalone ForeverUI bag frame mode)
local bank = CreateFrame("Frame", "ForeverStockBank", UIParent)
bank.w, bank.h, bank.level = 500, 440, 2
bank.backdrop = { bgFile = "WHITE8X8", edgeFile = "BagForever-Edge", edgeSize = 14 }
local bankHeader = region("Texture", bank); bankHeader.texture = "Interface\\AddOns\\ForeverUI\\Art\\BagForever-Header"
local bankTitle = region("FontString", bank); bankTitle.text = "Банк"
_G.ForeverStockBankTitleText = bankTitle
local bankClose = CreateFrame("Button", "ForeverStockBankCloseButton", bank)
local bankCloseArt = region("Texture", bankClose); bankCloseArt.texture = "Interface\\AddOns\\ForeverUI\\Art\\Backpack-Chrome"
local bankFooter = CreateFrame("Frame", "ForeverStockBankFooter", bank)
bankFooter.backdrop = { bgFile = "WHITE8X8", edgeFile = "UnitFrame-Edge" }
local buySlot = CreateFrame("Button", "ForeverStockBankBuySlot", bankFooter)
local buyBg = region("Texture", buySlot); buyBg.texture = "Interface\\Buttons\\UI-Panel-Button-Up"
local bankGrid = CreateFrame("Frame", "ForeverStockBankGrid", bank)
local bankBag0 = CreateFrame("Frame", "ForeverStockBankBag1", bankGrid)
local bankSlot1 = makeSlotBtn(bankBag0, "ForeverStockBankBag1Item1")

-- Load ForeverUI BagAero module with ForeverUI-style `ui` table
local db = {
    bagsEnabled = true,
    bagsTheme = "forever",
    bagsAeroPreset = "aqua",
    bagsAeroBubbles = true,
    bagsAeroAlpha = 88,
}
local ui = {
    Settings = function() return db end,
}
assert(loadfile("BagAero.lua"))("ForeverUI", ui)
assert(ui.BagAero and ui.BagAero.Apply and ui.BagAero.Restore and ui.BagAero.Presets, "ui.BagAero exported")

-- 1. Default bagsTheme == "forever": zero Aero skinning on login
fire("PLAYER_LOGIN")
assert(not ui.BagAero.Skins[inv] and not ui.BagAero.Skins[bank], "forever theme allocates no Aero skins")
assert(wsChrome.alpha == 1 and inv.backdrop.edgeFile == "BagForever-Edge", "ForeverUI chrome untouched by default")

-- 2. Live switch to Frutiger Aero (`bagsTheme = "aero"`)
db.bagsTheme = "aero"
ui.BagAero.Apply()

local st = ui.BagAero.Skins[inv]
assert(st and st.active, "ForeverStockInventory skinned on live switch")
assert(st.backdropTex.texture == "Interface\\AddOns\\ForeverUI\\Art\\Aero\\Aero-Backdrop",
    "Aero textures load from ForeverUI\\Art\\Aero\\")

-- WindowSkin compatibility & geometry normalization
assert(wsChrome.shown and wsChrome.alpha == 0, "WindowSkin chrome muted without hiding")
assert(closeBtn.points[1][2] == wsChrome, "CloseButton stays anchored to WindowSkin chrome")
assert(invHeader.alpha == 0 and invGround.alpha == 0 and portraitFrame.alpha == 0, "old ForeverUI chrome muted")
assert(inv.backdrop == nil, "window dark backdrop cleared")

assert(st.bgFrame.points[1][5] == 17, "Aero backdrop normalized above WindowSkin header")
assert(st.headerTex.h == 34, "Aero header height 34 with WindowSkin")
assert(st.orb.points[1][5] == -21, "Crystal orb centered at -21 with WindowSkin")
assert(st.closeHolder.points[1][5] == -2, "Close holder centered at -2 with WindowSkin")
assert(st.bgFrame.level < inv.level and st.rimFrame.level == wsChrome.level, "correct frame layering")
assert(st.orb.shown and st.orbIcon.portraitIcon == "Interface\\Buttons\\Button-Backpack-Up", "crystal orb backpack icon")
assert(st.bubblesTex.shown, "bubbles shown by default")

-- Slots, toolbar, search, close button, separators, footer, currency drawer
assert(fill0_1.alpha == 0 and edge0_1.alpha == 0 and icon0_1.alpha == 1, "item slot brown art hidden, icon kept")
assert(st.slotArts[item0_1] and st.slotArts[item0_1].well.shown and st.slotArts[item0_1].rim.shown, "Aero glass slot")
assert(st.slotArts[item1_1] and st.slotArts[bagSlot0] and st.slotArts[sortBtn], "tray & toolbar buttons skinned")
assert(sortIcon.alpha == 1, "toolbar button icon preserved")
assert(bag1.separator.texture:find("Aero%-Divider") and bag1.separator.h == 6, "separator replaced with Aero light beam")
assert(searchBox.backdrop == nil and st.searchPill.slices.mid.shown, "search pill applied")
assert(searchHint.color[1] > 0.7 and searchHint.color[3] > 0.9, "search hint legible light ice-blue")
searchBox.scripts.OnEditFocusGained(searchBox)
assert(st.searchPill.slices.mid.vertex[1] == 1, "search pill highlights on focus")
searchBox.scripts.OnEditFocusLost(searchBox)
assert(math.abs(st.searchPill.slices.mid.vertex[1] - 0.88) < 0.01, "search pill restores preset tint on blur")
assert(footer.backdrop == nil and st.footerPill.slices.mid.shown, "footer pill applied")
assert(curPanel.backdrop == nil and st.currencyBg.shown, "currency drawer Aero glass applied")
assert(curRow.line.vertex[4] == 0.30, "currency divider tinted")

-- Close button immunity to WindowSkin region fade + interactive states
assert(closeWsFace.alpha == 0 and closeStock.alpha == 0 and st.closeHolder.parent == closeBtn
    and st.closeHolder.shown and st.closeFace.shown and st.closeFace.alpha == 1, "Aero ruby close button active")
for _, reg in ipairs({ closeBtn:GetRegions() }) do
    if reg.kind == "Texture" then reg:SetAlpha(0) end
end
assert(st.closeFace.alpha == 1 and st.closeHolder.alpha == 1 and st.closeHolder.shown,
    "WindowSkin region fade does not hide Aero close button")
closeBtn.scripts.OnEnter(closeBtn)
assert(math.abs(st.closeFace.coords[1] - 0.25) < 0.001 and st.closeGlow.shown, "close hover cell and glow")
closeBtn.scripts.OnMouseDown(closeBtn)
assert(math.abs(st.closeFace.coords[1] - 0.50) < 0.001, "close pressed cell")
closeBtn.mouseOver = true
closeBtn.scripts.OnMouseUp(closeBtn)
assert(math.abs(st.closeFace.coords[1] - 0.25) < 0.001, "close returns to hover when pointer still over")
closeBtn.mouseOver = false
closeBtn.scripts.OnLeave(closeBtn)
assert(math.abs(st.closeFace.coords[1] - 0) < 0.001 and not st.closeGlow.shown, "close normal cell restored")

-- Bank window WITHOUT WindowSkin
local bst = ui.BagAero.Skins[bank]
assert(bst and bst.active and bst.topRaise == 0 and bst.bgFrame.points[1][5] == 2,
    "bank skinned cleanly without WindowSkin")
assert(bst.headerTex.h == 32 and bst.orb.points[1][5] == -19 and bst.closeHolder.points[1][5] == 0,
    "standalone header normalization")
assert(bst.bgFrame.level < bank.level, "bank native TitleText remains above Aero backdrop")
assert(buyBg.alpha == 0 and bst.buyPill.slices.mid.shown, "bank BuySlot capsule applied")
assert(bst.slotArts[bankSlot1] and bst.slotArts[bankSlot1].well.shown, "bank item slot skinned")

-- 3. Dynamic WindowSkin toggle (chrome OnHide / OnShow) updates geometry automatically
wsChrome:Hide()
assert(st.topRaise == 0 and st.bgFrame.points[1][5] == 2 and st.orb.points[1][5] == -19,
    "hiding WindowSkin chrome lowers Aero header edge to +2")
wsChrome:Show()
assert(st.topRaise == 12 and st.wsChrome.alpha == 0 and st.bgFrame.points[1][5] == 17,
    "showing WindowSkin chrome mutes it and raises Aero header to +17")

-- 4. Lazy item slot creation on BAG_UPDATE
local lazySlot = makeSlotBtn(bag0, "ForeverStockInventoryBag0Item2")
fire("BAG_UPDATE")
assert(st.slotArts[lazySlot] and st.slotArts[lazySlot].well.shown, "newly created slot skinned on BAG_UPDATE")

-- 5. All presets, bubbles toggle, alpha clamping
db.bagsAeroPreset = "emerald"
ui.BagAero.Apply()
assert(st.headerDiv.vertex[2] > 0.9 and st.headerDiv.vertex[1] < 0.6, "emerald divider tint applied")

db.bagsAeroPreset = "frost"
ui.BagAero.Apply()
assert(st.outerRim.slices.tl.vertex[3] == 1.0 and st.headerDiv.vertex[1] > 0.65, "frost preset applied")

db.bagsAeroPreset = "midnight"
ui.BagAero.Apply()
assert(st.backdropTex.vertex[1] < 0.65, "midnight preset applied")

db.bagsAeroBubbles = false
ui.BagAero.Apply()
assert(not st.bubblesTex.shown, "bubbles toggled off")
db.bagsAeroBubbles = true
ui.BagAero.Apply()
assert(st.bubblesTex.shown, "bubbles toggled back on")

db.bagsAeroAlpha = 30
ui.BagAero.Apply()
assert(math.abs(st.backdropTex.vertex[4] - 0.50) < 0.001, "alpha clamped to minimum 50%")
db.bagsAeroAlpha = 150
ui.BagAero.Apply()
assert(math.abs(st.backdropTex.vertex[4] - 1.00) < 0.001, "alpha clamped to maximum 100%")
db.bagsAeroAlpha = 72
ui.BagAero.Apply()
assert(math.abs(st.backdropTex.vertex[4] - 0.72) < 0.001, "alpha updated to 72%")

-- 6. Live switch back to WoW: Forever (`bagsTheme = "forever"`) restores everything cleanly
db.bagsTheme = "forever"
ui.BagAero.Apply()
assert(not st.active and not st.bgFrame.shown and not st.rimFrame.shown and not st.closeHolder.shown,
    "Aero chrome hidden when switched to forever")
assert(not bst.active and not bst.bgFrame.shown and not bst.closeHolder.shown, "bank Aero chrome hidden")
assert(wsChrome.alpha == 1 and invHeader.alpha == 1 and portraitFrame.alpha == 1, "WindowSkin & ForeverUI restored")
assert(inv.backdrop and inv.backdrop.edgeFile == "BagForever-Edge", "window backdrop restored")
assert(searchHint.color[1] == 0.5, "search hint original color restored")
assert(fill0_1.alpha == 1 and edge0_1.alpha == 1 and not st.slotArts[item0_1].well.shown, "item slot restored")
assert(bag1.separator.texture == "Interface\\Buttons\\WHITE8X8" and bag1.separator.h == 1, "separator restored")
assert(closeWsFace.alpha == 1 and not st.closeFace.shown, "close button restored")
assert(curRow.line.vertex[2] == 0.39, "currency row divider restored")

-- 7. Roundtrip re-enable
db.bagsTheme = "aero"
ui.BagAero.Apply()
assert(st.active and st.bgFrame.shown and st.slotArts[item0_1].well.shown, "Aero re-enabled cleanly")

print("BagAero tests passed")
