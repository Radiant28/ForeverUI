local _, ui = ...
-- Frutiger Aero glossy glass theme for ForeverUI's combined backpack and bank windows.
-- Renders over ForeverStockInventory and ForeverStockBank when settings.bagsTheme == "aero"
-- and cleanly restores ForeverUI / WindowSkin styling when switched back to "forever".

local ART = "Interface\\AddOns\\ForeverUI\\Art\\Aero\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local BACKPACK_ICON = "Interface\\Buttons\\Button-Backpack-Up"
local WINDOWS = { "ForeverStockInventory", "ForeverStockBank" }

local PRESETS = {
    aqua = {
        label = "Aqua",
        bg = { 0.88, 0.95, 1.0 },
        header = { 0.90, 0.96, 1.0 },
        border = { 0.84, 0.95, 1.0 },
        orb = { 0.90, 0.97, 1.0 },
        slot = { 0.88, 0.96, 1.0 },
        pill = { 0.88, 0.96, 1.0 },
        divider = { 0.54, 0.88, 0.98 },
        bubble = { 0.82, 0.95, 1.0, 0.32 },
        accent = { 0.45, 0.88, 1.0 },
    },
    emerald = {
        label = "Emerald",
        bg = { 0.70, 0.96, 0.86 },
        header = { 0.68, 0.94, 0.84 },
        border = { 0.70, 0.95, 0.85 },
        orb = { 0.74, 0.96, 0.86 },
        slot = { 0.74, 0.96, 0.88 },
        pill = { 0.72, 0.94, 0.86 },
        divider = { 0.44, 0.94, 0.78 },
        bubble = { 0.72, 0.96, 0.88, 0.34 },
        accent = { 0.42, 0.95, 0.76 },
    },
    frost = {
        label = "Frost",
        bg = { 0.84, 0.90, 0.98 },
        header = { 0.86, 0.92, 0.99 },
        border = { 0.88, 0.94, 1.0 },
        orb = { 0.88, 0.94, 1.0 },
        slot = { 0.86, 0.92, 0.98 },
        pill = { 0.86, 0.92, 0.98 },
        divider = { 0.70, 0.88, 0.98 },
        bubble = { 0.86, 0.93, 1.0, 0.30 },
        accent = { 0.68, 0.88, 0.98 },
    },
    midnight = {
        label = "Midnight",
        bg = { 0.56, 0.68, 0.84 },
        header = { 0.58, 0.70, 0.86 },
        border = { 0.64, 0.78, 0.94 },
        orb = { 0.66, 0.80, 0.95 },
        slot = { 0.68, 0.80, 0.94 },
        pill = { 0.64, 0.76, 0.90 },
        divider = { 0.48, 0.78, 0.96 },
        bubble = { 0.68, 0.84, 0.98, 0.28 },
        accent = { 0.46, 0.82, 0.98 },
    },
}

local skins = {}
local hookedWindows = {}
local pendingWindows = {}
local retryTimer = CreateFrame("Frame")
retryTimer:Hide()

local function settings()
    return (ui.Settings and ui.Settings()) or {}
end

local function isAeroEnabled()
    return settings().bagsTheme == "aero"
end

local function getConfig()
    local db = settings()
    local preset = PRESETS[db.bagsAeroPreset] or PRESETS.aqua
    local bubbles = db.bagsAeroBubbles ~= false
    local alpha = tonumber(db.bagsAeroAlpha) or 88
    if alpha < 50 then alpha = 50 elseif alpha > 100 then alpha = 100 end
    return preset, bubbles, alpha, db
end

local function texPath(region)
    local p = region and region.GetTexture and region:GetTexture()
    return type(p) == "string" and p:lower() or ""
end

local function isTexture(region)
    return region and region.GetObjectType and region:GetObjectType() == "Texture"
end

local function fadeRegion(st, region)
    if not region or not region.SetAlpha or st.ownRegions[region] then return end
    if st.faded[region] == nil then
        st.faded[region] = region.GetAlpha and (region:GetAlpha() or 1) or 1
    end
    region:SetAlpha(0)
end

local function saveBackdrop(st, frame)
    if not frame or not frame.SetBackdrop then return end
    if not st.backdrops[frame] then
        local bg = frame.GetBackdrop and frame:GetBackdrop()
        local color = frame.GetBackdropColor and { frame:GetBackdropColor() }
        local border = frame.GetBackdropBorderColor and { frame:GetBackdropBorderColor() }
        st.backdrops[frame] = { bg = bg, color = color, border = border }
    end
    frame:SetBackdrop(nil)
end

