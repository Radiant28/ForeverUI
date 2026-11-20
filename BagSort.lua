local _, ui = ...
-- Bag and bank sorting (BankStack-style): scanner, item data cache, move executor, buttons and /fuisort.
-- The planning itself (stacks, profession bags, permutation cycles) is pure and lives in BagSortPlan.lua.
--
-- A run is a converge loop: scan → plan (stack moves first; when there are none, sort moves) → execute the queue
-- move by move on OnUpdate → when the queue is done and every touched slot is unlocked, scan and plan again.
-- It ends when a fresh plan has no moves. Any surprise (slot content differs from the plan, lock timeout) just
-- drops the queue and replans from a new scan, so a client/server desync never breaks the sort.

local L = ui.L
local P = ui.BagSortPlan
local B = {}
ui.BagSort = B

local TICK = 0.05          -- seconds between executor steps
local LOCK_TIMEOUT = 2.5   -- a moved slot that stays locked longer drops the queue (replan)
local LOCK_WAIT = 1.5      -- before planning, wait this long for slots that are still locked by the server
local CURSOR_WAIT = 10     -- the player holds an item on the cursor: wait, then give up
local MAX_PASSES = 40      -- plans per run (stack + sort + check normally take 3; replans after lag add more)
local MAX_WASTED = 4       -- plans in a row after which nothing moved: give up
local SETTLE = 0.6         -- unlocked slot without the expected contents: server answer still on its way
local REFRESH_GAP = 0.3    -- bag window refresh while moving
-- The guild bank answers slower and drops moves sent too fast: one move at a time and longer waits.
local GUILD_LOCK_TIMEOUT, GUILD_SETTLE = 5, 2.5
-- Nozdor also throttles guild bank moves (seen in game: a move sent right after the last one landed is dropped
-- now and then). Pause between moves; every refusal doubles the pause and retries the move; an item is left in
-- place only after GUILD_RETRIES refusals. A run may take more passes there.
local GUILD_GAP, GUILD_GAP_MAX, GUILD_RETRIES, GUILD_MAX_PASSES = 0.4, 4, 3, 200
-- Guild bank slots in the state: bag = GUILD_BASE + tab (only the tab that is open in the guild bank window).
local GUILD_BASE = 1000
B.GUILD_BASE = GUILD_BASE

local function setting(key, fallback)
    local db = ui.Settings and ui.Settings()
    local value = db and db[key]
    if value == nil then return fallback end
    return value
end

------------------------------------------------------------------------------------------------------------------
-- Item data (static per itemID; partial answers are not cached and get retried on the next plan).

local CLASS_ORDER = {
    { "Weapon", "Оружие" },
    { "Armor", "Доспехи", "Броня" },
    { "Container", "Сумки", "Контейнеры", "Контейнер" },
    { "Consumable", "Расходуемые", "Расходуемое" },
    { "Glyph", "Символы", "Символ" },
    { "Trade Goods", "Хозяйственные товары", "Ремесленные товары", "Материалы" },
    { "Projectile", "Боеприпасы", "Снаряды" },
    { "Quiver", "Амуниция", "Колчаны", "Колчан" },
    { "Recipe", "Рецепты", "Рецепт" },
    { "Gem", "Самоцветы", "Самоцвет" },
    { "Reagent", "Реагенты", "Реагент" },
    { "Miscellaneous", "Разное" },
    { "Quest", "Задания", "Квестовые предметы", "Задание" },
    { "Key", "Ключи", "Ключ" },
}
local classRank = {}
for rank, names in ipairs(CLASS_ORDER) do
    for _, name in ipairs(names) do classRank[name] = rank end
end
local UNKNOWN_CLASS = #CLASS_ORDER + 1

-- Groups in the bag, in this order, one after another without gaps.
-- 1 equipment (and bags, quivers), 2 resources, 3 recipes and glyphs, 4 consumables and spell reagents,
-- 5 everything else, 6 quest items, 7 grey items (always last, equipment included).
local GROUP_CLASSES = {
    [1] = { "Weapon", "Оружие", "Armor", "Доспехи", "Броня", "Container", "Сумки", "Контейнеры", "Контейнер",
        "Quiver", "Амуниция", "Колчаны", "Колчан" },
    [2] = { "Trade Goods", "Хозяйственные товары", "Ремесленные товары", "Материалы", "Gem", "Самоцветы", "Самоцвет" },
    [3] = { "Recipe", "Рецепты", "Рецепт", "Glyph", "Символы", "Символ" },
    [4] = { "Consumable", "Расходуемые", "Расходуемое", "Reagent", "Реагенты", "Реагент" },
    [6] = { "Quest", "Задания", "Квестовые предметы", "Задание" },
}
local GROUP_OTHER, GROUP_JUNK = 5, 7
local groupOf = {}
for group, names in pairs(GROUP_CLASSES) do
    for _, name in ipairs(names) do groupOf[name] = group end
end
-- Item level order by group (BagSortPlan `level`): resources by tier inside the block, consumables by tier
-- inside their subclass; highest item level first, then quality.
local LEVEL_ORDER = { [2] = 1, [4] = 2 }
local GEM_CLASS = { Gem = true, ["Самоцветы"] = true, ["Самоцвет"] = true }

-- Resource blocks by trade goods subclass (enUS / ruRU); ore and bars share one subclass, so one block.
local RESOURCE_BLOCKS = {
    { "Metal & Stone", "Металл и камень", "Металлы и камни" },
    { "Herb", "Трава", "Травы" },
    { "Cloth", "Ткань", "Ткани" },
    { "Leather", "Кожа" },
    { "Enchanting", "Наложение чар", "Зачаровывание", "Armor Enchantment", "Weapon Enchantment",
        "Чары для доспехов", "Чары для оружия" },
    { "Elemental", "Стихии", "Стихийные" },
    { "Jewelcrafting", "Ювелирное дело" }, -- and every item of the gem class
    { "Meat", "Мясо" },
    { "Parts", "Детали", "Devices", "Устройства", "Explosives", "Взрывчатка", "Взрывчатые вещества" },
}
local GEM_BLOCK, OTHER_BLOCK = 7, #RESOURCE_BLOCKS + 1
local blockOf = {}
for block, names in ipairs(RESOURCE_BLOCKS) do
    for _, name in ipairs(names) do blockOf[name] = block end
