--!strict
-- Lists what each transport interface offers, for the ones within reach: it tries each in turn, opens the one at the nearest
-- object or NPC, prints its destinations and closes it again. Goes nowhere; each section ends with the call that would travel.
local Balloon = require("@lib/main/interfaces/mainscreen/balloon")
local Canoe = require("@lib/main/interfaces/mainscreen/canoe")
local Chartering = require("@lib/main/interfaces/mainscreen/chartering")
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")
local Gnomeglider = require("@lib/main/interfaces/mainscreen/gnomeglider")
local House = require("@lib/main/house")
local Jewellerybox = require("@lib/main/interfaces/mainscreen/jewellerybox")
local Minecart = require("@lib/main/interfaces/mainscreen/minecart")
local Minigames = require("@lib/main/interfaces/mainscreen/minigames")
local Mounted = require("@lib/main/interfaces/mainscreen/mounted")
local Mushtree = require("@lib/main/interfaces/mainscreen/mushtree")
local Nexus = require("@lib/main/interfaces/mainscreen/nexus")
local Obelisk = require("@lib/main/interfaces/mainscreen/obelisk")
local Quetzal = require("@lib/main/interfaces/mainscreen/quetzal")
local Scrollbook = require("@lib/main/interfaces/mainscreen/scrollbook")
local Spirittree = require("@lib/main/interfaces/mainscreen/spirittree")

type Section = { name: string, run: () -> (boolean, string?) }

