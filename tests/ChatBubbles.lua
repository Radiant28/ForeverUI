-- ChatBubbles.lua: own bubbles above ForeverUI plates and restyled client bubbles. Run from the addon root (INDEX.md).
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
    function f:GetEffectiveScale()
        local s, p = 1, self
        while p do s = s * (p.scale or 1); p = p.parent end
        return s
    end
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

-- 0. Removed settings are forgotten on ConfigLoaded; only bubblesEnabled stays.
for _, fn in ipairs(callbacks.ConfigLoaded or {}) do fn() end
assert(settings.bubblesLook == nil and settings.bubblesMax == nil and settings.bubblesFontSize == nil, "old keys wiped")

-- 1. Art: every file exists as an uncompressed 32-bit TGA with power-of-two sides.
local function pow2(v) return v > 0 and v == 2 ^ math.floor(math.log(v) / math.log(2) + 0.5) end
for _, name in ipairs({ "Frame", "Glow", "Tail", "Gem", "Crystal" }) do
    local path = "Art/Bubbles/Bubble-" .. name .. CB.LOOK.index .. ".tga"
    local file = assert(io.open(path, "rb"), "missing " .. path)
    local header = file:read(18)
    file:close()
    local w, h = header:byte(13) + header:byte(14) * 256, header:byte(15) + header:byte(16) * 256
    assert(header:byte(3) == 2 and header:byte(17) == 32 and pow2(w) and pow2(h), path .. ": 32-bit, power of two")
end

-- 2. Say above a player's plate: parent, anchor, bronze chrome, gem in the channel colour, faint glow.
local look = CB.LOOK
local alice = plateView("Алиса", "0x0000000000000001")
views[1] = alice
fire("CHAT_MSG_SAY", "Привет", "Алиса", "0x0000000000000001")
local b = bubbleOf("0x0000000000000001")
local c = b.chrome
assert(b and b.view == alice and b.parent == WorldFrame and b.kind == "say",
    "say bubble on the speaker's plate, parented to WorldFrame so the plate's fade does not dim it")
assert(b.text.text == "Привет" and b.anchor == alice.name, "anchored above the name")
assert(c.frame[1].texture:find("Bubble%-Frame2$") and c.glow[5].texture:find("Bubble%-Glow2$")
    and c.tail.texture:find("Bubble%-Tail2$") and c.bezel.texture:find("Bubble%-Gem2$")
    and c.crystal.texture:find("Bubble%-Crystal2$"), "bronze, dark stone files")
assert(c.frame[1].width == 18 and c.frame[1].coords[2] == look.u and c.frame[9].coords[4] == 1, "corner slice")
assert(c.frame[5].coords[1] == look.u and c.frame[5].coords[3] == look.v, "centre slice stretches")
assert(c.crystal.color[1] == 1 and c.crystal.color[2] == 0.84 and c.bezel.color[2] == 1, "gem tinted, bezel not")
assert(math.abs(c.glow[1].color[4] - 0.22) < 1e-6, "faint channel glow")
assert(b.width == #"Привет" * 6 + 1 + 2 * (look.inset + 5) and b.height == 15 + 2 * (look.inset + 3),
    "padded inside the border: " .. b.width .. "x" .. b.height)
assert(b.strata == "LOW" and b.level == alice.level + 20, "regular layer above the plates")
assert(b.alpha == 0 and b.points[1][5] < look.tail + 2, "starts invisible and lower")
tick(0.25)
assert(b.alpha == 1 and b.scale == 1 and b.rise == 0 and b.points[1][5] == look.tail + 2, "intro finished")
assert(c.frame[5].color[4] == 0.92 and c.tail.color[4] == 0.92, "nearly opaque background")
alice.scale = 0.8
tick(0.3)
assert(math.abs(b.scale - 0.8) < 1e-6 and b.alpha == 1, "follows the plate's scale, not its fade")
alice.scale = 1
tick(0.35)
assert(b.scale == 1, "scale back with the plate")

-- 3. Size: a tiny message keeps two corners and the gem; long text wraps at 220 px.
fire("CHAT_MSG_SAY", "!", "Алиса", "0x0000000000000001")
assert(bubbleOf("0x0000000000000001") == b and b.width == 2 * 18 + 14 and b.height == 37, "minimum box: "
    .. b.width .. "x" .. b.height)
fire("CHAT_MSG_SAY", string.rep("слово ", 40), "Алиса", "0x0000000000000001")
assert(b.width == 220 + 2 * (look.inset + 5) and b.height > 12 * 3, "long text wraps")

-- 4. Auras: above the aura row, also when they appear after the intro.
tick(0.3)
alice[2]:Show()
tick(0.05)
assert(b.anchor == alice.auraRow, "re-anchored above auras")
alice[2]:Hide()
tick(0.05)
assert(b.anchor == alice.name, "back above the name")