-- Nine-slice panel builder: eight edge/corner pieces + optional center piece anchored dynamically to target.
local function createNineSlice(st, parent, texture, texW, texH, texCorner, displayCorner, layer, sub, withCenter)
    local slices = {}
    local names = { "tl", "tr", "bl", "br", "top", "bottom", "left", "right" }
    if withCenter then names[#names + 1] = "mid" end
    for _, key in ipairs(names) do
        local tex = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
        tex:SetTexture(texture)
        st.ownRegions[tex] = true
        slices[key] = tex
    end
    local ux, uy = texCorner / texW, texCorner / texH
    slices.tl:SetTexCoord(0, ux, 0, uy)
    slices.tr:SetTexCoord(1 - ux, 1, 0, uy)
    slices.bl:SetTexCoord(0, ux, 1 - uy, 1)
    slices.br:SetTexCoord(1 - ux, 1, 1 - uy, 1)
    slices.top:SetTexCoord(ux, 1 - ux, 0, uy)
    slices.bottom:SetTexCoord(ux, 1 - ux, 1 - uy, 1)
    slices.left:SetTexCoord(0, ux, uy, 1 - uy)
    slices.right:SetTexCoord(1 - ux, 1, uy, 1 - uy)
    if slices.mid then slices.mid:SetTexCoord(ux, 1 - ux, uy, 1 - uy) end

    local obj = { slices = slices, corner = displayCorner }
    function obj:Anchor(target, outset)
        local c = self.corner
        local o = outset or 0
        for _, key in ipairs({ "tl", "tr", "bl", "br" }) do
            slices[key]:SetSize(c, c)
            slices[key]:ClearAllPoints()
        end
        slices.tl:SetPoint("TOPLEFT", target, "TOPLEFT", -o, o)
        slices.tr:SetPoint("TOPRIGHT", target, "TOPRIGHT", o, o)
        slices.bl:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", -o, -o)
        slices.br:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", o, -o)

        slices.top:ClearAllPoints()
        slices.top:SetPoint("TOPLEFT", slices.tl, "TOPRIGHT")
        slices.top:SetPoint("BOTTOMRIGHT", slices.tr, "BOTTOMLEFT")

        slices.bottom:ClearAllPoints()
        slices.bottom:SetPoint("TOPLEFT", slices.bl, "TOPRIGHT")
        slices.bottom:SetPoint("BOTTOMRIGHT", slices.br, "BOTTOMLEFT")

        slices.left:ClearAllPoints()
        slices.left:SetPoint("TOPLEFT", slices.tl, "BOTTOMLEFT")
        slices.left:SetPoint("BOTTOMRIGHT", slices.bl, "TOPRIGHT")

        slices.right:ClearAllPoints()
        slices.right:SetPoint("TOPLEFT", slices.tr, "BOTTOMLEFT")
        slices.right:SetPoint("BOTTOMRIGHT", slices.br, "TOPRIGHT")

        if slices.mid then
            slices.mid:ClearAllPoints()
            slices.mid:SetPoint("TOPLEFT", slices.tl, "BOTTOMRIGHT")
            slices.mid:SetPoint("BOTTOMRIGHT", slices.br, "TOPLEFT")
        end
    end
    function obj:SetColor(r, g, b, a)
        for _, tex in pairs(slices) do
            tex:SetVertexColor(r, g, b, a or 1)
        end
    end
    function obj:Show()
        for _, tex in pairs(slices) do tex:Show() end
    end
    function obj:Hide()
        for _, tex in pairs(slices) do tex:Hide() end
    end
    return obj
end

local function detectWindowSkinChrome(window, st)
    if not window or not window.GetChildren then return nil, false end
    for _, child in ipairs({ window:GetChildren() }) do
        if not st.ownFrames[child] and child.GetRegions then
            for _, region in ipairs({ child:GetRegions() }) do
                if isTexture(region) and texPath(region):find("window%-metal", 1, false) then
                    return child, child.IsShown and child:IsShown() and true or false
                end
            end
        end
    end
    return nil, false
end

local function ensureChrome(st)
    if st.bgFrame then return end
    local window = st.window
    local bgFrame = CreateFrame("Frame", nil, window)
    bgFrame:EnableMouse(false)
    st.ownFrames[bgFrame] = true
    st.bgFrame = bgFrame

    local bg = bgFrame:CreateTexture(nil, "BACKGROUND", nil, -6)
    bg:SetTexture(ART .. "Aero-Backdrop")
    bg:SetPoint("TOPLEFT", bgFrame, "TOPLEFT", 4, -4)
    bg:SetPoint("BOTTOMRIGHT", bgFrame, "BOTTOMRIGHT", -4, 4)
    st.ownRegions[bg] = true
    st.backdropTex = bg

    local bubbles = bgFrame:CreateTexture(nil, "BACKGROUND", nil, -5)
    bubbles:SetTexture(ART .. "Aero-Bubbles")
    bubbles:SetPoint("TOPLEFT", bgFrame, "TOPLEFT", 4, -4)
    bubbles:SetPoint("BOTTOMRIGHT", bgFrame, "BOTTOMRIGHT", -4, 4)
    st.ownRegions[bubbles] = true
    st.bubblesTex = bubbles

    local header = bgFrame:CreateTexture(nil, "BACKGROUND", nil, -4)
    header:SetTexture(ART .. "Aero-Header")
    header:SetPoint("TOPLEFT", bgFrame, "TOPLEFT", 4, -4)
    header:SetPoint("TOPRIGHT", bgFrame, "TOPRIGHT", -4, -4)
    header:SetHeight(34)
    st.ownRegions[header] = true
    st.headerTex = header

    local headerDiv = bgFrame:CreateTexture(nil, "BACKGROUND", nil, -3)
    headerDiv:SetTexture(ART .. "Aero-Divider")
    headerDiv:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 4, 3)
    headerDiv:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -4, 3)
    headerDiv:SetHeight(6)
    st.ownRegions[headerDiv] = true
    st.headerDiv = headerDiv

    local rimFrame = CreateFrame("Frame", nil, window)
    rimFrame:EnableMouse(false)
    st.ownFrames[rimFrame] = true
    st.rimFrame = rimFrame
    st.outerRim = createNineSlice(st, rimFrame, ART .. "Aero-Frame", 256, 256, 36, 18, "OVERLAY", 1, false)
    st.outerRim:Anchor(rimFrame, 0)

    local orb = CreateFrame("Frame", nil, rimFrame)
    orb:EnableMouse(false)
    orb:SetSize(54, 54)
    st.ownFrames[orb] = true
    st.orb = orb

    local orbBack = orb:CreateTexture(nil, "BORDER")
    orbBack:SetTexture(ART .. "Aero-Orb")
    orbBack:SetTexCoord(0, 0.5, 0, 1)
    orbBack:SetAllPoints(orb)
    st.ownRegions[orbBack] = true
    st.orbBack = orbBack

    local orbIcon = orb:CreateTexture(nil, "ARTWORK")
    orbIcon:SetSize(36, 36)
    orbIcon:SetPoint("CENTER", orb, "CENTER")
    if SetPortraitToTexture then SetPortraitToTexture(orbIcon, BACKPACK_ICON) else orbIcon:SetTexture(BACKPACK_ICON) end
    st.ownRegions[orbIcon] = true
    st.orbIcon = orbIcon

    local orbDome = orb:CreateTexture(nil, "OVERLAY")
    orbDome:SetTexture(ART .. "Aero-Orb")
    orbDome:SetTexCoord(0.5, 1, 0, 1)
    orbDome:SetAllPoints(orb)
    st.ownRegions[orbDome] = true
    st.orbDome = orbDome
