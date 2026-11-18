-- Run from the addon directory (see INDEX.md): red icons of items the character cannot use.
-- Real ItemUsability.lua, Merchant.lua and Loot.lua on mocks: the tooltip verdict
-- (red requirement lines, level, broken item, data still loading, cache reset), U.Paint (only its own
-- red is taken back), the merchant page after the stock update (stock verdict kept, missing verdicts
-- added, page change, buyback tab, late item data), loot rows
-- and the loot flyout.

local frames, failures = {}, 0
local function check(ok, label)
    if not ok then
        failures = failures + 1
        print("FAIL: " .. label)
    end
end
local function near(a, b) return math.abs(a - b) < 0.01 end
local function isRed(texture)
    local r, g, b = texture:GetVertexColor()
    return r > 0.3 and near(g, 0) and near(b, 0)
end
local function isWhite(texture)
    local r, g, b = texture:GetVertexColor()
    return near(r, 1) and near(g, 1) and near(b, 1)
end

local methods = {}
local function new(kind, parent, name)
    local object = setmetatable({ kind = kind, shown = true, scripts = {}, children = {}, regions = {},
        color = { 1, 1, 1, 1 }, name = name, events = {} }, { __index = function(_, key)
        if methods[key] then return methods[key] end
        if type(key) == "string" and key:match("^%u") and not key:match("^Retail") and key ~= "Icon" then
            return function() end
        end
    end })
    if parent then
        object.parent = parent
        table.insert((kind == "Texture" or kind == "FontString") and parent.regions or parent.children, object)
    end
    if name then _G[name] = object end
    frames[#frames + 1] = object
    return object
end
function methods:GetName() return self.name end
function methods:GetParent() return self.parent end
function methods:GetObjectType() return self.kind end
function methods:IsObjectType(kind) return self.kind == kind end
function methods:GetChildren() return unpack(self.children) end
function methods:GetRegions() return unpack(self.regions) end
function methods:Show() local was = self.shown self.shown = true if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() self.shown = false end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown end
function methods:SetScript(name, fn) self.scripts[name] = fn end
function methods:GetScript(name) return self.scripts[name] end
function methods:HookScript(name, fn)
    local old = self.scripts[name]
    self.scripts[name] = function(...) if old then old(...) end fn(...) end
end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:UnregisterEvent(event) self.events[event] = nil end
function methods:CreateTexture(name) return new("Texture", self, name) end
function methods:CreateFontString(name) return new("FontString", self, name) end
function methods:SetVertexColor(r, g, b, a) self.color = { r, g, b, a or 1 } end
function methods:GetVertexColor() return unpack(self.color) end
function methods:SetTexture(texture) self.texture = texture end
function methods:GetTexture() return self.texture end
function methods:SetText(text) self.text = text end
function methods:GetText() return self.text end
function methods:SetTextColor(r, g, b) self.textColor = { r, g, b } end
function methods:GetTextColor() return unpack(self.textColor or { 1, 1, 1 }) end
function methods:GetNormalTexture() return self.normal end
function methods:GetWidth() return 40 end
function methods:GetHeight() return 40 end
function methods:GetDrawLayer() return "ARTWORK" end
function methods:GetLeft() return 100 end
function methods:GetRight() return 50 end
function methods:GetFrameLevel() return 1 end
function methods:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function methods:GetTop() return 400 end
function methods:GetEffectiveScale() return 1 end
function methods:GetAlpha() return 1 end

-- Item data and tooltips: lines are { left, r, g, b, right, rr, rg, rb }.
local RED, WHITE = { 1, 0.125, 0.125 }, { 1, 1, 1 }
local items, tips = {}, {}
local function item(link, minLevel, lines)
    items[link] = { minLevel = minLevel }
    tips[link] = lines
end
local function line(text, color, right, rightColor)
    return { text, color or WHITE, right, rightColor or WHITE }
end
item("mailBelt", 10, { line("Mail belt"), line("Пояс", WHITE, "Кольчуга", RED), line("Броня: 120") })
item("trinket", 10, { line("Trinket"), line("Аксессуар"), line("Использование: ...") })
item("staff", 10, { line("Staff"), line("Двуручное", WHITE, "Древковое", RED) })  -- subtype "Древковое оружие"
item("highLevel", 40, { line("Sword"), line("Требуется уровень 40", RED) })
item("broken", 10, { line("Helm"), line("Прочность 0 / 50", RED) })
item("recipe", 10, { line("Recipe"), line("Требуется Портняжное дело (300)", RED) })
DURABILITY_TEMPLATE = "Прочность %d / %d"
-- Client requirement strings (ruRU) the check builds its patterns from.
ITEM_MIN_LEVEL, ITEM_MIN_SKILL, ITEM_REQ_SKILL = "Требуется уровень %d", "Требуется %s (%d)", "Требуется %s"
ITEM_CLASSES_ALLOWED, ITEM_SPELL_KNOWN = "Классы: %s", "Уже изучено"
-- Another addon writes a red line into every tooltip (Auctionator prices): no requirement, the item stays usable.
item("reagent", 10, { line("Ткань"), line("Хозяйственные товары"), line("Аукцион: нет данных", RED) })
item("knownRecipe", 10, { line("Рецепт"), line("Уже изучено", RED) })
item("classLocked", 10, { line("Tier helm"), line("Классы: Воин", RED) })
item("lowRed", 10, { line("Ring"), line("a"), line("b"), line("c"), line("d"), line("e"), line("f", WHITE, "Цена", RED) })

function GetItemInfo(link)
    local info = items[link]
    if not info or info.loading then return nil end
    return link, link, 2, 50, info.minLevel
end
function UnitLevel() return 30 end

function CreateFrame(kind, name, parent, template)
    local frame = new(kind, parent, name)
    if template == "LootButtonTemplate" then
        frame:CreateTexture(name .. "IconTexture")
        frame:CreateTexture(name .. "NameFrame")
        frame:CreateFontString(name .. "Text")
        frame:CreateFontString(name .. "Count")
    end
    if kind == "GameTooltip" then
        for i = 1, 8 do
            new("FontString", frame, name .. "TextLeft" .. i)
            new("FontString", frame, name .. "TextRight" .. i)
        end
        function frame:SetOwner() end
        function frame:ClearLines()
            self.count = 0
            for i = 1, 8 do
                _G[name .. "TextLeft" .. i]:SetText(nil)
                _G[name .. "TextRight" .. i]:SetText(nil)
            end
        end
        function frame:SetHyperlink(link)
            local info = items[link]
            local lines = tips[link] or {}
            if info and info.loading then lines = { lines[1] } end
            self.count = #lines
            for i, l in ipairs(lines) do
                local left, right = _G[name .. "TextLeft" .. i], _G[name .. "TextRight" .. i]
                left:SetText(l[1]); left:SetTextColor(unpack(l[2]))
                right:SetText(l[3]); right:SetTextColor(unpack(l[4]))
            end
        end
        function frame:NumLines() return self.count or 0 end
    end
    return frame
end
function hooksecurefunc(name, fn)
    local old = _G[name]
    _G[name] = function(...) local r = { old(...) } fn(...) return unpack(r) end
end
local function fire(event, ...)
    for _, frame in ipairs(frames) do
        if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
    end
end
local function tick(seconds)
    local step = 0.1
    for _ = 1, math.floor(seconds / step + 0.5) do
        for _, frame in ipairs(frames) do
            if frame.shown and frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, step) end
        end
    end
