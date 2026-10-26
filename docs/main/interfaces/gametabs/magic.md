# Main.Interfaces.Gametabs.Magic

The spellbook tab: which spellbook you're on, which spells you can cast, casting them, and the spell waiting for a target.

```luau
local Magic = require("../main/interfaces/gametabs/magic")
```

Nothing here looks at the screen's colours. The spells (names, levels, runes, icons, which button they are) come from the game files, the spellbook from a game setting, and whether a spell can be cast from the icon its button shows. The spell waiting for a target is read from the game.

A spell is given by its name. Case, spaces, dashes and apostrophes don't matter, so `"High Level Alchemy"`, `"high level alchemy"`, `"lvl1 enchant"` and `"Fenkenstrains castle teleport"` all work. A `Spell` returned by these functions can be passed instead of a name.

## Constants

Definition:
```luau
Magic.GROUP = 218
Magic.INFO = 210
Magic.BOOKS = { [0] = "standard", "ancient", "lunar", "arceuus" }
Magic.BOOKS_ENUM = 1981
Magic.JEWELLERY_ENUM = 5285

Magic.FILTERS_PANEL = 203
Magic.FILTERS_ROWS = 206
Magic.FILTERS_BUTTON = 209
Magic.FILTERING_OFF_VARBIT = 6718
Magic.FILTERS = {
	combat = { varbit = 6605, text = "Combat" },
	teleport = { varbit = 6609, text = "Teleport" },
	utility = { varbit = 6606, text = "Utility" },
	level = { varbit = 6607, text = "Magic level" },
	runes = { varbit = 6608, text = "runes" },
	requirements = { varbit = 12137, text = "requirements" },
}
```
The spellbook interface, the part of it that holds the info box about the hovered spell, the spellbook names by number, and the game file tables the spells are read from.

The rest is about spell filters. You turn spell filtering on and off from the right-click menu of the spellbook's tab button. While it's on, a "Filters" button at the bottom of the spellbook opens a panel of checkboxes that hide groups of spells. `FILTERS` names each checkbox: the game setting that is 1 while it hides its spells, and a word of its line in the panel. `level`, `runes` and `requirements` hide the spells you lack the Magic level, runes or requirements to cast.

## Types

Definition:
```luau
export type Spell = {
	name: string,
	book: string,
	menu: string?,
	item: number,
	child: number,
	id: number,
	level: number,
	members: boolean,
	kind: string,
	description: string,
	runes: { { item: number, amount: number } },
	castable: { number },
	disabled: { number },
}
export type SpellRef = string | Spell
```
A spell as the game files describe it. `child` is its button in the spellbook interface (`id` is the full component id). `menu` is `"jewellery"` for the spells inside the jewellery enchantments menu. `kind` is `"combat"`, `"utility"`, `"teleport"` or `"menu"` (the "Back" button). `runes` is what a cast costs. `castable` and `disabled` are the small and large icons the button shows when the spell can or can't be cast.

## Magic.spellbook

Definition:
```luau
function Magic.spellbook(): string?
```
The spellbook you're on: `"standard"`, `"ancient"`, `"lunar"` or `"arceuus"`.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

print(Magic.spellbook())
```

## Magic.is_spellbook

Definition:
```luau
function Magic.is_spellbook(book: string): boolean
```
Whether you're on that spellbook.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

if Magic.is_spellbook("lunar") then
	print("on lunars")
end
```

## Magic.spells

Definition:
```luau
function Magic.spells(book: string?): { Spell }?
```
Every spell of a spellbook, the one you're on by default. The standard book includes the jewellery enchantments and that menu's "Back" button. They are read from the game files the first time and kept for the rest of the script.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

for _, spell in ipairs(Magic.spells("ancient") or {}) do
	print(spell.level, spell.name)
