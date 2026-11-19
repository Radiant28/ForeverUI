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
    function f:SetPoint(...) self.point = { ... } end
    function f:GetPoint() if self.point then return unpack(self.point) end end
    function f:ClearAllPoints() self.point = nil end
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
local spells = { [13262] = "Disenchant", [7411] = "Enchanting", [31252] = "Prospecting", [25229] = "Jewelcrafting" }
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
-- ForeverUI must not touch the auction house API: calling it fails the test.
function GetAuctionItemClasses() error("auction house API used") end
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
local counts = {}
function GetContainerItemInfo(b, s) if bags[b][s] then return "tex", counts[b .. ":" .. s] or 1, false, 2 end end
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
-- A click: PreClick, the secure action of the template (a "/use" macro uses the item: with the enchant cursor up
-- the client applies the enchant to it, as a click on the item would), OnClick, PostClick.
local secureUses = {}
local function click(button, mouse)
    mouse = mouse or "LeftButton"
    if rawget(button.scripts, "PreClick") then button.scripts.PreClick(button, mouse) end
    if button.attrs.type == "click" then
        -- The secure "click" action presses the delegate button (Blizzard's own, untainted).
        local delegate = button.attrs.clickbutton
        if delegate and delegate.scripts.OnClick then delegate.scripts.OnClick(delegate, mouse) end
    elseif button.attrs.type == "macro" then
        local text = button.attrs.macrotext
        secureUses[#secureUses + 1] = text
        local bag, slot = text:match("^/use (%d+) (%d+)$")
        if bag then
            if targeting then targeting = false; appliedTo = "bag" .. bag .. ":" .. slot end
        else
            slot = text:match("^/use (%d+)$")
            if targeting then targeting = false; appliedTo = "inv" .. slot end
        end
    end
    if rawget(button.scripts, "OnClick") then button.scripts.OnClick(button, mouse) end
    if rawget(button.scripts, "PostClick") then button.scripts.PostClick(button, mouse) end
end
local function press()
    local target = overrides.SPACE
    assert(target, "session key is bound")
    click(_G[target])
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

-- Disenchant button: a plain Disenchant cast through the secure button laid over it while the bag is open.
local deButton, secure = _G.ForeverStockUIDisenchantButton, _G.ForeverStockUIDisenchantSecure
local de = E.disenchant
local function overlay(s) return E.Overlay(buttons[s]) end
local currentSpell
function IsCurrentSpell(name) return name == currentSpell end
window:Show()
tick(0.05)
assert(secure.shown and secure.attrs.type == "spell" and secure.attrs.spell == "Disenchant"
    and secure.attrs["target-bag"] == nil, "a plain Disenchant cast, no target")
assert(not _G.ForeverStockUIDisenchantCancel and deButton.scripts.OnClick, "no list mode left")
-- Place: just left of the bag's close cross, in its size; the secure button takes the same size.
local close = newFrame("Button", "ForeverStockInventoryCloseButton", window)
close:SetSize(23, 23)
close.level = 7
ui.Bags.CloseButton = function() return close end
local ctrl = _G.ForeverStockUIDisenchantControl
local anchored
ctrl.SetPoint = function(_, point, relative, relativePoint, x, y) anchored = { point, relative, relativePoint, x, y } end
E.Apply()
tick(0.05)
assert(anchored and anchored[1] == "RIGHT" and anchored[2] == close and anchored[3] == "LEFT", "left of the close cross")
assert(deButton:GetWidth() == 20 and deButton:GetHeight() == 20 and ctrl.parent == window, "85% of the cross")
assert(secure.w == 20 and secure.h == 20, "the secure button covers all of it")
assert(anchored[4] <= -8, "a gap from the cross against misclicks")
assert(deButton.level > close.level and ctrl.level >= close.level, "drawn above the window frame, like the cross")
close.level = 12   -- the window skin lifts the cross later
tick(0.05)
assert(deButton.level > 12, "follows the cross when the skin lifts it")
-- Click: the cursor waits for an item; items that cannot be disenchanted are dimmed, the layer takes no clicks.
secure.scripts.PreClick(secure, "LeftButton")
targeting = true
tick(0.05)
assert(de.dimmed, "dimmed while the cursor is up")
assert(overlay(1).dim.alpha == 0 and overlay(2).dim.alpha == 0, "items that can be disenchanted stay bright")
assert(overlay(3).dim.alpha > 0 and overlay(4).dim.alpha > 0 and overlay(5).dim.alpha > 0, "grey, shirt, consumable dimmed")
assert(overlay(6).dim.alpha == 0, "empty slots are not dimmed")
assert(overlay(3).mouse == false, "clicks go through to the item")
-- The item is clicked: the cursor ends, the dimming goes.
targeting = false
tick(0.6)
assert(not de.dimmed and not overlay(3).shown and de.armed == nil, "undimmed after the cast")
-- Disenchant from the spellbook dims too; another targeting spell does not.
targeting, currentSpell = true, "Disenchant"
fire("CURRENT_SPELL_CAST_CHANGED")
tick(0.05)
assert(de.dimmed, "spellbook Disenchant dims")
currentSpell = "Frost Nova"
tick(0.05)
assert(not de.dimmed, "other targeting spells do not dim")
-- Bag changes while the cursor is up re-check the cells.
currentSpell = "Disenchant"
tick(0.05)
bags[0][1] = link(102)
fire("BAG_UPDATE")
tick(0.05)
assert(overlay(1).dim.alpha > 0, "re-checked after a bag change")
targeting, currentSpell = false, nil
tick(0.05)
bags[0][1] = link(100, 0, 1)
-- Combat hides the secure cover before the lockdown; it comes back after combat.
fire("PLAYER_REGEN_DISABLED")
assert(not secure.shown, "hidden for combat")
combat = true
tick(0.05)
assert(not secure.shown)
combat = false
fire("PLAYER_REGEN_ENABLED")
tick(0.05)
assert(secure.shown, "back after combat")
-- Closing the bag hides the cover.
window:Hide()
tick(0.05)
assert(not secure.shown, "bag closed")
window:Show()
tick(0.05)
assert(secure.shown)
-- No Enchanting: no button at all, and nothing to cast; it comes back with the profession.
known[13262] = nil
fire("SPELLS_CHANGED")
tick(0.05)
assert(not ctrl.shown and not secure.shown and secure.attrs.type == nil, "no profession, no button")
known[13262] = true
fire("SPELLS_CHANGED")
tick(0.05)
assert(ctrl.shown and secure.shown and secure.attrs.type == "spell", "back with the profession")

-- Prospecting: a second button left of Disenchant, same size; Disenchant stays next to the cross.
local prButton, prSecure = _G.ForeverStockUIProspectButton, _G.ForeverStockUIProspectSecure
local pr = E.prospect
assert(prButton and not prButton.shown and not prSecure.shown, "no Jewelcrafting, no prospect button")
known[31252] = true
fire("SPELLS_CHANGED")
tick(0.05)
assert(prButton.shown and prSecure.shown and prSecure.attrs.type == "spell" and prSecure.attrs.spell == "Prospecting",
    "a plain Prospecting cast")
assert(prButton:GetWidth() == deButton:GetWidth() and prButton:GetHeight() == deButton:GetHeight(), "same size")
assert(prSecure.w == 20 and prSecure.h == 20, "its secure cover takes the size too")
local dePoint = { deButton:GetPoint() }
local prPoint = { prButton:GetPoint() }
assert(dePoint[2] == ctrl and dePoint[4] == 0 and prPoint[2] == ctrl and prPoint[4] < -20, "right to left from the cross")
assert(ctrl:GetWidth() > 40, "the control holds both")
assert(prButton.level > close.level, "drawn above the window frame too")
-- Ores (5 or more) stay bright, everything else is dimmed.
bags[0][7], bags[0][8] = link(2770), link(36909)
counts["0:7"], counts["0:8"] = 20, 4
assert(E.CanProspect(0, 7) and not E.CanProspect(0, 8) and not E.CanProspect(0, 1), "ore x20, ore x4, sword")
prSecure.scripts.PreClick(prSecure, "LeftButton")
targeting = true
tick(0.05)
assert(pr.dimmed and not de.dimmed, "the prospect cursor dims for prospecting")
assert(overlay(7).dim.alpha == 0 and overlay(8).dim.alpha > 0 and overlay(1).dim.alpha > 0, "only ores x5 stay bright")
targeting = false
tick(0.6)
assert(not pr.dimmed and pr.armed == nil and not overlay(7).shown, "undimmed after the cast")
targeting, currentSpell = true, "Prospecting"
tick(0.05)
assert(pr.dimmed, "spellbook Prospecting dims")
targeting, currentSpell = false, nil
tick(0.05)
-- Combat hides both covers.
fire("PLAYER_REGEN_DISABLED")
assert(not prSecure.shown and not secure.shown, "both hidden for combat")
fire("PLAYER_REGEN_ENABLED")
tick(0.05)
assert(prSecure.shown and secure.shown)
-- Without Enchanting the prospect button moves up to the cross.
known[13262] = nil
fire("SPELLS_CHANGED")
tick(0.05)
prPoint = { prButton:GetPoint() }
assert(ctrl.shown and prButton.shown and not deButton.shown and not secure.shown and prPoint[4] == 0, "next to the cross")
known[13262] = true
-- The option turns it off.
ui.settings.enchantProspectButton = false
E.Apply()
tick(0.05)
assert(not prButton.shown and not prSecure.shown and deButton.shown, "option off")
ui.settings.enchantProspectButton = nil
known[31252] = nil
fire("SPELLS_CHANGED")
tick(0.05)
bags[0][7], bags[0][8] = nil, nil

-- Re-enchant: the repeat row and the one-time target pick.
fire("ADDON_LOADED", "Blizzard_TradeSkillUI")
local reButton = _G.ForeverStockUIReenchantButton
local re = E.reenchant
ui.settings.enchantRepeatCount = 3
fire("TRADE_SKILL_SHOW")
-- The count follows what the reagents allow (5 here)...
assert(_G.ForeverStockUIReenchant.shown and reButton.text == "Repeat ×5", reButton.text)
assert(ui.settings.enchantRepeatCount == 5 and _G.ForeverStockUIReenchantCount.text == 5, "max available filled in")
-- ...until it is set by hand for the recipe: then updates keep the player's number.
local minus = _G.ForeverStockUIReenchantMinus
minus.scripts.OnClick(minus)
minus.scripts.OnClick(minus)
fire("TRADE_SKILL_UPDATE")
assert(reButton.text == "Repeat ×3" and ui.settings.enchantRepeatCount == 3, "manual count kept")
-- Outside a session the replace popup is left alone and the key is not bound.
StaticPopup_Show("REPLACE_ENCHANT")
tick(0.05)
assert(popups.REPLACE_ENCHANT and overrides.SPACE == nil and replaced == 0)
popups.REPLACE_ENCHANT = nil

inventory[15] = link(200, 1000, 5)
click(reButton)
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
-- A mouse click on "Space: replace" does what the key does: Blizzard's Yes through the secure click action.
assert(reButton.text == "Space: replace")
click(reButton)
assert(replaced == 2 and re.active and not popups.REPLACE_ENCHANT, "mouse click presses Blizzard's Yes")
assert(reButton.attrs.type == nil and reButton.attrs.clickbutton == nil, "click action cleared")
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
click(reButton)
assert(re.active and re.phase == "casting" and re.stepMode, "remembered target, no pick, step mode")
assert(secureUses[#secureUses] == "/use 15" and appliedTo == "inv15", "a press applies the target with its secure /use")
assert(reButton.attrs.type == nil and reButton.attrs.macrotext == nil, "the secure action is cleared after the click")
fire("UNIT_SPELLCAST_START", "player", "Enchant Cloak - Agility")
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Enchant Cloak - Agility")
TradeSkillFrame_SetSelection(2)
assert(not re.active and printed[#printed]:find("recipe changed"))
TradeSkillFrame_SetSelection(1)
inventory[15] = link(200, 0, 99)
click(reButton)
assert(re.target == nil and re.phase == "picking", "a different cloak is not the remembered one")
SpellStopTargeting()
tick(0.2)
assert(not re.active and printed[#printed]:find("no target"))
-- Reagents.
recipes[1][3] = 0
click(reButton)
assert(not re.active)
recipes[1][3] = 5
-- The client takes an auto-chained repeat but never casts it (no cast, no popup): no stop, the session goes
-- on by presses and later sessions start that way.
ui.settings.enchantAutoChainBlocked = nil
inventory[15] = link(200, 1000, 5)
click(reButton)
PickupInventoryItem(15)
fire("UNIT_SPELLCAST_START", "player", "Enchant Cloak - Agility")
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Enchant Cloak - Agility")
tick(0.4)
assert(re.phase == "casting" and re.auto, "auto chain applied the target")
for _ = 1, 35 do tick(0.1) end
assert(re.active and re.stepMode and re.phase == "wait_click", "silent drop: the session waits for a press")
assert(ui.settings.enchantAutoChainBlocked == true and printed[#printed]:find("did not start the repeat"), "remembered")
assert(press() == "ForeverStockUIReenchantButton" and re.phase == "casting" and not re.auto, "a press repeats")
for _ = 1, 35 do tick(0.1) end
assert(not re.active and printed[#printed]:find("did not start"), "a press that does not cast stops the session")
-- No enchant cursor (the client refused DoTradeSkill): the press never runs "/use" (it would equip the item).
ui.settings.enchantAutoChainBlocked = true
inventory[15] = link(200, 1000, 5)
local usesBefore = #secureUses
tradeAllowed = false
click(reButton)
assert(#secureUses == usesBefore and not re.active, "no /use without the enchant cursor")
tradeAllowed = true
-- Stopping with the replace dialog up leaves the cursor alone (stopping it would close Blizzard's dialog from addon code).
ui.settings.enchantAutoChainBlocked = true
inventory[15] = link(200, 1000, 5)
click(reButton)
assert(re.active and re.phase == "casting", "session on the remembered cloak")
targeting = true
StaticPopup_Show("REPLACE_ENCHANT")
click(reButton, "RightButton")
assert(not re.active and targeting and popups.REPLACE_ENCHANT, "stopped, the dialog and its cursor untouched")
popups.REPLACE_ENCHANT, targeting = nil, false
-- Non-enchant recipe hides the row (the client shows its own "Create all" there).
TradeSkillFrame_SetSelection(2)
assert(not _G.ForeverStockUIReenchant.shown)

assert(addonReplaced == 0 and addonTouchedPopup == 0, "the addon never calls ReplaceEnchant or StaticPopup_Hide")

print("Enchanting OK: session key (Blizzard Yes, Next, sink, released, combat), forbidden-action fallback, item keys, eligibility, disenchant button (plain cast, dimming, spellbook cast, bag changes, combat, bag close, no spell), prospect button (place, size, ores x5, spellbook, combat, alone, option), re-enchant (pick, replace only in session, auto chain, step mode, recipe change, target check, reagents)")
