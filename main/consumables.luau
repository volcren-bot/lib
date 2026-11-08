--!strict
local Host = require("@lib/host")
local game_state = Host.game_state
local Varbits = require("@lib/main/varbits")
local Varps = require("@lib/main/varps")

-- A level the way `result` sees it: skills by name, plus "Run energy" and "Special attack" in percent (real 100).
export type Level = { level: number, real: number }
export type Levels = { [string]: Level }

export type Change = {
	stat: string,
	flat: number,
	-- of the real level (or of the current one with `of_current`), signed; the part is rounded toward zero
	percent: number,
	of_current: boolean?,
	-- may raise the stat above its real level, by up to the amount
	boost: boolean?,
	-- the flat part is anywhere from `flat` to `up_to`
	up_to: number?,
	-- ticks after the rest of the item's changes
	later: number?,
	-- replaces `flat` and `percent`
	amount: ((levels: Levels) -> number)?,
}

-- A timed effect (`ticks` per dose when known) or a cure the item gives besides its changes.
export type Special = { name: string, ticks: number? }

export type Consumable = {
	name: string,
	ids: { number },
	option: string,
	changes: { Change },
	special: { Special },
	-- ignores the eating delay of other food, like karambwan
	combo: boolean,
}

export type Outcome = { from: number, low: number, high: number }

local Consumables = {}

local function part(level: number, percent: number): number
	local p = math.floor(level * math.abs(percent))
	return if percent < 0 then -p else p
end

local NONE: Level = { level = 0, real = 0 }

local function lv(levels: Levels, stat: string): Level
	return levels[stat] or NONE
end

local function change(stat: string, flat: number, percent: number?): Change
	return { stat = stat, flat = flat, percent = percent or 0 }
end

local function restore(stat: string, flat: number, percent: number?): Change
	return change(stat, flat, percent)
end

local function boost(stat: string, flat: number, percent: number?): Change
	local c = change(stat, flat, percent)
	c.boost = true
	return c
end

local function drain(stat: string, flat: number, percent: number?): Change
	local c = change(stat, flat, percent)
	c.of_current = true
	return c
end

local function lower(stat: string, flat: number): Change
	return change(stat, -flat)
end

local function food(flat: number, percent: number?): Change
	return restore("Hitpoints", flat, percent)
end

local function food_range(flat: number, up_to: number): Change
	local c = food(flat)
	c.up_to = up_to
	return c
end

local function restore_range(stat: string, flat: number, up_to: number): Change
	local c = restore(stat, flat)
	c.up_to = up_to
	return c
end

local function later(flat: number): Change
	local c = food(flat)
	c.later = 5
	return c
end

local function custom(stat: string, raises_above_real: boolean, amount: (Levels) -> number): Change
	local c = change(stat, 0)
	c.boost = if raises_above_real then true else nil
	c.amount = amount
	return c
end

