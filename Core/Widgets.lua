-- ForeverUI widget factory: one flat, minimal style for every options control.
-- Only 3.3.5a API: SetBackdrop, template-free CreateFrame, CreateFont; no Retail mixins or pools.
local _, ui = ...
local L = ui.L
local W = {}
ui.Widgets = W

local white = "Interface\\Buttons\\WHITE8X8"
local floor, max, min = math.floor, math.max, math.min

local S = {
    font = STANDARD_TEXT_FONT,
    window = { 0.043, 0.043, 0.051, 0.97 },
    sidebar = { 1, 1, 1, 0.025 },
    surface = { 1, 1, 1, 0.04 },
    surfaceHover = { 1, 1, 1, 0.08 },
    surfaceActive = { 1, 1, 1, 0.12 },
    border = { 1, 1, 1, 0.10 },
    borderHover = { 1, 1, 1, 0.24 },
    accent = { 0.910, 0.761, 0.478 },
    accentText = { 1, 0.875, 0.62 },
    text = { 0.93, 0.93, 0.93 },
    muted = { 0.58, 0.58, 0.61 },
    danger = { 1, 0.42, 0.36 },
    success = { 0.42, 0.86, 0.50 },
    disabledAlpha = 0.35,
    padding = 16,
    columnGap = 24,
    rowGap = 10,
    sectionGap = 22,
}
ui.Style = S

local function rgba(color, alpha)
    return color[1], color[2], color[3], alpha or color[4] or 1
end
W.rgba = rgba

local fonts = {}
local function font(name, size, flags, color)
    if fonts[name] then return fonts[name] end
    local object = CreateFont("ForeverUIFont" .. name)
    object:SetFont(S.font, size, flags or "")
    object:SetShadowColor(0, 0, 0, 0.8)
    object:SetShadowOffset(1, -1)
    object:SetTextColor(rgba(color or S.text))
    fonts[name] = object
    return object
end
W.fonts = {
    title = font("Title", 17, nil, S.text),
    heading = font("Heading", 13, nil, S.accentText),
    label = font("Label", 12, nil, S.text),
    small = font("Small", 11, nil, S.muted),
    value = font("Value", 11, nil, S.text),
    group = font("Group", 10, nil, S.muted),
}

local flat = { bgFile = white, edgeFile = white, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }

function W.Skin(frame, background, border)
    frame:SetBackdrop(flat)
    frame:SetBackdropColor(rgba(background or S.surface))
    frame:SetBackdropBorderColor(rgba(border or S.border))
end

function W.Text(parent, fontObject, layer)
    local text = parent:CreateFontString(nil, layer or "OVERLAY")
    text:SetFontObject(fontObject or W.fonts.label)
    text:SetJustifyH("LEFT")
    return text
end

function W.Line(parent, color, layer)
    local line = parent:CreateTexture(nil, layer or "ARTWORK")
    line:SetTexture(white)
    line:SetVertexColor(rgba(color or S.border))
    return line
end

local function setVisible(region, visible)
    if visible then region:Show() else region:Hide() end
end
W.SetVisible = setVisible

---------------------------------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------------------------------
function W.ShowTooltip(owner, title, text, opt)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(title or "", 1, 1, 1)
    if text and text ~= "" then GameTooltip:AddLine(text, 0.82, 0.82, 0.82, true) end
    if opt then
        if opt.reload then
            GameTooltip:AddLine(L("Требует перезагрузки интерфейса (/reload).", "Requires a UI reload (/reload)."),
                1, 0.55, 0.35, true)
        end
        if opt.protected or (opt.module and opt.module.protected) then
            GameTooltip:AddLine(L("В бою применится после выхода из боя.", "In combat it applies after combat ends."),
                0.55, 0.75, 1, true)
        end
        if opt.module and opt.key and opt.type ~= "button" then
            local default = ui.GetDefault(opt.module.id, opt.key)
            local shown
            if opt.type == "toggle" then
                shown = default and L("вкл.", "on") or L("выкл.", "off")
            elseif opt.type == "range" then
                shown = tostring(default) .. (opt.suffix or "")
            elseif opt.type == "select" then
                for _, item in ipairs(ui.OptionValues(opt)) do
                    if item[1] == default then shown = item[2] end
                end
            end
            if shown then GameTooltip:AddLine(L("По умолчанию: ", "Default: ") .. shown, 0.55, 0.55, 0.58) end
        end
    end
    GameTooltip:Show()
end

local function bindTooltip(frame, row)
    frame:HookScript("OnEnter", function()
        if row.opt and (row.opt.tooltip or row.opt.reload or row.opt.label) then
            W.ShowTooltip(frame, row.opt.label, row.opt.tooltip, row.opt.module and row.opt)
        end
        if row.OnHover then row:OnHover(true) end
        W.Redraw(frame)
    end)
    frame:HookScript("OnLeave", function()
        GameTooltip:Hide()
        if row.OnHover then row:OnHover(false) end
        W.Redraw(frame)
    end)
