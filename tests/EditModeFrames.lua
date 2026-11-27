-- Mock harness for EditMode.lua: buff/debuff grids (icons per row, rows) and the "Show" switch
-- of the right-click popup. Run from the addon root.
local noop = function() end
local Region = {}
Region.__index = function(_, k)
    local v = rawget(Region, k)
    if v ~= nil then return v end
    if type(k) == "string" and k:match("^%u") then return noop end
end
local eventFrames = {}
local function new(kind, name, parent)
    local o = setmetatable({ kind = kind, name = name, parent = parent, children = {}, scripts = {},
        w = 30, h = 30, scale = 1, shown = true, points = {}, level = 1 }, Region)
    if parent and parent.children then table.insert(parent.children, o) end
    if name then _G[name] = o end
    return o
end
function Region:SetSize(w, h) self.w, self.h = w, h end
function Region:GetWidth() return self.w end
function Region:GetHeight() return self.h end
function Region:SetPoint(...) self.points[#self.points + 1] = { ... } end
function Region:ClearAllPoints() self.points = {} end
function Region:GetPoint(i) local p = self.points[i or 1]; if p then return unpack(p) end end
function Region:GetNumPoints() return #self.points end
function Region:GetLeft() return 100 end
function Region:GetBottom() return 100 end
function Region:GetRight() return 1024 end
function Region:GetTop() return 768 end
function Region:GetCenter() return 100, 100 end
function Region:SetScale(s) self.scale = s end
function Region:GetScale() return self.scale end
function Region:GetEffectiveScale() return 1 end
function Region:GetParent() return self.parent end
function Region:SetParent(p) self.parent = p end
function Region:GetName() return self.name end
function Region:GetFrameLevel() return self.level end
function Region:SetFrameLevel(l) self.level = l end
function Region:IsProtected() return false end
function Region:Show()
    if not self.shown then self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
end
function Region:Hide()
    if self.shown then self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
end
function Region:IsShown() return self.shown end
function Region:IsVisible()
    local o = self
    while o do if not o.shown then return false end o = o.parent end
    return true
end
function Region:SetScript(s, f) self.scripts[s] = f end
function Region:HookScript(s, f)
    local old = self.scripts[s]
    self.scripts[s] = old and function(...) old(...); f(...) end or f
end
function Region:CreateTexture(name) return new("Texture", name, self) end
function Region:CreateFontString(name) return new("FontString", name, self) end
function Region:SetText(t) self.text = t end
function Region:GetText() return self.text end
function Region:SetChecked(c) self.checked = c and true or false end
function Region:GetChecked() return self.checked end
function Region:SetMinMaxValues(a, b) self.min, self.max = a, b end
function Region:GetMinMaxValues() return self.min, self.max end
function Region:SetValue(v)
    v = math.max(self.min or v, math.min(self.max or v, v))
    if self.value ~= v then
        self.value = v
        if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end
    end
end
function Region:GetValue() return self.value or 0 end
function Region:RegisterEvent() eventFrames[self] = true end

function CreateFrame(kind, name, parent, template)
    local frame = new(kind, name, parent)
    if name and template == "OptionsSliderTemplate" then
        for _, suffix in ipairs({ "Low", "High", "Text" }) do new("FontString", name .. suffix, frame) end
    elseif name and template == "InterfaceOptionsCheckButtonTemplate" then
        new("FontString", name .. "Text", frame)
    end
    return frame
end

local hooks = {}
function hooksecurefunc(target, name, fn)
    if type(target) == "table" then
        local old = target[name]
        target[name] = function(...) local a, b, c = old(...); fn(...); return a, b, c end
        return
    end
    name, fn = target, name
    local old = _G[name]
    _G[name] = function(...) local a, b, c = old(...); fn(...); return a, b, c end
end
UIParent = new("Frame", "UIParent")
GameMenuFrame = new("Frame", "GameMenuFrame", UIParent)
GameMenuFrame_AddButton = noop
UISpecialFrames = {}
tinsert = table.insert
InCombatLockdown = function() return false end
SlashCmdList = {}
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
debugstack = function() return "Interface\\FrameXML\\UIParent.lua:100: in function `UIParent_ManageFramePositions'\n" end
PlaySound, HideUIPanel = noop, noop
BUFF_MAX_DISPLAY, DEBUFF_MAX_DISPLAY, BUFFS_PER_ROW = 32, 16, 8

-- Stock aura frames: buffs and debuffs both live under BuffFrame.
new("Frame", "PlayerFrame", UIParent)
new("Frame", "TargetFrameToT", UIParent)
new("Frame", "BuffFrame", UIParent)
new("Frame", "ConsolidatedBuffs", UIParent)
new("Frame", "TemporaryEnchantFrame", UIParent)
for i = 1, 32 do local b = new("Button", "BuffButton" .. i, BuffFrame); b.shown = i <= 12 end
for i = 1, 16 do local b = new("Button", "DebuffButton" .. i, BuffFrame); b.shown = i <= 5 end
-- Pet bar (10 buttons, stock chain 8 px) and totem bar (summon, 4 slots, recall).
new("Frame", "PetActionBarFrame", UIParent)
for i = 1, 10 do
    local b = new("CheckButton", "PetActionButton" .. i, PetActionBarFrame)
    b.w, b.h = 30, 30
    b:SetPoint("LEFT", i == 1 and PetActionBarFrame or _G["PetActionButton" .. (i - 1)], i == 1 and "LEFT" or "RIGHT",
        i == 1 and 36 or 8, 0)
end
new("Frame", "MultiCastActionBarFrame", UIParent)
new("Button", "MultiCastSummonSpellButton", MultiCastActionBarFrame)
new("Button", "MultiCastRecallSpellButton", MultiCastActionBarFrame)
for i = 1, 4 do
    local b = new("Button", "MultiCastSlotButton" .. i, MultiCastActionBarFrame)
    b:SetPoint("LEFT", i == 1 and MultiCastSummonSpellButton or _G["MultiCastSlotButton" .. (i - 1)], "RIGHT", 6, 0)
end
function BuffFrame_UpdateAllBuffAnchors()
    for i = 1, 32 do
        local b = _G["BuffButton" .. i]
        b:ClearAllPoints()
        b:SetPoint("STOCK")
    end
end
function DebuffButton_UpdateAnchors(_, index)
    local b = _G["DebuffButton" .. index]
    b:ClearAllPoints()
    b:SetPoint("STOCK")
end

local settings = {}
local ui = { russian = true, Settings = function() return settings end }
function ui.Checkbox(parent) return new("CheckButton", nil, parent) end
ui.Slider = ui.Checkbox
-- Gryphon holders (StockPanels.lua creates them before EditMode.lua loads).
ui.GryphonHolders = { "ForeverStockUILeftGryphon", "ForeverStockUIRightGryphon" }
for _, name in ipairs(ui.GryphonHolders) do new("Frame", name, UIParent) end
assert(loadfile("EditLayouts.lua"))("ForeverUI", ui)
-- The client's managed frame table (UIParent_ManageFramePositions) and an unprotected frame it moves itself.
new("Frame", "WatchFrame", UIParent)
UIPARENT_MANAGED_FRAME_POSITIONS = { PlayerFrame = { baseY = 0 }, PETACTIONBAR_YPOS = { baseY = 0 } }
assert(loadfile("EditMode.lua"))("ForeverUI", ui)
for frame in pairs(eventFrames) do
    if frame.scripts.OnEvent then frame.scripts.OnEvent(frame, "PLAYER_LOGIN") end
end

local buffs, debuffs = settings.editLayout.ConsolidatedBuffs, settings.editLayout.DebuffButton1
assert(buffs and debuffs, "aura entries registered")

-- Buffs: 4 per row, 2 rows; icons 9-12 are parked, icon 6 sits in the second row.
buffs.columns, buffs.rows = 4, 2
BuffFrame_UpdateAllBuffAnchors()
local hider = BuffButton9:GetParent()
assert(hider ~= BuffFrame and not hider:IsShown(), "icons past the last row are parked")
assert(BuffButton8:GetParent() == BuffFrame, "icons inside the grid stay")
local point, relative, relPoint, x, y = BuffButton6:GetPoint(1)
assert(point == "TOPRIGHT" and relative == BuffButton1 and x == -35 and y == -45, "second row, second column")
assert(BuffButton1:GetPoint(1) == "STOCK", "the first icon keeps the stock anchor")

-- All rows again: the parked icons come back.
buffs.rows = nil
BuffFrame_UpdateAllBuffAnchors()
assert(BuffButton9:GetParent() == BuffFrame, "row limit lifted")
assert(BuffButton12:GetParent() == BuffFrame)

-- Debuffs keep their own grid.
debuffs.columns = 2
DebuffButton_UpdateAnchors("DebuffButton", 1)
point, relative, relPoint, x, y = DebuffButton3:GetPoint(1)
assert(relative == DebuffButton1 and x == 0 and y == -45, "debuff grid")

-- Buffs switched off: buffs, consolidated buffs and weapon enchants go, debuffs stay.
buffs.hidden = true
BuffFrame_UpdateAllBuffAnchors()
assert(BuffButton1:GetParent() == hider and ConsolidatedBuffs:GetParent() == hider
    and TemporaryEnchantFrame:GetParent() == hider, "buffs hidden")
assert(BuffFrame:GetParent() == UIParent and DebuffButton1:GetParent() == BuffFrame, "debuffs untouched")
buffs.hidden = nil
BuffFrame_UpdateAllBuffAnchors()
assert(BuffButton1:GetParent() == BuffFrame and ConsolidatedBuffs:GetParent() == UIParent, "buffs back")

-- The popup: overlays are opened with a right click.
ForeverStockUIEditMode:Show()
local function overlayFor(label)
    for _, child in ipairs(ForeverStockUIEditMode.children) do
        if child.label and child.label.text and child.label.text:find(label, 1, true) == 1 then return child end
    end
end
local shownBox = ForeverStockUIEditShown
overlayFor("Игрок").scripts.OnClick(overlayFor("Игрок"))
assert(shownBox:IsShown() and shownBox:GetChecked(), "Show switch offered and on")
shownBox:SetChecked(false)
shownBox.scripts.OnClick(shownBox)
assert(PlayerFrame:GetParent() == hider and settings.editLayout.PlayerFrame.hidden == true, "player frame off")
assert(overlayFor("Игрок").label.text:find("скрыт"), "overlay marks the hidden frame")
shownBox:SetChecked(true)
shownBox.scripts.OnClick(shownBox)
assert(PlayerFrame:GetParent() == UIParent and settings.editLayout.PlayerFrame.hidden == nil, "player frame on")

overlayFor("Цель цели").scripts.OnClick(overlayFor("Цель цели"))
assert(not shownBox:IsShown(), "target of target cannot be parked")

-- Buff popup sliders: per row and rows.
overlayFor("Бафы").scripts.OnClick(overlayFor("Бафы"))
assert(ForeverStockUIEditCount:IsShown() and ForeverStockUIEditCountText.text:find("В ряду"), "per-row slider")
ForeverStockUIEditCount:SetValue(6)
assert(buffs.columns == 6 and buffs.rows == nil, "per row set, all rows kept")
ForeverStockUIEditRows:SetValue(2)
assert(buffs.rows == 2, "rows set")
assert(BuffButton12:GetParent() == BuffFrame and BuffButton13:GetParent() == BuffFrame, "12 icons fit 6x2")

-- Pet bar grid: up to 10 cells, 5 x 2, the rest parked; the slider stops at 10.
overlayFor("Панель питомца").scripts.OnClick(overlayFor("Панель питомца"))
local count, rowsS = ForeverStockUIEditCount, ForeverStockUIEditRows
assert(count:IsShown() and ForeverStockUIEditCountText.text:find("Ячеек"), "pet bar has the cell slider")
assert(select(2, count:GetMinMaxValues()) == 10, "pet bar: 10 cells at most")
assert(settings.editLayout.PetActionBarFrame.count == nil, "pet stock layout untouched when opened")
count:SetValue(10)
rowsS:SetValue(2)
local pet = settings.editLayout.PetActionBarFrame
assert(pet.count == 10 and pet.rows == 2, "pet grid stored")
point, relative, relPoint, x, y = PetActionButton7:GetPoint(1)
assert(point == "BOTTOMLEFT" and relative == PetActionButton1 and x == 38 and y == 38, "pet cell 7: row 2, column 2")
assert(PetActionButton1:GetPoint(1) == "LEFT" and select(2, PetActionButton1:GetPoint(1)) == PetActionBarFrame,
    "first pet button keeps its stock anchor")
count:SetValue(8)
point, relative = PetActionButton9:GetPoint(1)
assert(point == "RIGHT" and relative == UIParent, "pet cells past the count are parked")

-- Totem bar: the four slots, max 4; summon and recall belong to the outline.
overlayFor("Панель тотемов").scripts.OnClick(overlayFor("Панель тотемов"))
assert(count:IsShown() and select(2, count:GetMinMaxValues()) == 4, "totem bar: 4 slots at most")
count:SetValue(4)
rowsS:SetValue(2)
point, relative, relPoint, x, y = MultiCastSlotButton4:GetPoint(1)
assert(point == "BOTTOMLEFT" and relative == MultiCastSlotButton1 and x == 36 and y == 36, "totem slot 4: 2 x 2")
assert(select(2, MultiCastSlotButton1:GetPoint(1)) == MultiCastSummonSpellButton, "slot 1 stays by the summon button")

-- Retail layout: the Retail look is applied before the frames are measured (the micro menu shrinks).
local lookAt
ui.ActionBars = { Apply = function() lookAt = lookAt or settings.barLayout end }
assert(ui.ApplyEditLayout("retail"), "Retail layout started")
assert(settings.barLayout == "retail" and lookAt == "retail", "Retail look applied before measuring")

-- Gryphons: own overlays, one saved spot per layout.
assert(overlayFor("Левый грифон") and overlayFor("Правый грифон"), "each gryphon has its own overlay")
local leftSpot = settings.editLayout.ForeverStockUILeftGryphon
leftSpot.position = { -800, -600 } -- dragged in Retail before per-layout spots existed
ui.ApplyEditLayout("classic")
assert(leftSpot.position == nil, "Classic has no saved spot: default place")
assert(leftSpot.positions.retail[1] == -800 and leftSpot.positions.retail[2] == -600, "Retail spot kept")
leftSpot.position, leftSpot.positions.classic = { -100, -900 }, { -100, -900 }
ui.ApplyEditLayout("retail")
assert(leftSpot.position[1] == -800 and leftSpot.position[2] == -600, "Retail spot back")
ui.ApplyEditLayout("classic")
assert(leftSpot.position[1] == -100, "Classic spot back")

-- Setup wizard API: a spot by point, a layout loaded in place, the stock spot back for frames without a position.
local function runUpdates()
    for _ = 1, 2 do
        for frame in pairs(eventFrames) do
            local update = frame.scripts.OnUpdate
            if update then update(frame, 0.02) end
        end
    end
end
UIParent.w, UIParent.h = 1024, 768
local EM = ui.EditMode
local playerConfig = settings.editLayout.PlayerFrame
PlayerFrame.points = { { "TOPLEFT", UIParent, "TOPLEFT", -19, -4 } }
assert(EM.Place("PlayerFrame", "RIGHT", "CENTER", -170, -120), "player placed")
-- 30 x 30 frame, its right edge 170 left of the centre, its middle 120 under it: TOPRIGHT offset -682, -489.
assert(playerConfig.position[1] == -682 and playerConfig.position[2] == -489, "spot in Edit Mode format")
local px, py = ui.ComputeEditPosition("TOPLEFT", "TOPLEFT", 20, -200, 220, 160, 1024, 768)
assert(px == 20 + 220 - 1024 and py == -200, "top-left spot")
px, py = ui.ComputeEditPosition("BOTTOMRIGHT", "BOTTOMRIGHT", -8, 108, 300, 120, 1024, 768)
assert(px == -8 and py == 108 + 120 - 768, "bottom-right spot")
runUpdates()
assert(PlayerFrame:GetPoint(1) == "TOPRIGHT", "frame moved to the spot")

local leftGryphon = settings.editLayout.ForeverStockUILeftGryphon
EM.LoadLayout({ PlayerFrame = { position = { -500, -300 }, scale = 1.2 }, SomeTracker = { position = { 1, 2 } } },
    function(name) return name == "ForeverStockUILeftGryphon" end)
assert(settings.editLayout.PlayerFrame == playerConfig, "layout loaded in place: modules keep their table")
assert(playerConfig.position[1] == -500 and playerConfig.scale == 1.2, "saved values copied")
assert(settings.editLayout.SomeTracker.position[2] == 2, "new frames added")
assert(settings.editLayout.ForeverStockUILeftGryphon == leftGryphon and leftGryphon.positions, "skipped entry untouched")
assert(next(settings.editLayout.PetActionBarFrame) == nil, "frames missing from the layout lose their settings")
runUpdates()
assert(PlayerFrame.scale == 1.2, "scale applied")
-- The client re-anchors a unit frame after login: the saved spot wins on the next pass.
PlayerFrame:ClearAllPoints()
PlayerFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -19, -4)
runUpdates()
assert(PlayerFrame:GetPoint(1) == "TOPRIGHT" and select(4, PlayerFrame:GetPoint(1)) == -500, "saved spot back after the client moved it")
EM.LoadLayout({})
assert(playerConfig.position == nil, "no position")
assert(PlayerFrame:GetPoint(1) == "TOPLEFT" and select(4, PlayerFrame:GetPoint(1)) == -19, "stock spot back")
assert(PlayerFrame.scale == 1, "stock scale back")
assert(EM.SetBarStyle("retail") and settings.barLayout == "retail", "bar look without moving bars")
EM.SetBarStyle("classic")