end

local function refreshOrbIcon(st)
    if not (st and st.active and st.orbIcon) then return end
    if SetPortraitToTexture then
        SetPortraitToTexture(st.orbIcon, BACKPACK_ICON)
    else
        st.orbIcon:SetTexture(BACKPACK_ICON)
    end
end

local applyWindow

local function hookWsChrome(st, chrome)
    if not chrome or st.hookedWs[chrome] or not chrome.HookScript then return end
    st.hookedWs[chrome] = true
    local function syncLater()
        if st.active then applyWindow(st.window) end
    end
    chrome:HookScript("OnShow", syncLater)
    chrome:HookScript("OnHide", syncLater)
end

local function syncChromeGeometry(st)
    local window = st.window
    local wsChrome, wsShown = detectWindowSkinChrome(window, st)
    if wsChrome then hookWsChrome(st, wsChrome) end

    if wsChrome and wsShown then
        if st.wsChrome and st.wsChrome ~= wsChrome then st.wsChrome:SetAlpha(1) end
        st.wsChrome = wsChrome
        wsChrome:SetAlpha(0)
        st.topRaise = 12
    else
        if st.wsChrome then
            st.wsChrome:SetAlpha(1)
            st.wsChrome = nil
        end
        st.topRaise = 0
    end

    -- Ensure native TitleText on `window` renders cleanly above bgFrame (`windowLevel - 1`).
    local wLevel = window:GetFrameLevel() or 0
    if wLevel < 2 then
        window:SetFrameLevel(3)
        wLevel = 3
    end

    -- Raise the top glass edge cleanly above TitleText, CloseButton and Enchanting buttons so all header elements center nicely.
    local topOffset = st.topRaise > 0 and 17 or 2

    st.bgFrame:ClearAllPoints()
    st.bgFrame:SetPoint("TOPLEFT", window, "TOPLEFT", -4, topOffset)
    st.bgFrame:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 4, -4)
    st.bgFrame:SetFrameLevel(math.max(0, wLevel - 1))

    st.rimFrame:ClearAllPoints()
    st.rimFrame:SetPoint("TOPLEFT", window, "TOPLEFT", -4, topOffset)
    st.rimFrame:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 4, -4)
    local rimLevel = (st.wsChrome and st.wsChrome:GetFrameLevel()) or wLevel
    st.rimFrame:SetFrameLevel(rimLevel)

    st.orb:ClearAllPoints()
    st.orb:SetPoint("CENTER", st.rimFrame, "TOPLEFT", 24, st.topRaise > 0 and -21 or -19)
    st.orb:SetFrameLevel(rimLevel + 1)

    st.headerTex:SetHeight(st.topRaise > 0 and 34 or 32)
    st.bgFrame:Show()
    st.rimFrame:Show()
    st.orb:Show()
    st.outerRim:Show()