-- 5. Yell: red gem, larger text, glow flash that settles; also when it replaces an older message.
local bob = plateView("Боб", "0x0000000000000002")
views[2] = bob
fire("CHAT_MSG_SAY", "Привет", "Боб", "0x0000000000000002")
tick(0.5)
fire("CHAT_MSG_YELL", "Атака!", "Боб", "0x0000000000000002")
local y = bubbleOf("0x0000000000000002")
tick(0.05)
assert(y.kind == "yell" and y.text.font[2] == 14 and y.chrome.crystal.color[2] == 0.3, "yell style")
assert(y.chrome.glow[1].color[4] > 0.5, "yell flash on a replaced bubble")
tick(0.4)
assert(math.abs(y.chrome.glow[1].color[4] - 0.22) < 1e-6, "flash settles")

-- 6. Mention: bright gold glow and the top layer; the target's bubble is on top too.
fire("CHAT_MSG_SAY", "Ксандр, иди сюда", "Боб", "0x0000000000000002")
assert(y.mention and y.strata == "MEDIUM" and y.chrome.crystal.color[2] == 0.82
    and math.abs(y.chrome.glow[1].color[4] - 0.65) < 1e-6 and y.chrome.glow[1].color[2] == 0.82, "mention")
alice.priority = "target"
fire("CHAT_MSG_SAY", "Цель говорит", "Алиса", "0x0000000000000001")
assert(b.strata == "MEDIUM", "target bubble on top")
alice.priority = nil

-- 7. Duration follows reading speed and the bubble expires.
assert(CB.Duration("Привет") == 3.5, "short message keeps the minimum")
assert(math.abs(CB.Duration(string.rep("а", 150)) - (1.5 + 10)) < 1e-6, "150 letters at 15/s")
assert(CB.Duration(string.rep("а", 600)) == 14, "capped")
fire("CHAT_MSG_SAY", "Пока", "Алиса", "0x0000000000000001")
tick(3.2)
assert(b.alpha > 0 and b.alpha < 1, "fading out near the end")
tick(0.5)
assert(not bubbleOf("0x0000000000000001") and not b.shown, "expired and released")

-- 8. Raid icons; pooled frame reused.
fire("CHAT_MSG_SAY", "Бей {звезда}!", "Алиса", "0x0000000000000001")
assert(bubbleOf("0x0000000000000001").text.text:find("UI-RaidTargetingIcon_1:0|t", 1, true), "raid icon tag")
local reused = bubbleOf("0x0000000000000001")
assert(reused == b or reused == y, "a pooled frame is reused")
b = reused

-- 9. No plate: no own bubble, the log records it.
fire("CHAT_MSG_SAY", "Я далеко", "Вася", "0x0000000000000009")
assert(not bubbleOf("0x0000000000000009") and CB.Log()[1].name == "Вася" and CB.Log()[1].bubble == false, "logged")

-- 10. Plate recycled for another unit: hidden, back when the speaker's plate returns.
alice.identityName, alice.identityGUID = "Волк", "0xF130000000000001"
tick(0.1)
assert(not b.shown, "hidden on a recycled plate")
local alice2 = plateView("Алиса", "0x0000000000000001")
views[3] = alice2
tick(0.3)
assert(b.shown and b.view == alice2 and b.parent == WorldFrame, "moved to the speaker's new plate")

-- 11. Party (blue) and NPC speech by name (no GUID).
fire("CHAT_MSG_PARTY", "Группа", "Боб", "0x0000000000000002")
local p = bubbleOf("0x0000000000000002")
assert(p.kind == "party" and p.chrome.crystal.color[3] == 1, "party blue")
local npc = plateView("Стражник", nil)
views[4] = npc
fire("CHAT_MSG_MONSTER_SAY", "Стой!", "Стражник", "")
assert(bubbleOf("Стражник") and bubbleOf("Стражник").kind == "npc", "npc speech by name")

-- 11b. Every chat: numbered channels (LFG, trade, own), raid warning, battleground, guild, officer, whispers.
local function fireChannel(text, sender, guid, zoneID, baseName, channelString)
    driver.scripts.OnEvent(driver, "CHAT_MSG_CHANNEL", text, sender, "", channelString or "", "", "", zoneID, 4,
        baseName or "", 0, 1, guid)
end
for _, event in ipairs({ "CHAT_MSG_CHANNEL", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_BATTLEGROUND",
    "CHAT_MSG_BATTLEGROUND_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_WHISPER" }) do
    assert(driver.events[event], event .. " registered")
