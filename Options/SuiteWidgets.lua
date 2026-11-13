-- Building blocks for the option pages of the combat suite (Cooldown Manager, raid frames,
-- click-casting, profiles): controls bound to nested tables, a small grid layout, a selectable
-- list, a key/mouse capture button and a multi-line text box. Built on the flat widget factory.
local _, ui = ...
local L, W, S = ui.L, ui.Widgets, ui.Style
local rgba = W.rgba
local max, min, floor = math.max, math.min, math.floor

local SU = {}
ui.SuiteUI = SU

-- Access object for W.Create on a field of a table returned by `target()`.
-- path: "key" or { "sub", "key" } for nested tables (load.zone.raid -> { "load", "zone", "raid" }).
function SU.Access(target, path, default, onChange)
    if type(path) ~= "table" then path = { path } end
    local function holder(create)
        local t = target()
        if not t then return end
        for i = 1, #path - 1 do
            if type(t[path[i]]) ~= "table" then
                if not create then return end
                t[path[i]] = {}
            end
            t = t[path[i]]
        end
        return t
    end
    local last = path[#path]
    local access = {}
    function access.get()
        local t = holder(false)
        local value = t and t[last]
        if value == nil then value = default end
        return value
    end
    function access.set(value)
        local t = holder(true)
        if not t then return end
        t[last] = ui.CopyTable(value)
        if onChange then onChange(last, value) end
    end
    if default ~= nil then
        function access.reset() access.set(default) end
        function access.isDefault() return ui.SameValue(access.get(), default) end
    end
    return access
end

-- Vertical grid: rows go into `columns` columns, full-width rows break the line.
function SU.Grid(parent, x, y, width, columns)
    local grid = { rows = {}, x = x, y = y, top = y, width = width, columns = columns or 2, column = 0, line = 0 }
    local gap = S.columnGap
    local columnWidth = floor((width - gap * (grid.columns - 1)) / grid.columns)
    grid.columnWidth = columnWidth
    function grid:Break()
        if self.column > 0 then
            self.y = self.y - self.line - S.rowGap
            self.column, self.line = 0, 0
        end
    end
    function grid:Place(frame, full, height)
        if full then self:Break() end
        local offset = full and 0 or self.column * (columnWidth + gap)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", parent, "TOPLEFT", self.x + offset, self.y)
        self.line = max(self.line, height or frame:GetHeight())
        if full then
            self.column = self.columns
        else
            self.column = self.column + 1
        end
        if self.column >= self.columns then self:Break() end
        return frame
    end
    -- opt: { "toggle"|"range"|"select"|"media"|"color"|"text", label = , ... }, access, full
    function grid:Add(opt, access, full, enabled)
        opt.type = opt.type or opt[1]
        opt.label = opt.label or opt[2]
        local row = W.Create(parent, opt, access, full and width or columnWidth)
        if not row then return end
        row.isEnabled = enabled
        self.rows[#self.rows + 1] = row
        return self:Place(row, full)
    end
    function grid:Header(text)
        self:Break()
        self.y = self.y - 4
        local header = W.Header(parent, text, width)
        self:Place(header, true, 22)
        return header
    end
    function grid:Text(text)
        local row = W.Description(parent, text, width)
        self:Place(row, true)
        return row
    end
    function grid:Skip(height)
        self:Break()
        self.y = self.y - height
    end
    function grid:Height()
        self:Break()
        return self.top - self.y
    end
    function grid:Refresh()
        for _, row in ipairs(self.rows) do
            if row.SetEnabled then
                local enabled = true
                if row.isEnabled then enabled = row.isEnabled() and true or false end
                row:SetEnabled(enabled)
            end
            if row.Refresh then row:Refresh() end
        end
        W.Redraw(parent)
    end
    return grid
end

-- Selectable list with fixed rows and wheel paging.
-- render(row, item, index) fills row.icon / row.text / row.sub; onSelect(index, item).
function SU.List(parent, width, visible, rowHeight, onSelect)
    local list = CreateFrame("Frame", nil, parent)
    rowHeight = rowHeight or 24
    list:SetWidth(width)
    list:SetHeight(visible * rowHeight + 4)
    W.Skin(list, { 0, 0, 0, 0.25 }, S.border)
    list:EnableMouseWheel(true)
    list.items, list.offset, list.rows = {}, 0, {}
    for i = 1, visible do
        local row = CreateFrame("Button", nil, list)
        row:SetHeight(rowHeight)
        row:SetPoint("TOPLEFT", 2, -2 - (i - 1) * rowHeight)
        row:SetPoint("RIGHT", list, "RIGHT", -6, 0)
        row.background = row:CreateTexture(nil, "BACKGROUND")
        row.background:SetAllPoints(row)
        row.background:SetTexture("Interface\\Buttons\\WHITE8X8")
        row.background:SetVertexColor(rgba(S.accent, 0))
        local hover = row:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints(row)
        hover:SetTexture("Interface\\Buttons\\WHITE8X8")
        hover:SetVertexColor(1, 1, 1, 0.05)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetWidth(rowHeight - 6)
        row.icon:SetHeight(rowHeight - 6)
        row.icon:SetPoint("LEFT", 4, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.text = W.Text(row, W.fonts.label)
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.text:SetPoint("RIGHT", row, "RIGHT", -70, 0)
        row.text:SetHeight(rowHeight)
        row.sub = W.Text(row, W.fonts.small)
        row.sub:SetPoint("RIGHT", -4, 0)
        row.sub:SetJustifyH("RIGHT")
        row:SetScript("OnClick", function(self)
            if self.index then
                list.selected = self.index
                list:Draw()
                if onSelect then onSelect(self.index, list.items[self.index]) end
            end
        end)
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function(_, delta) list:Scroll(delta) end)
        list.rows[i] = row
    end
    local thumb = list:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
    thumb:SetVertexColor(1, 1, 1, 0.22)
    thumb:SetWidth(2)
    function list:Scroll(delta)
        local maxOffset = max(0, #self.items - visible)
        self.offset = max(0, min(maxOffset, self.offset - delta))
        self:Draw()
    end
    list:SetScript("OnMouseWheel", function(self, delta) self:Scroll(delta) end)
    function list:SetItems(items, render)
        self.items, self.render = items or {}, render or self.render
        local maxOffset = max(0, #self.items - visible)
        if self.offset > maxOffset then self.offset = maxOffset end
        self:Draw()
    end
    function list:Select(index)
        self.selected = index
        if index then
            if index <= self.offset then self.offset = max(0, index - 1) end
            if index > self.offset + visible then self.offset = index - visible end
        end
        self:Draw()
    end
    function list:Draw()
        for i, row in ipairs(self.rows) do
            local index = self.offset + i
            local item = self.items[index]
            row.index = item and index or nil
            if item then
                row.icon:SetTexture(nil)
                row.sub:SetText("")
                if self.render then self.render(row, item, index) end
                row.background:SetVertexColor(rgba(S.accent, index == self.selected and 0.18 or 0))
                row:Show()
            else
                row:Hide()
            end
        end
        local total = #self.items
        if total > visible then
            local height = self:GetHeight() - 4
            local size = max(16, height * visible / total)
            thumb:ClearAllPoints()
            thumb:SetHeight(size)
            thumb:SetPoint("TOPRIGHT", -2, -2 - (height - size) * self.offset / (total - visible))
            thumb:Show()
        else
            thumb:Hide()
        end
        W.Redraw(self)
    end
    return list
end

-- Captures the next mouse button, wheel turn or key with modifiers. onCaptured(key, mods).
function SU.CaptureButton(parent, width, onCaptured)
    local button = W.Button(parent, L("Нажмите и задайте клавишу", "Click, then press a key"), width, nil, 26)
    button:RegisterForClicks("AnyUp")
    local hint = L("Нажмите кнопку мыши, колесо или клавишу (Esc — отмена)",
        "Press a mouse button, turn the wheel or press a key (Esc cancels)")
    local function stop(self)
        self.capturing = nil
        self:EnableKeyboard(false)
        self:EnableMouseWheel(false)
        self:SetText(L("Нажмите и задайте клавишу", "Click, then press a key"))
        self:SetBackdropBorderColor(rgba(S.border))
    end
    local function mods()
        return ui.ClickCast and ui.ClickCast.NormalizeMods(IsAltKeyDown(), IsControlKeyDown(), IsShiftKeyDown())
            or ((IsAltKeyDown() and "alt-" or "") .. (IsControlKeyDown() and "ctrl-" or "") .. (IsShiftKeyDown() and "shift-" or ""))
    end
    local buttons = { LeftButton = "BUTTON1", RightButton = "BUTTON2", MiddleButton = "BUTTON3",
        Button4 = "BUTTON4", Button5 = "BUTTON5" }
    button:SetScript("OnClick", function(self, mouse)
        if self.capturing then
            local key = buttons[mouse]
            local held = mods()
            stop(self)
            if key then onCaptured(key, held) end
            return
        end
        if mouse ~= "LeftButton" then return end
        self.capturing = true
        self:EnableKeyboard(true)
        self:EnableMouseWheel(true)
        self:SetText(hint)
        self:SetBackdropBorderColor(rgba(S.accent))
    end)
    button:SetScript("OnKeyDown", function(self, key)
        if not self.capturing then return end
        if key == "ESCAPE" then stop(self) return end
        if key:match("SHIFT$") or key:match("CTRL$") or key:match("ALT$") then return end
        local held = mods()
        stop(self)
        onCaptured(key, held)
    end)
    button:SetScript("OnMouseWheel", function(self, delta)
        if not self.capturing then return end
        local held = mods()
        stop(self)
        onCaptured(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN", held)
    end)
    button:SetScript("OnHide", stop)
    button:EnableKeyboard(false)
    return button
end

-- Scrollable multi-line text box (import / export strings).
function SU.TextBox(parent, width, height)
    local box = CreateFrame("Frame", nil, parent)
    box:SetWidth(width)
    box:SetHeight(height)
    W.Skin(box, { 0, 0, 0, 0.35 }, S.border)
    local scroll = CreateFrame("ScrollFrame", nil, box)
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -6, 6)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(W.fonts.value)
    edit:SetWidth(width - 14)
    edit:SetHeight(height - 12)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    scroll:SetScrollChild(edit)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = max(0, edit:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(max(0, min(range, self:GetVerticalScroll() - delta * 30)))
    end)
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function() edit:SetFocus() end)
    box.edit = edit
    function box:SetText(text) edit:SetText(text or "") end
    function box:GetText() return edit:GetText() or "" end
    return box
end

function SU.Confirm(text, onAccept)
    StaticPopupDialogs.FOREVERUI_SUITE_CONFIRM = StaticPopupDialogs.FOREVERUI_SUITE_CONFIRM or {
        button1 = YES, button2 = NO, timeout = 0, whileDead = 1, hideOnEscape = 1,
        OnAccept = function(self) if self.data then self.data() end end,
    }
    StaticPopupDialogs.FOREVERUI_SUITE_CONFIRM.text = text
    local dialog = StaticPopup_Show("FOREVERUI_SUITE_CONFIRM")
    if dialog then dialog.data = onAccept end
end

-- Asks for a name. onAccept(text).
function SU.Prompt(text, default, onAccept)
    StaticPopupDialogs.FOREVERUI_SUITE_PROMPT = StaticPopupDialogs.FOREVERUI_SUITE_PROMPT or {
        button1 = ACCEPT or OKAY, button2 = CANCEL, timeout = 0, whileDead = 1, hideOnEscape = 1, hasEditBox = 1,
        OnShow = function(self)
            local edit = self.editBox or _G[self:GetName() .. "EditBox"]
            if edit then
                edit:SetText(self.defaultText or "")
                edit:HighlightText()
                edit:SetFocus()
            end
        end,
        OnAccept = function(self)
            local edit = self.editBox or _G[self:GetName() .. "EditBox"]
            local value = edit and edit:GetText() or ""
            if self.data and value ~= "" then self.data(value) end
        end,
        EditBoxOnEnterPressed = function(self)
            local parent = self:GetParent()
            local value = self:GetText() or ""
            if parent.data and value ~= "" then parent.data(value) end
            parent:Hide()
        end,
        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    }
    StaticPopupDialogs.FOREVERUI_SUITE_PROMPT.text = text
    local dialog = StaticPopup_Show("FOREVERUI_SUITE_PROMPT")
    if dialog then
        dialog.data = onAccept
        dialog.defaultText = default
        local edit = dialog.editBox or _G[(dialog:GetName() or "") .. "EditBox"]
        if edit then
            edit:SetText(default or "")
            edit:HighlightText()
        end
    end
end

-- Spellbook entries for W.OpenList: "|T icon |t Name".
function SU.SpellbookItems()
    local items = {}
    local book = ui.Suite and ui.Suite.Spellbook() or {}
    for _, spell in ipairs(book) do
        items[#items + 1] = { spell.name, ("|T%s:16:16:0:0|t %s"):format(spell.icon or "", spell.name) }
    end
    return items
end

function SU.MacroItems()
    local items = {}
    local general, character = 0, 0
    if GetNumMacros then general, character = GetNumMacros() end
    local function add(index)
        local name, icon = GetMacroInfo(index)
        if name then items[#items + 1] = { name, ("|T%s:16:16:0:0|t %s"):format(icon or "", name) } end
    end
    for i = 1, general or 0 do add(i) end
    for i = 1, character or 0 do add((MAX_ACCOUNT_MACROS or 36) + i) end
    return items
end

function SU.Unavailable(parent, width)
    local text = W.Description(parent, L("Модуль не загружен.", "The module is not loaded."), width)
    text:SetPoint("TOPLEFT", 0, 0)
    return 20
end
