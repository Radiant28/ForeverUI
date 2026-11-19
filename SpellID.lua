local _, ui = ...

-- Spell IDs: an "ID: 12345" line under the name in spell and aura tooltips, and spell drop into input boxes.
-- Settings (ui.Settings()): tooltipSpellId (bool, default on), tooltipSpellIdPlace "name"|"bottom".
--
-- Drop: ui.SpellID.Attach(editBox, { list = bool, items = bool, as = "id"|"name", commit = fn(box, text) }).
-- Dragging a spell (spellbook, action bar, macro, mount/pet) onto the box, clicking the box while a spell is on the
-- cursor, or Shift-clicking a spell while the box has focus puts the spell ID in (or the name with as = "name").
-- list = append with ", " instead of replacing; items = items become "item:ID" (otherwise they are ignored).

local SID = {}
ui.SpellID = SID

local function setting(key, fallback)
    local value = ui.Settings and ui.Settings()[key]
    if value == nil then return fallback end
    return value
end

local function linkSpell(link)
    return link and tonumber(tostring(link):match("spell:(%d+)"))
end
SID.LinkSpell = linkSpell

-- Spell ID of a name ("Fireball" or "Fireball(Rank 3)"); only spells the player knows give a link in 3.3.5.
local function nameSpell(name)
    if not name or name == "" or not GetSpellLink then return nil end
    return linkSpell(GetSpellLink(name))
end

---------------------------------------------------------------------------------------------------
-- What is on the cursor
---------------------------------------------------------------------------------------------------
-- Returns the spell ID (or "item:ID" when items are allowed) of what the cursor holds, plus the spell name.
function SID.CursorValue(items)
    if not GetCursorInfo then return nil end
    local kind, a, b, c = GetCursorInfo()
    if kind == "spell" then
        -- 3.3.5: "spell", book slot, book type; later clients add the spell ID as the 4th value.
        local id = tonumber(c)
        if not id and a and GetSpellLink then id = linkSpell(GetSpellLink(a, b or BOOKTYPE_SPELL or "spell")) end
        local name = id and GetSpellInfo and GetSpellInfo(id)
        if not name and a and GetSpellName then name = GetSpellName(a, b or BOOKTYPE_SPELL or "spell") end
        return id, name
    elseif kind == "macro" then
        local name = GetMacroSpell and GetMacroSpell(a)
        return nameSpell(name), name
    elseif kind == "companion" then
        if GetCompanionInfo then
            local _, name, id = GetCompanionInfo(b, a)
            return tonumber(id), name
        end
    elseif kind == "item" and items then
        local id = tonumber(a) or tonumber(tostring(b or ""):match("item:(%d+)"))
        if id then return "item:" .. id, GetItemInfo and GetItemInfo(id) end
    end
end

---------------------------------------------------------------------------------------------------
-- Input boxes
---------------------------------------------------------------------------------------------------
local attached = setmetatable({}, { __mode = "k" })

