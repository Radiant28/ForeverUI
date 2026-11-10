local _, ui = ...
local ru = ui.russian

local pingFormat = ru and "Пинг %d мс" or "Ping %d ms"
local pingUnknown = ru and "Пинг —" or "Ping —"
local settings, fps, ping

local function color(key, fallback)
    local value = settings[key]
    if type(value) ~= "table" then value = fallback end
    return value[1], value[2], value[3]
end

local function createIndicator(key)
    local frame = CreateFrame("Frame", "ForeverStockUI_" .. key, UIParent)
    frame:SetSize(96, 18)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(false)

    local label = frame:CreateFontString(nil, "OVERLAY")
    label:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    label:SetPoint("RIGHT", -4, 0)
    frame.label = label
    return frame
end

local function place(frame, key, defaultY)
    local scale = settings[key .. "Scale"] / 100
    frame:SetScale(scale)
    frame:ClearAllPoints()
    local position = settings[key .. "Position"]
    if not ui.RegisterEditFrame and type(position) == "table" then
        local x, y = position[1], position[2]
        if type(x) == "number" and type(y) == "number" and math.abs(x) < math.huge and math.abs(y) < math.huge then
            frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", x / scale, y / scale)
            return
        end
    end
    frame:SetPoint("TOPRIGHT", MinimapCluster, "BOTTOMRIGHT", -8 / scale, defaultY / scale)
end

local function refresh()
    local rate = math.floor(GetFramerate() + 0.5)
    fps.label:SetFormattedText("%d FPS", rate)
    if rate >= settings.perfGoodFPS then
        fps.label:SetTextColor(color("perfGoodColor", { 0.39, 0.9, 0.43 }))
    elseif rate >= settings.perfFairFPS then
        fps.label:SetTextColor(color("perfFairColor", { 1, 0.78, 0.29 }))
    else
        fps.label:SetTextColor(color("perfPoorColor", { 1, 0.36, 0.32 }))
    end

    local latency = select(3, GetNetStats())
    if latency and latency > 0 then
        ping.label:SetFormattedText(pingFormat, latency)
        if latency <= settings.perfGoodPing then
            ping.label:SetTextColor(color("perfGoodColor", { 0.39, 0.9, 0.43 }))
        elseif latency <= settings.perfFairPing then
            ping.label:SetTextColor(color("perfFairColor", { 1, 0.78, 0.29 }))
        else
            ping.label:SetTextColor(color("perfPoorColor", { 1, 0.36, 0.32 }))
        end
    else
        ping.label:SetText(pingUnknown)
        ping.label:SetTextColor(0.8, 0.8, 0.8)
    end
end

local function apply()
    if not fps then return end
    local font = ui.MediaPath("font", settings.perfFont, true) or STANDARD_TEXT_FONT
    for _, frame in ipairs({ fps, ping }) do
        frame.label:SetFont(STANDARD_TEXT_FONT, settings.perfFontSize, settings.perfFontOutline)
        frame.label:SetFont(font, settings.perfFontSize, settings.perfFontOutline)
    end
    place(fps, "fps", -4)
    place(ping, "ping", -7 - fps:GetHeight() * fps:GetScale())
    local enabled = settings.perfEnabled ~= false
    if enabled and settings.perfShowFPS then fps:Show() else fps:Hide() end
    if enabled and settings.perfShowPing then ping:Show() else ping:Hide() end
    refresh()
    if ui.RefreshEditLayout then ui.RefreshEditLayout() end
end
ui.Performance = { Apply = apply }

local events = CreateFrame("Frame", nil, UIParent)
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    settings = ui.Settings()
    fps = createIndicator("fps")
    ping = createIndicator("ping")
    apply()
    if ui.RegisterEditFrame then
        local fpsEntry = ui.RegisterEditFrame(fps, "FPS", "performance", ui.OptionBinding("performance", "fpsScale"),
            "fpsPosition")
        local pingEntry = ui.RegisterEditFrame(ping, ru and "Пинг" or "Ping", "performance",
            ui.OptionBinding("performance", "pingScale"), "pingPosition")
        fpsEntry.resetPosition, pingEntry.resetPosition = apply, apply
    end

    local elapsed = 0
    self:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < settings.perfInterval then return end
        elapsed = 0
        if fps:IsShown() or ping:IsShown() then refresh() end
    end)
end)
