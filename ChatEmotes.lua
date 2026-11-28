local _, ui = ...
local L = ui.L

-- Emote medallions above ForeverUI nameplates (2026-11-28).
-- A built-in emote (/laugh, /dance, ...) arrives as CHAT_MSG_TEXT_EMOTE with the sender's name and GUID but no emote
-- token: only the server's text ("Алиса смеется."), taken from the server's own emote table (not in the interface
-- files). The emote is therefore recognised by Russian word stems (EMOTES[i].words, first match wins, the sender's
-- name is cut out first). Texts no stem matches are kept in ForeverStockUIDB.emoteUnknown (UNKNOWN_KEEP, newest
-- first) for extending the dictionary; /fuiemote prints the last events.
--
-- A round bronze medallion (Art/Emotes/Emote-<key>.tga, 64x64, generated in Antigravity and converted by
-- Art/Emotes/convert_emotes.py) pops up above the speaker's plate: on the top-right corner of the speaker's chat
-- bubble while it is drawn (ChatBubbles.lua), otherwise above the name or the aura row. Movement is code, not
-- frames: each emote has a MOTIONS entry (bounce, sway, wave, shake, float, droop, nod, clap, pop, bob, doze),
-- love and kiss let small hearts rise, sleep lets "Z" letters rise. Rotation is done in texture coordinates
-- (3.3.5 has no SetRotation); the art has a transparent margin, so a turned medallion is never cut.
-- Attention design: the motion only lasts DURATION s (pop in, motion, fade out), one medallion per speaker
-- (a new emote replaces the old one), at most MAX_EMOTES on screen; no medallion above your own character (no plate;
-- a fixed screen spot was tried and removed on the user's request, 2026-11-28).
--
-- Setting: emotesEnabled (checkbox on the Skins page). API: ui.ChatEmotes { Apply, Show(name, guid, key), Recognize,
-- Preview(key), Tick(now), Active, Log, EMOTES, MOTIONS }. /fuiemote [test <key> | unknown | clear].

local CE = {}
ui.ChatEmotes = CE

local CreateFrame, GetTime, UnitName = CreateFrame, GetTime, UnitName
local pairs, ipairs, select, type, tostring = pairs, ipairs, select, type, tostring
local abs, sin, cos, exp, max, min, pi = math.abs, math.sin, math.cos, math.exp, math.max, math.min, math.pi

local ART = [[Interface\AddOns\ForeverUI\Art\Emotes\Emote-]]
-- The medallion fills 84% of its 64x64 file (convert_emotes.py): turned up to 20 degrees, the quad's corners sample
-- only the transparent margin (texture coordinates past the edge may wrap in 3.3.5).
local SIZE, ON_BUBBLE = 34, 0.8
local DURATION, FADE_IN, FADE_OUT, POP = 2.8, 0.12, 0.45, 0.3
local MAX_EMOTES, LOG_SIZE, UNKNOWN_KEEP = 8, 10, 30
local PARTICLES = 3
local GAP = 4

-- Stems are lower case UTF-8; verbs come before adjectives and adverbs ("злобно смеется" is a laugh). Stems stop
-- before the person ending ("хлопа", "лику"), so "хлопает" and "хлопаете" both match.
local EMOTES = {
    { key = "laugh", words = { "смеет", "смеёт", "хохоч", "хохот", "хихика" } },
    { key = "cry", words = { "плач", "рыда", "всхлип" } },
    { key = "dance", words = { "танцу", "пляш" } },
    { key = "kiss", words = { "целу", "поцелу" } },
    { key = "wave", words = { "машет", "помаха" } },
    { key = "bow", words = { "кланя", "поклон" } },
    { key = "applaud", words = { "аплодир", "хлопа", "рукоплещ" } },
    { key = "sleep", words = { "засыпа", "спит", "уснул", "дремл" } },
    { key = "thank", words = { "благодар", "спасибо" } },
    { key = "burp", words = { "рыга", "отрыжк", "тошн", "блюёт", "блюет" } },
    { key = "smile", words = { "улыба" } },
    { key = "angry", words = { "злит", "злобн", "гнев", "ярост", "сердит", "негоду" } },
    { key = "surprised", words = { "удивл", "изумл", "поражён", "поражен" } },
    { key = "sad", words = { "груст", "печал", "тоскл", "хандр" } },
    { key = "love", words = { "любит", "любов", "обожа", "влюбл", "нежн" } },
    { key = "cheer", words = { "лику", "радостно", "восторг", "подбадрива" } },
}
CE.EMOTES = EMOTES

-- Motion of each emote; particles: "heart" (the love medallion, small) or "z" (letters).
local MOTIONS = {
    laugh = { kind = "bounce" }, smile = { kind = "bob" }, dance = { kind = "sway" }, cry = { kind = "droop" },
    angry = { kind = "shake" }, kiss = { kind = "float", particles = "heart" }, love = { kind = "float", particles = "heart" },
    wave = { kind = "wave" }, bow = { kind = "nod" }, applaud = { kind = "clap" }, cheer = { kind = "bounce" },
    sleep = { kind = "doze", particles = "z" }, surprised = { kind = "pop" }, thank = { kind = "nod" },
    sad = { kind = "droop" }, burp = { kind = "shake" },
}
CE.MOTIONS = MOTIONS

local function enabled()
    local db = ui.Settings and ui.Settings()
    return not (db and db.emotesEnabled == false)
end

local function platesActive()
    local wfn = ui.wfn
    return wfn and wfn.active and wfn.FindCombatTextAnchor and true or false
end

local function shortName(name)
    if type(name) ~= "string" then return nil end
    return name:match("^[^%-]+") or name
end

-- The emote key of a server emote text, or nil. The sender's name is cut out, so a name never matches a stem.
function CE.Recognize(text, sender)
    if type(text) ~= "string" or text == "" then return nil end
    local plain = text
    if type(sender) == "string" and sender ~= "" then
        local at, stop = plain:find(sender, 1, true)
        while at do
            plain = plain:sub(1, at - 1) .. plain:sub(stop + 1)
            at, stop = plain:find(sender, 1, true)
        end
    end
    plain = plain:lower()
    for _, emote in ipairs(EMOTES) do
        for _, word in ipairs(emote.words) do
            if plain:find(word, 1, true) then return emote.key end
        end
    end
end

---------------------------------------------------------------------------------------------------
-- Motion: offsets (px), angle (radians) and size factor at time t
---------------------------------------------------------------------------------------------------
local TAU = 2 * pi
local function deg(d) return d * pi / 180 end

local MOVES = {
    bounce = function(t) return sin(t * 40) * 1.2, abs(sin(t * TAU * 2.2)) * 7, deg(sin(t * 30) * 4), 1 end,
    bob = function(t) return 0, sin(t * TAU * 0.9) * 2.5, 0, 1 end,
    sway = function(t) return sin(t * TAU * 1.2) * 5, abs(sin(t * TAU * 2.4)) * 2, deg(sin(t * TAU * 1.2) * 14), 1 end,
    wave = function(t) return 0, 0, deg(sin(t * TAU * 2.5) * 20), 1 end,
    shake = function(t) return sin(t * 55) * 2.5 * (1 - t / DURATION * 0.5), 0, deg(sin(t * 47) * 3), 1 end,
    float = function(t) return 0, sin(t * TAU * 0.8) * 3, 0, 1 + 0.06 * sin(t * TAU * 1.6) end,
    droop = function(t) local k = min(t, 1); return sin(t * 30) * 0.6, -k * 4, deg(-8 * k), 1 end,
    nod = function(t) return 0, -sin(min(t / 0.9, 1) * pi) * 7, deg(-sin(min(t / 0.9, 1) * pi) * 6), 1 end,
    clap = function(t) return 0, 0, 0, 1 + 0.14 * abs(sin(t * TAU * 2)) end,
    pop = function(t) return 0, 0, 0, 1 + 0.3 * exp(-t * 3) * abs(cos(t * TAU * 1.5)) end,
    doze = function(t) return 0, sin(t * TAU * 0.5) * 2, deg(sin(t * TAU * 0.5) * 6), 1 end,
}
CE.MOVES = MOVES

-- Overshooting grow for the first POP seconds.
local function popScale(t)
    if t >= POP then return 1 end
    local x = t / POP - 1
    return 1 + 2.7 * x * x * x + 1.7 * x * x
end

-- Turns a whole texture by `angle` around its centre in texture coordinates.
local function rotate(texture, angle)
    local c, s = cos(angle), sin(angle)
    local function u(dx, dy) return 0.5 + dx * c + dy * s end
    local function v(dx, dy) return 0.5 - dx * s + dy * c end
    texture:SetTexCoord(u(-0.5, -0.5), v(-0.5, -0.5), u(-0.5, 0.5), v(-0.5, 0.5),
        u(0.5, -0.5), v(0.5, -0.5), u(0.5, 0.5), v(0.5, 0.5))
end
CE.Rotate = rotate

---------------------------------------------------------------------------------------------------
-- Medallions
---------------------------------------------------------------------------------------------------
local shown, pool, log = {}, {}, {}
local driver = CreateFrame("Frame")
local sequence = 0

local function newMedallion()
    local e = CreateFrame("Frame", nil, UIParent)
    e:Hide()
    e:EnableMouse(false)
    e:SetWidth(SIZE)
    e:SetHeight(SIZE)
    local icon = e:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", e, "CENTER")
    e.icon = icon
    e.particles = {}
    return e
end

local function particle(e, i, kind)
    local p = e.particles[i]
    if p and p.kind ~= kind then p:Hide(); p = nil end
    if not p then
        if kind == "z" then
            p = e:CreateFontString(nil, "OVERLAY")
            p:SetFont(STANDARD_TEXT_FONT or [[Fonts\FRIZQT__.TTF]], 10 + i * 2, "OUTLINE")
            p:SetText(i == 3 and "Z" or "z")
            p:SetTextColor(0.75, 0.85, 1)
        else
            p = e:CreateTexture(nil, "OVERLAY")
            p:SetTexture(ART .. "love")
            p:SetWidth(12)
            p:SetHeight(12)
        end
        p.kind = kind
        e.particles[i] = p
    end
    return p
end

local function hideParticles(e)
    for _, p in pairs(e.particles) do p:Hide() end
end

-- Small hearts or letters rise from the medallion one after another and fade.
local function drawParticles(e, t)
    local kind = MOTIONS[e.key] and MOTIONS[e.key].particles
    if not kind then return end
    for i = 1, PARTICLES do
        local p = particle(e, i, kind)
        local life = (t - (i - 1) * 0.45) / 1.4
        if life <= 0 or life >= 1 then
            p:Hide()
        else
            local side = (i % 2 == 0) and -1 or 1
            p:ClearAllPoints()
            p:SetPoint("CENTER", e, "TOP", side * (6 + 4 * sin(life * pi * 2)), life * 22)
            p:SetAlpha((1 - life) * min(1, life * 5))
            p:Show()
        end
    end
end

local function release(key)
    local e = shown[key]
    if not e then return end
    shown[key] = nil
    e:Hide()
    e:ClearAllPoints()
    e:SetParent(UIParent)
    hideParticles(e)
    e.view, e.host, e.onBubble = nil, nil, nil
    pool[#pool + 1] = e
end

local function releaseAll()
    for key in pairs(shown) do release(key) end
end

local function ownsView(e, view)
    if not view or not view.infoActive or not view:IsVisible() then return false end
    if e.guid and view.identityGUID then return view.identityGUID == e.guid end
    return view.identityName == e.name
end

local function findView(guid, name)
    if not platesActive() then return nil end
    return ui.wfn.FindCombatTextAnchor(guid, name)
end

-- On the bubble's top-right corner while the speaker's bubble is drawn, otherwise above the plate.
local function place(e, view)
    if e.view ~= view then
        e.view = view
        e:SetParent(view)
        e.host = nil
    end
    local CB = ui.ChatBubbles
    local bubble = CB and CB.BubbleFor and CB.BubbleFor(e.guid, e.name)
    if bubble and bubble.view ~= view then bubble = nil end
    local host = bubble or (CB and CB.AnchorRegion and CB.AnchorRegion(view)) or view
    if e.host ~= host then
        e.host = host
        e.onBubble = bubble ~= nil
        e:ClearAllPoints()
        if bubble then
            e:SetPoint("CENTER", bubble, "TOPRIGHT", -6, -2)
        else
            e:SetPoint("BOTTOM", host, "TOP", 0, GAP)
        end
    end
    local strata = (bubble and bubble.strata) or (view.priority == "target" and "MEDIUM") or "LOW"
    if e.strata ~= strata then
        e.strata = strata
        e:SetFrameStrata(strata)
    end
    local level = (bubble and (bubble.level or 0) + 6) or view:GetFrameLevel() + 24
    if e.level ~= level then
        e.level = level
        e:SetFrameLevel(level)
    end
end

local function trim(now)
    local alive = {}
    for _, e in pairs(shown) do
        if e.expire > now + 0.2 then alive[#alive + 1] = e end
    end
    if #alive <= MAX_EMOTES then return end
    table.sort(alive, function(a, b) return a.seq < b.seq end)
    for i = 1, #alive - MAX_EMOTES do alive[i].expire = now + 0.2 end
end

local function wake()
    driver:SetScript("OnUpdate", function() CE.Tick(GetTime()) end)
end

-- Shows the medallion of `key` above the speaker's plate. Returns it, or nil without a visible plate.
function CE.Show(name, guid, key, now)
    now = now or GetTime()
    name = shortName(name)
    if guid == "" then guid = nil end
    if not name or not MOTIONS[key] then return nil end
    local view = findView(guid, name)
    if not view then return nil end
    local id = guid or name
    local e = shown[id]
    if not e then
        e = table.remove(pool) or newMedallion()
        shown[id] = e
    end
    sequence = sequence + 1
    e.seq, e.id, e.name, e.guid, e.key = sequence, id, name, guid, key
    e.born, e.expire = now, now + DURATION
    e.icon:SetTexture(ART .. key)
    hideParticles(e)
    place(e, view)
    e:SetAlpha(0)
    e:Show()
    trim(now)
    wake()
    return e
end

local function animate(e, now)
    local t = now - e.born
    local left = e.expire - now
    e:SetAlpha(min(1, t / FADE_IN) * (left < FADE_OUT and max(0, left / FADE_OUT) or 1))
    local x, y, angle, grow = MOVES[MOTIONS[e.key].kind](t)
    local size = SIZE * (e.onBubble and ON_BUBBLE or 1) * popScale(t) * grow
    e.icon:SetWidth(size)
    e.icon:SetHeight(size)
    e.icon:ClearAllPoints()
    e.icon:SetPoint("CENTER", e, "CENTER", x, y)
    rotate(e.icon, angle)
    drawParticles(e, t)
end

function CE.Tick(now)
    local busy = false
    for id, e in pairs(shown) do
        if now >= e.expire then
            release(id)
        else
            busy = true
            local view = ownsView(e, e.view) and e.view or findView(e.guid, e.name)
            if view then
                place(e, view)
                if not e:IsShown() then e:Show() end
                animate(e, now)
            elseif e:IsShown() then
                e:Hide()
            end
        end
    end
    if not busy then driver:SetScript("OnUpdate", nil) end
end

---------------------------------------------------------------------------------------------------
-- Events, settings, diagnostics
---------------------------------------------------------------------------------------------------
local function remember(entry)
    table.insert(log, 1, entry)
    log[LOG_SIZE + 1] = nil
end

-- Unrecognised texts, newest first, without repeats, so the dictionary can be extended from them.
local function rememberUnknown(text)
    local db = ui.Settings and ui.Settings()
    if not db then return end
    local list = type(db.emoteUnknown) == "table" and db.emoteUnknown or {}
    db.emoteUnknown = list
    for i = #list, 1, -1 do
        if list[i] == text then table.remove(list, i) end
    end
    table.insert(list, 1, text)
    for i = #list, UNKNOWN_KEEP + 1, -1 do list[i] = nil end
end

local function onEmote(text, sender, ...)
    if not enabled() then return end
    local guid = select(10, ...)
    if guid == "" then guid = nil end
    local name = shortName(sender)
    local key = CE.Recognize(text, name)
    local entry = { name = name, key = key, plates = platesActive(), text = text }
    if not key then
        rememberUnknown(text)
    elseif name ~= (UnitName and UnitName("player")) then
        entry.shown = CE.Show(name, guid, key) ~= nil
    end
    remember(entry)
end

driver:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
driver:RegisterEvent("PLAYER_LOGIN")
driver:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        -- The removed own-character spot may have a saved Edit Mode position.
        local db = ui.Settings and ui.Settings()
        if db and type(db.editLayout) == "table" then db.editLayout.ForeverStockUIEmoteSelf = nil end
        return
    end
    onEmote(...)
end)

function CE.Apply()
    if not enabled() then releaseAll() end
end

-- An example above the target: the given key, or the next emote of the list on every call.
local nextPreview = 0
function CE.Preview(key)
    local view = platesActive() and ui.wfn.FindCombatTextAnchor(UnitGUID and UnitGUID("target"), UnitName("target"))
    if not view then
        ui.Print(L("Возьмите в цель игрока или NPC с видимой плашкой ForeverUI.",
            "Target a player or NPC with a visible ForeverUI nameplate."))
        return
    end
    if not MOTIONS[key or ""] then
        nextPreview = nextPreview % #EMOTES + 1
        key = EMOTES[nextPreview].key
    end
    CE.Show(view.identityName, view.identityGUID, key)
    return key
end

function CE.Active() return shown end
function CE.Log() return log end

-- /fuiemote: the last emote texts and what became of them (ASCII labels; the texts themselves are Cyrillic and some
-- chat fonts print them as "?": the unknown ones are also in ForeverStockUIDB.emoteUnknown).
SLASH_FOREVERUIEMOTE1 = "/fuiemote"
SlashCmdList.FOREVERUIEMOTE = function(input)
    local command, arg = (input or ""):lower():match("^%s*(%S*)%s*(%S*)")
    if command == "test" then
        local key = CE.Preview(arg ~= "" and arg or nil)
        if key then ui.Print("emote test " .. key) end
        return
    end
    local db = ui.Settings and ui.Settings()
    if command == "clear" then
        if db then db.emoteUnknown = nil end
        ui.Print("emote unknown list cleared")
        return
    end
    local unknown = db and type(db.emoteUnknown) == "table" and db.emoteUnknown or {}
    if command == "unknown" then
        for i, text in ipairs(unknown) do ui.Print(("unknown %d: %s"):format(i, text)) end
        return
    end
    local count = 0
    for _ in pairs(shown) do count = count + 1 end
    ui.Print(("enabled=%s plates=%s shown=%d unknown=%d (ForeverStockUIDB.emoteUnknown)"):format(tostring(enabled()),
        tostring(platesActive()), count, #unknown))
    for _, entry in ipairs(log) do
        ui.Print(("emote from=%s key=%s plates=%s shown=%s text=%s"):format(tostring(entry.name), tostring(entry.key),
            tostring(entry.plates), tostring(entry.shown or false), tostring(entry.text)))
    end
end
