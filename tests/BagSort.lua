-- Run from the addon directory (see INDEX.md): bag sorting.
-- Part 1, BagSortPlan.lua on a move simulator with the client's rules (a swap needs both items to fit the other
-- container, a stack dropped on a partial stack of the same item merges and the rest stays): random bags with
-- profession bags, full bags, stacks, junk, reverse fill, the narrowest bag for items that fit several, idempotence,
-- deposit and withdraw.
-- Part 2, the real BagSort.lua executor on a mocked container API with server-side locks: sort, desync (loot
-- during the sort), combat pause, bank deposit, closed bank, forbidden APIs.

local failures = 0
local function check(ok, label)
    if not ok then
        failures = failures + 1
        print("FAIL: " .. label)
    end
end

local prints = {}
local settings = {}
local ui = {
    L = function(ru) return ru end,
    Print = function(text) prints[#prints + 1] = text end,
    Settings = function() return settings end,
}
assert(loadfile("BagSortPlan.lua"))("ForeverUI", ui)
local P = ui.BagSortPlan
local band = bit.band

-- Item database: id → name, class, subclass, quality, ilvl, max stack, equip slot, family.
local DB = {
    [6948] = { "Камень возвращения", "Разное", "Хлам", 1, 1, 1, "", 0 },
    [1] = { "Меч", "Оружие", "Мечи", 3, 200, 1, "INVTYPE_WEAPON", 0 },
    [2] = { "Шлем", "Доспехи", "Латы", 4, 226, 1, "INVTYPE_HEAD", 0 },
    [3] = { "Сапоги", "Доспехи", "Латы", 3, 200, 1, "INVTYPE_FEET", 0 },
    [10] = { "Золотой клевер", "Хозяйственные товары", "Трава", 1, 75, 20, "", 32 },
    [11] = { "Личиющий цветок", "Хозяйственные товары", "Трава", 1, 75, 20, "", 32 },
    [12] = { "Ледошип", "Хозяйственные товары", "Трава", 1, 80, 20, "", 32 },
    [13] = { "Мироцвет", "Хозяйственные товары", "Трава", 1, 60, 20, "", 32 },
    [20] = { "Саронитовая руда", "Хозяйственные товары", "Металл и камень", 1, 77, 20, "", 1024 },
    [30] = { "Хризопраз", "Самоцветы", "Простые", 2, 70, 20, "", 512 },
    [31] = { "Сапфир", "Самоцветы", "Синие", 3, 80, 20, "", 512 },
    [32] = { "Рубин", "Самоцветы", "Красные", 2, 80, 20, "", 512 },
    [40] = { "Двойной реагент", "Хозяйственные товары", "Другое", 1, 70, 20, "", 32 + 1024 },
    [50] = { "Стрела", "Боеприпасы", "Стрелы", 1, 80, 200, "INVTYPE_AMMO", 1 },
    [60] = { "Осколок души", "Разное", "Реагент", 1, 1, 1, "", 4 },
    [70] = { "Сломанный клык", "Разное", "Хлам", 0, 1, 10, "", 0 },
    [71] = { "Порванный мех", "Разное", "Хлам", 0, 1, 10, "", 0 },
    [80] = { "Зелье", "Расходуемые", "Зелья", 1, 80, 20, "", 0 },
    [81] = { "Слабое зелье", "Расходуемые", "Зелья", 1, 70, 20, "", 0 },
    [82] = { "Хлеб", "Расходуемые", "Еда", 1, 80, 20, "", 0 },
    [90] = { "Сумка травника", "Сумки", "Сумка травника", 2, 70, 1, "INVTYPE_BAG", 32 },
    [4] = { "Ржавый меч", "Оружие", "Мечи", 0, 5, 1, "INVTYPE_WEAPON", 0 },
    [100] = { "Рецепт: зелье", "Рецепты", "Алхимия", 2, 70, 1, "", 0 },
    [110] = { "Письмо", "Задания", "Задания", 1, 1, 1, "", 0 },
}
local ALL = { 6948, 1, 2, 3, 4, 10, 11, 12, 13, 20, 30, 31, 32, 40, 50, 60, 70, 71, 80, 81, 82, 90, 100, 110 }

local classRank = { ["Оружие"] = 1, ["Доспехи"] = 2, ["Сумки"] = 3, ["Расходуемые"] = 4,
    ["Хозяйственные товары"] = 6, ["Боеприпасы"] = 7, ["Самоцветы"] = 10, ["Разное"] = 12 }
local equipRank = { INVTYPE_HEAD = 1, INVTYPE_FEET = 12, INVTYPE_WEAPON = 17, INVTYPE_AMMO = 26, INVTYPE_BAG = 27 }
-- Groups and resource blocks as BagSort.lua gives them (part 2 checks the real ones against these).
local groupRank = { ["Оружие"] = 1, ["Доспехи"] = 1, ["Сумки"] = 1, ["Хозяйственные товары"] = 2, ["Самоцветы"] = 2,
    ["Рецепты"] = 3, ["Расходуемые"] = 4, ["Задания"] = 6 }
local blockRank = { ["Металл и камень"] = 1, ["Трава"] = 2 }
local function groupOf(id)
    local d = DB[id]
    if id == 6948 then return 1, 0 end
    if d[4] == 0 then return 7, 0 end
    local group = groupRank[d[2]] or 5
    if group ~= 2 then return group, 0 end
    return group, d[2] == "Самоцветы" and 7 or blockRank[d[3]] or 10
end
-- Item level order: 1 resources (inside the block), 2 consumables (inside the subclass).
local levelRank = { [2] = 1, [4] = 2 }
local infoCache = {}
local function info(id)
    local r = infoCache[id]
    if r then return r end
    local d = DB[id]
    local group, block = groupOf(id)
    r = { family = d[8], maxStack = d[6], isBag = d[7] == "INVTYPE_BAG", pin = id == 6948 and 1 or 999,
        group = group, block = block, level = levelRank[group], classRank = classRank[d[2]] or 15, subclass = d[3],
        equipRank = equipRank[d[7]] or 99, quality = d[4], ilvl = d[5], name = d[1] }
    infoCache[id] = r
    return r
end

------------------------------------------------------------------------------------------------------------------
-- Planner on a simulator.

-- containers: { { family=, size=, group= }, ... }
local function newState(containers)
    local S = P.NewState()
    local n = 0
    for c, spec in ipairs(containers) do
        for slot = 1, spec.size do
            n = n + 1
            S.bag[n], S.slot[n], S.group[n], S.family[n], S.fixed[n] = c, slot, spec.group or 1, spec.family or 0, false
            S.count[n] = 0
        end
    end
    S.n = n
    return S
end

local function put(S, i, id, count, suffix)
    S.id[i], S.count[i], S.key[i] = id, count, id .. ":0:0:0:0:0:" .. (suffix or 0)
end

local function fitsIn(id, family)
    if not id or family == 0 then return true end
    local r = info(id)
    if r.isBag then return false end
    return band(r.family, family) ~= 0
end

local illegal, mismatch = 0, 0
local function apply(S, Q, k)
    local s, d = Q.src[k], Q.dst[k]
    if S.id[s] ~= Q.sid[k] or S.count[s] ~= Q.scount[k] or S.id[d] ~= (Q.did[k] or nil)
        or (S.id[d] and S.count[d] ~= Q.dcount[k]) then
        mismatch = mismatch + 1
        return
    end
    local xid, xc, xk = S.id[s], S.count[s], S.key[s]
    local yid, yc, yk = S.id[d], S.count[d], S.key[d]
    if not yid then
        if not fitsIn(xid, S.family[d]) then illegal = illegal + 1 return end
        S.id[d], S.count[d], S.key[d] = xid, xc, xk
        S.id[s], S.count[s], S.key[s] = nil, 0, nil
    elseif xid == yid and xk == yk and info(xid).maxStack > 1 and yc < info(xid).maxStack then
        local room = info(xid).maxStack - yc
        local moved = math.min(room, xc)
        S.count[d] = yc + moved
        S.count[s] = xc - moved
        if S.count[s] == 0 then S.id[s], S.key[s] = nil, nil end
    else
        if not fitsIn(xid, S.family[d]) or not fitsIn(yid, S.family[s]) then illegal = illegal + 1 return end
        S.id[d], S.count[d], S.key[d] = xid, xc, xk
        S.id[s], S.count[s], S.key[s] = yid, yc, yk
    end
end

local notPermutation = 0
local function runSort(S, g, opts)
    local Q = P.NewQueue()
    local passes, moves, fails = 0, 0, 0
    for _ = 1, 6 do
        P.ResetQueue(Q)
        P.StackMoves(S, g, info, Q)
        if Q.n == 0 then
            local layout = P.Layout(S, g, info, opts or {})
            local seen = {}
            for t = 1, S.n do
                local s = layout[t]
                if s then
                    if s == 0 or seen[s] then
                        notPermutation = notPermutation + 1
                        if DEBUG_NOW then print("dup/zero target", t, "source", s, "first", seen[s]) end
                    end
                    seen[s] = t
                end
            end
            fails = P.SortMoves(S, g, info, opts or {}, Q)
        end
        if Q.n == 0 then return passes, moves, fails end
        passes = passes + 1
        moves = moves + Q.n
        if DEBUG_NOW then
            print("pass", passes, "moves", Q.n)
            for k = 1, Q.n do print("  ", Q.src[k], "->", Q.dst[k], Q.sid[k], Q.scount[k], Q.did[k], Q.dcount[k]) end
        end
        for k = 1, Q.n do apply(S, Q, k) end
    end
    return passes, moves, fails, true
end

local function totals(S, g)
    local t = {}
    for i = 1, S.n do
        if S.id[i] and (not g or S.group[i] == g) then t[S.id[i]] = (t[S.id[i]] or 0) + S.count[i] end
    end
    return t
end
local function same(a, b)
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k, v in pairs(b) do if a[k] ~= v then return false end end
    return true
end

-- Profession priority: no item that fits a profession bag with a free slot is left in an ordinary bag.
local function priorityOk(S, g)
    for i = 1, S.n do
        if S.group[i] == g and S.id[i] and S.family[i] == 0 then
            for j = 1, S.n do
                if S.group[j] == g and not S.id[j] and S.family[j] ~= 0 and fitsIn(S.id[i], S.family[j]) then
                    return false
                end
            end
        end
    end
    return true
end

local function onePartialPerItem(S, g)
    local seen = {}
    for i = 1, S.n do
        local id = S.id[i]
        if id and S.group[i] == g and info(id).maxStack > 1 and S.count[i] < info(id).maxStack then
            if seen[id] then return false end
            seen[id] = true
        end
    end
    return true
end

local function poolOrder(S, g, family)
    local list = {}
    for i = 1, S.n do
        if S.group[i] == g and S.family[i] == family then list[#list + 1] = i end
    end
    return list
end

-- 1. Hand-made case: herbs scattered in ordinary bags go to the herb bag, overflow stays ordinary.
do
    local S = newState({ { size = 8 }, { size = 2, family = 32 } })
    put(S, 1, 70, 3)        -- junk
    put(S, 2, 10, 20)       -- herb
    put(S, 3, 1, 1)         -- sword
    put(S, 4, 11, 20)       -- herb 2
    put(S, 5, 10, 7)        -- herb partial
    put(S, 6, 6948, 1)      -- hearthstone
    put(S, 8, 10, 5)        -- herb partial
    local before = totals(S, 1)
    local passes, moves, fails = runSort(S, 1, {})
    check(illegal == 0 and mismatch == 0, "case 1: legal moves that match the plan")
    check(same(before, totals(S, 1)), "case 1: nothing lost")
    check(fails == 0, "case 1: no failures")
    check(S.id[1] == 6948, "case 1: hearthstone first")
    check(S.id[9] and S.id[10] and info(S.id[9]).family == 32 and info(S.id[10]).family == 32,
        "case 1: herb bag full of herbs")
    check(onePartialPerItem(S, 1), "case 1: partial stacks merged")
    local lastItem
    for i = 1, 8 do if S.id[i] then lastItem = i end end
    check(S.id[lastItem] == 70, "case 1: junk last in ordinary bags")
    check(passes <= 2, "case 1: stack + sort passes, got " .. passes)
end

-- 2. Item that fits two profession bags goes to the narrower one; the general reagent goes to the other.
do
    local S = newState({ { size = 4 }, { size = 1, family = 32 + 1024 }, { size = 1, family = 1024 } })
    put(S, 1, 40, 4) -- herb + mining reagent
    put(S, 2, 20, 4) -- ore: fits only mining
    local _, _, fails = runSort(S, 1, {})
    check(fails == 0 and illegal == 0, "case 2: legal")
    check(S.id[6] == 20 and S.id[5] == 40, "case 2: ore in the narrow mining bag, reagent in the wide bag")
end
do
    local S = newState({ { size = 4 }, { size = 1, family = 32 }, { size = 1, family = 1024 } })
    put(S, 1, 40, 4)
    put(S, 2, 10, 4)
    put(S, 3, 20, 4)
    runSort(S, 1, {})
    check(S.id[5] == 10 and S.id[6] == 20 and S.id[1] == 40, "case 2b: constrained items first, flexible overflow")
end

-- 3. A bag item never goes into a profession bag of its own family.
do
    local S = newState({ { size = 3 }, { size = 2, family = 32 } })
    put(S, 1, 90, 1)
    put(S, 2, 10, 3)
    runSort(S, 1, {})
    check(S.id[1] == 90 and S.id[4] == 10 and not S.id[5], "case 3: herb bag item stays in the ordinary bag")
end

-- 4. Reverse fill: the layout is mirrored, free slots first in every pool.
do
    local S = newState({ { size = 6 }, { size = 3, family = 32 } })
    put(S, 1, 1, 1)
    put(S, 2, 10, 3)
    put(S, 3, 80, 4)
    runSort(S, 1, { reverse = true })
    check(not S.id[1] and not S.id[2] and not S.id[3] and not S.id[4] and S.id[6] == 1 and S.id[5] == 80,
        "case 4: ordinary bag fills from the last slot backwards")
    check(not S.id[7] and not S.id[8] and S.id[9] == 10, "case 4: herb bag fills from the end")
end

-- 5. Grey items always last, grey equipment too; order of the groups.
do
    local S = newState({ { size = 10 } })
    put(S, 1, 70, 1)
    put(S, 2, 4, 1)      -- grey sword
    put(S, 3, 80, 1)     -- potion
    put(S, 4, 3, 1)      -- boots
    put(S, 5, 110, 1)    -- quest
    put(S, 6, 100, 1)    -- recipe
    put(S, 7, 20, 1)     -- ore
    put(S, 8, 6948, 1)
    put(S, 9, 60, 1)     -- soul shard: "everything else"
    runSort(S, 1, {})
    local want = { 6948, 3, 20, 100, 80, 60, 110 }
    local ok = true
    for k, id in ipairs(want) do if S.id[k] ~= id then ok = false end end
    check(ok, "case 5: hearthstone, equipment, resources, recipes, consumables, rest, quest")
    check(info(S.id[8]).group == 7 and info(S.id[9]).group == 7 and not S.id[10], "case 5: grey items (sword too) last")
end

-- 6. Identical copies do not move: an unsorted bag of the same item costs nothing.
do
    local S = newState({ { size = 6 } })
    put(S, 2, 1, 1)
    put(S, 4, 1, 1)
    put(S, 5, 1, 1)
    local _, moves = runSort(S, 1, {})
    check(moves == 2 and S.id[1] == 1 and S.id[2] == 1 and S.id[3] == 1, "case 6: the copy in slot 2 stays, two moves, got " .. moves)
    local S2 = newState({ { size = 3 } })
    put(S2, 1, 2, 1)
    put(S2, 2, 2, 1)
    put(S2, 3, 1, 1)
    local _, moves2 = runSort(S2, 1, {})
    check(moves2 == 1, "case 6b: one swap for a two-slot cycle with a copy in place, got " .. moves2)
end

-- 7. Bank transfers.
do
    local S = newState({ { size = 4, group = 1 }, { size = 4, group = 2 }, { size = 2, group = 2, family = 32 } })
    put(S, 1, 10, 15)       -- herb in bags, bank has herbs
    put(S, 2, 20, 10)       -- ore in bags, bank has ore
    put(S, 3, 1, 1)         -- sword: bank has none → stays
    put(S, 5, 10, 18)       -- bank: partial herbs (ordinary bank slot)
    put(S, 6, 20, 20)       -- bank: full ore
    local Q = P.NewQueue()
    local fails = P.DepositMoves(S, info, Q)
    for k = 1, Q.n do apply(S, Q, k) end
    check(illegal == 0 and mismatch == 0, "deposit: legal")
    check(fails == 0, "deposit: room found")
    local t = totals(S, 2)
    check(t[10] == 33 and t[20] == 30 and not t[1], "deposit: herbs and ore moved, sword kept")
    check(S.id[5] == 10 and S.count[5] == 20, "deposit: partial bank stack filled first")
    check(S.id[9] == 10 and S.id[7] == 20, "deposit: herbs go to the bank herb bag, ore to a free ordinary slot")
    check(not S.id[1] and not S.id[2] and S.id[3] == 1, "deposit: bag slots emptied")
    P.ResetQueue(Q)
    check(P.DepositMoves(S, info, Q) == 0 and Q.n == 0, "deposit: nothing left the second time")
end
do
    local S = newState({ { size = 3, group = 1 }, { size = 3, group = 2 } })
    put(S, 1, 80, 3)        -- potion partial in bags
    put(S, 2, 1, 1)
    put(S, 4, 80, 20)       -- bank: potions
    put(S, 5, 80, 5)
    local Q = P.NewQueue()
    P.WithdrawMoves(S, info, Q)
    for k = 1, Q.n do apply(S, Q, k) end
    check(illegal == 0 and mismatch == 0, "withdraw: legal")
    check(S.count[1] == 20 and not S.id[5] and S.count[4] == 8, "withdraw: smallest bank stack used first, bag stack full")
    check(not S.id[3], "withdraw: no new slots taken in the bags")
end

-- 9. No gaps: groups and resource blocks follow each other, free slots at the end.
local function idsAt(S, slots)
    for k, i in pairs(slots) do if S.id[i] ~= k then return false end end
    return true
end
do
    local S = newState({ { size = 24 } })
    put(S, 1, 70, 1) put(S, 2, 10, 4) put(S, 3, 80, 2) put(S, 4, 20, 3) put(S, 5, 1, 1) put(S, 6, 6948, 1)
    local passes, _, fails = runSort(S, 1, {})
    check(fails == 0 and passes <= 2, "case 9: sorted")
    check(idsAt(S, { [6948] = 1, [1] = 2, [20] = 3, [10] = 4, [80] = 5, [70] = 6 }),
        "case 9: hearthstone, sword, ore, herb, potion, junk one after another")
    for i = 7, 24 do if S.id[i] then check(false, "case 9: free slots at the end") break end end
    local S2 = newState({ { size = 8 } })
    put(S2, 1, 80, 1) put(S2, 2, 1, 1) put(S2, 3, 6948, 1)
    runSort(S2, 1, { reverse = true })
    check(idsAt(S2, { [6948] = 8, [1] = 7, [80] = 6 }), "case 9: mirrored from the last slot without gaps")
end
-- 9f. Item level: resources by tier inside the block (quality before gem colour), consumables inside the subclass.
do
    local S = newState({ { size = 16 } })
    put(S, 1, 81, 3) put(S, 2, 13, 4) put(S, 3, 30, 2) put(S, 4, 80, 1) put(S, 5, 11, 5) put(S, 6, 32, 1)
    put(S, 7, 82, 6) put(S, 8, 12, 2) put(S, 9, 31, 1) put(S, 10, 10, 7)
    local passes, _, fails = runSort(S, 1, {})
    check(fails == 0 and passes <= 2, "case 9f: sorted")
    check(idsAt(S, { [12] = 1, [10] = 2, [11] = 3, [13] = 4 }), "case 9f: herbs 80, 75, 75, 60")
    check(idsAt(S, { [31] = 5, [32] = 6, [30] = 7 }), "case 9f: gems 80 blue quality, 80 green, 70")
    check(idsAt(S, { [82] = 8, [80] = 9, [81] = 10 }), "case 9f: food, then potions 80, 70")
end
-- 9e. Profession bags keep their priority; blocks inside them follow each other too.
do
    local S = newState({ { size = 4 }, { size = 8, family = 1024 } })
    put(S, 1, 20, 3) put(S, 2, 40, 2) put(S, 3, 1, 1)
    runSort(S, 1, {})
    check(S.id[1] == 1 and not S.id[2], "case 9e: the sword stays in the ordinary bag")
    check(S.id[5] == 20 and S.id[6] == 40, "case 9e: ore, then the other reagent in the mining bag")
    check(priorityOk(S, 1), "case 9e: profession bag used first")
end

-- 8. Random bags, including completely full ones.
math.randomseed(12345)
local CONTAINER_SETS = {
    { { size = 16 }, { size = 12 }, { size = 8, family = 32 }, { size = 6, family = 1024 } },
    { { size = 16 }, { size = 14, family = 1 }, { size = 10 }, { size = 6, family = 4 } },
    { { size = 16 }, { size = 6, family = 512 }, { size = 6, family = 32 + 1024 }, { size = 4, family = 1024 } },
    { { size = 6 }, { size = 4, family = 32 } },
}
local stats = { cases = 0, moves = 0, fails = 0, maxPasses = 0 }
for case = 1, 400 do
    local set = CONTAINER_SETS[(case - 1) % #CONTAINER_SETS + 1]
    local S = newState(set)
    local fill = case % 5 == 0 and 1 or (0.3 + math.random() * 0.6)
    for i = 1, S.n do
        if math.random() < fill then
            local options = {}
            for _, id in ipairs(ALL) do
                if fitsIn(id, S.family[i]) then options[#options + 1] = id end
            end
            local id = options[math.random(#options)]
            put(S, i, id, math.random(info(id).maxStack), info(id).maxStack == 1 and math.random(3) == 1 and math.random(2) or 0)
        end
    end
    -- a couple of locked slots now and then
    if case % 7 == 0 then S.fixed[math.random(S.n)] = true end
    local before = totals(S)
    local reverse = case % 3 == 0
    DEBUG_NOW = DEBUG_CASE == case
    local passes, moves, fails, stuck = runSort(S, 1, { reverse = reverse })
    if DEBUG_CASE == case then
        for i = 1, S.n do print(i, S.family[i], S.id[i], S.count[i], S.key[i], S.fixed[i]) end
        print("passes", passes, "fails", fails, "reverse", reverse)
    end
    stats.cases, stats.moves, stats.fails = stats.cases + 1, stats.moves + moves, stats.fails + fails
    if passes > stats.maxPasses then stats.maxPasses = passes end
    check(not stuck, "random " .. case .. ": converges")
    check(same(before, totals(S)), "random " .. case .. ": nothing lost")
    check(passes <= 2, "random " .. case .. ": at most stack + sort passes, got " .. passes)
    if fails == 0 and case % 7 ~= 0 then
        check(priorityOk(S, 1), "random " .. case .. ": profession bags used first")
        check(onePartialPerItem(S, 1), "random " .. case .. ": partial stacks merged")
        -- Every pool, read in layout order (backwards when filling from the end): hearthstone, then groups and
        -- blocks in order, no free slot before the last item.
        local order = true
        local families = {}
        for i = 1, S.n do families[S.family[i]] = true end
        for family in pairs(families) do
            local list = poolOrder(S, 1, family)
            local prev, sawEmpty = nil, false
            for k = 1, #list do
                local i = list[reverse and (#list - k + 1) or k]
                if S.id[i] then
                    local r = info(S.id[i])
                    local key = (r.pin < 999 and 0 or 1) * 10000 + r.group * 100 + r.block
                    if prev and key < prev then order = false end
                    if sawEmpty then order = false end
                    prev = key
                else
                    sawEmpty = true
                end
            end
        end
        check(order, "random " .. case .. ": hearthstone first, groups and blocks in order, grey last, no gaps")
    end
end
check(notPermutation == 0, "layout is a permutation (" .. notPermutation .. ")")
check(illegal == 0, "random: no illegal move (" .. illegal .. ")")
check(mismatch == 0, "random: every move matches its expectation (" .. mismatch .. ")")
print(("planner: %d cases, %d moves, %d unplaceable, max passes %d"):format(stats.cases, stats.moves, stats.fails,
    stats.maxPasses))

------------------------------------------------------------------------------------------------------------------
-- Part 2: the executor on a mocked client.

local clock, combat, cursor = 100, false, nil
local frames = {}
local methods = {}
local function newFrame()
    local f = setmetatable({ scripts = {}, shown = true, events = {} }, { __index = function(_, key)
        if methods[key] then return methods[key] end
        return function() end
    end })
    frames[#frames + 1] = f
    return f
end
function methods:SetScript(name, fn) self.scripts[name] = fn end
function methods:GetScript(name) return self.scripts[name] end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:IsShown() return self.shown end
function methods:RegisterEvent(e) self.events[e] = true end
function methods:CreateTexture() return newFrame() end
function methods:CreateFontString() return newFrame() end
function methods:SetText(t) self.text = t end

local used = {}
local function track(name, fn) return function(...) used[name] = true return fn(...) end end

-- world[bag] = { family, size, slots = { [slot] = { id, count, lockedUntil } } }
local world = {}
local function container(bag, size, family) world[bag] = { family = family or 0, size = size, slots = {} } end
local function at(bag, slot) return world[bag] and world[bag].slots[slot] end
local function place(bag, slot, id, count) world[bag].slots[slot] = { id = id, count = count, lockedUntil = 0 } end

_G.CreateFrame = function() return newFrame() end
_G.GetTime = function() return clock end
_G.InCombatLockdown = function() return combat end
_G.CursorHasItem = function() return cursor ~= nil end
_G.ClearCursor = function() cursor = nil end
_G.NUM_BAG_SLOTS, _G.NUM_BANKBAGSLOTS, _G.BANK_CONTAINER = 4, 7, -1
_G.SlashCmdList = {}
_G.GetContainerNumSlots = function(bag) return world[bag] and world[bag].size or 0 end
_G.GetContainerNumFreeSlots = function(bag)
    local c = world[bag]
    if not c then return 0, 0 end
    local free = 0
    for s = 1, c.size do if not c.slots[s] then free = free + 1 end end
    return free, c.family
end
_G.GetContainerItemInfo = function(bag, slot)
    local item = at(bag, slot)
    if not item then return end
    return "icon", item.count, item.lockedUntil > clock
end
_G.GetContainerItemLink = function(bag, slot)
    local item = at(bag, slot)
    return item and ("|cffffffff|Hitem:%d:0:0:0:0:0:0:0:80|h[x]|h|r"):format(item.id)
end
_G.GetItemInfo = function(id)
    local d = DB[id]
    if not d then return end
    return d[1], "link", d[4], d[5], 1, d[2], d[3], d[6], d[7]
end
_G.GetItemFamily = function(id) return DB[id] and DB[id][8] end
-- Like the real client: the drop only locks the items (an empty destination has nothing to lock) and sends the
-- move; the server applies it LATENCY later, and the unlock arrives before the new contents (worst case).
local LATENCY = 0.18
local inflight = {}
local refuseClient, refuseServer = {}, {} -- [bag][itemID]: a crafting bag that says no despite its family
local serverRule = {}                      -- [bag] = function(itemID) -> accepted (server crafting bag, family 0)
local bagItems = {}                        -- [bag] = { id, name }: the bag item in that container slot
_G.ContainerIDToInventoryID = function(bag) return 100 + bag end
_G.GetInventoryItemLink = function(_, slot)
    local b = bagItems[slot - 100]
    return b and ("|cff0070dd|Hitem:%d:0:0:0:0:0:0:0:80|h[%s]|h|r"):format(b[1], b[2])
end
local function serverApply(m)
    local from, item = at(m.fb, m.fs), at(m.b, m.s)
    if not from then return end
    local function refused(bag, id)
        return (refuseServer[bag] and refuseServer[bag][id]) or (serverRule[bag] and not serverRule[bag](id))
    end
    if refused(m.b, from.id) or (item and refused(m.fb, item.id)) then
        return
    end
    if not item then
        world[m.b].slots[m.s], world[m.fb].slots[m.fs] = from, nil
    elseif item.id == from.id and DB[from.id][6] > 1 and item.count < DB[from.id][6] then
        local moved = math.min(DB[from.id][6] - item.count, from.count)
        item.count, from.count = item.count + moved, from.count - moved
        if from.count == 0 then world[m.fb].slots[m.fs] = nil end
    else
        world[m.b].slots[m.s], world[m.fb].slots[m.fs] = from, item
    end
end
local function serverTick()
    local keep = {}
    for _, m in ipairs(inflight) do
        if m.due <= clock then serverApply(m) else keep[#keep + 1] = m end
    end
    inflight = keep
end
_G.PickupContainerItem = track("PickupContainerItem", function(bag, slot)
    local item = at(bag, slot)
    if not cursor then
        if item and item.lockedUntil <= clock then cursor = { bag = bag, slot = slot } end
        return
    end
    if item and item.lockedUntil > clock then return end -- locked target: refused, item stays on the cursor
    local from = at(cursor.bag, cursor.slot)
    local fromBag, fromSlot = cursor.bag, cursor.slot
    if (refuseClient[bag] and refuseClient[bag][from.id]) or (item and refuseClient[fromBag] and refuseClient[fromBag][item.id]) then
        return
    end
    if not item then
        if not fitsIn(from.id, world[bag].family) then return end
    elseif not (item.id == from.id and DB[from.id][6] > 1 and item.count < DB[from.id][6]) then
        if not fitsIn(from.id, world[bag].family) or not fitsIn(item.id, world[fromBag].family) then return end
    end
    local unlock = clock + LATENCY * 0.6
    from.lockedUntil = unlock
    if item then item.lockedUntil = unlock end
    inflight[#inflight + 1] = { due = clock + LATENCY, fb = fromBag, fs = fromSlot, b = bag, s = slot }
    cursor = nil
end)
_G.wipe = nil

local sortUi = { L = ui.L, Print = ui.Print, Settings = ui.Settings, BagSortPlan = P,
    Bags = { Refresh = function() end } }
assert(loadfile("BagSort.lua"))("ForeverUI", sortUi)
local B = sortUi.BagSort
local driver, eventFrame
for _, f in ipairs(frames) do
    if f.scripts.OnUpdate then driver = f end
    if f.scripts.OnEvent then eventFrame = f end
end
check(driver and eventFrame, "executor: driver and event frames")

local function tick(n)
    for _ = 1, n or 1 do
        clock = clock + 0.05
        serverTick()
        if driver.shown then driver.scripts.OnUpdate(driver, 0.05) end
    end
end
local function runUntilIdle(limit)
    for t = 1, limit or 2000 do
        if not B.Busy() then return t end
        tick()
    end
    return nil
end
local function worldSorted(groupA)
    local S = B.Scan(groupA)
    local Q = P.NewQueue()
    P.StackMoves(S, groupA, B.ItemInfo, Q)
    if Q.n > 0 then return false end
    P.SortMoves(S, groupA, B.ItemInfo, B.SortOptions(groupA == 3), Q)
    return Q.n == 0
end

-- The real groups and blocks match the planner tests above.
for _, id in ipairs(ALL) do
    local r, group, block = B.ItemInfo(id), groupOf(id)
    check(r.group == group and r.block == block, ("item groups: %d is %s/%s, want %d/%d"):format(id,
        tostring(r.group), tostring(r.block), group, block))
    check(r.level == levelRank[group], ("item level order: %d is %s"):format(id, tostring(r.level)))
end
local function worldTotals()
    local t = {}
    for _, c in pairs(world) do
        for s = 1, c.size do
            local item = c.slots[s]
            if item then t[item.id] = (t[item.id] or 0) + item.count end
        end
    end
    return t
end

-- Bags: backpack 16, ordinary 12, herb bag 8, mining bag 6.
container(0, 16) container(1, 12) container(2, 8, 32) container(3, 6, 1024)
math.randomseed(777)
for bag = 0, 3 do
    for slot = 1, world[bag].size do
        if math.random() < 0.6 then
            local options = {}
            for _, id in ipairs(ALL) do if fitsIn(id, world[bag].family) then options[#options + 1] = id end end
            local id = options[math.random(#options)]
            place(bag, slot, id, math.random(DB[id][6]))
        end
    end
end
local before = worldTotals()
settings.bagSortBatch = 2
check(B.Start("bags"), "executor: started")
check(not B.Start("bags"), "executor: second start refused while running")
-- Loot arrives in the middle of the sort.
tick(6)
for slot = 1, 16 do
    if not world[0].slots[slot] then place(0, slot, 80, 1) before[80] = (before[80] or 0) + 1 break end
end
-- Combat pauses the sort.
combat = true
local moved = 0
local count = 0
for _ = 1, 10 do
    local snapshot = 0
    for _, c in pairs(world) do for s = 1, c.size do if c.slots[s] then snapshot = snapshot + s * c.slots[s].id end end end
    tick()
    local after = 0
    for _, c in pairs(world) do for s = 1, c.size do if c.slots[s] then after = after + s * c.slots[s].id end end end
    if after ~= snapshot then moved = moved + 1 end
    count = count + 1
end
check(moved == 0, "executor: nothing moves in combat")
combat = false
local ticks = runUntilIdle()
check(ticks ~= nil, "executor: finished")
check(same(before, worldTotals()), "executor: nothing lost")
check(worldSorted(1), "executor: bags end sorted and stacked")
check(cursor == nil, "executor: cursor empty")
local finished = prints[#prints] or ""
check(finished:find("Сумки отсортированы", 1, true) ~= nil, "executor: done message, got " .. finished)
check(B.Start("bags") and runUntilIdle() and (prints[#prints] or ""):find("уже в порядке", 1, true) ~= nil,
    "executor: second run says already in order")

-- Bank: deposit needs an open bank, stops when it closes.
container(-1, 6) container(5, 4, 32)
place(-1, 1, 10, 3)
local herbsInBags = 0
for bag = 0, 3 do
    for slot = 1, world[bag].size do
        local item = world[bag].slots[slot]
        if item and item.id == 10 then herbsInBags = herbsInBags + item.count end
    end
end
check(not B.Start("deposit"), "bank: refused while the bank is closed")
eventFrame.scripts.OnEvent(eventFrame, "BANKFRAME_OPENED")
check(B.Start("deposit"), "bank: deposit started")
check(runUntilIdle(), "bank: deposit finished")
local bankHerbs = 0
for _, bag in ipairs({ -1, 5 }) do
    for slot = 1, world[bag].size do
        local item = world[bag].slots[slot]
        if item and item.id == 10 then bankHerbs = bankHerbs + item.count end
    end
end
check(herbsInBags == 0 or bankHerbs > 3, "bank: herbs moved into the bank (" .. bankHerbs .. ")")
check(B.Start("bank"), "bank: sort started")
tick(1)
eventFrame.scripts.OnEvent(eventFrame, "BANKFRAME_CLOSED")
check(not B.Busy(), "bank: closing the bank stops the run")
check((prints[#prints] or ""):find("Банк закрыт", 1, true) ~= nil, "bank: closed message")

-- A crafting bag that refuses items its family says it takes (client-side and server-side refusal):
-- the run must end, leave those items in place and say so.
for _, side in ipairs({ "client", "server" }) do
    for k in pairs(world) do world[k] = nil end
    refuseClient, refuseServer = {}, {}
    container(0, 8) container(1, 4, 32)
    place(0, 1, 1, 1)
    place(0, 2, 11, 7)
    place(0, 3, 10, 9)
    place(0, 5, 80, 2)
    if side == "client" then refuseClient[1] = { [11] = true } else refuseServer[1] = { [11] = true } end
    local herbs = worldTotals()
    check(B.Start("bags"), side .. " refusal: started")
    check(runUntilIdle(), side .. " refusal: finished")
    local text = prints[#prints] or ""
    check(text:find("Сумки отсортированы", 1, true) ~= nil and text:find("не принял 1", 1, true) ~= nil,
        side .. " refusal: done with one refusal reported, got " .. text)
    check(same(herbs, worldTotals()), side .. " refusal: nothing lost")
    local inBag = {}
    for slot = 1, 4 do local item = world[1].slots[slot] if item then inBag[item.id] = true end end
    check(inBag[10] and not inBag[11], side .. " refusal: the accepted herb is in the crafting bag, the refused one is not")
    check(cursor == nil, side .. " refusal: cursor empty")
end

-- Server crafting bags that the client reports as ordinary (family 0), like Nozdor's
-- «Сумка ремесленника вечности»: the server takes only trade goods and gems there.
local function tradeOrGem(id) return DB[id][2] == "Хозяйственные товары" or DB[id][2] == "Самоцветы" end
local function fresh()
    for k in pairs(world) do world[k] = nil end
    for k in pairs(bagItems) do bagItems[k] = nil end
    for k in pairs(serverRule) do serverRule[k] = nil end
    refuseClient, refuseServer = {}, {}
end
local function contents(bag)
    local ids = {}
    for slot = 1, world[bag].size do local item = world[bag].slots[slot] if item then ids[item.id] = true end end
    return ids
end

-- (a) Recognised by its name: filled first with trade goods, nothing refused, gem class learned from contents.
fresh()
settings.bagSortCustomBags = nil
container(0, 8) container(1, 6) container(2, 4)
bagItems[1] = { 90001, "Сумка ремесленника вечности" }
serverRule[1] = tradeOrGem
place(0, 1, 80, 3) place(0, 2, 10, 5) place(0, 3, 1, 1) place(0, 4, 20, 7) place(2, 1, 6948, 1) place(1, 4, 30, 2)
place(2, 2, 11, 9)
local totalsBefore = worldTotals()
check(B.Start("bags") and runUntilIdle(), "crafting bag: finished")
local text = prints[#prints] or ""
check(text:find("Сумки отсортированы", 1, true) and not text:find("не принял", 1, true),
    "crafting bag: sorted without refusals, got " .. text)
check(same(totalsBefore, worldTotals()), "crafting bag: nothing lost")
local inBag = contents(1)
check(inBag[10] and inBag[11] and inBag[20] and inBag[30], "crafting bag: herbs, ore and gems inside")
check(not inBag[80] and not inBag[1] and not inBag[6948], "crafting bag: potion, sword, hearthstone outside")
local rule = settings.bagSortCustomBags and settings.bagSortCustomBags[90001]
check(rule and rule.accept["Самоцветы"], "crafting bag: class of its contents learned and saved")
check(B.Start("bags") and runUntilIdle() and (prints[#prints] or ""):find("уже в порядке", 1, true),
    "crafting bag: second run already in order")

-- (b) Unknown name: the first refusal turns it into a crafting bag; potions never go there again.
fresh()
settings.bagSortCustomBags = nil
container(0, 6) container(1, 6)
bagItems[1] = { 90002, "Странная сумка" }
serverRule[1] = tradeOrGem
place(1, 1, 10, 4) place(0, 2, 80, 3) place(0, 1, 1, 1) place(0, 5, 3, 1) place(0, 6, 20, 2) place(0, 4, 70, 1)
place(0, 3, 2, 1)
totalsBefore = worldTotals()
check(B.Start("bags") and runUntilIdle(), "learned bag: finished")
text = prints[#prints] or ""
check(text:find("Сумки отсортированы", 1, true) and not text:find("не принял", 1, true),
    "learned bag: refusals were learned, not left in place, got " .. text)
check(same(totalsBefore, worldTotals()), "learned bag: nothing lost")
rule = settings.bagSortCustomBags and settings.bagSortCustomBags[90002]
check(rule and rule.accept["Хозяйственные товары"] and next(rule.deny) ~= nil, "learned bag: rule saved")
inBag = contents(1)
check(inBag[10] and inBag[20], "learned bag: trade goods moved in")
for id in pairs(inBag) do check(tradeOrGem(id), "learned bag: only accepted items inside (" .. id .. ")") end
check(B.Start("bags") and runUntilIdle() and (prints[#prints] or ""):find("уже в порядке", 1, true),
    "learned bag: second run already in order")
fresh()

-- /fuisort scan names the resource subclasses that got no block.
container(0, 4)
place(0, 1, 40, 2) place(0, 2, 20, 2)
_G.SlashCmdList.FOREVERUISORT("scan")
local loose
for _, line in ipairs(prints) do if line:find("resources without a block", 1, true) then loose = line end end
check(loose and loose:find("Другое", 1, true) and not loose:find("Металл", 1, true), "scan: loose resource subclasses, got "
    .. tostring(loose))
fresh()

-- Guild bank: the open tab is container GUILD_BASE + tab in the mock world (98 ordinary slots); the server counts
-- withdrawals (tab → bags moves) and refuses them past the daily limit.
local GB = B.GUILD_BASE
local guildTabNow, guildRemaining, guildCanDeposit = 1, -1, true
_G.MAX_GUILDBANK_SLOTS_PER_TAB = 98
_G.GetCurrentGuildBankTab = function() return guildTabNow end
_G.GetGuildBankTabInfo = function() return "ГБ", "icon", true, guildCanDeposit, 5, guildRemaining end
_G.GetGuildBankItemInfo = function(tab, slot) return GetContainerItemInfo(GB + tab, slot) end
_G.GetGuildBankItemLink = function(tab, slot) return GetContainerItemLink(GB + tab, slot) end
_G.PickupGuildBankItem = track("PickupGuildBankItem", function(tab, slot) PickupContainerItem(GB + tab, slot) end)
-- Like Nozdor (seen in game): the server handles one guild bank move at a time and drops a move that arrives while
-- the previous one is still being handled (the items just stay where they are).
local plainApply = serverApply
local lastGuildDue, guildSwaps, guildDropped = 0, 0, 0
local GUILD_THROTTLE = 0.9
serverApply = function(m)
    if m.fb > GB or m.b > GB then
        -- Throttle (third log from the game): a move sent sooner than GUILD_THROTTLE after the last one landed is
        -- dropped too.
        if m.due - LATENCY < lastGuildDue + GUILD_THROTTLE then guildDropped = guildDropped + 1 return end
        lastGuildDue = m.due
        -- Also seen in game: two occupied guild slots are never swapped (a move into an empty slot or onto a
        -- partial stack of the same item works).
        local from, item = at(m.fb, m.fs), at(m.b, m.s)
        if from and item and not (item.id == from.id and item.count < DB[item.id][6]) then
            guildSwaps = guildSwaps + 1
            return
        end
    end
    if m.fb > GB and m.b <= GB and guildRemaining >= 0 then
        if guildRemaining == 0 then return end
        guildRemaining = guildRemaining - 1
    end
    plainApply(m)
end
local function guildTotals()
    local t = {}
    for slot = 1, 98 do
        local item = world[GB + 1].slots[slot]
        if item then t[item.id] = (t[item.id] or 0) + item.count end
    end
    return t
end

-- Planner, noSwap (guild tab): random tabs end sorted, every move goes into an empty slot or onto a partial stack.
do
    local swaps, unsorted, lost = 0, 0, 0
    for case = 1, 60 do
        local S = newState({ { family = 0, size = 98, group = 3 } })
        local fill = case % 3 == 0 and 0.97 or math.random() * 0.9
        for i = 1, 98 do
            if math.random() < fill then
                local id = ALL[math.random(#ALL)]
                put(S, i, id, math.random(DB[id][6]))
            end
        end
        local before = totals(S, 3)
        local Q = P.NewQueue()
        for _ = 1, 6 do
            P.ResetQueue(Q)
            P.StackMoves(S, 3, info, Q)
            if Q.n == 0 then P.SortMoves(S, 3, info, { noSwap = true }, Q) end
            if Q.n == 0 then break end
            for k = 1, Q.n do
                local d = Q.dst[k]
                if Q.did[k] and not (Q.did[k] == Q.sid[k] and Q.dcount[k] < DB[Q.sid[k]][6]) then swaps = swaps + 1 end
                apply(S, Q, k)
            end
        end
        P.ResetQueue(Q)
        P.StackMoves(S, 3, info, Q)
        if Q.n == 0 then P.SortMoves(S, 3, info, { noSwap = true }, Q) end
        if Q.n > 0 then unsorted = unsorted + 1 end
        if not same(before, totals(S, 3)) then lost = lost + 1 end
    end
    check(swaps == 0, "noSwap: no swap of two occupied slots (" .. swaps .. ")")
    check(unsorted == 0, "noSwap: every tab ends sorted (" .. unsorted .. " not)")
    check(lost == 0, "noSwap: nothing lost (" .. lost .. ")")
end

-- Planner: deposit and withdraw take the bank group, withdraw stops at the limit.
do
    local S = newState({ { family = 0, size = 4, group = 1 }, { family = 0, size = 4, group = 3 } })
    put(S, 1, 10, 5) put(S, 2, 20, 3) put(S, 5, 10, 18) put(S, 6, 20, 2) put(S, 7, 20, 2)
    local Q = P.NewQueue()
    P.DepositMoves(S, info, Q, 3)
    local intoTab = Q.n == 3
    for k = 1, Q.n do intoTab = intoTab and S.group[Q.dst[k]] == 3 and S.group[Q.src[k]] == 1 end
    check(intoTab, "guild plan: deposit into group 3 (" .. Q.n .. ")")
    P.ResetQueue(Q)
    P.WithdrawMoves(S, info, Q, 3)
    local unlimited = Q.n
    P.ResetQueue(Q)
    P.WithdrawMoves(S, info, Q, 3, 1)
    check(unlimited >= 2 and Q.n == 1 and S.group[Q.src[1]] == 3, "guild plan: withdraw limit (" .. unlimited .. "/" .. Q.n .. ")")
end

container(0, 16)
container(GB + 1, 98)
math.randomseed(4242)
for slot = 1, 98 do
    if math.random() < 0.5 then
        local id = ALL[math.random(#ALL)]
        place(GB + 1, slot, id, math.random(DB[id][6]))
    end
end
local guildBefore = guildTotals()
check(not B.Start("guild"), "guild: refused while the guild bank is closed")
eventFrame.scripts.OnEvent(eventFrame, "GUILDBANKFRAME_OPENED")
check(B.GuildOpen(), "guild: open after GUILDBANKFRAME_OPENED")
used.PickupGuildBankItem = nil
check(B.Start("guild") and runUntilIdle(6000), "guild: tab sort finished")
check(used.PickupGuildBankItem, "guild: moves go through PickupGuildBankItem")
check(guildDropped > 0, "guild: the throttle was hit and retried (" .. guildDropped .. ")")
check(same(guildBefore, guildTotals()), "guild: nothing lost on the tab")
check(worldSorted(3), "guild: tab ends sorted and stacked")
check((prints[#prints] or ""):find("Вкладка банка гильдии отсортирована", 1, true) ~= nil
    and not (prints[#prints] or ""):find("не принял", 1, true),
    "guild: done message without refusals, got " .. tostring(prints[#prints]))
check(cursor == nil, "guild: cursor empty")

-- Deposit: herbs from the bags go onto the tab's herb stack.
for k in pairs(world[GB + 1].slots) do world[GB + 1].slots[k] = nil end
for k in pairs(world[0].slots) do world[0].slots[k] = nil end
place(GB + 1, 1, 10, 5) place(0, 3, 10, 18) place(0, 4, 10, 4) place(0, 5, 80, 2)
guildCanDeposit = false
check(not B.Start("guilddeposit"), "guild: deposit refused without the right to deposit")
guildCanDeposit = true
check(B.Start("guilddeposit") and runUntilIdle(), "guild: deposit finished")
local inBags = 0
for slot = 1, 16 do local item = world[0].slots[slot] if item and item.id == 10 then inBags = inBags + item.count end end
check(inBags == 0 and guildTotals()[10] == 27 and guildTotals()[80] == nil, "guild: herbs deposited, potion kept")

-- Withdraw with one withdrawal left: one move, then the limit is reported.
for k in pairs(world[0].slots) do world[0].slots[k] = nil end
place(0, 1, 20, 3)
place(GB + 1, 2, 20, 2) place(GB + 1, 3, 20, 2) place(GB + 1, 4, 20, 2)
guildRemaining = 1
check(B.Start("guildwithdraw") and runUntilIdle(), "guild: withdraw finished")
check(world[0].slots[1].count == 5, "guild: one stack withdrawn (" .. world[0].slots[1].count .. ")")
check((prints[#prints] or ""):find("лимит", 1, true) ~= nil, "guild: limit reported, got " .. tostring(prints[#prints]))
check(not B.Start("guildwithdraw"), "guild: withdraw refused with no withdrawals left")
guildRemaining = -1

-- Switching the tab or closing the guild bank stops the run.
place(GB + 1, 90, 1, 1) place(GB + 1, 50, 2, 1)
check(B.Start("guild"), "guild: started again")
tick(1)
guildTabNow = 2
tick(2)
check(not B.Busy() and (prints[#prints] or ""):find("другая вкладка", 1, true) ~= nil, "guild: tab switch stops the run")
guildTabNow = 1
check(B.Start("guild"), "guild: started once more")
eventFrame.scripts.OnEvent(eventFrame, "GUILDBANKFRAME_CLOSED")
check(not B.Busy() and (prints[#prints] or ""):find("Банк гильдии закрыт", 1, true) ~= nil, "guild: closing stops the run")
fresh()

-- Forbidden APIs.
for _, path in ipairs({ "BagSort.lua", "BagSortPlan.lua", "Options/BagSort.lua" }) do
    local file = assert(io.open(path, "r"))
    local text = file:read("*a")
    file:close()
    for _, bad in ipairs({ "C_Timer", "SetShown%(", "SetColorTexture", "C_Container", "GetAuctionItem" }) do
        check(not text:find(bad), path .. " uses " .. bad)
    end
end

if failures > 0 then
    error(failures .. " bag sort check(s) failed")
end
print("BagSort tests passed")
