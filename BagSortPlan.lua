local _, ui = ...
-- Bag sort planner: pure functions over a scanned bag state, no WoW API (tests/BagSort.lua runs them as is).
-- The scanner and the move executor live in BagSort.lua.
--
-- State S (parallel arrays, index i = one container slot, reused between runs):
--   S.n, S.bag[i], S.slot[i], S.group[i] (1 bags, 2 bank), S.family[i] (container family, 0 = ordinary bag),
--   S.fixed[i] (locked or ignored: never moved, never a target), S.id[i] (nil = empty), S.key[i] (item string
--   without unique id: equal keys are interchangeable), S.count[i].
-- info(itemID) returns a record: family, maxStack, isBag, pin, junk, classRank, subclass, equipRank, quality,
--   ilvl, name (all present; the same table for the same id while cached).
-- Queue Q: Q.n moves; move k = PickupContainerItem(src) then PickupContainerItem(dst), with the expected
--   contents before the move (sid/scount at src, did/dcount at dst; did == false means empty).

local band = bit.band
local floor = math.floor
local sort = table.sort
local wipe = wipe or function(t) for k in pairs(t) do t[k] = nil end return t end

local P = {}
ui.BagSortPlan = P

function P.NewState()
    return { n = 0, bag = {}, slot = {}, group = {}, family = {}, fixed = {}, id = {}, key = {}, count = {} }
end

function P.NewQueue()
    return { n = 0, src = {}, dst = {}, sid = {}, scount = {}, did = {}, dcount = {} }
end

function P.ResetQueue(Q) Q.n = 0 end

local function push(Q, s, d, sid, scount, did, dcount)
    local k = Q.n + 1
    Q.n = k
    Q.src[k], Q.dst[k], Q.sid[k], Q.scount[k] = s, d, sid, scount
    Q.did[k], Q.dcount[k] = did or false, did and dcount or 0
end

local function popcount(x)
    local c = 0
    while x > 0 do
        if x % 2 == 1 then c = c + 1 end
        x = floor(x / 2)
    end
    return c
end
P.popcount = popcount

-- Synthetic family bits for server crafting bags (BagSort.lua) start here, above every real WotLK family.
P.CUSTOM = 65536

-- How wide a bag family is: real profession bags first (fewest bits), server crafting bags after them.
local function breadth(family)
    local real = family % P.CUSTOM
    local c = popcount(real)
    if family >= P.CUSTOM then c = c + 16 + popcount(floor(family / P.CUSTOM)) end
    return c
end
P.breadth = breadth

-- Family bits of an item as a bag content (a bag itself reports its own family and must not "fit" into one).
local function itemFamily(info, id)
    local r = info(id)
    if r.isBag then return 0 end
    return r.family or 0
end

local function fits(info, id, containerFamily)
    if not id or containerFamily == 0 then return true end
    return band(itemFamily(info, id), containerFamily) ~= 0
end
P.Fits = fits

-- Scratch storage reused by every plan (no per-slot tables).
local cid, ccount = {}, {}
local eligible = {}
local from, tgtOf, at, where, processed = {}, {}, {}, {}, {}
local items, cand, compat, famBits, empties = {}, {}, {}, {}, {}
local stackLists, stackOrder, listPool = {}, {}, {}
local pools, poolByFamily, special = {}, {}, {}

local function markEligible(S, g)
    for i = 1, S.n do eligible[i] = not S.fixed[i] and (g == nil or S.group[i] == g) end
end

------------------------------------------------------------------------------------------------------------------
-- Comparators. They read module-level upvalues instead of closures created per sort.

local cS, cInfo, cJunkLast, cCount

local function itemBefore(a, b)
    local ia, ib = cS.id[a], cS.id[b]
    if ia ~= ib then
        local ra, rb = cInfo(ia), cInfo(ib)
        if ra.pin ~= rb.pin then return ra.pin < rb.pin end
        if cJunkLast and ra.junk ~= rb.junk then return rb.junk end
        if ra.classRank ~= rb.classRank then return ra.classRank < rb.classRank end
        if ra.subclass ~= rb.subclass then return ra.subclass < rb.subclass end
        if ra.equipRank ~= rb.equipRank then return ra.equipRank < rb.equipRank end
        if ra.quality ~= rb.quality then return ra.quality > rb.quality end
        if ra.ilvl ~= rb.ilvl then return ra.ilvl > rb.ilvl end
        if ra.name ~= rb.name then return ra.name < rb.name end
        return ia < ib
    end
    local ka, kb = cS.key[a] or "", cS.key[b] or ""
    if ka ~= kb then return ka < kb end
    local ca, cb = cS.count[a], cS.count[b]
    if ca ~= cb then return ca > cb end
    return a < b -- total order: sorting an already sorted bag moves nothing
