--!strict
local Host = require("../../host")

-- Reading how hurt an NPC is. The game client shows the exact hitpoints of the NPC you are fighting in its target
-- display (top left), and only that one: `target` reads it, and `set` takes it as the truth for that NPC. For the
-- others this adds up the damage of every hit it sees (hitsplats) from there: call `update` every tick with the NPCs
-- around, then ask for the damage, or the hitpoints left. An NPC already hurt when it is first seen counts from
-- there on, until it is the one you fight.
local NpcHealth = {}

-- the hitsplat types that carry damage: a hit, and a block (which shows 0)
NpcHealth.HIT = 16
NpcHealth.BLOCK = 12

-- the target display: its interface, the child with the NPC's name and the one with "hitpoints / maximum"
NpcHealth.GROUP = 303
NpcHealth.NAME_CHILD = 9
NpcHealth.HP_CHILD = 21

type Track = {
	damage: number,
	-- its maximum hitpoints when the target display showed them
	max: number?,
	-- the hits already added, by slot and cycle
	counted: { [string]: boolean },
}

local tracks: { [number]: Track } = {}

-- Reads the hitsplats of the NPCs with `indices` and adds the new hits. Forgets the NPCs not in the list. Call it
-- at least once a tick: a hitsplat is replaced by the next hit in its slot.
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
		local track = tracks[index]
		if track == nil then
			local fresh: Track = { damage = 0, max = nil, counted = {} }
			track = fresh
			tracks[index] = track
		end
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

-- The name, hitpoints and maximum hitpoints the target display shows (the NPC you are fighting), or nil when it
-- shows none.
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

-- Takes `hp` of `max_hp` as the truth for the NPC with `index` (what `target` shows for the NPC you fight): the
-- damage seen before and any healing are corrected, and the hits seen after count from here.
function NpcHealth.set(index: number, hp: number, max_hp: number)
	local track = tracks[index]
	if track == nil then
		local fresh: Track = { damage = 0, max = nil, counted = {} }
		track = fresh
		tracks[index] = track
	end
	track.damage = max_hp - hp
	track.max = max_hp
end

-- The maximum hitpoints the target display showed for the NPC, nil when it never did.
function NpcHealth.max_hp(index: number): number?
	local track = tracks[index]
	return if track then track.max else nil
end

-- The damage seen on the NPC so far, 0 for one not seen.
function NpcHealth.damage(index: number): number
	local track = tracks[index]
	return if track then track.damage else 0
end

-- The hitpoints left of an NPC with `max_hp` hitpoints, at least 0.
function NpcHealth.remaining(index: number, max_hp: number): number
	return math.max(0, max_hp - NpcHealth.damage(index))
end

-- How much of its hitpoints an NPC with `max_hp` has left, from 1 (unhurt) to 0.
function NpcHealth.fraction(index: number, max_hp: number): number
	return NpcHealth.remaining(index, max_hp) / max_hp
end

-- Forgets everything seen (a new fight).
function NpcHealth.reset()
	tracks = {}
end

return NpcHealth
