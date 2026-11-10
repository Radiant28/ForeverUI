-- Legacy control API (ui.Checkbox, ui.Slider, ui.MediaChoice, ui.Options) drawn by the widget factory.
-- Popups such as the Edit Mode toolbar and the item label editor keep their absolute layouts.
local _, ui = ...
local W = ui.Widgets

local legacyRows = {}

local function register(settings, key, row)
    _G["ForeverStockUI_" .. key] = row
    legacyRows[#legacyRows + 1] = { settings = settings, key = key, row = row }
end

-- Keeps legacy controls in sync when the same key changes from the options window.
ui.RegisterCallback("SettingChanged", function(_, key)
    for _, entry in ipairs(legacyRows) do
        if entry.key == key and entry.settings == ui.Settings() and entry.row:IsVisible() then entry.row:Refresh() end
    end
end, "Compat")

local function access(settings, key, default, apply)
    return {
        get = function() return settings[key] end,
        set = function(value)
            settings[key] = value
            apply()
            for _, entry in ipairs(legacyRows) do
                if entry.key == key and entry.settings == settings then entry.row:Refresh() end
            end
            ui.Fire("LegacySettingChanged", key, value)
        end,
        reset = default ~= nil and function()
            settings[key] = ui.CopyTable(default)
            apply()
            for _, entry in ipairs(legacyRows) do
                if entry.key == key and entry.settings == settings then entry.row:Refresh() end
            end
        end or nil,
        isDefault = function() return ui.SameValue(settings[key], default) end,
    }
end

function ui.Checkbox(panel, key, label, y, default, apply, settings)
    settings = settings or ui.Settings()
    if type(settings[key]) ~= "boolean" then settings[key] = default end
    local opt = { type = "toggle", key = key, label = label }
    local row = W.Toggle(panel, opt, access(settings, key, default, apply), 280)
    row:SetPoint("TOPLEFT", 16, y - 4)
    register(settings, key, row)
    function row:GetChecked() return settings[key] end
    function row:SetChecked(value) settings[key] = value and true or false; self:Refresh() end
    function row:Disable() self:SetEnabled(false) end
    function row:Enable() self:SetEnabled(true) end
    return row
end

function ui.Slider(panel, key, label, y, limits, apply, suffix, settings)
    local low, high, step, default = unpack(limits)
    settings = settings or ui.Settings()
    local value = settings[key]
    if not ui.IsFinite(value) then value = default end
    settings[key] = math.max(low, math.min(high, math.floor(value / step + 0.5) * step))
    local opt = { type = "range", key = key, label = label, min = low, max = high, step = step, suffix = suffix }
    local row = W.Range(panel, opt, access(settings, key, default, apply), 300)
    row:SetPoint("TOPLEFT", 16, y + 14)
    register(settings, key, row)
    row.foreverDefault = default
    function row:GetValue() return settings[key] end
    function row:SetValue(next) self.access.set(math.max(low, math.min(high, next))) end
    function row:GetMinMaxValues() return low, high end
    function row:GetValueStep() return step end
    function row:Disable() self:SetEnabled(false) end
    function row:Enable() self:SetEnabled(true) end
    return row
end

function ui.MediaChoice(panel, key, kind, x, y, apply, label, ignoreGlobal, settings)
    settings = settings or ui.Settings()
    local default = ui.MediaDefault(kind)
    local value = settings[key]
    if type(value) ~= "string" and not ui.MediaHasIndex(kind, value) then settings[key] = default end
    local opt = { type = "media", key = key, label = label or "", kind = kind, ignoreGlobal = ignoreGlobal }
    local row = W.Select(panel, opt, access(settings, key, default, apply), 160)
    row:SetPoint("TOPLEFT", x + 16, y)
    register(settings, key, row)
    ui.WatchMedia(row, kind, function()
        row:Refresh()
        apply()
    end, function(registered) return registered == settings[key] end, ignoreGlobal)
    return row
end

-- A legacy page: the frame is hosted by a custom section of its own module in the options window.
function ui.Options(title)
    local panel = CreateFrame("Frame", nil, UIParent)
    panel:Hide()
    local id = "legacy:" .. title
    panel.foreverModule = id
    ui.RegisterOptions(id, {
        title = title, group = "other", order = 900,
        sections = { { options = { { "custom", build = function(parent, width)
            panel:SetParent(parent)
            panel:ClearAllPoints()
            panel:SetPoint("TOPLEFT", -16, 16)
            panel:SetSize(width + 16, panel.legacyHeight or 460)
            panel:Show()
            return panel.legacyHeight or 460
        end } } } },
    })
    return panel
end