end

local function skinTitle(st)
    local title = _G[st.name .. "TitleText"]
    if not title or not title.SetTextColor then return end
    if not st.titleSaved then
        local r, g, b, a = title:GetTextColor()
        local sr, sg, sb, sa = 0, 0, 0, 1
        if title.GetShadowColor then sr, sg, sb, sa = title:GetShadowColor() end
        local sx, sy = 1, -1
        if title.GetShadowOffset then sx, sy = title:GetShadowOffset() end
        st.titleSaved = { r = r or 1, g = g or 0.82, b = b or 0, a = a or 1,
            sr = sr, sg = sg, sb = sb, sa = sa, sx = sx, sy = sy }
    end
    title:SetTextColor(0.96, 0.99, 1.0, 1)
    if title.SetShadowColor then title:SetShadowColor(0.02, 0.14, 0.30, 0.95) end
    if title.SetShadowOffset then title:SetShadowOffset(1, -1) end
end

local function skinCloseButton(st)
    local close = _G[st.name .. "CloseButton"]
    if not close or not close.GetRegions then return end
    for _, region in ipairs({ close:GetRegions() }) do
        if isTexture(region) then fadeRegion(st, region) end
    end
    -- Child frame keeps close art immune to WindowSkin's `close:GetRegions()` alpha-zero loop.
    if not st.closeHolder then
        local holder = CreateFrame("Frame", nil, close)
        holder:EnableMouse(false)
        holder:SetSize(24, 24)
        st.ownFrames[holder] = true
        st.closeHolder = holder

        local face = holder:CreateTexture(nil, "ARTWORK")
        face:SetTexture(ART .. "Aero-Close")
        face:SetTexCoord(0, 0.25, 0, 1)
        face:SetAllPoints(holder)
        st.ownRegions[face] = true
        st.closeFace = face

        local glow = holder:CreateTexture(nil, "OVERLAY")
        glow:SetTexture(ART .. "Aero-Close")
        glow:SetTexCoord(0.75, 1, 0, 1)
        glow:SetBlendMode("ADD")
        glow:SetAllPoints(holder)
        glow:Hide()
        st.ownRegions[glow] = true
        st.closeGlow = glow

        if close.HookScript then
            close:HookScript("OnEnter", function()
                if st.active then
                    st.closeFace:SetTexCoord(0.25, 0.5, 0, 1)
                    st.closeGlow:Show()
                end
            end)
            close:HookScript("OnLeave", function()
                if st.active then
                    st.closeFace:SetTexCoord(0, 0.25, 0, 1)
                    st.closeGlow:Hide()
                end
            end)
            close:HookScript("OnMouseDown", function()
                if st.active then st.closeFace:SetTexCoord(0.5, 0.75, 0, 1) end
            end)
            close:HookScript("OnMouseUp", function(self)
                if st.active then
                    local over = self.IsMouseOver and self:IsMouseOver()
                    st.closeFace:SetTexCoord(over and 0.25 or 0, over and 0.5 or 0.25, 0, 1)
                end
            end)
            close:HookScript("OnShow", function()
                if st.active then
                    for _, region in ipairs({ close:GetRegions() }) do
                        if isTexture(region) then fadeRegion(st, region) end
                    end
                    st.closeHolder:SetFrameLevel((close:GetFrameLevel() or 0) + 1)
                    st.closeHolder:SetAlpha(1)
                    st.closeHolder:Show()
                    st.closeFace:SetAlpha(1)
                    st.closeFace:Show()
                end
            end)
        end
    end
    st.closeHolder:ClearAllPoints()
    st.closeHolder:SetPoint("CENTER", close, "CENTER", 0, st.topRaise > 0 and -2 or 0)
    st.closeHolder:SetFrameLevel((close:GetFrameLevel() or 0) + 1)
    st.closeHolder:SetAlpha(1)
    st.closeHolder:Show()
    st.closeFace:SetTexCoord(0, 0.25, 0, 1)
    st.closeFace:SetAlpha(1)
    st.closeFace:Show()
    st.closeGlow:Hide()
end

