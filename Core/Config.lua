-- ForeverUI configuration core: SavedVariables, option registry, defaults, live-apply callbacks
-- and the out-of-combat queue for protected frames. WotLK 3.3.5a (12340), Lua 5.1.
local addonName, ui = ...

ui.russian = GetLocale() == "ruRU"
function ui.L(russian, english) return ui.russian and russian or english end
local L = ui.L

local floor, abs, max, min = math.floor, math.abs, math.max, math.min

---------------------------------------------------------------------------------------------------
-- SavedVariables
---------------------------------------------------------------------------------------------------
local modules, moduleOrder = {}, {}
ui.optionModules, ui.optionOrder = modules, moduleOrder
local normalizedTable

local function mainDB()
    if type(ForeverStockUIDB) ~= "table" then ForeverStockUIDB = {} end
    return ForeverStockUIDB
end

local normalizeModule

-- The table identity changes once the client loads SavedVariables, so normalization runs again then.
function ui.Settings()
    local db = mainDB()
    if normalizedTable ~= db then
        normalizedTable = db
        for _, spec in ipairs(moduleOrder) do
            if not spec.db then normalizeModule(spec) end
        end
    end
    return db
end

---------------------------------------------------------------------------------------------------
-- Callbacks
---------------------------------------------------------------------------------------------------
local listeners = {}

function ui.RegisterCallback(event, fn, owner)
    listeners[event] = listeners[event] or {}
    listeners[event][owner or fn] = fn
end

function ui.UnregisterCallback(event, owner)
    if listeners[event] then listeners[event][owner] = nil end
end

local function safecall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then geterrorhandler()(err) end
    return ok
end
ui.SafeCall = safecall

function ui.Fire(event, ...)
    local set = listeners[event]
    if not set then return end
    for _, fn in pairs(set) do safecall(fn, ...) end
end

---------------------------------------------------------------------------------------------------
-- Combat queue: protected frames are touched only after PLAYER_REGEN_ENABLED.
---------------------------------------------------------------------------------------------------
local queue, queueOrder = {}, {}
local queueFrame = CreateFrame("Frame")

function ui.RunOutOfCombat(token, fn)
    if not InCombatLockdown() then
        safecall(fn)
        return true
    end
    if not queue[token] then queueOrder[#queueOrder + 1] = token end
    queue[token] = fn
    queueFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    ui.Fire("CombatQueued", token)
    return false
end

function ui.HasCombatQueue() return #queueOrder > 0 end

queueFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local tokens = queueOrder
    queueOrder = {}
    for _, token in ipairs(tokens) do
        local fn = queue[token]
        queue[token] = nil
        if fn then safecall(fn) end
    end
    ui.Fire("CombatQueueFlushed")
end)

---------------------------------------------------------------------------------------------------
-- Value helpers
---------------------------------------------------------------------------------------------------
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = copy(v) end
    return result
end
ui.CopyTable = copy

local function finite(value)
    return type(value) == "number" and value == value and abs(value) ~= math.huge
end
ui.IsFinite = finite

local function snap(value, low, step)
    if not step or step <= 0 then return value end
    value = low + floor((value - low) / step + 0.5) * step
    return floor(value * 10000 + 0.5) / 10000
end

function ui.ResolveDefault(opt)
    local value = opt.default
    if type(value) == "function" then value = value() end
    return copy(value)
end

local function validColor(value)
    if type(value) ~= "table" then return false end
    for i = 1, 3 do
        local channel = value[i]
        if not finite(channel) or channel < 0 or channel > 1 then return false end
    end
    return value[4] == nil or (finite(value[4]) and value[4] >= 0 and value[4] <= 1)
end

local function selectValues(opt)
    local values = opt.values
    if type(values) == "function" then values = values() end
    return values or {}
end
ui.OptionValues = selectValues

-- Returns a valid stored value for the option, or nil when the value has to be replaced.
local function validate(opt, value)
    local kind = opt.type
    if kind == "toggle" then
        if type(value) == "boolean" then return value end
    elseif kind == "range" then
        if finite(value) then
            local low, high = opt.min, opt.max
            if type(low) == "function" then low = low() end
            if type(high) == "function" then high = high() end
            return snap(max(low, min(high, value)), low, opt.step)
        end
    elseif kind == "select" then
        for _, item in ipairs(selectValues(opt)) do
            if item[1] == value then return value end
        end
    elseif kind == "media" then
        if type(value) == "string" or finite(value) then return value end
    elseif kind == "color" then
        if validColor(value) then
            if opt.alpha and value[4] == nil then value[4] = 1 end
            return value
        end
    elseif kind == "text" then
        if type(value) == "string" then return value end
    end
end
ui.ValidateOption = validate

