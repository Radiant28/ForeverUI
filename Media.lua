local _, ui = ...
local ru = ui.russian
local fadeLeft = "Interface\\AddOns\\ForeverUI\\Art\\FadeLeft"
local fadeRight = "Interface\\AddOns\\ForeverUI\\Art\\FadeRight"
local foreverUnitFill = "Interface\\AddOns\\ForeverUI\\Art\\UnitBar-Fill"
ui.foreverCastFill = "Interface\\AddOns\\ForeverUI\\Art\\CastBar-Fill"

local builtins = {
    font = {
        names = { "Friz Quadrata", "Arial Narrow", "Morpheus" },
        paths = { STANDARD_TEXT_FONT, "Fonts\\ARIALN.TTF", "Fonts\\MORPHEUS.TTF" },
    },
    statusbar = {
        names = ru and { "Штатная", "WoW: Forever", "Гладкая" } or { "Classic", "WoW: Forever", "Flat" },
        paths = { "Interface\\TargetingFrame\\UI-StatusBar", ui.foreverCastFill, "Interface\\Buttons\\WHITE8X8" },
    },
    unitbar = {
        names = { ru and "Зеркальный градиент" or "Mirrored fade", "WoW: Forever", "Fade Left", "Fade Right" },
        paths = { foreverUnitFill, foreverUnitFill, fadeLeft, fadeRight },
        default = 3,
        mediaType = "statusbar",
    },
    background = {
        names = { "WoW: Forever" },
        paths = { "Interface\\Buttons\\WHITE8X8" },
    },
    meterbackground = {
        names = ru and { "Вертикальный градиент", "Тёмный фон" } or { "Vertical gradient", "Dark background" },
        paths = { "Interface\\AddOns\\ForeverUI\\Art\\Meter-Background", "Interface\\Tooltips\\UI-Tooltip-Background" },
        mediaType = "background",
    },
    meterbar = {
        names = ru and { "Вертикальный градиент", "Гладкая", "Штатная" } or { "Vertical gradient", "Flat", "Classic" },
        paths = { "Interface\\AddOns\\ForeverUI\\Art\\Meter-Bar", "Interface\\Buttons\\WHITE8X8",
            "Interface\\TargetingFrame\\UI-StatusBar" },
        mediaType = "statusbar",
    },
    border = {
        names = { "WoW: Forever" },
        paths = { "Interface\\AddOns\\ForeverUI\\Art\\UnitFrame-Edge" },
    },
}

local function sharedMedia()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

function ui.MediaPath(kind, selection, ignoreGlobal)
    local media = builtins[kind]
    local mediaType = media.mediaType or kind
    local registry = sharedMedia()
    local bundled = ui.bundledMedia[mediaType]
    local registered = registry and registry:HashTable(mediaType)
    if ignoreGlobal then
        return media.paths[selection] or bundled[selection] or (registered and registered[selection])
    end
    local key = registry and registry:GetGlobal(mediaType) or (type(selection) == "string" and selection)
    local path = key and (bundled[key] or (registered and registered[key]))
    local paths = media.paths
    return path or paths[selection] or paths[media.default or 1]
end

function ui.UnitBarFill(frame, selection)
    if selection == 1 then
        if frame == PlayerFrame then
            selection = 3
        elseif frame == TargetFrame then
            selection = 4
        end
    end
    return ui.MediaPath("unitbar", selection)
end

function ui.MediaDefault(kind)
    return builtins[kind].default or 1
end

function ui.MediaHasIndex(kind, value)
    return builtins[kind].names[value] ~= nil
end

-- Dropdown entries { value, label, font = path | texture = path } for the widget factory.
function ui.MediaItems(kind, ignoreGlobal)
    local media = builtins[kind]
    local mediaType = media.mediaType or kind
    local items, seen = {}, {}
    local function add(value, label)
        local path = ui.MediaPath(kind, value, true)
        local item = { value, label }
        if mediaType == "font" then
            item.font = path
        elseif path and path ~= "" then
            item.texture = path
        end
        items[#items + 1] = item
    end
    for index, name in ipairs(media.names) do
        seen[name] = true
        if kind == "unitbar" and index == 1 then
            add(index, ("|T%s:11:28|t|T%s:11:28|t %s"):format(fadeLeft, fadeRight, name))
        else
            add(index, name)
        end
    end
    local registry = sharedMedia()
    for _, name in ipairs(registry and registry:List(mediaType) or {}) do
        if not seen[name] then add(name, name) end
    end
    return items
end

function ui.MediaPreview(kind, value)
    local media = builtins[kind]
    local path = ui.MediaPath(kind, value, true)
    if (media.mediaType or kind) == "font" then return { font = path } end
    if path and path ~= "" then return { texture = path } end
end

function ui.MediaLabel(kind, value, ignoreGlobal)
    local media = builtins[kind]
    local registry = sharedMedia()
    local active = not ignoreGlobal and registry and registry:GetGlobal(media.mediaType or kind)
    if active then return active end
    if type(value) == "string" then return value end
    return media.names[value] or media.names[media.default or 1]
end

-- Calls back when LibSharedMedia registers the selected file late or changes its global override.
function ui.WatchMedia(owner, kind, callback, isSelected, ignoreGlobal)
    local registry = sharedMedia()
    if not registry then return end
    local mediaType = builtins[kind].mediaType or kind
    registry.RegisterCallback(owner, "LibSharedMedia_Registered", function(_, registeredType, registered)
        if registeredType == mediaType and isSelected(registered) then callback() end
    end)
    registry.RegisterCallback(owner, "LibSharedMedia_SetGlobal", function(_, changedType)
        if not ignoreGlobal and changedType == mediaType then callback() end
    end)
end
