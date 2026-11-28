local _, ui = ...
local L = ui.L

-- Chat bubbles above ForeverUI nameplates (2026-11-28).
-- With the ForeverUI nameplates on, the client's bubbles above players go missing (the addon sets no bubble CVar
-- and skips bubble frames in AddPlate, so the cause is in the client; /fuibubble lists what the client has).
-- This module draws its own bubble above the speaker's plate (every chat a player or NPC speaks in: say, yell, party,
-- raid and raid warning, battleground, guild and officer, whispers to you, every numbered channel) and restyles
-- the client bubbles that are still drawn (own character, speakers without a plate) in the same look. A client
-- bubble with the same text as one of ours is muted, so a message is never shown twice.
--
-- Look: WoW-style bronze frame with a dark stone panel (Art/Bubbles, generated 2026-11-28 and converted by
-- Art/Bubbles/convert_bubbles.py; variant 2 of 3): a 9-slice frame (corner CORNER px on screen), a gem on top whose
-- crystal takes the channel colour (the bezel stays bronze), a tail under the frame and a soft glow in the channel
-- colour.
--
-- Attention design:
--  * the message is the only content: the speaker's name is already on the plate right under the bubble;
--  * the channel is a pre-attentive colour cue (gem and glow), the body text stays light on dark for contrast;
--  * motion only at onset (fade + rise + slight grow, INTRO s), no idle animation; a yell flashes its glow once
--    (FLASH_TIME) and is two points larger;
--  * the time on screen follows reading speed (READ_SPEED letters per second, MIN_TIME..MAX_TIME);
--  * one bubble per speaker (a new message replaces the old one), at most MAX_BUBBLES on screen (oldest go first);
--  * distance: the bubble is a child of the plate view, so it takes the plate's scale and fade.
-- Persuasive design (tailoring, salience by relevance): a message with your name gets a bright gold glow and the top
-- layer, the same layer as your target's bubble; party and raid speech keep their group colour.
--
-- The only setting is bubblesEnabled (checkbox on the Skins page, Options/Skins.lua); everything else is fixed here.
-- Keys of the removed "Chat bubbles" page are wiped on load (REMOVED_KEYS).
-- API: ui.ChatBubbles { Apply, Show(name, guid, text, kind), Preview, Tick(now), ScanNatives, Active, BubbleFor,
-- AnchorRegion, Natives, Log, Duration, Prepare, KINDS, STYLES, LOOK }.

local CB = {}
ui.ChatBubbles = CB

local CreateFrame, GetTime, UnitName = CreateFrame, GetTime, UnitName
local pairs, ipairs, select, type, tostring = pairs, ipairs, select, type, tostring
local ceil, floor, max, min = math.ceil, math.floor, math.max, math.min

local FONT = STANDARD_TEXT_FONT or [[Fonts\FRIZQT__.TTF]]
local FONT_SIZE, MAX_WIDTH, BACK_ALPHA = 12, 220, 0.92
local READ_SPEED, MIN_TIME, MAX_TIME = 15, 3.5, 14
local MAX_BUBBLES = 6
local INTRO, OUTRO, RISE = 0.18, 0.45, 6
local GAP = 2
local SCAN_WINDOW, SCAN_STEP, LOST_STEP = 20, 0.1, 0.25
local LOG_SIZE = 8

-- Bronze, dark stone. u/v: corner share of the frame file (128 source px of the cropped frame), inset: inner edge of
-- the bronze border on screen, glow: how far the glow starts outside the frame, tail: tail height below the frame.
local ART = [[Interface\AddOns\ForeverUI\Art\Bubbles\]]
local LOOK = { index = 2, u = 0.1252, v = 0.2510, inset = 8, glow = 10.5, tail = 10 }
CB.LOOK = LOOK
local CORNER, GLOW_CORNER, GLOW_U, GLOW_V = 18, 24, 0.09375, 0.1875
local TAIL_SIZE, GEM_SIZE = 20, 14
-- Glow strength: every bubble gets a faint aura in its channel colour, a message with your name a bright one.
local GLOW_BASE, GLOW_MENTION, GLOW_FLASH, FLASH_TIME = 0.22, 0.65, 0.8, 0.35

