--!strict
-- Prints the spellbook, which spells can be cast and which wait for a target.
local Magic = require("../main/interfaces/gametabs/magic")

local book = Magic.spellbook()
assert(book, "the spellbook isn't readable")
local spells = Magic.spells()
assert(spells, "the spells aren't readable")
print(`{book} spellbook, {Magic.spell_count()} spells`)
for _, spell in ipairs(spells) do
	if spell.kind ~= "menu" then
		local castable = Magic.can_cast(spell)
		print(if castable then "can cast" else "        -", spell.level, spell.name)
	end
end
local selected = Magic.selected()
print("selected:", if selected then `{selected.verb} {selected.name}` else "nothing")