-- A frame placed by Edit Mode leaves the client's managed table; other keys stay.
assert(UIPARENT_MANAGED_FRAME_POSITIONS.PlayerFrame == nil, "placed frame out of the client layout")
assert(UIPARENT_MANAGED_FRAME_POSITIONS.PETACTIONBAR_YPOS, "other managed keys kept")
-- The quest tracker moved by the client in combat goes back to its spot at once.
local watchConfig = settings.editLayout.WatchFrame
watchConfig.position = { -50, -300 }
runUpdates()
InCombatLockdown = function() return true end
WatchFrame:ClearAllPoints()
WatchFrame:SetPoint("TOPRIGHT", MinimapCluster, "BOTTOMRIGHT", 0, -14)
local wp, wrel, _, wx, wy = WatchFrame:GetPoint(1)
assert(wp == "TOPRIGHT" and wrel == UIParent and wx == -50 and wy == -300 and WatchFrame:GetNumPoints() == 1,
    "tracker pinned back in combat")
InCombatLockdown = function() return false end

-- /fuimoves: frames the client moves in combat, by caller, and their shift from the start of combat.
local function fireAll(event)
    for frame in pairs(eventFrames) do
        if frame.scripts and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event) end
    end
end
InCombatLockdown = function() return true end
fireAll("PLAYER_REGEN_DISABLED")
PlayerFrame.GetBottom = function() return 112 end
PlayerFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 12)
InCombatLockdown = function() return false end
fireAll("PLAYER_REGEN_ENABLED")
PlayerFrame.GetBottom = nil
PlayerFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0) -- out of combat: not counted
local lines, realPrint = {}, print
print = function(...) lines[#lines + 1] = table.concat({ ... }, " ") end
SlashCmdList.FOREVERUIMOVES("")
print = realPrint
local report = table.concat(lines, "\n")
assert(report:find("PlayerFrame %+0%.0 %+12%.0"), "shift over the combat: " .. report)
assert(report:find("1x PlayerFrame | UIParent%.lua:100 `UIParent_ManageFramePositions'"), "caller counted once: " .. report)

print("EditModeFrames OK: Retail look before measuring, pet and totem grids, buff and debuff grids, row limit, hiding auras, Show switch, popup sliders, setup API (place, load in place, stock spots back)")
