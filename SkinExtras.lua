local _, ui = ...
-- WoW Forever art on stock elements that are not window chrome (WindowSkin.lua does the windows):
--   * panel buttons (UIPanelButtonTemplate) get the WoW Forever red button;
--   * talent tree backgrounds get the WoW Forever class panels.
-- Both are switched on the "Skins" page (master switch `foreverWindows`, then `skinPanelButtons` / `skinTalents`).
-- They replace textures once; turning them off takes effect after /reload.

local function settings() return ui.Settings and ui.Settings() or {} end
local function on(key)
    local db = settings()
    return db.foreverWindows ~= false and db[key] ~= false
end

-- Panel buttons ---------------------------------------------------------------------------------------------
-- Stock panel buttons (UIPanelButtonTemplate: one stretched UI-Panel-Button-Up/Down/Disabled texture) get the
-- WoW Forever red button (Art/Forever/Panel-Button.tga: up, pressed, disabled and the glow in 256 x 64 rows).
-- The windows below are scanned for such buttons each time they open.
local WINDOWS = { "CharacterFrame", "SpellBookFrame", "PlayerTalentFrame", "FriendsFrame", "QuestLogFrame",
    "GossipFrame", "QuestFrame", "MerchantFrame", "MailFrame", "TradeFrame", "BankFrame", "LootFrame",
    "InspectFrame", "AuctionFrame", "GuildBankFrame", "TradeSkillFrame", "WorldMapFrame", "ChatConfigFrame",
    "GameMenuFrame", "AchievementFrame", "LFDParentFrame", "PVPFrame", "ClassTrainerFrame", "TaxiFrame",
    "NozdorCollectionsFrame", "EncounterJournal", "BattlePassFrame", "LuckyWheelMainFrame", "NozdorStoreFrame", "StoreFrame",
    "StaticPopup1", "GlyphFrame", "ItemSocketingFrame", "MacroFrame", "ReadyCheckFrame" }

local buttonArt = "Interface\\AddOns\\ForeverUI\\Art\\Forever\\Panel-Button"
local buttonRows = { up = 0, down = 1, disabled = 2, highlight = 3 }
local skinnedButtons = {}

local function buttonFace(texture, row)
    if not texture then return end
    texture:SetTexture(buttonArt)
    texture:SetTexCoord(0, 1, row / 4, (row + 1) / 4)
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

local scanButtons
local function scanChildren(depth, ...)
    for i = 1, select("#", ...) do scanButtons(select(i, ...), depth) end
end
scanButtons = function(frame, depth)
    if not frame or depth > 6 then return end
    if frame.GetObjectType and frame:GetObjectType() == "Button" then skinPanelButton(frame) end
    scanChildren(depth + 1, frame:GetChildren())
end

-- A window can finish building after its OnShow, so the window that opened is scanned at once, after 0.2 s and
-- after 1.2 s.
local pending = {}
local delay = CreateFrame("Frame")
delay:Hide()
delay:SetScript("OnUpdate", function(self, elapsed)
    local left = false
    for frame, waited in pairs(pending) do
        local before = waited
        waited = waited + elapsed
        if (before < 0.2 and waited >= 0.2) or (before < 1.2 and waited >= 1.2) then scanButtons(frame, 0) end
        if waited >= 1.2 then
            pending[frame] = nil
        else
            pending[frame] = waited
            left = true
        end
    end
    if not left then self:Hide() end
end)

local function onShow(frame)
    if not on("skinPanelButtons") then return end
    scanButtons(frame, 0)
    pending[frame] = 0
    delay:Show()
end

local hooked = {}
local function hookWindows()
    for _, name in ipairs(WINDOWS) do
        local frame = _G[name]
        if frame and not hooked[name] and frame.HookScript then
            hooked[name] = true
            frame:HookScript("OnShow", onShow)
        end
    end
end

-- Windows loaded later (load-on-demand UIs, the shop) are hooked when they appear.
local late = CreateFrame("Frame")
local lateWait = 0
late:SetScript("OnUpdate", function(self, elapsed)
    lateWait = lateWait + elapsed
    if lateWait < 2 then return end
    lateWait = 0
    hookWindows()
end)

-- Talent backgrounds ----------------------------------------------------------------------------------------
-- The stock code sets "Interface\TalentFrame\<Tree>-TopLeft" (and TopRight, BottomLeft, BottomRight) on four
-- pieces; the tree name picks a panel of the class sheet in Art/Forever/Talents. Class sheets hold three portrait
-- panels of 341 x 590 at the top of 1024 x 1024; the death knight ones are landscape panels of 807 x 388 (two in
-- deathknight1, one in deathknight2). Pet trees keep the stock art.
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
            if talentSwapping[self] or not on("skinTalents") or type(path) ~= "string" then return end
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

local talentSkinned = {}
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event)
    hookWindows()
    for _, prefix in ipairs({ "PlayerTalentFrame", "InspectTalentFrame" }) do
        if not talentSkinned[prefix] and _G[prefix .. "BackgroundTopLeft"] then
            talentSkinned[prefix] = true
            skinTalentFrame(prefix)
        end
    end
    if event == "PLAYER_LOGIN" then
        -- The warm window tint is gone: its old switch is dropped from the saved settings.
        settings().characterSkin = nil
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
    end
end)

ui.SkinExtras = { SkinButton = skinPanelButton, Windows = WINDOWS }
