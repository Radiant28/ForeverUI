-- Floating combat text adapted from NiceDamage 2.0.0 by Antigravity.
local _, ui = ...
local CombatText = CreateFrame("Frame", "ForeverUICombatText", UIParent)

local DEFAULTS = {
    enabled = true,
    replace3DFont = true,
    hideBlizzDamage = true,
    hideBlizzHealing = true,

    -- Шрифт и текст
    fontName = "BigNoodleTitling (Overwatch)",
    fontPath = "Interface\\AddOns\\ForeverUI\\Media\\fonts\\BigNoodleTitlingCyr.ttf",
    fontSize = 20,
    critScale = 1.45,
    fontOutline = "OUTLINE", -- "", "OUTLINE", "THICKOUTLINE"
    fontShadow = true,
    shortNumbers = false,
    colorBySchool = true,

    -- Иконки скиллов
    showIcons = true,
    iconSize = 22,
    iconPosition = "LEFT", -- "LEFT" или "RIGHT"
    showSwingIcon = true,

    -- Фильтры (что показывать)
    showOutgoingDamage = true,
    showOutgoingHeal = true,
    showPetDamage = true,
    showIncomingHeal = false,
    showIncomingDamage = false,
    showMisses = true,
    showMana = true,
    onlyOnUnits = false,

    -- Анимация и позиция
    anchorToNameplates = true,
    animStyle = "FOUNTAIN", -- "FOUNTAIN", "VERTICAL", "DIAGONAL"
    duration = 1.35,
    floatHeight = 65,
    fallbackOffsetX = 0,
    fallbackOffsetY = 140,
    nameplateOffsetY = 18,

    -- Цвета
    colorNormal = { 1.00, 1.00, 1.00 },
    colorCrit = { 1.00, 0.85, 0.15 },
    colorHeal = { 0.20, 0.92, 0.30 },
    colorHealCrit = { 0.25, 1.00, 0.35 },
    colorPet = { 1.00, 0.65, 0.20 },
    colorMana = { 0.30, 0.69, 1.00 },
}

local SCHOOL_COLORS = {
    [1]  = { 1.00, 0.92, 0.25 }, -- Physical (Жёлтый / Золотой)
    [2]  = { 1.00, 0.90, 0.50 }, -- Holy (Свет)
    [4]  = { 1.00, 0.45, 0.10 }, -- Fire (Огонь)
    [8]  = { 0.30, 1.00, 0.30 }, -- Nature (Природа)
    [16] = { 0.40, 0.85, 1.00 }, -- Frost (Лёд)
    [32] = { 0.70, 0.40, 1.00 }, -- Shadow (Тьма)
    [64] = { 1.00, 0.55, 1.00 }, -- Arcane (Тайная магия)
}

for bit, color in pairs(SCHOOL_COLORS) do DEFAULTS["colorSchool" .. bit] = color end

local MISS_TRANSLATIONS = {
    MISS = "Промах",
    DODGE = "Уклонение",
    PARRY = "Парирование",
    BLOCK = "Блок",
    RESIST = "Сопротивление",
    ABSORB = "Поглощение",
    IMMUNE = "Невосприимчивость",
    DEFLECT = "Отклонение",
    EVADE = "Мимо",
    REFLECT = "Отражение",
}


local db
local activeFrames, framePool = {}, {}
local stockFont = DAMAGE_TEXT_FONT or STANDARD_TEXT_FONT or [[Fonts\FRIZQT__.TTF]]
local originalFont, originalSize, originalFlags

local function GetConfiguredFontPath()
    return ui.MediaPath("font", db.fontName, true) or db.fontPath or stockFont
end

local function ApplySystemDamageFont()
    local replace = db.enabled and db.replace3DFont
    DAMAGE_TEXT_FONT = replace and GetConfiguredFontPath() or stockFont
    if CombatTextFont and replace then
        if not originalFont then originalFont, originalSize, originalFlags = CombatTextFont:GetFont() end
        CombatTextFont:SetFont(DAMAGE_TEXT_FONT, 24, db.fontOutline)
    elseif CombatTextFont and originalFont then
        CombatTextFont:SetFont(originalFont, originalSize, originalFlags)
    end
    SetCVar("CombatDamage", db.enabled and db.showOutgoingDamage and db.hideBlizzDamage and "0" or "1")
    SetCVar("CombatHealing", db.enabled and db.showOutgoingHeal and db.hideBlizzHealing and "0" or "1")
end

