-- ChatEmotes.lua: emote medallions above ForeverUI plates (with the real ChatBubbles.lua). Run from the addon root.
-- The mocks are the ones of tests/ChatBubbles.lua.
local forbidden = { "C_Timer", "BackdropTemplate", "SetShown(", "SetColorTexture", "SetAtlas", "C_NamePlate" }
do
    local file = assert(io.open("ChatBubbles.lua", "r"))
    local source = file:read("*a")
    file:close()
    for _, word in ipairs(forbidden) do assert(not source:find(word, 1, true), "forbidden API: " .. word) end
end

local now = 100
function GetTime() return now end
local cvars = { chatBubbles = "1", chatBubblesParty = "1" }
function GetCVar(name) return cvars[name] end
local me = "Ксандр"
function UnitName(unit)
    if unit == "player" then return me end
    if unit == "target" then return _G.targetName end
end
function UnitGUID(unit) if unit == "target" then return _G.targetGUID end end
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
ICON_TAG_LIST = { star = 1, rt1 = 1, ["звезда"] = 1 }
ICON_LIST = { "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:" }
SlashCmdList = {}
local printed = {}

local function region(kind, parent)
    local r = { kind = kind, parent = parent, shown = true, alpha = 1, points = {} }
    function r:GetObjectType() return self.kind end
    function r:SetTexture(path) self.texture = path end
    function r:GetTexture() return self.texture end
    function r:SetVertexColor(...) self.color = { ... } end
    function r:SetTexCoord(...) self.coords = { ... } end
    function r:SetWidth(w) self.width = w end
    function r:SetHeight(h) self.height = h end
    function r:GetHeight() return self.height or 0 end
    function r:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function r:ClearAllPoints() self.points = {} end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:IsShown() return self.shown end
    function r:SetAlpha(a) self.alpha = a end
    function r:SetFont(f, size, flags) self.font = { f, size, flags } end
    function r:GetFont() return self.font and self.font[1], self.font and self.font[2] end
    function r:SetJustifyH() end function r:SetJustifyV() end
    function r:SetShadowColor() end function r:SetShadowOffset() end
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:SetTextColor(r_, g, b) self.textColor = { r_, g, b } end
    function r:GetTextColor() local c = self.textColor or { 1, 1, 1 }; return c[1], c[2], c[3] end
    -- 6 px per byte is enough for the width logic; wrapped height comes from the bubble's line estimate.
    function r:GetStringWidth() return #(self.text or "") * 6 end
    function r:GetStringHeight() return self.font and self.font[2] or 12 end
    return r
end