local REMOVED_KEYS = { "bubblesLook", "bubblesGroup", "bubblesNPC", "bubblesMention", "bubblesSkinNative",
    "bubblesFontSize", "bubblesMaxWidth", "bubblesAlpha", "bubblesReadSpeed", "bubblesMax" }
CB.REMOVED_KEYS = REMOVED_KEYS

local KINDS = {
    CHAT_MSG_SAY = "say", CHAT_MSG_YELL = "yell",
    CHAT_MSG_PARTY = "party", CHAT_MSG_PARTY_LEADER = "party",
    CHAT_MSG_RAID = "raid", CHAT_MSG_RAID_LEADER = "raid",
    CHAT_MSG_MONSTER_SAY = "npc", CHAT_MSG_MONSTER_YELL = "npcYell",
    CHAT_MSG_RAID_WARNING = "warning",
    CHAT_MSG_BATTLEGROUND = "bg", CHAT_MSG_BATTLEGROUND_LEADER = "bg",
    CHAT_MSG_GUILD = "guild", CHAT_MSG_OFFICER = "officer",
    CHAT_MSG_WHISPER = "whisper",
    -- Every numbered channel: general, trade, "Looking for group", local defence, own channels.
    CHAT_MSG_CHANNEL = "channel",
}
CB.KINDS = KINDS

-- The last channel message seen (zone channel ID, name, channel string), for /fuibubble.
local lastChannel

-- CHAT_MSG_CHANNEL arguments after text and sender: language, channelString, target, flags, zoneChannelID,
-- channelIndex, channelBaseName.
local function noteChannel(...)
    local _, channelString, _, _, zoneID, _, baseName = ...
    lastChannel = ("%s/%s/%s"):format(tostring(zoneID), tostring(baseName), tostring(channelString))
end

-- accent: gem and glow; text: body colour; size: added to FONT_SIZE; loud: one glow flash.
local STYLES = {
    say = { accent = { 1, 0.84, 0.52 }, text = { 0.97, 0.95, 0.9 }, size = 0 },
    yell = { accent = { 1, 0.3, 0.22 }, text = { 1, 0.88, 0.84 }, size = 2, loud = true },
    party = { accent = { 0.46, 0.68, 1 }, text = { 0.92, 0.95, 1 }, size = 0 },
    warning = { accent = { 1, 0.28, 0.05 }, text = { 1, 0.9, 0.8 }, size = 2, loud = true },
    bg = { accent = { 1, 0.5, 0.1 }, text = { 1, 0.94, 0.86 }, size = 0 },
    guild = { accent = { 0.3, 1, 0.3 }, text = { 0.9, 1, 0.9 }, size = 0 },
    officer = { accent = { 0.2, 0.72, 0.2 }, text = { 0.88, 0.98, 0.88 }, size = 0 },
    whisper = { accent = { 1, 0.5, 1 }, text = { 1, 0.92, 1 }, size = 0 },
    channel = { accent = { 1, 0.62, 0.62 }, text = { 1, 0.94, 0.92 }, size = 0 },
    raid = { accent = { 1, 0.56, 0.16 }, text = { 1, 0.95, 0.88 }, size = 0 },
    npc = { accent = { 0.78, 0.72, 0.6 }, text = { 0.93, 0.9, 0.84 }, size = 0 },
    npcYell = { accent = { 1, 0.42, 0.28 }, text = { 1, 0.9, 0.86 }, size = 2, loud = true },
}
CB.STYLES = STYLES
local MENTION = { 1, 0.82, 0.22 }

local function enabled()
    local db = ui.Settings and ui.Settings()
    return not (db and db.bubblesEnabled == false)
end

-- Own bubbles need the ForeverUI plates (wfn.active is set when their scanner starts).
local function platesActive()
    local wfn = ui.wfn
    return wfn and wfn.active and wfn.FindCombatTextAnchor and true or false
