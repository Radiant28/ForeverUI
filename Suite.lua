-- ForeverUI combat suite core: profiles shared by the Cooldown Manager, the raid frame extension and
-- click-casting; per-character profile and talent-group binding; a safe string import/export;
-- the spellbook and talent caches; WoW Forever art (icon border, proc glow flipbook) shared by the
-- three modules. WotLK 3.3.5a, Lua 5.1: no bit operators, timers run on OnUpdate.
local addonName, ui = ...
local L = ui.L
local floor, max, min, format = math.floor, math.max, math.min, string.format

local Suite = {}
ui.Suite = Suite

---------------------------------------------------------------------------------------------------
-- WoW Forever art (copied from ForeverTextures into Art/Forever and Media/statusbar)
---------------------------------------------------------------------------------------------------
local ART = "Interface\\AddOns\\ForeverUI\\Art\\Forever\\"
Suite.art = {
    iconFrame = ART .. "Icon-Frame",              -- whiteiconframe.tga, 64x64, white: tinted per state
    fx = ART .. "ActionBar-FX",                   -- uiactionbarfx.tga, 1024x512: proc loop flipbook
    raid = ART .. "RaidFrame-Atlas",              -- raidframe.tga, 256x128: outlines, dispel and role icons
    raidBackground = ART .. "RaidFrame-Background",
    editHighlight = ART .. "EditMode-Highlight",
    editSelected = ART .. "EditMode-Selected",
    white = "Interface\\Buttons\\WHITE8X8",
    bar = "Interface\\AddOns\\ForeverUI\\Media\\statusbar\\Forever-Raid",
    font = STANDARD_TEXT_FONT,
}
-- Pixel rectangles inside RaidFrame-Atlas (256x128).
local raidCells = {
    outline = { 72, 0, 144, 35 },        -- white rounded outline (target / dispel border)
    outlineGold = { 144, 0, 216, 35 },
    Poison = { 187, 38, 206, 59 },
    Curse = { 164, 82, 184, 105 },
    Disease = { 140, 107, 161, 128 },
    Magic = { 163, 107, 184, 128 },
    Bleed = { 143, 84, 158, 105 },
    DAMAGER = { 209, 38, 228, 59 },
    TANK = { 232, 38, 251, 59 },
}
function Suite.RaidCell(texture, cell)
    local c = raidCells[cell]
    if not c then return false end
    texture:SetTexture(Suite.art.raid)
    texture:SetTexCoord(c[1] / 256, c[3] / 256, c[2] / 128, c[4] / 128)
    return true
end

Suite.dispelColors = {
    Magic = { 0.20, 0.60, 1.00 },
    Curse = { 0.60, 0.00, 1.00 },
    Disease = { 0.60, 0.40, 0.00 },
    Poison = { 0.00, 0.60, 0.00 },
}

---------------------------------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------------------------------
local function shown(region, visible)
    if visible then region:Show() else region:Hide() end
end
Suite.Shown = shown

function Suite.FormatTime(seconds)
    if not seconds or seconds <= 0 then return "" end
    if seconds >= 3600 then return format("%dh", floor(seconds / 3600 + 0.5)) end
    if seconds >= 90 then return format("%dm", floor(seconds / 60 + 0.5)) end
    if seconds >= 10 then return format("%d", floor(seconds + 0.5)) end
    return format("%.1f", seconds)
end

function Suite.ShortNumber(value)
    value = value or 0
    local magnitude = math.abs(value)
    if magnitude >= 1000000 then return format("%.1fm", value / 1000000) end
    if magnitude >= 1000 then return format("%.1fk", value / 1000) end
    return tostring(floor(value + 0.5))
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = copy(v) end
    return result
end
Suite.Copy = copy

