local _, ui = ...
-- Warm bronze tint for the interface windows. Texture colour only: nothing is moved, resized or
-- recreated, and no behaviour is touched. Textures are recognised by file name.
local WARM = { 1.0, 0.80, 0.56 }
local MATCH = { "uiframe", "diamondmetal", "charpaperdollparts", "charstatmiddle", "characterplus",
    "sidetab", "paperdollsidebartabs", "characterpanelbackground", "ui%-dialogbox", "ui%-panel",
    "paperdollinfoframe", "spellbook", "talentframe", "friendsframe", "ui%-frame", "framegeneral",
    "commonframe", "ui%-background", "marble", "rock", "store", "shop", "collections", "journal" }
local SKIP = { "icons.", "portrait", "checkbox", ".character.", "statusbar", "cooldown",
    "tooltip", "model", "parchment", "dressup" }
local WINDOWS = { "CharacterFrame", "SpellBookFrame", "PlayerTalentFrame", "FriendsFrame", "QuestLogFrame",
    "GossipFrame", "QuestFrame", "MerchantFrame", "MailFrame", "TradeFrame", "BankFrame", "LootFrame",
    "InspectFrame", "AuctionFrame", "GuildBankFrame", "TradeSkillFrame", "WorldMapFrame", "ChatConfigFrame",
    "GameMenuFrame", "AchievementFrame", "LFDParentFrame", "PVPFrame", "ClassTrainerFrame", "TaxiFrame",
    "NozdorCollectionsFrame", "EncounterJournal", "BattlePassFrame", "LuckyWheelMainFrame", "NozdorStoreFrame", "StoreFrame",
    "StaticPopup1", "GlyphFrame", "ItemSocketingFrame", "MacroFrame", "ReadyCheckFrame" }
local LISTED = {}
for _, name in ipairs(WINDOWS) do LISTED[name] = true end
local tinted = {}
local select, type = select, type

-- The verdict depends only on the file name, so it is worked out once per file name and kept:
-- reopening a window costs one GetTexture and one table lookup per texture, no string work.
local verdict, forcedVerdict = {}, {}

local function judge(path, force)
    if type(path) ~= "string" then return false end
    path = path:lower()
    for _, fragment in ipairs(SKIP) do
        if path:find(fragment) then return false end
    end
    -- Solid-colour textures (a dark ground drawn with SetTexture(r, g, b)) take their whole colour from
    -- the vertex colour: tinting them would paint over it, so they are left alone.
    if not (path:find("/", 1, true) or path:find("%c")) and not path:find("interface") then return false end
    if path:find("white8x8") or path:find("solid") then return false end
    if force then return true end
    for _, fragment in ipairs(MATCH) do
        if path:find(fragment) then return true end
    end
    return false
end

local function isFrameArt(texture, force)
    local path = texture:GetTexture()
    if type(path) ~= "string" then return false end
    local cache = force and forcedVerdict or verdict
    local known = cache[path]
    if known == nil then
        known = judge(path, force)
        cache[path] = known
    end
    return known
end

-- Windows whose texture names are not known: everything but icons, portraits and the like is tinted.
local FORCE = { StoreFrame = true }

-- The original colour of each texture is kept: the tint multiplies it (a dark ground stays dark) and
-- turning the skin off puts it back.
-- The shop panels are "Inset" frames (StoreFrameFilterInset and its siblings): only the large background
-- textures of those frames are replaced by the dark WoW: Forever ground; rows and buttons are not touched.
local GROUND = "Interface/AddOns/ForeverUI/Art/Forever-DarkGround"
local grounded = {}

local function isTexture(region)
    return region.GetObjectType and region:GetObjectType() == "Texture"
end

-- Regions and children are walked straight from the varargs: no table is made per frame, so opening a
-- window leaves nothing for the garbage collector.
local function groundRegions(...)
    for i = 1, select("#", ...) do
        local region = select(i, ...)
        if not grounded[region] and isTexture(region) then
            local w, h = region:GetWidth() or 0, region:GetHeight() or 0
            local layer = region:GetDrawLayer()
            if w >= 100 and h >= 100 and (layer == "BACKGROUND" or layer == "BORDER") then
                grounded[region] = true
                region:SetTexture(GROUND)
                region:SetHorizTile(true)
                region:SetVertTile(true)
                region:SetTexCoord(0, w / 64, 0, h / 64)
                region:SetVertexColor(1, 0.92, 0.82)
            end
        end
    end
end

