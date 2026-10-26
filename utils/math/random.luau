--!strict
local Host = require("../../host")
local sleep = Host.sleep
local sleep_async = Host.sleep_async

local Random = {}

Random.CUTOFF = 5

export type Dir = "left" | "mean" | "right"

local function nz_random(): number
	return math.max(math.random(), 1.0e-320)
end

function Random.trunc(v: number): number
	if v >= 0 then
		return math.floor(v)
	end
	return math.ceil(v)
end

local function half_normal(cutoff: number): number
	local r = cutoff + 1
	while r >= cutoff do
		r = math.abs(math.sqrt(-2 * math.log(nz_random())) * math.cos(2 * math.pi * math.random()))
	end
	return r
end

function Random.float(lo: number, hi: number): number
	return lo + math.random() * (hi - lo)
end

function Random.int(lo: number, hi: number): number
	return Random.trunc(Random.float(lo, hi))
end

function Random.range(lo: number, hi: number): number
	if lo > hi then
		lo, hi = hi, lo
	end
	return lo + math.floor(math.random() * (hi - lo))
end

export type Tile = { x: number, y: number }

function Random.tile_in_box(x1: number, y1: number, x2: number, y2: number): Tile
	if x1 > x2 then
		x1, x2 = x2, x1
	end
	if y1 > y2 then
		y1, y2 = y2, y1
	end
	return { x = Random.range(x1, x2 + 1), y = Random.range(y1, y2 + 1) }
end

function Random.left(lo: number, hi: number, cutoff: number?): number
	local c = cutoff or Random.CUTOFF
	return half_normal(c) / c * (hi - lo) + lo
end

function Random.right(lo: number, hi: number, cutoff: number?): number
	return Random.left(hi, lo, cutoff)
end

function Random.mode(mode: number, lo: number, hi: number, cutoff: number?): number
	local c = cutoff or Random.CUTOFF
	local top = lo
	if math.random() * (hi - lo) > mode - lo then
		top = hi
	end
	return half_normal(c) / c * (top - mode) + mode
end

function Random.mean(lo: number, hi: number, cutoff: number?): number
	return Random.mode(lo + (hi - lo) / 2, lo, hi, cutoff)
end

function Random.gauss(mean: number, dev: number): number
	local len = dev * math.sqrt(-2 * math.log(nz_random()))
	return mean + len * math.cos(2 * math.pi * math.random())
end

function Random.chance(probability: number?): boolean
	return math.random() < (probability or 0.5)
end

function Random.weighted_index(weights: { number }): number?
	local total = 0
	for _, w in ipairs(weights) do
		if w > 0 then
			total += w
		end
	end
	if total <= 0 then
		return nil
	end
	local r = math.random() * total
	local last: number? = nil
	for i, w in ipairs(weights) do
		if w > 0 then
			r -= w
			last = i
			if r < 0 then
				return i
			end
		end
	end
	return last
end

function Random.weighted<T>(items: { T }, weight: (T) -> number): T?
	local weights = table.create(#items) :: { number }
	for i, item in ipairs(items) do
		weights[i] = weight(item)
	end
	local i = Random.weighted_index(weights)
	return if i then items[i] else nil
end

function Random.nearest_weighted<T>(items: { T }, distance: (T) -> number, falloff: number): T?
	local distances = table.create(#items) :: { number }
	local closest = math.huge
	for i, item in ipairs(items) do
		distances[i] = distance(item)
		closest = math.min(closest, distances[i])
	end
	local weights = table.create(#items) :: { number }
	for i, d in ipairs(distances) do
		weights[i] = math.exp(-(d - closest) / falloff)
	end
	local i = Random.weighted_index(weights)
	return if i then items[i] else nil
end

local function duration(min: number, max: number, dir: Dir?): number
	local ms
	if dir == "mean" then
		ms = Random.int(min, max)
	elseif dir == "right" then
		ms = Random.trunc(Random.right(min, max))
	else
		ms = Random.trunc(Random.left(min, max))
	end
	return math.max(0, ms)
end

function Random.sleep(min: number, max: number, dir: Dir?)
	sleep(duration(min, max, dir))
end

function Random.sleep_async(min: number, max: number, dir: Dir?)
	sleep_async(duration(min, max, dir))
end

return Random