---------------------------------------------------------------------------------------------------
-- Registry
---------------------------------------------------------------------------------------------------
local storedTypes = { toggle = true, range = true, select = true, media = true, color = true, text = true }

local function optionDB(spec, opt)
    local source = opt.db or spec.db
    if source then
        local db = source()
        return type(db) == "table" and db or nil
    end
    return mainDB()
end

-- Split colours keep the channels in separate keys (prefix .. "R"), as CursorUZ did.
local function readRaw(db, opt)
    if opt.split then
        local key = opt.key
        local r, g, b, a = db[key .. "R"], db[key .. "G"], db[key .. "B"], db[key .. "A"]
        if r == nil then return nil end
        return { r, g, b, opt.alpha and a or nil }
    end
    return db[opt.key]
end

local function writeRaw(db, opt, value)
    if opt.split then
        local key = opt.key
        db[key .. "R"], db[key .. "G"], db[key .. "B"] = value[1], value[2], value[3]
        if opt.alpha then db[key .. "A"] = value[4] end
        return
    end
    db[opt.key] = value
end

normalizeModule = function(spec)
    for _, opt in ipairs(spec.options) do
        if storedTypes[opt.type] and opt.default ~= nil and not opt.noNormalize then
            local db = optionDB(spec, opt)
            if db then
                local value = validate(opt, readRaw(db, opt))
                if value == nil then value = ui.ResolveDefault(opt) end
                writeRaw(db, opt, value)
            end
        end
    end
end