end

local EQUIP_ORDER = { "INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_CLOAK", "INVTYPE_CHEST",
    "INVTYPE_ROBE", "INVTYPE_BODY", "INVTYPE_TABARD", "INVTYPE_WRIST", "INVTYPE_HAND", "INVTYPE_WAIST",
    "INVTYPE_LEGS", "INVTYPE_FEET", "INVTYPE_FINGER", "INVTYPE_TRINKET", "INVTYPE_2HWEAPON", "INVTYPE_WEAPON",
    "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND", "INVTYPE_SHIELD", "INVTYPE_HOLDABLE", "INVTYPE_RANGED",
    "INVTYPE_RANGEDRIGHT", "INVTYPE_THROWN", "INVTYPE_RELIC", "INVTYPE_AMMO", "INVTYPE_BAG", "INVTYPE_QUIVER" }
local equipRank = {}
for rank, name in ipairs(EQUIP_ORDER) do equipRank[name] = rank end

-- Always first, in this order: Hearthstone.
local PINNED = { [6948] = 1 }
B.pinned = PINNED

------------------------------------------------------------------------------------------------------------------
-- Server crafting bags. Nozdor has bags (e.g. «Сумка ремесленника вечности») that the client reports as ordinary
-- (family 0) while the server only takes some items in them. Such a bag gets a synthetic family bit (from
-- P.CUSTOM, above every real family) and a rule learned per bag item ID and saved in `bagSortCustomBags`:
-- accept[class] from what lies in the bag, deny[class] / denyItems[id] from refusals. Items of an accepted class
-- carry the bit, so the planner fills the bag first like a profession bag (after the real profession bags).

local TRADE_GOODS = { ["Trade Goods"] = true, ["Хозяйственные товары"] = true, ["Ремесленные товары"] = true,
    ["Материалы"] = true }
local CRAFT_NAMES = { "ремесленник", "реагент", "crafter", "crafting", "reagent" }
local customBit, customBits = {}, 0
local bagRule, bagItemOf = {}, {}
local cache = {}

local function customRules()
    local db = ui.Settings and ui.Settings()
    if not db then return {} end
    if type(db.bagSortCustomBags) ~= "table" then db.bagSortCustomBags = {} end
    return db.bagSortCustomBags
end

local function rulesChanged()
    for k in pairs(cache) do cache[k] = nil end
end

local function bitFor(bagItem)
    local value = customBit[bagItem]
    if not value then
        if customBits >= 12 then return nil end
        value = P.CUSTOM * 2 ^ customBits
        customBits = customBits + 1
        customBit[bagItem] = value
        rulesChanged()
    end
    return value
end

local function customFamily(id, class)
    local bits = 0
    for bagItem, rule in pairs(customRules()) do
        local value = customBit[bagItem]
        if value and class and rule.accept and rule.accept[class]
            and not (rule.denyItems and rule.denyItems[id]) then
            bits = bits + value
        end
    end
    return bits
end

local function itemInfo(id)
    local r = cache[id]
    if r then return r end
    local name, _, quality, ilvl, _, class, subclass, maxStack, equipLoc = GetItemInfo(id)
    local family = GetItemFamily and GetItemFamily(id) or 0
    local isBag = equipLoc == "INVTYPE_BAG" or equipLoc == "INVTYPE_QUIVER"
    if family and not isBag then family = family + customFamily(id, class) end
    local group, block = class and groupOf[class] or GROUP_OTHER, 0
    if PINNED[id] then
        group = 1 -- the hearthstone opens the equipment row
    elseif quality == 0 then
        group = GROUP_JUNK
    elseif group == 2 then
        block = GEM_CLASS[class] and GEM_BLOCK or blockOf[subclass or ""] or OTHER_BLOCK
    end
    r = {
        class = class,
        family = family or 0,
        maxStack = maxStack or 1,
        isBag = isBag,
        pin = PINNED[id] or 999,
        junk = quality == 0,
        group = group,
        block = block,
        level = LEVEL_ORDER[group],
        classRank = class and classRank[class] or UNKNOWN_CLASS,
        subclass = subclass or "",
        equipRank = equipRank[equipLoc or ""] or 99,
        quality = quality or 1,
        ilvl = ilvl or 0,
        name = name or "",
    }
    if name and family then cache[id] = r end
    return r
end
B.ItemInfo = itemInfo

------------------------------------------------------------------------------------------------------------------
-- Scanner.

local S = P.NewState()
local Q = P.NewQueue()
local keyOf, keyCount = {}, 0

