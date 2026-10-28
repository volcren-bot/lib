--!strict
-- Outlines the Ferry's model for two minutes, projected by the client, to compare with local projection.
local NAME = "Ferry"
local SECONDS = 120

local Host = require("../host")
local time = Host.time
local sleep = Host.sleep
local Draw = require("../utils/draw")
local Geometry = require("../utils/math/geometry")
local Objects = require("../main/entities/objects")
local Walker = require("../main/walker")
type Point = Geometry.Point

local me = assert(Walker.position())
local loc = Objects.nearest(NAME, me)
if loc == nil then
	print(`no {NAME} around`)
	return
end

local COLOR = Draw.CYAN
local ERASE = Draw.color(0, 0, 0, 0)

-- Each triangle edge once (neighbouring faces share them).
local function edges(faces: { { Point } }): { { Point } }
	local seen: { [string]: boolean } = {}
	local out: { { Point } } = {}
	for _, f in ipairs(faces) do
		for i = 1, 3 do
			local a, b = f[i], f[i % 3 + 1]
			local ka, kb = `{a.x},{a.y}`, `{b.x},{b.y}`
			local key = if ka < kb then ka .. "|" .. kb else kb .. "|" .. ka
			if not seen[key] then
				seen[key] = true
				table.insert(out, { a, b })
			end
		end
	end
	return out
end

local function draw(lines: { { Point } }, color: Draw.Color)
	for _, l in ipairs(lines) do
		Draw.line(l[1], l[2], color)
	end
end

local last: { { Point } }? = nil
local frames, projecting, drawing = 0, 0, 0
local started = time()
while time() - started < SECONDS * 1000 do
	local t0 = time()
	local model = Objects.model(loc)
	local t1 = time()
	if model then
		local lines = edges(model.faces)
		if last then
			draw(last, ERASE)
		end
		draw(lines, COLOR)
		last = lines
	end
	frames += 1
	projecting += t1 - t0
	drawing += time() - t1
	sleep(5)
end
if last then
	draw(last, ERASE)
end
local elapsed = (time() - started) / 1000
print(
	string.format(
		"%d frames in %.1f s (%.0f/s): %.2f ms projecting, %.2f ms drawing per frame",
		frames,
		elapsed,
		frames / elapsed,
		projecting / frames,
		drawing / frames
	)
)
