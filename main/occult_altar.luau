--!strict
-- The Altar of the Occult in a player's house, which swaps the spellbook. It offers each other book as a menu option, and "Venerate" (its left click) opens a dialogue listing them.
-- A swap is confirmed by the game's spellbook, never assumed from a click. The altar's "Remove" option takes it out of the house; nothing here can click it.
local Host = require("@lib/host")
local sleep = Host.sleep
local time = Host.time
type Loc = Host.Loc
local Biometrics = require("@lib/main/antiban/biometrics")
local ChatOptions = require("@lib/main/interfaces/chatbox/chat_options")
local Log = require("@lib/utils/log")
local Magic = require("@lib/main/interfaces/gametabs/magic")
local Minimenu = require("@lib/main/interfaces/minimenu")
local Objects = require("@lib/main/entities/objects")
local Player = require("@lib/main/player")
local Random = require("@lib/utils/math/random")

local OccultAltar = {}

OccultAltar.NAME = "Altar of the Occult"
OccultAltar.OPTION = "Venerate"
-- How long to wait for the dialogue (the walk is part of it), for the book to change, and between looks.
OccultAltar.DIALOGUE_TIMEOUT_MS = 8000
OccultAltar.SWAP_TIMEOUT_MS = 8000
OccultAltar.POLL_MS = 100
-- How long to wait after hovering the altar for its menu.
OccultAltar.HOVER_MS = 350

-- Every spellbook, as `Magic.spellbook` names it.
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

-- How the altar names each book.
local LABELS: { [string]: string } = {
	standard = "Standard",
	ancient = "Ancient",
	lunar = "Lunar",
	arceuus = "Arceuus",
}

-- The nearest altar loaded, nil when there is none.
function OccultAltar.nearest(): Loc?
	local me = Player.position()
	if me == nil then
		return nil
	end
	return Objects.nearest(OccultAltar.NAME, me)
end

-- The books the altar's menu offers now, found by hovering it: not the one in use, nor one the account hasn't unlocked. Nil when there is no altar to hover.
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

-- Whether the altar's dialogue is open: a list of options that are all books.
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

-- Opens the dialogue with "Venerate", walking to the altar if needed, and waits for it. True also when it was open already. When it didn't work the second result says why.
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
	local deadline = time() + OccultAltar.DIALOGUE_TIMEOUT_MS
	while time() < deadline do
		if OccultAltar.is_dialogue_open() then
			return true, nil
		end
		sleep(OccultAltar.POLL_MS)
	end
	return false, "the dialogue didn't open"
end

local function wait_book(book: Book): boolean
	local deadline = time() + OccultAltar.SWAP_TIMEOUT_MS
	while time() < deadline do
		if Magic.is_spellbook(book) then
			return true
		end
		sleep(OccultAltar.POLL_MS)
	end
	return false
end

-- Picks `book` in the open dialogue, by key or click (`key_probability`; nil is the biometric), by click if the key doesn't take, and waits for the book to change.
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
	if wait_book(book) then
		return true, nil
	end
	return false, `the book didn't change to {label}`
end

-- Swaps to `book` with the altar's menu option, walking to it if needed, and waits for the book to change.
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
	if wait_book(book) then
		return true, nil
	end
	return false, `the book didn't change to {label}`
end

-- Swaps to `book`: true at once when it is in use already. A dialogue left open is answered; otherwise the menu option or the dialogue is used, as the account's biometrics favour.
-- `via` forces one way. When it didn't work the second result says why, and a book that isn't unlocked isn't offered, so that is one of the reasons.
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