local function bagGroups()
    local list = {}
    for bag = 0, NUM_BAG_SLOTS or 4 do list[#list + 1] = bag end
    return list
end
local function bankGroups()
    local list = { BANK_CONTAINER or -1 }
    local first = (NUM_BAG_SLOTS or 4) + 1
    for bag = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do list[#list + 1] = bag end
    return list
end
local CONTAINERS = { bagGroups(), bankGroups() }
local guildOpen = false

local function guildTab()
    return GetCurrentGuildBankTab and GetCurrentGuildBankTab() or 1
end

-- Item string without the unique id and the level: equal keys are interchangeable copies.
local function itemKey(link)
    local key = keyOf[link]
    if key then return key end
    key = link:match("item:([%-%d]+:[%-%d]*:[%-%d]*:[%-%d]*:[%-%d]*:[%-%d]*:[%-%d]*)") or link:match("item:([%-%d]+)")
    if keyCount > 4000 then
        for k in pairs(keyOf) do keyOf[k] = nil end
        keyCount = 0
    end
    keyOf[link] = key
    keyCount = keyCount + 1
    return key
end

local function linkAt(bag, slot)
    if bag > GUILD_BASE then return GetGuildBankItemLink(bag - GUILD_BASE, slot) end
    return GetContainerItemLink(bag, slot)
end

local function readSlot(bag, slot)
    if bag > GUILD_BASE then
        local _, count, locked = GetGuildBankItemInfo(bag - GUILD_BASE, slot)
        local link = GetGuildBankItemLink(bag - GUILD_BASE, slot)
        local id = link and tonumber(link:match("item:(%-?%d+)"))
        return id, id and (count or 1) or 0, locked, link
    end
    local _, count, locked = GetContainerItemInfo(bag, slot)
    local link = GetContainerItemLink(bag, slot)
    local id = link and tonumber(link:match("item:(%-?%d+)"))
    if not id and count and GetContainerItemID then id = GetContainerItemID(bag, slot) end
    return id, id and (count or 1) or 0, locked, link
end

-- Item ID and name of the bag in container `bag` (nil for the backpack and the main bank).
local function pickup(bag, slot)
    if bag > GUILD_BASE then return PickupGuildBankItem(bag - GUILD_BASE, slot) end
    PickupContainerItem(bag, slot)
end

local function bagItem(bag)
    if bag <= 0 or bag > GUILD_BASE or not ContainerIDToInventoryID or not GetInventoryItemLink then return end
    local link = GetInventoryItemLink("player", ContainerIDToInventoryID(bag))
    if not link then return end
    return tonumber(link:match("item:(%d+)")), link:match("%[(.-)%]") or "", link
end

local function looksCrafting(name)
    name = (name or ""):lower()
    for _, word in ipairs(CRAFT_NAMES) do
        if name:find(word, 1, true) then return true end
    end
end

-- The rule of an ordinary-looking bag (nil when it is a plain bag). `create` makes one (after a refusal).
local function ruleFor(bag, family, create)
    if family ~= 0 or bag <= 0 then return end
    local id, name = bagItem(bag)
    if not id then return end
    local rules = customRules()
    local rule = rules[id]
    if not rule and (create or looksCrafting(name)) then
        rule = { name = name, accept = {}, deny = {}, denyItems = {} }
        if not create then
            for class in pairs(TRADE_GOODS) do rule.accept[class] = true end
        end
        rules[id] = rule
        rulesChanged()
    end
    return rule, id
end

-- An item lies in a crafting bag: its class is accepted there.
local function learnContent(rule, id)
    local class = itemInfo(id).class
    if class and not rule.accept[class] then
        rule.accept[class] = true
        rule.deny[class] = nil
        rulesChanged()
    end
end

-- The server refused item `id` in container `bag`. Returns true when this taught a rule (no need to freeze).
local function learnRefusal(bag, id)
    if not id or bag > GUILD_BASE then return false end
    local family = select(2, GetContainerNumFreeSlots(bag)) or 0
    local rule = ruleFor(bag, family, true)
    if not rule then return false end
    local class = itemInfo(id).class
    if class and rule.accept[class] then
        if rule.denyItems[id] then return false end
        rule.denyItems[id] = true
    elseif class then
        if rule.deny[class] then return false end
        rule.deny[class] = true
    else
        return false
    end
    rulesChanged()
    return true
end
B.CustomRules = customRules

-- One guild bank tab (group 3): every slot is ordinary (family 0), no crafting bag rules.
local function scanGuild(n, tab, frozen)
    local locked = 0
    local bag = GUILD_BASE + tab
    for slot = 1, MAX_GUILDBANK_SLOTS_PER_TAB or 98 do
        n = n + 1
        local id, count, isLocked, link = readSlot(bag, slot)
        S.bag[n], S.slot[n], S.group[n], S.family[n] = bag, slot, 3, 0
        S.id[n], S.count[n], S.key[n] = id, count, link and itemKey(link) or (id and tostring(id))
        S.fixed[n] = (isLocked or (frozen and S.key[n] and frozen[S.key[n]])) and true or false
        if isLocked then locked = locked + 1 end
    end
    return n, locked
end

-- groupA / groupB: 1 bags, 2 bank, 3 the open guild bank tab. Returns the number of locked slots.
local function scan(groupA, groupB, frozen, tab)
    local n, locked = 0, 0
    if groupA == 3 or groupB == 3 then
        n, locked = scanGuild(n, tab or guildTab(), frozen)
    end
    for g = 1, 2 do
        if g == groupA or g == groupB then
            for _, bag in ipairs(CONTAINERS[g]) do
                local size = GetContainerNumSlots(bag) or 0
                if size > 0 then
                    local _, family = GetContainerNumFreeSlots(bag)
                    family = family or 0
                    local rule, ruleItem = ruleFor(bag, family)
                    bagRule[bag], bagItemOf[bag] = rule, ruleItem
                    if rule then family = bitFor(ruleItem) or 0 end
                    for slot = 1, size do
                        n = n + 1
                        local id, count, isLocked, link = readSlot(bag, slot)
                        S.bag[n], S.slot[n], S.group[n], S.family[n] = bag, slot, g, family                        S.id[n], S.count[n], S.key[n] = id, count, link and itemKey(link) or (id and tostring(id))
                        S.fixed[n] = (isLocked or (frozen and S.key[n] and frozen[S.key[n]])) and true or false
                        if isLocked then locked = locked + 1 end
                        if rule and id then learnContent(rule, id) end
                    end
                end
            end
        end
    end
    for i = n + 1, S.n do S.id[i], S.key[i] = nil, nil end
    S.n = n
    return locked
end
B.Scan = function(groupA, groupB, tab) scan(groupA, groupB, nil, tab) return S end
B.State = S

------------------------------------------------------------------------------------------------------------------
-- Executor.

local MODES = {
    bags = { groups = { 1 }, sort = 1 },
    bank = { groups = { 2 }, sort = 2, bank = true },
    deposit = { groups = { 1, 2 }, bank = true, transfer = "deposit" },
    withdraw = { groups = { 1, 2 }, bank = true, transfer = "withdraw" },
    guild = { groups = { 3 }, sort = 3, guild = true },
    guilddeposit = { groups = { 1, 3 }, guild = true, transfer = "deposit" },
    guildwithdraw = { groups = { 1, 3 }, guild = true, transfer = "withdraw" },
}
B.modes = MODES

local run
local driver = CreateFrame("Frame")
driver:Hide()
local events = CreateFrame("Frame")
local bankOpen = false
local watchers = {}
local elapsedSum = 0

local function notify()
    for button, mode in pairs(watchers) do
        if button.SortProgress then button:SortProgress(run and run.mode == mode and run or nil) end
    end
end

local function progress()
    if not run then return 0 end
    local remaining = Q.n - run.pos + 1
    if remaining < 0 then remaining = 0 end
    local total = run.done + remaining
    local pct = total > 0 and math.floor(run.done * 100 / total) or 0
    if pct < run.shown then pct = run.shown end
    run.shown = pct
    return pct
end
B.Progress = progress

local function refreshBags()
    if ui.Bags and ui.Bags.Refresh then ui.Bags.Refresh() end
end

local MESSAGES = {
    bags = { L("Сумки отсортированы", "Bags sorted"), L("Сумки уже в порядке", "Bags are already in order") },
    bank = { L("Банк отсортирован", "Bank sorted"), L("Банк уже в порядке", "Bank is already in order") },
    deposit = { L("Предметы сложены в банк", "Items stacked into the bank"),
        L("Нечего складывать в банк", "Nothing to stack into the bank") },
    withdraw = { L("Стопки в сумках пополнены из банка", "Bag stacks topped up from the bank"),
        L("Нечего брать из банка", "Nothing to take from the bank") },
    guild = { L("Вкладка банка гильдии отсортирована", "Guild bank tab sorted"),
        L("Вкладка банка гильдии уже в порядке", "The guild bank tab is already in order") },
    guilddeposit = { L("Предметы сложены в банк гильдии", "Items stacked into the guild bank"),
        L("Нечего складывать в банк гильдии", "Nothing to stack into the guild bank") },
    guildwithdraw = { L("Стопки в сумках пополнены из банка гильдии", "Bag stacks topped up from the guild bank"),
        L("Нечего брать из банка гильдии", "Nothing to take from the guild bank") },
}

local function finish(reason)
    local r = run
    if not r then return end
    run = nil
    driver:Hide()
    refreshBags()
    notify()
    local text
    if reason == "done" then
        if setting("bagSortMessages", true) then
            local pair = MESSAGES[r.mode]
            text = r.done > 0 and (pair[1] .. L(": %d перемещ. за %.1f с.", ": %d moves in %.1f s."))
                :format(r.done, GetTime() - r.started) or (pair[2] .. ".")
        end
        if r.refused > 0 then
            text = (text and text .. " " or "") .. L("Сервер не принял %d перемещ. — эти предметы оставлены на месте "
                .. "(подробности: /fuisort debug и сортировка ещё раз).", "The server refused %d move(s); those items "
                .. "were left in place (details: /fuisort debug, then sort again)."):format(r.refused)
        end
        if r.failures > 0 then
            text = (text and text .. " " or "") .. L("Не удалось разместить: %d (нет свободной подходящей ячейки).",
                "Could not place: %d (no free slot that fits).")
                :format(r.failures)
        end
        if r.limited then
            text = (text and text .. " " or "") .. L("Дневной лимит снятия с этой вкладки исчерпан.",
                "The daily withdrawal limit of this tab is used up.")
        end
    elseif reason == "stopped" then
        text = L("Сортировка остановлена.", "Sorting stopped.")
    elseif reason == "bank" then
        text = L("Банк закрыт — сортировка остановлена.", "The bank was closed: sorting stopped.")
    elseif reason == "guild" then
        text = L("Банк гильдии закрыт — сортировка остановлена.", "The guild bank was closed: sorting stopped.")
    elseif reason == "tab" then
        text = L("Открыта другая вкладка банка гильдии — сортировка остановлена.",
            "Another guild bank tab was opened: sorting stopped.")
    elseif reason == "cursor" then
        text = L("На курсоре предмет — сортировка остановлена.", "An item is on the cursor: sorting stopped.")
    elseif reason == "passes" then
        text = L("Сортировка не завершилась: %d перемещ., %d проходов, рассинхронов %d, тайм-аутов %d, отказов %d. "
            .. "Подробности: /fuisort debug и сортировка ещё раз.", "Sorting did not settle: %d moves, %d passes, "
            .. "%d desyncs, %d timeouts, %d refusals. Details: /fuisort debug, then sort again.")
            :format(r.done, r.pass, r.desync, r.timeouts, r.refused)
    end
    if text and ui.Print then ui.Print(text) end
end

local function debugPrint(...)
    if B.debug and ui.Print then ui.Print("|cff88ccff[sort]|r " .. string.format(...)) end
end

local function bagText(bag)
    if bag > GUILD_BASE then return ("guild bank tab %d"):format(bag - GUILD_BASE) end
    local _, family = GetContainerNumFreeSlots(bag)
    local link = bag > 0 and ContainerIDToInventoryID and GetInventoryItemLink
        and GetInventoryItemLink("player", ContainerIDToInventoryID(bag))
    return ("%d %s (family %d)"):format(bag, link or "", family or 0)
end

local sortOptions = {}
-- noSwap: the guild bank tab (its server never swaps two occupied slots, seen in game).
function B.SortOptions(noSwap)
    sortOptions.reverse = setting("bagSortReverse", false)
    sortOptions.noSwap = noSwap or nil
    return sortOptions
end

local function plan(now)
    local mode = MODES[run.mode]
    local locked = scan(mode.groups[1], mode.groups[2], run.frozen, run.tab)
    if locked > 0 then
        run.lockSince = run.lockSince or now
        if now - run.lockSince < LOCK_WAIT then return end -- the server has not released our last moves yet
    end
    run.lockSince = nil
    run.pass = run.pass + 1
    -- A plan after a pass that moved nothing is wasted; a few of those in a row and the run gives up.
    if run.pass > 1 and run.doneAtPlan == run.done and run.learnedAtPlan == run.learned then
        run.wasted = run.wasted + 1
    else
        run.wasted = 0
    end
    run.doneAtPlan, run.learnedAtPlan = run.done, run.learned
    if run.wasted >= MAX_WASTED or run.pass > run.maxPasses then return finish("passes") end
    P.ResetQueue(Q)
    run.pos = 1
    local failures = 0
    if mode.sort then
        P.StackMoves(S, mode.sort, itemInfo, Q)
        if Q.n > 0 then
            run.phase = "stack"
        else
            run.phase = "sort"
            failures = P.SortMoves(S, mode.sort, itemInfo, B.SortOptions(mode.guild), Q)
        end
    elseif mode.transfer == "deposit" then
        run.phase = "deposit"
        failures = P.DepositMoves(S, itemInfo, Q, mode.guild and 3 or 2)
    else
        run.phase = "withdraw"
        local bank = mode.guild and 3 or 2
        if run.withdrawLeft then
            -- Without the limit first: more moves than the limit allows means the limit cut the plan.
            P.WithdrawMoves(S, itemInfo, Q, bank)
            run.limited = Q.n > run.withdrawLeft
            P.ResetQueue(Q)
        end
        failures = P.WithdrawMoves(S, itemInfo, Q, bank, run.withdrawLeft)
    end
    run.failures = failures
    debugPrint("pass %d (%s): %d moves, %d unplaceable", run.pass, run.phase, Q.n, failures)
    if Q.n == 0 then finish("done") end
end

local function dropQueue(why)
    if run.pos <= Q.n then debugPrint("replan: %s", why) end
    run.pos = Q.n + 1
end

-- Contents of src and dst after move k, as the client shows them once the server applied it (false = empty).
local function after(k)
    local sid, sc, did, dc = Q.sid[k], Q.scount[k], Q.did[k], Q.dcount[k]
    if not did then return false, 0, sid, sc end
    local max = itemInfo(sid).maxStack
    if did == sid and max > 1 and dc < max then
        local moved = math.min(max - dc, sc)
        local rest = sc - moved
        return rest > 0 and sid or false, rest, sid, dc + moved
    end
    return did, dc, sid, sc
end

-- The client or the server refused move k: both items stay where they are for the rest of the run.
local function refuse(k, why)
    local s, d = Q.src[k], Q.dst[k]
    local id = run.pass * 100000 + k -- both slots of one move report it: count it once
    if run.lastRefused == id then return end
    run.lastRefused = id
    -- A crafting bag that said no teaches its rule; the next plan keeps such items out of it.
    if learnRefusal(S.bag[d], Q.sid[k]) or (Q.did[k] and learnRefusal(S.bag[s], Q.did[k])) then
        run.learned = run.learned + 1
        run.wasted = 0
        debugPrint("%s: %s -> %s (learned)", why, linkAt(S.bag[s], S.slot[s]) or tostring(Q.sid[k]),
            bagText(S.bag[d]))
        return dropQueue(why)
    end
    -- Guild bank: a refusal is usually the server's throttle. Slow down and try again before giving up.
    if MODES[run.mode].guild then
        run.gap = math.min(run.gap * 2, GUILD_GAP_MAX)
        local key = S.key[s] or tostring(Q.sid[k])
        local tries = (run.retries[key] or 0) + 1
        run.retries[key] = tries
        if tries < GUILD_RETRIES then
            run.retried = run.retried + 1
            -- The dropped move did not use a withdrawal: give it back for the retry.
            if run.withdrawLeft and S.group[s] == 3 and S.group[d] ~= 3 then run.withdrawLeft = run.withdrawLeft + 1 end
            run.landed = GetTime()
            debugPrint("%s: %s -> %s (retry %d, pause %.1f s)", why, linkAt(S.bag[s], S.slot[s]) or tostring(Q.sid[k]),
                bagText(S.bag[d]), tries, run.gap)
            return dropQueue(why)
        end
    end
    run.refused = run.refused + 1
    if S.key[s] then run.frozen[S.key[s]] = true end
    if S.key[d] then run.frozen[S.key[d]] = true end
    local link = linkAt(S.bag[s], S.slot[s]) or tostring(Q.sid[k])
    debugPrint("%s: %s -> %s", why, link, bagText(S.bag[d]))
    if Q.did[k] then
        debugPrint("   swap with %s -> %s", linkAt(S.bag[d], S.slot[d]) or tostring(Q.did[k]),
            bagText(S.bag[s]))
    end
    dropQueue(why)
end

local function slotIs(i, id, count)
    local actualId, actualCount = readSlot(S.bag[i], S.slot[i])
    if not id then return actualId == nil end
    return actualId == id and actualCount == count
end

-- A moved slot is done when it is unlocked and shows the contents the move should give. The unlock can come
-- before the new contents, and an empty destination is never locked, so the contents decide.
local function pendingClear(now)
    local busy = false
    local pending = run.pending
    for i, issued in pairs(pending) do
        local id, count, locked = readSlot(S.bag[i], S.slot[i])
        id = id or false
        if not locked and id == run.wantId[i] and (not id or count == run.wantCount[i]) then
            pending[i] = nil
            run.landed = now
        elseif now - issued > run.lockTimeout then
            pending[i] = nil
            run.timeouts = run.timeouts + 1
            dropQueue("timeout")
        elseif not locked and now - issued > run.settle then
            pending[i] = nil
            if id == run.oldId[i] and (not id or count == run.oldCount[i]) then
                refuse(run.moveOf[i], "server refused") -- nothing changed: the server said no
            else
                run.desync = run.desync + 1
                dropQueue("unexpected contents")
            end
        else
            busy = true
        end
    end
    return busy
end

local function step(now)
    if InCombatLockdown() then
        if not run.paused and ui.Print then
            ui.Print(L("Сортировка продолжится после боя.", "Sorting continues after combat."))
        end
        run.paused = true
        return
    end
    run.paused = nil
    if MODES[run.mode].bank and not bankOpen then return finish("bank") end
    if MODES[run.mode].guild then
        if not guildOpen then return finish("guild") end
        if guildTab() ~= run.tab then return finish("tab") end
    end
    if CursorHasItem() then
        run.cursorSince = run.cursorSince or now
        if now - run.cursorSince > CURSOR_WAIT then finish("cursor") end
        return
    end
    run.cursorSince = nil
    local busy = pendingClear(now)
    if run.pos > Q.n then
        if not busy then plan(now) end
        return
    end
    -- The guild bank server handles one move at a time and drops a move sent while the previous one is still being
    -- handled (seen in game: a burst of moves, every swap "refused"). The next move waits for the last one to land.
    if MODES[run.mode].guild and (busy or now - run.landed < run.gap) then return end
    local batch = MODES[run.mode].guild and 1 or setting("bagSortBatch", 2)
    local issued = 0
    while issued < batch and run.pos <= Q.n do
        local k = run.pos
        local s, d = Q.src[k], Q.dst[k]
        if run.pending[s] or run.pending[d] then break end
        local _, _, lockedS = readSlot(S.bag[s], S.slot[s])
        local _, _, lockedD = readSlot(S.bag[d], S.slot[d])
        if lockedS or lockedD then break end
        if not slotIs(s, Q.sid[k], Q.scount[k]) or not slotIs(d, Q.did[k] or nil, Q.dcount[k]) then
            -- Late contents from the server settle within a moment; anything else (loot, another addon) replans.
            run.staleSince = run.staleSince or now
            if now - run.staleSince > run.settle then
                run.staleSince = nil
                run.desync = run.desync + 1
                dropQueue("bags changed")
            end
            break
        end
        run.staleSince = nil
        pickup(S.bag[s], S.slot[s])
        pickup(S.bag[d], S.slot[d])
        if CursorHasItem() then
            ClearCursor() -- the client refused the drop; the item goes back to its slot
            refuse(k, "client refused")
            break
        end
        local sid, sc, did, dc = after(k)
        run.oldId[s], run.oldCount[s], run.oldId[d], run.oldCount[d] = Q.sid[k], Q.scount[k], Q.did[k], Q.dcount[k]
        run.wantId[s], run.wantCount[s], run.wantId[d], run.wantCount[d] = sid, sc, did, dc
        run.moveOf[s], run.moveOf[d] = k, k
        run.pending[s], run.pending[d] = now, now
        run.pos = k + 1
        run.done = run.done + 1
        issued = issued + 1
        if run.withdrawLeft and S.group[s] == 3 and S.group[d] ~= 3 then run.withdrawLeft = run.withdrawLeft - 1 end
    end
    if issued > 0 and now - run.refreshed > REFRESH_GAP then
        run.refreshed = now
        refreshBags()
    end
end

driver:SetScript("OnUpdate", function(_, elapsed)
    elapsedSum = elapsedSum + elapsed
    if elapsedSum < TICK then return end
    elapsedSum = 0
    if not run then driver:Hide() return end
    step(GetTime())
    if run then notify() end
end)

function B.Start(mode)
    mode = mode or "bags"
    if not MODES[mode] then return false end
    if setting("bagSortEnabled", true) == false then return false end
    if run then return false end
    if MODES[mode].bank and not bankOpen then
        if ui.Print then ui.Print(L("Откройте банк.", "Open the bank first.")) end
        return false
    end
    local guild = MODES[mode].guild
    local tab, withdrawLeft
    if guild then
        local refusal = B.GuildRefusal(mode)
        if refusal then
            if ui.Print then ui.Print(refusal) end
            return false
        end
        tab = guildTab()
        withdrawLeft = B.GuildWithdrawals(tab)
    end
    run = { mode = mode, started = GetTime(), pass = 0, done = 0, doneAtPlan = 0, wasted = 0, failures = 0,
        desync = 0, timeouts = 0, refused = 0, learned = 0, shown = 0, pos = 1, refreshed = 0,
        pending = {}, wantId = {}, wantCount = {}, oldId = {}, oldCount = {}, moveOf = {}, frozen = {},
        tab = tab, withdrawLeft = withdrawLeft,
        lockTimeout = guild and GUILD_LOCK_TIMEOUT or LOCK_TIMEOUT, settle = guild and GUILD_SETTLE or SETTLE,
        maxPasses = guild and GUILD_MAX_PASSES or MAX_PASSES, gap = GUILD_GAP, landed = GetTime(), retries = {}, retried = 0 }
    P.ResetQueue(Q)
    elapsedSum = TICK
    driver:Show()
    notify()
    return true
end

function B.Stop()
    if run then finish("stopped") end
end

function B.Toggle(mode)
    if run then B.Stop() else B.Start(mode) end
end

function B.Busy() return run ~= nil end
function B.Mode() return run and run.mode end
function B.BankOpen() return bankOpen end
function B.GuildOpen() return guildOpen end

-- Withdrawals left today on guild bank tab `tab`: a number, or nil when unlimited.
function B.GuildWithdrawals(tab)
    if not GetGuildBankTabInfo then return nil end
    local _, _, _, _, _, remaining = GetGuildBankTabInfo(tab)
    if remaining and remaining >= 0 then return remaining end
    return nil
end

-- Why a guild bank mode cannot start now (nil = it can).
function B.GuildRefusal(mode)
    if not guildOpen then return L("Откройте банк гильдии.", "Open the guild bank first.") end
    local tab = guildTab()
    local _, _, viewable, canDeposit = GetGuildBankTabInfo(tab)
    if not viewable then
        return L("Эта вкладка банка гильдии вам недоступна.", "You cannot view this guild bank tab.")
    end
    if mode == "guilddeposit" and not canDeposit then
        return L("На эту вкладку банка гильдии вам нельзя класть предметы.",
            "You may not deposit items on this guild bank tab.")
    end
    if mode == "guildwithdraw" and B.GuildWithdrawals(tab) == 0 then
        return L("Дневной лимит снятия с этой вкладки исчерпан.", "The daily withdrawal limit of this tab is used up.")
    end
end

events:RegisterEvent("BANKFRAME_OPENED")
events:RegisterEvent("BANKFRAME_CLOSED")
events:RegisterEvent("GUILDBANKFRAME_OPENED")
events:RegisterEvent("GUILDBANKFRAME_CLOSED")
events:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("ITEM_LOCK_CHANGED")
events:RegisterEvent("BAG_UPDATE")
events:RegisterEvent("PLAYER_LEAVING_WORLD")
pcall(events.RegisterEvent, events, "GET_ITEM_INFO_RECEIVED")
events:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" then
        if arg == "Blizzard_GuildBankUI" then B.CreateGuildButtons() end
    elseif event == "GUILDBANKFRAME_OPENED" then
        guildOpen = true
        B.CreateGuildButtons()
    elseif event == "GUILDBANKFRAME_CLOSED" then
        guildOpen = false
        if run and MODES[run.mode].guild then finish("guild") end
    elseif event == "BANKFRAME_OPENED" then
        bankOpen = true
    elseif event == "BANKFRAME_CLOSED" then
        bankOpen = false
        if run and MODES[run.mode].bank then finish("bank") end
    elseif event == "PLAYER_LEAVING_WORLD" then
        if run then finish("stopped") end
    elseif run then
        elapsedSum = TICK -- a slot changed: check pending locks on the next frame instead of waiting a tick
    end
end)

------------------------------------------------------------------------------------------------------------------
-- Buttons in the combined bag window (Bags.lua calls CreateButtons from its toolbar).

local ICONS = {
    bags = "Interface\\Icons\\INV_Misc_Bag_10",
    bank = "Interface\\Icons\\INV_Misc_Bag_10",
    deposit = "Interface\\Icons\\INV_Box_02",
    withdraw = "Interface\\Icons\\INV_Misc_Bag_09",
}
ICONS.guild, ICONS.guilddeposit, ICONS.guildwithdraw = ICONS.bank, ICONS.deposit, ICONS.withdraw
local LABELS = {
    bags = L("Сортировать сумки\n|cffffffffЛКМ|r — сортировка, стопки объединяются сами\n|cffffffffПКМ|r — остановить",
        "Sort bags\n|cffffffffLeft click|r: sort, stacks merge on their own\n|cffffffffRight click|r: stop"),
    bank = L("Сортировать банк\n|cffffffffЛКМ|r — сортировка, стопки объединяются сами\n|cffffffffПКМ|r — остановить",
        "Sort bank\n|cffffffffLeft click|r: sort, stacks merge on their own\n|cffffffffRight click|r: stop"),
    deposit = L("Сложить в банк\nРеагенты и другие стопки, которые уже есть в банке, переносятся туда из сумок",
        "Stack into the bank\nStackable items the bank already holds move there from the bags"),
    withdraw = L("Взять из банка\nНеполные стопки в сумках пополняются из банка",
        "Take from the bank\nPartial stacks in the bags are topped up from the bank"),
    guild = L("Сортировать вкладку банка гильдии\nСортируется открытая вкладка, стопки объединяются сами\n"
        .. "|cffffffffЛКМ|r — сортировка, |cffffffffПКМ|r — остановить", "Sort the guild bank tab\nThe open tab is "
        .. "sorted, stacks merge on their own\n|cffffffffLeft click|r: sort, |cffffffffRight click|r: stop"),
    guilddeposit = L("Сложить в банк гильдии\nСтопки, которые уже есть на открытой вкладке, переносятся туда из сумок",
        "Stack into the guild bank\nStackable items the open tab already holds move there from the bags"),
    guildwithdraw = L("Взять из банка гильдии\nНеполные стопки в сумках пополняются с открытой вкладки\n"
        .. "Каждое перемещение тратит одно снятие из дневного лимита вкладки", "Take from the guild bank\nPartial "
        .. "stacks in the bags are topped up from the open tab\nEvery move uses one of the tab's daily withdrawals"),
}

local function sortProgress(button, state)
    if state then
        button.sortShade:Show()
        button.sortText:SetText(state.phase == "stack" and "…" or (progress() .. "%"))
        button.sortText:Show()
    else
        button.sortShade:Hide()
        button.sortText:Hide()
    end
end

function B.AttachButton(button, mode)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(_, which)
        if which == "RightButton" then B.Stop() else B.Toggle(mode) end
    end)
    local shade = button:CreateTexture(nil, "OVERLAY")
    shade:SetTexture(0, 0, 0, 0.6)
    shade:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    shade:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    shade:Hide()
    local text = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    text:SetPoint("CENTER", button, "CENTER", 0, 0)
    text:Hide()
    button.sortShade, button.sortText, button.SortProgress = shade, text, sortProgress
    watchers[button] = mode
    sortProgress(button, run and run.mode == mode and run or nil)
    return button