local function FormatAmount(amount)
    if not amount then return "" end
    if db.shortNumbers then
        if amount >= 1000000 then
            return string.format("%.1fM", amount / 1000000)
        elseif amount >= 10000 then
            return string.format("%.1fk", amount / 1000)
        elseif amount >= 1000 then
            return string.format("%.1fk", amount / 1000)
        end
    end
    return tostring(amount)
end

local function Colour(key)
    local c = db[key]
    if type(c) ~= "table" then c = DEFAULTS[key] end
    return c[1], c[2], c[3]
end

local function GetDamageColor(school, isHeal, isCrit, isPet)
    if isHeal then
        if isCrit then
            return Colour("colorHealCrit")
        end
        return Colour("colorHeal")
    end
    if isPet and not db.colorBySchool then
        return Colour("colorPet")
    end
    if db.colorBySchool and school then
        if SCHOOL_COLORS[school] then
            return Colour("colorSchool" .. school)
        end
        -- Комбинированные школы (например Frostfire)
        for bit in pairs(SCHOOL_COLORS) do
            if bit > 1 and math.floor(school / bit) % 2 == 1 then
                return Colour("colorSchool" .. bit)
            end
        end
    end
    if isCrit then
        return Colour("colorCrit")
    end
    return Colour("colorNormal")
end

local function GetSkillIcon(spellId, isSwing, isRange)
    if spellId and spellId > 0 then
        local _, _, icon = GetSpellInfo(spellId)
        if icon then
            return icon
        end
    end
    if isSwing then
        if not db.showSwingIcon then
            return nil
        end
        local weaponTex = GetInventoryItemTexture("player", 16)
        return weaponTex or "Interface\\Icons\\INV_Sword_04"
    end
    if isRange then
        local rangedTex = GetInventoryItemTexture("player", 18)
        return rangedTex or "Interface\\Icons\\INV_Weapon_Bow_07"
    end
    return nil
end

-- ============================================================================
-- Пул фреймов и анимация всплывающего текста с иконкой
-- ============================================================================
-- Two screen zones for text that has no unit to sit on. Both can be moved in Edit Mode.
local ZONE_POINT = "CENTER"
local function CreateZone(name)
    local zone = CreateFrame("Frame", name, UIParent)
    zone:SetSize(150, 44)
    zone.textPoint = ZONE_POINT
    return zone
end
local fallbackAnchor = CreateZone("ForeverUICombatTextOutgoing")
local playerAnchor = CreateZone("ForeverUICombatTextIncoming")

local function PlaceZone(zone, x, y)
    local layout = ui.Settings().editLayout
    local config = type(layout) == "table" and layout[zone:GetName()]
    if type(config) == "table" and config.position then return end -- Edit Mode owns a moved zone
    zone:ClearAllPoints()
    zone:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

local function PlaceZones()
    PlaceZone(fallbackAnchor, db and db.fallbackOffsetX or 0, db and db.fallbackOffsetY or 140)
    PlaceZone(playerAnchor, 0, -90)
end
fallbackAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
playerAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, -90)

local function AcquireSCTFrame()
    local f = table.remove(framePool)
    if not f then
        f = CreateFrame("Frame", nil, UIParent)
        f:SetFrameStrata("HIGH")
        f:SetWidth(200)
        f:SetHeight(40)

        -- Чёрная окантовка иконки
        f.iconBorder = f:CreateTexture(nil, "BACKGROUND")
        f.iconBorder:SetTexture(0, 0, 0, 0.9)

        -- Иконка заклинания
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        -- Текст урона / хила
        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    end
    f:Show()
    return f
end

local function ReleaseSCTFrame(f)
    f:Hide()
    f:ClearAllPoints()
    table.insert(framePool, f)
end

local fountainDir = 1

