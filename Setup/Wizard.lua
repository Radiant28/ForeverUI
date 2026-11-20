-- The setup wizard: a compact window in the bronze WoW Forever frame, the step icon in the portrait ring, Back / Next.
-- Every choice shows at once on the running interface; Cancel (or the close button) puts back what was there.
--   full  - new character: welcome, role, style, scale, layout, modules, chat, done (quick path: role -> done)
--   spec  - first switch to a talent set: welcome, role, layout, modules, done
--   copy  - copy every talent set of another character
local _, ui = ...
local L, W, S = ui.L, ui.Widgets, ui.Style
local Setup, Layouts = ui.Setup, ui.SetupLayouts
local copy = ui.CopyTable
local rgba = W.rgba

local WIDTH, HEIGHT = 480, 384
local PAD = 24
local INNER = WIDTH - 2 * PAD
local CHROME_SCALE = 0.5
local ART = "Interface\\AddOns\\ForeverUI\\Art\\Forever\\Window-"
-- Header band: centre of its dark strip below the outer edge (texture px of the metal sheet, see WindowSkin.lua).
local HEADER_CENTER = 31
local CONTENT_TOP = 66

local ICONS = {
    welcome = "Interface\\Icons\\INV_Misc_Book_09",
    spec = "Interface\\Icons\\Ability_Marksmanship",
    copy = "Interface\\Icons\\INV_Misc_Note_01",
    style = "Interface\\Icons\\INV_Inscription_Tradeskill01",
    scale = "Interface\\Icons\\INV_Misc_Spyglass_03",
    layout = "Interface\\Icons\\INV_Misc_Map_01",
    modules = "Interface\\Icons\\Trade_Engineering",
    chat = "Interface\\Icons\\INV_Letter_15",
    done = "Interface\\Icons\\Spell_ChargePositive",
}
local TITLES = {
    welcome = L("Добро пожаловать", "Welcome"), spec = L("Новый набор талантов", "New talent set"),
    copy = L("Копия персонажа", "Copy a character"), role = L("Роль", "Role"), style = L("Стиль", "Style"),
    scale = L("Масштаб", "Scale"), layout = L("Раскладка", "Layout"), modules = L("Модули", "Modules"),
    chat = L("Чат", "Chat"), done = L("Готово", "Done"),
}
local FULL = { "welcome", "role", "style", "scale", "layout", "modules", "chat", "done" }
local QUICK = { "welcome", "role", "done" }
local SPEC = { "spec", "role", "layout", "modules", "done" }
local COPY_FROM_WELCOME = { "welcome", "copy", "done" }
local COPY = { "copy", "done" }

local frame, session
local pages = {}

---------------------------------------------------------------------------------------------------
-- Small building blocks
---------------------------------------------------------------------------------------------------
local function wrapText(parent, fontObject, width)
    local text = W.Text(parent, fontObject)
    text:SetWidth(width)
    text:SetJustifyV("TOP")
    if text.SetWordWrap then text:SetWordWrap(true) end
    return text
end

-- A choice card: icon, title, one line of text; :SetSelected(on), :SetAvailable(on).
local function card(parent, width, height, icon, title, text, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height)
    W.Skin(button, S.surface, S.border)
    local tall = height >= 90
    local size = tall and 40 or math.min(32, height - 14)
    local picture = button:CreateTexture(nil, "ARTWORK")
    picture:SetSize(size, size)
    picture:SetTexture(icon)
    picture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local name = W.Text(button, W.fonts.heading)
    local line = wrapText(button, W.fonts.small, tall and width - 20 or width - size - 30)
    if tall then
        picture:SetPoint("TOP", 0, -12)
        name:SetPoint("TOP", picture, "BOTTOM", 0, -6)
        name:SetJustifyH("CENTER")
        line:SetPoint("TOP", name, "BOTTOM", 0, -4)
        line:SetJustifyH("CENTER")
    else
        picture:SetPoint("LEFT", 10, 0)
        name:SetPoint("TOPLEFT", picture, "TOPRIGHT", 10, 1)
        name:SetPoint("RIGHT", button, "RIGHT", -10, 0)
        line:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
    end
    name:SetText(title or "")
    line:SetText(text or "")
    local badge = W.Text(button, W.fonts.small)
    badge:SetPoint("TOPRIGHT", -8, -6)
    badge:SetTextColor(rgba(S.accentText))
    button.title, button.line, button.icon, button.badge = name, line, picture, badge
    local selected, available, hovered = false, true, false
    local function paint()
        if selected then
            button:SetBackdropColor(rgba(S.accent, 0.16))
            button:SetBackdropBorderColor(rgba(S.accent, 1))
        else
            button:SetBackdropColor(rgba(hovered and available and S.surfaceHover or S.surface))
            button:SetBackdropBorderColor(rgba(hovered and available and S.borderHover or S.border))
        end
        button:SetAlpha(available and 1 or S.disabledAlpha)
    end
    function button:SetSelected(on) selected = on and true or false; paint() end
    function button:SetAvailable(on) available = on and true or false; paint() end
    function button:SetBadge(value) badge:SetText(value or "") end
    button:SetScript("OnEnter", function() hovered = true; paint() end)
    button:SetScript("OnLeave", function() hovered = false; paint() end)
    button:SetScript("OnClick", function(self)
        if not available then return end
        PlaySound("igMainMenuOptionCheckBoxOn")
        if onClick then onClick(self) end
    end)
    paint()
    return button
end