end
W.BindTooltip = bindTooltip

---------------------------------------------------------------------------------------------------
-- Scroll container used by the window, pages and the dropdown list
---------------------------------------------------------------------------------------------------
function W.Scroll(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    scroll.child = child
    scroll:EnableMouseWheel(true)

    local bar = CreateFrame("Frame", nil, scroll)
    bar:SetWidth(3)
    bar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 6, 0)
    bar:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 6, 0)
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(white)
    thumb:SetVertexColor(1, 1, 1, 0.22)
    thumb:SetWidth(3)
    scroll.thumb = thumb

    function scroll:Update()
        local height = self:GetHeight()
        local content = self.contentHeight or 0
        local range = max(0, content - height)
        local offset = min(self:GetVerticalScroll(), range)
        self:SetVerticalScroll(offset)
        if range <= 0 or height <= 0 then
            thumb:Hide()
            return
        end
        local size = max(24, height * height / content)
        thumb:ClearAllPoints()
        thumb:SetHeight(size)
        thumb:SetPoint("TOP", bar, "TOP", 0, -(height - size) * offset / range)
        thumb:Show()
    end

    function scroll:SetContentHeight(height)
        self.contentHeight = height
        child:SetHeight(max(1, height))
        self:UpdateScrollChildRect()
        self:Update()
    end

    function scroll:ForeverScroll(delta)
        local range = max(0, (self.contentHeight or 0) - self:GetHeight())
        self:SetVerticalScroll(max(0, min(range, self:GetVerticalScroll() - delta * 48)))
        self:Update()
    end

    scroll:SetScript("OnMouseWheel", scroll.ForeverScroll)
    scroll:SetScript("OnSizeChanged", function(self, width)
        child:SetWidth(width)
        self:Update()
    end)
    return scroll
end

-- The 3.3.5 client does not always repaint a ScrollFrame when something inside its scroll child changes
-- (texts, colours, toggles stay stale until the frame scrolls or resizes, e.g. after switching pages).
-- W.Redraw(frame) queues every scroll frame above `frame`: next frame the child rect is updated and the
-- offset moves by half a pixel, the frame after it goes back. Nothing visible, but the content repaints.
local redrawQueue = {}
local redrawDriver = CreateFrame("Frame")
local function redrawStep(self)
    for scroll, phase in pairs(redrawQueue) do
        if phase == 1 then
            local offset = scroll:GetVerticalScroll() or 0
            scroll.redrawOffset = offset
            scroll:UpdateScrollChildRect()
            scroll:SetVerticalScroll(offset >= 0.5 and offset - 0.5 or offset + 0.5)
            redrawQueue[scroll] = 2
        else
            scroll:SetVerticalScroll(scroll.redrawOffset or 0)
            if scroll.Update then scroll:Update() end
            redrawQueue[scroll] = nil
        end
    end
    if not next(redrawQueue) then self:SetScript("OnUpdate", nil) end
end

function W.Redraw(frame)
    local node, any = frame, false
    while node do
        if node.ForeverScroll and not redrawQueue[node] then
            redrawQueue[node] = 1
            any = true
        end
        node = node.GetParent and node:GetParent()
    end
    if any then redrawDriver:SetScript("OnUpdate", redrawStep) end
end

local function forwardWheel(frame, delta)
    local parent = frame:GetParent()
    while parent do
        if parent.ForeverScroll then
            parent:ForeverScroll(delta)
            return
        end
        parent = parent:GetParent()
    end
end
W.ForwardWheel = forwardWheel

---------------------------------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------------------------------
function W.Button(parent, text, width, onClick, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 120, height or 24)
    W.Skin(button, S.surface, S.border)
    local label = W.Text(button, W.fonts.label)
    label:SetPoint("LEFT", 8, 0)
    label:SetPoint("RIGHT", -8, 0)
    label:SetJustifyH("CENTER")
    label:SetText(text or "")
    button.text = label
    function button:SetText(value) label:SetText(value) end
    button:SetScript("OnEnter", function(self)
        if self:IsEnabled() == 1 or self:IsEnabled() == true then
            self:SetBackdropColor(rgba(S.surfaceHover))
            self:SetBackdropBorderColor(rgba(S.accent, 0.6))
        end
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(rgba(S.surface))
        self:SetBackdropBorderColor(rgba(S.border))
    end)
    button:SetScript("OnMouseDown", function(self)
        self:SetBackdropColor(rgba(S.surfaceActive))
        W.Redraw(self)
    end)
    button:SetScript("OnMouseUp", function(self)
        self:SetBackdropColor(rgba(S.surfaceHover))
        W.Redraw(self)
    end)
    button:HookScript("OnEnter", function(self) W.Redraw(self) end)
    button:HookScript("OnLeave", function(self) W.Redraw(self) end)
    button:SetScript("OnDisable", function(self)
        self:SetAlpha(S.disabledAlpha)
        self:SetBackdropBorderColor(rgba(S.border))
    end)
    button:SetScript("OnEnable", function(self) self:SetAlpha(1) end)
    if onClick then
        button:SetScript("OnClick", function(self, ...)
            PlaySound("igMainMenuOptionCheckBoxOn")
            onClick(self, ...)
        end)
    end
    return button