end

-- factory(window, name, relative, label, texture, onClick) is Bags.lua's toolbarButton.
-- Returns the leftmost new button (the next toolbar button is anchored to it).
function B.CreateButtons(window, relative, isBank, factory)
    if setting("bagSortEnabled", true) == false then return relative end
    local list = isBank and { "bank", "deposit", "withdraw" } or { "bags" }
    local names = { bags = "Sort", bank = "Sort", deposit = "Deposit", withdraw = "Withdraw" }
    for _, mode in ipairs(list) do
        relative = B.AttachButton(factory(window, names[mode], relative, LABELS[mode], ICONS[mode], nil), mode)
    end
    return relative
end

-- Plain toolbar button for when the bag module's factory is missing.
local function plainButton(window, name, relative, label, texture)
    local button = CreateFrame("Button", window:GetName() .. name, window)
    button:SetSize(21, 21)
    button:SetPoint("RIGHT", relative, "LEFT", -3, 0)
    button:SetNormalTexture(texture)
    button:GetNormalTexture():SetTexCoord(0.09, 0.91, 0.09, 0.91)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(label)
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    return button
end

-- The same three buttons as in the bank, on the client's guild bank window (Blizzard_GuildBankUI loads on demand):
-- top right under the header, right to left: sort the open tab, stack into it, take from it. Shown on the item
-- page of the window only (not on the logs and the tab info).
local guildHolder
local GUILD_LEVEL = 10 -- above the window's own children (the WoW Forever chrome sits on top of them)

