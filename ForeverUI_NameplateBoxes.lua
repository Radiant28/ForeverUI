local _, ui = ...
local wfn = { specs = {}, order = {}, revision = 0 }
ui.wfn = wfn

WoWForeverNameplates = WoWForeverNameplates or {}
local API = WoWForeverNameplates
API.Version = "1.66.00-30300"

local specs, order = wfn.specs, wfn.order
local ru = ui.russian
local places = {
    { key = "arena", label = ru and "Арены" or "Arenas" },
    { key = "bg", label = ru and "Поля боя" or "Battlegrounds" },
    { key = "dungeon", label = ru and "Подземелья и рейды" or "Dungeons and raids" },
    { key = "world", label = ru and "Открытый мир" or "Open world" },
}
wfn.places = places

function wfn.Print(message)
    print("|cff66ccffWoW Forever Nameplates|r " .. tostring(message))
end

function wfn.Changed()
    wfn.revision = wfn.revision + 1
    if wfn.refreshOptions then pcall(wfn.refreshOptions) end
end

local function Resort()
    for i = #order, 1, -1 do order[i] = nil end
    for id in pairs(specs) do order[#order + 1] = id end
    table.sort(order, function(a, b)
        local left, right = specs[a], specs[b]
        if left.side ~= right.side then return left.side < right.side end
        if left.order ~= right.order then return left.order < right.order end
        return a < b
    end)
    wfn.Changed()
end

function wfn.LoadBoxes(db)
    wfn.db = db
    if type(db.boxOff) ~= "table" then db.boxOff = {} end
    if type(db.boxPlaces) ~= "table" then db.boxPlaces = {} end
    if type(db.boxOffset) ~= "table" then db.boxOffset = {} end
    for id, spec in pairs(specs) do
        if spec.enabled ~= nil then db.boxOff[id] = not spec.enabled or nil end
    end
end

function API:RegisterBox(id, spec)
    if type(id) ~= "string" or id == "" or type(spec) ~= "table" or type(spec.update) ~= "function" then
        return false
    end
    local rank = tonumber(spec.order)
    specs[id] = {
        owner = type(spec.owner) == "string" and spec.owner or "?",
        label = type(spec.label) == "string" and spec.label or id,
        side = (spec.side == "left" or spec.side == "above") and spec.side or "right",
        order = rank and rank == rank and rank or 50,
        places = type(spec.places) == "table" and spec.places or nil,
        update = spec.update, enabled = specs[id] and specs[id].enabled,
    }
    Resort()
    return true
end

function API:UnregisterBox(id)
    if not specs[id] then return false end
    specs[id] = nil
    Resort()
    return true
end

function API:IsBoxEnabled(id)
    local spec = specs[id]
    if not spec then return false end
    if wfn.db then return not wfn.db.boxOff[id] end
    return spec.enabled ~= false
end

function API:SetBoxEnabled(id, on)
    local spec = specs[id]
    if not spec then return false end
    spec.enabled = not not on
    if wfn.db then wfn.db.boxOff[id] = not on or nil end
    wfn.Changed()
    return true
end

local function PlaceEnabled(id, place)
    local spec = specs[id]
    if spec.places and spec.places[place] == nil then return nil end
    local saved = wfn.db and wfn.db.boxPlaces[id]
    if type(saved) == "table" and type(saved[place]) == "boolean" then return saved[place] end
    return not spec.places or not not spec.places[place]
end

function API:BoxPlaces(id)
    if not specs[id] then return end
    local offered, on = {}, {}
    for _, place in ipairs(places) do
        local enabled = PlaceEnabled(id, place.key)
        if enabled ~= nil then
            offered[#offered + 1] = place
            on[place.key] = enabled
        end
    end
    return offered, on
end

function API:SetBoxPlace(id, place, on)
    if not wfn.db or not specs[id] then return false end
    for _, entry in ipairs(places) do
        if entry.key == place and PlaceEnabled(id, place) ~= nil then
            local saved = wfn.db.boxPlaces[id]
            if type(saved) ~= "table" then saved = {}; wfn.db.boxPlaces[id] = saved end
            saved[place] = not not on
            wfn.Changed()
            return true
        end
    end
    return false
end

local function Offset(value)
    if type(value) ~= "number" or value ~= value then return 0 end
    return math.max(-2000, math.min(2000, value))
end

function API:BoxOffset(id)
    local offset = wfn.db and wfn.db.boxOffset[id]
    if type(offset) ~= "table" then return 0, 0 end
    return Offset(offset.x), Offset(offset.y)
end

function API:SetBoxOffset(id, x, y)
    if not wfn.db or not specs[id] then return false end
    x, y = Offset(x), Offset(y)
    local oldX, oldY = self:BoxOffset(id)
    if x == oldX and y == oldY then return true end
    local offset = wfn.db.boxOffset[id]
    if x == 0 and y == 0 then
        wfn.db.boxOffset[id] = nil
    elseif type(offset) == "table" then
        offset.x, offset.y = x, y
    else
        wfn.db.boxOffset[id] = { x = x, y = y }
    end
    wfn.Changed()
    return true
end

function API:ResetBoxOffsets()
    if wfn.db then wfn.db.boxOffset = {} end
    wfn.Changed()
end

function API:GetPlateInfo(plate)
    return wfn.infoFor and wfn.infoFor(plate)
end

function API:IsPreviewing()
    return wfn.previewing ~= nil
end

function wfn.ShowsHere(id, place)
    return API:IsBoxEnabled(id) and PlaceEnabled(id, place) == true
end

function wfn.Place(kind)
    if kind == "arena" then return "arena" end
    if kind == "pvp" then return "bg" end
    if kind == "party" or kind == "raid" then return "dungeon" end
    return "world"
end

local levelWant = { colour = { 1, 1, 1 } }
API:RegisterBox("wfn-level", {
    owner = "WoW Forever Nameplates", label = ru and "Уровень" or "Level", side = "right", order = 10,
    update = function(box)
        local level = box.view.displayLevel
        if not wfn.db.level or not level then return end
        local color = level > 0 and GetQuestDifficultyColor(level)
        levelWant.text = level > 0 and level or "??"
        levelWant.colour[1], levelWant.colour[2], levelWant.colour[3] =
            color and color.r or 1, color and color.g or 0.2, color and color.b or 0.15
        return levelWant
    end,
})