local function put(box, opts, id, name)
    local value
    if opts.as == "name" then value = name or (type(id) == "number" and GetSpellInfo and GetSpellInfo(id)) or id
    else value = id end
    if value == nil then return false end
    value = tostring(value)
    local text = value
    if opts.list then
        local current = (box:GetText() or ""):match("^%s*(.-)[%s,;]*$") or ""
        if current ~= "" then text = current .. ", " .. value end
    end
    box:SetText(text)
    if box.SetCursorPosition then box:SetCursorPosition(#text) end
    if opts.commit then opts.commit(box, text) end
    return true
end
SID.Put = put

local function dropCursor(box)
    local opts = attached[box]
    if not opts or (box.IsEnabled and not box:IsEnabled()) then return end
    local id, name = SID.CursorValue(opts.items)
    if id == nil and name == nil then return end
    if put(box, opts, id, name) and ClearCursor then ClearCursor() end
end
SID.Drop = dropCursor

function SID.Attach(box, opts)
    if not box or attached[box] then return box end
    attached[box] = opts or {}
    if box.EnableMouse then box:EnableMouse(true) end
    box:HookScript("OnReceiveDrag", dropCursor)
    box:HookScript("OnMouseDown", function(self)
        if GetCursorInfo and GetCursorInfo() then dropCursor(self) end
    end)
    return box
end

function SID.IsAttached(box) return attached[box] ~= nil end

-- Shift-click on a spell (spellbook, chat link) goes through ChatEdit_InsertLink; when one of our boxes has the
-- keyboard focus, the spell lands there.
local function insertLink(link)
    local box = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    local opts = box and attached[box]
    if not opts or not link then return end
    local id = linkSpell(link)
    local name = tostring(link):match("|h%[(.-)%]|h")
    if not id and opts.items then
        local item = tonumber(tostring(link):match("item:(%d+)"))
        if item then id = "item:" .. item end
    end
    if id then put(box, opts, id, name) end
end
SID.InsertLink = insertLink
if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", insertLink) end

---------------------------------------------------------------------------------------------------
-- Tooltips
---------------------------------------------------------------------------------------------------
local ID_COLOR = "|cff8f8f96"
SID.label = "ID: "

-- Rebuilds the tooltip with the ID as the second line. Lines cannot be inserted in 3.3.5, so every line is read
-- (texts and colours) and added again; single lines are re-added with wrapping so long descriptions stay wrapped.
local function readLines(tooltip)
    local prefix = tooltip:GetName()
    local lines = {}
    for i = 1, tooltip:NumLines() do
        local left, right = _G[prefix .. "TextLeft" .. i], _G[prefix .. "TextRight" .. i]
        local line = { text = left and left:GetText() }
        if left then line.r, line.g, line.b = left:GetTextColor() end
        if right and right:IsShown() and right:GetText() and right:GetText() ~= "" then
            line.right = right:GetText()
            line.rr, line.rg, line.rb = right:GetTextColor()
        end
        lines[i] = line
    end
    return lines
end

local function addId(tooltip, id)
    if not id or not setting("tooltipSpellId", true) then return end
    if tooltip.fuiSpellId == id then return end
    tooltip.fuiSpellId = id
    local text = ID_COLOR .. SID.label .. "|r|cffffffff" .. id .. "|r"
    local prefix = tooltip.GetName and tooltip:GetName()
    if setting("tooltipSpellIdPlace", "name") ~= "name" or not prefix or tooltip:NumLines() < 1 then
        tooltip:AddLine(text)
        tooltip:Show()
        return
    end
    local lines = readLines(tooltip)
    tooltip:ClearLines()
    tooltip.fuiSpellId = id -- ClearLines fires OnTooltipCleared
    for i, line in ipairs(lines) do
        if line.right then
            tooltip:AddDoubleLine(line.text or " ", line.right, line.r, line.g, line.b, line.rr, line.rg, line.rb)
        else
            tooltip:AddLine(line.text or " ", line.r, line.g, line.b, i > 1)
        end
        if i == 1 then tooltip:AddLine(text) end
    end
    tooltip:Show()
end
SID.AddToTooltip = addId

local function onSpell(tooltip)
    local name, rank, id = tooltip:GetSpell()
    id = tonumber(id)
    if not id and name then
        id = nameSpell(rank and rank ~= "" and (name .. "(" .. rank .. ")") or name) or nameSpell(name)
    end
    addId(tooltip, id)
end

local function hookTooltip(tooltip)
    if not tooltip or tooltip.fuiSpellIdHooked then return end
    tooltip.fuiSpellIdHooked = true
    tooltip:HookScript("OnTooltipSetSpell", onSpell)
    tooltip:HookScript("OnTooltipCleared", function(self) self.fuiSpellId = nil end)
    if tooltip.SetUnitAura then
        hooksecurefunc(tooltip, "SetUnitAura", function(self, unit, index, filter)
            addId(self, tonumber((select(11, UnitAura(unit, index, filter)))))
        end)
    end
    if tooltip.SetUnitBuff then
        hooksecurefunc(tooltip, "SetUnitBuff", function(self, unit, index, filter)
            addId(self, tonumber((select(11, UnitBuff(unit, index, filter)))))
        end)
    end
    if tooltip.SetUnitDebuff then
        hooksecurefunc(tooltip, "SetUnitDebuff", function(self, unit, index, filter)
            addId(self, tonumber((select(11, UnitDebuff(unit, index, filter)))))
        end)
    end
end
SID.HookTooltip = hookTooltip

hookTooltip(GameTooltip)
hookTooltip(ItemRefTooltip)

-- Options page hook: nothing to re-apply, tooltips read the settings each time.
function SID.Apply() end