local function placeGuildButtons()
    local frame = GuildBankFrame
    if not (guildHolder and frame) then return end
    local onItems = frame.mode == nil or frame.mode == "bank"
    if setting("bagSortEnabled", true) ~= false and onItems then guildHolder:Show() else guildHolder:Hide() end
    local level = frame:GetFrameLevel() + GUILD_LEVEL
    guildHolder:SetFrameLevel(level)
    for _, button in ipairs(guildHolder.buttons) do button:SetFrameLevel(level) end
end
B.PlaceGuildButtons = placeGuildButtons

function B.CreateGuildButtons()
    local frame = GuildBankFrame
    if guildHolder or not frame then return guildHolder end
    guildHolder = CreateFrame("Frame", "ForeverStockUIGuildBankSort", frame)
    guildHolder:SetSize(1, 21)
    guildHolder:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -40)
    guildHolder.buttons = {}
    local factory = ui.Bags and ui.Bags.ToolbarButton or plainButton
    local relative = guildHolder
    local names = { guild = "Sort", guilddeposit = "Deposit", guildwithdraw = "Withdraw" }
    for _, mode in ipairs({ "guild", "guilddeposit", "guildwithdraw" }) do
        relative = B.AttachButton(factory(guildHolder, names[mode], relative, LABELS[mode], ICONS[mode], nil), mode)
        guildHolder.buttons[#guildHolder.buttons + 1] = relative
    end
    frame:HookScript("OnShow", placeGuildButtons)
    if GuildBankFrame_Update then hooksecurefunc("GuildBankFrame_Update", placeGuildButtons) end
    placeGuildButtons()
    return guildHolder
end
if GuildBankFrame then B.CreateGuildButtons() end

------------------------------------------------------------------------------------------------------------------
-- Slash command and key binding.

local function report()
    local print = ui.Print or print
    if run then return print(L("Сортировка ещё идёт.", "Sorting is still running.")) end
    for g = 1, 2 do
        if g == 1 or bankOpen then
            for _, bag in ipairs(CONTAINERS[g]) do
                local size = GetContainerNumSlots(bag) or 0
                if size > 0 then
                    local free, family = GetContainerNumFreeSlots(bag)
                    local link = bag > 0 and GetInventoryItemLink and ContainerIDToInventoryID
                        and GetInventoryItemLink("player", ContainerIDToInventoryID(bag)) or ""
                    print(("%s %d: %d/%d, family %d %s"):format(g == 1 and "bag" or "bank", bag, free or 0, size,
                        family or 0, link or ""))
                end
            end
        end
    end
    local mode = MODES[bankOpen and "deposit" or "bags"]
    scan(mode.groups[1], mode.groups[2])
    for bagId, rule in pairs(customRules()) do
        local accept, deny = {}, {}
        for class in pairs(rule.accept or {}) do accept[#accept + 1] = class end
        for class in pairs(rule.deny or {}) do deny[#deny + 1] = class end
        local items = 0
        for _ in pairs(rule.denyItems or {}) do items = items + 1 end
        table.sort(accept) table.sort(deny)
        print(("crafting bag %d %s: takes [%s], refuses [%s], refused items %d"):format(bagId, rule.name or "",
            table.concat(accept, ", "), table.concat(deny, ", "), items))
    end
    -- Resource subclasses without a block (their client names are guesses for ruRU): they go to "other resources".
    local loose, seen = {}, {}
    for i = 1, S.n do
        local r = S.id[i] and itemInfo(S.id[i])
        if r and r.group == 2 and r.block == OTHER_BLOCK and not seen[r.subclass] then
            seen[r.subclass] = true
            loose[#loose + 1] = r.subclass
        end
    end
    table.sort(loose)
    print(("resources without a block: [%s]"):format(table.concat(loose, ", ")))
    P.ResetQueue(Q)
    local stacks = P.StackMoves(S, 1, itemInfo, Q)
    P.ResetQueue(Q)
    local fails = P.SortMoves(S, 1, itemInfo, B.SortOptions(), Q)
    print(("slots %d, stack moves %d, sort moves %d (before stacking), unplaceable %d"):format(S.n, stacks, Q.n, fails))
    P.ResetQueue(Q)
end

SLASH_FOREVERUISORT1 = "/fuisort"
SlashCmdList.FOREVERUISORT = function(msg)
    msg = (msg or ""):lower():match("^%s*(%S*)")
    if msg == "" or msg == "bags" then B.Toggle("bags")
    elseif msg == "bank" or msg == "deposit" or msg == "withdraw" or msg == "guild" or msg == "guilddeposit"
        or msg == "guildwithdraw" then B.Toggle(msg)
    elseif msg == "stop" then B.Stop()
    elseif msg == "scan" then report()
    elseif msg == "forget" then
        local db = ui.Settings and ui.Settings()
        if db then db.bagSortCustomBags = {} end
        rulesChanged()
        local print = ui.Print or print
        print(L("Правила ремесленных сумок сброшены.", "Crafting bag rules cleared."))
    elseif msg == "debug" then
        B.debug = not B.debug
        local print = ui.Print or print
        print(B.debug and L("Отладка сортировки включена: ходы, отказы и перепланирования пишутся в чат.",
            "Sort debugging on: moves, refusals and replans go to chat.") or L("Отладка сортировки выключена.",
            "Sort debugging off."))
    else
        local print = ui.Print or print
        print(L("/fuisort — сумки, /fuisort bank — банк, deposit — сложить в банк, withdraw — взять из банка, "
            .. "guild, guilddeposit, guildwithdraw — то же для банка гильдии, "
            .. "stop — остановить, scan — сумки и их семейства, debug — отладка в чат, forget — забыть правила ремесленных сумок", "/fuisort: bags, /fuisort bank: bank, deposit: "
            .. "stack into the bank, withdraw: take from the bank, guild, guilddeposit, guildwithdraw: the same for "
            .. "the guild bank, stop, scan: bags and their families, debug: log to chat, forget: clear crafting bag rules"))
    end
end

BINDING_NAME_FOREVERUI_BAGSORT = L("Сортировать сумки (в банке — банк, в банке гильдии — его вкладку)",
    "Sort bags (the bank or the guild bank tab when one is open)")
function ForeverStockUI_SortBags()
    B.Toggle(guildOpen and "guild" or bankOpen and "bank" or "bags")
end
