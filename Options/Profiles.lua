-- Profiles of the combat suite (Cooldown Manager groups, raid frame settings and indicators,
-- click-cast bindings): switch, create, copy, rename, delete, bind to talent specs, and move them
-- between characters or players as an import/export string.
local _, ui = ...
local L, W, S = ui.L, ui.Widgets, ui.Style

local function build(parent, width)
    local suite, su = ui.Suite, ui.SuiteUI
    if not suite or not su then return su and su.Unavailable(parent, width) or 20 end
    local refresh
    local state = { export = { cdm = true, raid = true, clicks = true } }

    local function names()
        local values = {}
        for _, name in ipairs(suite.ProfileNames()) do values[#values + 1] = { name, name } end
        return values
    end
    local profileAccess = {
        get = function() return suite.ActiveProfileName() end,
        set = function(value)
            suite.SetProfile(value)
            refresh()
        end,
    }
    local y = 0
    local active = W.Create(parent, { type = "select", label = L("Активный профиль", "Active profile"), values = names },
        profileAccess, 280)
    active:SetPoint("TOPLEFT", 0, y)
    local charText = W.Text(parent, W.fonts.small)
    charText:SetPoint("TOPLEFT", 300, y - 4)
    charText:SetWidth(width - 300)
    y = y - 52

    local function button(text, fn, x, w)
        local b = W.Button(parent, text, w or 140, fn, 24)
        b:SetPoint("TOPLEFT", x, y)
        return b
    end
    button(L("Новый", "New"), function()
        su.Prompt(L("Имя нового профиля:", "New profile name:"), "", function(name)
            if suite.NewProfile(name) then suite.SetProfile(name) end
            refresh()
        end)
    end, 0)
    button(L("Копия текущего", "Copy of current"), function()
        su.Prompt(L("Имя копии:", "Copy name:"), suite.ActiveProfileName() .. " 2", function(name)
            if suite.NewProfile(name, suite.ActiveProfileName()) then suite.SetProfile(name) end
            refresh()
        end)
    end, 148)
    button(L("Переименовать", "Rename"), function()
        local old = suite.ActiveProfileName()
        su.Prompt(L("Новое имя профиля:", "New profile name:"), old, function(name)
            suite.RenameProfile(old, name)
            refresh()
        end)
    end, 296)
    local delete = button(L("Удалить", "Delete"), function()
        local name = suite.ActiveProfileName()
        su.Confirm((L("Удалить профиль «%s»?", "Delete the profile “%s”?")):format(name), function()
            if not suite.DeleteProfile(name) then
                ui.Print(L("Последний профиль удалить нельзя.", "The last profile cannot be deleted."))
            end
            suite.SetProfile(suite.ActiveProfileName())
            refresh()
        end)
    end, 444, width - 444)
    delete.text:SetTextColor(W.rgba(S.danger))
    y = y - 32
    local copyFrom = W.Button(parent, L("Скопировать в текущий из…", "Copy into current from…"), 240, function(self)
        local items = {}
        for _, name in ipairs(suite.ProfileNames()) do
            if name ~= suite.ActiveProfileName() then items[#items + 1] = { name, name } end
        end
        W.OpenList(self, items, nil, function(source)
            su.Confirm((L("Заменить текущий профиль данными «%s»?", "Replace the current profile with “%s”?")):format(source),
                function()
                    suite.CopyProfile(source)
                    refresh()
                end)
        end, 240)
    end, 24)
    copyFrom:SetPoint("TOPLEFT", 0, y)
    local reset = W.Button(parent, L("Сбросить текущий", "Reset current"), 160, function()
        su.Confirm(L("Вернуть текущий профиль к стартовым настройкам?", "Reset the current profile to the starting setup?"),
            function()
                suite.ResetProfile()
                refresh()
            end)
    end, 24)
    reset:SetPoint("TOPLEFT", 248, y)
    y = y - 40

    local specHeader = W.Header(parent, L("Привязка к специализациям", "Bind to talent specs"), width)
    specHeader:SetPoint("TOPLEFT", 0, y)
    y = y - 30
    local function specValues()
        local values = { { "", L("Не переключать", "Do not switch") } }
        for _, name in ipairs(suite.ProfileNames()) do values[#values + 1] = { name, name } end
        return values
    end
    local specRows = {}
    for group = 1, 2 do
        local row = W.Create(parent, { type = "select", label = group == 1 and L("Основные таланты", "Primary talents")
            or L("Дополнительные таланты", "Secondary talents"), values = specValues }, {
            get = function() return suite.SpecProfile(group) or "" end,
            set = function(value)
                suite.SetSpecProfile(group, value)
                refresh()
            end,
        }, math.floor((width - 24) / 2))
        row:SetPoint("TOPLEFT", (group - 1) * (math.floor((width - 24) / 2) + 24), y)
        specRows[group] = row
    end
    y = y - 52
    local specNote = W.Description(parent, L("При смене набора талантов профиль переключается сам: свои группы трекеров, "
        .. "настройки рейда и привязки клавиш для хила и бафера. Привязки клавиш также хранятся отдельно для каждого набора "
        .. "талантов внутри профиля.", "When the talent spec changes the profile switches by itself: tracker groups, raid "
        .. "settings and key bindings for healing or buffing. Click-cast bindings are also kept per talent spec inside a profile."),
        width)
    specNote:SetPoint("TOPLEFT", 0, y)
    y = y - 44

    local exportHeader = W.Header(parent, L("Экспорт", "Export"), width)
    exportHeader:SetPoint("TOPLEFT", 0, y)
    y = y - 30
    local partNames = { { "cdm", "Cooldown Manager" }, { "raid", L("Фреймы рейда", "Raid frames") },
        { "clicks", L("Привязки клавиш", "Click-casting") } }
    for index, part in ipairs(partNames) do
        local row = W.Create(parent, { type = "toggle", label = part[2] },
            ui.SuiteUI.Access(function() return state.export end, part[1], true, function() end), 180)
        row:SetPoint("TOPLEFT", (index - 1) * 190, y)
    end
    y = y - 30
    local exportBox = su.TextBox(parent, width, 70)
    exportBox:SetPoint("TOPLEFT", 0, y)
    y = y - 78
    local exportButton = W.Button(parent, L("Создать строку", "Create string"), 160, function()
        exportBox:SetText(suite.Export(state.export))
        exportBox.edit:HighlightText()
        exportBox.edit:SetFocus()
    end, 24)
    exportButton:SetPoint("TOPLEFT", 0, y)
    local exportNote = W.Text(parent, W.fonts.small)
    exportNote:SetPoint("LEFT", exportButton, "RIGHT", 10, 0)
    exportNote:SetText(L("Ctrl+C, чтобы скопировать.", "Ctrl+C to copy."))
    y = y - 40

    local importHeader = W.Header(parent, L("Импорт", "Import"), width)
    importHeader:SetPoint("TOPLEFT", 0, y)
    y = y - 30
    local importBox = su.TextBox(parent, width, 70)
    importBox:SetPoint("TOPLEFT", 0, y)
    y = y - 78
    local status = W.Text(parent, W.fonts.small)
    local importNew = W.Button(parent, L("Импорт в новый профиль", "Import as a new profile"), 220, function()
        local name, err = suite.Import(importBox:GetText())
        if name then
            suite.SetProfile(name)
            status:SetText((L("Создан профиль «%s».", "Profile “%s” created.")):format(name))
            importBox:SetText("")
        else
            status:SetText(err or "?")
        end
        refresh()
    end, 24)
    importNew:SetPoint("TOPLEFT", 0, y)
    local importHere = W.Button(parent, L("Заменить текущий", "Replace current"), 180, function()
        local text = importBox:GetText()
        su.Confirm(L("Заменить текущий профиль импортом?", "Replace the current profile with the import?"), function()
            local name, err = suite.Import(text, suite.ActiveProfileName())
            status:SetText(name and L("Профиль обновлён.", "Profile updated.") or (err or "?"))
            if name then suite.SetProfile(name) end
            refresh()
        end)
    end, 24)
    importHere:SetPoint("TOPLEFT", 228, y)
    status:SetPoint("TOPLEFT", 0, y - 30)
    status:SetWidth(width)
    y = y - 50

    refresh = function()
        active:Refresh()
        for _, row in ipairs(specRows) do row:Refresh() end
        charText:SetText((L("Персонаж: %s\nАктивный набор талантов: %d", "Character: %s\nActive talent spec: %d")):format(
            suite.CharKey(), suite.TalentGroup()))
    end
    parent.refreshProfiles = refresh
    parent:SetScript("OnShow", refresh)
    ui.RegisterCallback("SuiteProfileChanged", function() refresh() end, "ProfilesOptions")
    refresh()
    return -y
end

ui.RegisterOptions("profiles", {
    title = L("Профили", "Profiles"),
    description = L("Профили Cooldown Manager, фреймов рейда и привязок; специализации; импорт и экспорт.",
        "Profiles for the Cooldown Manager, raid frames and bindings; specs; import and export."),
    icon = "Interface\\Icons\\INV_Misc_Note_05",
    group = "general",
    order = 90,
    sections = {
        { options = {
            { "custom", build = build, refresh = function(holder)
                if holder.refreshProfiles then holder.refreshProfiles() end
            end },
        } },
    },
})