local function SpawnCombatText(textStr, iconTex, r, g, b, isCrit, destGUID, destName, isIncomingOnPlayer)
    if not db or not db.enabled then return end

    -- Pick the anchor first: with "only on units" text without a unit is dropped.
    local anchorFrame
    local baseOffsetY = 0
    if isIncomingOnPlayer then
        anchorFrame = playerAnchor
    else
        local plate = db.anchorToNameplates and ui.wfn.FindCombatTextAnchor(destGUID, destName)
        if plate then
            anchorFrame = plate
            baseOffsetY = db.nameplateOffsetY or 18
        elseif db.onlyOnUnits then
            return
        else
            anchorFrame = fallbackAnchor
        end
    end

    local f = AcquireSCTFrame()
    local fontPath = GetConfiguredFontPath()
    local baseSize = db.fontSize or 20
    local finalSize = isCrit and math.floor(baseSize * (db.critScale or 1.45) + 0.5) or baseSize
    local outline = db.fontOutline or "OUTLINE"

    local ok = f.text:SetFont(fontPath, finalSize, outline)
    if not ok then
        f.text:SetFont("Fonts\\FRIZQT__.TTF", finalSize, outline)
    end

    if db.fontShadow then
        f.text:SetShadowColor(0, 0, 0, 0.9)
        f.text:SetShadowOffset(1.5, -1.5)
    else
        f.text:SetShadowOffset(0, 0)
    end

    f.text:SetTextColor(r or 1, g or 1, b or 1)
    f.text:SetText(textStr)

    f.icon:ClearAllPoints()
    f.iconBorder:ClearAllPoints()
    f.text:ClearAllPoints()

    local showIcon = db.showIcons and iconTex
    if showIcon then
        local iSize = isCrit and math.floor((db.iconSize or 22) * math.min(db.critScale or 1.35, 1.35) + 0.5) or (db.iconSize or 22)
        f.icon:SetTexture(iconTex)
        f.icon:SetWidth(iSize)
        f.icon:SetHeight(iSize)
        f.icon:Show()

        f.iconBorder:SetPoint("TOPLEFT", f.icon, "TOPLEFT", -1.5, 1.5)
        f.iconBorder:SetPoint("BOTTOMRIGHT", f.icon, "BOTTOMRIGHT", 1.5, -1.5)
        f.iconBorder:Show()

        if db.iconPosition == "RIGHT" then
            f.text:SetPoint("CENTER", f, "CENTER", -(iSize * 0.5 + 2), 0)
            f.icon:SetPoint("LEFT", f.text, "RIGHT", 4, 0)
        else
            f.text:SetPoint("CENTER", f, "CENTER", (iSize * 0.5 + 2), 0)
            f.icon:SetPoint("RIGHT", f.text, "LEFT", -4, 0)
        end
    else
        f.icon:Hide()
        f.iconBorder:Hide()
        f.text:SetPoint("CENTER", f, "CENTER", 0, 0)
    end

    f.anchorFrame = anchorFrame
    f.anchorPoint = anchorFrame.textPoint or "TOP"
    f.zoneScale = anchorFrame.textPoint and anchorFrame:GetScale() or 1
    f.anchorName, f.anchorGUID = anchorFrame.identityName, anchorFrame.identityGUID
    f.elapsed = 0
    f.duration = isCrit and ((db.duration or 1.35) * 1.15) or (db.duration or 1.35)
    f.isCrit = isCrit
    f.baseY = baseOffsetY + math.random(-6, 8)
    f.baseX = math.random(-12, 12)

    fountainDir = -fountainDir
    f.dir = fountainDir
    f.spreadX = math.random(28, 56) * f.dir

    f:SetAlpha(1)
    f:SetScale((isCrit and 1.35 or 1.0) * f.zoneScale)
    f:SetPoint("CENTER", anchorFrame, f.anchorPoint, f.baseX, f.baseY)

    table.insert(activeFrames, f)
    CombatText:SetScript("OnUpdate", CombatText.OnUpdate)
end

function CombatText:OnUpdate(elapsed)
    local count = #activeFrames
    if count == 0 then
        self:SetScript("OnUpdate", nil)
        return
    end

    local floatH = db.floatHeight or 65
    local style = db.animStyle or "FOUNTAIN"

    for i = count, 1, -1 do
        local f = activeFrames[i]
        f.elapsed = f.elapsed + elapsed
        local progress = f.elapsed / f.duration

        if progress >= 1 then
            table.remove(activeFrames, i)
            ReleaseSCTFrame(f)
        else
            -- Эффект "удара" (pop) для критов в начале анимации
            if f.isCrit then
                if progress < 0.12 then
                    local pop = 1.0 + 0.45 * (progress / 0.12)
                    f:SetScale(pop * f.zoneScale)
                elseif progress < 0.25 then
                    local pop = 1.45 - 0.45 * ((progress - 0.12) / 0.13)
                    f:SetScale(math.max(1.0, pop) * f.zoneScale)
                else
                    f:SetScale(f.zoneScale)
                end
            end

            -- Плавное затухание в конце
            if progress > 0.65 then
                local alpha = 1 - ((progress - 0.65) / 0.35)
                f:SetAlpha(math.max(0, alpha))
            else
                f:SetAlpha(1)
            end

            -- Траектория движения
            local dx, dy = f.baseX, f.baseY
            if style == "FOUNTAIN" then
                dx = f.baseX + f.spreadX * progress
                local arc = math.sin(progress * math.pi * 0.85) * floatH
                dy = f.baseY + arc
            elseif style == "DIAGONAL" then
                dx = f.baseX + (f.dir * 38 * progress)
                dy = f.baseY + (floatH * progress)
            else -- VERTICAL
                dy = f.baseY + (floatH * progress)
            end

            local anchor, point = f.anchorFrame, f.anchorPoint
            if not anchor:IsVisible() or anchor.identityName ~= f.anchorName or anchor.identityGUID ~= f.anchorGUID then
                anchor, point = fallbackAnchor, ZONE_POINT
                if db.onlyOnUnits then
                    -- The unit's plate is gone and the user does not want text on the screen.
                    table.remove(activeFrames, i)
                    ReleaseSCTFrame(f)
                    anchor = nil
                end
            end
            if anchor then
                f:ClearAllPoints()
                f:SetPoint("CENTER", anchor, point, dx, dy)
            end
        end
    end