local function toggle(parent, label, get, set, width, tooltip)
    local row = W.Toggle(parent, { label = label, tooltip = tooltip }, { get = get, set = function(value)
        set(value)
        if parent.Refresh then parent:Refresh() end
    end }, width)
    return row
end

---------------------------------------------------------------------------------------------------
-- Session
---------------------------------------------------------------------------------------------------
local function style() return ui.Settings().barLayout == "retail" and "retail" or "classic" end

local function newDraft(mode)
    local rec = Setup.Char(false)
    local state = rec and rec.specs[Setup.TalentGroup()]
    local role = Setup.GuessRole()
    local modules = {}
    for _, module in ipairs(Layouts.modules) do modules[module.id] = Setup.GetModule(module) end
    local recommended = Layouts.Recommended(role)
    if mode ~= "copy" then
        for id, on in pairs(recommended) do
            -- The account-wide nameplates and modules the player turned off stay as they are.
            if Setup.moduleById[id].kind ~= "account" then modules[id] = on end
        end
    end
    return {
        role = role, guessed = role, style = style(),
        scaleMode = state and state.scaleMode or "auto", scale = state and state.scale or nil,
        layout = "role", modules = modules,
        chat = { tabs = true, place = true, channels = true, font = false, fontSize = 14 },
    }
end

local function snapshotScale()
    return {
        cvar = GetCVar and GetCVar("uiScale"), use = GetCVar and GetCVar("useUiScale"),
        parent = UIParent:GetScale(), applied = Setup.appliedScale,
    }
end

local function restoreScale(info)
    if not info or not session or not session.scaleChanged then return end
    local function apply()
        if SetCVar then
            if info.use then SetCVar("useUiScale", info.use) end
            if info.cvar then SetCVar("uiScale", info.cvar) end
        end
        if info.parent then UIParent:SetScale(info.parent) end
        Setup.appliedScale = info.applied
    end
    ui.RunOutOfCombat("setupScaleBack", apply)
end

local showStep

local function steps() return session and session.steps or FULL end
local function currentId() return steps()[session.index] end

local function goTo(list, index)
    session.steps = list
    session.index = index or 1
    showStep()
end

local function nextStep()
    if session.index < #steps() then
        session.index = session.index + 1
        showStep()
    end
end

local function previousStep()
    if session.index > 1 then
        session.index = session.index - 1
        showStep()
    end
end

-- Live preview ----------------------------------------------------------------------------------
local function applyModules()
    local reload = false
    for id, on in pairs(session.draft.modules) do
        if Setup.SetModule(id, on) then reload = true end
    end
    session.reload = session.reload or reload
end

local function applyLayout()
    local draft = session.draft
    if InCombatLockdown() then return end
    if draft.layout == "role" then
        Setup.ApplyPreset(draft.role)
    else
        local snap = session.snapshot
        local s = ui.Settings()
        for _, key in ipairs({ "prdX", "prdY", "prdScale" }) do s[key] = copy(snap.raw[key]) end
        if ui.EditMode and ui.EditMode.LoadLayout then ui.EditMode.LoadLayout(snap.layout) end
        Setup.RefreshPlaced()
    end
    session.layoutApplied = true
end

local function applyStyle(value)
    if InCombatLockdown() then return end
    session.draft.style = value
    if value ~= style() or not session.styleApplied then
        -- Bars to the stock spots (Classic) or the Retail stack, like the buttons of Edit Mode.
        if ui.ApplyEditLayout then ui.ApplyEditLayout(value) end
        session.styleApplied = true
    end
end

local scaleTimer = CreateFrame("Frame")
local function applyScale(delay)
    local draft = session.draft
    local scale = Setup.ScaleOf({ scaleMode = draft.scaleMode, scale = draft.scale })
    if not scale then return end
    session.scaleChanged = true
    scaleTimer.left = delay or 0
    -- The window scales with UIParent: the change waits until the slider rests.
    scaleTimer:SetScript("OnUpdate", function(self, elapsed)
        self.left = self.left - elapsed
        if self.left > 0 then return end
        self:SetScript("OnUpdate", nil)
        Setup.SetScale(scale)
    end)
end

local function setRole(role)
    local draft = session.draft
    if draft.role == role then return end
    draft.role = role
    if not draft.modulesTouched then
        local recommended = Layouts.Recommended(role)
        for id, on in pairs(recommended) do
            if Setup.moduleById[id].kind ~= "account" then draft.modules[id] = on end
        end
        if session.modulesApplied then applyModules() end
    end
    if session.layoutApplied and draft.layout == "role" then applyLayout() end
end

-- Quick path: everything recommended for the role.
local function applyQuick()
    local draft = session.draft
    draft.scaleMode = "auto"
    applyScale(0)
    draft.layout = "role"
    applyLayout()
    applyModules()
    session.modulesApplied = true
end

---------------------------------------------------------------------------------------------------
-- Finish / cancel
---------------------------------------------------------------------------------------------------
local function close()
    scaleTimer:SetScript("OnUpdate", nil)
    session = nil
    if frame then frame:Hide() end
end

-- A module that needs /reload now differs from what was loaded at login.
local function needsReload()
    if not session then return false end
    for _, module in ipairs(Layouts.modules) do
        if module.reload and Setup.GetModule(module) ~= session.before[module.id] then return true end
    end
    return false
end