end
```

## Magic.spell

Definition:
```luau
function Magic.spell(spell: SpellRef, book: string?): Spell?
```
Looks a spell up by name in a spellbook, the one you're on by default. When it is on another spellbook the error says which.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

local alch = Magic.spell("High Level Alchemy")
print(alch and alch.level)
print(Magic.spell("Ice Barrage")) -- nil, Ice Barrage is on the ancient spellbook, not the standard one
```

## Magic.spell_count

Definition:
```luau
function Magic.spell_count(book: string?): number?
```
How many spells a spellbook has, the one you're on by default. Menu buttons like "Back" don't count.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

print(Magic.spell_count())
```

## Magic.is_open

Definition:
```luau
function Magic.is_open(): boolean
```
Whether the spellbook tab is open.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

print(Magic.is_open())
```

## Magic.open

Definition:
```luau
function Magic.open(timeout_ms: number?): boolean
```
Opens the spellbook tab.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

assert(Magic.open())
```

## Magic.widget

Definition:
```luau
function Magic.widget(spell: SpellRef): Widget?
```
The spell's button, whether the tab is open or not (it is hidden while the tab is closed).

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

local button = Magic.widget("Wind Strike")
print(button and button.sprite)
```

## Magic.can_cast

Definition:
```luau
function Magic.can_cast(spell: SpellRef): boolean
```
Whether you can cast the spell: you have the level, the runes and whatever unlocks it. This is the icon the game shows, so it works with the tab closed too.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

if Magic.can_cast("High Level Alchemy") then
	print("ready to alch")
end
```

## Magic.find

Definition:
```luau
function Magic.find(spell: SpellRef): Widget?
```
Puts the spell's button on screen and returns it. It opens the tab, closes the filters panel, and goes into or out of the jewellery enchantments menu when the spell is on the other side of it.

When spell filters hide the spell, it turns them off, one step at a time, stopping as soon as the spell shows:

1. The filter for the spell's group (combat, teleport or utility), plus the Magic level filter if your level is too low.
2. The runes and requirements filters if you can't cast the spell.
3. Spell filtering as a whole, as a last resort.

Other filters are left alone.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

local button = Magic.find("Lvl-1 Enchant")
print(button and button.x, button and button.y)
```

## Magic.contains

Definition:
```luau
function Magic.contains(spell: SpellRef): boolean
```
Whether the spell is on your spellbook and can be put on screen (see `Magic.find`, which can turn off spell filters that hide it). `false` when it is on another spellbook.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

print(Magic.contains("Teleport to House"))
```

## Magic.is_filtering

Definition:
```luau
function Magic.is_filtering(): boolean
```
Whether spell filtering is on. The filters only hide spells while it is.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

print(Magic.is_filtering())
```

## Magic.set_filtering

Definition:
```luau
function Magic.set_filtering(on: boolean): boolean
```
Turns spell filtering on or off from the tab button's right-click menu.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

Magic.set_filtering(false)
```

## Magic.is_filter_on

Definition:
```luau
function Magic.is_filter_on(filter: string): boolean
```
Whether a filter (`"combat"`, `"teleport"`, `"utility"`, `"level"`, `"runes"` or `"requirements"`) is set to hide its spells. It only takes effect while spell filtering is on.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

print(Magic.is_filter_on("combat"))
```

## Magic.is_filters_open

Definition:
```luau
function Magic.is_filters_open(): boolean
```
Whether the spell filters panel is open. The spells are hidden while it is.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

print(Magic.is_filters_open())
```

## Magic.open_filters

Definition:
```luau
function Magic.open_filters(): boolean
```
Opens the spell filters panel. Returns `false` when spell filtering is off, since the panel's button is only there while it's on.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

Magic.open_filters()
```

## Magic.close_filters

Definition:
```luau
function Magic.close_filters(): boolean
```
Closes the spell filters panel.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

Magic.close_filters()
```

## Magic.set_filter

Definition:
```luau
function Magic.set_filter(filter: string, hide: boolean): boolean
```
Sets a filter to hide its spells (`hide` true) or show them, by clicking its line in the filters panel. The panel is left open. Spell filtering has to be on.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

Magic.set_filter("teleport", false)
Magic.close_filters()
```