end

-- ============================================================================
-- Обработка COMBAT_LOG_EVENT_UNFILTERED (WotLK 3.3.5a)
-- ============================================================================
local COMBATLOG_OBJECT_AFFILIATION_MINE = COMBATLOG_OBJECT_AFFILIATION_MINE or 0x00000001
local bit_band = bit.band

function CombatText:COMBAT_LOG_EVENT_UNFILTERED(timestamp, eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, ...)
    if not db or not db.enabled then return end

    local playerGUID = UnitGUID("player")
    local petGUID = UnitGUID("pet")
    local isPlayerSource = (sourceGUID == playerGUID)
    local isPetSource = (petGUID and sourceGUID == petGUID) or (sourceFlags and bit_band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0 and not isPlayerSource)
    local isPlayerDest = (destGUID == playerGUID)

    -- 1. ИСХОДЯЩИЙ УРОН (Игрок или Питомец)
    if isPlayerSource or (isPetSource and db.showPetDamage) then
        if db.showOutgoingDamage then
            if eventType == "SWING_DAMAGE" then
                local amount, overkill, school, resisted, blocked, absorbed, critical = ...
                if amount and amount > 0 then
                    local icon = GetSkillIcon(nil, true, false)
                    local r, g, b = GetDamageColor(school or 1, false, critical, isPetSource)
                    local text = FormatAmount(amount)
                    if critical then text = text .. "!" end
                    SpawnCombatText(text, icon, r, g, b, critical, destGUID, destName, false)
                end
                return
            elseif eventType == "RANGE_DAMAGE" or eventType == "SPELL_DAMAGE" or eventType == "SPELL_PERIODIC_DAMAGE" or eventType == "DAMAGE_SHIELD" or eventType == "DAMAGE_SPLIT" then
                local spellId, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed, critical = ...
                if amount and amount > 0 then
                    local icon = GetSkillIcon(spellId, false, eventType == "RANGE_DAMAGE")
                    local r, g, b = GetDamageColor(spellSchool or school or 1, false, critical, isPetSource)
                    local text = FormatAmount(amount)
                    if critical then text = text .. "!" end
                    SpawnCombatText(text, icon, r, g, b, critical, destGUID, destName, false)
                end
                return
            end
        end

        -- ПРОМАХИ / УКЛОНЕНИЯ / ПОГЛОЩЕНИЯ
        if db.showMisses and isPlayerSource then
            if eventType == "SWING_MISSED" then
                local missType, amountMissed = ...
                local label = ui.russian and MISS_TRANSLATIONS[missType] or missType
                if label then
                    local icon = GetSkillIcon(nil, true, false)
                    SpawnCombatText(label, icon, 0.85, 0.85, 0.85, false, destGUID, destName, false)
                end
                return
            elseif eventType == "RANGE_MISSED" or eventType == "SPELL_MISSED" or eventType == "SPELL_PERIODIC_MISSED" then
                local spellId, spellName, spellSchool, missType, amountMissed = ...
                local label = ui.russian and MISS_TRANSLATIONS[missType] or missType
                if label then
                    local icon = GetSkillIcon(spellId, false, eventType == "RANGE_MISSED")
                    SpawnCombatText(label, icon, 0.85, 0.85, 0.85, false, destGUID, destName, false)
                end
                return
            end
        end

        -- 2. ИСХОДЯЩЕЕ ИСЦЕЛЕНИЕ (Игрок)
        if isPlayerSource and db.showOutgoingHeal then
            if eventType == "SPELL_HEAL" or eventType == "SPELL_PERIODIC_HEAL" then
                local spellId, spellName, spellSchool, amount, overhealing, absorbed, critical = ...
                if amount and amount > 0 then
                    local icon = GetSkillIcon(spellId, false, false)
                    local r, g, b = GetDamageColor(spellSchool, true, critical, false)
                    local text = "+" .. FormatAmount(amount)
                    if critical then text = text .. "!" end
                    SpawnCombatText(text, icon, r, g, b, critical, destGUID, destName, isPlayerDest and not db.anchorToNameplates)
                end
                return
            end
        end
    end

    -- Mana restored to the player (powerType 0 is mana).
    if isPlayerDest and db.showMana and (eventType == "SPELL_ENERGIZE" or eventType == "SPELL_PERIODIC_ENERGIZE") then
        local spellId, spellName, spellSchool, amount, powerType = ...
        if powerType == 0 and amount and amount > 0 then
            local r, g, b = Colour("colorMana")
            SpawnCombatText("+" .. FormatAmount(amount), GetSkillIcon(spellId, false, false), r, g, b, false,
                destGUID, destName, true)
        end
        return
    end

    -- 3. ВХОДЯЩЕЕ ИСЦЕЛЕНИЕ / УРОН ПО ИГРОКУ (от других источников)
    if isPlayerDest and not isPlayerSource then
        if db.showIncomingHeal and (eventType == "SPELL_HEAL" or eventType == "SPELL_PERIODIC_HEAL") then
            local spellId, spellName, spellSchool, amount, overhealing, absorbed, critical = ...
            if amount and amount > 0 then
                local icon = GetSkillIcon(spellId, false, false)
                local r, g, b = GetDamageColor(spellSchool, true, critical, false)
                local text = "+" .. FormatAmount(amount)
                SpawnCombatText(text, icon, r, g, b, critical, destGUID, destName, true)
            end
        elseif db.showIncomingDamage and (eventType == "SPELL_DAMAGE" or eventType == "SPELL_PERIODIC_DAMAGE" or eventType == "RANGE_DAMAGE" or eventType == "SWING_DAMAGE") then
            local spellId, amount, critical, spellSchool
            if eventType == "SWING_DAMAGE" then
                amount, _, spellSchool, _, _, _, critical = ...
            else
                spellId, _, spellSchool, amount, _, _, _, _, _, critical = ...
            end
            if amount and amount > 0 then
                local icon = GetSkillIcon(spellId, eventType == "SWING_DAMAGE", false)
                SpawnCombatText("-" .. FormatAmount(amount), icon, 1.0, 0.25, 0.25, critical, destGUID, destName, true)
            end
        end
    end