local function frame(kind, parent, name)
    local f = region(kind or "Frame", parent)
    f.name, f.children, f.regions, f.scripts, f.level, f.strata, f.scale = name, {}, {}, {}, 1, "MEDIUM", 1
    if parent and parent.children then parent.children[#parent.children + 1] = f end
    function f:GetName() return self.name end
    function f:CreateTexture() local t = region("Texture", self); self.regions[#self.regions + 1] = t; return t end
    function f:CreateFontString() local t = region("FontString", self); self.regions[#self.regions + 1] = t; return t end
    function f:GetRegions() return unpack(self.regions) end
    function f:GetChildren() return unpack(self.children) end
    function f:GetNumChildren() return #self.children end
    function f:SetScript(n, fn) self.scripts[n] = fn end
    function f:GetScript(n) return self.scripts[n] end
    function f:RegisterEvent(e) self.events = self.events or {}; self.events[e] = true end
    function f:UnregisterEvent(e) if self.events then self.events[e] = nil end end
    function f:EnableMouse() end
    function f:SetAllPoints() end
    function f:SetBackdrop(b) self.backdrop = b end
    function f:SetBackdropColor(...) self.bg = { ... } end
    function f:SetBackdropBorderColor(...) self.border = { ... } end
    function f:SetParent(p) self.parent = p end
    function f:GetParent() return self.parent end
    function f:SetFrameStrata(s) self.strata = s end
    function f:GetFrameStrata() return self.strata end
    function f:SetFrameLevel(l) self.level = l end
    function f:GetFrameLevel() return self.level end
    function f:SetScale(s) self.scale = s end
    function f:GetAlpha() return self.alpha end
    function f:IsVisible()
        local p = self
        while p do
            if p.shown == false then return false end
            p = p.parent
        end
        return true
    end
    return f
end
function CreateFrame(kind, name, parent) return frame(kind, parent, name) end
UIParent = frame("Frame", nil, "UIParent")
WorldFrame = frame("Frame", nil, "WorldFrame")

-- A ForeverUI plate view: identity, name above the bar, aura row with four slots.
local function plateView(name, guid)
    local plate = frame("Frame", WorldFrame)
    local view = frame("Frame", plate)
    view.infoActive, view.identityName, view.identityGUID, view.level = true, name, guid, 5
    view.name = region("FontString", view)
    view.name:SetText(name)
    view.auraRow = frame("Frame", view)
    for i = 1, 4 do view[i] = frame("Frame", view.auraRow); view[i]:Hide() end
    return view, plate
end

local views = {}
local ui = { russian = true, wfn = { active = true, db = { namePlace = "above" } } }
function ui.L(ru) return ru end
-- Saved keys of the removed "Chat bubbles" page must be wiped when the config loads.
local settings = { bubblesLook = "flat", bubblesMax = 2, bubblesFontSize = 20 }
function ui.Settings() return settings end
local callbacks = {}
function ui.RegisterCallback(event, fn) callbacks[event] = callbacks[event] or {}; table.insert(callbacks[event], fn) end
function ui.Print(text) printed[#printed + 1] = text end
function ui.wfn.FindCombatTextAnchor(guid, name)
    local match
    for _, view in ipairs(views) do
        if view.infoActive and view:IsVisible() then
            if guid and guid == view.identityGUID then return view end
            if name and name == view.identityName and not (guid and view.identityGUID) then
                if match == nil then match = view else match = false end
            end
        end
    end
    return match or nil
end

assert(loadfile("ChatBubbles.lua"))("ForeverUI", ui)
local CB = ui.ChatBubbles
local driver
local created = {}
local oldCreate = CreateFrame
function CreateFrame(kind, name, parent) local f = oldCreate(kind, name, parent); created[#created + 1] = f; return f end

-- Driver: reload with the recorder so the event frame is known.
assert(loadfile("ChatBubbles.lua"))("ForeverUI", ui)
CB = ui.ChatBubbles
for _, f in ipairs(created) do if f.events and f.events.CHAT_MSG_SAY then driver = f end end
assert(driver and driver.events.CHAT_MSG_YELL and driver.events.CHAT_MSG_MONSTER_SAY, "chat events registered")

local function fire(event, text, sender, guid)
    driver.scripts.OnEvent(driver, event, text, sender, "", "", "", "", 0, 0, "", 0, 1, guid)
end
local function tick(seconds)
    local step = 0.05
    local left = seconds
    while left > 1e-9 do
        now = now + step
        left = left - step
        local update = driver.scripts.OnUpdate
        if update then update(driver, step) end
    end
end
local function bubbleOf(key) return CB.Active()[key] end

-- Load the emote module next to the bubbles (it puts the medallion on the speaker's bubble).
local emoteCreated = {}
local plainCreate = CreateFrame
function CreateFrame(kind, name, parent) local f = plainCreate(kind, name, parent); emoteCreated[#emoteCreated + 1] = f; return f end
do
    local file = assert(io.open("ChatEmotes.lua", "r"))
    local source = file:read("*a")
    file:close()
    for _, word in ipairs(forbidden) do assert(not source:find(word, 1, true), "ChatEmotes forbidden API: " .. word) end
end
assert(loadfile("ChatEmotes.lua"))("ForeverUI", ui)
local CE = ui.ChatEmotes
local edriver
for _, f in ipairs(emoteCreated) do if f.events and f.events.CHAT_MSG_TEXT_EMOTE then edriver = f end end
assert(edriver, "emote event registered")
local function emote(text, sender, guid)
    edriver.scripts.OnEvent(edriver, "CHAT_MSG_TEXT_EMOTE", text, sender, "", "", "", "", 0, 0, "", 0, 1, guid)
end
local function etick(seconds)
    local step = 0.05
    local left = seconds
    while left > 1e-9 do
        now = now + step
        left = left - step
        if driver.scripts.OnUpdate then driver.scripts.OnUpdate(driver, step) end
        if edriver.scripts.OnUpdate then edriver.scripts.OnUpdate(edriver, step) end
    end
end
local function medallion(key) return CE.Active()[key] end

-- 1. Recognition by Russian stems; the sender's name never matches; unknown texts give nil.
local cases = {
    { "Алиса смеется.", "laugh" }, { "Алиса смеётся над Бобом.", "laugh" }, { "Алиса улыбается.", "smile" },
    { "Алиса танцует с Бобом.", "dance" }, { "Алиса плачет.", "cry" }, { "Алиса злится на Боба.", "angry" },
    { "Алиса посылает воздушный поцелуй.", "kiss" }, { "Алиса нежно целует Боба.", "kiss" },
    { "Алиса любит Боба.", "love" }, { "Алиса машет рукой.", "wave" }, { "Алиса кланяется.", "bow" },
    { "Алиса аплодирует.", "applaud" }, { "Алиса хлопает в ладоши.", "applaud" }, { "Алиса радостно ликует!", "cheer" },
    { "Алиса засыпает.", "sleep" }, { "Алиса удивлена.", "surprised" }, { "Алиса благодарит Боба.", "thank" },
    { "Алиса грустит.", "sad" }, { "Алиса громко рыгает.", "burp" }, { "Алиса злобно смеется.", "laugh" },
    -- Your own emotes come in the second person.
    { "Вы смеетесь.", "laugh" }, { "Вы улыбаетесь Бобу.", "smile" }, { "Вы танцуете.", "dance" }, { "Вы плачете.", "cry" },
    { "Вы злитесь.", "angry" }, { "Вы целуете Боба.", "kiss" }, { "Вы любите Боба.", "love" },
    { "Вы машете рукой.", "wave" }, { "Вы кланяетесь.", "bow" }, { "Вы аплодируете.", "applaud" },
    { "Вы хлопаете в ладоши.", "applaud" }, { "Вы ликуете!", "cheer" }, { "Вы засыпаете.", "sleep" },
    { "Вы удивлены.", "surprised" }, { "Вы благодарите Боба.", "thank" }, { "Вы грустите.", "sad" },
    { "Вы рыгаете.", "burp" },
}
for _, case in ipairs(cases) do
    assert(CE.Recognize(case[1], "Алиса") == case[2], case[1] .. " -> " .. tostring(CE.Recognize(case[1], "Алиса")))
end
assert(CE.Recognize("Плачущая указывает на Боба.", "Плачущая") == nil, "the sender's name is cut out")
assert(CE.Recognize("Алиса указывает на Боба.", "Алиса") == nil, "unknown emote")
for _, entry in ipairs(CE.EMOTES) do assert(CE.MOTIONS[entry.key], "motion for " .. entry.key) end
assert(#CE.EMOTES == 16, "16 emotes")
-- Every emote has its 64x64 uncompressed 32-bit TGA, and the toc loads the module after ChatBubbles.lua.
for _, entry in ipairs(CE.EMOTES) do
    local path = "Art/Emotes/Emote-" .. entry.key .. ".tga"
    local file = assert(io.open(path, "rb"), "missing " .. path)
    local header = file:read(18)
    file:close()
    assert(header:byte(3) == 2 and header:byte(17) == 32 and header:byte(13) == 64 and header:byte(15) == 64,
        path .. ": 64x64 32-bit")
end
do
    local toc = assert(io.open("ForeverUI.toc", "r")):read("*a")
    local bubbles, emotes = toc:find("ChatBubbles.lua", 1, true), toc:find("ChatEmotes.lua", 1, true)
    assert(bubbles and emotes and emotes > bubbles, "ChatEmotes.lua in the toc after ChatBubbles.lua")
end

-- 2. A laugh above a plate: medallion above the name, art file, pop in, bounce, fade out, release.
settings.emotesEnabled = nil
local eve = plateView("Ева", "0x0000000000000E01")
views[#views + 1] = eve
emote("Ева смеется.", "Ева", "0x0000000000000E01")
local m = medallion("0x0000000000000E01")
assert(m and m.parent == eve and m.key == "laugh" and m.icon.texture:find("Emote%-laugh$"), "laugh medallion")
assert(m.points[1][1] == "BOTTOM" and m.points[1][2] == eve.name, "above the name")
etick(0.05)
assert(m.alpha > 0 and m.alpha < 1 and m.icon.width < 34, "fading and popping in")
local ys = {}
for i = 1, 10 do etick(0.05); ys[#ys + 1] = m.icon.points[1][5] end
local moved = false
for i = 2, #ys do if ys[i] ~= ys[1] then moved = true end end
assert(moved and m.alpha == 1, "bounces while shown")
etick(2.2)
assert(m.alpha < 1, "fades out at the end")
etick(0.4)
assert(not medallion("0x0000000000000E01") and not m.shown, "released after DURATION")

-- 3. Wave turns the icon in texture coordinates (no SetRotation in 3.3.5).
emote("Ева машет рукой.", "Ева", "0x0000000000000E01")
etick(0.3)
m = medallion("0x0000000000000E01")
assert(m.icon.coords and #m.icon.coords == 8 and math.abs(m.icon.coords[1]) > 1e-3, "rotated texcoords")
local c = m.icon.coords
assert(math.abs((c[1] + c[7]) / 2 - 0.5) < 1e-9 and math.abs((c[2] + c[8]) / 2 - 0.5) < 1e-9, "turned around the centre")

-- 4. Love: hearts rise from the medallion; sleep: letters.
emote("Ева любит Боба.", "Ева", "0x0000000000000E01")
etick(0.6)
local heart = m.particles[1]
assert(heart and heart.kind == "heart" and heart.shown and heart.texture:find("Emote%-love$"), "heart particle")
emote("Ева засыпает.", "Ева", "0x0000000000000E01")
etick(0.6)
assert(m.particles[1].kind == "z" and m.particles[1].shown and m.particles[1].text == "z", "Z particle")
assert(not heart.shown, "old hearts hidden")

-- 5. With a chat bubble the medallion sits on the bubble's top-right corner, smaller, above it.
fire("CHAT_MSG_SAY", "Привет всем", "Ева", "0x0000000000000E01")
emote("Ева улыбается.", "Ева", "0x0000000000000E01")
etick(0.4)
local bubble = bubbleOf("0x0000000000000E01")
assert(m.points[1][1] == "CENTER" and m.points[1][2] == bubble and m.points[1][3] == "TOPRIGHT", "on the bubble corner")
assert(m.icon.width < 34 * 0.8 + 0.5 and m.level > bubble.level and m.strata == bubble.strata, "smaller, above the bubble")

-- 6. Own emotes: no medallion above your own character (the screen spot was removed); its saved Edit Mode position
-- is wiped at login. Unknown texts, no plate.
settings.editLayout = { ForeverStockUIEmoteSelf = { position = { 0, 100 } }, Other = {} }
edriver.scripts.OnEvent(edriver, "PLAYER_LOGIN")
assert(settings.editLayout.ForeverStockUIEmoteSelf == nil and settings.editLayout.Other, "old spot wiped, others kept")
assert(edriver.events.PLAYER_LOGIN == nil and edriver.events.CHAT_MSG_TEXT_EMOTE, "login handled once")
assert(CE.selfAnchor == nil and CE.ShowSelf == nil and _G.ForeverStockUIEmoteSelf == nil, "no own spot")
emote("Вы хлопаете в ладоши.", me, "0x0000000000000001")
assert(CE.Log()[1].name == me and CE.Log()[1].key == "applaud" and not CE.Log()[1].shown, "own emote not shown")
assert(next(CE.Active()) == nil or not CE.Active()["player-self"], "nothing above you")
emote("Ева указывает на Боба.", "Ева", "0x0000000000000E01")
emote("Ева указывает на Боба.", "Ева", "0x0000000000000E01")
assert(settings.emoteUnknown[1] == "Ева указывает на Боба." and #settings.emoteUnknown == 1, "unknown kept once")
emote("Вася смеется.", "Вася", "0x0000000000000E09")
assert(CE.Log()[1].key == "laugh" and CE.Log()[1].shown == false, "no plate, no medallion")

-- 7. Cap: at most 8, the oldest go first, even within one frame.
for i = 1, 9 do
    local v = plateView("Танцор" .. i, "0x00000000000E1" .. i)
    views[#views + 1] = v
    emote("Танцор" .. i .. " танцует.", "Танцор" .. i, "0x00000000000E1" .. i)
end
etick(0.3)
local alive = 0
for _ in pairs(CE.Active()) do alive = alive + 1 end
assert(alive == 8 and medallion("0x00000000000E19") and not medallion("0x0000000000000E01"), "cap 8: " .. alive)

-- 8. Plate recycled: the medallion hides, then follows the speaker's new plate.
local dancer = medallion("0x00000000000E19")
local oldView = dancer.view
oldView.identityName, oldView.identityGUID = "Волк", "0xF130000000000E19"
etick(0.1)
assert(not dancer.shown, "hidden on a recycled plate")
local again = plateView("Танцор9", "0x00000000000E19")
views[#views + 1] = again
etick(0.1)
assert(dancer.shown and dancer.parent == again, "follows the new plate")

-- 9. Off (Skins checkbox): released and nothing new.
settings.emotesEnabled = false
CE.Apply()
assert(next(CE.Active()) == nil, "released when off")
emote("Ева смеется.", "Ева", "0x0000000000000E01")
assert(next(CE.Active()) == nil, "nothing while off")
settings.emotesEnabled = nil

-- 10. Preview cycles through the list; /fuiemote.
_G.targetName, _G.targetGUID = "Ева", "0x0000000000000E01"
SlashCmdList.FOREVERUIEMOTE("test dance")
assert(medallion("0x0000000000000E01").key == "dance", "test with a key")
SlashCmdList.FOREVERUIEMOTE("test")
assert(medallion("0x0000000000000E01").key == "laugh", "test cycles from the first emote")
_G.targetName, _G.targetGUID = nil, nil
local printedBefore = #printed
SlashCmdList.FOREVERUIEMOTE("test wave")
assert(#printed == printedBefore + 1 and printed[#printed]:find("плашкой", 1, true), "test without a target asks for one")
SlashCmdList.FOREVERUIEMOTE("")
local report = table.concat(printed, "\n")
assert(report:find("unknown=1", 1, true) and report:find("key=laugh", 1, true), "/fuiemote report")
SlashCmdList.FOREVERUIEMOTE("clear")
assert(settings.emoteUnknown == nil, "unknown list cleared")
etick(5)
assert(edriver.scripts.OnUpdate == nil, "emote OnUpdate removed when idle")

print("ChatEmotes: all tests passed")