local function styleSlotButton(st, button, isToolbar)
    if not button or not button.GetRegions then return end
    for _, region in ipairs({ button:GetRegions() }) do
        if isTexture(region) then
            local p = texPath(region)
            if p:find("bag%-slot", 1, false) or p:find("backpack%-chrome", 1, false) then
                fadeRegion(st, region)
            end
        end
    end
    local normal = button.GetNormalTexture and button:GetNormalTexture()
    if normal and not st.ownRegions[normal] then fadeRegion(st, normal) end

    local artSlot = st.slotArts[button]
    if not artSlot then
        local well = button:CreateTexture(nil, "BACKGROUND", nil, -1)
        well:SetTexture(ART .. "Aero-Slot")
        well:SetTexCoord(0, 0.5, 0, 1)
        well:SetAllPoints(button)
        st.ownRegions[well] = true

        local rim = button:CreateTexture(nil, "ARTWORK", nil, isToolbar and 4 or 2)
        rim:SetTexture(ART .. "Aero-Slot")
        rim:SetTexCoord(0.5, 1, 0, 1)
        rim:SetAllPoints(button)
        st.ownRegions[rim] = true

        local hilite = button.GetHighlightTexture and button:GetHighlightTexture()
        if hilite and hilite.SetVertexColor then
            if st.hiliteColors[hilite] == nil then
                local r, g, b, a = 1, 1, 1, 1
                if hilite.GetVertexColor then r, g, b, a = hilite:GetVertexColor() end
                st.hiliteColors[hilite] = { r or 1, g or 1, b or 1, a or 1 }
            end
        end
        artSlot = { well = well, rim = rim, hilite = hilite }
        st.slotArts[button] = artSlot
    end
    artSlot.well:Show()
    artSlot.rim:Show()
end

local function skinSlotsAndToolbar(st)
    local window = st.window
    -- Toolbar buttons directly parented to `window` (`Options`, `Labels`, `Search`, `ToggleBags`, `KeyRing`, `Sort`, etc.)
    if window.GetChildren then
        for _, child in ipairs({ window:GetChildren() }) do
            if not st.ownFrames[child] and child.GetObjectType and child:GetObjectType() == "Button" then
                local childName = child.GetName and child:GetName() or ""
                if childName ~= st.name .. "CloseButton" then
                    local hasSlotArt = false
                    for _, region in ipairs({ child:GetRegions() }) do
                        if isTexture(region) then
                            local p = texPath(region)
                            if p:find("bag%-slot", 1, false) or p:find("backpack%-chrome", 1, false) then
                                hasSlotArt = true
                                break
                            end
                        end
                    end
                    if hasSlotArt or st.slotArts[child] then
                        styleSlotButton(st, child, true)
                    end
                end
            end
        end
    end

    -- BagTray bag slots
    local tray = _G[st.name .. "BagTray"]
    if tray and tray.GetChildren then
        for _, slot in ipairs({ tray:GetChildren() }) do
            if slot.GetObjectType and slot:GetObjectType() == "Button" then
                styleSlotButton(st, slot, true)
            end
        end
    end

    -- Item Grid bags, item slots, and group separators
    local grid = _G[st.name .. "Grid"]
    if grid and grid.GetChildren then
        for _, bag in ipairs({ grid:GetChildren() }) do
            if bag.GetChildren then
                for _, itemBtn in ipairs({ bag:GetChildren() }) do
                    if itemBtn.GetObjectType and itemBtn:GetObjectType() == "Button" then
                        styleSlotButton(st, itemBtn, false)
                    end
                end
            end
            if bag.separator then
                local sep = bag.separator
                if not st.separators[sep] then
                    st.separators[sep] = {
                        tex = sep.GetTexture and sep:GetTexture() or WHITE,
                        h = sep.GetHeight and sep:GetHeight() or 1,
                    }
                end
                sep:SetTexture(ART .. "Aero-Divider")
                sep:SetHeight(6)
            end
        end
    end
end