-- Fills missing keys of target from defaults (deep), keeps what the user set.
local function merge(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then
            target[k] = copy(v)
        elseif type(v) == "table" and type(target[k]) == "table" and v[1] == nil then
            merge(target[k], v)
        end
    end
    return target
end
Suite.Merge = merge

-- "123, Arcane Intellect, 456" -> { 123, "Arcane Intellect", 456 }
function Suite.ParseSpellList(text)
    local list = {}
    if type(text) == "number" then
        list[1] = text
        return list
    end
    for part in tostring(text or ""):gmatch("[^,;]+") do
        part = part:match("^%s*(.-)%s*$")
        if part ~= "" then list[#list + 1] = tonumber(part) or part end
    end
    return list
end

-- Spell name and icon for an id or a name (names that are not spell ids are returned as they are).
function Suite.SpellInfo(spell)
    if type(spell) == "number" then
        local name, _, icon = GetSpellInfo(spell)
        return name, icon
    end
    if type(spell) == "string" and spell ~= "" then
        local name, _, icon = GetSpellInfo(spell)
        return name or spell, icon
    end
end

---------------------------------------------------------------------------------------------------
-- Serializer: tagged text, parsed without loadstring, so an imported string can never run code.
---------------------------------------------------------------------------------------------------
local serialize
local function serializeKey(key)
    if type(key) == "number" or type(key) == "string" then return serialize(key) end
end

serialize = function(value, depth)
    depth = depth or 0
    if depth > 40 then error("table too deep") end
    local kind = type(value)
    if kind == "string" then return "s" .. #value .. ":" .. value end
    if kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then return "n0;" end
        if value == floor(value) and math.abs(value) < 2 ^ 52 then return "n" .. format("%d", value) .. ";" end
        return "n" .. format("%.14g", value) .. ";"
    end
    if kind == "boolean" then return value and "T" or "F" end
    if kind == "table" then
        local parts, keys = { "{" }, {}
        for k in pairs(value) do
            if type(k) == "number" or type(k) == "string" then keys[#keys + 1] = k end
        end
        table.sort(keys, function(a, b)
            if type(a) == type(b) then return a < b end
            return type(a) == "number"
        end)
        for _, k in ipairs(keys) do
            local v = value[k]
            local vt = type(v)
            if vt == "string" or vt == "number" or vt == "boolean" or vt == "table" then
                parts[#parts + 1] = serializeKey(k)
                parts[#parts + 1] = serialize(v, depth + 1)
            end
        end
        parts[#parts + 1] = "}"
        return table.concat(parts)
    end
    return "N"
end
Suite.Serialize = function(value) return serialize(value, 0) end

local function parse(text, pos, depth)
    if depth > 40 then error("too deep") end
    local tag = text:sub(pos, pos)
    if tag == "s" then
        local colon = text:find(":", pos, true)
        local length = colon and tonumber(text:sub(pos + 1, colon - 1))
        if not length or length < 0 then error("bad string") end
        local value = text:sub(colon + 1, colon + length)
        if #value ~= length then error("truncated string") end
        return value, colon + length + 1
    elseif tag == "n" then
        local stop = text:find(";", pos, true)
        local value = stop and tonumber(text:sub(pos + 1, stop - 1))
        if not value then error("bad number") end
        return value, stop + 1
    elseif tag == "T" then
        return true, pos + 1
    elseif tag == "F" then
        return false, pos + 1
    elseif tag == "N" then
        return nil, pos + 1
    elseif tag == "{" then
        local result = {}
        pos = pos + 1
        while text:sub(pos, pos) ~= "}" do
            if pos > #text then error("unterminated table") end
            local key, value
            key, pos = parse(text, pos, depth + 1)
            value, pos = parse(text, pos, depth + 1)
            if key == nil or type(key) == "table" or type(key) == "boolean" then error("bad key") end
            result[key] = value
        end
        return result, pos + 1
    end
    error("unexpected '" .. tag .. "'")
end

function Suite.Deserialize(text)
    if type(text) ~= "string" or text == "" then return nil, "empty" end
    local ok, value, pos = pcall(parse, text, 1, 0)
    if not ok then return nil, value end
    if pos ~= #text + 1 then return nil, "trailing data" end
    return value
end

-- Base64 with arithmetic only (Lua 5.1 has no bit operators).
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local decodeMap = {}
for i = 1, 64 do decodeMap[alphabet:sub(i, i)] = i - 1 end

function Suite.Encode64(data)
    local out = {}
    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1, c2 = floor(n / 262144) % 64, floor(n / 4096) % 64
        local c3, c4 = floor(n / 64) % 64, n % 64
        out[#out + 1] = alphabet:sub(c1 + 1, c1 + 1) .. alphabet:sub(c2 + 1, c2 + 1)
            .. (b and alphabet:sub(c3 + 1, c3 + 1) or "=") .. (c and alphabet:sub(c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end

function Suite.Decode64(text)
    text = (text or ""):gsub("[^%w%+/=]", "")
    if #text % 4 ~= 0 then return nil end
    local out = {}
    for i = 1, #text, 4 do
        local chunk = text:sub(i, i + 3)
        local n, pad = 0, 0
        for j = 1, 4 do
            local ch = chunk:sub(j, j)
            local v = decodeMap[ch]
            if ch == "=" then
                v, pad = 0, pad + 1
            elseif not v then
                return nil
            end
            n = n * 64 + v
        end
        local a, b, c = floor(n / 65536) % 256, floor(n / 256) % 256, n % 256
        out[#out + 1] = string.char(a)
        if pad < 2 then out[#out + 1] = string.char(b) end
        if pad < 1 then out[#out + 1] = string.char(c) end
    end
    return table.concat(out)
end

-- Cheap checksum to reject damaged strings.
local function checksum(text)
    local sum = 0
    for i = 1, #text do sum = (sum * 31 + text:byte(i)) % 16777213 end
    return sum
end

local EXPORT_PREFIX = "!FUI1!"
function Suite.EncodeString(value)
    local body = serialize(value, 0)
    return EXPORT_PREFIX .. Suite.Encode64(format("%d|", checksum(body)) .. body)
end

function Suite.DecodeString(text)
    text = (text or ""):match("^%s*(.-)%s*$")
    if text:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then return nil, L("Неизвестный формат строки.", "Unknown string format.") end
    local raw = Suite.Decode64(text:sub(#EXPORT_PREFIX + 1))
    if not raw then return nil, L("Строка повреждена.", "The string is damaged.") end
    local sum, body = raw:match("^(%d+)|(.*)$")
    if not sum or tonumber(sum) ~= checksum(body) then return nil, L("Строка повреждена.", "The string is damaged.") end
    local value, err = Suite.Deserialize(body)
    if type(value) ~= "table" then return nil, err or L("Пустые данные.", "No data.") end
    return value
end

---------------------------------------------------------------------------------------------------
-- Profiles: ForeverStockUIDB.suite = { profiles = { [name] = profile }, chars = { [char] = {...} } }
-- profile = { cdm = { groups, order, nextId }, raid = { ...option values... }, clicks = { [1], [2], common } }
---------------------------------------------------------------------------------------------------
Suite.DEFAULT_PROFILE = L("Основной", "Default")
local profileBuilders = {}

-- Modules register a function that fills their part of a fresh profile.
function Suite.RegisterProfilePart(key, builder)
    profileBuilders[key] = builder
end

local function suiteDB()
    local settings = ui.Settings()
    if type(settings.suite) ~= "table" then settings.suite = {} end
    local db = settings.suite
    if type(db.profiles) ~= "table" then db.profiles = {} end
    if type(db.chars) ~= "table" then db.chars = {} end
    return db
end
Suite.DB = suiteDB

function Suite.CharKey()
    return (UnitName("player") or "?") .. " - " .. (GetRealmName and GetRealmName() or "?")
end

local function charDB()
    local db = suiteDB()
    local key = Suite.CharKey()
    if type(db.chars[key]) ~= "table" then db.chars[key] = {} end
    local char = db.chars[key]
    if type(char.specProfiles) ~= "table" then char.specProfiles = {} end
    return char
end
Suite.CharDB = charDB

local function fillProfile(profile)
    for key, builder in pairs(profileBuilders) do
        if type(profile[key]) ~= "table" then profile[key] = {} end
        builder(profile[key])
    end
    return profile
end

function Suite.ProfileNames()
    local names = {}
    for name in pairs(suiteDB().profiles) do names[#names + 1] = name end
    table.sort(names)
    return names
end

function Suite.ActiveProfileName()
    local char = charDB()
    local db = suiteDB()
    if type(char.profile) ~= "string" or type(db.profiles[char.profile]) ~= "table" then
        char.profile = Suite.DEFAULT_PROFILE
    end
    return char.profile
end

function Suite.Profile()
    local db = suiteDB()
    local name = Suite.ActiveProfileName()
    if type(db.profiles[name]) ~= "table" then db.profiles[name] = {} end
    return fillProfile(db.profiles[name])
end

-- Part of the active profile: Suite.Part("cdm"), Suite.Part("raid"), Suite.Part("clicks").
function Suite.Part(key)
    local profile = Suite.Profile()
    if type(profile[key]) ~= "table" then
        profile[key] = {}
        if profileBuilders[key] then profileBuilders[key](profile[key]) end
    end
    return profile[key]
end

local function changed()
    ui.Fire("SuiteProfileChanged", Suite.ActiveProfileName())
end

function Suite.SetProfile(name)
    local db = suiteDB()
    if type(name) ~= "string" or name == "" then return false end
    if type(db.profiles[name]) ~= "table" then db.profiles[name] = fillProfile({}) end
    charDB().profile = name
    changed()
    return true
end

function Suite.NewProfile(name, source)
    local db = suiteDB()
    if type(name) ~= "string" or name == "" or db.profiles[name] then return false end
    db.profiles[name] = source and copy(db.profiles[source]) or fillProfile({})
    return true
end

function Suite.CopyProfile(source)
    local db = suiteDB()
    local name = Suite.ActiveProfileName()
    if not db.profiles[source] or source == name then return false end
    db.profiles[name] = fillProfile(copy(db.profiles[source]))
    changed()
    return true
end

function Suite.ResetProfile()
    local db = suiteDB()
    db.profiles[Suite.ActiveProfileName()] = fillProfile({})
    changed()
end

function Suite.RenameProfile(old, new)
    local db = suiteDB()
    if not db.profiles[old] or type(new) ~= "string" or new == "" or db.profiles[new] then return false end
    db.profiles[new], db.profiles[old] = db.profiles[old], nil
    for _, char in pairs(db.chars) do
        if type(char) == "table" then
            if char.profile == old then char.profile = new end
            for group, bound in pairs(char.specProfiles or {}) do
                if bound == old then char.specProfiles[group] = new end
            end
        end
    end
    changed()
    return true
end

function Suite.DeleteProfile(name)
    local db = suiteDB()
    if not db.profiles[name] then return false end
    local count = 0
    for _ in pairs(db.profiles) do count = count + 1 end
    if count <= 1 then return false end
    db.profiles[name] = nil
    for _, char in pairs(db.chars) do
        if type(char) == "table" then
            if char.profile == name then char.profile = nil end
            for group, bound in pairs(char.specProfiles or {}) do
                if bound == name then char.specProfiles[group] = nil end
            end
        end
    end
    if Suite.ActiveProfileName() ~= name then changed() end
    return true
end

-- Profiles bound to talent groups (dual specialization) switch automatically.
function Suite.SpecProfile(group) return charDB().specProfiles[group] end
function Suite.SetSpecProfile(group, name)
    charDB().specProfiles[group] = (name ~= "" and name) or nil
    Suite.CheckSpecProfile()
end

function Suite.Export(parts)
    local profile = Suite.Profile()
    local data = { v = 1, profile = {} }
    for key, value in pairs(profile) do
        if not parts or parts[key] then data.profile[key] = copy(value) end
    end
    return Suite.EncodeString(data)
end

-- Imports into a new profile (or overwrites `target` when given). Returns the profile name.
function Suite.Import(text, target)
    local data, err = Suite.DecodeString(text)
    if not data then return nil, err end
    if type(data.profile) ~= "table" then return nil, L("В строке нет профиля.", "The string holds no profile.") end
    local db = suiteDB()
    local name = target
    if not name or name == "" then
        local base = L("Импорт", "Import")
        name = base
        local i = 2
        while db.profiles[name] do
            name = base .. " " .. i
            i = i + 1
        end
    end
    local profile = fillProfile({})
    for key, value in pairs(data.profile) do
        if type(key) == "string" and type(value) == "table" and profileBuilders[key] then profile[key] = value end
    end
    db.profiles[name] = fillProfile(profile)
    if name == Suite.ActiveProfileName() then changed() end
    return name
end

---------------------------------------------------------------------------------------------------
-- Talents: talent group (dual spec) and primary tree
---------------------------------------------------------------------------------------------------
function Suite.TalentGroup()
    return GetActiveTalentGroup and GetActiveTalentGroup() or 1
end

function Suite.PrimaryTree()
    if not GetNumTalentTabs then return 0 end
    local best, bestPoints = 0, 0
    local group = Suite.TalentGroup()
    for i = 1, GetNumTalentTabs() or 0 do
        local _, _, points = GetTalentTabInfo(i, false, false, group)
        if (points or 0) > bestPoints then best, bestPoints = i, points end
    end
    return best
end

function Suite.TreeNames()
    local names = {}
    for i = 1, (GetNumTalentTabs and GetNumTalentTabs()) or 0 do
        names[i] = GetTalentTabInfo(i) or ("#" .. i)
    end
    return names
end

function Suite.CheckSpecProfile()
    local bound = charDB().specProfiles[Suite.TalentGroup()]
    if bound and suiteDB().profiles[bound] and bound ~= Suite.ActiveProfileName() then
        Suite.SetProfile(bound)
        ui.Print(L("Профиль сменён: ", "Profile switched: ") .. bound)
    end
end

---------------------------------------------------------------------------------------------------
-- Spellbook cache: names the player (and the pet) know; refreshed on SPELLS_CHANGED.
---------------------------------------------------------------------------------------------------
local known, petKnown, spellList = {}, {}, {}
local BOOK = BOOKTYPE_SPELL or "spell"

local function rebuildSpellbook()
    for k in pairs(known) do known[k] = nil end
    for k in pairs(petKnown) do petKnown[k] = nil end
    for i = #spellList, 1, -1 do spellList[i] = nil end
    local seen = {}
    for tab = 1, (GetNumSpellTabs and GetNumSpellTabs()) or 0 do
        local _, _, offset, count = GetSpellTabInfo(tab)
        for index = (offset or 0) + 1, (offset or 0) + (count or 0) do
            local name = GetSpellName(index, BOOK)
            if name then
                known[name] = true
                if not seen[name] and not (IsPassiveSpell and IsPassiveSpell(index, BOOK)) then
                    seen[name] = true
                    spellList[#spellList + 1] = { name = name, icon = GetSpellTexture(index, BOOK) }
                end
            end
        end
    end
    local petCount = HasPetSpells and HasPetSpells()
    for index = 1, petCount or 0 do
        local name = GetSpellName(index, "pet")
        if name then petKnown[name] = true end
    end
    table.sort(spellList, function(a, b) return a.name < b.name end)
    ui.Fire("SuiteSpellsChanged")
end
Suite.RebuildSpellbook = rebuildSpellbook

-- Talent ranks by name for the active talent group (passive talents never reach the spellbook).
local talents = {}
local function rebuildTalents()
    for k in pairs(talents) do talents[k] = nil end
    if not GetNumTalentTabs then return end
    local group = Suite.TalentGroup and Suite.TalentGroup() or 1
    for tab = 1, GetNumTalentTabs() or 0 do
        for index = 1, (GetNumTalents(tab) or 0) do
            local name, _, _, _, rank = GetTalentInfo(tab, index, false, false, group)
            if name and (rank or 0) > 0 then talents[name] = rank end
        end
    end
end
Suite.RebuildTalents = rebuildTalents

function Suite.IsKnown(spell)
    local name = Suite.SpellInfo(spell)
    return name and (known[name] or petKnown[name] or talents[name]) and true or false
end

function Suite.TalentRank(name) return talents[name] or 0 end

function Suite.Spellbook() return spellList end

-- Debuff types the player can remove right now (class spells, talents and the felhunter).
local dispelSpells = {
    PRIEST = { [988] = { "Magic" }, [527] = { "Magic" }, [528] = { "Disease" }, [552] = { "Disease" } },
    PALADIN = { [4987] = { "Magic", "Poison", "Disease" }, [1152] = { "Poison", "Disease" } },
    SHAMAN = { [51886] = { "Curse", "Poison", "Disease" }, [526] = { "Poison", "Disease" } },
    DRUID = { [2782] = { "Curse" }, [8946] = { "Poison" }, [2893] = { "Poison" } },
    MAGE = { [475] = { "Curse" } },
    WARLOCK = { [19505] = { "Magic" } },
}
local canDispel = {}
function Suite.RefreshDispels()
    for k in pairs(canDispel) do canDispel[k] = nil end
    local _, class = UnitClass("player")
    for id, types in pairs(dispelSpells[class] or {}) do
        if Suite.IsKnown(id) then
            for _, kind in ipairs(types) do canDispel[kind] = true end
        end
    end
end
function Suite.CanDispel(kind) return kind and canDispel[kind] or false end

---------------------------------------------------------------------------------------------------
-- Load conditions shared by tracker groups and indicators.
---------------------------------------------------------------------------------------------------
function Suite.ZoneType()
    local inInstance, kind = IsInInstance()
    if not inInstance then return "none" end
    return kind or "none"
end

-- Group role of a unit: "TANK", "HEALER", "DAMAGER" or nil. 3.3.5 UnitGroupRolesAssigned returns three
-- booleans (later clients return a string); the raid main tank assignment counts as a tank.
function Suite.UnitRole(unit)
    if not unit or not UnitExists(unit) then return nil end
    if UnitGroupRolesAssigned then
        local a, b, c = UnitGroupRolesAssigned(unit)
        if type(a) == "string" then
            if a ~= "NONE" and a ~= "" then return a end
        elseif a then
            return "TANK"
        elseif b then
            return "HEALER"
        elseif c then
            return "DAMAGER"
        end
    end
    if GetPartyAssignment and GetPartyAssignment("MAINTANK", unit) then return "TANK" end
    return nil
end

function Suite.GroupType()
    if GetNumRaidMembers() > 0 then return "raid" end
    if GetNumPartyMembers() > 0 then return "party" end
    return "solo"
end

---------------------------------------------------------------------------------------------------
-- Forever icon: icon, white border tinted per state, native cooldown spiral, stacks, timer, glow.
---------------------------------------------------------------------------------------------------
-- Proc loop flipbook of uiactionbarfx (1024x512): 5 x 6 frames. The grid is measured on the art so
-- every gold square sits in the centre of its cell (square centres x 439 + 33.25 n, y 17 + 33.33 n).
local FX = { left = 422.4, top = 0.35, cell = 33.25, cellH = 33.33, cols = 5, frames = 30, fps = 30,
    -- the square fills 28 / 33.25 of a cell: 1.4 x the icon puts the ring just outside its edge
    scale = 1.4 }
local fxCoords = {}
for frame = 0, FX.frames - 1 do
    local col, row = frame % FX.cols, floor(frame / FX.cols)
    fxCoords[frame] = {
        (FX.left + col * FX.cell) / 1024, (FX.left + (col + 1) * FX.cell) / 1024,
        (FX.top + row * FX.cellH) / 512, (FX.top + (row + 1) * FX.cellH) / 512,
    }
end
local glowing = {}
local glowDriver = CreateFrame("Frame")
local glowClock, glowFrame = 0, -1

local function currentCoords()
    return fxCoords[floor(glowClock * FX.fps) % FX.frames]
end

local function glowStep(_, elapsed)
    glowClock = glowClock + elapsed
    local frame = floor(glowClock * FX.fps) % FX.frames
    if frame == glowFrame then return end
    glowFrame = frame
    local c = fxCoords[frame]
    local any = false
    for texture in pairs(glowing) do
        any = true
        texture:SetTexCoord(c[1], c[2], c[3], c[4])
    end
    if not any then glowDriver:SetScript("OnUpdate", nil) end
end

-- Proc highlight: the marching gold square of WoW Forever, one driver for every glow on screen.
-- It lives on its own click-through layer above the cooldown spiral, centred on the owner.
function Suite.SetGlow(owner, on, color)
    local holder = owner.foreverGlow
    if not on then
        if holder and holder:IsShown() then
            holder:Hide()
            glowing[holder.texture] = nil
        end
        return
    end
    if not holder then
        holder = CreateFrame("Frame", nil, owner)
        holder:EnableMouse(false)
        holder:SetPoint("CENTER", owner, "CENTER", 0, 0)
        holder.texture = holder:CreateTexture(nil, "OVERLAY")
        holder.texture:SetAllPoints(holder)
        holder.texture:SetTexture(Suite.art.fx)
        holder.texture:SetBlendMode("ADD")
        holder:Hide()
        owner.foreverGlow = holder
    end
    holder:SetFrameLevel(owner:GetFrameLevel() + 2) -- above the spiral, below stack and timer text
    local size = max(owner:GetWidth(), owner:GetHeight()) * FX.scale
    if holder.size ~= size then
        holder:SetWidth(size)
        holder:SetHeight(size)
        holder.size = size
    end
    color = color or { 1, 1, 1 }
    holder.texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    if not holder:IsShown() then
        local c = currentCoords()
        holder.texture:SetTexCoord(c[1], c[2], c[3], c[4])
        holder:Show()
    end
    glowing[holder.texture] = true
    glowDriver:SetScript("OnUpdate", glowStep)
end

-- Builds an icon frame. opts: size, font, fontSize, timerSize, mouse (false = click-through).
function Suite.CreateIcon(parent, size)
    local icon = CreateFrame("Frame", nil, parent)
    icon:SetWidth(size)
    icon:SetHeight(size)
    icon:EnableMouse(false)
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetPoint("TOPLEFT", 2, -2)
    icon.texture:SetPoint("BOTTOMRIGHT", -2, 2)
    icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon.border = icon:CreateTexture(nil, "OVERLAY")
    icon.border:SetTexture(Suite.art.iconFrame)
    icon.border:SetAllPoints(icon)
    icon.border:SetVertexColor(0.85, 0.72, 0.45)
    icon.cooldown = CreateFrame("Cooldown", nil, icon)
    icon.cooldown:SetPoint("TOPLEFT", 2, -2)
    icon.cooldown:SetPoint("BOTTOMRIGHT", -2, 2)
    icon.cooldown.noCooldownCount = true -- OmniCC and similar: we draw our own numbers
    icon.overlay = CreateFrame("Frame", nil, icon)
    icon.overlay:SetAllPoints(icon)
    icon.overlay:SetFrameLevel(icon.cooldown:GetFrameLevel() + 2)
    icon.count = icon.overlay:CreateFontString(nil, "OVERLAY")
    icon.count:SetFont(Suite.art.font, 11, "OUTLINE")
    icon.count:SetPoint("BOTTOMRIGHT", -1, 2)
    icon.timer = icon.overlay:CreateFontString(nil, "OVERLAY")
    icon.timer:SetFont(Suite.art.font, 13, "OUTLINE")
    icon.timer:SetPoint("CENTER", 0, 0)
    return icon
end

function Suite.SetCooldown(cooldown, start, duration)
    if start and duration and duration > 0 then
        if cooldown.start ~= start or cooldown.duration ~= duration then
            cooldown.start, cooldown.duration = start, duration
            cooldown:SetCooldown(start, duration)
        end
        if not cooldown:IsShown() then cooldown:Show() end
    elseif cooldown.duration then
        cooldown.start, cooldown.duration = nil, nil
        cooldown:Hide()
    end
end

---------------------------------------------------------------------------------------------------
-- Sounds for alerts
---------------------------------------------------------------------------------------------------
Suite.sounds = {
    { "", L("Без звука", "None") },
    { "RaidWarning", L("Рейдовое предупреждение", "Raid warning") },
    { "ReadyCheck", L("Проверка готовности", "Ready check") },
    { "AlarmClockWarning3", L("Будильник", "Alarm") },
    { "MapPing", L("Метка на карте", "Map ping") },
    { "TellMessage", L("Шёпот", "Whisper") },
    { "igQuestListComplete", L("Задание выполнено", "Quest complete") },
    { "LEVELUP", L("Новый уровень", "Level up") },
}
function Suite.SoundItems()
    local items = {}
    for _, entry in ipairs(Suite.sounds) do items[#items + 1] = { entry[1], entry[2] } end
    local registry = LibStub and LibStub("LibSharedMedia-3.0", true)
    for _, name in ipairs(registry and registry:List("sound") or {}) do
        if name ~= "None" then items[#items + 1] = { "lsm:" .. name, name } end
    end
    return items
end
function Suite.PlayAlert(sound)
    if type(sound) ~= "string" or sound == "" then return end
    if sound:sub(1, 4) == "lsm:" then
        local registry = LibStub and LibStub("LibSharedMedia-3.0", true)
        local path = registry and registry:Fetch("sound", sound:sub(5), true)
        if path then PlaySoundFile(path) end
        return
    end
    PlaySound(sound)
end

---------------------------------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------------------------------
local driver = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "UNIT_PET",
    "ACTIVE_TALENT_GROUP_CHANGED", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE" }) do
    driver:RegisterEvent(event)
end
local pending
driver:SetScript("OnEvent", function(self, event, unit)
    if event == "UNIT_PET" and unit ~= "player" then return end
    if event == "PLAYER_LOGIN" then
        Suite.ready = true
        Suite.Profile()
        rebuildTalents()
        rebuildSpellbook()
        Suite.RefreshDispels()
        Suite.CheckSpecProfile()
        ui.Fire("SuiteReady")
        return
    end
    -- Spell and talent events come in bursts: rebuild once on the next frame.
    if not pending then
        pending = true
        self:SetScript("OnUpdate", function(frame)
            frame:SetScript("OnUpdate", nil)
            pending = nil
            rebuildTalents()
            rebuildSpellbook()
            Suite.RefreshDispels()
            ui.Fire("SuiteTalentsChanged")
        end)
    end
    if event == "ACTIVE_TALENT_GROUP_CHANGED" then Suite.CheckSpecProfile() end
end)