## Magic.info_box

Definition:
```luau
function Magic.info_box(): Widget?
```
The frame of the box the tab shows about the hovered spell (name, description, runes). `nil` when it isn't shown.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

local box = Magic.info_box()
if box then
	print("info box covers", box.x, box.y, box.width, box.height)
end
```

## Magic.is_info_open

Definition:
```luau
function Magic.is_info_open(): boolean
```
Whether the info box about a spell is shown.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

print(Magic.is_info_open())
```

## Magic.close_info

Definition:
```luau
function Magic.close_info(spell: SpellRef?): boolean
```
Closes the info box by moving the mouse just outside the spellbook, past its nearest edge. With a spell it moves onto that spell instead, which shows that spell's info.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

if Magic.is_info_open() then
	Magic.close_info()
end
```

## Magic.selected

Definition:
```luau
function Magic.selected(): SelectedWidget?
```
What is waiting for a target: a spell you clicked that needs something to be cast on, or anything else that works the same way. `nil` when nothing is.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

local selected = Magic.selected()
print(selected and selected.name)
```

## Magic.selected_spell

Definition:
```luau
function Magic.selected_spell(): Spell?
```
The spell waiting for a target, `nil` when no spell is.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

local spell = Magic.selected_spell()
print(spell and spell.name)
```

## Magic.has_selected

Definition:
```luau
function Magic.has_selected(): boolean
```
Whether something is waiting for a target.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

print(Magic.has_selected())
```

## Magic.is_selected

Definition:
```luau
function Magic.is_selected(spell: SpellRef): boolean
```
Whether that spell is the one waiting for a target.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

print(Magic.is_selected("High Level Alchemy"))
```

## Magic.deselect

Definition:
```luau
function Magic.deselect(): boolean
```
Cancels what is waiting for a target: clicks the selected spell when its button is on screen, otherwise picks "Cancel" from the right-click menu. `true` when nothing was selected.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

assert(Magic.deselect())
```

## Magic.hover

Definition:
```luau
function Magic.hover(spell: SpellRef): boolean
```
Moves the mouse onto the spell, opening the tab and the jewellery menu as needed.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

Magic.hover("High Level Alchemy")
```

## Magic.click

Definition:
```luau
function Magic.click(spell: SpellRef, button: Mouse.Button?): boolean
```
Clicks the spell's button (left by default) without checking what the click did.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

Magic.click("Camelot Teleport", "right")
```

## Magic.interact

Definition:
```luau
function Magic.interact(spell: SpellRef, option: string?): boolean
```
Picks an option on the spell's button, its left-click option by default ("Cast", or "View"/"Back" for the menu buttons). Other options, like a teleport's alternative destination, are picked from the right-click menu. Returns `false` and the reason when the game did something else.

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

Magic.interact("Camelot Teleport", "Seers'")
```

## Magic.was_cast

Definition:
```luau
function Magic.was_cast(spell: SpellRef): boolean
```
Whether the game did what casting the spell does: the spell is waiting for a target (spells cast on something), or nothing is and the last thing clicked was casting it (spells that go off right away, like teleports).

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")

Magic.click("Varrock Teleport")
print(Magic.was_cast("Varrock Teleport"))
```

## Magic.cast

Definition:
```luau
function Magic.cast(spell: SpellRef, option: string?): boolean
```
Casts the spell. A spell cast on something is left waiting for its target (click the target next, for example with `Interact.with`); one that goes off right away is cast. If the spell is already waiting for a target that counts as cast; if another one is, it is cancelled first. Returns `false` without clicking when you can't cast the spell (level, runes, unlocks).

Example:
```luau
local Magic = require("../main/interfaces/gametabs/magic")
local Inventory = require("../main/interfaces/gametabs/inventory")

if Magic.cast("High Level Alchemy") then
	print("now click the item to alch", Inventory.index_of("Yew longbow"))
end
```
