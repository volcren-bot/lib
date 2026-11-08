--!strict
-- The Surprise Exam random event: the Dunce takes you to Mr. Mordaut's classroom (region 7502), where two kinds of question
-- come up, "what comes next" (interface 103, `pattern_next`) and three cards out of fifteen matching a hint (interface 559,
-- `pattern_cards`); once passed, the door out gives the reward. The questions show exam-only models (no item's): `ITEMS`
-- names them and `THEMES` groups them, with the words a card hint uses for each theme.
local Host = require("@lib/host")
local sleep = Host.sleep
local time = Host.time
local widget = Host.widget
local widget_model = Host.widget_model
local ChatOptions = require("@lib/main/interfaces/chatbox/chat_options")
local Interact = require("@lib/main/interact")
local Log = require("@lib/utils/log")
local Npcs = require("@lib/main/entities/npcs")
local Objects = require("@lib/main/entities/objects")
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")
local Walker = require("@lib/main/walker")

local SurpriseExam = {}

-- The classroom's map square, the teacher, the Dunce who brings you and his answer, and the door out.
SurpriseExam.REGION = 7502
SurpriseExam.MORDAUT = 5504
SurpriseExam.DUNCE = 6749
SurpriseExam.ACCEPT = "Sure, I fancy an exam."
SurpriseExam.DOOR = 9316

-- "What comes next": the pattern's three models, the four answers' models (each answer is clicked on its model), "Select".
SurpriseExam.PATTERN = 103
SurpriseExam.PATTERN_SEQUENCE = { 10, 11, 12 }
SurpriseExam.PATTERN_ANSWERS = { 15, 17, 19, 21 }
SurpriseExam.SELECT = "Select"
-- The cards: their models (first card's child, 15 in rows of five), the cells to click, the hint and the confirm button.
SurpriseExam.CARDS = 559
SurpriseExam.CARD_MODELS = 21
SurpriseExam.CARD_CELLS = 52
SurpriseExam.CARD_COUNT = 15
SurpriseExam.CARD_PICKS = 3
SurpriseExam.CARD_HINT = 67
SurpriseExam.CARD_CONFIRM = 68
SurpriseExam.CONFIRM = "Confirm"

-- The data below (every exam model's item, the themes and their hint keywords) is from Random Event Helper
-- (github.com/Infinitay/Random-Event-Helper), under this license:
--
-- Copyright (c) 2025, infinity
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

-- What each exam model shows, by model id.
SurpriseExam.ITEMS = {
	[41168] = "air_rune",
	[41188] = "square_shield_1",
	[41190] = "apron",
	[41177] = "arrows",
	[41176] = "battle_axe",
	[41222] = "banana",
	[41209] = "tuna",
	[41152] = "beer",
	[41207] = "grapes",
	[41182] = "rune_or_essence",
	[41181] = "book",
	[41172] = "bread",
	[41202] = "cake",
	[27102] = "candle_on_stand",
	[41161] = "cheese",
	[41203] = "chefs_hat",
	[27096] = "cocktail_shaker",
	[41204] = "trout_cod_pike_salmon_1",
	[41146] = "crossbow",
	[41162] = "cup_of_tea",
	[41175] = "bottle",
	[41157] = "earth_rune",
	[41165] = "eye_patch",
	[41224] = "feather",
	[41215] = "fire_rune",
	[27101] = "frog_mask",
	[27097] = "cocktail_1",
	[41178] = "full_helm",
	[41226] = "onion",
	[41151] = "gem_with_cross",
	[41219] = "gin_or_rum",
	[41183] = "hammer",
	[41158] = "harpoon",
	[41184] = "axe",
	[41193] = "herring_or_mackerel",
	[41195] = "highwayman_mask",
	[41196] = "jester_hat",
	[41225] = "jug",
	[41200] = "kiteshield",
	[41229] = "candle_lantern",
	[41164] = "lederhosen_hat",
	[41167] = "cape_of_legends",
	[41232] = "logs",
	[41198] = "longbow",
	[41150] = "longsword",
	[41211] = "mace",
	[41189] = "med_helm",
	[41153] = "bar",
	[41191] = "mime_mask",
	[41216] = "necklace",
	[41199] = "needle",
	[41170] = "ore",
	[41194] = "pickaxe",
	[41205] = "pie",
	[41206] = "trout_cod_pike_salmon_2",
	[41214] = "pineapple",
	[41186] = "pirate_boots",
	[41187] = "pirate_hat",
	[41228] = "pirate_hook",
	[41185] = "pizza",
	[41208] = "plant_pot",
	[41179] = "platelegs",
	[41223] = "pot",
	[41212] = "rake",
	[41220] = "leather_boots",
	[27091] = "ring",
	[41221] = "wooden_shield",
	[27094] = "platebody",
	[41163] = "trout_cod_pike_salmon_3",
	[41159] = "holy_symbol",
	[41173] = "fish",
	[41192] = "scimitar",
	[41197] = "secateurs",
	[28421] = "cocktail_2",
	[41166] = "shark",
	[41227] = "shears",
	[41171] = "short_bow",
	[41147] = "shrimp",
	[27104] = "insulated_boots",
	[41160] = "fighter_boots",
	[41155] = "spade",
	[41169] = "square_shield_2",
	[41174] = "staff",
	[41230] = "strawberry",
	[41201] = "kitchen_knife",
	[41218] = "thread",
	[41148] = "tiara",
	[41154] = "tinderbox",
	[41217] = "trout_cod_pike_salmon_4",
	[41210] = "gardening_trowel",
	[41180] = "bass",
	[41149] = "potion",
	[41213] = "watering_can",
	[41156] = "watermelon_slice",
	[41231] = "water_rune",
	[2674] = "bones",
	[29232] = "key",
} :: { [number]: string }

-- Themes: the items that go together, and the words a card hint uses for them.
SurpriseExam.THEMES = {
	combat_ecosystem = {
		items = {
			"bones",
			"battle_axe",
			"longsword",
			"mace",
			"scimitar",
			"crossbow",
			"longbow",
			"short_bow",
			"arrows",
			"staff",
			"potion",
		},
		keywords = { "combat", "prayer", "bones", "weapons", "battle", "fighting" },
	},
	fishing_to_cooking = {
		items = {
			"harpoon",
			"tuna",
			"shark",
			"bass",
			"trout_cod_pike_salmon_1",
			"trout_cod_pike_salmon_2",
			"trout_cod_pike_salmon_3",
			"trout_cod_pike_salmon_4",
			"herring_or_mackerel",
			"shrimp",
			"fish",
		},
		keywords = { "fishing", "cooking", "harpoon", "fish", "tuna", "shark", "food" },
	},
	mining_smithing_crafting = {
		items = { "pickaxe", "ore", "bar", "gem_with_cross", "hammer" },
		keywords = { "mining", "smithing", "crafting", "pickaxe", "ore", "bar", "hammer" },
	},
	woodcutting_fletching = {
		items = { "axe", "logs", "longbow", "short_bow", "arrows", "feather" },
		keywords = { "woodcutting", "fletching", "axe", "logs", "bow", "arrows", "feather" },
	},
	farming_ecosystem = {
		items = {
			"rake",
			"gardening_trowel",
			"watering_can",
			"secateurs",
			"spade",
			"plant_pot",
			"shears",
			"banana",
			"grapes",
			"pineapple",
			"strawberry",
			"watermelon_slice",
			"onion",
		},
		keywords = { "farming", "agriculture", "rake", "seeds", "crops", "harvest", "plants" },
	},
	cooking_production = {
		items = {
			"kitchen_knife",
			"pot",
			"tuna",
			"bread",
			"cake",
			"cheese",
			"pie",
			"pizza",
			"banana",
			"grapes",
			"onion",
			"chefs_hat",
			"apron",
		},
		keywords = { "cooking", "food", "chef", "kitchen", "bread", "cake", "meals" },
	},
	alcohol_production = {
		items = { "grapes", "beer", "gin_or_rum", "cocktail_1", "cocktail_2", "cocktail_shaker", "bottle", "jug" },
		keywords = { "alcohol", "brewing", "cocktail", "beer", "rum", "gin", "drinks" },
	},
	magic_runecrafting = {
		items = { "rune_or_essence", "air_rune", "earth_rune", "fire_rune", "water_rune", "staff", "book", "tiara" },
		keywords = {
			"magic",
			"runecrafting",
			"runes",
			"essence",
			"spells",
			"staff",
			"abracadabra",
			"hocus pocus",
			"wizard",
		},
	},
	jewelry_crafting = {
		items = { "gem_with_cross", "necklace", "ring", "holy_symbol", "tiara" },
		keywords = {
			"jewelry",
			"gems",
			"necklace",
			"ring",
			"crafting",
			"status",
			"shiny",
			"precious",
			"wearing all your bangles",
			"bobbles and fineries",
			"accessory",
			"accessories",
			"silver",
			"gold",
		},
	},
	light_fire_system = {
		items = { "tinderbox", "candle_on_stand", "candle_lantern", "logs" },
		keywords = { "fire", "light", "candle", "lantern", "tinderbox", "illumination", "ignite", "igniting" },
	},
	container_storage = {
		items = { "bottle", "jug", "pot", "plant_pot", "cocktail_shaker" },
		keywords = { "container", "storage", "bottle", "jug", "pot", "holding" },
	},
	pirate_theme = {
		items = { "pirate_hat", "pirate_boots", "pirate_hook", "eye_patch", "highwayman_mask" },
		keywords = { "pirate", "sea", "nautical", "hook", "eyepatch", "boots", "hat", "yarr", "crime", "strange" },
	},
	entertainment_theme = {
		items = { "jester_hat", "mime_mask", "frog_mask", "highwayman_mask", "lederhosen_hat", "pirate_hat" },
		keywords = {
			"entertainment",
			"performance",
			"jester",
			"mime",
			"mask",
			"fun",
			"clown",
			"fool",
			"mask",
			"face",
			"strange",
			"hairstyle",
			"garment",
			"garments",
		},
	},
	professional_theme = {
		items = { "chefs_hat", "apron", "lederhosen_hat" },
		keywords = { "profession", "work", "chef", "trade", "job", "occupation" },
	},
	melee_weapons = {
		items = { "battle_axe", "longsword", "mace", "scimitar" },
		keywords = { "melee", "sword", "axe", "mace", "scimitar", "close", "combat", "sharp" },
	},
	ranged_weapons = {
		items = { "crossbow", "longbow", "short_bow", "arrows" },
		keywords = { "ranged", "bow", "crossbow", "arrows", "ammunition", "distance", "sharp" },
	},
	magic_runes = {
		items = { "air_rune", "earth_rune", "fire_rune", "water_rune" },
		keywords = { "runes", "elemental", "air", "earth", "fire", "water", "magic", "abracadabra", "hocus pocus" },
	},
	head_armor = {
		items = {
			"full_helm",
			"med_helm",
			"chefs_hat",
			"pirate_hat",
			"jester_hat",
			"lederhosen_hat",
			"tiara",
			"highwayman_mask",
			"mime_mask",
			"frog_mask",
		},
		keywords = { "head", "helmet", "hat", "protection", "headwear", "skull", "mask", "headgear" },
	},
	body_armor = {
		items = { "platebody", "apron" },
		keywords = { "body", "chest", "torso", "platebody", "apron", "protection" },
	},
	leg_armor = {
		items = { "platelegs" },
		keywords = { "legs", "platelegs", "protection", "lower", "body" },
	},
	foot_armor = {
		items = { "insulated_boots", "pirate_boots", "leather_boots", "fighter_boots" },
		keywords = { "feet", "boots", "footwear", "walking", "protection" },
	},
	shields = {
		items = { "square_shield_1", "square_shield_2", "kiteshield", "wooden_shield" },
		keywords = { "shield", "defense", "blocking", "protection", "guard" },
	},
	melee_gear = {
		items = {
			"battle_axe",
			"longsword",
			"mace",
			"scimitar",
			"full_helm",
			"med_helm",
			"platebody",
			"platelegs",
			"square_shield_1",
			"square_shield_2",
			"kiteshield",
			"wooden_shield",
		},
		keywords = {
			"melee",
			"sword",
			"scimitar",
			"axe",
			"mace",
			"combat",
			"sharp",
			"helmet",
			"platebody",
			"platelegs",
			"shield",
		},
	},
	jewelry_accessories = {
		items = { "necklace", "ring", "holy_symbol" },
		keywords = {
			"jewelry",
			"accessories",
			"accessory",
			"necklace",
			"ring",
			"status",
			"shiny",
			"precious",
			"wearing all your bangles",
			"bobbles and fineries",
			"silver",
			"gold",
		},
	},
	face_accessories = {
		items = { "eye_patch", "frog_mask", "highwayman_mask", "mime_mask", "pirate_hook" },
		keywords = { "face", "mask", "eyepatch", "hook", "covering", "facial" },
	},
	all_skilling_tools = {
		items = {
			"pickaxe",
			"axe",
			"harpoon",
			"needle",
			"thread",
			"hammer",
			"tinderbox",
			"rake",
			"secateurs",
			"shears",
			"gardening_trowel",
			"spade",
			"watering_can",
			"kitchen_knife",
		},
		keywords = { "tools", "skills", "gathering", "resources", "equipment", "utility" },
	},
	mining_tools = {
		items = { "pickaxe", "ore", "bar", "gem_with_cross" },
		keywords = { "mining", "pickaxe", "ore", "rocks", "gems", "underground" },
	},
	fishing_tools = {
		items = { "harpoon", "tuna", "shark", "bass", "shrimp" },
		keywords = { "fishing", "harpoon", "fish", "water", "catching", "sea", "sea food" },
	},
	farming_tools = {
		items = { "rake", "secateurs", "shears", "gardening_trowel", "spade", "watering_can", "plant_pot" },
		keywords = { "farming", "gardening", "rake", "spade", "plants", "agriculture" },
	},
	crafting_tools = {
		items = { "needle", "thread", "hammer" },
		keywords = { "crafting", "needle", "thread", "making", "creating", "tailoring" },
	},
	fish = {
		items = {
			"tuna",
			"trout_cod_pike_salmon_1",
			"trout_cod_pike_salmon_2",
			"trout_cod_pike_salmon_3",
			"trout_cod_pike_salmon_4",
			"herring_or_mackerel",
			"shark",
			"shrimp",
			"bass",
			"fish",
		},
		keywords = { "fish", "raw", "uncooked", "sea", "food", "sea food", "seafood", "fishing", "water" },
	},
	fruits = {
		items = { "banana", "grapes", "pineapple", "strawberry", "watermelon_slice" },
		keywords = { "fruits", "berries", "fresh", "healthy", "vitamins", "nature" },
	},
	baking_food = {
		items = { "bread", "cake", "cheese", "pie", "pizza" },
		keywords = { "cooked", "food", "meals", "prepared", "baked", "ready" },
	},
	alcoholic_drinks = {
		items = { "beer", "gin_or_rum", "cocktail_1", "cocktail_2" },
		keywords = { "alcohol", "drinks", "beer", "spirits", "intoxicating", "beverages", "thirsty", "dehydrated" },
	},
	drinks = {
		items = { "beer", "gin_or_rum", "cocktail_1", "cocktail_2", "cup_of_tea", "bottle", "jug", "potion" },
		keywords = { "drink", "beverage", "refreshing", "hydrate", "quench", "thirsty", "liquid", "sip", "dehydrated" },
	},
	combat_consumables = {
		items = { "bones", "potion" },
		keywords = { "combat", "consumable", "potion", "bones", "prayer", "aid" },
	},
	light_sources = {
		items = { "candle_on_stand", "candle_lantern" },
		keywords = { "light", "illumination", "candle", "lantern", "brightness", "glow" },
	},
	resource_materials = {
		items = { "rune_or_essence", "ore", "logs", "feather", "thread" },
		keywords = { "resources", "materials", "raw", "crafting", "essence", "components" },
	},
} :: { [string]: { items: { string }, keywords: { string } } }

SurpriseExam.QUESTION_TIMEOUT_MS = 6000
SurpriseExam.ANSWER_SETTLE_MS = 1200
SurpriseExam.POLL_MS = 100
SurpriseExam.LEAVE_TIMEOUT_MS = 8000

-- item -> the themes it is in, built from THEMES
local themes_of: { [string]: { string } } = {}
for theme, def in SurpriseExam.THEMES do
	for _, item in def.items do
		themes_of[item] = themes_of[item] or {}
		table.insert(themes_of[item], theme)
	end
end

-- Whether we're in the classroom: its map square, or the teacher there.
function SurpriseExam.inside(): boolean
	local pos = Host.game_state().position
	if pos and (pos.x // 64) * 256 + pos.y // 64 == SurpriseExam.REGION then
		return true
	end
	local teacher = Npcs.find(SurpriseExam.MORDAUT)
	return teacher ~= nil and #teacher > 0
end

-- What an exam model shows, nil when ITEMS doesn't list it.
function SurpriseExam.item(model: number): string?
	return SurpriseExam.ITEMS[model]
end

local function model_at(group: number, child: number): number?
	local m = widget_model(group, child)
	return if m and m.id and m.id > 0 then m.id else nil
end

local function unknown(models: { number }, what: string)
	local missing = {}
	for _, m in models do
		if SurpriseExam.ITEMS[m] == nil then
			table.insert(missing, tostring(m))
		end
	end
	if #missing > 0 then
		Log.log("SurpriseExam", `{what}: models not in ITEMS: {table.concat(missing, ", ")}`)
	end
end

-- Whether a theme lists the item.
local function in_theme(theme: string, item: string?): boolean
	return item ~= nil and table.find(SurpriseExam.THEMES[theme].items, item) ~= nil
end

-- "What comes next": the pattern's models and the answers' models, nil when the question isn't open.
function SurpriseExam.pattern(): ({ number }?, { number }?)
	if not Toplevel.is_open(SurpriseExam.PATTERN) then
		return nil, nil
	end
	local sequence, answers = {}, {}
	for _, c in SurpriseExam.PATTERN_SEQUENCE do
		table.insert(sequence, model_at(SurpriseExam.PATTERN, c) or -1)
	end
	for _, c in SurpriseExam.PATTERN_ANSWERS do
		table.insert(answers, model_at(SurpriseExam.PATTERN, c) or -1)
	end
	return sequence, answers
end

-- The answer to "what comes next" (1 to 4): each answer scores over every theme by how many of the row's items the theme
-- has (3: 10 with the answer in it, 4 without; 2: 8 or 2; 1: 3 or 0.5; none: 1 or 0), and the best scoring one is taken.
-- Unknown models are logged.
function SurpriseExam.pattern_answer(sequence: { number }, answers: { number }): number
	unknown(sequence, "pattern")
	unknown(answers, "answers")
	local with = { [0] = 1, [1] = 3, [2] = 8, [3] = 10 }
	local without = { [0] = 0, [1] = 0.5, [2] = 2, [3] = 4 }
	local best, best_score = math.random(1, #answers), -1
	for i, m in answers do
		local candidate = SurpriseExam.ITEMS[m]
		local score = 0
		for theme in SurpriseExam.THEMES do
			local known = 0
			for _, s in sequence do
				if in_theme(theme, SurpriseExam.ITEMS[s]) then
					known += 1
				end
			end
			score += if in_theme(theme, candidate) then with[known] else without[known]
		end
		if score > best_score then
			best, best_score = i, score
		end
	end
	return best
end

-- The cards' models (1 to 15, in rows of five) and the hint, nil when the question isn't open.
function SurpriseExam.cards(): ({ number }?, string?)
	if not Toplevel.is_open(SurpriseExam.CARDS) then
		return nil, nil
	end
	local models = {}
	for i = 0, SurpriseExam.CARD_COUNT - 1 do
		table.insert(models, model_at(SurpriseExam.CARDS, SurpriseExam.CARD_MODELS + i) or -1)
	end
	local hint = widget(SurpriseExam.CARDS, SurpriseExam.CARD_HINT)
	return models, hint and hint.text
end

-- How well each theme fits a hint: 5 for each of its keywords the hint has as a word (or phrase), 3 for one only part of
-- a word matches (arrow in arrows).
function SurpriseExam.hint_scores(hint: string): { [string]: number }
	local lower = string.lower(hint)
	local words: { [string]: boolean } = {}
	for word in string.gmatch(lower, "%a+") do
		words[word] = true
	end
	local scores: { [string]: number } = {}
	for theme, def in SurpriseExam.THEMES do
		local score = 0
		for _, keyword in def.keywords do
			if words[keyword] or (string.find(keyword, " ", 1, true) and string.find(lower, keyword, 1, true)) then
				score += 5
			else
				for word in words do
					if #word > 2 and (string.find(keyword, word, 1, true) or string.find(word, keyword, 1, true)) then
						score += 3
						break
					end
				end
			end
		end
		scores[theme] = score
	end
	return scores
end

-- Three cards (1 to 15) for the hint: each card takes the score of its best fitting theme, the best three are picked.
-- Unknown models, and a hint no theme fits, are logged.
function SurpriseExam.card_answer(models: { number }, hint: string): { number }
	unknown(models, "cards")
	local scores = SurpriseExam.hint_scores(hint)
	local top = 0
	for _, score in scores do
		top = math.max(top, score)
	end
	if top == 0 then
		Log.log("SurpriseExam", `no theme fits the hint "{hint}"`)
	end
	local ranked: { { index: number, score: number } } = {}
	for i, m in models do
		local item = SurpriseExam.ITEMS[m]
		local score = math.random() / 10
		for _, theme in (item and themes_of[item]) or {} do
			score = math.max(score, scores[theme])
		end
		table.insert(ranked, { index = i, score = score })
	end
	table.sort(ranked, function(a, b): boolean
		return a.score > b.score
	end)
	local picks = {}
	for i = 1, SurpriseExam.CARD_PICKS do
		table.insert(picks, ranked[i].index)
	end
	return picks
end

local function click(group: number, child: number, option: string): boolean
	local w = widget(group, child)
	if w == nil or w.hidden then
		return false
	end
	return (Interact.with(w, option))
end

-- Answers the question that is open (either kind). True when an answer was given.
function SurpriseExam.answer(): boolean
	local sequence, answers = SurpriseExam.pattern()
	if sequence and answers then
		local i = SurpriseExam.pattern_answer(sequence, answers)
		Log.log("SurpriseExam", `what comes next: answer {i} (model {answers[i]})`)
		return click(SurpriseExam.PATTERN, SurpriseExam.PATTERN_ANSWERS[i], SurpriseExam.SELECT)
	end
	local models, hint = SurpriseExam.cards()
	if models then
		local picks = SurpriseExam.card_answer(models, hint or "")
		Log.log("SurpriseExam", `cards for "{hint}": {table.concat(picks, ", ")}`)
		for _, i in picks do
			if not click(SurpriseExam.CARDS, SurpriseExam.CARD_CELLS + i - 1, SurpriseExam.SELECT) then
				return false
			end
			sleep(SurpriseExam.POLL_MS * 3)
		end
		return click(SurpriseExam.CARDS, SurpriseExam.CARD_CONFIRM, SurpriseExam.CONFIRM)
	end
	return false
end

-- Out of the classroom by the door (the reward comes then). True once outside.
function SurpriseExam.leave(): boolean
	local me = Walker.position()
	local door = me and Objects.nearest(SurpriseExam.DOOR, me)
	if door == nil or not Objects.interact(door, "Open") then
		Log.log("SurpriseExam", "couldn't open the door out")
		return false
	end
	local deadline = time() + SurpriseExam.LEAVE_TIMEOUT_MS
	while SurpriseExam.inside() and time() < deadline do
		sleep(SurpriseExam.POLL_MS)
	end
	return not SurpriseExam.inside()
end

-- Sits the exam from wherever it is: through the teacher's talk, every question, then out by the door. True once outside.
function SurpriseExam.complete(): boolean
	local idle_since = time()
	while SurpriseExam.inside() do
		if Toplevel.is_open(SurpriseExam.PATTERN) or Toplevel.is_open(SurpriseExam.CARDS) then
			SurpriseExam.answer()
			sleep(SurpriseExam.ANSWER_SETTLE_MS)
			idle_since = time()
		elseif ChatOptions.contains_continue() then
			ChatOptions.continue_chat()
			sleep(SurpriseExam.ANSWER_SETTLE_MS)
			idle_since = time()
		elseif time() - idle_since > SurpriseExam.QUESTION_TIMEOUT_MS then
			-- no question and no talk: the exam is over (passed or not), out by the door
			return SurpriseExam.leave()
		else
			sleep(SurpriseExam.POLL_MS)
		end
	end
	return true
end

-- The Dunce's event: says yes to the exam, then sits it. True once back outside.
function SurpriseExam.accept(dunce: Host.Npc): boolean
	if not Npcs.interact(dunce, "Talk-to") then
		return false
	end
	if not ChatOptions.continue_until_option(SurpriseExam.ACCEPT, SurpriseExam.QUESTION_TIMEOUT_MS) then
		Log.log("SurpriseExam", "the Dunce didn't ask")
		return false
	end
	if not ChatOptions.select(SurpriseExam.ACCEPT) then
		return false
	end
	local deadline = time() + SurpriseExam.QUESTION_TIMEOUT_MS
	while not SurpriseExam.inside() and time() < deadline do
		if ChatOptions.contains_continue() then
			ChatOptions.continue_chat()
		end
		sleep(SurpriseExam.POLL_MS * 5)
	end
	return SurpriseExam.complete()
end

return SurpriseExam