local function finish()
    if InCombatLockdown() then return end
    local draft, mode = session.draft, session.mode
    if not session.copied then
        applyModules()
        if mode == "full" then
            local chat = draft.chat
            Setup.ApplyChat({ tabs = chat.tabs, place = chat.place, channels = chat.channels,
                fontSize = chat.font and chat.fontSize or nil }, draft.role, style())
        end
        local rec = Setup.Char(true)
        local group = Setup.TalentGroup()
        local state = rec.specs[group] or {}
        state.role = draft.role
        if mode == "full" then state.scaleMode, state.scale = draft.scaleMode, draft.scale end
        Setup.Capture(state)
        state.configured = true
        rec.specs[group] = state
        -- The first wizard gives the other talent set the same look and scale (it gets its own role later).
        rec.group, rec.installed = group, true
        Setup.currentGroup = group
    end
    local reload = needsReload()
    close()
    if reload then ReloadUI() end
end

-- silent: logging out (no messages, no new frames).
function Setup.Cancel(silent)
    if not session then return end
    local snap, mode = session.snapshot, session.mode
    if not InCombatLockdown() then
        Setup.ApplyState(snap, { keepScale = true })
        restoreScale(session.scaleInfo)
    end
    -- Account-wide switches are not part of a character's state: they go back from the values at opening.
    for _, module in ipairs(Layouts.modules) do
        if module.kind == "account" then Setup.SetModule(module, session.before[module.id]) end
    end
    -- A copy made in this session is undone too.
    if session.copied then Setup.DB().chars[Setup.CharKey()] = session.recBackup end
    local rec = Setup.Char(false)
    if mode == "full" and not (rec and rec.installed) then
        -- Skipped: what is on screen becomes this character's, the wizard does not come back by itself.
        Setup.Adopt(true)
        if not silent then
            ui.Print(L("установка пропущена. Пройти её заново: |cffe8c27a/fui install|r",
                "setup skipped. Run it again with |cffe8c27a/fui install|r"))
        end
    elseif mode == "spec" and not silent then
        ui.Print(L("набор талантов взял настройки первого. Настроить: |cffe8c27a/fui install|r",
            "the talent set took the settings of the first one. Set it up: |cffe8c27a/fui install|r"))
    end
    close()
end

function Setup.IsOpen() return session ~= nil end

---------------------------------------------------------------------------------------------------
-- Mini map of the screen
---------------------------------------------------------------------------------------------------
local COLORS = {
    units = { 0.91, 0.76, 0.48 },
    combat = { 0.36, 0.79, 0.65 },
    bars = { 0.62, 0.62, 0.66 },
}