end

local function constrainedFirst(a, b)
    local ca, cb = compat[a], compat[b]
    if ca ~= cb then return ca < cb end
    ca, cb = famBits[a], famBits[b] -- ore (one bag type) before a reagent that fits two types
    if ca ~= cb then return ca < cb end
    return itemBefore(a, b)
end

local function countDesc(a, b)
    local ca, cb = cCount[a], cCount[b]
    if ca ~= cb then return ca > cb end
    return a < b
end

local function specificFirst(a, b)
    local pa, pb = breadth(a.family), breadth(b.family)
    if pa ~= pb then return pa < pb end
    return a.first < b.first
end

------------------------------------------------------------------------------------------------------------------
-- Stacking: merge partial stacks of the same item inside group g (nil = every group).
-- Largest partial stacks receive, smallest are emptied first, so the fewest slots stay in use.

function P.StackMoves(S, g, info, Q)
    markEligible(S, g)
    local n = S.n
    for i = 1, n do cid[i], ccount[i] = S.id[i], S.count[i] end
    wipe(stackLists)
    local orders, used = 0, 0
    for i = 1, n do
        local id = cid[i]
        if id and eligible[i] then
            local max = info(id).maxStack
            if max > 1 and ccount[i] < max then
                local list = stackLists[id]
                if not list then
                    used = used + 1
                    list = listPool[used]
                    if not list then list = {} listPool[used] = list end
                    list.n = 0
                    stackLists[id] = list
                    orders = orders + 1
                    stackOrder[orders] = id
                end
                list.n = list.n + 1
                list[list.n] = i
            end
        end
    end
    local before = Q.n
    cCount = ccount
    for o = 1, orders do
        local id = stackOrder[o]
        local list = stackLists[id]
        local count = list.n
        if count > 1 then
            for k = count + 1, #list do list[k] = nil end
            sort(list, countDesc)
            local max = info(id).maxStack
            local hi, lo = 1, count
            while hi < lo do
                local t, s = list[hi], list[lo]
                local room = max - ccount[t]
                if room <= 0 then
                    hi = hi + 1
                else
                    push(Q, s, t, id, ccount[s], id, ccount[t])
                    local moved = room < ccount[s] and room or ccount[s]
                    ccount[t] = ccount[t] + moved
                    ccount[s] = ccount[s] - moved
                    if ccount[s] == 0 then
                        cid[s] = nil
                        lo = lo - 1
                    end
                    if ccount[t] >= max then hi = hi + 1 end
                end
            end
        end
    end
    return Q.n - before
end

------------------------------------------------------------------------------------------------------------------
-- Target layout. Slots of group g are split into pools by container family; items that fit a profession bag
-- (herbs, ore, gems, ammo, soul shards…) go there first, the most constrained items first and into the narrowest
-- bag; whatever does not fit falls back to the ordinary bags. Each pool is then sorted on its own.
-- Fills from[t] = the slot whose current content must end up in t (empties are matched to empties).