-- Schemas use positional fields for brevity: { "range", "key", "Label", min = 0, max = 1 }.
local function prepareOption(spec, opt, section)
    opt.type = opt.type or opt[1]
    if storedTypes[opt.type] then
        opt.key = opt.key or opt[2]
        opt.label = opt.label or opt[3]
    else
        -- Buttons, headers, descriptions and custom blocks store nothing: { "button", "Label", func = ... }.
        opt.label = opt.label or opt[2]
    end
    opt.section = section
    opt.module = spec
    -- Sections may share an apply function, a dependency or the protected flag with their options.
    if opt.apply == nil then opt.apply = section.apply end
    if opt.depends == nil then opt.depends = section.depends end
    if opt.protected == nil then opt.protected = section.protected end
    if opt.key and storedTypes[opt.type] then
        spec.byKey[opt.key] = opt
    end
    spec.options[#spec.options + 1] = opt
end

--[[ ui.RegisterOptions(id, spec)
spec = {
    title, description, icon, group, order,
    db = function() return table end,     -- default: ForeverStockUIDB
    enable = "key",                        -- master toggle: disables every other control when false
    apply = function(key, value) end,      -- live apply for the whole module
    protected = true,                      -- apply through the out-of-combat queue
    unavailable = function() return reason end,
    sections = { { title, description, options = { { type, key, label, default = ..., ... } } } },
}
Option fields: tooltip, default, apply, protected, reload, depends ("key" | "!key" | function(get)),
width ("full"), min/max/step/suffix/format (range), values = { { value, label }, ... } (select),
kind/ignoreGlobal (media), alpha/split (color), func (button), build(parent, width) -> height (custom). ]]
function ui.NormalizeModule(id)
    local spec = modules[id]
    if spec then normalizeModule(spec) end
end

function ui.RegisterOptions(id, spec)
    spec.id = id
    spec.options, spec.byKey = {}, {}
    spec.order = spec.order or 100
    spec.sections = spec.sections or {}
    for _, section in ipairs(spec.sections) do
        for _, opt in ipairs(section.options or {}) do prepareOption(spec, opt, section) end
    end
    if modules[id] then
        for index, existing in ipairs(moduleOrder) do
            if existing.id == id then table.remove(moduleOrder, index) break end
        end
    end
    modules[id] = spec
    moduleOrder[#moduleOrder + 1] = spec
    table.sort(moduleOrder, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.id < b.id
    end)
    if normalizedTable or spec.db then normalizeModule(spec) end
    ui.Fire("ModuleRegistered", id)
    return spec
end

function ui.GetModule(id) return modules[id] end

local function findOption(id, key)
    local spec = modules[id]
    return spec, spec and spec.byKey[key]
end
ui.FindOption = findOption

function ui.GetOption(id, key)
    local spec, opt = findOption(id, key)
    if not opt then return end
    local db = optionDB(spec, opt)
    local value = db and validate(opt, readRaw(db, opt))
    if value == nil then value = ui.ResolveDefault(opt) end
    return value
end

function ui.GetDefault(id, key)
    local _, opt = findOption(id, key)
    return opt and ui.ResolveDefault(opt)
end

local function same(a, b)
    if type(a) == "number" and type(b) == "number" then return abs(a - b) < 0.00001 end
    if type(a) == "table" and type(b) == "table" then
        for i = 1, max(#a, #b) do
            if not same(a[i] or 1, b[i] or 1) then return false end
        end
        return true
    end
    return a == b
end
ui.SameValue = same

function ui.IsDefault(id, key)
    return same(ui.GetOption(id, key), ui.GetDefault(id, key))
end

local reloadPending
function ui.IsReloadPending() return reloadPending end

local function applyFunction(spec, opt)
    if opt.apply == false then return nil end
    return opt.apply or spec.apply
end

local function runApply(spec, opt, value)
    local fn = applyFunction(spec, opt)
    if not fn then return end
    local key = opt.key
    local token = spec.id .. ":" .. (opt.apply and key or "*")
    if (opt.protected or spec.protected) and InCombatLockdown() then
        ui.RunOutOfCombat(token, function() fn(key, ui.GetOption(spec.id, key)) end)
        return
    end
    safecall(fn, key, value)
end

function ui.SetOption(id, key, value, silent)
    local spec, opt = findOption(id, key)
    if not opt then return end
    local db = optionDB(spec, opt)
    if not db then return end
    value = validate(opt, copy(value))
    if value == nil then value = ui.ResolveDefault(opt) end
    local previous = readRaw(db, opt)
    writeRaw(db, opt, value)
    if silent then return value end
    if opt.reload and not same(previous, value) and not reloadPending then
        reloadPending = true
        ui.Fire("ReloadPending")
    end
    runApply(spec, opt, value)
    ui.Fire("SettingChanged", id, key, value)
    return value
end

function ui.ResetOption(id, key)
    return ui.SetOption(id, key, ui.GetDefault(id, key))
end

function ui.ResetModule(id)
    local spec = modules[id]
    if not spec then return end
    local applied = {}
    for _, opt in ipairs(spec.options) do
        if storedTypes[opt.type] and opt.default ~= nil and not opt.noReset then
            local db = optionDB(spec, opt)
            if db then writeRaw(db, opt, ui.ResolveDefault(opt)) end
        end
    end
    -- Run each distinct apply function once after every value is back to default.
    for _, opt in ipairs(spec.options) do
        local fn = applyFunction(spec, opt)
        if fn and storedTypes[opt.type] and not applied[fn] then
            applied[fn] = true
            if opt.reload and not reloadPending then
                reloadPending = true
                ui.Fire("ReloadPending")
            end
            runApply(spec, opt, ui.GetOption(id, opt.key))
        end
    end
    if spec.onReset then safecall(spec.onReset) end
    ui.Fire("ModuleReset", id)
end

-- The master switch of a module, when the schema declares one.
function ui.IsModuleEnabled(id)
    local spec = modules[id]
    if not spec or not spec.enable then return true end
    return ui.GetOption(id, spec.enable) ~= false
end

function ui.IsOptionAvailable(spec, opt)
    if spec.enable and opt.key ~= spec.enable and not opt.ignoreEnable and not ui.IsModuleEnabled(spec.id) then
        return false
    end
    local depends = opt.depends
    if not depends then return true end
    local get = function(key) return ui.GetOption(spec.id, key) end
    if type(depends) == "function" then return depends(get) and true or false end
    if depends:sub(1, 1) == "!" then return not get(depends:sub(2)) end
    return get(depends) and true or false
end

---------------------------------------------------------------------------------------------------
-- Binding: an object with the slider API that EditMode expects, backed by an option.
---------------------------------------------------------------------------------------------------
function ui.OptionBinding(id, key)
    local binding = {}
    local function opt() return select(2, findOption(id, key)) end
    local function limit(value)
        if type(value) == "function" then return value() end
        return value
    end
    function binding:GetMinMaxValues()
        local o = opt()
        return limit(o.min), limit(o.max)
    end
    function binding:GetValueStep() return opt().step or 1 end
    function binding:GetValue() return ui.GetOption(id, key) end
    function binding:SetValue(value) ui.SetOption(id, key, value) end
    function binding:Disable() end
    return setmetatable(binding, { __index = function(_, field)
        if field == "foreverDefault" then return ui.GetDefault(id, key) end
    end })
end

---------------------------------------------------------------------------------------------------
-- Shared option value lists
---------------------------------------------------------------------------------------------------
ui.OutlineValues = {
    { "", L("Без обводки", "None") },
    { "OUTLINE", L("Тонкая", "Thin") },
    { "THICKOUTLINE", L("Толстая", "Thick") },
}

ui.Groups = {
    { id = "general", title = L("Общее", "General") },
    { id = "frames", title = L("Рамки и панели", "Frames and bars") },
    { id = "combat", title = L("Бой", "Combat") },
    { id = "items", title = L("Предметы", "Items") },
    { id = "social", title = L("Чат", "Chat") },
}

function ui.Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffe8c27aForever UI|r " .. message)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
    if name ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    ui.Settings()
    ui.Fire("ConfigLoaded")
end)
