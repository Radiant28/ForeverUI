-- Retail layout geometry. Run from the addon root (see INDEX.md).
local ui = {}
assert(loadfile("EditLayouts.lua"))("ForeverUI", ui)

local function item(w, h, extra)
    local e = { shown = true, w = w, h = h, ox = 0, oy = 0, fw = w, fh = h, scale = 1 }
    for k, v in pairs(extra or {}) do e[k] = v end
    return e
end
local m = {
    xp = item(1024, 10), xpMax = item(1024, 10, { shown = false }),
    -- the stock main bar is 1024 wide, but its buttons only cover 498 starting 8 px from the left
    main = item(498, 36, { fw = 1024, fh = 53, ox = 8, oy = 4 }),
    bl = item(498, 36), br = item(498, 36), stance = item(110, 36), pet = item(370, 36), totem = item(300, 40),
    micro = item(200, 30), bags = item(160, 40),
}
local out = ui.ComputeRetailLayout(m, 1920)

-- xp bar resized (not scaled) to the stack width and centred at the bottom
assert(out.xp.resizeWidth == 498 and out.xp.scale == nil and out.xp.width == 498)
assert(math.abs(out.xp.left + 498 / 2 - 960) < 1e-9 and out.xp.bottom == 6)
-- stacked bars, centred, each above the previous one
local mainBottom = out.main.bottom + m.main.oy
assert(mainBottom > out.xp.bottom + 10, "main above xp")
assert(math.abs(out.main.left + m.main.ox + 249 - 960) < 1e-9, "main buttons centred")
assert(out.bl.bottom > mainBottom + 36 - 1 and out.br.bottom > out.bl.bottom + 36 - 1, "rows ascend")
-- top row above the stack
assert(out.stance.bottom > out.br.bottom + 36 - 1 and out.pet.bottom == out.stance.bottom and out.totem.bottom == out.stance.bottom)
assert(out.stance.left == 960 - 249 and out.pet.left + 370 == 960 + 249)
assert(math.abs(out.totem.left + 150 - 960) < 1e-9)
-- corner
assert(out.micro.left + 200 == 1910 and out.micro.bottom == 6)
assert(out.bags.left + 160 == 1910 and out.bags.bottom == out.micro.bottom + 30 + 4, "bags right above the micro menu")

-- a hidden bottom bar collapses the stack
m.bl.shown = false
local collapsed = ui.ComputeRetailLayout(m, 1920)
assert(collapsed.bl == nil and collapsed.br.bottom == out.bl.bottom, "hidden bar leaves no gap")
-- nothing measured: no result
assert(next(ui.ComputeRetailLayout({}, 1920)) == nil)

-- action bar grids
local cols, grid, count, rows = ui.ComputeBarGrid(12, 1, false, false, 42)
assert(cols == 12 and count == 12 and rows == 1 and grid[12].x == 11 * 42 and grid[12].y == 0)
cols, grid = ui.ComputeBarGrid(12, 2, false, false, 42)
assert(cols == 6 and grid[7].x == 0 and grid[7].y == 42 and grid[12].x == 5 * 42 and grid[12].y == 42, "two rows grow upwards")
cols, grid, count, rows = ui.ComputeBarGrid(6, 12, false, false, 42)
assert(rows == 6 and cols == 1 and grid[6].y == 5 * 42 and grid[7] == nil, "rows are limited by the count")
cols, grid = ui.ComputeBarGrid(12, 12, true, true, 42)
assert(cols == 1 and grid[12].x == 0 and grid[12].y == -11 * 42, "vertical default is one column")
cols, grid = ui.ComputeBarGrid(10, 5, true, true, 42)
assert(cols == 2 and grid[2].x == -42 and grid[3].y == -42, "vertical bars grow left and down")
print("EditLayouts OK")