local function buildLayout(S, g, info, opts)
    local n = S.n
    cS, cInfo, cJunkLast = S, info, not opts or opts.junkLast ~= false
    local reverse = opts and opts.reverse

    -- Pools in slot order; one pool per container family (two herb bags make one pool).
    wipe(poolByFamily)
    local poolCount, nItems, nEmpty = 0, 0, 0
    for i = 1, n do
        if eligible[i] then
            local family = S.family[i]
            local pool = poolByFamily[family]
            if not pool then
                poolCount = poolCount + 1
                pool = pools[poolCount]
                if not pool then pool = { slots = {}, items = {} } pools[poolCount] = pool end
                pool.family, pool.first, pool.ns, pool.ni = family, i, 0, 0
                poolByFamily[family] = pool
            end
            pool.ns = pool.ns + 1
            pool.slots[pool.ns] = i
            if S.id[i] then
                nItems = nItems + 1
                items[nItems] = i
            else
                nEmpty = nEmpty + 1
                empties[nEmpty] = i
            end
        end
    end
    local nSpecial = 0
    for p = 1, poolCount do
        if pools[p].family ~= 0 then
            nSpecial = nSpecial + 1
            special[nSpecial] = pools[p]
        end
    end
    for k = nSpecial + 1, #special do special[k] = nil end
    sort(special, specificFirst)
    local general = poolByFamily[0]

    -- Profession bags first: items with the fewest matching bags go first, into the most specific bag.
    local nCand = 0
    for k = 1, nItems do
        local i = items[k]
        local family, c = itemFamily(info, S.id[i]), 0
        if family ~= 0 then
            for p = 1, nSpecial do
                if band(family, special[p].family) ~= 0 then c = c + 1 end
            end
        end
        compat[i] = c
        if c > 0 then
            famBits[i] = breadth(family)
            nCand = nCand + 1
            cand[nCand] = i
        end
    end
    for k = nCand + 1, #cand do cand[k] = nil end
    sort(cand, constrainedFirst)
    local placed = processed -- reused as a set here, wiped below before the move pass
    wipe(placed)
    for k = 1, nCand do
        local i = cand[k]
        local family = itemFamily(info, S.id[i])
        for p = 1, nSpecial do
            local pool = special[p]
            if pool.ni < pool.ns and band(family, pool.family) ~= 0 then
                pool.ni = pool.ni + 1
                pool.items[pool.ni] = i
                placed[i] = true
                break
            end
        end
    end
    local unplaced = 0
    for k = 1, nItems do
        local i = items[k]
        if not placed[i] then
            if general and general.ni < general.ns then
                general.ni = general.ni + 1
                general.items[general.ni] = i
            else
                unplaced = unplaced + 1 -- cannot happen with a consistent scan; reported as a failure
            end
        end
    end

    -- Sort each pool and lay it out (reverse: items at the end of the pool, free slots first).
    for i = 1, n do from[i] = 0 end
    for p = 1, poolCount do
        local pool = pools[p]
        local list = pool.items
        for k = pool.ni + 1, #list do list[k] = nil end
        sort(list, itemBefore)
        local offset = reverse and (pool.ns - pool.ni) or 0
        for k = 1, pool.ns do
            local j = k - offset
            if j >= 1 and j <= pool.ni then from[pool.slots[k]] = list[j] end
        end
    end

    -- Empty targets take empty sources, an empty slot that stays empty first.
    wipe(placed)
    for i = 1, n do
        if eligible[i] and from[i] == 0 and not S.id[i] then
            from[i] = i
            placed[i] = true
        end
    end
    local e = 1
    for i = 1, n do
        if eligible[i] and from[i] == 0 then
            while e <= nEmpty and placed[empties[e]] do e = e + 1 end
            local source = empties[e]
            if source then
                from[i] = source
                placed[source] = true
            end
        end
    end

    -- Interchangeable items (same key and count) stay where they are when one of them is already in place.
    wipe(tgtOf)
    for i = 1, n do
        if eligible[i] and from[i] ~= 0 then tgtOf[from[i]] = i end
    end
    for t = 1, n do
        local s = eligible[t] and from[t]
        if s and s ~= 0 and s ~= t and S.id[t] and S.id[s] and S.key[t] == S.key[s] and S.count[t] == S.count[s] then
            local u = tgtOf[t]
            if u then
                from[t], from[u] = t, s
                tgtOf[t], tgtOf[s] = t, u
            end
        end
    end
    return unplaced
end

local function swapAt(a, b)
    local oa, ob = at[a], at[b]
    at[a], at[b] = ob, oa
    where[ob], where[oa] = a, b
end

-- Moves that turn the current state into the layout: each move places at least one slot for good, so a
-- permutation cycle of k slots costs k - 1 moves (a move into an empty slot costs one). A swap is only issued when
-- both items fit the other container; otherwise the blocking item is first parked in a free slot it fits
-- (only possible between two different profession bags).
-- Returns the number of slots that could not be arranged (no free slot to park in).
function P.SortMoves(S, g, info, opts, Q)
    markEligible(S, g)
    local n = S.n
    local failures = buildLayout(S, g, info, opts)
    for i = 1, n do
        at[i], where[i] = i, i
    end
    wipe(processed)
    -- Profession bags first: once they hold their final items, nothing left in the ordinary bags belongs to a
    -- profession bag, so every swap among ordinary slots is legal and no item has to be parked there.
    for phase = 1, 2 do
        for t = 1, n do
            if eligible[t] and (S.family[t] ~= 0) == (phase == 1) then
                local need = from[t]
                local s = need ~= 0 and where[need]
                if s and s ~= t then
                    local x = at[t]
                    local xid, nid = S.id[x], S.id[need]
                    if not xid and not nid then
                        swapAt(t, s)
                    elseif not fits(info, nid, S.family[t]) then
                        failures = failures + 1
                    elseif fits(info, xid, S.family[s]) then
                        if nid then
                            push(Q, s, t, nid, S.count[need], xid, S.count[x])
                        else
                            push(Q, t, s, xid, S.count[x], nil, 0) -- t must end empty: its item goes to the free slot
                        end
                        swapAt(t, s)
                    else
                        local park
                        for u = 1, n do
                            if eligible[u] and not processed[u] and u ~= t and u ~= s and not S.id[at[u]]
                                and fits(info, xid, S.family[u]) then
                                if S.family[u] == 0 then park = u break end
                                park = park or u
                            end
                        end
                        if park then
                            push(Q, t, park, xid, S.count[x], nil, 0)
                            swapAt(t, park)
                            if nid then push(Q, s, t, nid, S.count[need], nil, 0) end
                            swapAt(t, s)
                        else
                            failures = failures + 1
                        end
                    end
                end
                processed[t] = true
            end
        end
    end
    return failures