local groundInsets
local function groundChildren(depth, ...)
    for i = 1, select("#", ...) do groundInsets(select(i, ...), depth) end
end

groundInsets = function(frame, depth)
    if not frame or depth > 6 then return end
    local name = frame.GetName and frame:GetName()
    if name and name:find("Inset", 1, true) then groundRegions(frame:GetRegions()) end
    groundChildren(depth + 1, frame:GetChildren())
end

local function near(a, b)
    return a and b and a - b < 0.004 and b - a < 0.004
end

local function tintRegions(on, force, ...)
    for i = 1, select("#", ...) do
        local region = select(i, ...)
        if not grounded[region] and isTexture(region) and (tinted[region] or isFrameArt(region, force)) then
            local original = tinted[region]
            if not original then
                local r, g, b = region:GetVertexColor()
                original = { r, g, b }
                tinted[region] = original
            end
            local r, g, b = original[1], original[2], original[3]
            if on then r, g, b = r * WARM[1], g * WARM[2], b * WARM[3] end
            -- Only a colour that differs is set again: an already tinted window costs no redraw.
            local cr, cg, cb = region:GetVertexColor()
            if not (near(cr, r) and near(cg, g) and near(cb, b)) then
                region:SetVertexColor(r, g, b)
            end
        end
    end
end

-- Stock panel buttons (UIPanelButtonTemplate: one stretched UI-Panel-Button-Up/Down/Disabled texture) get the
-- WoW Forever red button (Art/Forever/Panel-Button.tga: up, pressed, disabled and the glow in 256 x 64 rows).
-- A button is done once; turning the skin off leaves it as it is until /reload.
local buttonArt = "Interface\\AddOns\\ForeverUI\\Art\\Forever\\Panel-Button"
local buttonRows = { up = 0, down = 1, disabled = 2, highlight = 3 }
local skinnedButtons = {}
local function buttonFace(texture, row)
    if not texture then return end
    texture:SetTexture(buttonArt)
    texture:SetTexCoord(0, 1, row / 4, (row + 1) / 4)
    tinted[texture] = nil
    grounded[texture] = true          -- keeps the warm tint off the new face
end
local function skinPanelButton(button)
    if skinnedButtons[button] or not button.GetNormalTexture then return end
    local normal = button:GetNormalTexture()
    local path = normal and normal:GetTexture()
    if type(path) ~= "string" or not path:lower():find("ui%-panel%-button%-up") then return end
    skinnedButtons[button] = true
    buttonFace(normal, buttonRows.up)
    buttonFace(button:GetPushedTexture(), buttonRows.down)
    buttonFace(button:GetDisabledTexture(), buttonRows.disabled)
    local highlight = button:GetHighlightTexture()
    if highlight then
        buttonFace(highlight, buttonRows.highlight)
        highlight:SetBlendMode("ADD")
    end
end

local scan
local function scanChildren(on, depth, force, ...)
    for i = 1, select("#", ...) do scan(select(i, ...), on, depth, force) end
end

scan = function(frame, on, depth, force)
    if not frame or depth > 6 then return end
    if on and frame.GetObjectType and frame:GetObjectType() == "Button" then skinPanelButton(frame) end
    tintRegions(on, force, frame:GetRegions())
    scanChildren(on, depth + 1, force, frame:GetChildren())
end

local function enabled()
    return ui.Settings().characterSkin ~= false
end

local function applyWindow(frame, name)
    local on = enabled()
    if not on and not next(tinted) then return end
    name = name or (frame.GetName and frame:GetName())
    local force = name and FORCE[name]
    if force and on then groundInsets(frame, 0) end
    scan(frame, on, 0, force)
end

-- Every listed window: used when the setting changes and once after login.
local function apply()
    if not enabled() and not next(tinted) then return end
    for _, name in ipairs(WINDOWS) do
        local frame = _G[name]
        if frame then applyWindow(frame, name) end
    end
end

-- A window can finish building after its OnShow, so the window that opened (and only that one) is
-- scanned twice: after 0.2 s and after 1.2 s.
local pendingWait, pendingPass = {}, {}
local delay = CreateFrame("Frame")
delay:Hide()
delay:SetScript("OnUpdate", function(self, elapsed)
    local left = false
    for frame, waited in pairs(pendingWait) do
        waited = waited + elapsed
        local pass = pendingPass[frame]
        if pass == 0 and waited >= 0.2 then
            pendingPass[frame] = 1
            applyWindow(frame)
        elseif pass == 1 and waited >= 1.2 then
            pendingWait[frame], pendingPass[frame] = nil, nil
            applyWindow(frame)
        end
        if pendingWait[frame] then
            pendingWait[frame] = waited
            left = true
        end
    end
    if not left then self:Hide() end
end)