end

UIParent = new("Frame", nil, "UIParent")
WorldFrame = new("Frame")
SlashCmdList, ITEM_QUALITY_COLORS = {}, { [2] = { r = 0, g = 1, b = 0 } }
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
function GetMouseFocus() return nil end
function IsAddOnLoaded() return false end
function InRepairMode() return false end
function GetCursorInfo() return nil end
function GetTime() return 100 end

local settings = { characterSkin = true }
local ui = { Settings = function() return settings end, russian = true, ApplySlotEdge = function() end }
local function load(path) assert(loadfile(path))("ForeverUI", ui) end

-- 1. The tooltip verdict -------------------------------------------------------------------------------
load("ItemUsability.lua")
local U = ui.ItemUsability
check(U.CannotUse("mailBelt") == true, "armour type in red: cannot use")
check(U.CannotUse("trinket") == false, "no red line: usable")
check(U.CannotUse("staff") == true, "weapon type whose tooltip text differs from the subtype: cannot use")
check(U.CannotUse("highLevel") == true, "required level above the character: cannot use")
check(U.CannotUse("broken") == false, "red durability of a broken item is no requirement")
check(U.CannotUse("recipe") == true, "red skill requirement: cannot use")
check(U.CannotUse(nil) == false, "no link: nothing to paint")
check(U.CannotUse("reagent") == false, "a red line of another addon is no requirement")
check(U.CannotUse("knownRecipe") == true, "already known: cannot use")
check(U.CannotUse("classLocked") == true, "class requirement: cannot use")
check(U.CannotUse("lowRed") == false, "a red right text far below the slot line is no armour type")
item("late", 10, { line("Late belt"), line("Пояс", WHITE, "Кожа", RED) })
items.late.loading = true
check(U.CannotUse("late") == nil, "item data not there yet: no verdict (and none cached)")
items.late.loading = nil
check(U.CannotUse("late") == true, "verdict once the data arrives")
local changed = 0
U.OnChange(function() changed = changed + 1 end)
tips.mailBelt = { line("Mail belt"), line("Пояс", WHITE, "Кольчуга", WHITE) }   -- learned mail
check(U.CannotUse("mailBelt") == true, "verdict cached per link")
fire("SKILL_LINES_CHANGED")
check(changed == 1, "a change of the character tells the windows")
fire("PLAYER_ENTERING_WORLD")
check(changed == 1, "a loading screen does not recheck at once (tooltips still empty)")
tick(2.1)
check(changed == 2, "every window is checked again 2 s after a loading screen")
changed = 1
check(U.CannotUse("mailBelt") == false, "cache dropped when the character changes")
tips.mailBelt = { line("Mail belt"), line("Пояс", WHITE, "Кольчуга", RED) }
fire("PLAYER_LEVEL_UP")

