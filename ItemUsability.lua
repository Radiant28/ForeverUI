local _, ui = ...
-- Items the character cannot use (armour or weapon type, class, level, skill, reputation, a known recipe)
-- are painted red in the merchant, loot, bag and bank windows, as the stock client does at the merchant.
-- The verdict comes from the item tooltip: the client writes every unmet requirement in red
-- (RED_FONT_COLOR). It is cached per link and dropped when the character changes (level, skills,
-- reputation, spells, talents).
--
-- U.CannotUse(link)        true / false, or nil while the client has no data for the item yet
-- U.Paint(texture, red, r) paints the texture red (r, 0, 0; r defaults to 0.9) or takes back only the
--                          red it painted itself (a colour set by someone else since then is kept)
-- U.IsPainted(texture)     true while the texture carries the red of U.Paint
-- U.Retry(key, fn)         calls fn again a little later (item data still loading), at most a few times
-- U.OnChange(fn)           fn() after the cache is dropped (the character changed)

local U = {}
ui.ItemUsability = U

local RED_MIN, OTHER_MAX = 0.8, 0.3
local cache, painted = {}, {}
local scanner
local skipPrefixes = {}
-- Red lines that are no requirement: a broken item ("Прочность 0 / 50") can still be worn.
for _, template in ipairs({ DURABILITY_TEMPLATE or "" }) do
    local prefix = template:match("^(.-)%%") or template
    if prefix ~= "" then skipPrefixes[#skipPrefixes + 1] = prefix end
end

local function isRed(line)
    if not line then return false end
    local text = line:GetText()
    if not text or text == "" then return false end
    local r, g, b = line:GetTextColor()
    if not r or r < RED_MIN or g > OTHER_MAX or b > OTHER_MAX then return false end
    for _, prefix in ipairs(skipPrefixes) do
        if text:find(prefix, 1, true) == 1 then return false end
    end
    return true
end

local function tooltip()
    if not scanner then
        scanner = CreateFrame("GameTooltip", "ForeverStockUIUsabilityTooltip", UIParent, "GameTooltipTemplate")
        scanner:Hide()
    end
    return scanner
end

-- Only the client's own requirement lines count: other addons (Auctionator's price lines and others) write into
-- every item tooltip, ours included, sometimes in red, and every reagent in the bank was painted (checked in game).
-- Left lines: the requirement texts of the client (their part before the first %), and "Already known". Right
-- lines near the top: the armour or weapon type next to the slot ("Plate", "Polearm").
local requirementPrefixes, requirementWhole = {}, {}
local function addPrefix(format)
    if type(format) ~= "string" or format == "" then return end
    local prefix = format:match("^(.-)%%") or format
    prefix = prefix:gsub("%s+$", "")
    if #prefix >= 3 then requirementPrefixes[#requirementPrefixes + 1] = prefix end
end
for _, name in ipairs({ "ITEM_MIN_LEVEL", "ITEM_REQ_SKILL", "ITEM_MIN_SKILL", "ITEM_REQ_REPUTATION",
    "ITEM_REQ_ARENA_RATING", "ITEM_REQ_ARENA_RATING_3V3", "ITEM_REQ_ARENA_RATING_5V5", "ITEM_REQ_SPECIALIZATION",
    "ITEM_CLASSES_ALLOWED", "ITEM_RACES_ALLOWED", "ITEM_REQ_PURCHASE_GROUP" }) do
    addPrefix(_G[name])
end
for _, name in ipairs({ "ITEM_SPELL_KNOWN" }) do
    if type(_G[name]) == "string" then requirementWhole[_G[name]] = true end
end
-- Equip type on the right: within the first lines (name, binding, unique, slot / type).
local TYPE_LINES = 6

local function requirementLine(left, right, index)
    if isRed(left) then
        local text = left:GetText()
        if requirementWhole[text] then return true end
        for _, prefix in ipairs(requirementPrefixes) do
            if text:find(prefix, 1, true) == 1 then return true end
        end
    end
    return index <= TYPE_LINES and isRed(right)
end
U.RequirementLine = requirementLine

function U.CannotUse(link)
    if type(link) ~= "string" or link == "" then return false end
    local known = cache[link]
    if known ~= nil then return known end
    local name, _, _, _, minLevel = GetItemInfo(link)
    if not name then return nil end
    if minLevel and UnitLevel and minLevel > (UnitLevel("player") or 0) then
        cache[link] = true
        return true
    end
    local tip = tooltip()
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    tip:ClearLines()
    tip:SetHyperlink(link)
    local lines = tip:NumLines() or 0
    local prefix = tip:GetName()
    local red = false
    for index = 2, lines do
        if requirementLine(_G[prefix .. "TextLeft" .. index], _G[prefix .. "TextRight" .. index], index) then
            red = true
            break
        end
    end
    tip:Hide()
    if lines < 2 then return nil end          -- the tooltip is still empty: the server has not answered
    cache[link] = red
    return red
end

local function near(a, b) return a and b and a - b < 0.01 and b - a < 0.01 end
local function reddish(r, g, b) return r and r > 0.3 and g < 0.2 and b < 0.2 end

