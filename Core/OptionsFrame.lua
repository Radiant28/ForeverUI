-- ForeverUI options window: WoW Forever bronze chrome, inner panel, sidebar tabs,
-- lazily built pages from declarative schemas, search, live refresh and reload footer.
local addonName, ui = ...
local L, W, S = ui.L, ui.Widgets, ui.Style
local rgba = W.rgba
local max, min, floor = math.max, math.min, math.floor

local WIDTH, HEIGHT = 860, 580
-- Size limits for resizing with the right mouse button. No real minimum: only enough for the sidebar,
-- the header and the footer so the window never collapses; narrow pages are laid out in what is left.
local MIN_WIDTH, MAX_WIDTH, MIN_HEIGHT, MAX_HEIGHT = 340, 1500, 160, 1100
local SIDEBAR, CHROME_SCALE = 208, 0.5
local INNER_LEFT, INNER_RIGHT, INNER_TOP, INNER_BOTTOM = 14, 14, 66, 46
local HEADER_BAR, FOOTER = 34, 34
local function pageWidth(windowWidth)
    return max(120, floor((windowWidth or WIDTH) + 0.5) - SIDEBAR - 80)
end
local PAGE_HEADER = 60

local window, sidebar, pages, tabs, current, searchText = nil, nil, {}, {}, nil, ""

---------------------------------------------------------------------------------------------------
-- Page building
---------------------------------------------------------------------------------------------------
local function optionAccess(spec, opt)
    local id, key = spec.id, opt.key
    return {
        get = function() return ui.GetOption(id, key) end,
        set = function(value) ui.SetOption(id, key, value) end,
        reset = function() ui.ResetOption(id, key) end,
        isDefault = function() return ui.IsDefault(id, key) end,
    }
end

local function matches(opt, needle)
    if needle == "" then return false end
    local text = W.Fold((opt.label or "") .. " " .. (opt.tooltip or ""))
    return text:find(needle, 1, true) ~= nil
end

local function moduleMatches(spec, needle)
    if needle == "" then return true end
    if W.Fold((spec.title or "") .. " " .. (spec.description or "")):find(needle, 1, true) then return true end
    for _, opt in ipairs(spec.options) do
        if matches(opt, needle) then return true end
    end
    return false
end

