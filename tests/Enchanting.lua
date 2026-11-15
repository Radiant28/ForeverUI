-- Enchanting.lua on a permissive WoW mock: item keys, disenchant selection and queue (secure attributes,
-- moved items, loot wait, combat stop), re-enchant session (target pick, REPLACE_ENCHANT only in session,
-- recipe change, step-mode fallback).
local ui = { russian = false, settings = {} }
function ui.L(_, en) return en end
function ui.Settings() return ui.settings end
local printed = {}
function ui.Print(msg) printed[#printed + 1] = msg end

local now = 0
function GetTime() return now end
local frames, scripts = {}, {}
local function newFrame(kind, name, parent)
    local f = { shown = kind ~= "Frame" or true, attrs = {}, scripts = {}, level = 1, w = 10, h = 10, parent = parent,
        x = 0, y = 0, kind = kind }
    f.shown = true
    -- Unknown methods (capitalised) are no-ops; unknown fields stay nil.
    local mt = { __index = function(t, k)
        if type(k) == "string" and k:match("^%u") then return function() end end
    end }
    setmetatable(f, mt)
    function f:SetScript(n, fn) self.scripts[n] = fn end
    function f:GetScript(n) return self.scripts[n] end
    function f:HookScript(n, fn)
        local old = self.scripts[n]
        self.scripts[n] = function(...) if old then old(...) end fn(...) end
    end
    function f:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function f:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown and (not self.parent or not self.parent.IsVisible or self.parent:IsVisible()) end
    function f:SetAttribute(k, v) self.attrs[k] = v end
    function f:GetAttribute(k) return self.attrs[k] end
    function f:GetFrameLevel() return self.level end
    function f:SetFrameLevel(l) self.level = l end
    function f:SetParent(p) self.parent = p end
    function f:GetParent() return self.parent end
    function f:GetName() return name end
    function f:SetWidth(w) self.w = w end
    function f:SetSize(w, h) self.w, self.h = w, h end
    function f:GetWidth() return self.w end
    function f:GetHeight() return self.h end
    function f:GetLeft() return 100 end
    function f:GetBottom() return 50 end
    function f:GetEffectiveScale() return 1 end
    function f:SetText(t) self.text = t end
    function f:GetText() return self.text end
    function f:GetStringWidth() return #(self.text or "") * 5 end
    function f:Enable() self.enabled = true end
    function f:Disable() self.enabled = false end
    function f:EnableMouse(v) self.mouse = v end
    function f:SetAlpha(a) self.alpha = a end
    function f:SetBackdropBorderColor(r, g, b, a) self.borderAlpha = a end
    function f:GetID() return self.id or 0 end
    function f:SetID(i) self.id = i end
    function f:CreateTexture() return newFrame("Texture", nil, f) end
    function f:CreateFontString() return newFrame("FontString", nil, f) end
    f.events = {}
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
function CreateFrame(kind, name, parent) return newFrame(kind, name, parent) end
UIParent = newFrame("Frame", "UIParent")
GameTooltip = newFrame("GameTooltip", "GameTooltip")
function GameTooltip_Hide() end
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
SlashCmdList = {}
NUM_BAG_SLOTS, NUM_CONTAINER_FRAMES = 4, 0
CANCEL = "Cancel"
bit = bit or require("bit")
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
local hooks = {}
function hooksecurefunc(name, fn)
    local old = _G[name]
    _G[name] = function(...) local r = { old(...) }; fn(...); return unpack(r) end
end

-- Spells, items, bags.
local known = { [13262] = true }
local spells = { [13262] = "Disenchant", [7411] = "Enchanting" }
function GetSpellInfo(id)
    if type(id) == "string" then
        for sid, n in pairs(spells) do if n == id and known[sid] then return n end end
        return nil
    end
    return spells[id], nil, "icon"
end
function IsSpellKnown(id) return known[id] == true end
local combat = false
function InCombatLockdown() return combat end
function GetAuctionItemClasses() return "Weapon", "Armor", "Container" end
local itemInfo = {
    [100] = { "Green Sword", 2, "Weapon", "INVTYPE_WEAPON" },
    [101] = { "Blue Helm", 3, "Armor", "INVTYPE_HEAD" },
    [102] = { "Grey Junk", 0, "Armor", "INVTYPE_HEAD" },
    [103] = { "Green Shirt", 2, "Armor", "INVTYPE_BODY" },
    [104] = { "Potion", 1, "Consumable", "" },
    [200] = { "Cloak", 3, "Armor", "INVTYPE_CLOAK" },
}
local function link(id, enchant, unique) return ("|cff1eff00|Hitem:%d:%d:0:0:0:0:0:%d:80|h[x]|h|r"):format(id, enchant or 0, unique or 0) end
function GetItemInfo(l)
    local id = tonumber(l:match("item:(%d+)"))
    local i = itemInfo[id]
    if not i then return end
    return i[1], l, i[2], 80, 80, i[3], "sub", 1, i[4]
end
local bags = { [0] = {}, {}, {}, {}, {} }
local sizes = { [0] = 16, 0, 0, 0, 0 }
function GetContainerItemLink(b, s) return bags[b] and bags[b][s] end
function GetContainerItemInfo(b, s) if bags[b][s] then return "tex", 1, false, 2 end end
function GetContainerItemQuestInfo() return false end
function GetContainerNumSlots(b) return sizes[b] or 0 end
function GetContainerNumFreeSlots(b)
    local n = 0
    for s = 1, sizes[b] or 0 do if not bags[b][s] then n = n + 1 end end
    return n, 0
end
local casting
function UnitCastingInfo() return casting end
local targeting, cursorItem = false, false
function SpellIsTargeting() return targeting end
function SpellCanTargetItem() return targeting end
function SpellStopTargeting() targeting = false end
function CursorHasItem() return cursorItem end
function ClearCursor() cursorItem = false end
local used = {}
function UseContainerItem(b, s) used[#used + 1] = b .. ":" .. s; targeting = false end
local appliedTo
function PickupContainerItem(b, s) if targeting then targeting = false; appliedTo = "bag" .. b .. ":" .. s else cursorItem = true end end
function PickupInventoryItem(s) if targeting then targeting = false; appliedTo = "inv" .. s else cursorItem = true end end
function UseInventoryItem(s) PickupInventoryItem(s) end
local inventory = {}
function GetInventoryItemLink(_, s) return inventory[s] end
-- The addon must never call ReplaceEnchant or StaticPopup_Hide itself (Blizzard-only / taints dialogs):
-- those stubs count calls from addon code; Blizzard's popup button below does the real confirmation.
local popups, addonTouchedPopup = {}, 0
function StaticPopup_Show(which) popups[which] = true end
function StaticPopup_Hide(which) addonTouchedPopup = addonTouchedPopup + 1; popups[which] = nil end
function StaticPopup_Visible(which) if popups[which] then return "StaticPopup1" end end
local replaced, addonReplaced = 0, 0
function ReplaceEnchant() addonReplaced = addonReplaced + 1 end
local overrides = {}
function SetOverrideBindingClick(owner, prio, key, target, button) overrides[key] = target end
function ClearOverrideBindings() for k in pairs(overrides) do overrides[k] = nil end end
function GetBindingText(key) return key == "SPACE" and "Space" or key end
function IsShiftKeyDown() return false end
-- Blizzard's dialog button: a hardware press on it runs the dialog's own OnAccept.
local popupYes = newFrame("Button", "StaticPopup1Button1")
popupYes:SetScript("OnClick", function() replaced = replaced + 1; popups.REPLACE_ENCHANT = nil end)

-- Combined bag stand-in.
local window = newFrame("Frame", "ForeverStockInventory")
local footer = newFrame("Frame", "ForeverStockInventoryFooter", window)
local buttons = {}
for s = 1, 16 do buttons[s] = newFrame("Button", "Slot" .. s, window) end
ui.Bags = {
    Window = function() return window end,
    Footer = function() return footer end,
    EachItem = function(fn) for s = 1, 16 do fn(buttons[s], 0, s) end end,
}

-- Trade skill stand-in.
local recipes = { { "Enchant Cloak - Agility", "optimal", 5, false, "Enchant" }, { "Runed Rod", "optimal", 1, false, nil } }
local selected = 1
TradeSkillFrame = newFrame("Frame", "TradeSkillFrame")
TradeSkillCreateButton = newFrame("Button", "TradeSkillCreateButton", TradeSkillFrame)
function TradeSkillFrame_SetSelection(id) selected = id end
function TradeSkillFrame_Update() end
function GetTradeSkillLine() return "Enchanting" end
function IsTradeSkillLinked() return false end
function GetTradeSkillSelectionIndex() return selected end
function GetTradeSkillInfo(i) local r = recipes[i]; if r then return r[1], r[2], r[3], r[4], r[5] end end
local tradeCalls, tradeAllowed = 0, true
function DoTradeSkill(i)
    tradeCalls = tradeCalls + 1
    if tradeAllowed and recipes[i][5] then targeting = true end
end

local chunk = assert(loadfile("Enchanting.lua"))
chunk("ForeverUI", ui)
local E = ui.Enchanting
local events
for _, f in ipairs(frames) do if rawget(f.scripts, "OnEvent") and rawget(f.events, "PLAYER_LOGIN") then events = f end end
local function fire(e, ...) events.scripts.OnEvent(events, e, ...) end
local driver
for _, f in ipairs(frames) do if rawget(f.scripts, "OnUpdate") then driver = f end end
local function tick(dt) now = now + (dt or 0.05); driver.scripts.OnUpdate(driver, dt or 0.05) end
-- A press of the session key: the override binding clicks whatever button it points at.
local function press()
    local target = overrides.SPACE
    assert(target, "session key is bound")
    local button = _G[target]
    if rawget(button.scripts, "PreClick") then button.scripts.PreClick(button, "LeftButton") end
    if rawget(button.scripts, "OnClick") then button.scripts.OnClick(button, "LeftButton") end
    if rawget(button.scripts, "PostClick") then button.scripts.PostClick(button, "LeftButton") end
    return target
end
fire("PLAYER_LOGIN")

-- Item keys ignore enchant and gems, keep id, suffix and unique id.
assert(E.ItemKey(link(200, 0, 7)) == E.ItemKey(link(200, 1889, 7)))
assert(E.ItemKey(link(200, 0, 7)) ~= E.ItemKey(link(200, 0, 8)))
assert(E.ItemKey(nil) == nil)

bags[0][1], bags[0][2], bags[0][3], bags[0][4], bags[0][5] = link(100, 0, 1), link(101, 0, 2), link(102), link(103), link(104)
assert(E.CanDisenchant(0, 1) and E.CanDisenchant(0, 2))
assert(not E.CanDisenchant(0, 3) and not E.CanDisenchant(0, 4) and not E.CanDisenchant(0, 5), "grey, shirt, consumable")

-- Selection mode.
local deButton, secure = _G.ForeverStockUIDisenchantButton, _G.ForeverStockUIDisenchantSecure
deButton.scripts.OnClick(deButton, "LeftButton")
local de = E.disenchant
assert(de.mode == "select")
local function overlay(s) return E.Overlay(buttons[s]) end
overlay(1).scripts.OnClick(overlay(1), "LeftButton")
overlay(3).scripts.OnClick(overlay(3), "LeftButton")
overlay(2).scripts.OnClick(overlay(2), "LeftButton")
assert(#de.queue == 2 and de.queue[1].slot == 1 and de.queue[2].slot == 2, "invalid items are ignored")
assert(overlay(3).dim.alpha > 0 and overlay(1).dim.alpha == 0, "ineligible items are dimmed")
overlay(2).scripts.OnClick(overlay(2), "LeftButton")
assert(#de.queue == 1, "second click unselects")
overlay(2).scripts.OnClick(overlay(2), "LeftButton")
assert(deButton.scripts and _G.ForeverStockUIDisenchantButton, "control exists")

-- Run: the secure button points at item 1.
deButton.scripts.OnClick(deButton, "LeftButton")
assert(de.mode == "run" and secure.shown)
assert(secure.attrs.type == "spell" and secure.attrs.spell == "Disenchant" and secure.attrs["target-bag"] == 0
    and secure.attrs["target-slot"] == 1)
-- The session key is bound to the secure button for the whole run.
tick(0.05)
assert(overrides.SPACE == "ForeverStockUIDisenchantSecure")
-- Press: PreClick then the secure cast (target applied by the template), PostClick sees no targeting.
assert(press() == "ForeverStockUIDisenchantSecure")
assert(de.phase == "sent")
assert(#used == 0)
fire("UNIT_SPELLCAST_START", "player", "Disenchant")
assert(de.phase == "casting")
-- Spamming the key mid-cast does nothing (and the key no longer reaches jump).
press()
assert(de.phase == "casting" and de.index == 1)
bags[0][1] = nil
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Disenchant")
fire("LOOT_OPENED")
tick(3)
assert(de.phase == "loot", "an open loot window holds the queue")
fire("LOOT_CLOSED")
tick(0.3)
assert(de.index == 2 and de.phase == "ready" and secure.attrs["target-slot"] == 2)

-- The second item moved to slot 9: the queue follows it by key.
bags[0][9], bags[0][2] = bags[0][2], nil
secure.scripts.PreClick(secure, "LeftButton")
assert(secure.attrs.type == nil, "a stale slot never casts")
secure.scripts.PostClick(secure, "LeftButton")
assert(secure.attrs["target-slot"] == 9 and de.phase == "ready")
-- Fallback for a template without target-bag: the cursor still targets after the click.
secure.scripts.PreClick(secure, "LeftButton")
targeting = true
secure.scripts.PostClick(secure, "LeftButton")
assert(used[1] == "0:9" and not targeting)
fire("UNIT_SPELLCAST_SENT", "player", "Disenchant")
bags[0][9] = nil
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Disenchant")
tick(3) -- autoloot: no loot window, the timeout advances
tick(0.3)
assert(de.mode == "idle" and not secure.shown and secure.attrs.type == nil, "queue finished")
assert(overrides.SPACE == nil, "the key is released after the run")
assert(printed[#printed]:find("finished: 2"))

-- Combat stops a run and clears the secure button.
bags[0][1] = link(100, 0, 11)
deButton.scripts.OnClick(deButton, "LeftButton")
overlay(1).scripts.OnClick(overlay(1), "LeftButton")
deButton.scripts.OnClick(deButton, "LeftButton")
assert(secure.attrs.type == "spell")
tick(0.05)
assert(overrides.SPACE)
fire("PLAYER_REGEN_DISABLED")
assert(de.mode == "idle" and secure.attrs.type == nil and not secure.shown and overrides.SPACE == nil)
-- Closing the bag cancels selection.
deButton.scripts.OnClick(deButton, "LeftButton")
window:Hide()
assert(de.mode == "idle")
window:Show()
-- No disenchant spell: the button is disabled.
known[13262] = nil
fire("SPELLS_CHANGED")
assert(deButton.enabled == false)
deButton.scripts.OnClick(deButton, "LeftButton")
assert(de.mode == "idle")
known[13262] = true

-- Re-enchant: the repeat row and the one-time target pick.
fire("ADDON_LOADED", "Blizzard_TradeSkillUI")
local reButton = _G.ForeverStockUIReenchantButton
local re = E.reenchant
ui.settings.enchantRepeatCount = 3
fire("TRADE_SKILL_SHOW")
assert(_G.ForeverStockUIReenchant.shown and reButton.text == "Repeat ×3")
-- Outside a session the replace popup is left alone and the key is not bound.
StaticPopup_Show("REPLACE_ENCHANT")
tick(0.05)
assert(popups.REPLACE_ENCHANT and overrides.SPACE == nil and replaced == 0)
popups.REPLACE_ENCHANT = nil

inventory[15] = link(200, 1000, 5)
reButton.scripts.OnClick(reButton, "LeftButton")
assert(re.active and re.phase == "picking" and targeting)
-- The user clicks the cloak on the character: the client applies the target, then asks to replace.
PickupInventoryItem(15)
assert(re.target and re.target.type == "inv" and re.target.slot == 15 and re.phase == "casting")
StaticPopup_Show("REPLACE_ENCHANT")
fire("REPLACE_ENCHANT")
tick(0.05)
assert(popups.REPLACE_ENCHANT, "the addon never confirms on its own")
assert(overrides.SPACE == "StaticPopup1Button1" and reButton.text == "Space: replace", "the key points at Blizzard's Yes")
assert(press() == "StaticPopup1Button1" and replaced == 1 and not popups.REPLACE_ENCHANT)
tick(0.05)
assert(overrides.SPACE == "ForeverStockUIEnchantKeySink", "during the cast the key is swallowed")
fire("UNIT_SPELLCAST_START", "player", "Enchant Cloak - Agility")
inventory[15] = link(200, 1099, 5)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Enchant Cloak - Agility")
assert(re.done == 1 and re.phase == "next")
tick(0.4)
assert(re.phase == "casting" and appliedTo == "inv15", "auto chain applies the remembered target")
StaticPopup_Show("REPLACE_ENCHANT")
tick(0.05)
press()
assert(replaced == 2)
fire("UNIT_SPELLCAST_START", "player", "Enchant Cloak - Agility")
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Enchant Cloak - Agility")
-- The client refuses DoTradeSkill outside a click: two tries, then step mode; the key presses "Next".
tradeAllowed = false
tick(0.4)
tick(0.7)
assert(re.stepMode and re.phase == "wait_click" and reButton.text == "Next 3/3 [Space]")
tradeAllowed = true
tick(0.05)
assert(press() == "ForeverStockUIReenchantButton")
assert(re.phase == "casting")
fire("UNIT_SPELLCAST_START", "player", "Enchant Cloak - Agility")
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Enchant Cloak - Agility")
assert(not re.active and printed[#printed]:find("finished: 3 of 3"))
tick(0.05)
assert(overrides.SPACE == nil, "key released after the session")
StaticPopup_Show("REPLACE_ENCHANT")
assert(popups.REPLACE_ENCHANT and replaced == 2, "after the session the popup stays")
popups.REPLACE_ENCHANT = nil

-- ADDON_ACTION_FORBIDDEN on DoTradeSkill: remembered, the next session starts in step mode.
fire("ADDON_ACTION_FORBIDDEN", "ForeverUI", "DoTradeSkill()")
assert(ui.settings.enchantAutoChainBlocked == true)
fire("ADDON_ACTION_FORBIDDEN", "OtherAddon", "CastSpellByName()")
assert(E.blocked == "DoTradeSkill()")

-- Remembered target reused; recipe change and a swapped item stop the session.
reButton.scripts.OnClick(reButton, "LeftButton")
assert(re.active and re.phase == "casting" and re.stepMode, "remembered target, no pick, step mode")
fire("UNIT_SPELLCAST_START", "player", "Enchant Cloak - Agility")
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Enchant Cloak - Agility")
TradeSkillFrame_SetSelection(2)
assert(not re.active and printed[#printed]:find("recipe changed"))
TradeSkillFrame_SetSelection(1)
inventory[15] = link(200, 0, 99)
reButton.scripts.OnClick(reButton, "LeftButton")
assert(re.target == nil and re.phase == "picking", "a different cloak is not the remembered one")
SpellStopTargeting()
tick(0.2)
assert(not re.active and printed[#printed]:find("no target"))
-- Reagents.
recipes[1][3] = 0
reButton.scripts.OnClick(reButton, "LeftButton")
assert(not re.active)
recipes[1][3] = 5
-- Non-enchant recipe hides the row (the client shows its own "Create all" there).
TradeSkillFrame_SetSelection(2)
assert(not _G.ForeverStockUIReenchant.shown)

assert(addonReplaced == 0 and addonTouchedPopup == 0, "the addon never calls ReplaceEnchant or StaticPopup_Hide")

print("Enchanting OK: session key (disenchant, Blizzard Yes, Next, sink, released, combat), forbidden-action fallback, item keys, eligibility, selection, secure queue (moved item, loot wait, fallback target, combat, bag close), re-enchant (pick, replace only in session, auto chain, step mode, recipe change, target check, reagents)")