local function skinSearchAndFooter(st)
    local preset = getConfig()
    local searchBox = _G[st.name .. "SearchBox"]
    if searchBox then
        saveBackdrop(st, searchBox)
        if not st.searchPill then
            st.searchPill = createNineSlice(st, searchBox, ART .. "Aero-Pill", 256, 128, 24, 9, "BACKGROUND", -2, true)
            st.searchPill:Anchor(searchBox, 0)
            if searchBox.HookScript then
                searchBox:HookScript("OnEditFocusGained", function()
                    if st.active and st.searchPill then
                        local p = getConfig()
                        st.searchPill:SetColor(1.0, 1.0, 1.0, 1.0)
                        if p.border then st.searchPill.slices.top:SetVertexColor(1, 1, 1, 1) end
                    end
                end)
                searchBox:HookScript("OnEditFocusLost", function()
                    if st.active and st.searchPill then
                        local p = getConfig()
                        st.searchPill:SetColor(p.pill[1], p.pill[2], p.pill[3], 1)
                    end
                end)
            end
        end
        st.searchPill:Show()
        for _, region in ipairs({ searchBox:GetRegions() }) do
            if isTexture(region) and not st.ownRegions[region] and texPath(region):find("backpack%-chrome", 1, false) then
                if not st.tints[region] then
                    st.tints[region] = { region.GetVertexColor and region:GetVertexColor() }
                end
                region:SetVertexColor(preset.accent[1], preset.accent[2], preset.accent[3])
            elseif region and region.GetObjectType and region:GetObjectType() == "FontString"
                and region.SetTextColor then
                if not st.hintColors[region] then
                    local r, g, b, a = 0.5, 0.5, 0.5, 1
                    if region.GetTextColor then r, g, b, a = region:GetTextColor() end
                    st.hintColors[region] = { r or 0.5, g or 0.5, b or 0.5, a or 1 }
                end
                region:SetTextColor(0.76, 0.90, 0.98, 0.90)
            end
        end
    end

    local footer = _G[st.name .. "Footer"]
    if footer then
        saveBackdrop(st, footer)
        if not st.footerPill then
            st.footerPill = createNineSlice(st, footer, ART .. "Aero-Pill", 256, 128, 24, 9, "BACKGROUND", -2, true)
            st.footerPill:Anchor(footer, 0)
        end
        st.footerPill:Show()
    end

    local buySlot = _G[st.name .. "BuySlot"]
    if buySlot and buySlot.GetRegions then
        for _, region in ipairs({ buySlot:GetRegions() }) do
            if isTexture(region) then fadeRegion(st, region) end
        end
        if not st.buyPill then
            st.buyPill = createNineSlice(st, buySlot, ART .. "Aero-Pill", 256, 128, 24, 8, "BACKGROUND", -2, true)
            st.buyPill:Anchor(buySlot, 0)
        end
        st.buyPill:Show()
    end
end

local function styleCurrencyRows(st, panel)
    if not (st.active and panel and panel.GetChildren) then return end
    local preset = getConfig()
    for _, row in ipairs({ panel:GetChildren() }) do
        if not st.ownFrames[row] and row.line then
            row.line:SetVertexColor(preset.divider[1], preset.divider[2], preset.divider[3], 0.30)
        end
    end
end

local function skinCurrencies(st)
    local preset = getConfig()
    local toggleBtn = _G[st.name .. "CurrencyToggle"]
    if toggleBtn and toggleBtn.GetRegions then
        for _, region in ipairs({ toggleBtn:GetRegions() }) do
            if isTexture(region) and not st.ownRegions[region] then
                if not st.tints[region] then
                    local r, g, b, a = 1, 1, 1, 1
                    if region.GetVertexColor then r, g, b, a = region:GetVertexColor() end
                    st.tints[region] = { r or 1, g or 1, b or 1, a or 1 }
                end
                region:SetVertexColor(preset.accent[1], preset.accent[2], preset.accent[3], 1)
            end
        end
    end

    local panel = _G[st.name .. "Currencies"]
    if not panel then return end
    saveBackdrop(st, panel)
    if not st.currencyBg then
        local bg = panel:CreateTexture(nil, "BACKGROUND", nil, -4)
        bg:SetTexture(ART .. "Aero-Backdrop")
        bg:SetPoint("TOPLEFT", panel, "TOPLEFT", 2, -2)
        bg:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -2, 2)
        st.ownRegions[bg] = true
        st.currencyBg = bg

        st.currencyRim = createNineSlice(st, panel, ART .. "Aero-Frame", 256, 256, 36, 10, "BACKGROUND", -1, false)
        st.currencyRim:Anchor(panel, 0)

        if panel.HookScript then
            local function restyle() styleCurrencyRows(st, panel) end
            panel:HookScript("OnShow", restyle)
            panel:HookScript("OnMouseWheel", restyle)
            panel:HookScript("OnEvent", restyle)
        end
    end
    st.currencyBg:Show()
    st.currencyRim:Show()
    styleCurrencyRows(st, panel)
end