end

-- The planned layout without moves (tests, /fuisort scan): from[t] for every slot of group g.
function P.Layout(S, g, info, opts)
    markEligible(S, g)
    local unplaced = buildLayout(S, g, info, opts)
    local copy = {}
    for i = 1, S.n do copy[i] = eligible[i] and from[i] or nil end
    return copy, unplaced
end

------------------------------------------------------------------------------------------------------------------
-- Bank transfers (group 1 = bags, group 2 = bank).

-- Best free slot of group g for an item: the narrowest profession bag it fits, else an ordinary bag.
local function freeSlot(S, g, info, id)
    local best, bestScore
    for k = 1, S.n do
        if not S.fixed[k] and S.group[k] == g and not cid[k] and fits(info, id, S.family[k]) then
            local family = S.family[k]
            local score = family == 0 and 100 or breadth(family)
            if not bestScore or score < bestScore then best, bestScore = k, score end
        end
    end
    return best
end

-- Deposit: every stackable item that the bank already holds goes to the bank: first onto its partial stacks,
-- the rest into a free bank slot (profession bags first). Returns the number of stacks that found no room.
function P.DepositMoves(S, info, Q)
    local n = S.n
    for i = 1, n do cid[i], ccount[i] = S.id[i], S.count[i] end
    local inBank = wipe(tgtOf)
    for k = 1, n do
        if S.group[k] == 2 and cid[k] then inBank[cid[k]] = true end
    end
    local failures = 0
    for b = 1, n do
        local id = cid[b]
        if id and not S.fixed[b] and S.group[b] == 1 and inBank[id] and info(id).maxStack > 1 then
            local max = info(id).maxStack
            for k = 1, n do
                if cid[b] and cid[k] == id and not S.fixed[k] and S.group[k] == 2 and ccount[k] < max then
                    push(Q, b, k, id, ccount[b], id, ccount[k])
                    local room = max - ccount[k]
                    local moved = room < ccount[b] and room or ccount[b]
                    ccount[k] = ccount[k] + moved
                    ccount[b] = ccount[b] - moved
                    if ccount[b] == 0 then cid[b] = nil end
                end
            end
            if cid[b] then
                local k = freeSlot(S, 2, info, id)
                if k then
                    push(Q, b, k, id, ccount[b], nil, 0)
                    cid[k], ccount[k] = id, ccount[b]
                    cid[b], ccount[b] = nil, 0
                else
                    failures = failures + 1
                end
            end
        end
    end
    return failures
end

-- Withdraw: partial stacks in the bags are topped up from the bank, smallest bank stacks first
-- (they free bank slots). Returns 0 (nothing can fail here).
function P.WithdrawMoves(S, info, Q)
    local n = S.n
    for i = 1, n do cid[i], ccount[i] = S.id[i], S.count[i] end
    for b = 1, n do
        local id = cid[b]
        if id and not S.fixed[b] and S.group[b] == 1 then
            local max = info(id).maxStack
            while max > 1 and ccount[b] < max do
                local source
                for k = 1, n do
                    if cid[k] == id and not S.fixed[k] and S.group[k] == 2
                        and (not source or ccount[k] < ccount[source]) then
                        source = k
                    end
                end
                if not source then break end
                push(Q, source, b, id, ccount[source], id, ccount[b])
                local room = max - ccount[b]
                local moved = room < ccount[source] and room or ccount[source]
                ccount[b] = ccount[b] + moved
                ccount[source] = ccount[source] - moved
                if ccount[source] == 0 then cid[source] = nil end
            end
        end
    end
    return 0
end
