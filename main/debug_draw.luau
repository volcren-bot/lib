--!strict
local Draw = require("@lib/utils/draw")
local Host = require("@lib/host")
local Projection = require("@lib/main/projection/projection")
type Tile = Projection.Tile
type Point = { x: number, y: number }

local DebugDraw = {}

local layers: { [string]: () -> () } = {}
local kinds: { [string]: Draw.Layer } = {}
local order: { string } = {}
local shown = false

function DebugDraw.on(): boolean
	return Host.script_debugging()
end

function DebugDraw.render()
	if not DebugDraw.on() or #order == 0 then
		if shown then
			shown = false
			Draw.clear()
		end
		return
	end
	shown = true
	Draw.batch(function()
		Draw.clear()
		for _, name in ipairs(order) do
			Draw.batch(layers[name], kinds[name])
		end
	end)
end

function DebugDraw.set(name: string, paint: (() -> ())?, layer: Draw.Layer?)
	if paint == nil then
		if layers[name] == nil then
			return
		end
		layers[name] = nil
		kinds[name] = nil
		table.remove(order, table.find(order, name) :: number)
	else
		if layers[name] == nil then
			table.insert(order, name)
		end
		layers[name] = paint
		kinds[name] = layer or "world"
	end
	DebugDraw.render()
end

local function key(x: number, y: number): string
	return `{x},{y}`
end

function DebugDraw.outline(tiles: { Tile }, color: Draw.Color, width: number?)
	local inside: { [string]: boolean } = {}
	for _, t in ipairs(tiles) do
		inside[key(t.x, t.y)] = true
	end
	local segments: { { Point } } = {}
	local quads = Projection.tiles(tiles)
	for i, t in ipairs(tiles) do
		local quad = quads[i]
		if quad then
			local sw, nw, ne, se = quad.top, quad.right, quad.bottom, quad.left
			if not inside[key(t.x - 1, t.y)] then
				table.insert(segments, { sw, nw })
			end
			if not inside[key(t.x, t.y + 1)] then
				table.insert(segments, { nw, ne })
			end
			if not inside[key(t.x + 1, t.y)] then
				table.insert(segments, { ne, se })
			end
			if not inside[key(t.x, t.y - 1)] then
				table.insert(segments, { se, sw })
			end
		end
	end
	if #segments > 0 then
		Draw.lines(segments, color, width)
	end
end

return DebugDraw
