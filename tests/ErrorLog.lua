-- ErrorLog.lua on mocks: chained handler, stacks, errors before the saved variables, re-wrap, dedupe, cap, /fuierrors.
local failures = 0
local function check(ok, label)
    if not ok then failures = failures + 1; print("FAIL " .. label) end
end

local chat = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) chat[#chat + 1] = text end }
SlashCmdList = {}
ForeverStockUIDB = nil
function date() return "2026-11-23 20:00:00" end
local stackNo = 0
function debugstack() stackNo = stackNo + 1; return "Interface\\FrameXML\\Caller.lua:10: in function <x>\nline2\nstack" .. stackNo end

local clientSeen = {}
local current = function(message) clientSeen[#clientSeen + 1] = message end
function geterrorhandler() return current end
function seterrorhandler(fn) current = fn end

local onEvent
function CreateFrame()
    return { RegisterEvent = function() end, SetScript = function(_, _, fn) onEvent = fn end }
end

local ui = {}
assert(loadfile("ErrorLog.lua"))("ForeverUI", ui)

-- An error before ADDON_LOADED: kept in memory, client handler still called.
geterrorhandler()("early error")
check(clientSeen[1] == "early error", "client handler gets the early error")
check(#ui.ErrorLog.Entries() == 1, "early error pending")
check(#chat == 0, "no chat line before the log is loaded")

-- Saved variables arrive: an old log plus the pending error.
ForeverStockUIDB = { errorLog = { { message = "old", stack = "s", count = 1, last = "x" } } }
onEvent(nil, "ADDON_LOADED", "ForeverUI")
local log = ForeverStockUIDB.errorLog
check(#log == 2 and log[1].message == "early error" and log[2].message == "old", "pending merged on top")
check(ui.ErrorLog.Entries() == log, "entries are the saved log")

-- The interesting error: stack saved, chat hint once.
geterrorhandler()("Interface\\FrameXML\\ItemButtonTemplate.lua:63: attempt to index field '?' (a nil value)")
check(log[1].stack:find("Caller.lua:10", 1, true) ~= nil, "stack saved")
check(#chat == 1 and chat[1]:find("/fuierrors", 1, true), "chat hint shown")
geterrorhandler()("Interface\\FrameXML\\ItemButtonTemplate.lua:63: attempt to index field '?' (a nil value)")
check(log[1].count == 2 and #log == 3, "same message counted, not duplicated")
check(#chat == 1, "chat hint only once per session")
check(#clientSeen == 3, "client handler called every time")

-- Another addon sets its own handler later: wrapped again on the next event, chain kept.
local otherSeen = 0
seterrorhandler(function() otherSeen = otherSeen + 1 end)
onEvent(nil, "ADDON_LOADED", "Blizzard_DebugTools")
geterrorhandler()("after debugtools")
check(otherSeen == 1 and log[1].message == "after debugtools", "re-wrapped over a later handler")
onEvent(nil, "PLAYER_LOGIN")
geterrorhandler()("after debugtools")
check(otherSeen == 2 and log[1].count == 2, "no double wrap")

-- A broken record never stops the chain.
local saved = debugstack
debugstack = function() error("boom") end
geterrorhandler()("stack fails")
check(otherSeen == 3, "chain survives a failing record")
debugstack = saved

-- Cap.
for i = 1, 40 do geterrorhandler()("spam " .. i) end
check(#log == 30 and log[1].message == "spam 40", "log capped at 30, newest first")

-- /fuierrors prints, clear empties.
chat = {}
SlashCmdList.FUIERRORS("2")
check(#chat > 3 and chat[2]:find("spam 40", 1, true), "/fuierrors prints the newest")
SlashCmdList.FUIERRORS("clear")
check(#log == 0, "/fuierrors clear")

if failures > 0 then error(failures .. " ErrorLog checks failed") end
print("ErrorLog: all checks passed")