-- 2. U.Paint --------------------------------------------------------------------------------------------
local tex = new("Texture")
tex:SetVertexColor(0.6, 0.6, 0.6)
U.Paint(tex, true)
check(isRed(tex) and U.IsPainted(tex), "paint: red")
U.Paint(tex, false)
check(near(tex.color[1], 0.6) and near(tex.color[2], 0.6), "paint off: colour from before comes back")
U.Paint(tex, true)
tex:SetVertexColor(0.5, 0.5, 0.5)        -- someone else repainted it meanwhile
U.Paint(tex, false)
check(near(tex.color[1], 0.5) and near(tex.color[2], 0.5), "paint off keeps a colour set by someone else")
tex:SetVertexColor(0.9, 0, 0)            -- the client's own red
U.Paint(tex, true)
tex:SetVertexColor(0.9, 0, 0)
U.Paint(tex, false)
check(isWhite(tex), "client red is no colour to come back to")

-- 3. Merchant -------------------------------------------------------------------------------------------
MERCHANT_ITEMS_PER_PAGE, BUYBACK_ITEMS_PER_PAGE = 10, 12
MerchantFrame = new("Frame", UIParent, "MerchantFrame")
MerchantFrame.selectedTab, MerchantFrame.page = 1, 1
MerchantFrame:Hide()
local back = MerchantFrame:CreateTexture("MerchantFrameBg")
back:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble")
MerchantRepairAllButton, MerchantGuildBankRepairButton, MerchantBuyBackItem = new("Button"), new("Button"), new("Button")
for i = 1, 12 do
    local merchantButton = new("Frame", MerchantFrame, "MerchantItem" .. i)
    local slot = merchantButton:CreateTexture("MerchantItem" .. i .. "SlotTexture")
    slot:SetTexture("Interface\\FrameGeneral\\UI-Frame-Slot")
    local nameFrame = merchantButton:CreateTexture("MerchantItem" .. i .. "NameFrame")
    nameFrame:SetTexture("Interface\\FrameGeneral\\UI-Frame-Label")
    local itemButton = new("Button", merchantButton, "MerchantItem" .. i .. "ItemButton")
    local icon = itemButton:CreateTexture("MerchantItem" .. i .. "ItemButtonIconTexture")
    icon:SetTexture("Interface\\Icons\\INV_Belt_01")
    itemButton.normal = itemButton:CreateTexture()
    itemButton.normal:SetTexture("Interface\\Buttons\\UI-Quickslot2")