local sections: { Section } = {
	{
		name = "Balloon",
		run = function()
			for name, count in Balloon.check() or {} do
				print(`  logs: {name} x{count}`)
			end
			local ok, why = Balloon.open()
			if not ok then
				return false, why
			end
			for _, d in ipairs(Balloon.destinations() or {}) do
				print(`  {d.name} ({d.log.name}, {if d.unlocked then "unlocked" else "locked"})`)
			end
			-- To fly, spending a log: Balloon.select(Balloon.Place.Varrock)
			return Balloon.close(), "couldn't close the map"
		end,
	},
	{
		name = "Canoe",
		run = function()
			local keeper = Canoe.keeper()
			if keeper == nil then
				return false, "no canoe station here"
			end
			print(`  next step: {Canoe.stage()}, axes from {keeper.name}`)
			-- To paddle, making the smallest canoe for 1 stop: Canoe.travel("The Clock Tower", Canoe.Kind.Log)
			return true
		end,
	},
	{
		name = "Charter ship",
		run = function()
			if not Chartering.Tab.is_open() and not Chartering.Map.is_open() then
				return false, "talk to a trader first"
			end
			for _, d in ipairs(Chartering.Tab.destinations() or {}) do
				print(`  list: {d.key} {d.name}`)
			end
			for index, name in pairs(Chartering.Map.names() or {}) do
				print(`  map marker {index}: {name}`)
			end
			-- To sail: Chartering.select(Chartering.Port.Catherby)
			return true
		end,
	},
	{
		name = "Fairy ring",
		run = function()
			local ok, why = Fairyring.open()
			if not ok then
				return false, why
			end
			print(`  dials: {Fairyring.Dial.code()}`)
			for _, d in ipairs(Fairyring.Log.destinations() or {}) do
				print(`  {d.code}: {d.name}`)
			end
			-- To travel, by a code or part of a place's name: Fairyring.travel("aiq") or Fairyring.travel("mudskipper")
			return Fairyring.close(), "couldn't close the dials"
		end,
	},
	{
		name = "Gnome glider",
		run = function()
			local ok, why = Gnomeglider.open()
			if not ok then
				return false, why
			end
			for _, d in ipairs(Gnomeglider.destinations() or {}) do
				print(`  {d.name}`)
			end
			-- To travel: Gnomeglider.select(Gnomeglider.Site.KarHewo)
			return Gnomeglider.close(), "couldn't close the map"
		end,
	},
	{
		name = "Jewellery box",
		run = function()
			if not House.inside() then
				return false, "not in a house"
			end
			local ok, why = Jewellerybox.open()
			if not ok then
				return false, why
			end
			for _, d in ipairs(Jewellerybox.destinations() or {}) do
				print(`  {d.key}: {d.name} ({d.jewellery}, {if d.available then "available" else "unavailable"})`)
			end
			-- To travel: Jewellerybox.select(Jewellerybox.Place.GrandExchange)
			return Jewellerybox.close(), "couldn't close the menu"
		end,
	},
	{
		name = "Minecart",
		run = function()
			if not Minecart.open() then
				return false, "no minecart here"
			end
			for _, d in ipairs(Minecart.destinations() or {}) do
				print(`  {d.key}: {d.name}`)
			end
			-- To travel: Minecart.select(Minecart.Stop.Lovakengj)
			return Minecart.close(), "couldn't close the list"
		end,
	},
	{
		name = "Minigame teleports",
		run = function()
			local ok, why = Minigames.open()
			if not ok then
				return false, why
			end
			for _, t in ipairs(Minigames.teleports() or {}) do
				print(`  {t.name}: {t.location}`)
			end
			-- To teleport, which starts the 20 minute cooldown once it finishes: Minigames.teleport("Castle Wars")
			return Minigames.close(), "couldn't close the list"
		end,
	},
	{
		name = "Mounted jewellery",
		run = function()
			if not Mounted.is_open() then
				return false, "open a mounted piece first (in a house: its Teleport option)"
			end
			for _, d in ipairs(Mounted.destinations() or {}) do
				print(`  {d.name}`)
			end
			-- To go, from inside the house without opening it first: Mounted.teleport("talisman", "Glade")
			return Mounted.close(), "couldn't close it"
		end,
	},
	{
		name = "Mushtree",
		run = function()
			if not Mushtree.open() then
				return false, "no mushtree here"
			end
			for _, d in ipairs(Mushtree.destinations() or {}) do
				print(`  {d.number}: {d.name}`)
			end
			-- To travel: Mushtree.select(Mushtree.Tree.VerdantValley)
			return Mushtree.close(), "couldn't close the list"
		end,
	},
	{
		name = "Portal nexus",
		run = function()
			if not House.inside() then
				return false, "not in a house"
			end
			local ok, why = Nexus.open()
			if not ok then
				return false, why
			end
			for _, d in ipairs(Nexus.destinations() or {}) do
				print(`  {d.key}: {d.name}`)
			end
			-- To go: Nexus.select("Barrows")
			return Nexus.close(), "couldn't close the list"
		end,
	},
	{
		name = "Wilderness obelisk",
		run = function()
			if not Obelisk.open() then
				return false, "no obelisk here, or no Wilderness hard diary"
			end
			for _, d in ipairs(Obelisk.destinations() or {}) do
				print(`  {d.name}`)
			end
			-- To go: Obelisk.select(Obelisk.Level.Level19), then Obelisk.teleport()
			return Obelisk.close(), "couldn't close the list"
		end,
	},
	{
		name = "Quetzal",
		run = function()
			if not Quetzal.open() then
				return false, "no Renu here"
			end
			for index, name in pairs(Quetzal.names() or {}) do
				print(`  marker {index}: {name}`)
			end
			-- To travel: Quetzal.select(Quetzal.Site.Aldarin)
			return Quetzal.close(), "couldn't close the map"
		end,
	},
	{
		name = "Master scroll book",
		run = function()
			local ok, why = Scrollbook.open()
			if not ok then
				return false, why
			end
			for _, s in ipairs(Scrollbook.scrolls() or {}) do
				print(`  {s.name} x{s.count}`)
			end
			-- To teleport, spending a scroll: Scrollbook.select(Scrollbook.Name.Watson)
			return Scrollbook.close(), "couldn't close the book"
		end,
	},
	{
		name = "Spirit tree",
		run = function()
			if Spirittree.nearest() == nil or not Spirittree.open() then
				return false, "no spirit tree here"
			end
			for _, name in ipairs(Spirittree.names() or {}) do
				print(`  {name}`)
			end
			-- To travel: Spirittree.select(Spirittree.Place.GrandExchange)
			return Spirittree.close(), "couldn't close the list"
		end,
	},
}

for _, section in ipairs(sections) do
	print(`{section.name}:`)
	local ok, why = section.run()
	if not ok then
		print(`  skipped: {why or "not here"}`)
	end
end