end

-- ============================================================================
-- Демо-тест урона и исцеления
-- ============================================================================
local TEST_SPELLS = {
    { id = 47540, amount = 8420,  school = 2,  crit = true,  heal = false }, -- Исповедь / Penance
    { id = 48666, amount = 14850, school = 4,  crit = true,  heal = false }, -- Огненная глыба / Pyroblast
    { id = 49998, amount = 6230,  school = 1,  crit = false, heal = false }, -- Удар смерти / Death Strike
    { id = 48441, amount = 9540,  school = 8,  crit = true,  heal = true  }, -- Омоложение / Rejuvenation
    { id = 42897, amount = 11920, school = 16, crit = true,  heal = false }, -- Ледяная стрела / Frostbolt
    { id = 47809, amount = 7310,  school = 32, crit = false, heal = false }, -- Стрела Тьмы / Shadow Bolt
}

local function RunTestBurst()
    local targetGUID = UnitExists("target") and UnitGUID("target") or nil
    local targetName = UnitExists("target") and UnitName("target") or nil
    for i, sample in ipairs(TEST_SPELLS) do
        local _, _, icon = GetSpellInfo(sample.id)
        local r, g, b = GetDamageColor(sample.school, sample.heal, sample.crit, false)
        local txt = (sample.heal and "+" or "") .. FormatAmount(sample.amount) .. (sample.crit and "!" or "")
        SpawnCombatText(txt, icon or "Interface\\Icons\\Spell_Fire_FlameBolt", r, g, b, sample.crit, targetGUID, targetName, false)
    end
    -- Samples for the incoming zone: damage taken and mana restored.
    local r, g, b = Colour("colorMana")
    SpawnCombatText("-1520", "Interface\\Icons\\Spell_Fire_FlameBolt", 1.0, 0.25, 0.25, false, nil, nil, true)
    SpawnCombatText("+3200", select(3, GetSpellInfo(29166)) or "Interface\\Icons\\Spell_Nature_Lightning", r, g, b,
        false, nil, nil, true)