end
-- pages: { link, isUsable (stock), numAvailable }
local merchant = {
    { "mailBelt", 1, -1 }, { "trinket", 1, -1 }, { "staff", nil, -1 }, { "highLevel", 1, 0 },
    { "trinket", 1, -1 }, { "trinket", 1, -1 }, { "trinket", 1, -1 }, { "trinket", 1, -1 },
    { "trinket", 1, -1 }, { "trinket", 1, -1 },
    { "trinket", 1, -1 }, { "mailBelt", 1, -1 },
}
local buyback = { "trinket", "mailBelt" }
function GetMerchantItemInfo(index)
    local e = merchant[index]
    if not e then return nil end
    return e[1], "icon", 100, 1, e[3], e[2]
end
function GetMerchantItemLink(index) return merchant[index] and merchant[index][1] end
function GetBuybackItemLink(index) return buyback[index] end
function GetMerchantNumItems() return #merchant end
-- Like the client: every slot of the page is repainted (red, dark red, gray or white).
local stockHonest = true
local function stockColor(i, isUsable, available)
    local icon = _G["MerchantItem" .. i .. "ItemButtonIconTexture"]
    local normal = _G["MerchantItem" .. i .. "ItemButton"].normal
    local r, g, b = 1, 1, 1
    if not isUsable and stockHonest then r, g, b = available == 0 and 0.5 or 0.9, 0, 0 end
    icon:SetVertexColor(r, g, b)
    normal:SetVertexColor(r, g, b)
    _G["MerchantItem" .. i .. "NameFrame"]:SetVertexColor(r == 1 and 0.5 or 1, r == 1 and 0.5 or 0, r == 1 and 0.5 or 0)
