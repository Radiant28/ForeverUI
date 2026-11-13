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
fire("RAID_ROSTER_UPDATE")
CC.Add(1, "BUTTON1", "", "spell", "Renew")
assert(button.attributes.type1 == "spell" and button.attributes.spell1 == "Renew", "bindings land on client buttons")
assert(button.wraps and button.wraps.OnEnter and button.wraps.OnLeave, "secure wrappers for wheel and keys")
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
local onlyRaid = Suite.DecodeString(Suite.Export({ raid = true }))
assert(onlyRaid.profile.raid and not onlyRaid.profile.cdm, "partial export")

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
holder.scripts.OnHide(holder)
assert(not side:IsShown(), "the side preview hides with the page")
holder.scripts.OnShow(holder)
assert(side:IsShown(), "and shows with it")
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

print(("Suite OK: serializer, export strings, profiles and spec switch, cooldown engine (GCD, buffs, reminders, ICD, "
    .. "alerts, load conditions), click-cast plan and combat queue, raid decoration (shield modes, dispel, indicators), "
    .. "option pages, action bar key binding, options window resizing; %d frames"):format(#objects))