end

local function shortName(name)
    if type(name) ~= "string" then return nil end
    return name:match("^[^%-]+") or name
end

-- Raid target tags ({rt1}, {star}, {звезда}) become icons, as the chat frame does it.
local function prepare(text)
    if type(text) ~= "string" then return "" end
    if ICON_TAG_LIST and ICON_LIST then
        text = text:gsub("%b{}", function(tag)
            local index = ICON_TAG_LIST[tag:sub(2, -2):lower()]
            local icon = index and ICON_LIST[index]
            if icon then return icon .. "0|t" end
        end)
    end
    return text
end
CB.Prepare = prepare

-- Letters a reader sees: links and colour codes do not count, a UTF-8 letter counts once.
local function letters(text)
    local plain = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")
        :gsub("|T.-|t", "x")
    local count = 0
    for _ in plain:gmatch("[^\128-\191]") do count = count + 1 end
    return count
end

local function duration(text)
    return max(MIN_TIME, min(MAX_TIME, 1.5 + letters(text) / READ_SPEED))
end
CB.Duration = duration

local function mentions(text)
    local me = UnitName and UnitName("player")
    return type(me) == "string" and me ~= "" and type(text) == "string" and text:find(me, 1, true) ~= nil
end

---------------------------------------------------------------------------------------------------
-- Bronze chrome: 9-slice frame, glow, tail and gem, shared by own and client bubbles
---------------------------------------------------------------------------------------------------
local function makeSlices(owner, layer, sub, file)
    local slices = {}
    for i = 1, 9 do
        slices[i] = owner:CreateTexture(nil, layer, nil, sub)
        slices[i]:SetTexture(file)
    end
    return slices
end

-- Corners keep `corner` px, edges and centre stretch. Anchored to `box`, pushed out by `outset`.
local function placeSlices(s, box, corner, outset, u, v)
    local cu, cv = { 0, u, 1 - u, 1 }, { 0, v, 1 - v, 1 }
    for row = 1, 3 do
        for col = 1, 3 do
            s[(row - 1) * 3 + col]:SetTexCoord(cu[col], cu[col + 1], cv[row], cv[row + 1])
        end
    end
    local tl, tr, bl, br = s[1], s[3], s[7], s[9]
    for _, t in ipairs({ tl, tr, bl, br }) do
        t:SetWidth(corner)
        t:SetHeight(corner)
    end
    tl:SetPoint("TOPLEFT", box, "TOPLEFT", -outset, outset)
    tr:SetPoint("TOPRIGHT", box, "TOPRIGHT", outset, outset)
    bl:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", -outset, -outset)
    br:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", outset, -outset)
    s[2]:SetPoint("TOPLEFT", tl, "TOPRIGHT"); s[2]:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
    s[4]:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); s[4]:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
    s[5]:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT"); s[5]:SetPoint("BOTTOMRIGHT", br, "TOPLEFT")
    s[6]:SetPoint("TOPLEFT", tr, "BOTTOMLEFT"); s[6]:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
    s[8]:SetPoint("TOPLEFT", bl, "TOPRIGHT"); s[8]:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
end

