--!strict
local Host = require("@lib/host")
local sleep = Host.sleep
type Loc = Host.Loc
local Biometrics = require("@lib/main/antiban/biometrics")
local ChatOptions = require("@lib/main/interfaces/chatbox/chat_options")
local Log = require("@lib/utils/log")
local Magic = require("@lib/main/interfaces/gametabs/magic")
local Minimenu = require("@lib/main/interfaces/minimenu")
local Objects = require("@lib/main/entities/objects")
local Player = require("@lib/main/player")
local Random = require("@lib/utils/math/random")
local Widgets = require("@lib/main/interfaces/widgets")

local OccultAltar = {}

OccultAltar.NAME = "Altar of the Occult"
OccultAltar.OPTION = "Venerate"
OccultAltar.DIALOGUE_TIMEOUT_MS = 8000
OccultAltar.SWAP_TIMEOUT_MS = 8000
OccultAltar.POLL_MS = 100
OccultAltar.HOVER_MS = 350

export type Book = "standard" | "ancient" | "lunar" | "arceuus"

OccultAltar.Book = table.freeze({
	Standard = "standard",
	Ancient = "ancient",
	Lunar = "lunar",
	Arceuus = "arceuus",
}) :: {
	Standard: "standard",
	Ancient: "ancient",
	Lunar: "lunar",
	Arceuus: "arceuus",
}

local LABELS: { [string]: string } = {
	standard = "Standard",
	ancient = "Ancient",
	lunar = "Lunar",
	arceuus = "Arceuus",
}

function OccultAltar.nearest(): Loc?
	local me = Player.position()
	if me == nil then
		return nil
	end
	return Objects.nearest(OccultAltar.NAME, me)
end

function OccultAltar.books(altar: Loc?): { Book }?
	local target = altar or OccultAltar.nearest()
	if target == nil or not Objects.hover(target) then
		return nil
	end
	sleep(OccultAltar.HOVER_MS)
	local found: { Book } = {}
	for _, entry in ipairs(Minimenu.entries() or {}) do
		if Objects.owns(target, entry) then
			local book = string.lower(entry.option)
			if LABELS[book] ~= nil then
				table.insert(found, book :: any)
			end
		end
	end
	return found
end

function OccultAltar.is_dialogue_open(): boolean
	local options = ChatOptions.get()
	if options == nil or #options == 0 then
		return false
	end
	for _, option in ipairs(options) do
		if LABELS[string.lower(option.text)] == nil then
			return false
		end
	end
	return true
end

function OccultAltar.venerate(altar: Loc?): (boolean, string?)
	if OccultAltar.is_dialogue_open() then
		return true, nil
	end
	local target = altar or OccultAltar.nearest()
	if target == nil then
		return false, "no altar around"
	end
	if not Objects.approach(target, OccultAltar.OPTION) then
		return false, `couldn't {OccultAltar.OPTION} the altar`
	end
	if Widgets.wait_within(OccultAltar.is_dialogue_open, OccultAltar.DIALOGUE_TIMEOUT_MS, OccultAltar.POLL_MS) then
		return true, nil
	end
	return false, "the dialogue didn't open"
end

local function swapped(book: Book, label: string): (boolean, string?)
	local done = Widgets.wait_within(function(): boolean
		return Magic.is_spellbook(book)
	end, OccultAltar.SWAP_TIMEOUT_MS, OccultAltar.POLL_MS)
	if done then
		return true, nil
	end
	return false, `the book didn't change to {label}`
end

function OccultAltar.choose(book: Book, key_probability: number?): (boolean, string?)
	local label = LABELS[book]
	if label == nil then
		return false, `unknown spellbook "{book}"`
	end
	if not OccultAltar.is_dialogue_open() or ChatOptions.find(label, true) == nil then
		return false, `the dialogue doesn't offer {label}`
	end
	if not ChatOptions.select(label, true, key_probability) and ChatOptions.find(label, true) ~= nil then
		ChatOptions.select(label, true, 0)
	end
	return swapped(book, label)
end

function OccultAltar.swap_by_menu(book: Book, altar: Loc?): (boolean, string?)
	local label = LABELS[book]
	if label == nil then
		return false, `unknown spellbook "{book}"`
	end
	local target = altar or OccultAltar.nearest()
	if target == nil then
		return false, "no altar around"
	end
	if not Objects.approach(target, label) then
		return false, `the altar doesn't offer {label}`
	end
	return swapped(book, label)
end

function OccultAltar.swap(book: Book, via: ("menu" | "dialogue")?, altar: Loc?): (boolean, string?)
	if Magic.is_spellbook(book) then
		return true, nil
	end
	if LABELS[book] == nil then
		return false, `unknown spellbook "{book}"`
	end
	local by_menu = via == "menu"
		or (
			via == nil
			and not OccultAltar.is_dialogue_open()
			and Random.chance(Biometrics.get_probability(Biometrics.CHOOSEOPTION))
		)
	local ok: boolean, why: string?
	if by_menu then
		ok, why = OccultAltar.swap_by_menu(book, altar)
	else
		ok, why = OccultAltar.venerate(altar)
		if ok then
			ok, why = OccultAltar.choose(book)
		end
	end
	if not ok then
		Log.log("OccultAltar", why or "the swap didn't work")
	end
	return ok, why
end

return OccultAltar