end

-- A borderless square icon button (close, reset).
function W.IconButton(parent, size, texture, onClick, coords)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size, size)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    icon:SetTexture(texture)
    if coords then icon:SetTexCoord(unpack(coords)) end
    icon:SetVertexColor(rgba(S.muted))
    button.icon = icon
    button:SetScript("OnEnter", function() icon:SetVertexColor(rgba(S.accentText)) end)
    button:SetScript("OnLeave", function() icon:SetVertexColor(rgba(S.muted)) end)
    if onClick then button:SetScript("OnClick", onClick) end
    return button
end

-- Close cross drawn from two rotated lines would need SetRotation (absent in 3.3.5): use a glyph.
function W.CloseButton(parent, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(24, 24)
    local glyph = W.Text(button, W.fonts.title)
    glyph:SetPoint("CENTER", 0, 1)
    glyph:SetText("×")
    glyph:SetTextColor(rgba(S.muted))
    if not glyph:GetText() or glyph:GetStringWidth() < 2 then glyph:SetText("x") end
    button:SetScript("OnEnter", function() glyph:SetTextColor(rgba(S.danger)) end)
    button:SetScript("OnLeave", function() glyph:SetTextColor(rgba(S.muted)) end)
    button:SetScript("OnClick", onClick)
    return button
end

local undoIcon = "Interface\\PaperDollInfoFrame\\UI-GearManager-Undo"
local function resetButton(row)
    local button = W.IconButton(row, 14, undoIcon, function()
        if row.enabled ~= false and row.access.reset then
            PlaySound("igMainMenuOptionCheckBoxOff")
            row.access.reset()
        end
    end)
    button:HookScript("OnEnter", function(self)
        W.ShowTooltip(self, L("Сбросить", "Reset"), L("Вернуть значение по умолчанию.", "Restore the default value."))
    end)
    button:HookScript("OnLeave", GameTooltip_Hide)
    button:SetFrameLevel(row:GetFrameLevel() + 5)
    button:Hide()
    row.resetButton = button
    return button
end

local function updateReset(row)
    local button = row.resetButton
    if not button then return end
    local access = row.access
    local show = access.reset and row.enabled ~= false and access.isDefault and not access.isDefault()
    setVisible(button, show)
end

---------------------------------------------------------------------------------------------------
-- Rows. Every control is a row frame with :Refresh() and :SetEnabled(enabled).
-- access = { get(), set(value), reset(), isDefault() }
---------------------------------------------------------------------------------------------------
local function newRow(parent, opt, access, width, height, kind)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(width, height)
    row.opt, row.access, row.kind, row.enabled = opt, access, kind, true
    function row:SetEnabled(enabled)
        self.enabled = enabled and true or false
        self:SetAlpha(enabled and 1 or S.disabledAlpha)
        if self.OnEnabledChanged then self:OnEnabledChanged(self.enabled) end
        updateReset(self)
    end
    return row
end

-- Toggle switch
function W.Toggle(parent, opt, access, width)
    local row = newRow(parent, opt, access, width, 22, "toggle")
    local hit = CreateFrame("Button", nil, row)
    hit:SetAllPoints(row)
    local track = CreateFrame("Frame", nil, hit)
    track:SetSize(30, 16)
    track:SetPoint("LEFT", 0, 0)
    W.Skin(track, S.surface, S.border)
    local knob = track:CreateTexture(nil, "OVERLAY")
    knob:SetTexture(white)
    knob:SetSize(10, 10)
    local label = W.Text(hit, W.fonts.label)
    label:SetPoint("LEFT", track, "RIGHT", 9, 0)
    label:SetPoint("RIGHT", row, "RIGHT", -20, 0)
    label:SetHeight(20)
    label:SetText(opt.label or "")
    row.label = label
    local reset = resetButton(row)
    reset:SetPoint("RIGHT", row, "RIGHT", 0, 0)

    local hovered
    local function paint()
        local on = access.get() and true or false
        knob:ClearAllPoints()
        if on then
            knob:SetPoint("RIGHT", track, "RIGHT", -3, 0)
            track:SetBackdropColor(rgba(S.accent, 0.85))
            track:SetBackdropBorderColor(rgba(S.accent, 1))
            knob:SetVertexColor(0.08, 0.07, 0.06, 1)
        else
            knob:SetPoint("LEFT", track, "LEFT", 3, 0)
            track:SetBackdropColor(rgba(hovered and S.surfaceHover or S.surface))
            track:SetBackdropBorderColor(rgba(hovered and S.borderHover or S.border))
            knob:SetVertexColor(rgba(S.muted))
        end
    end
    function row:OnHover(state)
        hovered = state and self.enabled
        paint()
    end
    hit:SetScript("OnClick", function()
        if not row.enabled then return end
        local on = not access.get()
        PlaySound(on and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
        access.set(on)
    end)
    bindTooltip(hit, row)
    function row:OnEnabledChanged(enabled) hit:EnableMouse(enabled) end
    function row:Refresh()
        paint()
        updateReset(self)
    end
    row:Refresh()
    return row
end

local function decimals(step)
    if not step or step >= 1 then return 0 end
    local text = tostring(step)
    local fraction = text:match("%.(%d+)")
    return fraction and #fraction or 2
end

local function limit(value)
    if type(value) == "function" then return value() end
    return value
end

-- Slider with an exact value input. Shift + wheel steps the value, the plain wheel scrolls the page.
function W.Range(parent, opt, access, width)
    local row = newRow(parent, opt, access, width, 40, "range")
    local label = W.Text(row, W.fonts.label)
    label:SetPoint("TOPLEFT", 0, -2)
    label:SetPoint("RIGHT", row, "RIGHT", -82, 0)
    label:SetHeight(16)
    label:SetText(opt.label or "")
    row.label = label

    local input = CreateFrame("EditBox", nil, row)
    input:SetSize(56, 18)
    input:SetPoint("TOPRIGHT", 0, 0)
    W.Skin(input, { 0, 0, 0, 0.35 }, S.border)
    input:SetFontObject(W.fonts.value)
    input:SetJustifyH("CENTER")
    input:SetAutoFocus(false)
    input:SetMaxLetters(10)
    input:SetTextInsets(3, 3, 0, 0)
    local reset = resetButton(row)
    reset:SetPoint("RIGHT", input, "LEFT", -5, 0)

    local slider = CreateFrame("Slider", nil, row)
    slider:SetOrientation("HORIZONTAL")
    slider:SetHeight(14)
    slider:SetPoint("BOTTOMLEFT", 0, 2)
    slider:SetPoint("BOTTOMRIGHT", 0, 2)
    slider:SetHitRectInsets(0, 0, -4, -4)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(white)
    track:SetVertexColor(1, 1, 1, 0.10)
    track:SetHeight(4)
    track:SetPoint("LEFT", 0, 0)
    track:SetPoint("RIGHT", 0, 0)
    slider:SetThumbTexture(white)
    local thumb = slider:GetThumbTexture()
    thumb:SetSize(8, 14)
    thumb:SetVertexColor(rgba(S.accent))
    local fill = slider:CreateTexture(nil, "ARTWORK")
    fill:SetTexture(white)
    fill:SetVertexColor(rgba(S.accent, 0.55))
    fill:SetHeight(4)
    fill:SetPoint("LEFT", track, "LEFT", 0, 0)
    fill:SetPoint("RIGHT", thumb, "CENTER", 0, 0)

    local places = decimals(opt.step)
    local updating
    local function bounds()
        return limit(opt.min) or 0, limit(opt.max) or 1, opt.step or 1
    end
    local function format(value)
        if opt.format then return opt.format(value) end
        return ("%." .. places .. "f"):format(value) .. (opt.suffix or "")
    end
    local function commit(value)
        local low, high, step = bounds()
        value = max(low, min(high, low + floor((value - low) / step + 0.5) * step))
        if not ui.SameValue(value, access.get()) then access.set(value) else row:Refresh() end
    end

    slider:SetScript("OnValueChanged", function(_, value)
        if updating or not row.enabled then return end
        commit(value)
    end)
    slider:EnableMouseWheel(true)
    slider:SetScript("OnMouseWheel", function(self, delta)
        if IsShiftKeyDown() and row.enabled then
            local _, _, step = bounds()
            commit(access.get() + delta * step)
        else
            forwardWheel(self, delta)
        end
    end)
    input:SetScript("OnEditFocusGained", function(self)
        self.focused = true
        self:SetText(("%." .. places .. "f"):format(access.get()))
        self:HighlightText()
        self:SetBackdropBorderColor(rgba(S.accent))
    end)
    input:SetScript("OnEditFocusLost", function(self)
        self.focused = nil
        self:SetBackdropBorderColor(rgba(S.border))
        self:HighlightText(0, 0)
        row:Refresh()
    end)
    input:SetScript("OnEnterPressed", function(self)
        local value = tonumber((self:GetText() or ""):gsub(",", "."):match("%-?[%d%.]+") or "")
        if value then commit(value) end
        self:ClearFocus()
    end)
    input:SetScript("OnEscapePressed", input.ClearFocus)
    bindTooltip(slider, row)
    bindTooltip(input, row)

    function row:OnHover(state)
        thumb:SetVertexColor(rgba(state and self.enabled and S.accentText or S.accent))
    end
    function row:OnEnabledChanged(enabled)
        slider:EnableMouse(enabled)
        input:EnableMouse(enabled)
        if not enabled then input:ClearFocus() end
    end
    function row:Refresh()
        local low, high, step = bounds()
        updating = true
        slider:SetMinMaxValues(low, high)
        slider:SetValueStep(step)
        local value = access.get() or low
        slider:SetValue(value)
        updating = false
        if not input.focused then input:SetText(format(value)) end
        updateReset(self)
    end
    row.slider, row.input = slider, input
    row:Refresh()
    return row
end

---------------------------------------------------------------------------------------------------
-- Dropdown list (shared popup with search, previews and wheel scrolling)
---------------------------------------------------------------------------------------------------
local list
local LIST_ROWS, LIST_ROW_HEIGHT = 12, 20

local function fold(value)
    value = (value or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    local ascii = value:gsub("[A-Z]", string.lower)
    return (ascii:gsub("\208([\129\144-\175])", function(byte)
        local n = byte:byte()
        if n == 129 then return "\209\145" end
        if n >= 160 then return "\209" .. string.char(n - 32) end
        return "\208" .. string.char(n + 32)
    end))
end
W.Fold = fold

local function buildList()
    list = CreateFrame("Frame", "ForeverUIDropdownList", UIParent)
    list:SetFrameStrata("FULLSCREEN_DIALOG")
    list:SetClampedToScreen(true)
    list:EnableMouse(true)
    list:EnableMouseWheel(true)
    W.Skin(list, { 0.06, 0.06, 0.07, 0.98 }, S.borderHover)
    list:Hide()
    tinsert(UISpecialFrames, list:GetName())

    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:RegisterForClicks("AnyUp")
    catcher:SetScript("OnClick", function() list:Hide() end)
    catcher:Hide()
    list.catcher = catcher

    local search = CreateFrame("EditBox", nil, list)
    search:SetHeight(20)
    search:SetPoint("TOPLEFT", 6, -6)
    search:SetPoint("TOPRIGHT", -6, -6)
    W.Skin(search, { 0, 0, 0, 0.4 }, S.border)
    search:SetFontObject(W.fonts.value)
    search:SetAutoFocus(false)
    search:SetTextInsets(6, 6, 0, 0)
    local hint = W.Text(search, W.fonts.small)
    hint:SetPoint("LEFT", 7, 0)
    hint:SetText(L("Поиск…", "Search…"))
    search:SetScript("OnEscapePressed", function() list:Hide() end)
    search:SetScript("OnEnterPressed", search.ClearFocus)
    search:SetScript("OnTextChanged", function(self)
        setVisible(hint, (self:GetText() or "") == "")
        list.offset = 0
        list:Filter()
    end)
    list.search = search

    list.rows = {}
    for i = 1, LIST_ROWS do
        local row = CreateFrame("Button", nil, list)
        row:SetHeight(LIST_ROW_HEIGHT)
        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(row)
        highlight:SetTexture(white)
        highlight:SetVertexColor(1, 1, 1, 0.07)
        local marker = row:CreateTexture(nil, "ARTWORK")
        marker:SetTexture(white)
        marker:SetVertexColor(rgba(S.accent))
        marker:SetSize(2, LIST_ROW_HEIGHT - 6)
        marker:SetPoint("LEFT", 2, 0)
        row.marker = marker
        local text = W.Text(row, W.fonts.label)
        text:SetPoint("LEFT", 10, 0)
        text:SetPoint("RIGHT", -8, 0)
        text:SetHeight(LIST_ROW_HEIGHT)
        row.text = text
        local swatch = row:CreateTexture(nil, "ARTWORK")
        swatch:SetSize(72, 10)
        swatch:SetPoint("RIGHT", -8, 0)
        row.swatch = swatch
        row:SetScript("OnClick", function(self)
            if not self.item then return end
            local callback = list.onSelect
            list:Hide()
            PlaySound("igMainMenuOptionCheckBoxOn")
            callback(self.item[1])
        end)
        list.rows[i] = row
    end

    local thumb = list:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(white)
    thumb:SetVertexColor(1, 1, 1, 0.22)
    thumb:SetWidth(2)
    list.thumb = thumb

    function list:Filter()
        local needle = fold(self.search:GetText())
        local matches = {}
        for _, item in ipairs(self.items) do
            if needle == "" or fold(item[2]):find(needle, 1, true) then matches[#matches + 1] = item end
        end
        self.matches = matches
        self:Draw()
    end

    function list:Draw()
        local matches = self.matches
        local visible = min(LIST_ROWS, #matches)
        self.offset = max(0, min(self.offset or 0, #matches - visible))
        local top = self.searchShown and 32 or 4
        for i, row in ipairs(self.rows) do
            local item = matches[self.offset + i]
            row.item = item
            if item and i <= visible then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 4, -top - (i - 1) * LIST_ROW_HEIGHT)
                row:SetPoint("TOPRIGHT", -6, -top - (i - 1) * LIST_ROW_HEIGHT)
                row.text:SetFontObject(W.fonts.label)
                if item.font then
                    -- An unreadable font file leaves the previous font in place instead of hiding the text.
                    row.text:SetFont(S.font, 12)
                    row.text:SetFont(item.font, 13)
                end
                row.text:SetText(item[2])
                local current = ui.SameValue(item[1], self.current)
                row.text:SetTextColor(rgba(current and S.accentText or S.text))
                setVisible(row.marker, current)
                if item.texture then
                    row.swatch:SetTexture(item.texture)
                    row.swatch:SetVertexColor(1, 1, 1, 1)
                    row.swatch:Show()
                    row.text:SetPoint("RIGHT", -86, 0)
                else
                    row.swatch:Hide()
                    row.text:SetPoint("RIGHT", -8, 0)
                end
                row:Show()
            else
                row:Hide()
            end
        end
        local height = top + max(1, visible) * LIST_ROW_HEIGHT + 4
        self:SetHeight(height)
        if #matches > visible and visible > 0 then
            local span = visible * LIST_ROW_HEIGHT
            local size = max(16, span * visible / #matches)
            thumb:ClearAllPoints()
            thumb:SetHeight(size)
            thumb:SetPoint("TOPRIGHT", -2, -top - (span - size) * self.offset / (#matches - visible))
            thumb:Show()
        else
            thumb:Hide()
        end
    end

    list:SetScript("OnMouseWheel", function(self, delta)
        self.offset = (self.offset or 0) - delta * 3
        self:Draw()
    end)
    list:SetScript("OnHide", function(self)
        self.catcher:Hide()
        self.search:ClearFocus()
        if self.owner and self.owner.OnListClosed then self.owner:OnListClosed() end
        self.owner = nil
    end)
end

function W.OpenList(owner, items, current, onSelect, width)
    if not list then buildList() end
    if list:IsShown() and list.owner == owner then
        list:Hide()
        return
    end
    list:Hide()
    list.owner, list.items, list.current, list.onSelect = owner, items, current, onSelect
    list.offset = 0
    list.searchShown = #items > LIST_ROWS
    setVisible(list.search, list.searchShown)
    list.search:SetText("")
    list:SetWidth(max(width or owner:GetWidth(), 160))
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    list:SetScale(owner:GetEffectiveScale() / UIParent:GetEffectiveScale())
    list:Filter()
    for i, item in ipairs(list.matches) do
        if ui.SameValue(item[1], current) then
            list.offset = max(0, i - floor(LIST_ROWS / 2))
            list:Draw()
            break
        end
    end
    list.catcher:Show()
    list:Show()
    list:SetFrameLevel(list.catcher:GetFrameLevel() + 10)
    for _, row in ipairs(list.rows) do row:SetFrameLevel(list:GetFrameLevel() + 1) end
    list.search:SetFrameLevel(list:GetFrameLevel() + 1)
end

function W.CloseList()
    if list then list:Hide() end
end

-- Select box. opt.values = { { value, label }, ... } or a function; media options call ui.MediaItems.
function W.Select(parent, opt, access, width)
    local row = newRow(parent, opt, access, width, 44, "select")
    local label = W.Text(row, W.fonts.label)
    label:SetPoint("TOPLEFT", 0, -2)
    label:SetPoint("RIGHT", row, "RIGHT", -20, 0)
    label:SetHeight(16)
    label:SetText(opt.label or "")
    row.label = label
    local reset = resetButton(row)
    reset:SetPoint("TOPRIGHT", 0, -1)

    local box = CreateFrame("Button", nil, row)
    box:SetHeight(22)
    box:SetPoint("BOTTOMLEFT", 0, 0)
    box:SetPoint("BOTTOMRIGHT", 0, 0)
    W.Skin(box, S.surface, S.border)
    local text = W.Text(box, W.fonts.label)
    text:SetPoint("LEFT", 8, 0)
    text:SetPoint("RIGHT", -24, 0)
    text:SetHeight(20)
    local swatch = box:CreateTexture(nil, "ARTWORK")
    swatch:SetSize(56, 8)
    swatch:SetPoint("RIGHT", -22, 0)
    swatch:Hide()
    local arrow = box:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    arrow:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
    arrow:SetSize(10, 10)
    arrow:SetPoint("RIGHT", -8, 0)
    arrow:SetVertexColor(rgba(S.muted))

    local function items()
        if opt.type == "media" then return ui.MediaItems(opt.kind, opt.ignoreGlobal) end
        return ui.OptionValues(opt)
    end
    local function paintBox(hover)
        box:SetBackdropColor(rgba(hover and S.surfaceHover or S.surface))
        box:SetBackdropBorderColor(rgba(hover and S.borderHover or S.border))
        arrow:SetVertexColor(rgba(hover and S.accentText or S.muted))
    end
    function row:OnHover(state) paintBox(state and self.enabled) end
    function row:OnListClosed() paintBox(false) end
    box:SetScript("OnClick", function(self)
        if not row.enabled then return end
        W.OpenList(self, items(), access.get(), function(value) access.set(value) end)
    end)
    bindTooltip(box, row)
    function row:OnEnabledChanged(enabled)
        box:EnableMouse(enabled)
        if not enabled and list and list.owner == box then list:Hide() end
    end
    function row:Refresh()
        local value = access.get()
        local shown, preview
        if opt.type == "media" then
            -- Media lists can hold hundreds of LibSharedMedia entries: resolve the current one directly.
            shown, preview = ui.MediaLabel(opt.kind, value, opt.ignoreGlobal), ui.MediaPreview(opt.kind, value)
        else
            for _, item in ipairs(items()) do
                if ui.SameValue(item[1], value) then
                    shown, preview = item[2], item
                    break
                end
            end
        end
        text:SetFontObject(W.fonts.label)
        if preview and preview.font then
            text:SetFont(S.font, 12)
            text:SetFont(preview.font, 12)
        end
        text:SetText(shown or tostring(value or ""))
        if preview and preview.texture then
            swatch:SetTexture(preview.texture)
            swatch:Show()
            text:SetPoint("RIGHT", -84, 0)
        else
            swatch:Hide()
            text:SetPoint("RIGHT", -24, 0)
        end
        updateReset(self)
    end
    row.box = box
    row:Refresh()
    return row
end

---------------------------------------------------------------------------------------------------
-- Colour swatch with optional alpha
---------------------------------------------------------------------------------------------------
local pickerStrata
local function restorePicker()
    if pickerStrata then
        ColorPickerFrame:SetFrameStrata(pickerStrata)
        pickerStrata = nil
    end
end

function W.OpenColorPicker(value, hasAlpha, onChange)
    local picker = ColorPickerFrame
    picker:Hide()
    local r, g, b, a = value[1], value[2], value[3], value[4] or 1
    picker.func, picker.opacityFunc, picker.cancelFunc = nil, nil, nil
    picker.hasOpacity = hasAlpha and true or false
    picker.opacity = 1 - a
    picker.previousValues = { r, g, b, a }
    picker:SetColorRGB(r, g, b)
    local function current()
        local nr, ng, nb = picker:GetColorRGB()
        local na = hasAlpha and (1 - (OpacitySliderFrame and OpacitySliderFrame:GetValue() or 0)) or nil
        return { nr, ng, nb, na }
    end
    picker.func = function() onChange(current()) end
    picker.opacityFunc = picker.func
    picker.cancelFunc = function() onChange({ r, g, b, hasAlpha and a or nil }) end
    if not pickerStrata then
        pickerStrata = picker:GetFrameStrata()
        picker:HookScript("OnHide", restorePicker)
    end
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:Show()
    picker:Raise()
end

function W.Color(parent, opt, access, width)
    local row = newRow(parent, opt, access, width, 22, "color")
    local hit = CreateFrame("Button", nil, row)
    hit:SetAllPoints(row)
    local frame = CreateFrame("Frame", nil, hit)
    frame:SetSize(30, 16)
    frame:SetPoint("LEFT", 0, 0)
    W.Skin(frame, { 0.2, 0.2, 0.2, 1 }, S.borderHover)
    local checker = frame:CreateTexture(nil, "BORDER")
    checker:SetTexture(white)
    checker:SetVertexColor(0.55, 0.55, 0.55, 1)
    checker:SetPoint("TOPLEFT", 1, -1)
    checker:SetPoint("BOTTOMRIGHT", frame, "CENTER", 0, 0)
    local checker2 = frame:CreateTexture(nil, "BORDER")
    checker2:SetTexture(white)
    checker2:SetVertexColor(0.55, 0.55, 0.55, 1)
    checker2:SetPoint("TOPLEFT", frame, "CENTER", 0, 0)
    checker2:SetPoint("BOTTOMRIGHT", -1, 1)
    local swatch = frame:CreateTexture(nil, "ARTWORK")
    swatch:SetTexture(white)
    swatch:SetPoint("TOPLEFT", 1, -1)
    swatch:SetPoint("BOTTOMRIGHT", -1, 1)
    local label = W.Text(hit, W.fonts.label)
    label:SetPoint("LEFT", frame, "RIGHT", 9, 0)
    label:SetPoint("RIGHT", row, "RIGHT", -20, 0)
    label:SetHeight(20)
    label:SetText(opt.label or "")
    row.label = label
    local reset = resetButton(row)
    reset:SetPoint("RIGHT", 0, 0)

    hit:SetScript("OnClick", function()
        if not row.enabled then return end
        W.OpenColorPicker(access.get(), opt.alpha, function(color) access.set(color) end)
    end)
    bindTooltip(hit, row)
    function row:OnHover(state)
        frame:SetBackdropBorderColor(rgba(state and self.enabled and S.accent or S.borderHover))
    end
    function row:OnEnabledChanged(enabled) hit:EnableMouse(enabled) end
    function row:Refresh()
        local color = access.get() or { 1, 1, 1 }
        swatch:SetVertexColor(color[1], color[2], color[3], opt.alpha and (color[4] or 1) or 1)
        updateReset(self)
    end
    row:Refresh()
    return row
end

---------------------------------------------------------------------------------------------------
-- Text input
---------------------------------------------------------------------------------------------------
function W.Input(parent, opt, access, width)
    local row = newRow(parent, opt, access, width, 44, "text")
    local label = W.Text(row, W.fonts.label)
    label:SetPoint("TOPLEFT", 0, -2)
    label:SetText(opt.label or "")
    row.label = label
    local reset = resetButton(row)
    reset:SetPoint("TOPRIGHT", 0, -1)
    local input = CreateFrame("EditBox", nil, row)
    input:SetHeight(22)
    input:SetPoint("BOTTOMLEFT", 0, 0)
    input:SetPoint("BOTTOMRIGHT", 0, 0)
    W.Skin(input, { 0, 0, 0, 0.35 }, S.border)
    input:SetFontObject(W.fonts.label)
    input:SetAutoFocus(false)
    input:SetTextInsets(8, 8, 0, 0)
    input:SetScript("OnEnterPressed", function(self)
        access.set(self:GetText() or "")
        self:ClearFocus()
    end)
    input:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        row:Refresh()
    end)
    input:SetScript("OnEditFocusGained", function(self)
        self.focused = true
        self:SetBackdropBorderColor(rgba(S.accent))
    end)
    input:SetScript("OnEditFocusLost", function(self)
        self.focused = nil
        self:SetBackdropBorderColor(rgba(S.border))
    end)
    bindTooltip(input, row)
    function row:OnEnabledChanged(enabled) input:EnableMouse(enabled) end
    function row:Refresh()
        if not input.focused then input:SetText(access.get() or "") end
        updateReset(self)
    end
    row:Refresh()
    return row
end

---------------------------------------------------------------------------------------------------
-- Static content
---------------------------------------------------------------------------------------------------
function W.Header(parent, text, width)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(width, 22)
    local label = W.Text(row, W.fonts.heading)
    label:SetPoint("LEFT", 0, 0)
    label:SetText(text or "")
    local line = W.Line(row)
    line:SetHeight(1)
    line:SetPoint("LEFT", label, "RIGHT", 10, 0)
    line:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.label = label
    return row
end

function W.Description(parent, text, width)
    local row = CreateFrame("Frame", nil, parent)
    local label = W.Text(row, W.fonts.small)
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetWidth(width)
    label:SetJustifyV("TOP")
    label:SetText(text or "")
    row:SetSize(width, max(14, label:GetStringHeight() + 2))
    row.label = label
    return row
end

function W.ActionButton(parent, opt, width)
    local row = newRow(parent, opt, {}, width, 26, "button")
    local button = W.Button(row, opt.label, min(width, opt.buttonWidth or 220), function()
        if row.enabled and opt.func then opt.func() end
    end, 24)
    button:SetPoint("LEFT", 0, 0)
    if opt.tooltip then
        button:HookScript("OnEnter", function(self) W.ShowTooltip(self, opt.label, opt.tooltip) end)
        button:HookScript("OnLeave", GameTooltip_Hide)
    end
    function row:OnEnabledChanged(enabled)
        if enabled then button:Enable() else button:Disable() end
        self:SetAlpha(1)
    end
    function row:Refresh() end
    row.button = button
    return row
end

-- Builds the right control for an option description.
function W.Create(parent, opt, access, width)
    local kind = opt.type
    if kind == "toggle" then return W.Toggle(parent, opt, access, width) end
    if kind == "range" then return W.Range(parent, opt, access, width) end
    if kind == "select" or kind == "media" then return W.Select(parent, opt, access, width) end
    if kind == "color" then return W.Color(parent, opt, access, width) end
    if kind == "text" then return W.Input(parent, opt, access, width) end
    if kind == "button" then return W.ActionButton(parent, opt, width) end
    if kind == "header" then return W.Header(parent, opt.label, width) end
    if kind == "description" then return W.Description(parent, opt.label, width) end
end
