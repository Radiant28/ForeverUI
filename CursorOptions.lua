-- Cursor settings live in the ForeverUI options window (Options\Cursor.lua); this file keeps the commands.
local _, ui = ...
local Cursor = ui.cursor

function Cursor.ToggleSettings()
    ui.ToggleOptions("cursor")
end

local function bindCommands()
    SLASH_CURSORUZ1 = "/cursoruz"
    SLASH_CURSORUZ2 = "/midcursor"
    SlashCmdList.CURSORUZ = Cursor.ToggleSettings
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, addon)
    if event == "ADDON_LOADED" then
        if addon == "CursorUZ" then bindCommands() end
        return
    end
    self:UnregisterEvent(event)
    bindCommands()
end)