end
local bob = "0x0000000000000002"
fireChannel("Ищу танка в ЦЛК", "Боб", bob, 26, "ПоискСпутников", "4. Поиск спутников")
assert(bubbleOf(bob).kind == "channel" and bubbleOf(bob).raw == "Ищу танка в ЦЛК", "lfg channel")
fireChannel("Продам руду", "Боб", bob, 2, "Торговля", "2. Торговля - Даларан")
assert(bubbleOf(bob).raw == "Продам руду", "trade channel")
fireChannel("Свой канал", "Боб", bob, 0, "мой", "5. мой")
assert(bubbleOf(bob).raw == "Свой канал", "own channel")
for event, kind in pairs({ CHAT_MSG_RAID_WARNING = "warning", CHAT_MSG_BATTLEGROUND = "bg",
    CHAT_MSG_BATTLEGROUND_LEADER = "bg", CHAT_MSG_GUILD = "guild", CHAT_MSG_OFFICER = "officer",
    CHAT_MSG_WHISPER = "whisper", CHAT_MSG_RAID = "raid", CHAT_MSG_RAID_LEADER = "raid",
    CHAT_MSG_PARTY_LEADER = "party" }) do
    fire(event, "Текст " .. event, "Боб", bob)
    assert(bubbleOf(bob).kind == kind and bubbleOf(bob).raw == "Текст " .. event, event)
end
fire("CHAT_MSG_GUILD", "Гильдия", "Боб", bob)
assert(bubbleOf(bob).text.font[2] == 12, "normal size")
fire("CHAT_MSG_RAID_WARNING", "Все из огня!", "Боб", bob)
assert(bubbleOf(bob).flashAt and bubbleOf(bob).text.font[2] == 14, "raid warning is loud")
fire("CHAT_MSG_PARTY", "Группа", "Боб", bob)

-- 12. Cap of 6: the oldest leave first.
for i = 1, 6 do
    local v = plateView("Игрок" .. i, "0x00000000000001" .. i)
    views[#views + 1] = v
    fire("CHAT_MSG_SAY", "Сообщение " .. i, "Игрок" .. i, "0x00000000000001" .. i)
end
tick(0.3)
local alive = 0
for _ in pairs(CB.Active()) do alive = alive + 1 end
assert(alive == 6, "cap applied: " .. alive)
-- All six came in the same frame (same GetTime): arrival order still keeps the newest.
assert(bubbleOf("0x000000000000016") and bubbleOf("0x000000000000011"), "newest kept, oldest of the batch kept")
assert(not bubbleOf("0x0000000000000001"), "the oldest bubble left first")

-- 13. Client bubbles: bronze chrome, gem from the client's text colour, duplicates muted.
local native = frame("Frame", WorldFrame)
local bg = native:CreateTexture(); bg:SetTexture("Interface\\Tooltips\\ChatBubble-Background")
local text = native:CreateFontString(); text:SetText("Я тут"); text:SetTextColor(1, 0.25, 0.25)
fire("CHAT_MSG_SAY", "Я тут", me, "0x0000000000000099")
tick(0.15)
local n = CB.Natives()[native]
assert(n and n.skinned and bg.texture == nil and n.chrome.shown, "client bubble in bronze")
assert(n.chrome.crystal.color[1] == 1 and n.chrome.crystal.color[2] == 0.25, "gem from the client's text colour")
assert(native.alpha == 1, "no own bubble with this text: stays visible")
text:SetText("Сообщение 6")
tick(0.15)
assert(native.alpha == 0 and n.muted, "duplicate muted")
text:SetText("Другое")
fire("CHAT_MSG_SAY", "Другое", me, "0x0000000000000099")
tick(0.15)
assert(native.alpha == 1 and not n.muted, "unmuted for a new message")

-- 14. Off (checkbox on the Skins page): everything released, client look restored, nothing drawn.
settings.bubblesEnabled = false
CB.Apply()
assert(next(CB.Active()) == nil, "released when off")
assert(not n.skinned and not n.chrome.shown and bg.texture == "Interface\\Tooltips\\ChatBubble-Background",
    "client look restored")
fire("CHAT_MSG_SAY", "Тихо", "Алиса", "0x0000000000000001")
assert(next(CB.Active()) == nil, "nothing while off")
settings.bubblesEnabled = true
CB.Apply()
assert(n.skinned and n.chrome.shown, "client bubble in bronze again")

-- 15. Plates off: no own bubbles.
ui.wfn.active = nil
fire("CHAT_MSG_SAY", "Нет плашек", "Алиса", "0x0000000000000001")
assert(not bubbleOf("0x0000000000000001") and CB.Log()[1].plates == false, "needs the ForeverUI plates")
ui.wfn.active = true

-- 16. Preview and /fuibubble.
_G.targetName, _G.targetGUID = "Алиса", "0x0000000000000001"
SlashCmdList.FOREVERUIBUBBLE("test")
assert(bubbleOf("0x0000000000000001"), "preview above the target")
_G.targetName, _G.targetGUID = nil, nil
SlashCmdList.FOREVERUIBUBBLE("")
local report = table.concat(printed, "\n")
assert(report:find("native shown=true", 1, true) and report:find("event SAY", 1, true), "/fuibubble report")

-- 17. Driver sleeps when nothing is left.
tick(40)
assert(driver.scripts.OnUpdate == nil, "OnUpdate removed when idle")

print("ChatBubbles: all tests passed")
