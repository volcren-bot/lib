--!strict
local Host = require("@lib/host")

local NpcHealth = {}

NpcHealth.HIT = 16
NpcHealth.BLOCK = 12

NpcHealth.GROUP = 303
NpcHealth.NAME_CHILD = 9
NpcHealth.HP_CHILD = 21

type Track = {
	damage: number,
	max: number?,
	counted: { [string]: boolean },
}

local tracks: { [number]: Track } = {}

local function track_of(index: number): Track
	local track = tracks[index]
	if track == nil then
		local fresh: Track = { damage = 0, max = nil, counted = {} }
		track = fresh
		tracks[index] = track
	end
	return track
end

function NpcHealth.update(indices: { number })
	local present: { [number]: boolean } = {}
	for _, index in ipairs(indices) do
		present[index] = true
	end
	for index in pairs(tracks) do
		if not present[index] then
			tracks[index] = nil
		end
	end
	local splats = Host.npc_hitsplats(indices) or {}
	for _, index in ipairs(indices) do
		local track = track_of(index)
		for _, splat in ipairs(splats[index] or {}) do
			local key = `{splat.slot}:{splat.cycle}`
			if not track.counted[key] then
				track.counted[key] = true
				if splat.kind == NpcHealth.HIT or splat.kind == NpcHealth.BLOCK then
					track.damage += splat.damage
				end
			end
		end
	end
end

function NpcHealth.target(): (string?, number?, number?)
	local name = Host.widget(NpcHealth.GROUP, NpcHealth.NAME_CHILD)
	local health = Host.widget(NpcHealth.GROUP, NpcHealth.HP_CHILD)
	if name == nil or health == nil or name.hidden or health.hidden or health.text == nil then
		return nil, nil, nil
	end
	local current, max = string.match(health.text, "(%d+)%s*/%s*(%d+)")
	if current == nil or max == nil then
		return nil, nil, nil
	end
	return name.text, tonumber(current), tonumber(max)
end

function NpcHealth.set(index: number, hp: number, max_hp: number)
	local track = track_of(index)
	track.damage = max_hp - hp
	track.max = max_hp
end

function NpcHealth.max_hp(index: number): number?
	local track = tracks[index]
	return if track then track.max else nil
end

function NpcHealth.damage(index: number): number
	local track = tracks[index]
	return if track then track.damage else 0
end

function NpcHealth.remaining(index: number, max_hp: number): number
	return math.max(0, max_hp - NpcHealth.damage(index))
end

function NpcHealth.fraction(index: number, max_hp: number): number
	return NpcHealth.remaining(index, max_hp) / max_hp
end

function NpcHealth.reset()
	tracks = {}
end

return NpcHealth