end


local function L(ru, en) return ui.russian and ru or en end
local switches = {
    {"enabled", "Показывать текст боя", "Enable combat text"},
    {"showOutgoingDamage", "Исходящий урон", "Outgoing damage"},
    {"showOutgoingHeal", "Исходящее лечение", "Outgoing healing"},
    {"showPetDamage", "Урон питомца", "Pet damage"},
    {"showIncomingDamage", "Входящий урон", "Incoming damage"},
    {"showIncomingHeal", "Входящее лечение", "Incoming healing"},
    {"showMisses", "Промахи и уклонения", "Misses and dodges"},
    {"showMana", "Восстановление маны", "Mana restored"},
    {"onlyOnUnits", "Только на юнитах (без текста на экране)", "On units only (no screen text)"},
    {"showIcons", "Иконки заклинаний", "Spell icons"},
    {"showSwingIcon", "Иконки автоатак", "Auto-attack icons"},
    {"fontShadow", "Тень текста", "Text shadow"},
    {"shortNumbers", "Сокращать числа", "Abbreviate amounts"},
    {"colorBySchool", "Цвет по школе магии", "Colour by spell school"},
    {"anchorToNameplates", "Текст над неймплейтами", "Anchor text to nameplates"},
    {"replace3DFont", "Шрифт штатных цифр урона", "Change the native damage font"},
    {"hideBlizzDamage", "Скрывать штатные цифры урона", "Hide native damage numbers"},
    {"hideBlizzHealing", "Скрывать штатные цифры лечения", "Hide native healing numbers"},
}
local sliders = {
    {"fontSize", "Размер шрифта", "Font size", 12, 38, 1},
    {"critScale", "Размер критического удара", "Critical hit scale", 1.1, 2.2, 0.05},
    {"iconSize", "Размер иконки", "Icon size", 12, 42, 1},
    {"duration", "Длительность анимации", "Animation duration", 0.6, 2.5, 0.05},
    {"floatHeight", "Высота анимации", "Animation height", 25, 140, 5},
    {"nameplateOffsetY", "Отступ над неймплейтом", "Nameplate offset", -50, 100, 1},
    {"fallbackOffsetX", "Смещение по X без неймплейта", "Screen offset X", -300, 300, 1},
    {"fallbackOffsetY", "Смещение по Y без неймплейта", "Screen offset Y", -200, 350, 1},
}

CombatText:RegisterEvent("PLAYER_LOGIN")
CombatText:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        self:COMBAT_LOG_EVENT_UNFILTERED(...)
        return
    end
    self:UnregisterEvent("PLAYER_LOGIN")
    if IsAddOnLoaded("NiceDamage") then return end

    local settings = ui.Settings()
    if type(settings.combatText) ~= "table" then settings.combatText = {} end
    db = settings.combatText
    for key, value in pairs(DEFAULTS) do
        if type(db[key]) ~= type(value) and not (key == "fontName" and type(db[key]) == "number") then db[key] = value end
    end
    for _, option in ipairs(sliders) do
        local key, v = option[1], db[option[1]]
        db[key] = v == v and math.max(option[4], math.min(option[5], v)) or DEFAULTS[key]
    end
    ApplySystemDamageFont()
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    PlaceZones()
    if ui.RegisterEditFrame then
        ui.RegisterEditFrame(fallbackAnchor, L("Текст боя: исходящий", "Combat text: outgoing"), "combattext")
        ui.RegisterEditFrame(playerAnchor, L("Текст боя: входящий", "Combat text: incoming"), "combattext")
    end

    ui.CombatText.active = true
    SLASH_FOREVERUICOMBAT1 = "/nd"
    SLASH_FOREVERUICOMBAT2 = "/nicedamage"
    SlashCmdList.FOREVERUICOMBAT = function(input)
        if (input or ""):match("^%s*test%s*$") then RunTestBurst(); return end
        ui.OpenOptions("combattext")
    end
end)

ui.CombatText = {
    defaults = DEFAULTS, switches = switches, sliders = sliders, schools = SCHOOL_COLORS,
    Apply = function() if db then ApplySystemDamageFont(); PlaceZones() end end,
    Test = function() if db then RunTestBurst() end end,
}
