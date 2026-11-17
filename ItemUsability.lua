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
        if isRed(_G[prefix .. "TextLeft" .. index]) or isRed(_G[prefix .. "TextRight" .. index]) then
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
    retries[key] = { fn = fn, left = 6 }
    retryWait = 0
    retryFrame:Show()
end

local listeners = {}
function U.OnChange(fn) listeners[#listeners + 1] = fn end

function U.Reset()
    for link in pairs(cache) do cache[link] = nil end
    for _, fn in ipairs(listeners) do fn() end
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED", "UPDATE_FACTION", "LEARNED_SPELL_IN_TAB",
    "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", U.Reset)