local function applyColors(st)
    local preset, bubbles, alphaPct = getConfig()
    local alpha = alphaPct / 100

    st.backdropTex:SetVertexColor(preset.bg[1], preset.bg[2], preset.bg[3], alpha)
    st.headerTex:SetVertexColor(preset.header[1], preset.header[2], preset.header[3], math.min(1, alpha + 0.08))
    st.headerDiv:SetVertexColor(preset.divider[1], preset.divider[2], preset.divider[3], 0.95)
    st.outerRim:SetColor(preset.border[1], preset.border[2], preset.border[3], 1)
    st.orbBack:SetVertexColor(preset.orb[1], preset.orb[2], preset.orb[3], 1)
    st.orbDome:SetVertexColor(preset.orb[1], preset.orb[2], preset.orb[3], 1)

    if bubbles then
        st.bubblesTex:SetVertexColor(preset.bubble[1], preset.bubble[2], preset.bubble[3], preset.bubble[4])
        st.bubblesTex:Show()
    else
        st.bubblesTex:Hide()
    end

    for _, slotArt in pairs(st.slotArts) do
        slotArt.well:SetVertexColor(preset.slot[1], preset.slot[2], preset.slot[3], 0.95)
        slotArt.rim:SetVertexColor(preset.border[1], preset.border[2], preset.border[3], 1)
        if slotArt.hilite and slotArt.hilite.SetVertexColor then
            slotArt.hilite:SetVertexColor(preset.accent[1], preset.accent[2], preset.accent[3], 0.85)
        end
    end

    for sep in pairs(st.separators) do
        sep:SetVertexColor(preset.divider[1], preset.divider[2], preset.divider[3], 0.90)
    end

    if st.searchPill then st.searchPill:SetColor(preset.pill[1], preset.pill[2], preset.pill[3], 0.96) end
    if st.footerPill then st.footerPill:SetColor(preset.pill[1], preset.pill[2], preset.pill[3], 0.96) end
    if st.buyPill then st.buyPill:SetColor(preset.orb[1], preset.orb[2], preset.orb[3], 0.98) end
    if st.currencyBg then
        st.currencyBg:SetVertexColor(preset.bg[1], preset.bg[2], preset.bg[3], math.min(0.98, alpha + 0.06))
        st.currencyRim:SetColor(preset.border[1], preset.border[2], preset.border[3], 1)
    end
    local currencyPanel = _G[st.name .. "Currencies"]
    if currencyPanel and currencyPanel:IsShown() then styleCurrencyRows(st, currencyPanel) end
end

local function createState(window, name)
    local st = {
        window = window,
        name = name,
        ownFrames = {},
        ownRegions = {},
        faded = {},
        backdrops = {},
        slotArts = {},
        hiliteColors = {},
        separators = {},
        tints = {},
        hintColors = {},
        hookedWs = {},
    }
    skins[window] = st
    return st
end

local function restoreWindow(st)
    if not st then return end
    st.active = false

    if st.wsChrome then
        st.wsChrome:SetAlpha(1)
        st.wsChrome = nil
    end

    for region, alpha in pairs(st.faded) do
        if region.SetAlpha then region:SetAlpha(alpha) end
    end
    st.faded = {}

    for frame, saved in pairs(st.backdrops) do
        if frame.SetBackdrop then
            frame:SetBackdrop(saved.bg)
            if saved.color and frame.SetBackdropColor and #saved.color >= 3 then
                frame:SetBackdropColor(saved.color[1], saved.color[2], saved.color[3], saved.color[4] or 1)
            end
            if saved.border and frame.SetBackdropBorderColor and #saved.border >= 3 then
                frame:SetBackdropBorderColor(saved.border[1], saved.border[2], saved.border[3], saved.border[4] or 1)
            end
        end
    end
    st.backdrops = {}

    for sep, orig in pairs(st.separators) do
        sep:SetTexture(orig.tex or WHITE)
        sep:SetVertexColor(0.56, 0.49, 0.37, 0.78)
        sep:SetHeight(orig.h or 1)
    end
    st.separators = {}

    for region, color in pairs(st.tints) do
        if region.SetVertexColor then
            region:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
        end
    end
    st.tints = {}

    for region, color in pairs(st.hintColors or {}) do
        if region.SetTextColor then
            region:SetTextColor(color[1] or 0.5, color[2] or 0.5, color[3] or 0.5, color[4] or 1)
        end
    end
    st.hintColors = {}

    for hilite, color in pairs(st.hiliteColors) do
        if hilite.SetVertexColor then
            hilite:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
        end
    end

    for _, slotArt in pairs(st.slotArts) do
        slotArt.well:Hide()
        slotArt.rim:Hide()
    end

    local title = _G[st.name .. "TitleText"]
    if title and st.titleSaved then
        local s = st.titleSaved
        title:SetTextColor(s.r, s.g, s.b, s.a)
        if title.SetShadowColor then title:SetShadowColor(s.sr, s.sg, s.sb, s.sa) end
        if title.SetShadowOffset then title:SetShadowOffset(s.sx, s.sy) end
        st.titleSaved = nil
    end

    if st.closeHolder then st.closeHolder:Hide() end
    if st.closeFace then st.closeFace:Hide() end
    if st.closeGlow then st.closeGlow:Hide() end
    if st.searchPill then st.searchPill:Hide() end
    if st.footerPill then st.footerPill:Hide() end
    if st.buyPill then st.buyPill:Hide() end
    if st.currencyBg then st.currencyBg:Hide() end
    if st.currencyRim then st.currencyRim:Hide() end
    if st.bgFrame then st.bgFrame:Hide() end
    if st.rimFrame then st.rimFrame:Hide() end
    if st.orb then st.orb:Hide() end
    if st.outerRim then st.outerRim:Hide() end

    local currencyPanel = _G[st.name .. "Currencies"]
    if currencyPanel and currencyPanel.GetChildren then
        for _, row in ipairs({ currencyPanel:GetChildren() }) do
            if not st.ownFrames[row] and row.line then
                row.line:SetVertexColor(0.55, 0.39, 0.21, 0.35)
            end
        end
    end