function U.Paint(texture, red, r)
    if not texture or not texture.SetVertexColor then return end
    local mark = painted[texture]
    local cr, cg, cb = texture:GetVertexColor()
    if red then
        r = r or 0.9
        if not mark then
            mark = {}
            painted[texture] = mark
        end
        if not mark[4] or not (near(cr, mark[4]) and near(cg, 0) and near(cb, 0)) then
            -- What was there before the red; the client's own red is no colour to come back to.
            if reddish(cr, cg, cb) then cr, cg, cb = 1, 1, 1 end
            mark[1], mark[2], mark[3] = cr or 1, cg or 1, cb or 1
        end
        mark[4] = r
        if not (near(cr, r) and near(cg, 0) and near(cb, 0)) then texture:SetVertexColor(r, 0, 0) end
    elseif mark then
        painted[texture] = nil
        if near(cr, mark[4]) and near(cg, 0) and near(cb, 0) then
            texture:SetVertexColor(mark[1], mark[2], mark[3])
        end
    end
end

function U.IsPainted(texture)
    return painted[texture] ~= nil
end

-- Retries: item data reaches the client a moment after the first look (a page of a merchant, new loot).
local retries = {}
local retryFrame = CreateFrame("Frame")
retryFrame:Hide()
local retryWait = 0
retryFrame:SetScript("OnUpdate", function(self, elapsed)
    retryWait = retryWait + elapsed
    if retryWait < 0.4 then return end
    retryWait = 0
    local left = false
    for key, entry in pairs(retries) do
        entry.left = entry.left - 1
        if entry.left <= 0 then retries[key] = nil else left = true end
        entry.fn()
    end
    if not left and not next(retries) then self:Hide() end
end)

function U.Retry(key, fn)
    local entry = retries[key]
    if entry then
        entry.fn = fn
        return
    end
    -- Up to ~6 s: right after a loading screen the client answers item tooltips late.
    retries[key] = { fn = fn, left = 15 }
    retryWait = 0
    retryFrame:Show()
end

local listeners = {}
function U.OnChange(fn) listeners[#listeners + 1] = fn end

function U.Reset()
    for link in pairs(cache) do cache[link] = nil end
    for _, fn in ipairs(listeners) do fn() end
end

-- /fuiusable: what the check sees for the item under the mouse (hover it, then type the command; or pass a link).
-- Prints the verdict, the level check and every coloured line of the scanned tooltip with its colour.
local function report(link)
    local print = function(text) DEFAULT_CHAT_FRAME:AddMessage("|cffe8c27aForever UI|r " .. text) end
    if not link and GameTooltip and GameTooltip.GetItem and GameTooltip:IsShown() then link = select(2, GameTooltip:GetItem()) end
    if not link then
        print("/fuiusable: hover an item (bag, merchant, loot) and type the command again.")
        return
    end
    cache[link] = nil
    local ok, verdict = pcall(U.CannotUse, link)
    local _, _, _, _, minLevel = GetItemInfo(link)
    print(("item %s: verdict=%s (ok=%s) minLevel=%s player=%s"):format(link, tostring(verdict), tostring(ok),
        tostring(minLevel), tostring(UnitLevel and UnitLevel("player"))))
    local tip = tooltip()
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    tip:ClearLines()
    tip:SetHyperlink(link)
    local prefix = tip:GetName()
    print(("scanner lines: %d"):format(tip:NumLines() or 0))
    for index = 1, tip:NumLines() or 0 do
        for _, side in ipairs({ "TextLeft", "TextRight" }) do
            local line = _G[prefix .. side .. index]
            local text = line and line:GetText()
            if text and text ~= "" then
                local r, g, b = line:GetTextColor()
                if not (r and r > 0.95 and g > 0.95 and b > 0.95) then
                    print(("  %d %s: %.2f %.2f %.2f%s %s"):format(index, side, r or -1, g or -1, b or -1,
                        isRed(line) and " RED" or "", (text:gsub("|", "||"))))
                end
            end
        end
    end
    tip:Hide()
end
U.Report = report
SLASH_FOREVERUIUSABLE1 = "/fuiusable"
SlashCmdList.FOREVERUIUSABLE = function(input)
    local link = input and input:match("|H.-|h.-|h") and input or nil
    report(link)
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED", "UPDATE_FACTION", "LEARNED_SPELL_IN_TAB",
    "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE" }) do
    pcall(events.RegisterEvent, events, event)
end
events:RegisterEvent("PLAYER_ENTERING_WORLD")
-- After a loading screen (hearthstone, instance) tooltips come back empty for a while and the red was lost: every
-- window is checked again 2 s later.
local reloadWait = CreateFrame("Frame")
reloadWait:Hide()
reloadWait:SetScript("OnUpdate", function(self, elapsed)
    self.left = (self.left or 0) - elapsed
    if self.left > 0 then return end
    self:Hide()
    U.Reset()
end)
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        reloadWait.left = 2
        reloadWait:Show()
        return
    end
    U.Reset()
end)