end
function MerchantFrame_UpdateMerchantInfo()
    for i = 1, MERCHANT_ITEMS_PER_PAGE do
        local index = (MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE + i
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        if merchant[index] then
            button:Show()
            stockColor(i, merchant[index][2], merchant[index][3])
        else
            button:Hide()
        end
    end
end
function MerchantFrame_UpdateBuybackInfo()
    for i = 1, BUYBACK_ITEMS_PER_PAGE do
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        if buyback[i] then button:Show() stockColor(i, 1, -1) else button:Hide() end
    end
end
function MerchantFrame_Update()
    if MerchantFrame.selectedTab == 1 then MerchantFrame_UpdateMerchantInfo() else MerchantFrame_UpdateBuybackInfo() end
end
function MerchantFrame_UpdateRepairButtons() end
load("Merchant.lua")
fire("PLAYER_LOGIN")
MerchantFrame:Show()
local function icon(i) return _G["MerchantItem" .. i .. "ItemButtonIconTexture"] end

MerchantFrame_Update()
check(isRed(icon(1)) and isRed(icon(3)), "page 1: unusable items red")
check(isWhite(icon(2)), "page 1: usable item white")
check(near(icon(4).color[1], 0.5) and isRed(icon(4)), "sold out and unusable: dark red as in the client")

-- The client of the server reports the mail belt as usable and paints nothing red.
stockHonest = false
merchant[1][2] = 1
MerchantFrame_Update()
check(isRed(icon(1)), "stock verdict missing: the tooltip check paints it red")
check(isRed(_G["MerchantItem1ItemButton"].normal), "the slot border is red as well")
check(isWhite(icon(2)), "usable item stays white")

-- Next page: slot 1 now holds a usable item, slot 2 an unusable one.
MerchantFrame.page = 2
MerchantFrame_Update()
check(isWhite(icon(1)), "page change: a usable item in a once red slot is white")
check(isRed(icon(2)), "page change: unusable item on page 2 red")
check(not _G["MerchantItem3ItemButton"]:IsShown(), "empty slots hidden")

-- Page change by a client that does not repaint the icon at all: the red of ForeverUI is taken back.
MerchantFrame.page = 1
MerchantFrame_Update()
check(isRed(icon(2)) == false and isRed(icon(1)), "back to page 1")
local saved = MerchantFrame_UpdateMerchantInfo
merchant[1] = { "trinket", 1, -1 }
MerchantFrame_UpdateMerchantInfo = function() end
hooksecurefunc("MerchantFrame_UpdateMerchantInfo", ui.Merchant.PaintUnusable)
MerchantFrame_UpdateMerchantInfo()
check(isWhite(icon(1)), "client that does not repaint: ForeverUI takes its red back")
MerchantFrame_UpdateMerchantInfo = saved
merchant[1] = { "mailBelt", 1, -1 }

-- Buyback tab.
MerchantFrame.selectedTab = 2
MerchantFrame_Update()
check(isWhite(icon(1)) and isRed(icon(2)), "buyback: unusable item red")
MerchantFrame.selectedTab = 1

-- Item data that arrives a moment later.
item("lateBelt", 10, { line("Belt"), line("Пояс", WHITE, "Кожа", RED) })
items.lateBelt.loading = true
merchant[5] = { "lateBelt", 1, -1 }
MerchantFrame_Update()
check(isWhite(icon(5)), "no data yet: not red")
items.lateBelt.loading = nil
tick(1)
check(isRed(icon(5)), "late item data: red after the retry")

-- 5. Loot -----------------------------------------------------------------------------------------------
LOOTFRAME_NUMBUTTONS = 4
LootFrame = new("Frame", UIParent, "LootFrame")
LootFrame.RetailArt = false
LootFrameUpButton, LootFrameDownButton = new("Button"), new("Button")
local loot = { "mailBelt", "trinket", "staff", nil }
function GetLootSlotLink(slot) return loot[slot] end
function GetLootSlotInfo() return "icon", "Item", 1, 2, false end
for i = 1, LOOTFRAME_NUMBUTTONS do
    local button = new("Button", LootFrame, "LootButton" .. i)
    button.slot = i
    button:CreateTexture("LootButton" .. i .. "IconTexture"):SetTexture("Interface\\Icons\\INV_Belt_01")
    button:CreateFontString("LootButton" .. i .. "Text"):SetText("Item")
    button:CreateFontString("LootButton" .. i .. "Count")
end
function LootFrame_UpdateButton() end
function LootFrame_Show() LootFrame:Show() end
load("Loot.lua")
for i = 1, 3 do LootFrame_UpdateButton(i) end
check(isRed(_G.LootButton1IconTexture) and isRed(_G.LootButton3IconTexture), "loot: unusable items red")
check(isWhite(_G.LootButton2IconTexture), "loot: usable item white")
loot[1] = "trinket"
LootFrame_UpdateButton(1)
check(isWhite(_G.LootButton1IconTexture), "loot: button reused for a usable item turns white")
loot[1] = "mailBelt"
LootFrame_UpdateButton(1)
LootFrame_Show(LootFrame)
LootFrame.scripts.OnEvent(LootFrame, "LOOT_SLOT_CLEARED", 1)
check(isRed(_G.ForeverStockLootFlyout1IconTexture), "loot flyout of an unusable item is red")

-- 6. Bags: the module loads with the shared check ---------------------------------------------------------
local bags = io.open("Bags.lua"):read("*a")
check(bags:find("ui.ItemUsability", 1, true) and not bags:find("cannotEquip", 1, true), "bags use the shared check")
assert(loadfile("Bags.lua"))

-- 7. Forbidden API --------------------------------------------------------------------------------------
for _, path in ipairs({ "ItemUsability.lua", "Merchant.lua", "Loot.lua", "Bags.lua" }) do
    local text = io.open(path):read("*a")
    for _, api in ipairs({ "C_Timer", "SetShown(", "SetColorTexture", "SetAtlas", "C_AddOns" }) do
        check(not text:find(api, 1, true), path .. " uses " .. api)
    end
end

if failures > 0 then error(failures .. " check(s) failed") end
print("ItemUsability: all checks passed")