local function later(frame)
    pendingWait[frame], pendingPass[frame] = 0, 0
    delay:Show()
end

local hooked = {}
local function hookWindows()
    for _, name in ipairs(WINDOWS) do
        local frame = _G[name]
        if frame and not hooked[name] and frame.HookScript then
            hooked[name] = true
            frame:HookScript("OnShow", later)
        end
    end
end

-- Windows made by the client patch (Collections, Adventure Guide, Shop...) are not in the list above and
-- have no Lua of their own here: every 2 s the large visible children of UIParent are found and scanned
-- once per opening. Listed windows are skipped: their own OnShow hook already scans them.
local AUTO_SKIP = { "Chat", "Minimap", "Bagnon", "WeakAuras", "DBM", "Cell", "Prat", "Gatherer", "Nameplate",
    "ActionBar", "MainMenuBar", "WorldFrame", "ForeverStock", "PlayerFrame", "TargetFrame", "Tooltip" }
local seenShown = {}

local function autoFrame(frame)
    local name = frame.GetName and frame:GetName()
    local shown = name and not LISTED[name] and frame:IsShown()
        and (frame:GetWidth() or 0) >= 250 and (frame:GetHeight() or 0) >= 200
    if shown then
        for _, fragment in ipairs(AUTO_SKIP) do
            if name:find(fragment, 1, true) then shown = false break end
        end
    end
    if shown and not seenShown[frame] then
        seenShown[frame] = 1
        scan(frame, true, 0)
    elseif shown and seenShown[frame] == 1 then
        seenShown[frame] = 2
        scan(frame, true, 0)           -- content built after the first look
    elseif not shown then
        seenShown[frame] = nil
    end
end

local function autoChildren(...)
    for i = 1, select("#", ...) do autoFrame(select(i, ...)) end
end

local auto = CreateFrame("Frame")
local autoWait = 0
auto:SetScript("OnUpdate", function(self, elapsed)
    autoWait = autoWait + elapsed
    if autoWait < 2 then return end
    autoWait = 0
    if not enabled() then return end
    hookWindows()                      -- windows created later (the shop) get their OnShow hook here
    autoChildren(UIParent:GetChildren())
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event)
    hookWindows()
    if event == "PLAYER_LOGIN" then
        SLASH_FUICHARSKIN1 = "/fuiskin"
        SlashCmdList.FUICHARSKIN = function()
            -- Hover a window and type /fuiskin: prints the names of the frame under the mouse and its parents.
            local frame, chain = GetMouseFocus(), {}
            while frame and frame ~= WorldFrame and #chain < 8 do
                chain[#chain + 1] = (frame.GetName and frame:GetName()) or "?"
                frame = frame.GetParent and frame:GetParent()
            end
            DEFAULT_CHAT_FRAME:AddMessage("ForeverUI: " .. table.concat(chain, " < "))
        end
        -- Windows already open at login are tinted once, a moment after it.
        local wait = 0
        local login = CreateFrame("Frame")
        login:SetScript("OnUpdate", function(f, elapsed)
            wait = wait + elapsed
            if wait >= 1.2 then
                f:SetScript("OnUpdate", nil)
                apply()
            end
        end)
    end
end)