local function layoutSection(page, child, section, spec, y, width)
    if section.title then
        local header = W.Header(child, section.title, width)
        header:SetPoint("TOPLEFT", 0, y)
        y = y - 28
    end
    if section.description then
        local text = W.Description(child, section.description, width)
        text:SetPoint("TOPLEFT", 0, y)
        y = y - text:GetHeight() - 8
    end
    local columns = section.columns or 2
    local columnWidth = floor((width - S.columnGap * (columns - 1)) / columns)
    local column, lineHeight = 0, 0
    local function newLine()
        if column > 0 then
            y = y - lineHeight - S.rowGap
            column, lineHeight = 0, 0
        end
    end
    for _, opt in ipairs(section.options or {}) do
        local hidden = opt.hidden and opt.hidden()
        if not hidden then
            if opt.type == "custom" then
                newLine()
                local holder = CreateFrame("Frame", nil, child)
                holder:SetPoint("TOPLEFT", 0, y)
                holder:SetWidth(width)
                local height = opt.build(holder, width, spec) or 0
                holder:SetHeight(max(1, height))
                for _, anchor in ipairs(holder.anchors or {}) do
                    page.customTabs[#page.customTabs + 1] = { title = anchor.title, top = -y + (anchor.top or 0),
                        section = page.layingSection }
                end
                y = y - height - S.rowGap
                page.customs[#page.customs + 1] = { frame = holder, opt = opt }
            else
                local full = opt.width == "full" or opt.type == "header" or opt.type == "description"
                if full then newLine() end
                local controlWidth = full and width or columnWidth
                local row = W.Create(child, opt, optionAccess(spec, opt), controlWidth)
                if row then
                    if opt.type == "header" then
                        if column > 0 then newLine() end
                        y = y - 4
                    end
                    row:SetPoint("TOPLEFT", column * (columnWidth + S.columnGap), y)
                    lineHeight = max(lineHeight, row:GetHeight())
                    page.rows[#page.rows + 1] = { row = row, opt = opt }
                    if full then
                        column = columns
                    else
                        column = column + 1
                    end
                    if column >= columns then newLine() end
                end
            end
        end
    end
    newLine()
    return y - S.sectionGap + S.rowGap
end

local function refreshPage(page)
    local spec = page.spec
    for _, entry in ipairs(page.rows) do
        local row, opt = entry.row, entry.opt
        if row.SetEnabled then row:SetEnabled(ui.IsOptionAvailable(spec, opt)) end
        if row.Refresh then row:Refresh() end
        if row.label then
            local hit = matches(opt, searchText)
            if opt.type ~= "header" and opt.type ~= "description" then
                row.label:SetTextColor(rgba(hit and S.accentText or S.text))
            end
        end
    end
    for _, entry in ipairs(page.customs) do
        local enabled = ui.IsOptionAvailable(spec, entry.opt)
        entry.frame:SetAlpha(enabled and 1 or S.disabledAlpha)
        if entry.opt.refresh then entry.opt.refresh(entry.frame, enabled) end
    end
    W.Redraw(page.scroll)
    if page.resetButton then
        local any = false
        for _, opt in ipairs(spec.options) do
            if opt.key and opt.default ~= nil and not ui.IsDefault(spec.id, opt.key) then any = true break end
        end
        if any then page.resetButton:Enable() else page.resetButton:Disable() end
    end
end

local function confirmReset(spec)
    StaticPopupDialogs.FOREVERUI_RESET_MODULE = StaticPopupDialogs.FOREVERUI_RESET_MODULE or {
        button1 = YES, button2 = NO, timeout = 0, whileDead = 1, hideOnEscape = 1,
        OnAccept = function(self) ui.ResetModule(self.data) end,
    }
    StaticPopupDialogs.FOREVERUI_RESET_MODULE.text = L("Сбросить все настройки раздела «%s»?",
        "Reset every setting of “%s”?")
    local dialog = StaticPopup_Show("FOREVERUI_RESET_MODULE", spec.title)
    if dialog then dialog.data = spec.id end
end

---------------------------------------------------------------------------------------------------
-- Section tabs: bronze beveled sub-tabs above the page. A click scrolls to the section;
-- the tab of the section in view is highlighted while scrolling. Rows wrap on narrow windows.
---------------------------------------------------------------------------------------------------
local TAB_HEIGHT, TAB_GAP, TAB_MAX = 22, 5, 190

local function sectionTabs(spec)
    local list = {}
    for index, section in ipairs(spec.sections or {}) do
        local title = section.title
        if not title and index == 1 and #(section.options or {}) > 0 then title = L("Основное", "General") end
        if title then list[#list + 1] = { index = index, title = title } end
    end
    return list
end

local function paintSectionTab(tab, active, hovered)
    if active then
        tab.art:SetUV(W.UV.ddOpen)
        tab.activeGlow:Show()
        tab.text:SetTextColor(1, 1, 1)
    elseif hovered then
        tab.art:SetUV(W.UV.ddHover)
        tab.activeGlow:Hide()
        tab.text:SetTextColor(rgba(S.accentText))
    else
        tab.art:SetUV(W.UV.ddNormal)
        tab.activeGlow:Hide()
        tab.text:SetTextColor(rgba(S.text))
    end
end

local function buildSectionTabs(page, list, width)
    local bar = CreateFrame("Frame", nil, page)
    bar:SetPoint("TOPLEFT", 20, -PAGE_HEADER - 8)
    bar:SetWidth(width)
    page.sectionTabs = {}
    local x, y = 0, 0
    for i, entry in ipairs(list) do
        local tab = CreateFrame("Button", nil, bar)
        tab.art = W.ThreeSlice(tab, W.UV.ddNormal, "BACKGROUND", 2, 2, 5)
        tab.activeGlow = tab:CreateTexture(nil, "ARTWORK")
        W.ApplyUV(tab.activeGlow, W.UV.listActive)
        tab.activeGlow:SetAllPoints(tab)
        tab.activeGlow:Hide()
        local text = W.Text(tab, W.fonts.small)
        text:SetPoint("LEFT", 8, 0)
        text:SetPoint("RIGHT", -8, 0)
        text:SetJustifyH("CENTER")
        text:SetText(entry.title)
        tab.text = text
        local full = floor((text:GetStringWidth() or 60) + 0.5) + 18
        local tabWidth = min(TAB_MAX, width, full)
        tab.truncated = full > tabWidth
        tab:SetSize(tabWidth, TAB_HEIGHT)
        if x > 0 and x + tabWidth > width then
            x, y = 0, y - TAB_HEIGHT - TAB_GAP
        end
        tab:SetPoint("TOPLEFT", x, y)
        x = x + tabWidth + TAB_GAP
        tab.entry = entry
        tab:SetScript("OnClick", function()
            PlaySound("igMainMenuOptionCheckBoxOn")
            page:ShowSection(i)
        end)
        tab:SetScript("OnEnter", function(self)
            self.hovered = true
            paintSectionTab(self, self.index == page.activeTab, true)
            if self.truncated then
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                GameTooltip:SetText(entry.title, 1, 0.82, 0)
                GameTooltip:Show()
            end
            W.Redraw(self)
        end)
        tab:SetScript("OnLeave", function(self)
            self.hovered = false
            paintSectionTab(self, self.index == page.activeTab, false)
            GameTooltip:Hide()
            W.Redraw(self)
        end)
        tab.index = i
        paintSectionTab(tab, i == 1, false)
        page.sectionTabs[i] = tab
    end
    local height = -y + TAB_HEIGHT
    bar:SetHeight(height)
    page.sectionBar = bar
    return height
end

local function setActiveTab(page, index)
    if page.activeTab == index then return end
    page.activeTab = index
    for i, tab in ipairs(page.sectionTabs or {}) do
        paintSectionTab(tab, i == index, tab.hovered)
    end
end

local function buildPage(spec)
    local page = CreateFrame("Frame", nil, window.content)
    page:SetAllPoints(window.content)
    page.spec, page.rows, page.customs = spec, {}, {}

    local title = W.Text(page, W.fonts.title)
    title:SetPoint("TOPLEFT", 20, -14)
    title:SetText(spec.title or spec.id)
    local description = W.Text(page, W.fonts.small)
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    description:SetPoint("RIGHT", page, "RIGHT", -170, 0)
    description:SetHeight(14)
    description:SetText(spec.description or "")
    local divider = W.Divider(page)
    divider:SetHeight(2)
    divider:SetPoint("TOPLEFT", 20, -PAGE_HEADER + 4)
    divider:SetPoint("TOPRIGHT", -20, -PAGE_HEADER + 4)

    local hasDefaults = false
    for _, opt in ipairs(spec.options) do
        if opt.key and opt.default ~= nil and not opt.noReset then hasDefaults = true break end
    end
    if hasDefaults then
        local reset = W.Button(page, L("Сбросить раздел", "Reset section"), 140, function() confirmReset(spec) end, 24)
        reset:SetPoint("TOPRIGHT", -20, -14)
        page.resetButton = reset
    end

    local reason = spec.unavailable and spec.unavailable()
    if reason then
        local notice = W.Text(page, W.fonts.label)
        notice:SetPoint("TOPLEFT", 20, -PAGE_HEADER - 14)
        notice:SetPoint("RIGHT", page, "RIGHT", -20, 0)
        notice:SetTextColor(rgba(S.muted))
        notice:SetText(reason)
        page.Refresh = function() end
        return page
    end

    ui.NormalizeModule(spec.id)
    local width = pageWidth(window:GetWidth())
    local scroll = W.Scroll(page)
    page.builtWidth = width
    scroll.child:SetWidth(width)
    local y = 0
    local sectionTop = {}
    page.customTabs = {}
    for index, section in ipairs(spec.sections) do
        sectionTop[index] = -y
        page.layingSection = index
        y = layoutSection(page, scroll.child, section, spec, y, width)
    end
    page.layingSection = nil
    scroll:SetContentHeight(-y)
    page.scroll = scroll
    local marked = {}
    for _, entry in ipairs(page.customTabs) do marked[entry.section] = true end
    local tabList = {}
    for _, entry in ipairs(sectionTabs(spec)) do
        if spec.sections[entry.index].title or not marked[entry.index] then
            tabList[#tabList + 1] = { title = entry.title, top = sectionTop[entry.index] or 0 }
        end
    end
    for _, entry in ipairs(page.customTabs) do tabList[#tabList + 1] = { title = entry.title, top = entry.top } end
    table.sort(tabList, function(a, b) return a.top < b.top end)
    local tabsHeight = 0
    if #tabList >= 2 then tabsHeight = buildSectionTabs(page, tabList, width) + 8 end
    scroll:SetPoint("TOPLEFT", 20, -PAGE_HEADER - 16 - tabsHeight)
    scroll:SetPoint("BOTTOMRIGHT", -28, 16)
    if page.sectionTabs then
        for _, tab in ipairs(page.sectionTabs) do tab.top = tab.entry.top or 0 end
        function page:ShowSection(i)
            local tab = self.sectionTabs[i]
            if not tab then return end
            scroll:ScrollTo(tab.top)
            self.clickedTab, self.clickedOffset = i, scroll:GetVerticalScroll()
            setActiveTab(self, i)
            W.Redraw(scroll)
        end
        scroll.onScroll = function(_, offset)
            if page.clickedTab and math.abs(offset - (page.clickedOffset or -1)) < 1 then
                setActiveTab(page, page.clickedTab)
                return
            end
            page.clickedTab = nil
            local active = 1
            for i, tab in ipairs(page.sectionTabs) do
                if tab.top <= offset + 8 then active = i end
            end
            setActiveTab(page, active)
        end
        page.activeTab = 1
    end
    page.Refresh = refreshPage
    page:Refresh()
    return page
end

---------------------------------------------------------------------------------------------------
-- Sidebar
---------------------------------------------------------------------------------------------------
local function paintTab(tab)
    local selected = current == tab.spec.id
    W.SetVisible(tab.activeBg, selected)
    tab.text:SetTextColor(rgba(selected and { 1, 1, 1 } or S.accentText))
    local enabled = ui.IsModuleEnabled(tab.spec.id)
    tab.dot:SetVertexColor(rgba(enabled and S.success or S.muted, enabled and 0.9 or 0.5))
end

local function selectModule(id)
    local spec = ui.GetModule(id)
    if not spec then return end
    W.CloseList()
    if current and pages[current] then pages[current]:Hide() end
    current = id
    if window and window.chromeArt then
        window.chromeArt:SetPortrait(spec.icon or "Interface\\Icons\\INV_Misc_Gear_01")
    end
    if not pages[id] then pages[id] = buildPage(spec) end
    pages[id]:Show()
    pages[id]:Refresh()
    for _, tab in pairs(tabs) do paintTab(tab) end
    W.Redraw(sidebar)
end

local function createTab(spec)
    local tab = CreateFrame("Button", nil, sidebar.child)
    tab:SetHeight(26)
    tab.spec = spec
    tab.activeBg = tab:CreateTexture(nil, "BACKGROUND")
    W.ApplyUV(tab.activeBg, W.UV.listActive)
    tab.activeBg:SetPoint("TOPLEFT", -2, 0)
    tab.activeBg:SetPoint("BOTTOMRIGHT", 2, 0)
    tab.activeBg:Hide()
    local hover = tab:CreateTexture(nil, "HIGHLIGHT")
    W.ApplyUV(hover, W.UV.listHover)
    hover:SetPoint("TOPLEFT", -2, 0)
    hover:SetPoint("BOTTOMRIGHT", 2, 0)
    local icon = tab:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", 10, 0)
    icon:SetTexture(spec.icon or "Interface\\Icons\\INV_Misc_Gear_01")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    tab.iconRim = tab:CreateTexture(nil, "OVERLAY")
    W.ApplyUV(tab.iconRim, W.UV.slotRim)
    tab.iconRim:SetSize(20, 20)
    tab.iconRim:SetPoint("CENTER", icon, "CENTER", 0, 0)
    tab.iconRim:SetVertexColor(0.88, 0.82, 0.72)
    tab.text = W.Text(tab, W.fonts.label)
    tab.text:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    tab.text:SetPoint("RIGHT", -18, 0)
    tab.text:SetHeight(20)
    tab.text:SetText(spec.title or spec.id)
    tab.dot = tab:CreateTexture(nil, "OVERLAY")
    tab.dot:SetTexture("Interface\\Buttons\\WHITE8X8")
    tab.dot:SetSize(5, 5)
    tab.dot:SetPoint("RIGHT", -8, 0)
    tab:SetScript("OnClick", function()
        PlaySound("igMainMenuOptionCheckBoxOn")
        selectModule(spec.id)
    end)
    tabs[spec.id] = tab
    return tab
end

local function layoutSidebar()
    local y = -4
    local needle = searchText
    local groupLabels = sidebar.groupLabels
    local groupLines = sidebar.groupLines
    for _, label in pairs(groupLabels) do label:Hide() end
    for _, line in pairs(groupLines) do line:Hide() end
    for _, tab in pairs(tabs) do tab:Hide() end
    local known = {}
    for _, group in ipairs(ui.Groups) do known[group.id] = true end
    local groups = {}
    for _, group in ipairs(ui.Groups) do groups[#groups + 1] = group end
    groups[#groups + 1] = { id = "other", title = L("Прочее", "Other") }
    local first
    for _, group in ipairs(groups) do
        local shown = false
        for _, spec in ipairs(ui.optionOrder) do
            local inGroup = (spec.group or "other") == group.id or (group.id == "other" and not known[spec.group or ""])
            if inGroup and not spec.hidden and moduleMatches(spec, needle) then
                if not shown then
                    shown = true
                    local label = groupLabels[group.id]
                    if not label then
                        label = W.Text(sidebar.child, W.fonts.group)
                        groupLabels[group.id] = label
                    end
                    label:SetText((group.title or ""):upper())
                    label:ClearAllPoints()
                    label:SetPoint("TOPLEFT", 12, y - 8)
                    label:Show()
                    local line = groupLines[group.id]
                    if not line then
                        line = W.Divider(sidebar.child)
                        groupLines[group.id] = line
                    end
                    line:ClearAllPoints()
                    line:SetPoint("TOPLEFT", 10, y - 22)
                    line:SetPoint("RIGHT", sidebar.child, "RIGHT", -6, 0)
                    line:Show()
                    y = y - 28
                end
                local tab = tabs[spec.id] or createTab(spec)
                tab:ClearAllPoints()
                tab:SetPoint("TOPLEFT", 0, y)
                tab:SetPoint("RIGHT", sidebar.child, "RIGHT", 0, 0)
                tab:Show()
                paintTab(tab)
                first = first or spec.id
                y = y - 26
            end
        end
    end
    sidebar:SetContentHeight(-y + 8)
    W.Redraw(sidebar)
    return first
end

---------------------------------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------------------------------
local function savePosition()
    local settings = ui.Settings()
    local point, _, relativePoint, x, y = window:GetPoint(1)
    settings.optionsWindow = { point, relativePoint, x, y }
end

local function restorePosition()
    local saved = ui.Settings().optionsWindow
    window:ClearAllPoints()
    if type(saved) == "table" and type(saved[1]) == "string" and ui.IsFinite(saved[3]) and ui.IsFinite(saved[4]) then
        window:SetPoint(saved[1], UIParent, saved[2] or saved[1], saved[3], saved[4])
    else
        window:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    end
end

local function updateFooter()
    if not window then return end
    local footer = window.footer
    W.SetVisible(footer.reload, ui.IsReloadPending())
    if ui.HasCombatQueue() then
        footer.status:SetText(L("Часть изменений применится после выхода из боя.",
            "Some changes will apply after combat ends."))
        footer.status:SetTextColor(0.55, 0.75, 1)
    elseif ui.IsReloadPending() then
        footer.status:SetText(L("Некоторые изменения вступят в силу после перезагрузки интерфейса.",
            "Some changes take effect after a UI reload."))
        footer.status:SetTextColor(1, 0.62, 0.40)
    else
        footer.status:SetText(L("Изменения применяются сразу; Shift + колесо — точная настройка; ПКМ по заголовку — размер окна",
            "Changes apply instantly; Shift + wheel fine-tunes; right drag the header to resize"))
        footer.status:SetTextColor(rgba(S.muted))
    end
end

---------------------------------------------------------------------------------------------------
-- Resizing with the right mouse button
---------------------------------------------------------------------------------------------------
local sizing

local function cursor()
    local x, y = GetCursorPosition()
    local s = window:GetEffectiveScale()
    return x / s, y / s
end

local function limits()
    local scale = window:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local screenW, screenH = UIParent:GetWidth() / scale, UIParent:GetHeight() / scale
    return MIN_WIDTH, max(MIN_WIDTH, min(MAX_WIDTH, screenW - 20)), MIN_HEIGHT, max(MIN_HEIGHT, min(MAX_HEIGHT, screenH - 20))
end

local function syncChromeSize(width, height)
    if window.chromeArt then window.chromeArt:Update(width, height) end
    if window.inner then
        window.inner:Layout(width - INNER_LEFT - INNER_RIGHT, height - INNER_TOP - INNER_BOTTOM)
    end
end

local function applySavedSize()
    local saved = ui.Settings().optionsSize
    local width, height = WIDTH, HEIGHT
    if type(saved) == "table" and ui.IsFinite(saved[1]) and ui.IsFinite(saved[2]) then
        local minW, maxW, minH, maxH = limits()
        width, height = max(minW, min(maxW, saved[1])), max(minH, min(maxH, saved[2]))
    end
    window:SetWidth(width)
    window:SetHeight(height)
    syncChromeSize(width, height)
end

local function pinTopLeft(left, top)
    window:ClearAllPoints()
    window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

local function rebuildPages()
    local width = pageWidth(window:GetWidth())
    local stale = false
    for _, page in pairs(pages) do
        if page.builtWidth and page.builtWidth ~= width then stale = true end
    end
    if not stale then return end
    W.CloseList()
    for id, page in pairs(pages) do
        page:Hide()
        pages[id] = nil
    end
    if current then
        local id = current
        current = nil
        selectModule(id)
    end
end

local function stopSizing()
    if not sizing then return end
    sizing = nil
    window:SetScript("OnUpdate", nil)
    window.sizeLabel:Hide()
    ui.Settings().optionsSize = { floor(window:GetWidth() + 0.5), floor(window:GetHeight() + 0.5) }
    savePosition()
    rebuildPages()
end

local function startSizing()
    if sizing or not window:GetLeft() then return end
    local x, y = cursor()
    sizing = { x = x, y = y, width = window:GetWidth(), height = window:GetHeight() }
    pinTopLeft(window:GetLeft(), window:GetTop())
    window.sizeLabel:Show()
    window:SetScript("OnUpdate", function()
        if not IsMouseButtonDown("RightButton") then
            stopSizing()
            return
        end
        local cx, cy = cursor()
        local minW, maxW, minH, maxH = limits()
        local width = max(minW, min(maxW, sizing.width + (cx - sizing.x)))
        local height = max(minH, min(maxH, sizing.height - (cy - sizing.y)))
        if math.abs(width - window:GetWidth()) > 0.5 or math.abs(height - window:GetHeight()) > 0.5 then
            window:SetWidth(width)
            window:SetHeight(height)
            syncChromeSize(width, height)
            for _, page in pairs(pages) do
                if page.scroll and page:IsShown() then page.scroll:Update() end
            end
        end
        window.sizeLabel:SetText(("%d x %d"):format(floor(width + 0.5), floor(height + 0.5)))
    end)
end

local function bindSizing(frame)
    frame:EnableMouse(true)
    frame:HookScript("OnMouseDown", function(_, button) if button == "RightButton" then startSizing() end end)
    frame:HookScript("OnMouseUp", function(_, button) if button == "RightButton" then stopSizing() end end)
end

local function createWindow()
    window = CreateFrame("Frame", "ForeverUIOptions", UIParent)
    window:SetSize(WIDTH, HEIGHT)
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:Hide()
    tinsert(UISpecialFrames, window:GetName())

    local baseLevel = window:GetFrameLevel()
    window.chromeArt = W.BuildBronzeChrome(window, CHROME_SCALE, true)
    window.chrome = window.chromeArt.chrome
    window.chromeArt:SetPortrait("Interface\\Icons\\INV_Misc_Gear_01")

    local inner = W.InnerFrame(window, SIDEBAR)
    inner:SetPoint("TOPLEFT", window, "TOPLEFT", INNER_LEFT, -INNER_TOP)
    inner:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -INNER_RIGHT, INNER_BOTTOM)
    window.inner = inner

    applySavedSize()

    -- Header bar (overlaps top bronze strip for dragging, resizing and title)
    local header = CreateFrame("Frame", nil, window)
    header:SetFrameLevel(baseLevel + 8)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(HEADER_BAR)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() window:StartMoving() end)
    header:SetScript("OnDragStop", function()
        window:StopMovingOrSizing()
        savePosition()
    end)
    local brand = W.Text(header, W.fonts.title)
    brand:SetPoint("CENTER", header, "TOP", 0, window.chromeArt.headerY)
    brand:SetText("Forever |cffffd200UI|r")

    bindSizing(header)
    header:HookScript("OnEnter", function(self)
        W.ShowTooltip(self, L("Окно настроек", "Settings window"),
            L("ЛКМ — перетащить окно.\nПКМ (зажать и тянуть) — размер: вправо шире, вниз выше.\nМасштаб — во вкладке «Общие».",
                "Left drag moves the window.\nRight drag resizes it: right is wider, down is taller.\nScale lives on the General page."))
    end)
    header:HookScript("OnLeave", GameTooltip_Hide)
    window.sizeLabel = W.Text(header, W.fonts.heading)
    window.sizeLabel:SetPoint("LEFT", brand, "RIGHT", 14, 0)
    window.sizeLabel:Hide()

    local close = W.CloseButton(window, function() window:Hide() end, 56 * CHROME_SCALE)
    close:SetFrameLevel(baseLevel + 10)
    close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -2, 0)
    window.closeButton = close

    local subtitle = W.Text(header, W.fonts.small)
    subtitle:SetPoint("TOPLEFT", window, "TOPLEFT", 66, -42)
    subtitle:SetText("WoW Forever — v" .. (GetAddOnMetadata(addonName, "Version") or "?"))

    local search = CreateFrame("EditBox", nil, header)
    search:SetSize(220, 24)
    search:SetPoint("TOPRIGHT", window, "TOPRIGHT", -16, -37)
    search:SetFontObject(W.fonts.label)
    search:SetAutoFocus(false)
    search:SetTextInsets(22, 22, 0, 0)
    local hint = W.Text(search, W.fonts.small)
    hint:SetPoint("LEFT", 23, 0)
    hint:SetText(L("Поиск настройки…", "Search settings…"))
    local function applySearch(text)
        W.SetVisible(hint, text == "")
        searchText = W.Fold(text)
        local first = layoutSidebar()
        local spec = current and ui.GetModule(current)
        if searchText ~= "" and first and not (spec and moduleMatches(spec, searchText)) then
            selectModule(first)
        elseif current and pages[current] then
            pages[current]:Refresh()
        end
    end
    search:SetScript("OnEscapePressed", function(self)
        if (self:GetText() or "") ~= "" then self:SetText("") else self:ClearFocus() end
    end)
    search:SetScript("OnEnterPressed", search.ClearFocus)
    search:SetScript("OnTextChanged", function(self) applySearch(self:GetText() or "") end)
    W.StyleInput(search, true, function() applySearch("") end)
    window.search = search

    -- Sidebar inside inner frame
    local side = CreateFrame("Frame", nil, window)
    side:SetFrameLevel(baseLevel + 2)
    side:SetPoint("TOPLEFT", inner, "TOPLEFT", 2, -2)
    side:SetPoint("BOTTOMLEFT", inner, "BOTTOMLEFT", 2, 2)
    side:SetWidth(SIDEBAR - 2)
    sidebar = W.Scroll(side, 8, 2)
    sidebar:SetPoint("TOPLEFT", 2, -14)
    sidebar:SetPoint("BOTTOMRIGHT", -18, 14)
    sidebar.child:SetWidth(SIDEBAR - 22)
    sidebar.groupLabels, sidebar.groupLines = {}, {}

    -- Content inside inner frame
    local content = CreateFrame("Frame", nil, window)
    content:SetFrameLevel(baseLevel + 2)
    content:SetPoint("TOPLEFT", inner, "TOPLEFT", SIDEBAR + 2, -2)
    content:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", -2, 2)
    window.content = content

    -- Footer
    local footer = CreateFrame("Frame", nil, window)
    footer:SetFrameLevel(baseLevel + 2)
    footer:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", INNER_LEFT, 10)
    footer:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -INNER_RIGHT, 10)
    footer:SetHeight(FOOTER)
    footer.status = W.Text(footer, W.fonts.small)
    footer.status:SetPoint("LEFT", 4, 0)
    footer.status:SetPoint("RIGHT", footer, "RIGHT", -334, 0)
    footer.status:SetHeight(16)
    footer.reload = W.Button(footer, L("Перезагрузить UI", "Reload UI"), 140, ReloadUI, 24)
    footer.reload:SetPoint("RIGHT", -18, 0)
    footer.reload.text:SetTextColor(1, 0.75, 0.45)
    footer.edit = W.Button(footer, L("Режим редактирования", "Edit Mode"), 170, function()
        if ui.EditMode and ui.EditMode.Open then
            window:Hide()
            ui.EditMode.Open()
        end
    end, 24)
    footer.edit:SetPoint("RIGHT", footer.reload, "LEFT", -8, 0)
    window.footer = footer

    local grip = CreateFrame("Button", nil, window)
    grip:SetSize(14, 14)
    grip:SetPoint("BOTTOMRIGHT", -8, 8)
    grip:SetFrameLevel(baseLevel + 10)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    bindSizing(grip)
    grip:SetScript("OnEnter", function(self)
        W.ShowTooltip(self, L("Размер окна", "Window size"), L("Зажмите ПКМ и тяните: вправо шире, вниз выше.",
            "Hold the right button and drag: right is wider, down is taller."))
    end)
    grip:SetScript("OnLeave", GameTooltip_Hide)

    window:SetScript("OnShow", function(self)
        self:SetScale((ui.Settings().optionsScale or 100) / 100)
        syncChromeSize(self:GetWidth() or WIDTH, self:GetHeight() or HEIGHT)
        updateFooter()
        W.SetVisible(footer.edit, ui.EditMode ~= nil)
        if current and pages[current] then pages[current]:Refresh() end
        for _, tab in pairs(tabs) do paintTab(tab) end
    end)
    window:SetScript("OnHide", function()
        stopSizing()
        W.CloseList()
        search:ClearFocus()
        PlaySound("igMainMenuClose")
    end)
    restorePosition()
end

function ui.OpenOptions(target)
    if type(target) == "table" and target.foreverModule then target = target.foreverModule end
    if type(target) == "table" then
        InterfaceOptionsFrame_OpenToCategory(target)
        InterfaceOptionsFrame_OpenToCategory(target)
        return
    end
    if not window then createWindow() end
    if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then HideUIPanel(InterfaceOptionsFrame) end
    local first = layoutSidebar()
    local id = (type(target) == "string" and ui.GetModule(target) and target) or current or first
    window:Show()
    PlaySound("igMainMenuOpen")
    if id then selectModule(id) end
end

function ui.ToggleOptions(target)
    if window and window:IsShown() and (not target or target == current) then
        window:Hide()
    else
        ui.OpenOptions(target)
    end
end

function ui.ApplyOptionsWindowScale()
    if window then window:SetScale((ui.Settings().optionsScale or 100) / 100) end
end

ui.RegisterCallback("SettingChanged", function(id)
    if not window or not window:IsShown() then return end
    if current == id and pages[id] then pages[id]:Refresh() end
    if tabs[id] then paintTab(tabs[id]) end
    W.Redraw(sidebar)
end, "OptionsFrame")
ui.RegisterCallback("ModuleReset", function(id)
    if pages[id] and window and window:IsShown() then pages[id]:Refresh() end
    if tabs[id] then paintTab(tabs[id]) end
end, "OptionsFrameReset")
ui.RegisterCallback("OptionsRefresh", function(id)
    if pages[id] and window and window:IsShown() then pages[id]:Refresh() end
end, "OptionsFrameRefresh")
ui.RegisterCallback("ReloadPending", updateFooter, "OptionsFrameReload")
ui.RegisterCallback("CombatQueued", updateFooter, "OptionsFrameCombat")
ui.RegisterCallback("CombatQueueFlushed", updateFooter, "OptionsFrameFlush")
ui.RegisterCallback("ModuleRegistered", function(id)
    if pages[id] then
        pages[id]:Hide()
        pages[id] = nil
        if current == id and window and window:IsShown() then selectModule(id) end
    end
    if window and window:IsShown() then layoutSidebar() end
end, "OptionsFrameModules")

---------------------------------------------------------------------------------------------------
-- Blizzard Interface Options entry and slash commands
---------------------------------------------------------------------------------------------------
local blizzard = CreateFrame("Frame", nil, InterfaceOptionsFramePanelContainer)
blizzard.name = "Forever UI"
do
    local title = blizzard:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Forever UI")
    local text = blizzard:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    text:SetWidth(560)
    text:SetJustifyH("LEFT")
    text:SetText(L("Все настройки ForeverUI собраны в отдельном окне. Команда: /fui",
        "All ForeverUI settings live in their own window. Command: /fui"))
    local open = W.Button(blizzard, L("Открыть настройки Forever UI", "Open Forever UI settings"), 240, function()
        ui.OpenOptions()
    end, 26)
    open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -14)
end
InterfaceOptions_AddCategory(blizzard)
ui.blizzardOptions = blizzard

SLASH_FOREVERUI1 = "/fui"
SLASH_FOREVERUI2 = "/foreverui"
SlashCmdList.FOREVERUI = function(input)
    local command = (input or ""):match("^%s*(%S*)")
    if command == "reset" then
        StaticPopup_Show("FOREVERUI_RESET_ALL")
        return
    end
    if (command == "install" or command == "setup" or command == "copy") and ui.Setup and ui.Setup.Open then
        ui.Setup.Open(command == "copy" and "copy" or "full")
        return
    end
    ui.ToggleOptions(command ~= "" and command or nil)
end

StaticPopupDialogs.FOREVERUI_RESET_ALL = {
    text = L("Сбросить ВСЕ настройки Forever UI и перезагрузить интерфейс?",
        "Reset ALL Forever UI settings and reload the interface?"),
    button1 = YES, button2 = NO, timeout = 0, whileDead = 1, hideOnEscape = 1,
    OnAccept = function()
        for _, spec in ipairs(ui.optionOrder) do ui.ResetModule(spec.id) end
        ReloadUI()
    end,
}