-- owner: the frame the bubble box is (textures live on it); glowOwner: a lower frame for the glow, or owner.
-- Layers on one frame: glow (BACKGROUND -8) under the tail (-7) under the frame (0); gem on ARTWORK above.
local function makeChrome(owner, glowOwner)
    local n = LOOK.index
    local c = { owner = owner, own = {}, all = {} }
    c.frame = makeSlices(owner, "BACKGROUND", 0, ART .. "Bubble-Frame" .. n)
    placeSlices(c.frame, owner, CORNER, 0, LOOK.u, LOOK.v)
    c.glow = makeSlices(glowOwner or owner, "BACKGROUND", -8, ART .. "Bubble-Glow" .. n)
    placeSlices(c.glow, owner, GLOW_CORNER, LOOK.glow, GLOW_U, GLOW_V)
    c.tail = owner:CreateTexture(nil, "BACKGROUND", nil, -7)
    c.tail:SetTexture(ART .. "Bubble-Tail" .. n)
    c.tail:SetWidth(TAIL_SIZE)
    c.tail:SetHeight(TAIL_SIZE)
    -- The tail's open top hides under the bottom border.
    c.tail:SetPoint("TOP", owner, "BOTTOM", 0, LOOK.inset)
    c.crystal = owner:CreateTexture(nil, "ARTWORK", nil, 1)
    c.crystal:SetTexture(ART .. "Bubble-Crystal" .. n)
    c.bezel = owner:CreateTexture(nil, "ARTWORK", nil, 2)
    c.bezel:SetTexture(ART .. "Bubble-Gem" .. n)
    for _, t in ipairs({ c.crystal, c.bezel }) do
        t:SetWidth(GEM_SIZE)
        t:SetHeight(GEM_SIZE)
        t:SetPoint("CENTER", owner, "TOP", 0, -LOOK.inset / 2)
    end
    for _, t in ipairs(c.frame) do c.all[#c.all + 1] = t end
    for _, t in ipairs(c.glow) do c.all[#c.all + 1] = t end
    c.all[#c.all + 1] = c.tail
    c.all[#c.all + 1] = c.crystal
    c.all[#c.all + 1] = c.bezel
    for _, t in ipairs(c.all) do c.own[t] = true end
    c.shown = true
    return c
end

local function showChrome(c, on)
    if c.shown == on then return end
    c.shown = on
    for _, t in ipairs(c.all) do
        if on then t:Show() else t:Hide() end
    end
end

local function glowChrome(c, glow)
    local a = c.accent or STYLES.say.accent
    for _, t in ipairs(c.glow) do t:SetVertexColor(a[1], a[2], a[3], glow) end
end

local function paintChrome(c, accent, glow)
    for _, t in ipairs(c.frame) do t:SetVertexColor(1, 1, 1, BACK_ALPHA) end
    c.tail:SetVertexColor(1, 1, 1, BACK_ALPHA)
    c.bezel:SetVertexColor(1, 1, 1, 1)
    c.crystal:SetVertexColor(accent[1], accent[2], accent[3], 1)
    c.accent = accent
    glowChrome(c, glow)
end

---------------------------------------------------------------------------------------------------
-- Own bubbles
---------------------------------------------------------------------------------------------------
local bubbles, pool = {}, {}   -- bubbles[speaker key] = frame
local log = {}
local driver = CreateFrame("Frame")
local scanUntil, nextScan = 0, 0
-- Arrival order: several messages can come in one frame (same GetTime), the cap must still drop the oldest.
local sequence = 0

local function remember(entry)
    table.insert(log, 1, entry)
    log[LOG_SIZE + 1] = nil
end

-- Frames: b (the box) → halo (glow, under) and body (frame, gem, tail, text).
local function newBubble()
    local b = CreateFrame("Frame", nil, UIParent)
    b:Hide()
    b:EnableMouse(false)
    local halo = CreateFrame("Frame", nil, b)
    halo:SetAllPoints(b)
    halo:EnableMouse(false)
    b.halo = halo
    local body = CreateFrame("Frame", nil, b)
    body:SetAllPoints(b)
    body:EnableMouse(false)
    b.body = body
    b.chrome = makeChrome(body, halo)
    local text = body:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT, FONT_SIZE, "")
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetShadowColor(0, 0, 0, 0.9)
    text:SetShadowOffset(1, -1)
    b.text = text
    return b
end

local function setGlow(b, a)
    glowChrome(b.chrome, a)
    b.glowNow = a
end

local function paint(b)
    local style = STYLES[b.kind] or STYLES.say
    b.haloAlpha = b.mention and GLOW_MENTION or GLOW_BASE
    paintChrome(b.chrome, b.mention and MENTION or style.accent, b.haloAlpha)
    b.text:SetTextColor(style.text[1], style.text[2], style.text[3])
    b.glowNow = b.haloAlpha
end

-- Fits the box to the text: short messages get a tight box, long ones wrap at MAX_WIDTH. The text stays inside the
-- bronze border, and the box never shrinks below two corners (and the gem) per side.
local function layout(b)
    local style = STYLES[b.kind] or STYLES.say
    local size = FONT_SIZE + style.size
    local padX, padY = LOOK.inset + 5, LOOK.inset + 3
    local text = b.text
    text:SetFont(FONT, size, "")
    text:SetWidth(MAX_WIDTH)
    text:SetText(b.display)
    local natural = text:GetStringWidth() or 0
    local width = natural < MAX_WIDTH and ceil(natural) + 1 or MAX_WIDTH
    text:SetWidth(width)
    local lines = max(1, ceil(natural / width))
    local height = ceil(max(text:GetStringHeight() or 0, text:GetHeight() or 0, lines * size * 1.2))
    local boxWidth = max(width + 2 * padX, 2 * CORNER + GEM_SIZE)
    local boxHeight = max(height + 2 * padY, 2 * CORNER)
    b:SetWidth(boxWidth)
    b:SetHeight(boxHeight)
    text:ClearAllPoints()
    text:SetPoint("TOP", b.body, "TOP", 0, -floor((boxHeight - height) / 2))
end

local function anchorRegion(view)
    local row = view.auraRow
    if row then
        local i = 1
        while view[i] do
            if view[i]:IsShown() then return row end
            i = i + 1
        end
    end
    local name = view.name
    local db = ui.wfn and ui.wfn.db
    if name and name:IsShown() and (name:GetText() or "") ~= "" and not (db and db.namePlace == "undercast") then
        return name
    end
    return view
end

CB.AnchorRegion = anchorRegion

local function ownsView(b, view)
    if not view or not view.infoActive or not view:IsVisible() then return false end
    if b.guid and view.identityGUID then return view.identityGUID == b.guid end
    return view.identityName == b.name
end

local function findView(b)
    if not platesActive() then return nil end
    return ui.wfn.FindCombatTextAnchor(b.guid, b.name)
end

-- The bubble lives on WorldFrame, not on the plate: plates fade with distance, out of combat and behind other plates,
-- and a faded bubble is hard to read from afar. It follows the plate's scale and is hidden by Tick with the plate.
local function viewScale(view)
    local world = WorldFrame
    if not (view.GetEffectiveScale and world and world.GetEffectiveScale) then return 1 end
    local base = world:GetEffectiveScale()
    return base > 0 and view:GetEffectiveScale() / base or 1
end

local function setScale(b, intro)
    local scale = viewScale(b.view) * intro
    if b.scaleNow ~= scale then
        b.scaleNow = scale
        b:SetScale(scale)
    end
end

local function place(b, view, rise)
    if b.view ~= view then
        b.view = view
        b:SetParent(WorldFrame or UIParent)
        b.anchor = nil
    end
    local top = b.mention or view.priority == "target"
    local strata = top and "MEDIUM" or "LOW"
    if b.strata ~= strata then
        b.strata = strata
        b:SetFrameStrata(strata)
        b.halo:SetFrameStrata(strata)
        b.body:SetFrameStrata(strata)
    end
    local level = view:GetFrameLevel() + 20
    if b.level ~= level then
        b.level = level
        b:SetFrameLevel(level)
        b.halo:SetFrameLevel(level + 1)
        b.body:SetFrameLevel(level + 2)
    end
    local anchor = anchorRegion(view)
    if b.anchor ~= anchor or b.rise ~= rise then
        b.anchor, b.rise = anchor, rise
        b:ClearAllPoints()
        b:SetPoint("BOTTOM", anchor, "TOP", 0, LOOK.tail + GAP - rise)
    end
end

local function release(key)
    local b = bubbles[key]
    if not b then return end
    bubbles[key] = nil
    b:Hide()
    b:ClearAllPoints()
    b:SetParent(UIParent)
    b.view, b.anchor, b.strata, b.level, b.rise, b.scaleNow = nil, nil, nil, nil, nil, nil
    pool[#pool + 1] = b
end

local function releaseAll()
    for key in pairs(bubbles) do release(key) end
end

local function count()
    local n = 0
    for _ in pairs(bubbles) do n = n + 1 end
    return n
end

-- The oldest bubbles leave quickly when the cap is reached.
local function trim(now)
    local alive = {}
    for _, b in pairs(bubbles) do
        if b.expire > now + 0.2 then alive[#alive + 1] = b end
    end
    if #alive <= MAX_BUBBLES then return end
    table.sort(alive, function(a, c) return a.seq < c.seq end)
    for i = 1, #alive - MAX_BUBBLES do alive[i].expire = now + 0.2 end
end

local function wake()
    driver:SetScript("OnUpdate", function(_, elapsed) CB.Tick(GetTime(), elapsed) end)
end

-- Shows a bubble above the speaker's plate. Returns the bubble, or nil when the speaker has no visible plate.
function CB.Show(name, guid, text, kind, now)
    now = now or GetTime()
    name = shortName(name)
    if guid == "" then guid = nil end
    if not name or type(text) ~= "string" or text == "" then return nil end
    kind = STYLES[kind] and kind or "say"
    local view = findView({ name = name, guid = guid })
    if not view then return nil end
    local key = guid or name
    local b = bubbles[key]
    if not b then
        b = table.remove(pool) or newBubble()
        bubbles[key] = b
        b.born = now
    elseif now - b.born > INTRO then
        -- A new message from the same speaker replaces the text with a short pop, without a new fade-in.
        b.born = now - INTRO * 0.5
    end
    sequence = sequence + 1
    b.seq = sequence
    b.key, b.name, b.guid, b.kind = key, name, guid, kind
    b.raw, b.display = text, prepare(text)
    b.mention = mentions(text)
    b.expire = now + duration(b.display)
    b.lostAt, b.nextFind = nil, nil
    -- A yell flashes the glow from full strength, also when it replaces an older message of the same speaker.
    b.flashAt = STYLES[kind].loud and not b.mention and now or nil
    paint(b)
    layout(b)
    place(b, view, RISE)
    b:SetAlpha(0)
    b:Show()
    trim(now)
    wake()
    return b
end

local function animate(b, now)
    local progress = min(1, max(0, (now - b.born) / INTRO))
    local eased = 1 - (1 - progress) ^ 3
    local left = b.expire - now
    local out = left < OUTRO and max(0, left / OUTRO) or 1
    b:SetAlpha(eased * out)
    setScale(b, 0.94 + 0.06 * eased)
    if b.intro ~= 1 or progress < 1 then
        b.intro = progress
        place(b, b.view, (1 - eased) * RISE)
    else
        -- Auras can appear later (the speaker becomes the target): place() only re-anchors on a change.
        place(b, b.view, 0)
    end
    if b.flashAt then
        local flash = 1 - (now - b.flashAt) / FLASH_TIME
        if flash <= 0 then b.flashAt, flash = nil, 0 end
        setGlow(b, max(b.haloAlpha, GLOW_FLASH * flash))
    end
end

function CB.Tick(now, elapsed)
    local busy = false
    for key, b in pairs(bubbles) do
        if now >= b.expire then
            release(key)
        else
            busy = true
            if ownsView(b, b.view) then
                b.lostAt = nil
                if not b:IsShown() then b:Show() end
                animate(b, now)
            else
                -- The plate went away or the client gave its frame to another unit: wait for the speaker's plate.
                if b:IsShown() then b:Hide() end
                b.lostAt = b.lostAt or now
                if now >= (b.nextFind or 0) then
                    b.nextFind = now + LOST_STEP
                    local view = findView(b)
                    if view then
                        place(b, view, 0)
                        b:Show()
                        animate(b, now)
                    end
                end
            end
        end
    end
    if now < scanUntil then
        busy = true
        if now >= nextScan then
            nextScan = now + SCAN_STEP
            CB.ScanNatives()
        end
    end
    if not busy then driver:SetScript("OnUpdate", nil) end
end

---------------------------------------------------------------------------------------------------
-- Client bubbles: unnamed WorldFrame children with the ChatBubble-Background texture
---------------------------------------------------------------------------------------------------
local natives, checked = {}, {}
local worldCount = -1

local function isBubble(frame)
    if frame.GetName and frame:GetName() then return false end
    if not frame.GetRegions then return false end
    for i = 1, select("#", frame:GetRegions()) do
        local region = select(i, frame:GetRegions())
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then
            local path = region:GetTexture()
            if type(path) == "string" and path:lower():gsub("/", "\\"):find("chatbubble%-background") then
                return true
            end
        end
    end
    return false
end

local function discover()
    local world = WorldFrame
    if not world or not world.GetNumChildren then return end
    local n = world:GetNumChildren()
    if n == worldCount then return end
    worldCount = n
    for i = 1, select("#", world:GetChildren()) do
        local frame = select(i, world:GetChildren())
        if frame and not checked[frame] then
            checked[frame] = true
            if isBubble(frame) then natives[frame] = { own = {} } end
        end
    end
end

local function nativeText(frame, n)
    if not n.text then
        for i = 1, select("#", frame:GetRegions()) do
            local region = select(i, frame:GetRegions())
            if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                n.text = region
                break
            end
        end
    end
    return n.text and n.text:GetText()
end

-- Hides the client's own art (remembered for unskin) and puts the bronze chrome on the bubble.
local function skin(frame, n)
    if n.skinned then return end
    n.saved = {}
    for i = 1, select("#", frame:GetRegions()) do
        local region = select(i, frame:GetRegions())
        if region and not n.own[region] and region.GetObjectType and region:GetObjectType() == "Texture" then
            n.saved[region] = region:GetTexture()
            region:SetTexture(nil)
        end
    end
    if n.chrome then
        showChrome(n.chrome, true)
    else
        n.chrome = makeChrome(frame)
        for t in pairs(n.chrome.own) do n.own[t] = true end
    end
    n.skinned, n.paintedText = true, nil
end

local function unskin(frame, n)
    if not n.skinned then return end
    showChrome(n.chrome, false)
    for region, path in pairs(n.saved) do region:SetTexture(path) end
    n.saved, n.skinned = nil, nil
end

local function paintNative(n, text)
    if n.paintedText == text then return end
    n.paintedText = text
    -- The client colours the text by chat type: that colour becomes the accent.
    local r, g, b = 1, 0.84, 0.52
    if n.text and n.text.GetTextColor then r, g, b = n.text:GetTextColor() end
    local mention = mentions(text)
    if mention then r, g, b = MENTION[1], MENTION[2], MENTION[3] end
    paintChrome(n.chrome, { r, g, b }, mention and GLOW_MENTION or GLOW_BASE)
end

local function ownText(text)
    if not text then return false end
    -- Only a bubble that is drawn counts: while ours waits for the speaker's plate, the client's one stays.
    for _, b in pairs(bubbles) do
        if b:IsShown() and (b.raw == text or b.display == text) then return true end
    end
    return false
end

function CB.ScanNatives()
    discover()
    local on = enabled()
    for frame, n in pairs(natives) do
        local text = nativeText(frame, n)
        local muted = on and frame:IsShown() and ownText(text)
        if muted and not n.muted then
            n.muted = true
            frame:SetAlpha(0)
        elseif not muted and n.muted then
            n.muted = nil
            frame:SetAlpha(1)
        end
        if on then
            skin(frame, n)
            paintNative(n, text)
        else
            unskin(frame, n)
        end
    end
end

---------------------------------------------------------------------------------------------------
-- Events, settings, preview, diagnostics
---------------------------------------------------------------------------------------------------
local function onChat(event, text, sender, ...)
    local kind = KINDS[event]
    if kind == "channel" then noteChannel(...) end
    if not kind then return end
    local now = GetTime()
    scanUntil, nextScan = now + SCAN_WINDOW, 0
    wake()
    if not enabled() then return end
    local guid = select(10, ...)
    local entry = { event = event:gsub("^CHAT_MSG_", ""), name = shortName(sender), guid = guid ~= "" and guid or nil,
        plates = platesActive() }
    entry.bubble = CB.Show(sender, guid, text, kind, now) ~= nil
    remember(entry)
end

for event in pairs(KINDS) do pcall(driver.RegisterEvent, driver, event) end
driver:SetScript("OnEvent", function(_, event, ...) onChat(event, ...) end)

-- Saved keys of the removed "Chat bubbles" options page.
function CB.ForgetRemovedKeys()
    local db = ui.Settings and ui.Settings()
    if db then for _, key in ipairs(REMOVED_KEYS) do db[key] = nil end end
end
if ui.RegisterCallback then ui.RegisterCallback("ConfigLoaded", CB.ForgetRemovedKeys, "ChatBubbles") end

function CB.Apply()
    if not enabled() then releaseAll() end
    CB.ScanNatives()
    wake()
end

function CB.Preview()
    local view = platesActive() and ui.wfn.FindCombatTextAnchor(UnitGUID and UnitGUID("target"), UnitName("target"))
    if not view then
        ui.Print(L("Возьмите в цель игрока или NPC с видимой плашкой ForeverUI.",
            "Target a player or NPC with a visible ForeverUI nameplate."))
        return
    end
    CB.Show(view.identityName, view.identityGUID,
        L("Так выглядит облачко сообщения над плашкой.", "This is how a chat bubble looks above a nameplate."), "say")
end

function CB.Active() return bubbles end
-- The speaker's bubble while it is drawn (ChatEmotes.lua puts the emote medallion on its corner).
function CB.BubbleFor(guid, name)
    local b = bubbles[guid or name]
    if b and b:IsShown() then return b end
end
function CB.Natives() return natives end
function CB.Log() return log end

-- /fuibubble: what the client has (its bubbles in WorldFrame) and what the addon drew (ASCII labels: some client
-- chat fonts print Cyrillic as "?"). /fuibubble test: an example above the target.
SLASH_FOREVERUIBUBBLE1 = "/fuibubble"
SlashCmdList.FOREVERUIBUBBLE = function(input)
    if (input or ""):lower():match("test") then
        CB.Preview()
        return
    end
    discover()
    local nativeCount = 0
    for _ in pairs(natives) do nativeCount = nativeCount + 1 end
    ui.Print(("enabled=%s plates=%s own=%d native=%d CVar chatBubbles=%s chatBubblesParty=%s"):format(
        tostring(enabled()), tostring(platesActive()), count(), nativeCount,
        tostring(GetCVar and GetCVar("chatBubbles")), tostring(GetCVar and GetCVar("chatBubblesParty"))))
    for frame, n in pairs(natives) do
        local text = nativeText(frame, n)
        ui.Print(("native shown=%s visible=%s alpha=%.2f strata=%s level=%s skinned=%s muted=%s text=%s"):format(
            tostring(frame:IsShown()), tostring(frame:IsVisible()), frame:GetAlpha() or 0, tostring(frame:GetFrameStrata()),
            tostring(frame:GetFrameLevel()), tostring(n.skinned or false), tostring(n.muted or false),
            tostring(text and text:sub(1, 40))))
    end
    for _, b in pairs(bubbles) do
        ui.Print(("own %s kind=%s shown=%s strata=%s left=%.1fs"):format(tostring(b.name), b.kind,
            tostring(b:IsShown()), tostring(b.strata), b.expire - GetTime()))
    end
    ui.Print(("last channel (zoneID/name/string): %s"):format(tostring(lastChannel)))
    for _, e in ipairs(log) do
        ui.Print(("event %s from=%s guid=%s plates=%s bubble=%s"):format(e.event, tostring(e.name),
            e.guid and "yes" or "no", tostring(e.plates), tostring(e.bubble or false)))
    end
end
