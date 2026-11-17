-- Run from the addon directory (see INDEX.md): combat suite — profiles, serializer and import/export,
-- Cooldown Manager engine, click-cast attribute plan and combat queue, raid frame decoration
-- (shield line geometry, dispel highlight, indicators) and the four option pages on real modules.
local forbidden = { "C_Timer", "BackdropTemplate", "FramePool", "CreateFramePool", "SetColorTexture", "SetAtlas",
    "C_AddOns", "SetShown(", "CreateMaskTexture", "C_NamePlate" }

---------------------------------------------------------------------------------------------------
-- Permissive frame mock
---------------------------------------------------------------------------------------------------
local methods, objects = {}, {}
local function new(kind, parent, name)
    local object = setmetatable({ kind = kind, parent = parent, shown = true, scripts = {}, attributes = {},
        width = 100, height = 20, points = {}, children = {}, alpha = 1, scale = 1, level = 1 }, { __index = function(_, key)
        if methods[key] then return methods[key] end
        if type(key) == "string" and key:match("^%u") and not key:match("^On") and not key:match("^Forever") then
            return function() end
        end
    end })
    objects[#objects + 1] = object
    if parent and parent.children then table.insert(parent.children, object) end
    if name then _G[name] = object end
    return object
end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:GetSize() return self.width, self.height end
function methods:SetPoint(...) table.insert(self.points, { ... }) end
function methods:ClearAllPoints() self.points = {} end
function methods:GetPoint(i) local p = self.points[i or 1]; if p then return unpack(p) end end
function methods:GetNumPoints() return #self.points end
function methods:Show() local was = self.shown; self.shown = true; if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() local was = self.shown; self.shown = false; if was and self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:IsShown() return self.shown end
function methods:IsVisible()
    local node = self
    while node do
        if not node.shown then return false end
        node = node.parent
    end
    return true
end
function methods:SetScript(name, fn) self.scripts[name] = fn end
function methods:GetScript(name) return self.scripts[name] end
function methods:HookScript(name, fn)
    local old = self.scripts[name]
    self.scripts[name] = function(...) if old then old(...) end fn(...) end
end
function methods:CreateTexture() return new("Texture", self) end
function methods:CreateFontString() return new("FontString", self) end
function methods:SetText(text) self.text = text end
function methods:GetText() return self.text end
function methods:GetStringWidth() return #(tostring(self.text or "")) * 6 end
function methods:GetStringHeight() return 14 end
function methods:SetMinMaxValues(a, b) self.min, self.max = a, b end
function methods:GetMinMaxValues() return self.min, self.max end
function methods:SetValue(v) self.value = v; if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end end
function methods:GetValue() return self.value end
function methods:SetThumbTexture() self.thumb = new("Texture", self) end
function methods:GetThumbTexture() return self.thumb end
function methods:Enable() self.disabled = nil end
function methods:Disable() self.disabled = true end
function methods:IsEnabled() return not self.disabled and 1 or nil end
function methods:GetEffectiveScale() return self.scale end
function methods:SetScale(s) self.scale = s end
function methods:GetScale() return self.scale end
function methods:GetFrameLevel() return self.level end
function methods:SetFrameLevel(l) self.level = l end
function methods:GetParent() return self.parent end
function methods:SetParent(p) self.parent = p end
function methods:SetAlpha(a) self.alpha = a end
function methods:GetAlpha() return self.alpha end
function methods:GetVerticalScroll() return rawget(self, "vscroll") or 0 end
function methods:SetVerticalScroll(v) self.vscroll = v end
function methods:SetVertexColor(...) self.color = { ... } end
function methods:SetTexture(t) self.texture = t end
function methods:GetTexture() return self.texture end
function methods:SetStatusBarTexture(t) self.barTexture = t end
function methods:GetStatusBarTexture() local bar = self return { GetTexture = function() return bar.barTexture end } end
function methods:SetStatusBarColor(...) self.barColor = { ... } end
function methods:SetBackdropBorderColor(...) self.borderColor = { ... } end
function methods:GetName() return self.name end
function methods:GetChildren() return unpack(self.children) end
function methods:GetRegions() return end
function methods:SetAttribute(k, v) self.attributes[k] = v end
function methods:GetAttribute(k) return self.attributes[k] end
function methods:IsProtected() return self.protected end
function methods:GetObjectType() return self.kind end
function methods:SetCooldown(s, d) self.cd = { s, d } end
function methods:Click(button) if self.scripts.OnClick then self.scripts.OnClick(self, button or "LeftButton") end end
function methods:GetLeft() return 100 end
function methods:GetTop() return 600 end
methods.WrapScript = function(self, frame, script, body) frame.wraps = frame.wraps or {}; frame.wraps[script] = body end
-- The restricted environment of this client has IsUnderMouse: the probe in ClickCast.lua says yes.
methods.Execute = function(self) self.attributes["fuicc-um"] = 1 end
local released, hovering = {}, nil
function ClearOverrideBindings(frame) released[frame] = true end
function MouseIsOver(frame) return frame == hovering end

function CreateFrame(kind, name, parent)
    local frame = new(kind, parent, name)
    frame.name = name
    return frame
end
function CreateFont(name) return new("Font", nil, name) end

UIParent = CreateFrame("Frame", "UIParent")
InterfaceOptionsFramePanelContainer = CreateFrame("Frame")
ColorPickerFrame = CreateFrame("Frame", "ColorPickerFrame")
GameTooltip = CreateFrame("GameTooltip")
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
UISpecialFrames, StaticPopupDialogs, SlashCmdList = {}, {}, {}
YES, NO, BOOKTYPE_SPELL = "Yes", "No", "spell"
RAID_CLASS_COLORS = { PRIEST = { r = 1, g = 1, b = 1 } }

local combat, now = false, 100
local printed = {}
function InCombatLockdown() return combat end
function GetCursorPosition() return 0, 0 end
function GetTime() return now end
function GetLocale() return "ruRU" end
function GetAddOnMetadata() return "1.3.0" end
function PlaySound(sound) printed.sound = sound end
function PlaySoundFile() end
function GameTooltip_Hide() end
function geterrorhandler() return function(err) error(err, 0) end end
function InterfaceOptions_AddCategory() end
function StaticPopup_Show() return {} end
function tinsert(t, v) table.insert(t, v) end
function hooksecurefunc(a, b, c)
    if type(a) == "table" then
        local old = a[b]
        a[b] = function(...) local r = { old(...) } c(...) return unpack(r) end
    else
        local old = _G[a]
        _G[a] = function(...) local r = { old(...) } b(...) return unpack(r) end
    end
end
LibStub = nil

-- Unit and spell API
local talentGroup = 1
function UnitName() return "Tester" end
function GetRealmName() return "Realm" end
function UnitClass() return "Priest", "PRIEST" end
function UnitGUID(unit) return unit and ("GUID-" .. unit) or nil end
function UnitExists(unit) return unit == "player" or unit == "target" or unit == "raid1" or unit == "raid2" or unit == "raid3" end
function UnitIsUnit(a, b) return a == b end
function UnitHealth() return 60 end
function UnitHealthMax() return 100 end
function UnitIsDeadOrGhost() return false end
function UnitIsConnected() return true end
function UnitInRange() return 1 end
function UnitInRaid() return 1 end
function UnitInParty() return false end
function UnitThreatSituation() return 0 end
function GetThreatStatusColor() return 1, 0, 0 end
function UnitCanAttack() return true end
function GetActiveTalentGroup() return talentGroup end
function GetNumTalentTabs() return 3 end
function GetTalentTabInfo(i) return ({ "Discipline", "Holy", "Shadow" })[i], "", i == 2 and 51 or 10 end
function GetNumTalents() return 0 end
function GetNumRaidMembers() return 0 end
function GetNumPartyMembers() return 0 end
function IsInInstance() return false, "none" end
function GetShapeshiftForm() return 0 end
function GetNumShapeshiftForms() return 0 end

local spells = { [17] = { "Power Word: Shield", "Interface\\Icons\\PWS" }, [47540] = { "Penance", "Interface\\Icons\\Penance" },
    [139] = { "Renew", "Interface\\Icons\\Renew" }, [988] = { "Dispel Magic", "Interface\\Icons\\Dispel" },
    [528] = { "Cure Disease", "" }, [588] = { "Inner Fire", "Interface\\Icons\\InnerFire" },
    [33151] = { "Surge of Light", "Interface\\Icons\\Surge" }, [60065] = { "Reflection of Torment", "" } }
function GetSpellInfo(spell)
    if type(spell) == "number" then
        local s = spells[spell]
        if s then return s[1], "", s[2] end
        return nil
    end
    for id, s in pairs(spells) do if s[1] == spell then return s[1], "", s[2] end end
end
local book = { "Power Word: Shield", "Penance", "Renew", "Dispel Magic", "Inner Fire" }
function GetNumSpellTabs() return 1 end
function GetSpellTabInfo() return "General", "", 0, #book end
function GetSpellName(i, bookType) if bookType == "pet" then return nil end return book[i] end
function GetSpellTexture() return "Interface\\Icons\\Book" end
function IsPassiveSpell() return false end
function HasPetSpells() return nil end
local cooldowns = {}
function GetSpellCooldown(name) local cd = cooldowns[name] or { 0, 0, 1 } return cd[1], cd[2], cd[3] end
function IsUsableSpell() return 1, nil end
local auras = { player = { HELPFUL = {}, HARMFUL = {} }, target = { HELPFUL = {}, HARMFUL = {} },
    raid1 = { HELPFUL = {}, HARMFUL = {} }, raid2 = { HELPFUL = {}, HARMFUL = {} }, raid3 = { HELPFUL = {}, HARMFUL = {} } }
function UnitAura(unit, index, filter)
    local kind = filter and filter:match("HARMFUL") and "HARMFUL" or "HELPFUL"
    local list = auras[unit] and auras[unit][kind] or {}
    local a = list[index]
    if not a then return nil end
    return a.name, "", a.icon, a.count or 0, a.type, a.duration or 0, a.expiration or 0, a.caster, nil, nil, a.id
end
function GetTotemInfo() return false end
function GetWeaponEnchantInfo() return nil end
function GetInventoryItemID() return nil end

local events = {}
methods.RegisterEvent = function(self, event) events[event] = events[event] or {}; events[event][self] = true end
methods.UnregisterEvent = function(self, event) if events[event] then events[event][self] = nil end end
local function fire(event, ...)
    local list = {}
    for frame in pairs(events[event] or {}) do list[#list + 1] = frame end
    for _, frame in ipairs(list) do frame.scripts.OnEvent(frame, event, ...) end
end
local function tick(seconds)
    now = now + (seconds or 0.2)
    for _, object in ipairs(objects) do
        local update = object.scripts and object.scripts.OnUpdate
        if update then update(object, seconds or 0.2) end
    end
end

local ui = {}
local function load(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    for _, keyword in ipairs(forbidden) do assert(not source:find(keyword, 1, true), path .. ": " .. keyword) end
    assert(loadfile(path))("ForeverUI", ui)
end
for _, path in ipairs({ "Core/Config.lua", "Core/Widgets.lua", "Core/OptionsFrame.lua", "Core/Compat.lua" }) do load(path) end
ui.bundledMedia = { font = {}, statusbar = {}, background = {}, border = {} }
for _, path in ipairs({ "Media.lua", "Suite.lua", "RaidFrames.lua", "ClickCast.lua", "CooldownManager.lua",
    "Options/SuiteWidgets.lua", "Options/CooldownManager.lua", "Options/RaidFrames.lua", "Options/ClickCast.lua",
    "Options/Profiles.lua" }) do
    load(path)
end
local Suite, CDM, RF, CC = ui.Suite, ui.CooldownManager, ui.RaidFrames, ui.ClickCast

---------------------------------------------------------------------------------------------------
-- Serializer, base64, export strings
---------------------------------------------------------------------------------------------------
local sample = { a = 1, b = "x:y|z", c = { 1, 2, { deep = true } }, d = false, [5] = 0.25, e = -3 }
local back = Suite.Deserialize(Suite.Serialize(sample))
assert(back.a == 1 and back.b == "x:y|z" and back.c[3].deep == true and back.d == false and back[5] == 0.25 and back.e == -3)
for _, text in ipairs({ "", "a", "ab", "abc", "Привет, мир" }) do assert(Suite.Decode64(Suite.Encode64(text)) == text) end
local encoded = Suite.EncodeString({ hello = "world" })
assert(Suite.DecodeString(encoded).hello == "world")
assert(not Suite.DecodeString(encoded:sub(1, -3) .. "AA"), "damaged strings are rejected")
assert(not Suite.DecodeString("return os.exit()"), "foreign text is rejected")
assert(not Suite.Deserialize("{s1:an1;"), "unterminated tables are rejected")

---------------------------------------------------------------------------------------------------
-- Login: profile with starter groups, spellbook, dispels
---------------------------------------------------------------------------------------------------
ForeverStockUIDB = {}
fire("ADDON_LOADED", "ForeverUI")
fire("PLAYER_LOGIN")
assert(Suite.ready and Suite.ActiveProfileName() == Suite.DEFAULT_PROFILE)
local groups = CDM.Groups()
assert(#groups == 5 and groups[1].name == "Essential Cooldowns" and groups[4].kind == "bars", "starter groups")
assert(Suite.IsKnown(17) and Suite.IsKnown("Penance") and not Suite.IsKnown(60065), "spellbook cache")
assert(Suite.CanDispel("Magic") and not Suite.CanDispel("Disease") and not Suite.CanDispel("Curse"), "priest dispels")
assert(Suite.PrimaryTree() == 2, "primary tree by points")
assert(#Suite.Part("raid").indicators >= 3 and Suite.Part("raid").rfShieldMode == "attached")

---------------------------------------------------------------------------------------------------
-- Cooldown Manager engine
---------------------------------------------------------------------------------------------------
local id = CDM.CreateGroup("Test", "icons")
local group = CDM.Group(id)
group.items = {}
CDM.AddItem(id, "cooldown", 47540)
CDM.AddItem(id, "cooldown", 60065)        -- not learned: hidden
CDM.AddItem(id, "buff", 33151)
CDM.AddItem(id, "missing", 588)
CDM.AddItem(id, "icd", 60065)
group.items[5].duration = 45
local r = {}
cooldowns.Penance = { now - 0.5, 1.5, 1 }  -- GCD only
CDM.Evaluate(group, group.items[1], r, now)
assert(r.show and r.ready and not r.start, "the GCD is filtered")
cooldowns.Penance = { now - 2, 10, 1 }
CDM.Evaluate(group, group.items[1], r, now)
assert(r.show and not r.ready and r.duration == 10 and r.desaturate, "real cooldown")
group.cdShow = "ready"
CDM.Evaluate(group, group.items[1], r, now)
assert(not r.show, "only-ready filter")
group.cdShow = "always"
CDM.Evaluate(group, group.items[2], r, now)
assert(not r.show, "unlearned spells hide")
CDM.Evaluate(group, group.items[3], r, now)
assert(not r.show, "absent buff")
auras.player.HELPFUL[1] = { name = "Surge of Light", icon = "x", count = 2, duration = 10, expiration = now + 5, caster = "player", id = 33151 }
fire("UNIT_AURA", "player")
CDM.Evaluate(group, group.items[3], r, now)
assert(r.show and r.count == 2 and r.expiration == now + 5, "present buff")
CDM.Evaluate(group, group.items[4], r, now)
assert(r.show and r.glow, "missing Inner Fire is shown and glows")
auras.player.HELPFUL[2] = { name = "Inner Fire", icon = "y", caster = "player", id = 588 }
fire("UNIT_AURA", "player")
CDM.Evaluate(group, group.items[4], r, now)
assert(not r.show, "present Inner Fire hides the reminder")
-- ICD from the combat log
fire("PLAYER_LOGIN")
CDM.Evaluate(group, group.items[5], r, now)
assert(r.show and r.ready)
fire("COMBAT_LOG_EVENT_UNFILTERED", now, "SPELL_AURA_APPLIED", "GUID-player", "Tester", 0, "GUID-player", "Tester", 0,
    60065, "Reflection of Torment")
CDM.Evaluate(group, group.items[5], r, now)
assert(not r.ready and r.duration == 45, "ICD starts from the combat log")
-- alerts: sound once when the threshold is reached
group.items[3].stacks, group.items[3].soundStacks = 2, "RaidWarning"
printed.sound = nil
tick(0.2)
assert(printed.sound == "RaidWarning", "stack alert sound")
printed.sound = nil
tick(0.2)
assert(printed.sound == nil, "the alert sound plays once")
-- load conditions
group.load.when = "combat"
assert(not CDM.LoadAllowed(group))
group.load.when, group.load.tree = "always", 3
assert(not CDM.LoadAllowed(group), "talent tree condition")
group.load.tree = 2
assert(CDM.LoadAllowed(group))
-- group operations
local copyId = CDM.DuplicateGroup(id)
assert(CDM.Group(copyId) and #CDM.Group(copyId).items == 5)
CDM.DeleteGroup(copyId)
assert(not CDM.Group(copyId))
local before = #CDM.Groups()
CDM.MoveGroup(id, -1)
assert(CDM.Groups()[before - 1].id == id, "groups reorder")
assert(_G["ForeverStockUICDM" .. id], "each group is its own container")
-- Default positions: icon groups stack under each other without overlapping, bars sit to the left.
tick(0.2)
local tops, seen = {}, {}
for _, g in ipairs(CDM.Groups()) do
    local c = _G["ForeverStockUICDM" .. g.id]
    local point, _, _, x, y = c:GetPoint(1)
    assert(point == "TOP" or point == "TOPRIGHT", "default anchor")
    local key = point .. x .. ":" .. y
    assert(not seen[key], "two groups share one default spot")
    seen[key] = true
    if point == "TOP" then tops[#tops + 1] = { y = y, h = c:GetHeight() } else assert(x < 0, "bars to the left") end
end
for i = 2, #tops do
    assert(tops[i].y <= tops[i - 1].y - tops[i - 1].h, "the next icon group starts below the previous one")
end

---------------------------------------------------------------------------------------------------
-- Click-casting
---------------------------------------------------------------------------------------------------
local attrs, snippet = CC.Plan({
    { key = "BUTTON1", mods = "shift-", action = "spell", value = "Renew" },
    { key = "BUTTON2", mods = "", action = "menu" },
    { key = "MOUSEWHEELUP", mods = "ctrl-", action = "spell", value = "Penance" },
    { key = "F", mods = "alt-", action = "macrotext", value = "/cast [target=mouseover] Renew" },
    { key = "BUTTON3", mods = "", action = "spell", value = "" },   -- incomplete: skipped
})
assert(attrs["shift-type1"] == "spell" and attrs["shift-spell1"] == "Renew" and attrs.type2 == "menu")
assert(attrs["type-fuicc1"] == "spell" and attrs["spell-fuicc1"] == "Penance")
assert(attrs["type-fuicc2"] == "macro" and attrs["macrotext-fuicc2"]:find("mouseover"))
assert(attrs.type3 == nil, "incomplete bindings are skipped")
assert(snippet:find('SetBindingClick%(true, "CTRL%-MOUSEWHEELUP", self, "fuicc1"%)'))
assert(snippet:find('SetBindingClick%(true, "ALT%-F", self, "fuicc2"%)'))

local button = CreateFrame("Button", "CompactRaidFrame1", UIParent)
button.healthBar = CreateFrame("StatusBar", nil, button)
button.healthBar.width, button.healthBar.height = 70, 30
button.attributes.unit = "raid1"
button.attributes.type1 = "target"
button.scripts.OnClick = function() end
fire("RAID_ROSTER_UPDATE")
CC.Add(1, "BUTTON1", "", "spell", "Renew")
assert(button.attributes.type1 == "spell" and button.attributes.spell1 == "Renew", "bindings land on client buttons")
assert(button.wraps and button.wraps.OnEnter and button.wraps.OnLeave, "secure wrappers for wheel and keys")
-- Sticky bindings: one owner at a time, the leaving button forgets itself, and a key that fires
-- with the cursor off the button is cancelled instead of casting on the old unit.
assert(button.wraps.OnEnter:find("HOVER:ClearBindings%(%)") and button.wraps.OnEnter:find("HOVER = self"),
    "entering a button clears the previous owner")
assert(button.wraps.OnLeave:find("self:ClearBindings%(%)") and button.wraps.OnHide == button.wraps.OnLeave,
    "leaving and hiding drop the bindings")
assert(button.wraps.OnClick and button.wraps.OnClick:find("IsUnderMouse") and button.wraps.OnClick:find("return false"),
    "a binding fired off the button is cancelled")
released = {}
CC.ReleaseStale()
assert(released[button], "bindings of a button the cursor left are dropped out of combat")
released, hovering = {}, button
CC.ReleaseStale()
assert(not released[button], "the button under the cursor keeps its bindings")
hovering = nil
button.scripts.OnLeave(button)
assert(released[button], "the plain OnLeave hook drops them too")
combat, released = true, {}
CC.ReleaseStale()
button.scripts.OnLeave(button)
assert(next(released) == nil, "nothing insecure touches bindings in combat")
combat = false
CC.Remove(1, 1)
assert(button.attributes.type1 == "target" and button.attributes.spell1 == nil, "the client default comes back")
combat = true
CC.Add(1, "BUTTON2", "shift-", "spell", "Penance")
assert(button.attributes["shift-type2"] == nil and ui.HasCombatQueue(), "no attribute changes in combat")
combat = false
fire("PLAYER_REGEN_ENABLED")
assert(button.attributes["shift-type2"] == "spell", "applied after combat")
talentGroup = 2
fire("ACTIVE_TALENT_GROUP_CHANGED")
tick(0.1)
assert(button.attributes["shift-type2"] == nil, "the second talent spec has its own set")
talentGroup = 1
fire("ACTIVE_TALENT_GROUP_CHANGED")
tick(0.1)
assert(button.attributes["shift-type2"] == "spell")

-- Hint panel: key — icon — name of the active set
local hints = CC.hints
local hintCfg = CC.Data().hints
hintCfg.show = "group"
CC.RefreshHints()
assert(not hints.shown, "solo: the panel waits for a group")
hintCfg.show = "always"
CC.RefreshHints()
assert(hints.shown and hints.rows[1].shown, "bindings are listed")
assert(hints.rows[1].key.text == "Shift+ПКМ" and hints.rows[1].name.text == "Penance"
    and hints.rows[1].icon.texture == "Interface\\Icons\\Penance", "combination, icon and spell name")
hintCfg.show = "hover"
CC.RefreshHints()
assert(not hints.shown)
CC.SetHovered(true)
assert(hints.shown, "shown while a unit frame is hovered")
CC.SetHovered(false)
assert(not hints.shown)
hintCfg.show = "always"
hintCfg.alpha = 0.4
CC.RefreshHints()
assert(hints.alpha == 0.4, "panel opacity")
SlashCmdList.FOREVERUIKEYS("")
assert(not hintCfg.enabled and not hints.shown, "/fuikeys turns the hints off")
ForeverStockUI_ToggleKeyHints()
assert(hintCfg.enabled and hints.shown, "the key binding turns them back on")
SlashCmdList.FOREVERUIKEYS("off")
assert(not hintCfg.enabled)
SlashCmdList.FOREVERUIKEYS("on")
hintCfg.show = "group"

---------------------------------------------------------------------------------------------------
-- Raid frames
---------------------------------------------------------------------------------------------------
local deco
RF.EachFrame(function(frame, d) if frame == button then deco = d end end)
assert(deco, "the client button is decorated")
assert(button.healthBar.barTexture and deco.layer.level > button.level, "Forever texture, click-through layer above")
local settings = Suite.Part("raid")
-- Own name text, hover highlight and target border
tick(0.05)
assert(deco.name.shown and deco.name.text == "Tester", "own name text")
settings.rfNameMaxLetters = 3
RF.Apply()
tick(0.05)
assert(deco.name.text == "Tes", "the name is cut to the letter limit")
assert(RF.CutName("Привет", 3) == "При", "whole UTF-8 letters")
settings.rfNameMaxLetters, settings.rfNameCustom = 0, false
RF.Apply()
tick(0.05)
assert(not deco.name.shown, "the client name comes back")
settings.rfNameCustom = true
RF.Apply()
tick(0.05)
button.scripts.OnEnter(button)
assert(deco.hoverEdge.shown and deco.hoverFill.shown, "hover highlight")
settings.rfHoverStyle = "border"
RF.Apply()
assert(deco.hoverEdge.shown and not deco.hoverFill.shown, "border only")
settings.rfHoverStyle = "both"
button.scripts.OnLeave(button)
assert(not deco.hoverEdge.shown and not deco.hoverFill.shown, "the highlight leaves with the cursor")
button.scripts.OnEnter(button)
tick(0.6)
assert(not deco.hoverEdge.shown, "a highlight whose OnLeave was lost is swept away")
assert(not deco.target.shown, "no target border on a frame that is not the target")
do
    local realIsUnit = UnitIsUnit
    function UnitIsUnit(a, b) return (a == "raid1" and b == "target") or realIsUnit(a, b) end
    fire("PLAYER_TARGET_CHANGED")
    tick(0.05)
    assert(deco.target.shown and deco.target.borderColor[1] == 1 and deco.target.borderColor[2] == 0.82,
        "target border in the chosen colour")
    settings.rfTarget = false
    RF.Apply()
    tick(0.05)
    assert(not deco.target.shown, "the target border can be turned off")
    settings.rfTarget = true
    UnitIsUnit = realIsUnit
    fire("PLAYER_TARGET_CHANGED")
    tick(0.05)
    assert(not deco.target.shown, "the border follows the target")
end
RF.DrawBars(deco, 0.6, 0.1, 0.2)
assert(deco.shield.shown and math.abs(deco.shield.width - 70 * 0.2) < 0.01 and deco.shield.points[1][4] == 70 * 0.7,
    "attached shield starts after health and heals")
RF.DrawBars(deco, 0.9, 0, 0.3)
assert(math.abs(deco.shield.width - 7) < 0.01, "attached shield is clipped at the bar end")
settings.rfShieldMode = "overlay"
RF.DrawBars(deco, 0.9, 0, 0.3)
assert(math.abs(deco.shield.width - 21) < 0.01 and math.abs(deco.shield.points[1][4] - 49) < 0.01, "overflow overlays")
settings.rfShieldMode, settings.rfShieldHeight = "reverse", 3
RF.DrawBars(deco, 0.5, 0, 0.25)
assert(deco.shield.height == 3 and deco.shield.points[1][1] == "BOTTOMLEFT" and math.abs(deco.shield.points[1][4] - 52.5) < 0.01)
settings.rfShield = false
RF.DrawBars(deco, 0.5, 0, 0.25)
assert(not deco.shield.shown, "shield line off")
settings.rfShield, settings.rfShieldMode, settings.rfShieldHeight = true, "attached", 0
-- dispel: magic is the priest's, the poison is not
local magic = { name = "Frost Nova", icon = "f", type = "Magic", duration = 8, expiration = now + 4 }
local poison = { name = "Poison", icon = "p", type = "Poison", duration = 8, expiration = now + 4 }
RF.DrawAuras(deco, {}, { poison, magic }, now)
assert(deco.dispelOutline.shown and deco.dispelOutline.color[3] == 1, "magic outline in blue")
assert(deco.debuffs[1].texture.texture == "f", "dispellable debuffs come first")
RF.DrawAuras(deco, {}, { poison }, now)
assert(not deco.dispelOutline.shown, "what the player cannot dispel is not highlighted")
-- indicators claim their aura and leave the buff row
auras.raid1.HELPFUL[1] = { name = "Renew", icon = "r", duration = 15, expiration = now + 10, caster = "player", id = 139 }
deco.auraDirty = true
RF.MarkDirty()
tick(0.05)
local renewIndicator
for _, widget in pairs(deco.indicators) do if widget.shown and widget.stamp and widget.stamp.name == "Renew" then renewIndicator = widget end end
assert(renewIndicator and renewIndicator.cooldown.cd, "Renew indicator with its duration spiral")
assert(not (deco.buffs[1] and deco.buffs[1].shown), "the indicated Renew is not drawn twice")
-- Hide the client auras so they do not catch clicks
button.buffFrames = { CreateFrame("Frame", nil, button) }
RF.Apply()
assert(button.buffFrames[1].alpha == 0, "client aura icons are hidden")

-- One shield on one ally must not appear on the other frames.
local others = {}
for i = 2, 3 do
    local frame = CreateFrame("Button", "CompactRaidFrame" .. i, UIParent)
    frame.healthBar = CreateFrame("StatusBar", nil, frame)
    frame.healthBar.width, frame.healthBar.height = 70, 30
    frame.attributes.unit = "raid" .. i
    others[i] = frame
end
fire("RAID_ROSTER_UPDATE")
auras.raid2.HELPFUL[1] = { name = "Power Word: Shield", icon = "s", duration = 30, expiration = now + 25, caster = "player", id = 17 }
fire("UNIT_AURA", "raid2")
tick(0.05)
local function shieldShown(frame)
    local found
    RF.EachFrame(function(f, d)
        if f == frame then
            for _, widget in pairs(d.indicators) do
                if widget.shown and widget.stamp and widget.stamp.name == "Power Word: Shield" then found = true end
            end
            for _, icon in ipairs(d.buffs) do if icon.shown and icon.texture.texture == "s" then found = true end end
        end
    end)
    return found
end
assert(shieldShown(others[2]), "the shielded ally shows the shield")
assert(not shieldShown(others[3]) and not shieldShown(button), "other allies do not")
fire("UNIT_AURA", "raid3")
fire("UNIT_AURA", "raid1")
tick(0.05)
assert(not shieldShown(others[3]) and not shieldShown(button), "not even after their own updates")
auras.raid2.HELPFUL[1] = nil
fire("UNIT_AURA", "raid2")
tick(0.05)
assert(not shieldShown(others[2]), "the shield disappears when it fades")
-- a recycled button that now shows another unit never keeps the old unit's auras
auras.raid2.HELPFUL[1] = { name = "Power Word: Shield", icon = "s", duration = 30, expiration = now + 25, caster = "player", id = 17 }
fire("UNIT_AURA", "raid2")
tick(0.05)
others[2].attributes.unit = "raid3"
others[2].unit, others[2].displayedUnit = "raid2", "raid2"   -- stale Lua fields of the client code
fire("UNIT_AURA", "raid2")
tick(0.05)
tick(0.6)
tick(0.05)
assert(not shieldShown(others[2]), "the recycled frame drops the old shield")
-- The client can report one unit on several buttons while drawing different names on them:
-- the name on the button decides which unit each frame reads.
local realUnitName = UnitName
function UnitName(unit)
    if unit == "player" then return "Tester" end
    if unit == "raid1" or unit == "raid2" or unit == "raid3" then return "N" .. unit end
    return realUnitName(unit)
end
local labelled = { [button] = "Nraid1", [others[2]] = "Nraid2", [others[3]] = "Nraid3-Realm" }
for frame, text in pairs(labelled) do
    frame.name = frame:CreateFontString()
    frame.name:SetText(text)
    frame.attributes.unit = "raid2"
    frame.unit, frame.displayedUnit = "raid2", "raid2"
end
auras.raid2.HELPFUL[1] = { name = "Power Word: Shield", icon = "s", duration = 30, expiration = now + 25, caster = "player", id = 17 }
tick(0.6)
tick(0.05)
fire("UNIT_AURA", "raid2")
tick(0.05)
assert(RF.UnitOf(others[3]) == "raid3" and RF.UnitOf(button) == "raid1", "the unit follows the name on the button")
assert(shieldShown(others[2]), "the shield stays on the shielded ally")
assert(not shieldShown(button) and not shieldShown(others[3]), "and only there, even when the client reports one unit")
UnitName = realUnitName
for frame in pairs(labelled) do frame.name = nil end
-- Renewed Hope from Power Word: Shield lands on the whole party: hidden from the buff icons by default.
for _, frame in ipairs({ button, others[2], others[3] }) do frame.attributes.unit = nil end
button.attributes.unit, others[2].attributes.unit, others[3].attributes.unit = "raid1", "raid2", "raid3"
tick(0.6)
tick(0.05)
for _, unit in ipairs({ "raid1", "raid2", "raid3" }) do
    table.insert(auras[unit].HELPFUL, 1, { name = "Renewed Hope", icon = "hope", duration = 60, expiration = now + 50,
        caster = "player", id = 63944 })
    fire("UNIT_AURA", unit)
end
tick(0.05)
local function hopeShown(frame)
    local found
    RF.EachFrame(function(f, d)
        if f == frame then for _, icon in ipairs(d.buffs) do if icon.shown and icon.texture.texture == "hope" then found = true end end end
    end)
    return found
end
assert(Suite.Part("raid").rfBuffTrack == RF.defaultExclusionText.rfBuffTrack and Suite.Part("raid").rfDebuffHide:match("57724"),
    "the recommended tracked and hidden lists are the defaults")
assert(not hopeShown(button) and not hopeShown(others[2]) and not hopeShown(others[3]), "untracked buffs get no icon")
Suite.Part("raid").rfBuffTrack = "63944"; RF.Apply()
tick(0.05)
assert(hopeShown(button), "a tracked buff is drawn")
Suite.Part("raid").rfBuffFilter = "mine"; RF.Apply()
tick(0.05)
assert(hopeShown(button), "mine only keeps my tracked buff")
Suite.Part("raid").rfBuffTrack = ""; Suite.Part("raid").rfBuffFilter = "all"; RF.Apply()
tick(0.05)
assert(not hopeShown(button), "an empty tracked list draws no buff icons")
Suite.Part("raid").rfBuffTrack = RF.defaultExclusionText.rfBuffTrack; RF.Apply()
for _, unit in ipairs({ "raid1", "raid2", "raid3" }) do
    table.remove(auras[unit].HELPFUL, 1)
    fire("UNIT_AURA", unit)
end
tick(0.05)
button.attributes.unit, others[2].attributes.unit, others[3].attributes.unit = "raid1", "raid2", "raid3"
button.unit, button.displayedUnit, others[2].unit, others[2].displayedUnit, others[3].unit, others[3].displayedUnit = nil, nil, nil, nil, nil, nil
auras.raid2.HELPFUL[1] = nil
fire("UNIT_AURA", "raid2")
tick(0.6)
tick(0.05)

-- Role icons and sorting by role
local roles = { raid1 = "TANK", raid2 = "HEALER", raid3 = "DAMAGER" }
function UnitGroupRolesAssigned(unit)
    local role = roles[unit]
    return role == "TANK", role == "HEALER", role == "DAMAGER"
end
others[2].attributes.unit, others[2].unit, others[2].displayedUnit = "raid2", nil, nil
others[3].attributes.unit = "raid3"
button.roleIcon = CreateFrame("Frame", nil, button)
RF.Apply()
fire("PLAYER_ROLES_ASSIGNED")
tick(0.05)
local function decoOf(frame)
    local found
    RF.EachFrame(function(f, d) if f == frame then found = d end end)
    return found
end
local tankRole = decoOf(button).role
assert(tankRole.shown and tankRole.texture:find("Roles\\Blizzard2_ROLES", 1, true) and tankRole.width == 12, "tank icon")
assert(button.roleIcon.alpha == 0, "the client's role icon is hidden")
assert(decoOf(others[3]).role.shown, "damage dealers have an icon by default")
settings.rfRoleHideDamager = true
RF.Apply()
tick(0.05)
assert(not decoOf(others[3]).role.shown and decoOf(others[2]).role.shown, "the damage dealer icon can be hidden")
settings.rfRoleSet, settings.rfRoleSize, settings.rfRoleAnchor, settings.rfRoleX = "ffxiv", 20, "CENTER", 5
RF.Apply()
tick(0.05)
local healerRole = decoOf(others[2]).role
assert(healerRole.texture:find("FFXIV_HEALER", 1, true) and healerRole.width == 20 and healerRole.points[1][1] == "CENTER"
    and healerRole.points[1][4] == 5, "set, size and position")
settings.rfRoleHideDamager = false
-- sorting: the client's flow container gets a role-aware sort function
local originalSort = function(a, b) return a > b end
CompactRaidFrameContainer = CreateFrame("Frame", "CompactRaidFrameContainer", UIParent)
CompactRaidFrameContainer.flowSortFunc = originalSort
local relaid = 0
function CompactRaidFrameContainer_TryUpdate() relaid = relaid + 1 end
local function sorted(list)
    table.sort(list, CompactRaidFrameContainer.flowSortFunc)
    return table.concat(list, ",")
end
settings.rfRoleSort = true
combat = true
RF.ApplySort()
assert(CompactRaidFrameContainer.flowSortFunc == originalSort, "nothing changes in combat")
combat = false
fire("PLAYER_REGEN_ENABLED")
assert(sorted({ "raid3", "raid2", "raid1" }) == "raid1,raid2,raid3" and relaid >= 1, "tanks, healers, damage")
settings.rfRoleOrder = "HTD"
assert(sorted({ "raid3", "raid1", "raid2" }) == "raid2,raid1,raid3", "healers first")
roles.raid4, roles.raid5 = "DAMAGER", "DAMAGER"
local unitExists = UnitExists
function UnitExists(unit) return unit == "raid4" or unit == "raid5" or unitExists(unit) end
assert(sorted({ "raid4", "raid5", "raid3" }) == "raid5,raid4,raid3", "the client's order inside a role")
settings.rfRoleSort, settings.rfRoleOrder = false, "THD"
RF.ApplySort()
assert(CompactRaidFrameContainer.flowSortFunc == originalSort, "turning it off restores the client's sort")

---------------------------------------------------------------------------------------------------
-- Profiles: copy, switch, spec binding, import/export
---------------------------------------------------------------------------------------------------
assert(Suite.NewProfile("Heal", Suite.ActiveProfileName()))
assert(Suite.SetProfile("Heal") and Suite.ActiveProfileName() == "Heal")
assert(CDM.Group(id), "the copy keeps the groups")
CDM.DeleteGroup(id)
Suite.SetProfile(Suite.DEFAULT_PROFILE)
assert(CDM.Group(id), "profiles are independent")
Suite.SetSpecProfile(2, "Heal")
talentGroup = 2
fire("ACTIVE_TALENT_GROUP_CHANGED")
assert(Suite.ActiveProfileName() == "Heal", "the talent spec switches the profile")
talentGroup = 1
local exported = Suite.Export()
local imported = assert(Suite.Import(exported))
assert(imported:find("Импорт") and Suite.DB().profiles[imported].cdm.groups, "import creates a profile")
assert(not Suite.Import("garbage"), "bad strings do not import")
assert(Suite.RenameProfile(imported, "Shared") and Suite.DB().profiles.Shared)
assert(Suite.DeleteProfile("Shared") and not Suite.DB().profiles.Shared)
-- profiles with the old exclusion list get the recommended tracked list and see anyone's buffs
Suite.Part("raid").rfBuffHide, Suite.Part("raid").rfBuffTrack, Suite.Part("raid").rfBuffFilter = "63944", nil, "mine"
RF.Apply()
assert(Suite.Part("raid").rfBuffHide == nil and Suite.Part("raid").rfBuffTrack == RF.defaultExclusionText.rfBuffTrack
    and Suite.Part("raid").rfBuffFilter == "all", "old profiles move to the tracked list")
-- healer basics: every healer class starts with them, the button adds only what is missing
do
    local names = {}
    for _, entry in ipairs(Suite.Part("raid").indicators) do names[entry.name] = true end
    assert(names["Defensive cooldown"] and names["Healing reduced"] and names["Renew"], "a priest starts with healer basics")
    assert(RF.AddPresets(Suite.Part("raid").indicators, RF.healerIndicators) == 0, "no duplicates")
    assert(RF.IsHidden(false, { id = 999999, name = "Something" }) and not RF.IsHidden(false, { id = 33206, name = "x" }),
        "only tracked buffs are drawn")
    -- an indicator for anyone's saves sees another healer's Pain Suppression even with "mine only" icons
    local index
    for i, entry in ipairs(Suite.Part("raid").indicators) do if entry.name == "Defensive cooldown" then index = i end end
    Suite.Part("raid").rfBuffFilter = "mine"
    RF.Apply()
    table.insert(auras.raid1.HELPFUL, { name = "Pain Suppression", icon = "ps", duration = 8, expiration = now + 6,
        caster = "raid2", id = 33206 })
    fire("UNIT_AURA", "raid1")
    tick(0.05)
    local d
    RF.EachFrame(function(f, dd) if f == button then d = dd end end)
    local widget = d.indicators[index]
    assert(widget and widget.shown and widget.square.texture == "ps", "others' saves reach the indicators")
    -- list order is the layer order: moving an indicator up puts it over the ones below
    local list = Suite.Part("raid").indicators
    local first = d.indicators[1]
    assert(first and first.level > widget.level and widget.cooldown.level == widget.level + 1,
        "the first indicator is drawn above later ones")
    local renewLevel = first.level
    list[1], list[index] = list[index], list[1]
    RF.Apply()
    tick(0.05)
    assert(d.indicators[1].shown and d.indicators[1].square.texture == "ps" and d.indicators[1].level == renewLevel,
        "moved to the top, the save takes the top layer")
    list[1], list[index] = list[index], list[1]
    RF.Apply()
    table.remove(auras.raid1.HELPFUL)
    fire("UNIT_AURA", "raid1")
    Suite.Part("raid").rfBuffFilter = "all"
    RF.Apply()
    tick(0.05)
end
-- hidden debuffs: no icon and no dispel highlight; the rest still shows
do
    local d
    RF.EachFrame(function(f, dd) if f == button then d = dd end end)
    local sated = { name = "Sated", icon = "sated", type = "Magic", duration = 600, expiration = now + 500, id = 57724 }
    local nova = { name = "Frost Nova", icon = "f", type = "Magic", duration = 8, expiration = now + 4, id = 122 }
    Suite.Part("raid").rfDebuffHide = "57724, Frost Nova"
    RF.Apply()
    RF.DrawAuras(d, {}, { sated, nova }, now)
    assert(not d.debuffs[1] or not d.debuffs[1].shown, "hidden debuffs get no icon")
    assert(not d.dispelOutline.shown, "and no dispel highlight")
    Suite.Part("raid").rfDebuffHide = "57724"
    RF.Apply()
    RF.DrawAuras(d, {}, { sated, nova }, now)
    assert(d.debuffs[1].shown and d.debuffs[1].texture.texture == "f" and d.dispelOutline.shown, "the rest still shows")
    assert(RF.IsHidden(true, sated) and not RF.IsHidden(true, nova), "only listed debuffs are hidden")
    Suite.Part("raid").rfDebuffHide = RF.defaultExclusionText.rfDebuffHide
    RF.Apply()
end
local onlyRaid = Suite.DecodeString(Suite.Export({ raid = true }))
assert(onlyRaid.profile.raid and not onlyRaid.profile.cdm, "partial export")

---------------------------------------------------------------------------------------------------
-- Cooldown Manager: class and talent tree presets, restoring defaults
---------------------------------------------------------------------------------------------------
do
    local function presetGroup(key)
        for _, g in ipairs(CDM.Groups()) do if g.preset == key then return g end end
    end
    local function find(g, spell)
        for i, e in ipairs(g.items) do if e.spell == spell then return e, i end end
    end
    local function setTree(tree)
        GetTalentTabInfo = function(i) return ({ "Discipline", "Holy", "Shadow" })[i], "", i == tree and 51 or 0 end
        ui.Fire("SuiteTalentsChanged")
    end
    local r = {}
    local essential = presetGroup("essential")
    assert(essential and essential.name == "Essential Cooldowns", "starting groups are marked")
    local penance, pom = find(essential, 47540), find(essential, 33076)
    assert(penance.class == "PRIEST" and penance.spec == 1 and pom.class == "PRIEST" and pom.spec == 2,
        "default entries carry their class and tree")
    assert(find(presetGroup("utility"), 6346).spec == 0, "common entries are for every tree")
    setTree(2)
    assert(not CDM.EntryActive(penance) and CDM.EntryActive(pom), "holy shows holy entries")
    CDM.Evaluate(essential, penance, r, now)
    assert(not r.show, "entries of another tree are hidden")
    setTree(1)
    assert(select(2, CDM.CurrentSpec()) == 1 and CDM.EntryActive(penance) and not CDM.EntryActive(pom),
        "a talent change switches the set")
    CDM.Evaluate(essential, penance, r, now)
    assert(r.show, "penance shows for discipline")
    setTree(0)
    assert(CDM.EntryActive(penance) and CDM.EntryActive(pom), "without talents every tree is allowed")
    setTree(2)
    assert(not CDM.EntryActive({ kind = "cooldown", spell = 12294, class = "WARRIOR", spec = 0 }), "other classes are hidden")
    essential.load.class = "WARRIOR"
    assert(not CDM.LoadAllowed(essential), "group class condition")
    essential.load.class = "PRIEST"
    assert(CDM.LoadAllowed(essential))
    essential.load.class = ""

    -- every class: three tree names, five groups worth of entries, no entry twice for one tree
    local classes = 0
    for class, preset in pairs(CDM.presets) do
        classes = classes + 1
        assert(#preset.trees == 3, class)
        local total = 0
        for _, def in ipairs(CDM.presetGroups) do
            local common, seen = {}, {}
            local list = CDM.PresetItems(def.key, class)
            for _, e in ipairs(list) do if e.spec == 0 then common[CDM.EntryKey(e)] = true end end
            for _, e in ipairs(list) do
                local key = CDM.EntryKey(e) .. "#" .. e.spec
                assert(not seen[key], class .. " " .. def.key .. " repeats " .. key)
                assert(e.spec == 0 or not common[CDM.EntryKey(e)], class .. " " .. def.key .. " common and tree " .. key)
                seen[key] = true
                assert(type(e.spell) == "number" or e.kind == "missing" or e.kind == "totem", class .. " spell id")
            end
            total = total + #list
        end
        for tree = 1, 3 do
            local essentialCount = 0
            for _, e in ipairs(CDM.PresetItems("essential", class)) do
                if e.spec == tree then essentialCount = essentialCount + 1 end
            end
            assert(essentialCount >= 2, class .. " tree " .. tree .. " has its own cooldowns")
        end
        assert(total > 20, class)
    end
    assert(classes == 10, "all ten classes")

    -- restore deleted groups and entries; the user's own stay
    local count = #CDM.Groups()
    local utilityId, utilityPos = presetGroup("utility").id, nil
    for i, g in ipairs(CDM.Groups()) do if g.id == utilityId then utilityPos = i end end
    local utilityCount = #presetGroup("utility").items
    CDM.DeleteGroup(utilityId)
    local _, pomIndex = find(essential, 33076)
    CDM.RemoveItem(essential.id, pomIndex)
    CDM.AddItem(essential.id, "cooldown", 139)
    local addedGroups, addedItems = CDM.RestoreDefaults("missing")
    assert(addedGroups == 1 and addedItems == 1 + utilityCount, "restore counts")
    assert(#CDM.Groups() == count and CDM.Groups()[utilityPos].preset == "utility", "the group returns to its place")
    local back, backIndex = find(essential, 33076)
    assert(back and back.spec == 2 and backIndex == pomIndex, "the entry returns to its place")
    assert(find(essential, 139), "own entries stay")
    addedGroups, addedItems = CDM.RestoreDefaults("missing")
    assert(addedGroups == 0 and addedItems == 0, "nothing is added twice")
    -- a renamed starting group is still recognised
    essential.name = "Main"
    assert(CDM.RestoreDefaults("missing") == 0)

    -- profiles from before the split: the starting groups are found by name, default entries get tags
    Suite.DB().profiles.Legacy = { cdm = { groups = { [1] = { name = "Essential Cooldowns", kind = "icons",
        items = { { kind = "cooldown", spell = 47540 }, { kind = "cooldown", spell = 139 } } } }, order = { 1 }, nextId = 2 } }
    assert(Suite.SetProfile("Legacy"))
    local legacy = CDM.Groups()[1]
    assert(legacy.preset == "essential" and legacy.items[1].class == "PRIEST" and legacy.items[1].spec == 1,
        "old default entries get their tree")
    assert(legacy.items[2].class == "" and legacy.items[2].spec == 0, "own entries stay for every tree")
    addedGroups = CDM.RestoreDefaults("missing")
    assert(addedGroups == 4 and #CDM.Groups() == 5 and #legacy.items > 10, "restore completes an old profile")
    Suite.SetProfile(Suite.DEFAULT_PROFILE)
    Suite.DeleteProfile("Legacy")

    -- reset: only the starting set
    CDM.RestoreDefaults("all")
    assert(#CDM.Groups() == 5 and not find(presetGroup("essential"), 139) and presetGroup("essential").name == "Essential Cooldowns",
        "reset to defaults")
    GetTalentTabInfo = function(i) return ({ "Discipline", "Holy", "Shadow" })[i], "", i == 2 and 51 or 10 end
    ui.Fire("SuiteTalentsChanged")
end

---------------------------------------------------------------------------------------------------
-- Cooldown Manager: role, categories, display modes, active effect, test mode, per-spec entries
---------------------------------------------------------------------------------------------------
do
    local function presetGroup(key)
        for _, g in ipairs(CDM.Groups()) do if g.preset == key then return g end end
    end
    local r = {}
    assert(CDM.SpecKey() == "PRIEST-2" and CDM.Role() == "HEALER", "holy priest is a healer")
    Suite.Part("cdm").role = "TANK"
    CDM.SettingsChanged()
    assert(CDM.Role() == "TANK", "the chosen role wins")
    Suite.Part("cdm").role = "auto"
    CDM.SettingsChanged()
    assert(CDM.CategoryOf({ spell = 33206 }) == "raid" and CDM.CategoryOf({ spell = 47540 }) == nil
        and CDM.CategoryOf({ spell = 47540, category = "offensive" }) == "offensive", "categories")
    for id in pairs(CDM.categoryById) do assert(type(id) == "number") end
    assert(presetGroup("essential").sort == "role" and presetGroup("buffs").sort == "manual", "cooldown groups sort by role")

    -- what you add belongs to the current spec
    local id = CDM.CreateGroup("Mine", "icons")
    local group = CDM.Group(id)
    local index = CDM.AddItem(id, "cooldown", 47540)
    local penance = group.items[index]
    assert(penance.class == "PRIEST" and penance.spec == 2, "own entries are tagged with the spec")
    CDM.AddItem(id, "cooldown", 17)
    group.items[2].category = "raid"

    -- modes: group visibility and hidden categories
    assert(CDM.ActiveMode() == "full" and CDM.LoadAllowed(presetGroup("utility")))
    assert(CDM.SetMode("minimal") and not CDM.LoadAllowed(presetGroup("utility")) and CDM.LoadAllowed(presetGroup("essential"))
        and not CDM.LoadAllowed(group), "minimal shows the main cooldowns only")
    group.modes = { minimal = true }
    assert(CDM.LoadAllowed(group), "a group may override its mode visibility")
    CDM.Evaluate(group, penance, r, now)
    assert(r.show, "entries without a hidden category stay")
    CDM.Evaluate(group, group.items[2], r, now)
    assert(not r.show, "minimal hides raid cooldowns")
    CDM.SetMode("combat")
    assert(not CDM.LoadAllowed(presetGroup("essential")), "combat mode hides everything out of combat")
    assert(not CDM.SetMode("nonsense"))
    CDM.SetMode("auto")
    local stock = IsInInstance
    IsInInstance = function() return true, "raid" end
    fire("ZONE_CHANGED_NEW_AREA")
    assert(CDM.ActiveMode() == "raid", "auto mode follows the zone")
    IsInInstance = stock
    fire("ZONE_CHANGED_NEW_AREA")
    assert(CDM.ActiveMode() == "full")
    assert(_G.ForeverStockUICDMMode and _G.ForeverStockUICDMMode.shown, "mode button")
    _G.ForeverStockUICDMMode:Click("LeftButton")
    assert(Suite.Part("cdm").mode == "full", "the button steps to the next mode")
    _G.ForeverStockUICDMMode:Click("RightButton")
    assert(Suite.Part("cdm").mode == "auto")

    -- active effect: the spell's own buff takes the icon over
    cooldowns.Penance = { now - 2, 10, 1 }
    auras.player.HELPFUL[3] = { name = "Penance", icon = "p", duration = 6, expiration = now + 4, caster = "player", id = 47540 }
    fire("UNIT_AURA", "player")
    CDM.Evaluate(group, penance, r, now)
    assert(r.active and not r.desaturate and r.expiration == now + 4 and r.duration == 6, "active effect")
    group.showActive = false
    CDM.Evaluate(group, penance, r, now)
    assert(not r.active and r.desaturate and r.duration == 10, "cooldown without the active state")
    group.showActive = true
    auras.player.HELPFUL[3] = nil
    fire("UNIT_AURA", "player")
    cooldowns.Penance = nil

    -- layout: centred rows and the flat border
    group.grow, group.borderStyle, group.perRow = "CENTER", "pixel", 8
    CDM.Rebuild()
    local container = _G["ForeverStockUICDM" .. id]
    assert(container.shown and container.elements[1].pixelBorder and container.elements[1].shown, "pixel border")
    -- a group placed in Edit Mode keeps the box it had there; hidden entries do not shift the visible ones
    CDM.AddItem(id, "cooldown", 60065)        -- not learned: hidden
    CDM.Rebuild()
    assert(container:GetWidth() == 76, "an unplaced group is as wide as its visible icons")
    container.editEntry = { config = { position = { -300, -200 } } }
    CDM.Rebuild()
    assert(container:GetWidth() == 116, "a placed group keeps the Edit Mode box")
    assert(select(4, container.elements[1]:GetPoint(1)) == 20, "visible icons are centred in the box")
    group.grow = "RIGHT"
    CDM.Rebuild()
    assert(select(4, container.elements[1]:GetPoint(1)) == 0, "growth to the right starts at the left edge")
    group.grow = "CENTER"
    container.editEntry = nil

    -- test mode: everything of the spec runs a fake loop, combat ends it
    CDM.SetTest(true)
    tick(0.2)
    assert(CDM.IsTesting() and container.unlocked and container.shown, "test mode unlocks the groups")
    local sawTimer = false
    for _ = 1, 40 do
        tick(0.5)
        if container.elements[1].expiration then sawTimer = true end
    end
    assert(sawTimer, "fake timers run")
    fire("PLAYER_REGEN_DISABLED")
    assert(not CDM.IsTesting(), "combat ends the test")
    fire("PLAYER_REGEN_ENABLED")
    tick(0.2)
    assert(not container.unlocked)

    -- auto-adaptation off: every tree of the class shows
    local discipline = { kind = "cooldown", spell = 47540, class = "PRIEST", spec = 1 }
    assert(not CDM.EntryActive(discipline))
    Suite.Part("cdm").autoAdapt = false
    CDM.SettingsChanged()
    assert(CDM.EntryActive(discipline), "without auto-adaptation trees are not filtered")
    Suite.Part("cdm").autoAdapt = true
    CDM.SettingsChanged()

    -- factory layout of the current spec
    local essential = presetGroup("essential")
    local before = #essential.items
    CDM.AddItem(essential.id, "cooldown", 139)
    assert(#essential.items == before + 1)
    CDM.ResetSpec()
    assert(#essential.items == before and #group.items == 0, "the spec returns to its defaults")
    CDM.DeleteGroup(id)
end

---------------------------------------------------------------------------------------------------
-- Option pages on the real modules
---------------------------------------------------------------------------------------------------
for _, module in ipairs({ "cooldowns", "raidframes", "clickcast", "profiles" }) do
    ui.OpenOptions(module)
    assert(ForeverUIOptions:IsShown(), module)
end
local side = RF.previews[#RF.previews]:GetParent()
assert(#RF.previews >= 3 and side:GetParent() == ForeverUIOptions, "three previews beside the options window")
-- the page holder drives the panel (the real client sends OnHide/OnShow to children; the mock does not)
local holder
local function findHolder(frame)
    for _, child in ipairs(frame.children or {}) do
        if child.previews and child.previews[1] == RF.previews[#RF.previews - 2] then return child end
        local found = findHolder(child)
        if found then return found end
    end
end
holder = findHolder(ForeverUIOptions)
assert(holder, "the raid page keeps its previews")
-- exclusion editors: add by id or name, no duplicates, recommended merge, remove
do
    local function findEditor(frame, key)
        for _, child in ipairs(frame.children or {}) do
            if child["input" .. key] then return child end
            local found = findEditor(child, key)
            if found then return found end
        end
    end
    local editor = findEditor(ForeverUIOptions, "rfDebuffHide")
    assert(editor and findEditor(ForeverUIOptions, "rfBuffTrack"), "the tracked and hidden list editors are built")
    local input = editor.inputrfDebuffHide
    Suite.Part("raid").rfDebuffHide = ""
    input:SetText("139, Renew, Curse of Doom")
    input.scripts.OnEnterPressed(input)
    assert(Suite.Part("raid").rfDebuffHide == "139, Curse of Doom", "added by id or name without duplicates")
    local _, count = RF.defaultExclusionText.rfDebuffHide:gsub(",", ",")
    for _, child in ipairs(editor.children or {}) do
        if child.text and child.text.text == ui.L("Добавить рекомендуемые", "Add recommended") then child.scripts.OnClick(child) end
    end
    local _, after = Suite.Part("raid").rfDebuffHide:gsub(",", ",")
    assert(after == count + 2, "recommended entries are merged once")
    Suite.Part("raid").rfDebuffHide = RF.defaultExclusionText.rfDebuffHide
    editor.refreshrfDebuffHide()
end
holder.scripts.OnHide(holder)
assert(not side:IsShown(), "the side preview hides with the page")
holder.scripts.OnShow(holder)
assert(side:IsShown(), "and shows with it")
-- The three preview frames show the same indicators, buff and debuff icons.
do
    local function signature(preview)
        preview:Refresh()
        local d, parts = preview.deco, {}
        for i, widget in pairs(d.indicators) do
            if widget.shown then parts[#parts + 1] = "i" .. i .. "=" .. tostring(widget.square.texture) end
        end
        table.sort(parts)
        for _, kind in ipairs({ "buffs", "debuffs" }) do
            for i, icon in ipairs(d[kind]) do
                if icon.shown then parts[#parts + 1] = kind .. i .. "=" .. tostring(icon.texture.texture) end
            end
        end
        return table.concat(parts, " ") .. (d.dispelOutline.shown and " dispel" or "")
    end
    local n = #RF.previews
    local first = signature(RF.previews[n - 2])
    assert(first:find("i1=") and first:find("debuffs1=") and first:find("dispel"), "the preview shows indicators, debuffs and dispel")
    assert(signature(RF.previews[n - 1]) == first and signature(RF.previews[n]) == first, "all three previews show the same auras")
end
-- Edited indicators restyle in the preview too (entries change in place).
local renewEntry = Suite.Part("raid").indicators[1]
local oldSize = renewEntry.size
renewEntry.size = 20
RF.Apply()
local resized
for _, preview in ipairs(RF.previews) do
    for _, child in ipairs(preview.children) do
        for _, w in ipairs(child.children or {}) do
            if w.stamp == renewEntry and w.shown then resized = w.width end
        end
    end
end
assert(resized == 20, "the preview indicator follows its new size")
renewEntry.size = oldSize
RF.Apply()
-- Scroll frames repaint after a change and keep their offset.
local pageScroll
local function findScroll(frame)
    for _, child in ipairs(frame.children or {}) do
        if child.ForeverScroll and child.shown and child.contentHeight and child.contentHeight > 500 then return child end
        local found = findScroll(child)
        if found then return found end
    end
end
pageScroll = findScroll(ForeverUIOptions)
pageScroll:SetVerticalScroll(120)
ui.Widgets.Redraw(pageScroll)
tick(0.02)
assert(math.abs(pageScroll:GetVerticalScroll() - 119.5) < 0.01, "the redraw nudges the scroll frame")
tick(0.02)
assert(pageScroll:GetVerticalScroll() == 120, "and puts it back")
ui.SetOption("raidframes", "rfShieldAlpha", 0.5)
assert(Suite.Part("raid").rfShieldAlpha == 0.5, "the raid page writes into the active profile")
CDM.OpenGroup(CDM.Groups()[2].id)
assert(CDM.selectedGroup == CDM.Groups()[2].id, "right click in Edit Mode selects the group")

---------------------------------------------------------------------------------------------------
-- Action bar key binding mode
---------------------------------------------------------------------------------------------------
local bindings, saved = {}, {}
function SetBinding(key, command) bindings[key] = command end
function GetBindingKey(command)
    local keys = {}
    for key, bound in pairs(bindings) do if bound == command then keys[#keys + 1] = key end end
    table.sort(keys)
    return unpack(keys)
end
function GetBindingText(key) return key end
function SaveBindings(set) saved[#saved + 1] = set end
function GetCurrentBindingSet() return 1 end
local shift = false
function IsShiftKeyDown() return shift end
function IsAltKeyDown() return false end
function IsControlKeyDown() return false end
UIErrorsFrame = { AddMessage = function() end }
function HideUIPanel(frame) if frame and frame.Hide then frame:Hide() end end
for i = 1, 12 do CreateFrame("CheckButton", "ActionButton" .. i, UIParent) end
for i = 1, 12 do CreateFrame("CheckButton", "MultiBarBottomLeftButton" .. i, UIParent) end
GameMenuFrame = CreateFrame("Frame", "GameMenuFrame", UIParent)
local menuButtons = {}
function GameMenuFrame_AddButton(name, after) menuButtons[#menuButtons + 1] = { name, after } end
CreateFrame("Button", "ForeverStockUISettingsButton", GameMenuFrame)
load("KeyBinder.lua")
local KB = ui.KeyBinder
assert(menuButtons[1][1] == "ForeverStockUIKeyBindButton" and menuButtons[1][2] == "ForeverStockUISettingsButton",
    "the game menu button sits under ForeverUI")
ForeverStockUIKeyBindButton:Click()
assert(KB.IsActive() and ForeverStockUIKeyBinder:IsShown(), "the menu button opens the mode")
local binder = ForeverStockUIKeyBinderCatcher
ActionButton3.scripts.OnEnter(ActionButton3)
assert(binder:IsShown(), "the catcher covers the hovered slot")
shift = true
binder.scripts.OnKeyDown(binder, "F")
shift = false
assert(bindings["SHIFT-F"] == "ACTIONBUTTON3" and saved[#saved] == 1, "Shift+F is bound and saved")
binder.scripts.OnMouseWheel(binder, 1)
assert(bindings.MOUSEWHEELUP == "ACTIONBUTTON3", "wheel binding")
binder.scripts.OnClick(binder, "MiddleButton")
assert(bindings.BUTTON3 == "ACTIONBUTTON3", "middle mouse button binding")
binder.scripts.OnClick(binder, "LeftButton")
assert(bindings.BUTTON1 == nil, "the left click never binds")
binder.scripts.OnLeave(binder)
MultiBarBottomLeftButton2.scripts.OnEnter(MultiBarBottomLeftButton2)
binder.scripts.OnKeyDown(binder, "F")
assert(bindings.F == "MULTIACTIONBAR1BUTTON2", "bottom left bar command")
ActionButton3.scripts.OnEnter(ActionButton3)
binder.scripts.OnKeyDown(binder, "BACKSPACE")
assert(not GetBindingKey("ACTIONBUTTON3"), "Backspace clears the slot")
combat = true
binder.scripts.OnKeyDown(binder, "G")
assert(bindings.G == nil, "no binding in combat")
fire("PLAYER_REGEN_DISABLED")
combat = false
assert(not KB.IsActive(), "combat closes the mode")
SlashCmdList.FOREVERUIBIND("")
assert(KB.IsActive())
ActionButton1.scripts.OnEnter(ActionButton1)
binder.scripts.OnKeyDown(binder, "ESCAPE")
assert(not KB.IsActive() and not ForeverStockUIKeyBinder:IsShown(), "Esc leaves the mode")

---------------------------------------------------------------------------------------------------
-- Options window: right drag resizes width and height, pages follow the new width
---------------------------------------------------------------------------------------------------
UIParent.width, UIParent.height = 1920, 1080
local cursorX, cursorY, rightDown = 500, 500, false
function GetCursorPosition() return cursorX, cursorY end
function IsMouseButtonDown(button) return button == "RightButton" and rightDown end
ui.OpenOptions("cooldowns")
local window = ForeverUIOptions
local grip
for _, child in ipairs(window.children) do
    if child.kind == "Button" and child.width == 14 and child.scripts.OnMouseDown then grip = child end
end
assert(grip, "the resize grip exists")
local function findPage()
    for _, child in ipairs(window.children) do
        for _, page in ipairs(child.children or {}) do
            if page.builtWidth and page.shown then return page end
        end
    end
end
local before = findPage().builtWidth
rightDown = true
grip.scripts.OnMouseDown(grip, "RightButton")
cursorX, cursorY = 700, 400
window.scripts.OnUpdate(window, 0.02)
assert(window.width == 1060 and window.height == 680, "right is wider, down is taller")
rightDown = false
window.scripts.OnUpdate(window, 0.02)
assert(ui.Settings().optionsSize[1] == 1060 and ui.Settings().optionsSize[2] == 680, "the size is saved")
assert(findPage().builtWidth == before + 200, "the page is laid out again for the new width")
assert(window.scale == 1 or window.scale == (ui.Settings().optionsScale or 100) / 100, "the scale is not touched")
rightDown = true
grip.scripts.OnMouseDown(grip, "RightButton")
cursorX, cursorY = -2000, 3000
window.scripts.OnUpdate(window, 0.02)
assert(window.width == 340 and window.height == 160, "only a technical minimum remains")
rightDown = false
window.scripts.OnUpdate(window, 0.02)

-- Raid frame visibility: client / always / hidden, protected changes wait for the end of combat
do
    local raidSettings = Suite.Part("raid")
    local container = CompactRaidFrameContainer
    CompactPartyFrame = CompactPartyFrame or CreateFrame("Frame", "CompactPartyFrame", UIParent)
    local party = CompactPartyFrame
    container:Hide()
    party:Hide()
    raidSettings.rfPartyShow, raidSettings.rfRaidShow = "always", "client"
    RF.ApplyVisibility()
    assert(party:IsShown() and not container:IsShown(), "party frames always shown outside a raid")
    raidSettings.rfRaidShow = "always"
    RF.ApplyVisibility()
    assert(container:IsShown(), "raid frames always shown")
    container:Hide()
    assert(container:IsShown(), "the client hiding them is undone")
    raidSettings.rfPartyShow, raidSettings.rfRaidShow = "hidden", "hidden"
    RF.ApplyVisibility()
    assert(not party:IsShown() and not container:IsShown(), "both turned off")
    combat = true
    container:Show()
    assert(container:IsShown() and ui.HasCombatQueue(), "no protected hide in combat")
    combat = false
    fire("PLAYER_REGEN_ENABLED")
    assert(not container:IsShown(), "hidden again after combat")
    -- solo: the client party frame hangs on a hidden holder and its first button has no unit
    local holder = CreateFrame("Frame", nil, UIParent)
    holder:Hide()
    party:SetParent(holder)
    local member = CompactPartyFrameMember1 or CreateFrame("Button", "CompactPartyFrameMember1", party)
    member:Hide()
    raidSettings.rfPartyShow, raidSettings.rfRaidShow = "always", "client"
    RF.ApplyVisibility()
    assert(party:IsVisible() and party:GetParent() == UIParent, "a hidden holder does not hide the party frame")
    assert(member:IsShown() and member:GetAttribute("unit") == "player", "solo: the first button shows the player")
    raidSettings.rfPartyShow = "client"
    RF.ApplyVisibility()
    assert(party:GetParent() == holder and not member:IsShown(), "the client's parent and button come back")
    party:SetParent(UIParent)
    raidSettings.rfPartyShow, raidSettings.rfRaidShow = "client", "client"
    RF.ApplyVisibility()
    assert(not container:IsShown() and not party:IsShown(), "the state from before ForeverUI comes back")
    container:Show()
    assert(container:IsShown(), "the client is in charge again")
end

---------------------------------------------------------------------------------------------------
-- Drinking indicator on the raid frames
---------------------------------------------------------------------------------------------------
do
    local d
    RF.EachFrame(function(f, dd) if f == button then d = dd end end)
    tick(0.05)
    local unit = d.unit
    assert(unit and auras[unit], "the decorated button has a mocked unit")
    local inCombat, power = false, 0
    UnitBuff = function(u, i) return UnitAura(u, i, "HELPFUL") end
    UnitAffectingCombat = function() return inCombat end
    UnitPowerType = function() return power end
    UnitMana, UnitManaMax = function() return 42 end, function() return 100 end
    local raid = Suite.Part("raid")
    raid.rfDrink, raid.rfDrinkStyle, raid.rfDrinkManaOnly = true, "text", true
    RF.Apply()
    tick(0.05)
    assert(not d.drink.shown, "no drink, no mug")
    local list = auras[unit].HELPFUL
    local drink = { name = "Питье", icon = "x", duration = 30, expiration = now + 20 }
    list[#list + 1] = drink
    fire("UNIT_AURA", unit)
    tick(0.05)
    assert(d.drink.shown and d.drinkText.text == "Пьёт - - -", "the label shows while drinking")
    raid.rfDrinkStyle = "mana"
    RF.Apply()
    tick(0.05)
    assert(d.drink.shown and d.drinkText.text == "Пьёт 42%", "the label with the mana percent")
    raid.rfDrinkStyle = "text"
    RF.Apply()
    tick(0.05)
    assert(d.drinkText.text == "Пьёт - - -", "back to the plain label")
    inCombat = true
    fire("UNIT_FLAGS", unit)
    tick(0.05)
    assert(not d.drink.shown, "combat hides it at once")
    inCombat = false
    fire("UNIT_FLAGS", unit)
    tick(0.05)
    assert(d.drink.shown)
    power = 1
    fire("UNIT_DISPLAYPOWER", unit)
    tick(0.05)
    assert(not d.drink.shown, "mana users only")
    raid.rfDrinkManaOnly = false
    RF.Apply()
    tick(0.05)
    assert(d.drink.shown, "everyone when the option is off")
    power = 0
    -- matched by spell id when the name is unknown (mage water on another locale)
    drink.name, drink.id = "Unbekannt", 27089
    fire("UNIT_AURA", unit)
    tick(0.05)
    assert(d.drink.shown, "spell id match")
    table.remove(list)
    fire("UNIT_AURA", unit)
    tick(0.05)
    assert(not d.drink.shown, "the buff ends, the mug goes")
    raid.rfDrinkStyle, raid.rfDrinkManaOnly = "text", true
    -- a profile with the old mug defaults moves to the label bottom left
    local old = { rfDrinkStyle = "icon", rfDrinkAnchor = "TOP", rfDrinkX = 0, rfDrinkY = -2 }
    RF.MigrateExclusions(old)
    assert(old.rfDrinkStyle == "text" and old.rfDrinkAnchor == "BOTTOMLEFT" and old.rfDrinkX == 2 and old.rfDrinkY == 2)
    UnitBuff, UnitAffectingCombat, UnitPowerType, UnitMana, UnitManaMax = nil, nil, nil, nil, nil
    RF.Apply()
end

---------------------------------------------------------------------------------------------------
-- Raid anchor: left edge stays put when the width changes; drag handle moves the saved position
---------------------------------------------------------------------------------------------------
do
    local anchor, raid = RF.anchor, Suite.Part("raid")
    assert(RF.LeftPinnedOffset(100, 300, 1000) == -600, "right-corner offset for a left-pinned anchor")
    local x, y = RF.ClampPosition(50, -9999, 200, 100, 1000, 800)
    assert(x == 0 and y == 100 - 800, "clamped inside the screen")
    x = RF.ClampPosition(-5000, 0, 200, 100, 1000, 800)
    assert(x == 200 - 1000)

    local entry = { config = { position = { -700, -50 }, width = 200 } }
    anchor.editEntry = entry
    anchor.GetLeft = function() return 100 end
    UIParent.GetRight = function() return 1000 end
    UIParent.GetTop = function() return 800 end
    anchor:SetWidth(200)
    RF.ResizeAnchor(300, 100)      -- more players: wider, left edge stays at 100
    assert(entry.config.position[1] == -600 and entry.config.position[2] == -50, "grows to the right")
    local point, _, _, px, py = anchor:GetPoint()
    assert(point == "TOPRIGHT" and px == -600 and py == -50)
    RF.ResizeAnchor(150, 100)      -- players left: narrower, left edge still 100
    assert(entry.config.position[1] == -750, "shrinks to the right")
    RF.ResizeAnchor(150.2, 100)
    assert(entry.config.position[1] == -750, "no change below half a pixel")
    assert(entry.config.width == 150.2 and entry.config.height == 100, "the size is saved with the position")
    -- /reload: the anchor still stands at its default place (left, by the chat) with its default size
    -- when the buttons are measured; the saved position must survive that
    entry.config.position, entry.config.width = { -600, -50 }, 300
    anchor.GetLeft = function() return 22 end
    anchor:SetWidth(220)
    RF.ResizeAnchor(300, 100)
    assert(entry.config.position[1] == -600 and entry.config.position[2] == -50, "same size: the saved place stays")
    RF.ResizeAnchor(500, 100)
    assert(entry.config.position[1] == -400, "wider: the left edge of the SAVED place stays (100), not the default one")
    -- a position saved by an older version (no width): the right corner is kept, the width recorded
    entry.config.position, entry.config.width = { -600, -50 }, nil
    RF.ResizeAnchor(250, 100)
    assert(entry.config.position[1] == -600 and entry.config.width == 250, "old saves keep their place")
    -- login: the anchor takes the saved size and place before anything measures it
    entry.config.position, entry.config.width, entry.config.height = { -480, -120 }, 360, 90
    anchor:ClearAllPoints()
    anchor:SetWidth(220)
    RF.RestoreAnchor()
    local rp, rrel, rrp, rx, ry = anchor:GetPoint()
    assert(anchor:GetWidth() == 360 and anchor:GetHeight() == 90 and rp == "TOPRIGHT" and rrel == UIParent
        and rrp == "TOPRIGHT" and rx == -480 and ry == -120, "saved size and place restored at login")
    anchor.GetLeft = function() return 100 end
    entry.config.position, entry.config.width, entry.config.height = nil, nil, nil
    RF.ResizeAnchor(400, 100)
    assert(entry.config.position == nil and anchor:GetWidth() == 400, "no saved position: nothing is written")
    RF.RestoreAnchor()

    -- drag handle
    raid.rfEnabled, raid.rfHandle, raid.rfMoveContainer = true, true, true
    entry.config.position = { -500, -100 }
    cursorX, cursorY = 300, 400
    RF.StartHandleDrag()
    assert(RF.IsHandleDragging(), "drag started")
    cursorX, cursorY = 340, 380
    RF.handle.scripts.OnUpdate(RF.handle)
    assert(entry.config.position[1] == -460 and entry.config.position[2] == -120, "position follows the cursor")
    assert(entry.config.width == anchor:GetWidth() and entry.config.height == anchor:GetHeight(),
        "the drag saves the size with the position")
    local hp, hrel, hrp = RF.handle:GetPoint()
    assert(hp == "BOTTOMLEFT" and hrel == anchor and hrp == "TOPLEFT", "the handle rides on the group while dragging")
    cursorX, cursorY = 9999, -9999
    RF.handle.scripts.OnUpdate(RF.handle)
    assert(entry.config.position[1] == 0 and entry.config.position[2] == 100 - 800, "clamped on screen")
    combat = true
    RF.handle.scripts.OnUpdate(RF.handle)
    assert(not RF.IsHandleDragging(), "combat ends the drag")
    local saved = entry.config.position[1]
    RF.StartHandleDrag()
    assert(not RF.IsHandleDragging() and entry.config.position[1] == saved, "no drag in combat")
    combat = false
    raid.rfHandle = false
    RF.StartHandleDrag()
    assert(not RF.IsHandleDragging(), "handle can be turned off")
    raid.rfHandle = true
end

---------------------------------------------------------------------------------------------------
-- Pets under owners, sample frames, profiles bound to the group type
---------------------------------------------------------------------------------------------------
do
    assert(RF.PetOwner("partypet2") == "party2" and RF.PetOwner("raidpet11") == "raid11" and RF.PetOwner("pet") == "player"
        and RF.PetOwner("party2") == nil and RF.PetOwner(nil) == nil, "pet tokens map to owners")

    -- sample layout: 5 players in a row, pets of players 4 and 5
    local has = { false, false, false, true, true }
    local under = RF.TemplateLayout(has, 5, 100, 40, 22, 2, true)
    assert(under.cells[1][1] == 0 and under.cells[2][1] == 102 and under.cells[5][1] == 408 and under.cells[5][2] == 0)
    assert(#under.pets == 2 and under.pets[1].owner == 4 and under.pets[1].x == under.cells[4][1]
        and under.pets[1].y == -42 and under.pets[2].x == under.cells[5][1], "pets hang under their owners")
    assert(under.width == 508 and under.height == 40 + 2 + 22, "size with the pet row")
    local apart = RF.TemplateLayout(has, 5, 100, 40, 22, 2, false)
    assert(apart.pets[1].x == 0 and apart.pets[2].x == 102 and apart.pets[1].y == -42, "pets in their own row at the end")
    local two = RF.TemplateLayout({ false, false, false, false, false, false }, 5, 100, 40, 22, 2, true)
    assert(two.cells[6][1] == 0 and two.cells[6][2] == -42 and two.height == 82, "second row of players")
    assert(RF.TemplateLayout({}, 5, 100, 40, 22, 2, true).height == 0)

    -- real buttons: owners side by side, the client put the pet at the end of the row
    local raid = Suite.Part("raid")
    raid.rfEnabled, raid.rfPetsUnder = true, true
    local function make(name, unit, left)
        local f = CreateFrame("Button", name, UIParent)
        f.healthBar = CreateFrame("StatusBar", nil, f)
        f.attributes.unit = unit
        f.GetLeft = function() return left end
        f.GetRight = function() return left + 100 end
        f.GetTop = function() return 600 end
        f.GetBottom = function() return 560 end
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left, -100)
        return f
    end
    local owner1 = make("FuiTestOwner1", "raid1", 0)
    local owner2 = make("FuiTestOwner2", "raid2", 102)
    local pet = make("FuiTestPet", "raidpet2", 204)
    for _, frame in ipairs({ owner1, owner2, pet }) do RF.Register(frame) end
    fire("RAID_ROSTER_UPDATE")
    tick(0.05)
    RF.LayoutPets()
    local point, relative, relativePoint, x, y = pet:GetPoint()
    assert(point == "TOPLEFT" and relative == owner2 and relativePoint == "BOTTOMLEFT" and x == 0 and y == -2,
        "the pet is hung under its owner")
    -- off: the client lays it out again (nothing is moved by us)
    local before = pet.points[1]
    raid.rfPetsUnder = false
    RF.LayoutPets()
    assert(pet.points[1] == before, "turned off: no more moves")
    -- vertical layout: nothing is moved
    raid.rfPetsUnder = true
    owner2.GetLeft = function() return 0 end
    owner2.GetTop = function() return 560 end
    pet:ClearAllPoints()
    RF.LayoutPets()
    assert(pet:GetNumPoints() == 0, "vertical layout: the client keeps the pets")
    -- combat: queued, not moved
    owner2.GetLeft = function() return 102 end
    owner2.GetTop = function() return 600 end
    combat = true
    RF.LayoutPets()
    assert(pet:GetNumPoints() == 0 and ui.HasCombatQueue(), "no move in combat")
    combat = false
    fire("PLAYER_REGEN_ENABLED")
    assert(pet:GetNumPoints() == 1 and select(2, pet:GetPoint()) == owner2, "moved after combat")

    -- sample frames take the size of the real buttons
    owner1.width, owner1.height, owner2.width, owner2.height = 165, 62, 165, 62
    pet.width, pet.height = 165, 24
    RF.EachFrame(function(f) if f ~= owner1 and f ~= owner2 and f ~= pet then f.shown = false end end)
    local mw, mh, mpw, mph = RF.TemplateMetrics()
    assert(mw == 165 and mh == 62 and mpw == 165 and mph == 24, "metrics follow the real buttons")
    RF.SetEditKind(nil)
    RF.SetTemplate(true)
    local template = RF.template
    assert(template:IsShown() and RF.templateShown and #template.cells == 5 and #template.pets == 2)
    assert(template.cells[1].shown and not template.cells[6], "five players")
    assert(template.cells[1].width == 165 and template.cells[1].height == 62 and template.pets[1].height == 24,
        "sample cells have the real size")
    owner1.width, owner1.height = 90, 36
    owner2.width, owner2.height = 90, 36
    RF.LayoutTemplate()
    assert(template.cells[1].width == 90 and template.cells[1].height == 36, "a new size gets new cells")
    -- one state per cell: one target, one hovered (none), one drinking, one threat
    do
        local targets, hovered, drinking, threat = 0, 0, 0, 0
        for i = 1, 25 do
            local _, data = RF.TemplateMember("raid25", i)
            if data.target then targets = targets + 1 end
            if data.hover then hovered = hovered + 1 end
            if data.drink then drinking = drinking + 1 end
            if data.threat then threat = threat + 1 end
        end
        assert(targets == 1 and hovered == 0 and drinking == 1 and threat == 1, "each state on one sample cell only")
    end
    RF.editKind = "raid25"
    RF.LayoutTemplate()
    assert(#template.cells == 25 and template.cells[25].shown and #template.pets == 4, "raid of 25 with four pets")
    RF.editKind = nil
    RF.LayoutTemplate()
    assert(template.cells[5].shown and #template.cells == 5 and #template.pets == 2, "party again: its own cells")
    -- vertical client layout: groups become columns, pets a column to the right
    local vert = RF.TemplateLayout({ false, false, false, true, true, false, false, false, false, false },
        5, 100, 40, 22, 2, true, true)
    assert(vert.cells[2][1] == 0 and vert.cells[2][2] == -42 and vert.cells[6][1] == 102 and vert.cells[6][2] == 0,
        "vertical: groups are columns")
    assert(vert.pets[1].x == 204 and vert.pets[1].y == 0 and vert.pets[2].y == -24 and vert.width == 304
        and vert.height == 5 * 42 - 2, "vertical: pets in a column of their own")
    fire("PLAYER_REGEN_DISABLED")
    assert(not template:IsShown() and not RF.templateShown, "combat hides the sample frames")
    assert(RF.ToggleTemplate() and template:IsShown())
    RF.SetTemplate(false)
    assert(not template:IsShown())

    -- profiles bound to the group type
    assert(Suite.NewProfile("Raider", Suite.ActiveProfileName()) and Suite.NewProfile("Dungeon", Suite.ActiveProfileName()))
    Suite.SetSpecProfile(2, "")
    Suite.SetProfile(Suite.DEFAULT_PROFILE)
    Suite.SetGroupProfile("raid10", "Raider")
    Suite.SetGroupProfile("party", "Dungeon")
    assert(Suite.ActiveProfileName() == Suite.DEFAULT_PROFILE, "solo: nothing switches")
    local realRaid, realParty = GetNumRaidMembers, GetNumPartyMembers
    GetNumPartyMembers = function() return 4 end
    fire("PARTY_MEMBERS_CHANGED")
    assert(Suite.ActiveProfileName() == "Dungeon", "a party takes the dungeon profile")
    GetNumRaidMembers = function() return 10 end
    fire("RAID_ROSTER_UPDATE")
    assert(Suite.ActiveProfileName() == "Raider", "a raid takes the raid profile")
    GetNumRaidMembers = function() return 20 end
    fire("RAID_ROSTER_UPDATE")
    assert(Suite.ActiveProfileName() == "Raider" or Suite.ActiveProfileName() == "Dungeon"
        or Suite.ActiveProfileName() == Suite.DEFAULT_PROFILE, "raid 25 without a binding")
    Suite.SetGroupProfile("raid25", "Dungeon")
    assert(Suite.ActiveProfileName() == "Dungeon", "a raid of 20 takes the raid 25 profile")
    Suite.SetGroupProfile("raid25", "")
    GetNumRaidMembers = function() return 10 end
    fire("RAID_ROSTER_UPDATE")
    assert(Suite.ActiveProfileName() == "Raider")
    GetNumRaidMembers = realRaid
    combat = true
    fire("PARTY_MEMBERS_CHANGED")
    assert(Suite.ActiveProfileName() == "Raider" and ui.HasCombatQueue(), "no switch in combat")
    combat = false
    fire("PLAYER_REGEN_ENABLED")
    assert(Suite.ActiveProfileName() == "Dungeon", "after combat the party profile")
    GetNumPartyMembers = realParty
    fire("PARTY_MEMBERS_CHANGED")
    assert(Suite.ActiveProfileName() == Suite.DEFAULT_PROFILE, "leaving the group brings the earlier profile back")
    assert(Suite.RenameProfile("Raider", "Raid25") and Suite.GroupProfile("raid10") == "Raid25", "rename follows the binding")
    assert(Suite.DeleteProfile("Raid25") and Suite.GroupProfile("raid10") == nil, "delete clears the binding")
    -- the old single raid binding counts for both raid sizes
    Suite.CharDB().groupProfiles.raid = Suite.DEFAULT_PROFILE
    assert(Suite.GroupProfile("raid10") == Suite.DEFAULT_PROFILE and Suite.GroupProfile("raid25") == Suite.DEFAULT_PROFILE
        and Suite.CharDB().groupProfiles.raid == nil, "old raid binding migrates")
    Suite.SetGroupProfile("raid10", "")
    Suite.SetGroupProfile("raid25", "")
    Suite.SetGroupProfile("party", "")
    assert(Suite.DeleteProfile("Dungeon"))
end

---------------------------------------------------------------------------------------------------
-- Raid frame settings per group type (party, raid 10, raid 25) and copying between them
---------------------------------------------------------------------------------------------------
do
    local base = Suite.Part("raid")
    base.rfNameSize, base.rfEnabled, base.rfPartyShow = 11, true, "client"
    assert(RF.LiveKind() == "party" and RF.Settings() == base, "solo and party use the base table")
    local r10 = RF.KindSettings("raid10")
    assert(r10.rfNameSize == 11 and type(base.kinds.raid10) == "table", "raid 10 starts as a copy of the party")
    assert(base.kinds.raid10.rfEnabled == nil and base.kinds.raid10.kinds == nil, "shared keys are not copied")
    r10.rfNameSize = 14
    assert(base.rfNameSize == 11 and base.kinds.raid10.rfNameSize == 14, "tuned apart")
    r10.rfPartyShow = "always"
    assert(base.rfPartyShow == "always" and base.kinds.raid10.rfPartyShow == nil, "shared keys go to the base")
    base.rfPartyShow = "client"
    r10.indicators[#r10.indicators + 1] = { name = "Only in raid 10", spell = "139", enabled = true }
    local function has(list, name)
        for _, entry in ipairs(list) do if entry.name == name then return true end end
    end
    assert(not has(base.indicators, "Only in raid 10"), "indicators are per group type too")
    -- the live type follows the raid size
    local realRaid = GetNumRaidMembers
    GetNumRaidMembers = function() return 8 end
    fire("RAID_ROSTER_UPDATE")
    assert(RF.LiveKind() == "raid10" and RF.Settings().rfNameSize == 14, "a raid of 8 uses the raid 10 settings")
    GetNumRaidMembers = function() return 18 end
    fire("RAID_ROSTER_UPDATE")
    assert(RF.LiveKind() == "raid25" and RF.Settings().rfNameSize == 11, "a raid of 18 uses the raid 25 settings")
    -- the options page edits another type: its sample frames show, the real ones fade
    local partyFrame = CompactPartyFrame or CreateFrame("Frame", "CompactPartyFrame", UIParent)
    partyFrame:SetAlpha(1)
    local kindEvents = 0
    ui.RegisterCallback("RaidFramesKindChanged", function() kindEvents = kindEvents + 1 end, "TestKind")
    RF.SetEditKind("raid10")
    assert(RF.ViewKind() == "raid10" and RF.Settings().rfNameSize == 14 and kindEvents == 1)
    assert(RF.templateShown and RF.autoTemplate and #RF.template.cells == 10, "editing another type shows its samples")
    assert(partyFrame:GetAlpha() == 0, "the real frames fade under the samples")
    assert(ui.GetOption("raidframes", "rfNameSize") == 14, "the options page reads the edited type")
    ui.SetOption("raidframes", "rfNameSize", 15)
    assert(base.kinds.raid10.rfNameSize == 15 and base.rfNameSize == 11, "the options page writes the edited type")
    -- copy from: raid 25 takes the raid 10 settings
    RF.SetEditKind("raid25")
    assert(not RF.templateShown or RF.ViewKind() == "raid25")
    assert(RF.CopyKind("raid10", "raid25") and RF.Settings().rfNameSize == 15 and has(RF.Settings().indicators, "Only in raid 10"),
        "copy from raid 10")
    assert(base.kinds.raid25.indicators ~= base.kinds.raid10.indicators, "a copy, not the same table")
    assert(not RF.CopyKind("raid25", "raid25") and not RF.CopyKind("nope", "party"), "bad copies are refused")
    assert(RF.CopyKind("raid10", "party") and base.rfNameSize == 15 and base.rfEnabled == true and type(base.kinds) == "table",
        "copy into the party keeps the shared keys and the other types")
    base.rfNameSize = 11
    RF.SetEditKind(nil)
    assert(RF.ViewKind() == "raid25" and not RF.editKind, "back to the live type")
    assert(not RF.templateShown and partyFrame:GetAlpha() == 1, "the auto samples go, the real frames come back")
    -- profile copies, exports and resets carry the group types
    local text = Suite.Export({ raid = true })
    local name = Suite.Import(text)
    assert(name and Suite.DB().profiles[name].raid.kinds.raid10.rfNameSize == 15, "export keeps the group types")
    Suite.DeleteProfile(name)
    GetNumRaidMembers = realRaid
    fire("RAID_ROSTER_UPDATE")
    base.kinds = nil
end

---------------------------------------------------------------------------------------------------
-- Party frames at login: client code defined late, frames generated after login, the client setup
-- putting its own texture back, and a reset nobody hooks (restored by the sweep)
---------------------------------------------------------------------------------------------------
do
    local CLIENT_BAR = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill"
    local raid = Suite.Part("raid")
    raid.rfEnabled = true
    assert(not RF.hookedGlobals.DefaultCompactUnitFrameSetup, "the mock client has no setup function at login")
    function DefaultCompactUnitFrameSetup(frame) frame.healthBar:SetStatusBarTexture(CLIENT_BAR) end
    function CompactUnitFrame_SetUpFrame(frame, func) func(frame) end
    fire("ADDON_LOADED", "Blizzard_CompactRaidFrames")
    assert(RF.hookedGlobals.DefaultCompactUnitFrameSetup and RF.hookedGlobals.CompactUnitFrame_SetUpFrame,
        "client functions defined after login are hooked")
    fire("PLAYER_ENTERING_WORLD")
    local party = CompactPartyFrame or CreateFrame("Frame", "CompactPartyFrame", UIParent)
    local partyWasShown = party.shown
    party.shown = true
    local function decoOf(frame)
        local found
        RF.EachFrame(function(f, d) if f == frame then found = d end end)
        return found
    end
    local function newMember(name)
        local member = CreateFrame("Button", name, party)
        member.healthBar = CreateFrame("StatusBar", nil, member)
        member.healthBar.width, member.healthBar.height = 70, 30
        member.attributes.unit = "player"
        return member
    end
    local member = newMember("ForeverTestPartyMember1")
    CompactUnitFrame_SetUpFrame(member, DefaultCompactUnitFrameSetup)
    local styled = member.healthBar.barTexture
    assert(decoOf(member) and styled and styled ~= CLIENT_BAR, "a party frame generated after login is styled")
    -- the client frame profile loads later and runs the setup again on the decorated frame
    CompactUnitFrame_SetUpFrame(member, DefaultCompactUnitFrameSetup)
    assert(member.healthBar.barTexture == styled, "the client setup does not leave its own texture")
    DefaultCompactUnitFrameSetup(member)
    assert(member.healthBar.barTexture == styled, "nor does the setup function alone")
    -- a reset through a path that is not hooked: the half-second sweep restyles
    member.healthBar:SetStatusBarTexture(CLIENT_BAR)
    tick(0.6)
    assert(member.healthBar.barTexture == styled, "the sweep puts the ForeverUI texture back")
    -- entering the world in combat: the frame is styled once combat ends
    combat = true
    local late = newMember("ForeverTestPartyMember2")
    CompactUnitFrame_SetUpFrame(late, DefaultCompactUnitFrameSetup)
    assert(not decoOf(late) and late.healthBar.barTexture == CLIENT_BAR, "nothing is decorated in combat")
    combat = false
    fire("PLAYER_REGEN_ENABLED")
    assert(decoOf(late) and late.healthBar.barTexture == styled, "decorated and styled after combat")
    -- the ForeverUI style off: the sweep leaves the client texture alone
    raid.rfEnabled = false
    RF.Apply()
    member.healthBar:SetStatusBarTexture(CLIENT_BAR)
    tick(0.6)
    assert(member.healthBar.barTexture == CLIENT_BAR, "no restyle while the style is off")
    raid.rfEnabled = true
    RF.Apply()
    for _, frame in ipairs({ member, late }) do frame.shown = false end
    party.shown = partyWasShown
end

print(("Suite OK: serializer, export strings, profiles and spec switch, cooldown engine (GCD, buffs, reminders, ICD, "
    .. "alerts, load conditions), click-cast plan and combat queue, raid decoration (shield modes, dispel, indicators, visibility, exclusions), "
    .. "option pages, late party frames at login, action bar key binding, options window resizing, raid anchor left edge and drag handle, pets under owners, sample frames, group type profiles, frame settings per group type and copy; %d frames"):format(#objects))