-- WoW Forever talent backgrounds. The stock code sets "Interface\TalentFrame\<Tree>-TopLeft" (and TopRight,
-- BottomLeft, BottomRight) on four pieces; the tree name picks a panel of the class sheet in Art/Forever/Talents.
-- Class sheets hold three portrait panels of 341 x 590 at the top of 1024 x 1024; the death knight ones are
-- landscape panels of 807 x 388 (two in deathknight1, one in deathknight2). Pet trees keep the stock art.
local talentArt = "Interface\\AddOns\\ForeverUI\\Art\\Forever\\Talents\\"
local trees = {
    druidbalance = { "druid", 1 }, druidferalcombat = { "druid", 2 }, druidrestoration = { "druid", 3 },
    hunterbeastmastery = { "hunter", 1 }, huntermarksmanship = { "hunter", 2 }, huntersurvival = { "hunter", 3 },
    magearcane = { "mage", 1 }, magefire = { "mage", 2 }, magefrost = { "mage", 3 },
    paladinholy = { "paladin", 1 }, paladinprotection = { "paladin", 2 }, paladincombat = { "paladin", 3 },
    priestdiscipline = { "priest", 1 }, priestholy = { "priest", 2 }, priestshadow = { "priest", 3 },
    rogueassassination = { "rogue", 1 }, roguecombat = { "rogue", 2 }, roguesubtlety = { "rogue", 3 },
    shamanelementalcombat = { "shaman", 1 }, shamanenhancement = { "shaman", 2 }, shamanrestoration = { "shaman", 3 },
    warlockcurses = { "warlock", 1 }, warlocksummoning = { "warlock", 2 }, warlockdestruction = { "warlock", 3 },
    warriorarm = { "warrior", 1 }, warriorfury = { "warrior", 2 }, warriorprotection = { "warrior", 3 },
    deathknightblood = { "deathknight", 1 }, deathknightfrost = { "deathknight", 2 }, deathknightunholy = { "deathknight", 3 },
}
-- Panel of a tree as file, left, top, width, height (texture px).
local function treePanel(class, index)
    if class == "deathknight" then
        if index == 3 then return talentArt .. "deathknight2", 0, 0, 807, 388, 1024, 512 end
        return talentArt .. "deathknight1", 0, (index - 1) * 388, 807, 388, 1024, 1024
    end
    return talentArt .. class, (index - 1) * 341, 0, 341, 590, 1024, 1024
end
local corners = { "TopLeft", "TopRight", "BottomLeft", "BottomRight" }
local talentSwapping = {}
local function skinTalentFrame(prefix)
    local pieces = {}
    for _, corner in ipairs(corners) do
        pieces[corner] = _G[prefix .. "Background" .. corner]
        if not pieces[corner] then return end
    end
    local function place(tree)
        local file, left, top, width, height, sheetW, sheetH = treePanel(tree[1], tree[2])
        local totalW = pieces.TopLeft:GetWidth() + pieces.TopRight:GetWidth()
        local totalH = pieces.TopLeft:GetHeight() + pieces.BottomLeft:GetHeight()
        if totalW <= 0 or totalH <= 0 then return end
        -- Crop the panel to the frame's proportions, centred.
        local aspect = totalW / totalH
        if width / height > aspect then
            local cropped = height * aspect
            left, width = left + (width - cropped) / 2, cropped
        else
            local cropped = width / aspect
            top, height = top + (height - cropped) / 2, cropped
        end
        local splitX = pieces.TopLeft:GetWidth() / totalW
        local splitY = pieces.TopLeft:GetHeight() / totalH
        local spans = {
            TopLeft = { 0, splitX, 0, splitY }, TopRight = { splitX, 1, 0, splitY },
            BottomLeft = { 0, splitX, splitY, 1 }, BottomRight = { splitX, 1, splitY, 1 },
        }
        for corner, piece in pairs(pieces) do
            local s = spans[corner]
            talentSwapping[piece] = true
            piece:SetTexture(file)
            piece:SetTexCoord((left + s[1] * width) / sheetW, (left + s[2] * width) / sheetW,
                (top + s[3] * height) / sheetH, (top + s[4] * height) / sheetH)
            talentSwapping[piece] = false
        end
    end
    for _, piece in pairs(pieces) do
        talentSwapping[piece] = false
        hooksecurefunc(piece, "SetTexture", function(self, path)
            if talentSwapping[self] or not enabled() or type(path) ~= "string" then return end
            local name = path:lower():match("talentframe[\\/]([%w]+)%-")
            local tree = name and trees[name]
            if tree then
                place(tree)
            else
                self:SetTexCoord(0, 1, 0, 1)
            end
        end)
    end
    local current = pieces.TopLeft:GetTexture()
    if type(current) == "string" then pieces.TopLeft:SetTexture(current) end
end
local talentEvents = CreateFrame("Frame")
talentEvents:RegisterEvent("ADDON_LOADED")
talentEvents:RegisterEvent("PLAYER_LOGIN")
local talentSkinned = {}
talentEvents:SetScript("OnEvent", function()
    for _, prefix in ipairs({ "PlayerTalentFrame", "InspectTalentFrame" }) do
        if not talentSkinned[prefix] and _G[prefix .. "BackgroundTopLeft"] then
            talentSkinned[prefix] = true
            skinTalentFrame(prefix)
        end
    end
end)

ui.CharacterSkin = { Apply = apply }
