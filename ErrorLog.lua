local addonName, ui = ...

-- Lua error log with call stacks. The client's error window shows only the message ("ItemButtonTemplate.lua:63:
-- attempt to index field '?'"), not who called the failing function. Every error that reaches the error handler is
-- kept here with debugstack() in ForeverStockUIDB.errorLog (WTF\Account\<account>\SavedVariables\ForeverUI.lua)
-- and printed by /fuierrors. The previous handler is always called, so the client's window keeps working.

local MAX_ENTRIES = 30
local MAX_STACK = 3000

local pending = {}          -- errors raised before the saved variables are loaded
local log                   -- ForeverStockUIDB.errorLog once loaded
local previous              -- the handler we chain to
local handler               -- our handler
local announced = false

-- ui.L comes from Core/Config.lua, which loads after this file; texts are only built when printed.
local function L(russian, english)
    if ui.L then return ui.L(russian, english) end
    return russian
end

local function now()
    return date and date("%Y-%m-%d %H:%M:%S") or "?"
end

local function insert(list, message, stack, time)
    for _, entry in ipairs(list) do
        if entry.message == message then
            entry.count = (entry.count or 1) + 1
            entry.last = time
            entry.stack = stack
            return
        end
    end
    table.insert(list, 1, { message = message, stack = stack, count = 1, first = time, last = time })
    while #list > MAX_ENTRIES do table.remove(list) end
end

local function record(message)
    message = tostring(message)
    local stack = debugstack and debugstack(3, 20, 10) or ""
    if #stack > MAX_STACK then stack = stack:sub(1, MAX_STACK) end
    insert(log or pending, message, stack, now())
    if log and not announced and DEFAULT_CHAT_FRAME then
        announced = true
        DEFAULT_CHAT_FRAME:AddMessage(L("ForeverUI: Lua-ошибка записана вместе со стеком вызовов — /fuierrors",
            "ForeverUI: a Lua error was saved with its call stack — /fuierrors"))
    end
end

local function install()
    if not (geterrorhandler and seterrorhandler) then return end
    local current = geterrorhandler()
    if current == handler then return end
    previous = current
    handler = function(message, ...)
        pcall(record, message)
        if previous then return previous(message, ...) end
    end
    seterrorhandler(handler)
end

local function loadLog()
    if type(ForeverStockUIDB) ~= "table" then ForeverStockUIDB = {} end
    if type(ForeverStockUIDB.errorLog) ~= "table" then ForeverStockUIDB.errorLog = {} end
    log = ForeverStockUIDB.errorLog
    for i = #pending, 1, -1 do
        local entry = pending[i]
        for _ = 1, entry.count do insert(log, entry.message, entry.stack, entry.last) end
    end
    pending = {}
end

local function show(count)
    local list = log or pending
    local out = DEFAULT_CHAT_FRAME
    if #list == 0 then
        out:AddMessage(L("ForeverUI: записанных Lua-ошибок нет.", "ForeverUI: no Lua errors saved."))
        return
    end
    out:AddMessage(string.format(L("ForeverUI: Lua-ошибок записано: %d (новые сверху). Полный стек — в WTF\\Account\\<аккаунт>\\SavedVariables\\ForeverUI.lua, errorLog.",
        "ForeverUI: %d Lua errors saved (newest first). Full stacks: WTF\\Account\\<account>\\SavedVariables\\ForeverUI.lua, errorLog."), #list))
    for i = 1, math.min(count, #list) do
        local entry = list[i]
        out:AddMessage(string.format("|cffff4444%d.|r %s |cff999999(x%d, %s)|r", i, entry.message, entry.count or 1, entry.last or "?"))
        local shown = 0
        for line in (entry.stack or ""):gmatch("[^\n]+") do
            out:AddMessage("    |cffaaaaaa" .. line .. "|r")
            shown = shown + 1
            if shown >= 8 then break end
        end
    end
end

install()

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == addonName then loadLog() end
    -- An addon loaded later (Blizzard_DebugTools, for one) may set its own handler: wrap it again.
    install()
end)

SLASH_FUIERRORS1 = "/fuierrors"
SlashCmdList.FUIERRORS = function(arg)
    arg = (arg or ""):lower():match("^%s*(.-)%s*$")
    if arg == "clear" then
        if log then for i = #log, 1, -1 do log[i] = nil end end
        pending = {}
        DEFAULT_CHAT_FRAME:AddMessage(L("ForeverUI: журнал Lua-ошибок очищен.", "ForeverUI: Lua error log cleared."))
        return
    end
    show(tonumber(arg) or 3)
end

ui.ErrorLog = {
    Record = record,
    Entries = function() return log or pending end,
}