end

local function scheduleApply(window, wait)
    if not window then return end
    pendingWindows[window] = math.max(pendingWindows[window] or 0, wait or 0.25)
    retryTimer:Show()
end

local function hookWindow(window)
    if not window or hookedWindows[window] or not window.HookScript then return end
    hookedWindows[window] = true
    window:HookScript("OnShow", function(self)
        if isAeroEnabled() then
            applyWindow(self)
            scheduleApply(self, 0.25) -- catches WindowSkin's delayed OnShow skinning
        end
    end)
    window:HookScript("OnSizeChanged", function(self)
        local st = skins[self]
        if st and st.active then skinSlotsAndToolbar(st); applyColors(st) end
    end)
end

applyWindow = function(window)
    if not window then return end
    local name = window.GetName and window:GetName()
    if not name then return end
    hookWindow(window)
    local st = skins[window]
    if not isAeroEnabled() then
        if st and st.active then restoreWindow(st) end
        return
    end
    st = st or createState(window, name)
    st.active = true
    ensureChrome(st)

    syncChromeGeometry(st)
    for _, region in ipairs({ window:GetRegions() }) do
        if isTexture(region) and not st.ownRegions[region] then fadeRegion(st, region) end
    end
    saveBackdrop(st, window)
    fadeRegion(st, _G[name .. "PortraitFrame"])

    skinTitle(st)
    skinCloseButton(st)
    skinSlotsAndToolbar(st)
    skinSearchAndFooter(st)
    skinCurrencies(st)
    refreshOrbIcon(st)
    applyColors(st)
end

local function restoreAll()
    for window in pairs(pendingWindows) do pendingWindows[window] = nil end
    retryTimer:Hide()
    for _, st in pairs(skins) do restoreWindow(st) end
end

local function applyAll()
    if not isAeroEnabled() then
        restoreAll()
        return
    end
    for _, name in ipairs(WINDOWS) do
        local window = _G[name]
        if window then
            hookWindow(window)
            applyWindow(window)
        end
    end
end

retryTimer:SetScript("OnUpdate", function(self, elapsed)
    local any = false
    for window, wait in pairs(pendingWindows) do
        wait = wait - elapsed
        if wait <= 0 then
            pendingWindows[window] = nil
            applyWindow(window)
        else
            pendingWindows[window] = wait
            any = true
        end
    end
    if not any then self:Hide() end
end)

local function hookTargetWindows()
    local missing = false
    local aero = isAeroEnabled()
    for _, name in ipairs(WINDOWS) do
        local window = _G[name]
        if window then
            hookWindow(window)
            if aero then applyWindow(window) end
        else
            missing = true
        end
    end
    return not missing
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("BAG_UPDATE")
events:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
events:RegisterEvent("BANKFRAME_OPENED")
events:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        if (IsAddOnLoaded and IsAddOnLoaded("Bagnon")) or settings().bagsEnabled == false then return end
        local tries, wait = 0, 0
        self:SetScript("OnUpdate", function(frame, elapsed)
            wait = wait + elapsed
            if wait < 0.1 then return end
            wait = 0
            tries = tries + 1
            local allFound = hookTargetWindows()
            if allFound or tries >= 20 then frame:SetScript("OnUpdate", nil) end
        end)
        hookTargetWindows()
    elseif event == "PLAYER_ENTERING_WORLD" then
        if isAeroEnabled() then
            for _, st in pairs(skins) do refreshOrbIcon(st) end
            hookTargetWindows()
        end
    elseif event == "BAG_UPDATE" then
        if not isAeroEnabled() then return end
        local inv = _G.ForeverStockInventory
        local st = inv and skins[inv]
        if st and st.active and inv:IsShown() then
            skinSlotsAndToolbar(st)
            applyColors(st)
        end
    elseif event == "PLAYERBANKSLOTS_CHANGED" or event == "BANKFRAME_OPENED" then
        if not isAeroEnabled() then return end
        local bank = _G.ForeverStockBank
        if bank then
            applyWindow(bank)
            scheduleApply(bank, 0.25)
        else
            hookTargetWindows()
        end
    end
end)

ui.BagAero = {
    Apply = applyAll,
    Restore = restoreAll,
    Presets = PRESETS,
    Skins = skins,
}