local function schemaFrames()
    local list = {
        { "MainMenuBar", "bars" }, { "MultiBarBottomLeft", "bars" }, { "MultiBarBottomRight", "bars" },
        { "MultiBarRight", "bars" }, { "MinimapCluster", "bars" }, { "ChatFrame1", "bars" },
        { "PlayerFrame", "units" }, { "TargetFrame", "units" }, { "FocusFrame", "units" },
        { "CastingBarFrame", "combat", true },
    }
    local function module(id) return Setup.GetModule(id) end
    if module("raidframes") then list[#list + 1] = { "ForeverStockUIRaidAnchor", "combat", true } end
    if module("prd") then list[#list + 1] = { "ForeverStockUIPersonalResource", "combat", true } end
    if module("healermana") then list[#list + 1] = { "ForeverStockUIHealerManaBanner", "combat", true } end
    local EM = ui.EditMode
    if EM and EM.Entries then
        for _, entry in ipairs(EM.Entries()) do
            local name = entry.name
            if module("cooldowns") and name:find("^ForeverStockUICDM%d") and not entry.removed then
                list[#list + 1] = { name, "combat", true }
            elseif module("meter") and name:find("^ForeverStockUI.+Meter$") and not entry.removed then
                list[#list + 1] = { name, "combat" }
            end
        end
    end
    return list
end

local function buildSchema(parent, width, height)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(width, height)
    W.Skin(box, { 0, 0, 0, 0.5 }, S.border)
    local rects = {}
    function box:Refresh()
        local uw, uh = UIParent:GetWidth(), UIParent:GetHeight()
        local base = UIParent:GetEffectiveScale()
        if not uw or uw <= 0 or not uh or uh <= 0 then return end
        local count = 0
        for _, item in ipairs(schemaFrames()) do
            local target = _G[item[1]]
            if target and target.GetLeft and (item[3] or target:IsShown()) then
                local l, b, r, t = target:GetLeft(), target:GetBottom(), target:GetRight(), target:GetTop()
                if l and b and r and t then
                    local k = target:GetEffectiveScale() / base
                    l, b, r, t = l * k, b * k, r * k, t * k
                    count = count + 1
                    local rect = rects[count]
                    if not rect then
                        rect = CreateFrame("Frame", nil, box)
                        W.Skin(rect, { 1, 1, 1, 0.3 }, { 1, 1, 1, 0.9 })
                        rects[count] = rect
                    end
                    local color = COLORS[item[2]]
                    rect:SetBackdropColor(color[1], color[2], color[3], 0.35)
                    rect:SetBackdropBorderColor(color[1], color[2], color[3], 0.95)
                    local x = math.max(0, math.min(width - 3, l / uw * width))
                    local y = math.max(0, math.min(height - 3, b / uh * height))
                    rect:ClearAllPoints()
                    rect:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", x, y)
                    rect:SetWidth(math.max(3, math.min(width - x, (r - l) / uw * width)))
                    rect:SetHeight(math.max(3, math.min(height - y, (t - b) / uh * height)))
                    rect:Show()
                end
            end
        end
        for i = count + 1, #rects do rects[i]:Hide() end
        W.Redraw(box)
    end
    -- Layouts settle a frame or two later (Retail stack, Edit Mode pass): keep the map current while shown.
    local elapsedTotal = 0
    box:SetScript("OnUpdate", function(self, elapsed)
        elapsedTotal = elapsedTotal + elapsed
        if elapsedTotal < 0.4 then return end
        elapsedTotal = 0
        self:Refresh()
    end)
    -- Legend
    local x = 0
    for _, item in ipairs({ { "units", L("Рамки", "Unit frames") }, { "combat", L("Бой и группа", "Combat and group") },
        { "bars", L("Панели и чат", "Bars and chat") } }) do
        local swatch = box:CreateTexture(nil, "ARTWORK")
        swatch:SetTexture("Interface\\Buttons\\WHITE8X8")
        swatch:SetVertexColor(COLORS[item[1]][1], COLORS[item[1]][2], COLORS[item[1]][3], 0.9)
        swatch:SetSize(9, 9)
        swatch:SetPoint("TOPLEFT", box, "BOTTOMLEFT", x, -6)
        local label = W.Text(box, W.fonts.small)
        label:SetPoint("LEFT", swatch, "RIGHT", 4, 0)
        label:SetText(item[2])
        x = x + 18 + label:GetStringWidth() + 12
    end
    return box
end

---------------------------------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------------------------------
local builders = {}

local function intro(page, text, y)
    local line = wrapText(page, W.fonts.label, INNER)
    line:SetPoint("TOPLEFT", 0, y or 0)
    line:SetText(text)
    return line
end

function builders.welcome(page)
    local text = intro(page, "")
    local quick, detailed, copyCard
    quick = card(page, INNER, 52, "Interface\\Icons\\Ability_Rogue_Sprint", L("Быстрая установка", "Quick setup"),
        L("Выбрать роль — остальное по рекомендации.", "Pick a role, the rest as recommended."), function()
            session.quick = true
            goTo(QUICK, 2)
        end)
    quick:SetPoint("TOPLEFT", 0, -44)
    detailed = card(page, INNER, 52, "Interface\\Icons\\INV_Misc_Note_05", L("Подробная установка", "Detailed setup"),
        L("Стиль, масштаб, раскладка, модули и чат по шагам.", "Style, scale, layout, modules and chat step by step."),
        function()
            session.quick = nil
            goTo(FULL, 2)
        end)
    detailed:SetPoint("TOPLEFT", quick, "BOTTOMLEFT", 0, -8)
    copyCard = card(page, INNER, 52, ICONS.copy, L("Скопировать с другого персонажа", "Copy from another character"),
        "", function() goTo(COPY_FROM_WELCOME, 2) end)
    copyCard:SetPoint("TOPLEFT", detailed, "BOTTOMLEFT", 0, -8)
    function page:Refresh()
        text:SetText((L("Персонаж: |cffe8c27a%s|r. Как настроить интерфейс?", "Character: |cffe8c27a%s|r. How to set up the interface?"))
            :format(UnitName("player") or "?"))
        local others = #Setup.OtherChars()
        copyCard:SetAvailable(others > 0)
        copyCard.line:SetText(others > 0
            and (L("Все наборы талантов: роль, стиль, раскладка, модули. Персонажей: %d.",
                "Every talent set: role, style, layout, modules. Characters: %d.")):format(others)
            or L("Других настроенных персонажей пока нет.", "No other character is set up yet."))
    end
end

function builders.spec(page)
    local text = intro(page, "")
    local setup = card(page, INNER, 52, ICONS.layout, L("Настроить", "Set up"),
        L("Роль, раскладка и модули для этого набора.", "Role, layout and modules for this set."), function()
            goTo(SPEC, 2)
        end)
    setup:SetPoint("TOPLEFT", 0, -44)
    local take = card(page, INNER, 52, ICONS.copy, L("Взять настройки первого набора", "Use the first set's settings"),
        L("Всё как в другом наборе талантов, без вопросов.", "Everything as in the other talent set."), function()
            local rec = Setup.Char(true)
            local state = rec.specs[Setup.TalentGroup()]
            if state then state.configured = true end
            close()
        end)
    take:SetPoint("TOPLEFT", setup, "BOTTOMLEFT", 0, -8)
    local later = card(page, INNER, 52, "Interface\\Icons\\INV_Misc_PocketWatch_01", L("Позже", "Later"),
        L("Пока работает копия первого набора. Команда: /fui install.", "A copy of the first set for now. Command: /fui install."),
        function() Setup.Cancel() end)
    later:SetPoint("TOPLEFT", take, "BOTTOMLEFT", 0, -8)
    function page:Refresh()
        local names = ui.Suite and ui.Suite.TreeNames and ui.Suite.TreeNames() or {}
        local tree = ui.Suite and ui.Suite.PrimaryTree and ui.Suite.PrimaryTree() or 0
        text:SetText((L("Новый набор талантов: |cffe8c27a%s|r. Настроить для него раскладку?",
            "New talent set: |cffe8c27a%s|r. Set up a layout for it?")):format(names[tree] or L("без талантов", "no talents")))
    end
end

function builders.copy(page)
    local text = intro(page, L("Выберите персонажа: его наборы талантов станут наборами этого персонажа.",
        "Pick a character: its talent sets become this character's."))
    local rows = {}
    function page:Refresh()
        local list = Setup.OtherChars()
        for i, item in ipairs(list) do
            local key, rec = item[1], item[2]
            local row = rows[i]
            if not row then
                row = card(page, INNER, 38, ICONS.copy, "", "", function(self)
                    if InCombatLockdown() then return end
                    -- Copying again within the session starts from the original record.
                    if session.copied then Setup.DB().chars[Setup.CharKey()] = copy(session.recBackup) end
                    Setup.CopyFrom(self.key)
                    session.copied = self.key
                    nextStep()
                end)
                row:SetPoint("TOPLEFT", 0, -30 - (i - 1) * 44)
                rows[i] = row
            end
            row.key = key
            local state = rec.specs[1] or rec.specs[2] or {}
            local info = Layouts.roleInfo[state.role or ""]
            row.title:SetText(key)
            row.icon:SetTexture(info and info.icon or ICONS.copy)
            row.line:SetText((info and info.label or "?") .. ", " .. (state.style == "retail" and "Retail" or "Classic")
                .. ((rec.specs[1] and rec.specs[2]) and L(", два набора", ", two sets") or ""))
            row:Show()
        end
        for i = #list + 1, #rows do rows[i]:Hide() end
        text:SetText(#list > 0 and L("Выберите персонажа: его наборы талантов станут наборами этого персонажа.",
            "Pick a character: its talent sets become this character's.")
            or L("Других настроенных персонажей пока нет.", "No other character is set up yet."))
    end
end

function builders.role(page)
    local text = intro(page, L("Кем вы играете на этом наборе талантов? От роли зависят раскладка и модули.",
        "What do you play on this talent set? The layout and modules follow the role."))
    local cards = {}
    local half = (INNER - 8) / 2
    for i, role in ipairs(Layouts.roles) do
        local info = Layouts.roleInfo[role]
        local c = card(page, half, 84, info.icon, info.label, info.text, function()
            setRole(role)
            showStep() -- the ring shows the role's icon
        end)
        c:SetPoint("TOPLEFT", ((i - 1) % 2) * (half + 8), -40 - math.floor((i - 1) / 2) * 92)
        cards[role] = c
    end
    function page:Refresh()
        for role, c in pairs(cards) do
            c:SetSelected(session.draft.role == role)
            c:SetBadge(session.draft.guessed == role and L("по талантам", "from talents") or "")
        end
        text:SetText(L("Кем вы играете на этом наборе талантов? От роли зависят раскладка и модули.",
            "What do you play on this talent set? The layout and modules follow the role."))
    end
end

function builders.style(page)
    intro(page, L("Вид панелей, рамок, миникарты и чата. Панели встанут на места выбранного стиля.",
        "The look of bars, frames, minimap and chat. The bars move to the spots of the style."))
    local half = (INNER - 8) / 2
    local classic = card(page, half, 150, "Interface\\Icons\\INV_Misc_Head_Dragon_Bronze", "Classic",
        L("Бронзовая оправа WoW Forever, панели внизу как в клиенте.", "Bronze WoW Forever chrome, bars as in the client."),
        function() applyStyle("classic"); page:Refresh() end)
    classic:SetPoint("TOPLEFT", 0, -44)
    local retail = card(page, half, 150, "Interface\\Icons\\INV_Misc_Gear_08", "Retail",
        L("Плоский вид DragonUI, панели стопкой по центру.", "Flat DragonUI look, bars stacked in the centre."),
        function() applyStyle("retail"); page:Refresh() end)
    retail:SetPoint("TOPLEFT", classic, "TOPRIGHT", 8, 0)
    function page:Refresh()
        classic:SetSelected(session.draft.style == "classic")
        retail:SetSelected(session.draft.style == "retail")
    end
end

function builders.scale(page)
    local info = intro(page, "")
    local half = (INNER - 8) / 2
    local slider
    local auto = card(page, half, 52, ICONS.scale, L("Авто", "Auto"),
        L("Пиксель в пиксель под экран.", "Pixel perfect for the screen."), function()
            session.draft.scaleMode = "auto"
            applyScale(0)
            page:Refresh()
        end)
    auto:SetPoint("TOPLEFT", 0, -44)
    local manual = card(page, half, 52, "Interface\\Icons\\INV_Misc_Wrench_01", L("Вручную", "Manual"),
        L("Свой размер ползунком.", "Your own size with the slider."), function()
            local draft = session.draft
            draft.scaleMode = "manual"
            draft.scale = draft.scale or Setup.ScaleOf({ scaleMode = "auto" })
            applyScale(0)
            page:Refresh()
        end)
    manual:SetPoint("TOPLEFT", auto, "TOPRIGHT", 8, 0)
    slider = W.Range(page, { label = L("Масштаб интерфейса", "Interface scale"), min = 40, max = 115, step = 1, suffix = "%" }, {
        get = function()
            local scale = Setup.ScaleOf({ scaleMode = session.draft.scaleMode, scale = session.draft.scale }) or 1
            return math.floor(scale * 100 + 0.5)
        end,
        set = function(value)
            local draft = session.draft
            draft.scaleMode, draft.scale = "manual", value / 100
            applyScale(0.6)
            page:Refresh()
        end,
    }, INNER)
    slider:SetPoint("TOPLEFT", auto, "BOTTOMLEFT", 0, -22)
    local note = wrapText(page, W.fonts.small, INNER)
    note:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -10)
    note:SetText(L("Меняется сразу. Окна и шрифты растут вместе с интерфейсом; меньше 64% клиент не даёт — остальное "
        .. "делает аддон.", "Applies at once. Windows and fonts grow with the interface; below 64% the addon scales the rest."))
    function page:Refresh()
        local height = Setup.ScreenHeight()
        local autoScale = Layouts.AutoScale(height)
        info:SetText((L("Экран: %s px в высоту. Авто — %d%%.", "Screen: %s px high. Auto: %d%%."))
            :format(height and tostring(height) or "?", math.floor(autoScale * 100 + 0.5)))
        auto:SetSelected(session.draft.scaleMode == "auto")
        manual:SetSelected(session.draft.scaleMode == "manual")
        slider:Refresh()
    end
end

function builders.layout(page)
    intro(page, L("Где стоят фреймы. Двигать дальше — в режиме редактирования.",
        "Where the frames stand. Fine-tune them in Edit Mode."))
    local half = (INNER - 8) / 2
    local roleCard = card(page, half, 44, ICONS.layout, "", L("Фреймы встанут по роли.", "Frames move for the role."),
        function()
            session.draft.layout = "role"
            applyLayout()
            page:Refresh()
        end)
    roleCard:SetPoint("TOPLEFT", 0, -26)
    local keep = card(page, half, 44, "Interface\\Icons\\INV_Misc_Pin_01" , L("Оставить мои позиции", "Keep my positions"),
        L("Как было до установки.", "As before the setup."), function()
            session.draft.layout = "keep"
            applyLayout()
            page:Refresh()
        end)
    keep:SetPoint("TOPLEFT", roleCard, "TOPRIGHT", 8, 0)
    local schemaWidth = 288
    local schema = buildSchema(page, schemaWidth, math.floor(schemaWidth * 9 / 16 + 0.5))
    schema:SetPoint("TOP", page, "TOP", 0, -80)
    page.schema = schema
    function page:Refresh()
        local info = Layouts.roleInfo[session.draft.role]
        roleCard.title:SetText((L("Раскладка: %s", "Layout: %s")):format(info and info.label or ""))
        roleCard.icon:SetTexture(info and info.icon or ICONS.layout)
        roleCard:SetSelected(session.draft.layout == "role")
        keep:SetSelected(session.draft.layout == "keep")
        schema:Refresh()
    end
    function page:OnEnter()
        if not session.layoutApplied then applyLayout() end
    end
end

function builders.modules(page)
    intro(page, L("Галочки выставлены под роль. Отмеченные * включатся после перезагрузки.",
        "Ticks follow the role. Those marked * apply after a reload."))
    local half = (INNER - 12) / 2
    local rows = {}
    for i, module in ipairs(Layouts.modules) do
        local row = toggle(page, module.label .. (module.reload and " *" or ""), function()
            return session.draft.modules[module.id]
        end, function(value)
            session.draft.modules[module.id] = value and true or false
            session.draft.modulesTouched = true
            Setup.SetModule(module, value)
        end, half)
        row:SetPoint("TOPLEFT", ((i - 1) % 2) * (half + 12), -30 - math.floor((i - 1) / 2) * 30)
        rows[#rows + 1] = row
    end
    local note = wrapText(page, W.fonts.small, INNER)
    note:SetPoint("TOPLEFT", 0, -30 - math.ceil(#Layouts.modules / 2) * 30 - 6)
    note:SetText(L("Неймплейты — общие для всех персонажей, остальное — для этого набора талантов.",
        "Nameplates are shared by every character, the rest belongs to this talent set."))
    function page:Refresh()
        for _, row in ipairs(rows) do row:Refresh() end
    end
    function page:OnEnter()
        if not session.modulesApplied then
            applyModules()
            session.modulesApplied = true
        end
    end
end

function builders.chat(page)
    intro(page, L("Применится по кнопке «Готово». Свои вкладки не удаляются.",
        "Applied with Done. Your own tabs stay."))
    local chat = function() return session.draft.chat end
    local items = {
        { "tabs", L("Вкладки: Группа/Рейд, Гильдия, Добыча", "Tabs: Party/Raid, Guild, Loot") },
        { "place", L("Положение и размер окна под раскладку", "Chat position and size for the layout") },
        { "channels", L("Общий, Торговля, Поиск — во вкладку «Каналы»", "General, Trade, LFG into a Channels tab") },
        { "font", L("Свой размер шрифта", "Own font size") },
    }
    local rows = {}
    for i, item in ipairs(items) do
        local row = toggle(page, item[2], function() return chat()[item[1]] end,
            function(value) chat()[item[1]] = value and true or false end, INNER)
        row:SetPoint("TOPLEFT", 0, -30 - (i - 1) * 30)
        rows[#rows + 1] = row
    end
    local size = W.Range(page, { label = L("Размер шрифта чата", "Chat font size"), min = 10, max = 20, step = 1 }, {
        get = function() return chat().fontSize end,
        set = function(value) chat().fontSize = value; page:Refresh() end,
    }, INNER)
    size:SetPoint("TOPLEFT", 0, -30 - #items * 30 - 4)
    function page:Refresh()
        for _, row in ipairs(rows) do row:Refresh() end
        size:Refresh()
        size:SetEnabled(chat().font)
    end
end

function builders.done(page)
    local summary = wrapText(page, W.fonts.label, INNER)
    summary:SetPoint("TOPLEFT", 0, 0)
    if summary.SetSpacing then summary:SetSpacing(4) end
    local back = W.Button(page, L("Вернуть как было", "Put everything back"), 180, function() Setup.Cancel() end, 26)
    back:SetPoint("BOTTOMLEFT", 0, 4)
    local edit = W.Button(page, L("Режим редактирования", "Edit Mode"), 180, function()
        finish()
        if ui.EditMode and ui.EditMode.Open then ui.EditMode.Open() end
    end, 26)
    edit:SetPoint("LEFT", back, "RIGHT", 8, 0)
    function page:Refresh()
        local draft = session.draft
        local lines = {}
        local function add(label, value) lines[#lines + 1] = "|cffe8c27a" .. label .. ":|r " .. value end
        if session.mode == "copy" then
            add(L("Скопировано с", "Copied from"), session.copied or "?")
            add(L("Раскладка", "Layout"), L("на экране", "on screen"))
        else
            local info = Layouts.roleInfo[draft.role]
            add(L("Роль", "Role"), info and info.label or "?")
            if session.mode == "full" then
                add(L("Стиль", "Style"), style() == "retail" and "Retail" or "Classic")
                local scale = Setup.ScaleOf({ scaleMode = draft.scaleMode, scale = draft.scale })
                add(L("Масштаб", "Scale"), (draft.scaleMode == "auto" and L("авто, ", "auto, ") or "")
                    .. (scale and (math.floor(scale * 100 + 0.5) .. "%") or "—"))
            end
            add(L("Раскладка", "Layout"), draft.layout == "role" and (info and info.label or "") or L("мои позиции", "my positions"))
            local on = 0
            for _, value in pairs(draft.modules) do if value then on = on + 1 end end
            add(L("Модули", "Modules"), (L("включено %d из %d", "%d of %d on")):format(on, #Layouts.modules))
            if session.mode == "full" then
                local c = draft.chat
                local parts = {}
                if c.tabs then parts[#parts + 1] = L("вкладки", "tabs") end
                if c.place then parts[#parts + 1] = L("положение", "position") end
                if c.channels then parts[#parts + 1] = L("каналы", "channels") end
                if c.font then parts[#parts + 1] = L("шрифт ", "font ") .. c.fontSize end
                add(L("Чат", "Chat"), #parts > 0 and table.concat(parts, ", ") or L("не трогать", "untouched"))
            end
        end
        if needsReload() then
            lines[#lines + 1] = ""
            lines[#lines + 1] = "|cffff8c5a" .. L("Часть модулей включится после перезагрузки интерфейса.",
                "Some modules switch after a UI reload.") .. "|r"
        end
        summary:SetText(table.concat(lines, "\n"))
    end
end

---------------------------------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------------------------------
local function closeCoords(cell)
    local cx, cy = (cell % 2) * 128, math.floor(cell / 2) * 128
    return (cx + 4) / 256, (cx + 125) / 256, (cy + 2) / 256, (cy + 122) / 256
end

local function buildChrome(window)
    local chrome = CreateFrame("Frame", nil, window)
    chrome:SetAllPoints(window)
    chrome:SetFrameLevel(window:GetFrameLevel() + 1)
    local ground = window:CreateTexture(nil, "BACKGROUND")
    ground:SetTexture(ART .. "InsetGround")
    local portrait = chrome:CreateTexture(nil, "BACKGROUND")
    window.portrait = portrait
    local layout = ui.WindowSkin and ui.WindowSkin.Layout
    if not layout then
        W.Skin(window, S.window, S.borderHover)
        ground:SetAllPoints(window)
        portrait:SetSize(46, 46)
        portrait:SetPoint("TOPLEFT", 6, -4)
        return
    end
    local pieces, extra = layout(WIDTH, HEIGHT, CHROME_SCALE, true)
    for _, p in ipairs(pieces) do
        local tex = chrome:CreateTexture(nil, "BORDER")
        tex:SetTexture(p.file)
        tex:SetTexCoord(p.l, p.r, p.t, p.b)
        tex:SetPoint("TOPLEFT", chrome, "TOPLEFT", p.x, -p.y)
        tex:SetWidth(p.w)
        tex:SetHeight(p.h)
    end
    local g = extra.ground
    ground:SetPoint("TOPLEFT", window, "TOPLEFT", g.x, -g.y)
    ground:SetWidth(g.w)
    ground:SetHeight(g.h)
    local p = extra.portrait
    portrait:SetPoint("TOPLEFT", chrome, "TOPLEFT", p.x, -p.y)
    portrait:SetWidth(p.w)
    portrait:SetHeight(p.h)
end

local function buildCloseButton(window)
    local button = CreateFrame("Button", nil, window)
    local size = 56 * CHROME_SCALE
    button:SetSize(size, size)
    button:SetPoint("TOPRIGHT", window, "TOPRIGHT", -2, 0)
    button:SetFrameLevel(window:GetFrameLevel() + 5)
    local function face(cell)
        local tex = button:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(ART .. "Close")
        tex:SetTexCoord(closeCoords(cell))
        tex:SetAllPoints(button)
        return tex
    end
    button:SetNormalTexture(face(0))
    button:SetPushedTexture(face(1))
    local highlight = face(2)
    highlight:SetDrawLayer("HIGHLIGHT")
    button:SetHighlightTexture(highlight)
    button:SetScript("OnClick", function() Setup.Cancel() end)
    button:SetScript("OnEnter", function(self)
        W.ShowTooltip(self, L("Закрыть", "Close"), L("Всё вернётся как было до установки.", "Everything goes back to how it was."))
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
end

local function buildWindow()
    frame = CreateFrame("Frame", "ForeverStockUISetup", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -40)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    buildChrome(frame)
    buildCloseButton(frame)

    local title = W.Text(frame, W.fonts.heading)
    title:SetPoint("CENTER", frame, "TOP", 0, -(HEADER_CENTER * CHROME_SCALE + 1))
    title:SetJustifyH("CENTER")
    frame.title = title
    local subtitle = W.Text(frame, W.fonts.small)
    subtitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 66, -40)
    frame.subtitle = subtitle

    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -CONTENT_TOP)
    body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, 50)
    body:SetFrameLevel(frame:GetFrameLevel() + 3)
    frame.body = body

    local back = W.Button(frame, L("Назад", "Back"), 110, function()
        if session.index == 1 then Setup.Cancel() else previousStep() end
    end, 26)
    back:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, 16)
    back:SetFrameLevel(frame:GetFrameLevel() + 4)
    frame.back = back
    local nextButton = W.Button(frame, L("Далее", "Next"), 150, function()
        local id = currentId()
        if id == "done" then
            finish()
        elseif id == "role" and session.quick then
            applyQuick()
            nextStep()
        else
            nextStep()
        end
    end, 26)
    nextButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, 16)
    nextButton:SetFrameLevel(frame:GetFrameLevel() + 4)
    frame.nextButton = nextButton
    frame.dots = {}
    for i = 1, 8 do
        local dot = frame:CreateTexture(nil, "OVERLAY")
        dot:SetTexture("Interface\\Buttons\\WHITE8X8")
        dot:SetSize(7, 7)
        frame.dots[i] = dot
    end

    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function(self, event)
        if not session then return end
        if event == "PLAYER_REGEN_DISABLED" then
            -- Frames cannot move in combat: the wizard waits.
            self:Hide()
            ui.Print(L("установка продолжится после боя.", "the setup continues after combat."))
        elseif event == "PLAYER_REGEN_ENABLED" then
            self:Show()
            showStep()
        end
    end)
end

showStep = function()
    if not session or not frame then return end
    local list = steps()
    local id = list[session.index]
    for key, page in pairs(pages) do
        if key ~= id then page:Hide() end
    end
    local page = pages[id]
    if not page then
        page = CreateFrame("Frame", nil, frame.body)
        page:SetAllPoints(frame.body)
        builders[id](page)
        pages[id] = page
    end
    if page.OnEnter then page:OnEnter() end
    if page.Refresh then page:Refresh() end
    page:Show()

    local icon = ICONS[id]
    if id == "role" then icon = (Layouts.roleInfo[session.draft.role] or {}).icon or ICONS.welcome end
    if SetPortraitToTexture then SetPortraitToTexture(frame.portrait, icon) else frame.portrait:SetTexture(icon) end
    frame.title:SetText(session.mode == "spec" and L("Новый набор талантов", "New talent set")
        or L("Установка ForeverUI", "ForeverUI setup"))
    frame.subtitle:SetText((L("Шаг %d из %d — %s", "Step %d of %d — %s")):format(session.index, #list, TITLES[id] or ""))

    -- Footer: the first page offers Skip instead of Back; pages made of cards move on by themselves.
    local first = session.index == 1
    frame.back:SetText(first and L("Пропустить", "Skip") or L("Назад", "Back"))
    local cardsOnly = id == "welcome" or id == "spec" or id == "copy"
    W.SetVisible(frame.nextButton, not cardsOnly)
    if id == "done" then
        frame.nextButton:SetText(needsReload() and L("Готово и /reload", "Done and /reload") or L("Готово", "Done"))
    elseif id == "role" and session.quick then
        frame.nextButton:SetText(L("Применить", "Apply"))
    else
        frame.nextButton:SetText(L("Далее", "Next"))
    end
    local count = #list
    local spacing = 13
    for i, dot in ipairs(frame.dots) do
        if i <= count then
            dot:ClearAllPoints()
            dot:SetPoint("BOTTOM", frame, "BOTTOM", (i - (count + 1) / 2) * spacing, 26)
            if i == session.index then dot:SetVertexColor(rgba(S.accent, 1)) else dot:SetVertexColor(1, 1, 1, 0.25) end
            dot:Show()
        else
            dot:Hide()
        end
    end
    W.Redraw(frame)
end

-- mode: "full" (default), "spec", "copy".
function Setup.Open(mode)
    mode = mode or "full"
    if InCombatLockdown() then
        ui.Print(L("установка откроется после боя.", "the setup opens after combat."))
        ui.RunOutOfCombat("setupOpen", function() Setup.Open(mode) end)
        return
    end
    if session then
        frame:Show()
        showStep()
        return
    end
    if not frame then buildWindow() end
    if ui.EditMode and ui.EditMode.IsOpen and ui.EditMode.IsOpen() then ui.EditMode.Close() end
    if ForeverUIOptions and ForeverUIOptions.Hide then ForeverUIOptions:Hide() end
    local before = {}
    for _, module in ipairs(Layouts.modules) do before[module.id] = Setup.GetModule(module) end
    session = {
        mode = mode, draft = newDraft(mode), snapshot = Setup.Capture({}), scaleInfo = snapshotScale(), index = 1,
        steps = mode == "spec" and SPEC or mode == "copy" and COPY or FULL,
        before = before, recBackup = copy(Setup.Char(false)),
    }
    frame:ClearAllPoints()
    frame:SetPoint("TOP", UIParent, "TOP", 0, -40)
    frame:Show()
    showStep()
end

-- For tests and diagnostics.
Setup.wizard = {
    Session = function() return session end,
    Frame = function() return frame end,
    Pages = pages,
    Next = function() if frame then frame.nextButton:Click() end end,
    Back = function() if frame then frame.back:Click() end end,
    Finish = function() finish() end,
}