-- a boost that stops `cap` above the real level, however much the amount (haddock, ancient brew's prayer)
local function capped_boost(stat: string, flat: number, percent: number, cap: (real: number) -> number): Change
	return custom(stat, true, function(levels)
		local s = lv(levels, stat)
		local below = math.min(s.level, s.real)
		return math.min(flat + part(s.real, percent), s.real + cap(s.real) - below)
	end)
end

local RESTORED = {
	"Attack",
	"Defence",
	"Strength",
	"Ranged",
	"Magic",
	"Cooking",
	"Woodcutting",
	"Fletching",
	"Fishing",
	"Firemaking",
	"Crafting",
	"Smithing",
	"Mining",
	"Herblore",
	"Agility",
	"Thieving",
	"Slayer",
	"Farming",
	"Runecraft",
	"Hunter",
	"Construction",
}

local function prayer_potion(flat: number): Change
	return restore("Prayer", flat, 0.25)
end

local function super_restore(flat: number, percent: number): { Change }
	local list = { restore("Prayer", flat, percent) }
	for _, stat in ipairs(RESTORED) do
		table.insert(list, restore(stat, flat, percent))
	end
	return list
end

local function saradomin_brew(heal: number, defence: number, drained: number, up: number, down: number): { Change }
	local list = { boost("Hitpoints", up, heal), boost("Defence", up, defence) }
	for _, stat in ipairs({ "Attack", "Strength", "Ranged", "Magic" }) do
		table.insert(list, drain(stat, -down, -drained))
	end
	return list
end

local function ancient_brew(flat: number, percent: number): { Change }
	return {
		capped_boost("Prayer", 2, 0.1, function(real)
			return part(real, 0.05)
		end),
		boost("Magic", flat, percent),
		drain("Attack", -2, -0.1),
		drain("Strength", -2, -0.1),
		drain("Defence", -2, -0.1),
	}
end

local function stamina(flat: number): Change
	return restore("Run energy", flat)
end

local function anglerfish(): Change
	return custom("Hitpoints", true, function(levels)
		local real = lv(levels, "Hitpoints").real
		local c = if real <= 24 then 2 elseif real <= 49 then 4 elseif real <= 74 then 6 elseif real <= 92 then 8 else 13
		return math.floor(real / 10) + c
	end)
end

local function food_of_max(percent: number): Change
	return custom("Hitpoints", false, function(levels)
		return math.ceil(lv(levels, "Hitpoints").real * percent)
	end)
end

local function cooked_bream(): Change
	return custom("Hitpoints", false, function(levels)
		return math.max(7, math.min(lv(levels, "Cooking").level // 3, lv(levels, "Fishing").level // 3))
	end)
end

local function cooked_moss_lizard(): Change
	return custom("Hitpoints", false, function(levels)
		return math.min(lv(levels, "Cooking").level // 3, lv(levels, "Hunter").level // 2)
	end)
end

local function haddock(): Change
	return capped_boost("Hitpoints", 18, 0, function(real)
		return math.min(part(real, 0.2), 10)
	end)
end

local function nettle_tea_energy(): Change
	return custom("Run energy", false, function(levels)
		local hp = lv(levels, "Hitpoints")
		return if hp.level < hp.real then 5 else 0
	end)
end

-- each stat takes the strongest potion the Herblore level allows
local function moonlight_potion(): { Change }
	local function tiered(stat: string, tiers: { { number } }): Change
		return custom(stat, true, function(levels)
			local herblore = lv(levels, "Herblore").level
			for _, t in ipairs(tiers) do
				if herblore >= t[1] then
					return t[2] + part(lv(levels, stat).real, t[3])
				end
			end
			return 0
		end)
	end
	return {
		tiered("Attack", { { 45, 5, 0.15 }, { 3, 3, 0.1 } }),
		tiered("Defence", { { 70, 7, 0.2 }, { 66, 5, 0.15 }, { 30, 3, 0.1 } }),
		tiered("Strength", { { 55, 5, 0.15 }, { 12, 3, 0.1 } }),
		custom("Prayer", false, function(levels)
			local herblore = lv(levels, "Herblore").level
			if herblore < 38 then
				return 0
			end
			return math.max(part(lv(levels, "Prayer").real, 0.25), part(herblore, 0.3)) + 7
		end),
	}
end

local function ambrosia(): { Change }
	local function to_full(stat: string, flat: number, percent: number): Change
		return custom(stat, true, function(levels)
			local s = lv(levels, stat)
			return flat + part(s.real, percent) + math.max(0, s.real - s.level)
		end)
	end
	return { to_full("Hitpoints", 2, 0.25), to_full("Prayer", 5, 0.2), restore("Run energy", 100) }
end

local function cave_nightshade(): Change
	return custom("Hitpoints", false, function(levels)
		local hp = lv(levels, "Hitpoints").level
		return if hp < 20 then -(hp // 2) else -15
	end)
end

local function rock_cake_guzzle(): Change
	return custom("Hitpoints", false, function(levels)
		local hp = lv(levels, "Hitpoints").level
		return if hp <= 1 then 0 else -(hp // 10 + 1)
	end)
end

local function locator_orb(): Change
	return custom("Hitpoints", false, function(levels)
		return -math.max(0, math.min(lv(levels, "Hitpoints").level - 1, 10))
	end)
end

local function sunlight_moth(): { Change }
	local list = { food(8) }
	for _, stat in ipairs(RESTORED) do
		table.insert(list, restore(stat, 6, 0.2))
	end
	return list
end

local function special(name: string, ticks: number?): Special
	return { name = name, ticks = ticks }
end

type Extra = { special: { Special }?, combo: boolean? }

local LIST: { Consumable } = {}

local function use(option: string, name: string, ids: { number }, changes: { Change | { Change } }, extra: Extra?)
	local flat: { Change } = {}
	for _, c in ipairs(changes) do
		if (c :: any).stat ~= nil then
			table.insert(flat, c :: Change)
		else
			for _, inner in ipairs(c :: { Change }) do
				table.insert(flat, inner)
			end
		end
	end
	table.insert(LIST, {
		name = name,
		ids = ids,
		option = option,
		changes = flat,
		special = if extra and extra.special then extra.special else {} :: { Special },
		combo = extra ~= nil and extra.combo == true,
	})
end

local function eat(name: string, ids: { number }, changes: { Change | { Change } }, extra: Extra?)
	use("Eat", name, ids, changes, extra)
end

local function drink(name: string, ids: { number }, changes: { Change | { Change } }, extra: Extra?)
	use("Drink", name, ids, changes, extra)
end

-- Most of the stat changes below are from RuneLite's item stats plugin (github.com/runelite/runelite), and the
-- timers' scales from its timers and buffs plugin, under this license:
--
-- Copyright (c) 2016-2018, Adam <Adam@sigterm.info>
-- Copyright (c) 2018, Jordan Atwood <jordan.atwood423@gmail.com>
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
-- following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following
--    disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following
--    disclaimer in the documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
-- INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
-- SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
-- SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
-- WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
-- OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

eat("Poison karambwan", { 3146 }, { food(-5) })
eat("Potato", { 1942 }, { food(1) })
eat("Onion", { 1957 }, { food(1) })
eat("Cabbage", { 1965 }, { food(1) })
eat("Pot of cream", { 2130 }, { food(1) })
eat("Chopped onion", { 1871 }, { food(1) })
eat("Anchovies", { 319 }, { food(1) })
drink("Nettle-water", { 4237 }, { food(1) })
eat("Equa leaves", { 2128 }, { food(1) })
eat("Fresh monkfish", { 7943 }, { food(1) })
eat("Cooked chicken", { 4291 }, { food(1) })
eat("Cooked meat", { 4293 }, { food(1) })
eat("Tomato", { 1982 }, { food(2) })
eat("Chopped tomato", { 1869 }, { food(2) })
eat("Banana", { 1963 }, { food(2) })
eat("Sliced banana", { 3162 }, { food(2) })
eat("Orange", { 2108 }, { food(2) })
eat("Orange slices", { 2112 }, { food(2) })
eat("Orange chunks", { 2110 }, { food(2) })
eat("Pineapple ring", { 2118 }, { food(2) })
eat("Pineapple chunks", { 2116 }, { food(2) })
eat("Spicy sauce", { 7072 }, { food(2) })
eat("Cheese", { 1985 }, { food(2) })
eat("Spinach roll", { 1969 }, { food(2) })
eat("Lemon", { 2102 }, { food(2) })
eat("Lemon chunks", { 2104 }, { food(2) })
eat("Lemon slices", { 2106 }, { food(2) })
eat("Lime", { 2120 }, { food(2) })
eat("Lime chunks", { 2122 }, { food(2) })
eat("Lime slices", { 2124 }, { food(2) })
eat("Dwellberries", { 2126 }, { food(2) })
eat("King worm", { 2162 }, { food(2) })
eat("Minced meat", { 7070 }, { food(2) })
eat("Spicy tomato", { 9994 }, { food(2) })
eat("White pearl", { 4485 }, { food(2) })
eat("Shrimps", { 315 }, { food(3) })
eat("Cooked meat", { 2142 }, { food(3) })
eat("Cooked chicken", { 2140 }, { food(3) })
eat("Roe", { 11324 }, { food(3) })
eat("Chocolate bar", { 1973 }, { food(3) })
eat("Ugthanki meat", { 1861 }, { food(3) })
eat("Toad's legs", { 2152 }, { food(3) })
eat("Onion & tomato", { 1875 }, { food(3) })
eat("Spicy minced meat", { 9996 }, { food(3) })
eat("Slice of birthday cake", { 11916 }, { food(3) })
eat("Locust meat", { 9052 }, { food(3) })
drink("Relicym's mix", { 11437, 11439 }, { food(3) }, { special = { special("cure_disease") } })
drink("Antipoison mix", { 11433, 11435 }, { food(3) }, { special = { special("antipoison", 150) } })
eat("Sardine", { 325 }, { food(4) })
eat("Cake", { 1891 }, { food(4) })
eat("2/3 cake", { 1893 }, { food(4) })
eat("Slice of cake", { 1895 }, { food(4) })
drink("Chocolatey milk", { 1977 }, { food(4) })
eat("Baked potato", { 6701 }, { food(4) })
eat("Edible seaweed", { 403 }, { food(4) })
drink("Moonlight mead", { 5817, 5815, 5813, 5811, 2955 }, { food(4) })
eat("Monkey nuts", { 4012 }, { food(4) })
eat("Bread", { 2309 }, { food(5) })
eat("Herring", { 347 }, { food(5) })
eat("Chocolate cake", { 1897 }, { food(5) })
eat("2/3 chocolate cake", { 1899 }, { food(5) })
eat("Chocolate slice", { 1901 }, { food(5) })
eat("Cooked rabbit", { 3228 }, { food(5) })
eat("Chilli con carne", { 7062 }, { food(5) })
eat("Fried mushrooms", { 7082 }, { food(5) })
eat("Fried onions", { 7084 }, { food(5) })
eat("Redberry pie", { 2325 }, { food(5) })
eat("Half a redberry pie", { 2333 }, { food(5) })
eat("Caviar", { 11326 }, { food(5) })
eat("Pysk fish", { 20856 }, { food(5) })
eat("Cooked mystery meat", { 24785 }, { food(5) })
eat("Scrambled egg", { 7078 }, { food(5) })
eat("Monkey bar", { 4014 }, { food(5) })
eat("Tchiki monkey nuts", { 7573 }, { food(5) })
eat("Tchiki nut paste", { 7575 }, { food(5) })
eat("Red banana", { 7572 }, { food(5) })
eat("Sliced red banana", { 7574 }, { food(5) })
eat("Mackerel", { 355 }, { food(6) })
eat("Meat pie", { 2327 }, { food(6) })
eat("Half a meat pie", { 2331 }, { food(6) })
eat("Guanic bat", { 20871 }, { food(6) })
eat("Roast bird meat", { 9980 }, { food(6) })
eat("Square sandwich", { 6965 }, { food(6) })
eat("Roll", { 6963 }, { food(6) })
eat("Baguette", { 6961 }, { food(6) })
eat("Triangle sandwich", { 6962 }, { food(6) })
eat("Giant carp", { 337 }, { food(6) })
drink("Moonlight mead(m)", { 5749 }, { food(6) })
drink("Moonlight mead(m4)", { 5897 }, { food(6) })
drink("Moonlight mead(m3)", { 5895 }, { food(6) })
drink("Moonlight mead(m2)", { 5893 }, { food(6) })
drink("Moonlight mead(m1)", { 5891 }, { food(6) })
eat("Steak sandwich", { 25631 }, { food(6) })
eat("Giant frog legs", { 4517 }, { food(6) })
drink("Antifire mix", { 11505, 11507 }, { food(6) }, { special = { special("antifire", 600) } })
drink("Extended antifire mix", { 11960, 11962 }, { food(6) }, { special = { special("antifire", 1200) } })
drink("Super antifire mix", { 21994, 21997 }, { food(6) }, { special = { special("super_antifire", 300) } })
drink("Extended super antifire mix", { 22221, 22224 }, { food(6) }, { special = { special("super_antifire", 600) } })
drink("Anti-poison supermix", { 11473, 11475 }, { food(6) }, { special = { special("antipoison", 600) } })
drink("Antidote+ mix", { 11501, 11503 }, { food(6) }, { special = { special("antipoison", 900) } })
eat("Choc-ice", { 6794 }, { food(7) })
eat("Trout", { 333 }, { food(7) })
eat("Cod", { 339 }, { food(7) })
eat("Plain pizza", { 2289 }, { food(7) })
eat("1/2 plain pizza", { 2291 }, { food(7) })
eat("Apple pie", { 2323 }, { food(7) })
eat("Half an apple pie", { 2335 }, { food(7) })
eat("Roast rabbit", { 7223 }, { food(7) })
eat("Premade ch' crunch", { 2239 }, { food(7) })
eat("Chocchip crunchies", { 2209 }, { food(7) })
eat("Premade s'y crunch", { 2241 }, { food(7) })
eat("Spicy crunchies", { 2213 }, { food(7) })
eat("Pike", { 351 }, { food(8) })
eat("Roast beast meat", { 9988 }, { food(8) })
eat("Meat pizza", { 2293 }, { food(8) })
eat("1/2 meat pizza", { 2295 }, { food(8) })
eat("Premade w'm crun'", { 2237 }, { food(8) })
eat("Worm crunchies", { 2205 }, { food(8) })
eat("Premade t'd crunch", { 2243 }, { food(8) })
eat("Toad crunchies", { 2217 }, { food(8) })
eat("Egg and tomato", { 7064 }, { food(8) })
eat("Prael bat", { 20873 }, { food(8) })
eat("Peach", { 6883 }, { food(8) })
eat("Suphi fish", { 20858 }, { food(8) })
eat("Red crab meat", { 31689 }, { food(8) })
drink("Premade p' punch", { 2036 }, { food(9) })
drink("Pineapple punch", { 2048 }, { food(9) })
drink("Premade fr' blast", { 2034 }, { food(9) })
drink("Fruit blast", { 2084 }, { food(9) })
eat("Salmon", { 329 }, { food(9) })
eat("Anchovy pizza", { 2297 }, { food(9) })
eat("1/2 anchovy pizza", { 2299 }, { food(9) })
eat("Tuna", { 361, 26149 }, { food(10) })
eat("Cooked giant crab meat", { 7521 }, { food(10) })
eat("Chopped tuna", { 7086 }, { food(10) })
eat("Cooked chompy", { 2878 }, { food(10) })
eat("Field ration", { 7934 }, { food(10) })
eat("Dragonfruit", { 22929 }, { food(10) })
eat("Rainbow fish", { 10136 }, { food(11) })
eat("Stew", { 2003 }, { food(11) })
eat("Pineapple pizza", { 2301 }, { food(11) })
eat("1/2 pineapple pizza", { 2303 }, { food(11) })
eat("Cooked fishcake", { 7530 }, { food(11) })
eat("Premade veg batta", { 2227 }, { food(11) })
eat("Vegetable batta", { 2281 }, { food(11) })
eat("Premade w'm batta", { 2219 }, { food(11) })
eat("Worm batta", { 2253 }, { food(11) })
eat("Premade t'd batta", { 2221 }, { food(11) })
eat("Toad batta", { 2255 }, { food(11) })
eat("Premade c+t batta", { 2223 }, { food(11) })
eat("Cheese+tom batta", { 2259 }, { food(11) })
eat("Premade fr't batta", { 2225 }, { food(11) })
eat("Fruit batta", { 2277 }, { food(11) })
eat("Mushroom & onion", { 7066 }, { food(11) })
eat("Giral bat", { 20875 }, { food(11) })
eat("Lava eel", { 2149 }, { food(11) })
eat("Leckish fish", { 20860 }, { food(11) })
eat("Banana stew", { 4016 }, { food(11) })
eat("Lobster", { 379 }, { food(12) })
eat("Premade worm hole", { 2233 }, { food(12) })
eat("Worm hole", { 2191 }, { food(12) })
eat("Premade veg ball", { 2235 }, { food(12) })
eat("Veg ball", { 2195 }, { food(12) })
eat("Bass", { 365 }, { food(13) })
eat("Tuna and corn", { 7068 }, { food(13) })
eat("Potato with butter", { 6703 }, { food(14) })
eat("Chilli potato", { 7054 }, { food(14) })
eat("Swordfish", { 373 }, { food(14) })
eat("Phluxia bat", { 20877 }, { food(14) })
eat("Pumpkin", { 1959 }, { food(14) })
eat("Easter egg", { 1961 }, { food(14) })
eat("Brawk fish", { 20862 }, { food(14) })
eat("Cooked oomlie wrap", { 2343 }, { food(14) })
eat("Blue crab meat", { 31695 }, { food(14) })
eat("Premade ttl", { 2231 }, { food(15) })
eat("Tangled toad's legs", { 2187 }, { food(15) })
eat("Premade choc bomb", { 2229 }, { food(15) })
eat("Chocolate bomb", { 2185 }, { food(15) })
eat("Cooked jubbly", { 7568 }, { food(15) })
eat("Swordtip squid", { 31556 }, { food(15) })
eat("Monkfish", { 7946 }, { food(16) })
eat("Potato with cheese", { 6705 }, { food(16) })
eat("Egg potato", { 7056 }, { food(16) })
eat("Crystal paddlefish", { 25960 }, { food(16) }, { combo = true })
eat("Corrupted paddlefish", { 25958 }, { food(16) }, { combo = true })
eat("Mycil fish", { 20864 }, { food(17) })
eat("Kryket bat", { 20879 }, { food(17) })
eat("Giant krill", { 32312 }, { food(17) })
eat("Jumbo squid", { 31564 }, { food(17) })
eat("Cooked karambwan", { 3144, 23533 }, { food(18) }, { combo = true })
eat("Blighted karambwan", { 24595 }, { food(18) }, { combo = true })
eat("Smelly kebab", { 33820 }, { food(18) })
eat("Curry", { 2011 }, { food(19) })
eat("Ugthanki kebab", { 1883, 1885 }, { food(19) })
eat("Rainbow crab meat", { 31703 }, { food(19) })
eat("Mushroom potato", { 7058 }, { food(20) })
eat("Shark", { 385, 20390 }, { food(20) })
eat("Roqed fish", { 20866 }, { food(20) })
eat("Murng bat", { 20881 }, { food(20) })
eat("Stuffed snake", { 7579 }, { food(20) })
eat("Paddlefish", { 23874 }, { food(20) })
eat("Corrupted shark", { 31174 }, { food(20) })
eat("Halibut", { 32336 }, { food(20) })
eat("Sea turtle", { 397 }, { food(21) })
eat("Manta ray", { 391 }, { food(22) })
eat("Blighted manta ray", { 24589 }, { food(22) })
eat("Dark crab", { 11936 }, { food(22) })
eat("Tuna potato", { 7060 }, { food(22) })
eat("Mysterious jerky", { 33802 }, { food(22) })
eat("Kyren fish", { 20868 }, { food(23) })
eat("Psykk bat", { 20883 }, { food(23) })
eat("Marlin", { 32352 }, { food(24) })
eat("Stymphike tartare", { 33628 }, { food(26) })
eat("Anglerfish", { 13441 }, { anglerfish() })
eat("Blighted anglerfish", { 24592 }, { anglerfish() })
eat("Strawberry", { 5504 }, { food_of_max(0.06) })
eat("Watermelon slice", { 5984 }, { food_of_max(0.05) })
eat("Cooked sweetcorn", { 5988 }, { food(1, 0.1) })
eat("Sweetcorn", { 7088 }, { food(1, 0.1) })
eat("Cooked bream", { 29217 }, { cooked_bream() })
eat("Cooked moss lizard", { 29077 }, { cooked_moss_lizard() })
eat("Cabbage", { 1967 }, { food(1), boost("Defence", 1, 0.02) })
eat("Papaya fruit", { 5972 }, { food(8), restore("Run energy", 5) })
drink("Cup of tea", { 1978 }, { food(3), boost("Attack", 2, 0.02) })
drink("Nettle tea", { 4239, 4240 }, { food(3), nettle_tea_energy() })
drink("Cup of tea", { 4242, 4243 }, { food(3), nettle_tea_energy() })
eat("Thin snail meat", { 3369 }, { food_range(5, 7) })
eat("Lean snail meat", { 3371 }, { food_range(5, 8) })
eat("Fat snail meat", { 3373 }, { food_range(7, 9) })
eat("Spider on stick", { 6297 }, { food_range(7, 10) })
eat("Spider on shaft", { 6299 }, { food_range(7, 10) })
eat("Cooked graahk", { 29149 }, { food(8), later(6) })
eat("Cooked kyatt", { 29152 }, { food(9), later(8) })
eat("Cooked pyre fox", { 29137 }, { food(11), later(8) })
eat("Cooked dashing kebbit", { 29134 }, { food(13), later(10), restore("Run energy", 10) })
eat("Cooked sunlight antelope", { 29140 }, { food(12), later(9) })
eat("Cooked moonlight antelope", { 29143 }, { food(14), later(12) })
eat("Haddock", { 32320 }, { haddock() })
eat("Yellowfin", { 32328 }, { food(19), restore("Run energy", 20) })
eat("Bluefin", { 32344 }, { food(22), restore("Prayer", 5) })
eat("Cooked t-bone steak", { 33109 }, { food(9), boost("Strength", 2) })
eat("Bat shish", { 10964 }, { food(2) })
eat("Coated frogs' legs", { 10963 }, { food(2) })
eat("Fillets", { 10969 }, { food(2) })
eat("Fingers", { 10965 }, { food(2) })
eat("Frogburger", { 10962 }, { food(2) })
eat("Frogspawn gumbo", { 10961 }, { food(2) })
eat("Green gloop soup", { 10960 }, { food(2) })
eat("Grubs à la mode", { 10966 }, { food(2) })
eat("Mushrooms", { 10968 }, { food(2) })
eat("Roast frog", { 10967 }, { food(2) })
eat("Loach", { 10970 }, { food(3) })
eat("Frog spawn", { 5004 }, { food_range(3, 6) })
eat("Cooked slimy eel", { 3381 }, { food_range(6, 10) })
eat("Cave eel", { 5003 }, { food_range(8, 12) })
eat("Eel sushi", { 10971 }, { food(10) })
drink("Jug of wine", { 1993 }, { food(11), lower("Attack", 2) })
drink("Bottle of wine", { 7919 }, { food(14), lower("Attack", 3) })
drink("Half full wine jug", { 1989 }, { food(7), lower("Attack", 2) })
drink("Jug of bad wine", { 1991 }, { lower("Attack", 3) })
drink("Premade sgg", { 2038 }, { food(5), boost("Strength", 1, 0.05), drain("Attack", -3, -0.02) })
drink("Short green guy", { 2080 }, { food(5), boost("Strength", 1, 0.05), drain("Attack", -3, -0.02) })
drink("Brandy", { 2021 }, { food(5), boost("Strength", 1, 0.05), drain("Attack", -3, -0.02) })
drink("Gin", { 2019 }, { food(5), boost("Strength", 1, 0.05), drain("Attack", -3, -0.02) })
drink("Vodka", { 2015 }, { food(5), boost("Strength", 1, 0.05), drain("Attack", -3, -0.02) })
drink("Whisky", { 2017 }, { food(5), boost("Strength", 1, 0.05), drain("Attack", -3, -0.02) })
drink("Premade blurb' sp.", { 2028 }, { food(7), boost("Strength", 2, 0.05), drain("Attack", -3, -0.02) })
drink("Blurberry special", { 2064 }, { food(7), boost("Strength", 2, 0.05), drain("Attack", -3, -0.02) })
drink("Premade dr' dragon", { 2032 }, { food(5), boost("Strength", 2, 0.05), drain("Attack", -3, -0.02) })
drink("Drunk dragon", { 2092 }, { food(5), boost("Strength", 2, 0.05), drain("Attack", -3, -0.02) })
drink("Premade choc s'dy", { 2030 }, { food(5), boost("Strength", 2, 0.05), drain("Attack", -3, -0.02) })
drink("Choc saturday", { 2074 }, { food(5), boost("Strength", 2, 0.05), drain("Attack", -3, -0.02) })
drink("Premade wiz blz'd", { 2040 }, { food(5), boost("Strength", 1, 0.06), drain("Attack", -3, -0.02) })
drink("Wizard blizzard", { 2054 }, { food(5), boost("Strength", 1, 0.06), drain("Attack", -3, -0.02) })
drink("Grog", { 1915 }, { food(3), boost("Strength", 1, 0.04), drain("Attack", -3, -0.05) })
drink("Beer", { 1917, 7740 }, { food(1), boost("Strength", 1, 0.02), drain("Attack", -1, -0.06) })
drink("Beer tankard", { 3803 }, { food(4), boost("Strength", 2, 0.04), drain("Attack", -2, -0.1) })
drink("Keg of beer", { 3801 }, { food(15), boost("Strength", 2, 0.1), drain("Attack", -4, -0.5) })
drink("Blood pint", { 24774 }, { boost("Attack", 5), boost("Strength", 5), lower("Magic", 5), lower("Prayer", 5) })
drink(
	"Asgarnian ale",
	{ 5785, 5783, 5781, 5779, 1905, 7744 },
	{ food(1), boost("Strength", 2), drain("Attack", -2, -0.05) }
)
drink("Asgarnian ale(m)", { 5739 }, { food(1), boost("Strength", 3), drain("Attack", -3, -0.05) })
drink("Asgarnian ale(m1)", { 5859 }, { food(1), boost("Strength", 3), drain("Attack", -3, -0.05) })
drink("Asgarnian ale(m2)", { 5861 }, { food(1), boost("Strength", 3), drain("Attack", -3, -0.05) })
drink("Asgarnian ale(m3)", { 5863 }, { food(1), boost("Strength", 3), drain("Attack", -3, -0.05) })
drink("Asgarnian ale(m4)", { 5865 }, { food(1), boost("Strength", 3), drain("Attack", -3, -0.05) })
drink(
	"Axeman's folly",
	{ 5825, 5823, 5821, 5819, 5751 },
	{ food(1), boost("Woodcutting", 1), drain("Attack", -2, -0.02), drain("Strength", -2, -0.02) }
)
drink(
	"Axeman's folly(m)",
	{ 5753 },
	{ food(2), boost("Woodcutting", 2), drain("Attack", -3, -0.02), drain("Strength", -3, -0.02) }
)
drink(
	"Axeman's folly(m1)",
	{ 5899 },
	{ food(2), boost("Woodcutting", 2), drain("Attack", -3, -0.02), drain("Strength", -3, -0.02) }
)
drink(
	"Axeman's folly(m2)",
	{ 5901 },
	{ food(2), boost("Woodcutting", 2), drain("Attack", -3, -0.02), drain("Strength", -3, -0.02) }
)
drink(
	"Axeman's folly(m3)",
	{ 5903 },
	{ food(2), boost("Woodcutting", 2), drain("Attack", -3, -0.02), drain("Strength", -3, -0.02) }
)
drink(
	"Axeman's folly(m4)",
	{ 5905 },
	{ food(2), boost("Woodcutting", 2), drain("Attack", -3, -0.02), drain("Strength", -3, -0.02) }
)
drink(
	"Bandit's brew",
	{ 4627 },
	{ food(1), boost("Thieving", 1), boost("Attack", 1), drain("Defence", -3, -0.06), drain("Strength", -3, -0.06) }
)
drink(
	"Chef's delight",
	{ 5833, 5831, 5829, 5827, 5755, 7754 },
	{ food(1), boost("Cooking", 1, 0.05), drain("Attack", -2, -0.05), drain("Strength", -2, -0.05) }
)
drink(
	"Chef's delight(m)",
	{ 5757 },
	{ food(2), boost("Cooking", 2, 0.05), drain("Attack", -3, -0.05), drain("Strength", -3, -0.05) }
)
drink(
	"Chef's delight(m1)",
	{ 5907 },
	{ food(2), boost("Cooking", 2, 0.05), drain("Attack", -3, -0.05), drain("Strength", -3, -0.05) }
)
drink(
	"Chef's delight(m2)",
	{ 5909 },
	{ food(2), boost("Cooking", 2, 0.05), drain("Attack", -3, -0.05), drain("Strength", -3, -0.05) }
)
drink(
	"Chef's delight(m3)",
	{ 5911 },
	{ food(2), boost("Cooking", 2, 0.05), drain("Attack", -3, -0.05), drain("Strength", -3, -0.05) }
)
drink(
	"Chef's delight(m4)",
	{ 5913 },
	{ food(2), boost("Cooking", 2, 0.05), drain("Attack", -3, -0.05), drain("Strength", -3, -0.05) }
)
drink(
	"Cider",
	{ 5849, 5847, 5845, 5843, 5763, 7752 },
	{ food(1), boost("Farming", 1), drain("Attack", -2, -0.02), drain("Strength", -2, -0.02) }
)
drink(
	"Mature cider",
	{ 5765 },
	{ food(2), boost("Farming", 2), drain("Attack", -3, -0.02), drain("Strength", -3, -0.02) }
)
drink("Cider(m1)", { 5923 }, { food(2), boost("Farming", 2), drain("Attack", -3, -0.02), drain("Strength", -3, -0.02) })
drink("Cider(m2)", { 5925 }, { food(2), boost("Farming", 2), drain("Attack", -3, -0.02), drain("Strength", -3, -0.02) })
drink("Cider(m3)", { 5927 }, { food(2), boost("Farming", 2), drain("Attack", -3, -0.02), drain("Strength", -3, -0.02) })
drink("Cider(m4)", { 5929 }, { food(2), boost("Farming", 2), drain("Attack", -3, -0.02), drain("Strength", -3, -0.02) })
drink(
	"Dragon bitter",
	{ 5809, 5807, 5805, 5803, 1911, 7748 },
	{ food(1), boost("Strength", 2), drain("Attack", -2, -0.05) }
)
drink("Dragon bitter(m)", { 5745 }, { food(2), boost("Strength", 3), drain("Attack", -2, -0.05) })
drink("Dragon bitter(m1)", { 5883 }, { food(2), boost("Strength", 3), drain("Attack", -2, -0.05) })
drink("Dragon bitter(m2)", { 5885 }, { food(2), boost("Strength", 3), drain("Attack", -2, -0.05) })
drink("Dragon bitter(m3)", { 5887 }, { food(2), boost("Strength", 3), drain("Attack", -2, -0.05) })
drink("Dragon bitter(m4)", { 5889 }, { food(2), boost("Strength", 3), drain("Attack", -2, -0.05) })
drink("Dwarven stout", { 5777, 5775, 5773, 5771, 1913 }, {
	food(1),
	boost("Mining", 1),
	boost("Smithing", 1),
	drain("Attack", -2, -0.04),
	drain("Defence", -2, -0.04),
	drain("Strength", -2, -0.04),
})
drink("Dwarven stout(m)", { 5747 }, {
	food(2),
	boost("Mining", 2),
	boost("Smithing", 2),
	drain("Attack", -3, -0.04),
	drain("Defence", -3, -0.04),
	drain("Strength", -3, -0.04),
})
drink("Dwarven stout(m1)", { 5851 }, {
	food(2),
	boost("Mining", 2),
	boost("Smithing", 2),
	drain("Attack", -3, -0.04),
	drain("Defence", -3, -0.04),
	drain("Strength", -3, -0.04),
})
drink("Dwarven stout(m2)", { 5853 }, {
	food(2),
	boost("Mining", 2),
	boost("Smithing", 2),
	drain("Attack", -3, -0.04),
	drain("Defence", -3, -0.04),
	drain("Strength", -3, -0.04),
})
drink("Dwarven stout(m3)", { 5855 }, {
	food(2),
	boost("Mining", 2),
	boost("Smithing", 2),
	drain("Attack", -3, -0.04),
	drain("Defence", -3, -0.04),
	drain("Strength", -3, -0.04),
})
drink("Dwarven stout(m4)", { 5857 }, {
	food(2),
	boost("Mining", 2),
	boost("Smithing", 2),
	drain("Attack", -3, -0.04),
	drain("Defence", -3, -0.04),
	drain("Strength", -3, -0.04),
})
drink(
	"Kovac's grog",
	{ 27014 },
	{ food(1), boost("Smithing", 4), lower("Attack", 2), lower("Ranged", 2), lower("Magic", 2) }
)
drink("Greenman's ale", { 1909, 7746 }, {
	food(1),
	boost("Herblore", 1),
	drain("Attack", -2, -0.04),
	drain("Defence", -2, -0.04),
	drain("Strength", -2, -0.04),
})
drink("Greenmans ale", { 5793, 5791, 5789, 5787 }, {
	food(1),
	boost("Herblore", 1),
	drain("Attack", -2, -0.04),
	drain("Defence", -2, -0.04),
	drain("Strength", -2, -0.04),
})
drink("Greenman's ale(m)", { 5743 }, {
	food(2),
	boost("Herblore", 2),
	drain("Attack", -3, -0.04),
	drain("Defence", -3, -0.04),
	drain("Strength", -3, -0.04),
})
drink("Greenmans ale(m1)", { 5867 }, {
	food(2),
	boost("Herblore", 2),
	drain("Attack", -3, -0.04),
	drain("Defence", -3, -0.04),
	drain("Strength", -3, -0.04),
})
drink("Greenmans ale(m2)", { 5869 }, {
	food(2),
	boost("Herblore", 2),
	drain("Attack", -3, -0.04),
	drain("Defence", -3, -0.04),
	drain("Strength", -3, -0.04),
})
drink("Greenmans ale(m3)", { 5871 }, {
	food(2),
	boost("Herblore", 2),
	drain("Attack", -3, -0.04),
	drain("Defence", -3, -0.04),
	drain("Strength", -3, -0.04),
})
drink("Greenmans ale(m4)", { 5873 }, {
	food(2),
	boost("Herblore", 2),
	drain("Attack", -3, -0.04),
	drain("Defence", -3, -0.04),
	drain("Strength", -3, -0.04),
})
drink("Slayer's respite", { 5841, 5839, 5837, 5835, 5759 }, {
	food(1),
	boost("Slayer", 2),
	drain("Attack", -2, -0.02),
	drain("Defence", -2, -0.02),
	drain("Strength", -2, -0.02),
})
drink("Slayer's respite(m)", { 5761 }, {
	food(2),
	boost("Slayer", 4),
	drain("Attack", -3, -0.02),
	drain("Defence", -3, -0.02),
	drain("Strength", -3, -0.02),
})
drink("Slayer's respite(m1)", { 5915 }, {
	food(2),
	boost("Slayer", 4),
	drain("Attack", -3, -0.02),
	drain("Defence", -3, -0.02),
	drain("Strength", -3, -0.02),
})
drink("Slayer's respite(m2)", { 5917 }, {
	food(2),
	boost("Slayer", 4),
	drain("Attack", -3, -0.02),
	drain("Defence", -3, -0.02),
	drain("Strength", -3, -0.02),
})
drink("Slayer's respite(m3)", { 5919 }, {
	food(2),
	boost("Slayer", 4),
	drain("Attack", -3, -0.02),
	drain("Defence", -3, -0.02),
	drain("Strength", -3, -0.02),
})
drink("Slayer's respite(m4)", { 5921 }, {
	food(2),
	boost("Slayer", 4),
	drain("Attack", -3, -0.02),
	drain("Defence", -3, -0.02),
	drain("Strength", -3, -0.02),
})
drink("Wizard's mind bomb", { 1907 }, {
	food(1),
	boost("Magic", 2, 0.02),
	drain("Attack", -1, -0.05),
	drain("Defence", -1, -0.05),
	drain("Strength", -1, -0.05),
})
drink("Mind bomb", { 5801, 5799, 5797, 5795 }, {
	food(1),
	boost("Magic", 2, 0.02),
	drain("Attack", -1, -0.05),
	drain("Defence", -1, -0.05),
	drain("Strength", -1, -0.05),
})
drink("Mature wmb", { 5741 }, {
	food(2),
	boost("Magic", 3, 0.02),
	drain("Attack", -2, -0.05),
	drain("Defence", -2, -0.05),
	drain("Strength", -2, -0.05),
})
drink("Mind bomb(m1)", { 5875 }, {
	food(2),
	boost("Magic", 3, 0.02),
	drain("Attack", -2, -0.05),
	drain("Defence", -2, -0.05),
	drain("Strength", -2, -0.05),
})
drink("Mind bomb(m2)", { 5877 }, {
	food(2),
	boost("Magic", 3, 0.02),
	drain("Attack", -2, -0.05),
	drain("Defence", -2, -0.05),
	drain("Strength", -2, -0.05),
})
drink("Mind bomb(m3)", { 5879 }, {
	food(2),
	boost("Magic", 3, 0.02),
	drain("Attack", -2, -0.05),
	drain("Defence", -2, -0.05),
	drain("Strength", -2, -0.05),
})
drink("Mind bomb(m4)", { 5881 }, {
	food(2),
	boost("Magic", 3, 0.02),
	drain("Attack", -2, -0.05),
	drain("Defence", -2, -0.05),
	drain("Strength", -2, -0.05),
})
drink("Braindeath 'rum'", { 7157 }, {
	food(14),
	boost("Strength", 3),
	boost("Mining", 1),
	restore("Prayer", -1, -0.06),
	drain("Agility", -3, -0.09),
	drain("Attack", -1, -0.06),
	drain("Defence", -2, -0.08),
	drain("Herblore", -1, -0.06),
	drain("Magic", -1, -0.05),
	drain("Ranged", -1, -0.06),
})
drink("Bloody bracer", { 22430 }, { food(2), restore("Prayer", -2, -0.04) })
drink("Elven dawn", { 23948 }, { food(1), boost("Agility", 1), lower("Strength", 1) })
drink("Lizardkicker", { 25826 }, { boost("Ranged", 4), drain("Strength", -2, -0.04), drain("Magic", -2, -0.04) })
drink("Trapper's tipple", { 29277 }, { food(1), boost("Hunter", 2), lower("Strength", 1), lower("Attack", 2) })
drink("Sunbeam ale", { 29409 }, { food(1), boost("Agility", 1), boost("Strength", 1), drain("Attack", -1, -0.05) })
drink("Moon-lite", { 29418 }, { food(5), boost("Strength", 1, 0.05), drain("Attack", -3, -0.02) })
drink("Sun-shine", { 29421 }, { food(5), boost("Strength", 1, 0.05), drain("Attack", -3, -0.02) })
drink("Rum", { 28896 }, { food(5), boost("Strength", 5), drain("Attack", -3, -0.02) })
drink("Eclipse red", { 29415 }, { food(16), boost("Woodcutting", 1), lower("Attack", 5), lower("Fletching", 1) })
drink(
	"Steamforge brew",
	{ 29412 },
	{ food(1), boost("Magic", 1), boost("Mining", 1), drain("Attack", -3, -0.05), drain("Defence", -3, -0.05) }
)
drink("Blackbird red", { 29944 }, { food(16), boost("Hunter", 1), lower("Attack", 5), lower("Slayer", 1) })
drink("Chilhuac red", { 29947 }, { food(16), boost("Firemaking", 1), lower("Attack", 5), lower("Cooking", 1) })
drink("Ixcoztic white", { 29952 }, { food(16), boost("Farming", 1), lower("Attack", 5), lower("Herblore", 1) })
drink("Metztonalli white", { 29955 }, { food(16), boost("Runecraft", 1), lower("Attack", 5), lower("Firemaking", 1) })
drink("Tonameyo white", { 29958 }, { food(16), boost("Prayer", 1), lower("Attack", 5), lower("Thieving", 1) })
drink("Chichilihui rosé", { 29963 }, { food(16), boost("Herblore", 1), lower("Attack", 5), lower("Farming", 1) })
drink("Imperial rosé", { 29966 }, { food(16), boost("Slayer", 1), lower("Attack", 5), lower("Agility", 1) })
drink("Kraken ink stout", { 31814 }, { boost("Sailing", 1), boost("Magic", 2), lower("Attack", 2) })
drink(
	"Perildance bitter",
	{ 31817 },
	{ boost("Sailing", 1), boost("Ranged", 2), boost("Strength", 2), lower("Magic", 2) }
)
drink("Trawler's trust", { 31820 }, { boost("Sailing", 2), boost("Fishing", 2), lower("Attack", 2) })
drink("Whirlpool surprise", { 31811 }, { boost("Sailing", 3), boost("Cooking", 2), lower("Agility", 2) })
drink("Horizon's lure", { 31823 }, { boost("Sailing", 4), lower("Thieving", 2) })
drink("Kraken colada", { 31258 }, {
	boost("Slayer", 1),
	drain("Sailing", -2, -0.02),
	drain("Attack", -2, -0.02),
	drain("Strength", -2, -0.02),
	drain("Defence", -2, -0.02),
})
drink("Barnacle blaster", { 31255 }, {
	boost("Fishing", 1),
	drain("Sailing", -2, -0.02),
	drain("Attack", -2, -0.02),
	drain("Strength", -2, -0.02),
	drain("Defence", -2, -0.02),
})
drink("Sailor's mirage", { 31261 }, {
	boost("Hunter", 1),
	drain("Sailing", -2, -0.02),
	drain("Attack", -2, -0.02),
	drain("Strength", -2, -0.02),
	drain("Defence", -2, -0.02),
})
drink("Winter sq'irkjuice", { 10851 }, { restore("Run energy", 5) })
drink("Spring sq'irkjuice", { 10848 }, { restore("Run energy", 10), boost("Thieving", 1) })
drink("Autumn sq'irkjuice", { 10850 }, { restore("Run energy", 15), boost("Thieving", 2) })
drink("Summer sq'irkjuice", { 10849 }, { restore("Run energy", 20), boost("Thieving", 3) })
drink("Attack potion", { 2428, 121, 123, 125 }, { boost("Attack", 3, 0.1) })
drink("Strength potion", { 113, 115, 117, 119 }, { boost("Strength", 3, 0.1) })
drink("Defence potion", { 2432, 133, 135, 137 }, { boost("Defence", 3, 0.1) })
drink("Magic potion", { 3040, 3042, 3044, 3046 }, { boost("Magic", 4) })
drink("Ranging potion", { 2444, 169, 171, 173, 23551, 23553, 23555, 23557 }, { boost("Ranged", 4, 0.1) })
drink(
	"Combat potion",
	{ 9739, 9741, 9743, 9745, 26150, 26151, 26152, 26153 },
	{ boost("Attack", 3, 0.1), boost("Strength", 3, 0.1) }
)
drink("Super attack", { 2436, 145, 147, 149 }, { boost("Attack", 5, 0.15) })
drink("Super strength", { 2440, 157, 159, 161 }, { boost("Strength", 5, 0.15) })
drink("Super defence", { 2442, 163, 165, 167 }, { boost("Defence", 5, 0.15) })
drink("Magic essence", { 9021, 9022, 9023, 9024 }, { boost("Magic", 3) })
drink(
	"Super combat potion",
	{ 12695, 12697, 12699, 12701 },
	{ boost("Attack", 5, 0.15), boost("Strength", 5, 0.15), boost("Defence", 5, 0.15) }
)
drink(
	"Rank frothy potion",
	{ 33815, 33816, 33817, 33818 },
	{ boost("Attack", 5, 0.15), boost("Strength", 5, 0.15), boost("Defence", 5, 0.15) }
)
drink("Zamorak brew", { 2450, 189, 191, 193 }, {
	boost("Attack", 2, 0.2),
	boost("Strength", 2, 0.12),
	restore("Prayer", 0, 0.1),
	drain("Defence", -2, -0.1),
	drain("Hitpoints", 0, -0.12),
})
drink(
	"Saradomin brew",
	{ 6685, 6687, 6689, 6691, 23575, 23577, 23579, 23581 },
	{ saradomin_brew(0.15, 0.2, 0.1, 2, 2) }
)
drink("Super ranging", { 11722, 11723, 11724, 11725 }, { boost("Ranged", 5, 0.15) })
drink("Super magic potion", { 11726, 11727, 11728, 11729 }, { boost("Magic", 5, 0.15) })
drink("Bastion potion", { 22461, 22464, 22467, 22470 }, { boost("Ranged", 4, 0.1), boost("Defence", 5, 0.15) })
drink("Battlemage potion", { 22449, 22452, 22455, 22458 }, { boost("Magic", 4), boost("Defence", 5, 0.15) })
drink(
	"Divine magic potion",
	{ 23745, 23748, 23751, 23754 },
	{ boost("Magic", 4), lower("Hitpoints", 10) },
	{ special = { special("divine_magic", 500) } }
)
drink(
	"Divine ranging potion",
	{ 23733, 23736, 23739, 23742 },
	{ boost("Ranged", 4, 0.1), lower("Hitpoints", 10) },
	{ special = { special("divine_ranging", 500) } }
)
drink(
	"Divine super attack potion",
	{ 23697, 23700, 23703, 23706 },
	{ boost("Attack", 5, 0.15), lower("Hitpoints", 10) },
	{ special = { special("divine_attack", 500) } }
)
drink(
	"Divine super strength potion",
	{ 23709, 23712, 23715, 23718 },
	{ boost("Strength", 5, 0.15), lower("Hitpoints", 10) },
	{ special = { special("divine_strength", 500) } }
)
drink(
	"Divine super defence potion",
	{ 23721, 23724, 23727, 23730 },
	{ boost("Defence", 5, 0.15), lower("Hitpoints", 10) },
	{ special = { special("divine_defence", 500) } }
)
drink(
	"Divine super combat potion",
	{ 23685, 23688, 23691, 23694 },
	{ boost("Attack", 5, 0.15), boost("Strength", 5, 0.15), boost("Defence", 5, 0.15), lower("Hitpoints", 10) },
	{ special = { special("divine_combat", 500) } }
)
drink(
	"Divine bastion potion",
	{ 24635, 24638, 24641, 24644 },
	{ boost("Ranged", 4, 0.1), boost("Defence", 5, 0.15), lower("Hitpoints", 10) },
	{ special = { special("divine_bastion", 500) } }
)
drink(
	"Divine battlemage potion",
	{ 24623, 24626, 24629, 24632 },
	{ boost("Magic", 4), boost("Defence", 5, 0.15), lower("Hitpoints", 10) },
	{ special = { special("divine_battlemage", 500) } }
)
drink("Castlewars brew", { 25159, 25160, 25161, 25162 }, {
	boost("Attack", 5, 0.15),
	boost("Strength", 5, 0.15),
	boost("Defence", 5, 0.15),
	boost("Ranged", 4, 0.1),
	boost("Magic", 1, 0.1),
})
drink("Super combat potion", { 23543, 23545, 23547, 23549 }, { boost("Attack", 5, 0.15), boost("Strength", 5, 0.15) })
drink("Ancient brew", { 26340, 26342, 26344, 26346 }, { ancient_brew(2, 0.05) })
drink("Forgotten brew", { 27629, 27632, 27635, 27638 }, { ancient_brew(3, 0.08) })
drink(
	"Moonlight potion",
	{ 29080, 29081, 29082, 29083 },
	{ moonlight_potion() },
	{ special = { special("moonlight") } }
)
drink("Armadyl brew", { 31650, 31653, 31656, 31659 }, {
	boost("Hitpoints", 2, 0.1),
	boost("Ranged", 4, 0.1),
	drain("Attack", -2, -0.1),
	drain("Strength", -2, -0.1),
	drain("Defence", -2, -0.1),
	drain("Magic", -2, -0.1),
})
drink("Rancid slimy potion", { 33811, 33812, 33813, 33814 }, { saradomin_brew(0.15, 0.2, 0, 2, 1) })
drink("Attack mix", { 11429, 11431 }, { boost("Attack", 3, 0.1), food(3) })
drink("Strength mix", { 11443, 11441 }, { boost("Strength", 3, 0.1), food(3) })
drink("Combat mix", { 11445, 11447 }, { boost("Attack", 3, 0.1), boost("Strength", 3, 0.1), food(3) })
drink("Defence mix", { 11457, 11459 }, { boost("Defence", 3, 0.1), food(6) })
drink("Magic mix", { 11513, 11515 }, { boost("Magic", 4), food(6) })
drink("Ranging mix", { 11509, 11511 }, { boost("Ranged", 4, 0.1), food(6) })
drink("Superattack mix", { 11469, 11471 }, { boost("Attack", 5, 0.15), food(6) })
drink("Super str. mix", { 11485, 11487 }, { boost("Strength", 5, 0.15), food(6) })
drink("Super def. mix", { 11497, 11499 }, { boost("Defence", 5, 0.15), food(6) })
drink("Magic essence mix", { 11489, 11491 }, { boost("Magic", 3), food(6) })
drink("Zamorak mix", { 11521, 11523 }, {
	boost("Attack", 2, 0.2),
	boost("Strength", 2, 0.12),
	restore("Prayer", 0, 0.1),
	drain("Defence", -2, -0.1),
	drain("Hitpoints", 0, -0.12),
	food(6),
})
drink("Ancient mix", { 26350, 26353 }, { ancient_brew(2, 0.05), food(6) })
drink("Overload", { 11730, 11731, 11732, 11733 }, {
	boost("Attack", 5, 0.15),
	boost("Strength", 5, 0.15),
	boost("Defence", 5, 0.15),
	boost("Ranged", 5, 0.15),
	boost("Magic", 5, 0.15),
	lower("Hitpoints", 50),
}, { special = { special("overload", 500) } })
drink("Blighted overload", { 29631, 29634, 29637, 29640 }, {
	boost("Attack", 8, 0.15),
	boost("Strength", 8, 0.15),
	drain("Defence", -1, -0.1),
	boost("Ranged", 7, 0.1),
	boost("Magic", 1, 0.1),
	lower("Hitpoints", 10),
}, { special = { special("blighted_overload") } })
use("Heal", "Bandages", { 4049 }, { food(0, 0.1), restore("Run energy", 30) })
use("Heal", "Bandages", { 25730 }, {
	food(20),
	restore("Prayer", 5, 0.25),
	restore("Run energy", 20),
	boost("Attack", 4, 0.15),
	boost("Strength", 4, 0.15),
	boost("Defence", 4, 0.15),
	boost("Ranged", 4, 0.1),
	boost("Magic", 4),
})
drink("Restore potion", { 2430, 127, 129, 131 }, {
	restore("Attack", 10, 0.3),
	restore("Strength", 10, 0.3),
	restore("Defence", 10, 0.3),
	restore("Ranged", 10, 0.3),
	restore("Magic", 10, 0.3),
})
drink("Energy potion", { 3008, 3010, 3012, 3014 }, { restore("Run energy", 15) })
drink("Prayer potion", { 2434, 139, 141, 143 }, { prayer_potion(7) })
drink("Super energy", { 3016, 3018, 3020, 3022 }, { restore("Run energy", 20) })
drink("Super restore", { 3024, 3026, 3028, 3030, 23567, 23569, 23571, 23573 }, { super_restore(8, 0.25) })
drink("Blighted super restore", { 24598, 24601, 24603, 24605 }, { super_restore(8, 0.25) })
drink("Foul chunky potion", { 33807, 33808, 33809, 33810 }, { super_restore(8, 0.25) })
drink(
	"Sanfew serum",
	{ 10925, 10927, 10929, 10931, 23559, 23561, 23563, 23565 },
	{ super_restore(4, 0.3) },
	{ special = { special("antipoison", 600), special("cure_disease") } }
)
drink("Menaphite remedy", { 27202, 27205, 27208, 27211 }, {
	restore("Attack", 6, 0.16),
	restore("Strength", 6, 0.16),
	restore("Defence", 6, 0.16),
	restore("Ranged", 6, 0.16),
	restore("Magic", 6, 0.16),
}, { special = { special("stat_renewal", 500) } })
drink("Stamina potion", { 12625, 12627, 12629, 12631 }, { stamina(20) }, { special = { special("stamina", 200) } })
drink("Putrid sticky potion", { 33803, 33804, 33805, 33806 }, { stamina(20) })
drink(
	"Extended stamina potion",
	{ 31638, 31641, 31644, 31647 },
	{ stamina(40) },
	{ special = { special("stamina", 400) } }
)
drink("Extreme energy potion", { 31614, 31617, 31620, 31623 }, { restore("Run energy", 40) })
eat("Jar of congealed blood", { 33819 }, { food(99), restore("Prayer", 99), restore("Run energy", 100) })
drink("Restore mix", { 11449, 11451 }, {
	restore("Attack", 10, 0.3),
	restore("Strength", 10, 0.3),
	restore("Defence", 10, 0.3),
	restore("Ranged", 10, 0.3),
	restore("Magic", 10, 0.3),
	food(3),
})
drink("Energy mix", { 11453, 11455 }, { restore("Run energy", 15), food(3) })
drink("Prayer mix", { 11465, 11467 }, { prayer_potion(7), food(6) })
drink("Super energy mix", { 11481, 11483 }, { restore("Run energy", 20), food(6) })
drink("Super restore mix", { 11493, 11495 }, { super_restore(8, 0.25), food(6) })
drink("Stamina mix", { 12633, 12635 }, { stamina(20), food(6) }, { special = { special("stamina", 200) } })
drink("Overload (+)", { 20996, 20995, 20994, 20993 }, {
	boost("Attack", 6, 0.16),
	boost("Strength", 6, 0.16),
	boost("Defence", 6, 0.16),
	boost("Ranged", 6, 0.16),
	boost("Magic", 6, 0.16),
	lower("Hitpoints", 50),
}, { special = { special("xeric_overload", 500) } })
drink(
	"Elder (+)",
	{ 20924, 20923, 20922, 20921 },
	{ boost("Attack", 6, 0.16), boost("Strength", 6, 0.16), boost("Defence", 6, 0.16) }
)
drink("Twisted (+)", { 20936, 20935, 20934, 20933 }, { boost("Ranged", 6, 0.16), boost("Defence", 6, 0.16) })
drink("Kodai (+)", { 20948, 20947, 20946, 20945 }, { boost("Magic", 6, 0.16), boost("Defence", 6, 0.16) })
drink("Revitalisation (+)", { 20960, 20959, 20958, 20957 }, { super_restore(11, 0.3) })
drink("Xeric's aid (+)", { 20984, 20983, 20982, 20981 }, { saradomin_brew(0.15, 0.2, 0.1, 5, 4) })
drink("Overload", { 20992, 20991, 20990, 20989 }, {
	boost("Attack", 5, 0.13),
	boost("Strength", 5, 0.13),
	boost("Defence", 5, 0.13),
	boost("Ranged", 5, 0.13),
	boost("Magic", 5, 0.13),
	lower("Hitpoints", 50),
}, { special = { special("xeric_overload", 500) } })
drink(
	"Elder potion",
	{ 20920, 20919, 20918, 20917 },
	{ boost("Attack", 5, 0.13), boost("Strength", 5, 0.13), boost("Defence", 5, 0.13) }
)
drink("Twisted potion", { 20932, 20931, 20930, 20929 }, { boost("Ranged", 5, 0.13), boost("Defence", 5, 0.13) })
drink("Kodai potion", { 20944, 20943, 20942, 20941 }, { boost("Magic", 5, 0.13), boost("Defence", 5, 0.13) })
drink("Overload (-)", { 20988, 20987, 20986, 20985 }, {
	boost("Attack", 4, 0.1),
	boost("Strength", 4, 0.1),
	boost("Defence", 4, 0.1),
	boost("Ranged", 4, 0.1),
	boost("Magic", 4, 0.1),
	lower("Hitpoints", 50),
}, { special = { special("xeric_overload", 500) } })
drink(
	"Elder (-)",
	{ 20916, 20915, 20914, 20913 },
	{ boost("Attack", 4, 0.1), boost("Strength", 4, 0.1), boost("Defence", 4, 0.1) }
)
drink("Twisted (-)", { 20928, 20927, 20926, 20925 }, { boost("Ranged", 4, 0.1), boost("Defence", 4, 0.1) })
drink("Kodai (-)", { 20940, 20939, 20938, 20937 }, { boost("Magic", 4, 0.1), boost("Defence", 4, 0.1) })
eat("Honey locust", { 27351 }, { boost("Hitpoints", 20), prayer_potion(7) })
drink("Ambrosia", { 27347, 27349 }, { ambrosia() })
use(
	"Crack",
	"Blessed crystal scarab",
	{ 27335, 27337 },
	{ restore("Prayer", 8) },
	{ special = { special("blessed_crystal_scarab", 40) } }
)
drink("Nectar", { 27315, 27317, 27319, 27321 }, {
	boost("Hitpoints", 3, 0.15),
	drain("Attack", -5, -0.2),
	drain("Strength", -5, -0.2),
	drain("Defence", -5, -0.2),
	drain("Ranged", -5, -0.2),
	drain("Magic", -5, -0.2),
})
use(
	"Apply",
	"Silk dressing",
	{ 27323, 27325 },
	{ boost("Hitpoints", 5) },
	{ special = { special("silk_dressing", 100) } }
)
use("Crush", "Smelling salts", { 27343, 27345 }, {
	boost("Attack", 11, 0.16),
	boost("Strength", 11, 0.16),
	boost("Defence", 11, 0.16),
	boost("Ranged", 11, 0.16),
	boost("Magic", 11, 0.16),
}, { special = { special("smelling_salts") } })
drink("Tears of Elidinis", { 27327, 27329, 27331, 27333 }, {
	restore("Prayer", 10, 0.25),
	restore("Attack", 3, 0.25),
	restore("Strength", 3, 0.25),
	restore("Defence", 3, 0.25),
	restore("Ranged", 3, 0.25),
	restore("Magic", 3, 0.25),
})
drink("Agility potion", { 3032, 3034, 3036, 3038 }, { boost("Agility", 3) })
drink("Fishing potion", { 2438, 151, 153, 155 }, { boost("Fishing", 3) })
drink("Super fishing potion", { 31602, 31605, 31608, 31611 }, { boost("Fishing", 6) })
drink("Hunter potion", { 9998, 10000, 10002, 10004 }, { boost("Hunter", 3) })
drink("Super hunter potion", { 31626, 31629, 31632, 31635 }, { boost("Hunter", 6) })
drink("Guthix rest", { 4417, 4419, 4421, 4423 }, { boost("Hitpoints", 5), restore("Run energy", 5) })
drink("Agility mix", { 11461, 11463 }, { boost("Agility", 3), food(6) })
drink("Fishing mix", { 11477, 11479 }, { boost("Fishing", 3), food(6) })
drink("Hunting mix", { 11517, 11519 }, { boost("Hunter", 3), food(6) })
eat("White tree fruit", { 6469 }, { food(3), restore_range("Run energy", 5, 10) })
eat("Strange fruit", { 464 }, { restore("Run energy", 30) })
eat("Mint cake", { 9475 }, { restore("Run energy", 50) })
eat("Gout tuber", { 6311 }, { food(12), restore("Run energy", 50) })
eat("Garden pie", { 7178 }, { food(6), boost("Farming", 3) })
eat("Half a garden pie", { 7180 }, { food(6), boost("Farming", 3) })
eat("Fish pie", { 7188 }, { food(6), boost("Fishing", 3) })
eat("Half a fish pie", { 7190 }, { food(6), boost("Fishing", 3) })
eat("Botanical pie", { 19662 }, { food(7), boost("Herblore", 4) })
eat("Half a botanical pie", { 19659 }, { food(7), boost("Herblore", 4) })
eat("Mushroom pie", { 21690 }, { food(8), boost("Crafting", 4) })
eat("Half a mushroom pie", { 21687 }, { food(8), boost("Crafting", 4) })
eat("Admiral pie", { 7198 }, { food(8), boost("Fishing", 5) })
eat("Half an admiral pie", { 7200 }, { food(8), boost("Fishing", 5) })
eat("Wild pie", { 7208 }, { food(11), boost("Slayer", 5), boost("Ranged", 4) })
eat("Half a wild pie", { 7210 }, { food(11), boost("Slayer", 5), boost("Ranged", 4) })
eat("Summer pie", { 7218 }, { food(11), boost("Agility", 5), restore("Run energy", 10) })
eat("Half a summer pie", { 7220 }, { food(11), boost("Agility", 5), restore("Run energy", 10) })
eat("Dragonfruit pie", { 22795 }, { food(10), boost("Fletching", 4) })
eat("Half a dragonfruit pie", { 22792 }, { food(10), boost("Fletching", 4) })
eat("Purple sweets", { 10476 }, { food_range(1, 3), restore("Run energy", 10) })
eat("Spicy stew", { 7479 }, {})
use("Invigorate", "Imbued heart", { 20724 }, { boost("Magic", 1, 0.1) }, { special = { special("imbued_heart", 700) } })
use("Invigorate", "Saturated heart", { 27641 }, { boost("Magic", 4, 0.1) }, { special = { special("imbued_heart") } })
eat("Jangerberries", { 247 }, { boost("Attack", 2), boost("Strength", 1), restore("Prayer", 1), lower("Defence", 1) })
eat("Cave nightshade", { 2398 }, { cave_nightshade() })
use(
	"Consume",
	"Scarred scraps",
	{ 28443 },
	{ food(15), restore("Prayer", 0, 0.25), stamina(20) },
	{ special = { special("stamina") } }
)
use("Guzzle", "Dwarven rock cake", { 7510 }, { rock_cake_guzzle() })
use("Feel", "Locator orb", { 22081 }, { locator_orb() })
drink("Egniol potion", { 23885, 23884, 23883, 23882 }, { restore("Prayer", 7, 0.25), restore("Run energy", 40) })
use("Heal", "Bandages", { 25202 }, { food(1, 0.15), restore("Run energy", 100) })
drink("Potion of power", { 25203, 25204, 25205, 25206 }, {
	boost("Attack", 5, 0.15),
	boost("Strength", 5, 0.15),
	boost("Defence", 5, 0.15),
	boost("Ranged", 5, 0.15),
	boost("Magic", 5, 0.15),
	restore("Prayer", 8, 0.25),
})
use("Release", "Sunlight moth", { 28890 }, { sunlight_moth() })
drink("Sunlight moth mix", { 29192, 29210 }, { sunlight_moth() })
use("Release", "Moonlight moth", { 28893 }, { restore("Prayer", 22) })
drink("Moonlight moth mix", { 29195, 29213 }, { restore("Prayer", 22) })
use("Release", "Snowy knight", { 10016 }, { food(15) })
drink("Snowy knight mix", { 29183, 29201 }, { food(8) })
use("Release", "Ruby harvest", { 10020 }, { boost("Attack", 4, 0.15) })
drink("Ruby harvest mix", { 29186, 29204 }, { boost("Attack", 4, 0.15) })
use("Release", "Black warlock", { 10014 }, { boost("Strength", 4, 0.15) })
drink("Black warlock mix", { 29189, 29207 }, { boost("Strength", 4, 0.15) })
use("Release", "Sapphire glacialis", { 10018 }, { boost("Defence", 4, 0.15) })
drink("Sapphire glacialis mix", { 29180, 29198 }, { boost("Defence", 4, 0.15) })
drink("Antipoison", { 2446, 175, 177, 179 }, {}, { special = { special("antipoison", 150) } })
drink("Superantipoison", { 2448, 181, 183, 185 }, {}, { special = { special("antipoison", 600) } })
drink("Antidote+", { 5943, 5945, 5947, 5949 }, {}, { special = { special("antipoison", 900) } })
drink("Antidote++", { 5952, 5954, 5956, 5958 }, {}, { special = { special("antipoison", 1200) } })
drink(
	"Anti-venom",
	{ 12905, 12907, 12909, 12911 },
	{},
	{ special = { special("antivenom", 30), special("antipoison", 1200) } }
)
drink(
	"Anti-venom+",
	{ 12913, 12915, 12917, 12919 },
	{},
	{ special = { special("antivenom", 300), special("antipoison", 1500) } }
)
drink(
	"Extended anti-venom+",
	{ 29824, 29827, 29830, 29833 },
	{},
	{ special = { special("antivenom", 600), special("antipoison", 1700) } }
)
drink("Antipoison (-)", { 25757, 25756, 25755, 25754 }, {}, { special = { special("antipoison") } })
drink("Antipoison potion", { 25761, 25760, 25759, 25758 }, {}, { special = { special("antipoison") } })
drink("Antipoison (+)", { 25765, 25764, 25763, 25762 }, {}, { special = { special("antipoison") } })
drink("Antifire potion", { 2452, 2454, 2456, 2458 }, {}, { special = { special("antifire", 600) } })
drink("Extended antifire", { 11951, 11953, 11955, 11957 }, {}, { special = { special("antifire", 1200) } })
drink("Super antifire potion", { 21978, 21981, 21984, 21987 }, {}, { special = { special("super_antifire", 300) } })
drink("Extended super antifire", { 22209, 22212, 22215, 22218 }, {}, { special = { special("super_antifire", 600) } })
drink("Absorption", { 11734, 11735, 11736, 11737 }, {}, { special = { special("absorption") } })
drink("Goading potion", { 30137, 30140, 30143, 30146 }, {}, { special = { special("goading") } })
drink(
	"Prayer regeneration potion",
	{ 30125, 30128, 30131, 30134 },
	{},
	{ special = { special("prayer_regeneration", 800) } }
)
drink(
	"Surge potion",
	{ 30875, 30878, 30881, 30884 },
	{ restore("Special attack", 25) },
	{ special = { special("surge", 500) } }
)
drink("Relicym's balm", { 4842, 4844, 4846, 4848 }, {}, { special = { special("cure_disease") } })
use("Apply", "Haemostatic dressing", { 31590, 31593, 31596, 31599 }, {}, { special = { special("cure_bleed") } })
drink("Liquid adrenaline", { 27339, 27341 }, {}, { special = { special("liquid_adrenaline", 250) } })
drink("Prayer enhance (-)", { 20964, 20963, 20962, 20961 }, {}, { special = { special("prayer_enhance") } })
drink("Prayer enhance", { 20968, 20967, 20966, 20965 }, {}, { special = { special("prayer_enhance") } })
drink("Prayer enhance (+)", { 20972, 20971, 20970, 20969 }, {}, { special = { special("prayer_enhance") } })
eat("Kebab", { 1971 }, { food(3, 0.07) })
eat("Super kebab", { 4608 }, { food(3, 0.07) })
eat("Varlamorian kebab", { 29900 }, { food(4, 0.1) })
drink("Damiana tea", { 30981, 30983 }, { food(4), restore("Run energy", 6) })
eat("Caerula berries", { 30937 }, { food(2) })
eat("Blueberry muffin", { 31128 }, { food(4) })
drink("Tea flask", { 10859 }, { food(3) })
eat("Cooked wild kebbit", { 29128 }, { food(4), later(4) })
eat("Cooked barb-tailed kebbit", { 29131 }, { food(7), later(5) })
eat("Cooked larupia", { 29146 }, { food(6), later(5) })

local BY_ID: { [number]: Consumable } = {}
for _, c in ipairs(LIST) do
	for _, id in ipairs(c.ids) do
		BY_ID[id] = c
	end
end

Consumables.LIST = LIST

function Consumables.get(id: number): Consumable?
	return BY_ID[id]
end

function Consumables.levels(): Levels?
	local s = game_state()
	if s.skills == nil or s.run_energy == nil then
		return nil
	end
	local spec = Varps.get(Varps.SPECIAL_ATTACK)
	if spec == nil then
		return nil
	end
	local levels: Levels = {}
	for _, skill in ipairs(s.skills) do
		levels[skill.name] = { level = skill.level, real = skill.real_level }
	end
	levels["Run energy"] = { level = s.run_energy // 100, real = 100 }
	levels["Special attack"] = { level = spec // 10, real = 100 }
	return levels
end

local function copy(levels: Levels): Levels
	local out: Levels = {}
	for stat, l in pairs(levels) do
		out[stat] = { level = l.level, real = l.real }
	end
	return out
end

local function apply(levels: Levels, c: Change, high: boolean)
	local s = levels[c.stat]
	if s == nil then
		return
	end
	local amount
	if c.amount then
		amount = c.amount(levels)
	else
		local flat = if high and c.up_to then c.up_to else c.flat
		amount = flat + part(if c.of_current then s.level else s.real, c.percent)
	end
	local cap = s.real
	if c.boost and amount > 0 then
		cap += amount
	end
	cap = math.max(cap, s.level)
	s.level = math.max(0, math.min(s.level + amount, cap))
end

function Consumables.result(id: number, levels: Levels?): { [string]: Outcome }?
	local c = BY_ID[id]
	local from = levels or Consumables.levels()
	if c == nil or from == nil then
		return nil
	end
	local low, high = copy(from), copy(from)
	for _, change in ipairs(c.changes) do
		apply(low, change, false)
		apply(high, change, true)
	end
	local out: { [string]: Outcome } = {}
	for _, change in ipairs(c.changes) do
		local stat = change.stat
		if from[stat] and out[stat] == nil then
			out[stat] = { from = from[stat].level, low = low[stat].level, high = high[stat].level }
		end
	end
	return out
end

function Consumables.raising(stat: string, at: number, levels: Levels?): { Consumable }
	local base = levels or Consumables.levels()
	local out: { Consumable } = {}
	if base == nil or base[stat] == nil then
		return out
	end
	local test = copy(base)
	test[stat].level = at
	for _, c in ipairs(LIST) do
		local r = Consumables.result(c.ids[1], test)
		local o = r and r[stat]
		if o and o.high > at then
			table.insert(out, c)
		end
	end
	return out
end

function Consumables.with_special(name: string): { Consumable }
	local out: { Consumable } = {}
	for _, c in ipairs(LIST) do
		for _, s in ipairs(c.special) do
			if s.name == name then
				table.insert(out, c)
				break
			end
		end
	end
	return out
end

local function scaled(varbit: number, ticks: number): () -> number?
	return function()
		local value = Varbits.get(varbit)
		return if value == nil then nil else value * ticks
	end
end

local VENOM = -38

local REMAINING: { [string]: () -> number? } = {
	stamina = function()
		local on, left = Varbits.get(25), Varbits.get(24)
		if on == nil or left == nil then
			return nil
		end
		return if on == 1 then left * 10 else 0
	end,
	antifire = scaled(3981, 30),
	super_antifire = scaled(6101, 20),
	antipoison = function()
		local value = Varps.get(Varps.POISON)
		if value == nil then
			return nil
		end
		return if value < 0 then -value * 30 else 0
	end,
	antivenom = function()
		local value = Varps.get(Varps.POISON)
		if value == nil then
			return nil
		end
		return if value < VENOM then -(value - VENOM) * 30 else 0
	end,
	divine_attack = scaled(8429, 1),
	divine_strength = scaled(8430, 1),
	divine_defence = scaled(8431, 1),
	divine_ranging = scaled(8432, 1),
	divine_magic = scaled(8433, 1),
	divine_combat = scaled(13663, 1),
	divine_bastion = scaled(13664, 1),
	divine_battlemage = scaled(13665, 1),
	moonlight = scaled(10029, 1),
	overload = scaled(3955, 25),
	xeric_overload = scaled(5418, 25),
	blighted_overload = scaled(10954, 25),
	imbued_heart = scaled(5361, 10),
	surge = scaled(16270, 10),
	stat_renewal = scaled(14448, 25),
	prayer_regeneration = scaled(11361, 12),
	goading = scaled(11294, 6),
	smelling_salts = scaled(14344, 25),
	prayer_enhance = function()
		local left, rate = Varbits.get(5417), Varbits.get(5419)
		if left == nil or rate == nil then
			return nil
		end
		return left * rate
	end,
	absorption = scaled(3956, 1),
}

function Consumables.remaining(name: string): number?
	local read = REMAINING[name]
	return if read then read() else nil
end

return Consumables
