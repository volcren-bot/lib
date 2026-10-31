# Main.Interfaces.Mainscreen.Bankmain

The bank. It has every function of [Inv](../inv.md) already set up for the bank's contents, and enters the account's bank PIN if the keypad is in the way.

```luau
local Bankmain = require("../main/interfaces/mainscreen/bankmain")
```

## Constants

Definition:
```luau
Bankmain.CONTAINER = 95
Bankmain.GROUP = 12
```
The bank's container id and its interface group.

## Functions from Inv

`slots`, `items`, `indices_of`, `index_of`, `find`, `contains`, `contains_any`, `contains_all`, `count`, `count_ex` and `wait_count` work as described in [Inv](../inv.md), on the bank's contents.

## Bankmain.is_open

Definition:
```luau
function Bankmain.is_open(): boolean
```
Whether the bank window is open. If the keypad is showing, the injector enters the account's PIN first (see [BankpinKeypad.enter](bankpin_keypad.md)); `false` if that fails. An account with no saved PIN leaves the keypad alone.

Example:
```luau
local Bankmain = require("../main/interfaces/mainscreen/bankmain")

if Bankmain.is_open() then
	print("coins in the bank:", Bankmain.count_ex("Coins"))
end
```

## Bankmain.close_button

Definition:
```luau
function Bankmain.close_button(): Widget?
```
The bank's close button, or `nil` when the bank is closed or it isn't where the frame keeps it.

Example:
```luau
local Bankmain = require("../main/interfaces/mainscreen/bankmain")

print(Bankmain.close_button())
```

## Bankmain.wait_open

Definition:
```luau
function Bankmain.wait_open(timeout_ms: number?): boolean
```
Polls `is_open` every 50 ms for up to `timeout_ms` (3 seconds by default). A PIN keypad in the way is handled by `is_open`.

## Bankmain.nearest

Definition:
```luau
export type Source = { loc: Loc?, npc: Npc? }
Bankmain.PLAN_CANDIDATES = 6
function Bankmain.nearest(): Source?
```
The bank that is the fewest steps to walk to, as a `Source` holding either a `loc` or an `npc`. It looks at every loaded "Bank booth", "Bank chest" and "Banker", plans a walk (`Walker.plan`, through doors, stairs and ladders, to within `Clickbox.APPROACH_NEAR` tiles) to the `PLAN_CANDIDATES` closest by straight distance, and takes the shortest plan; a plan that stops short counts the straight distance left. This costs one plan per candidate. When none can be planned it returns the closest by straight distance. `nil` when none is loaded or the position is unknown.

## Bankmain.hover

Definition:
```luau
function Bankmain.hover(source: Source?, walk: boolean?): boolean
```
Hovers the closest bank (or `source`). Walks closer first unless `walk` is `false`.

## Bankmain.open

Definition:
```luau
function Bankmain.open(source: Source?, walk: boolean?): boolean
```
Opens the closest bank (or `source`) with "Bank" (or "Use" on objects) and waits for it. Walks closer first unless `walk` is `false`. Another interface in the way is closed with Escape first. If the keypad shows up, `is_open` has the injector enter the PIN. `true` when the bank ends up open.

Example:
```luau
local Bankmain = require("../main/interfaces/mainscreen/bankmain")

if Bankmain.open() then
	print("coins in the bank:", Bankmain.count_ex("Coins"))
end
```

## Buttons

```luau
export type Button = "ARRANGEMENT" | "NOTES" | "PLACEHOLDERS" | "SEARCH" | "DEPOSIT_CONTAINERS" | "DEPOSIT_INVENTORY" | "DEPOSIT_WORN" | "POTION_STORAGE" | "TUTORIAL"
export type Quantity = "ONE" | "FIVE" | "TEN" | "CUSTOM" | "ALL"
export type Arrangement = "SWAP" | "INSERT"
```

### Bankmain.button / Bankmain.click_button

Definition:
```luau
function Bankmain.button(button: Button): Widget?
function Bankmain.click_button(button: Button): boolean
```
The widget of a button, `nil` when the bank is closed or the button isn't shown (the deposit containers and potion storage buttons depend on the account). `click_button` clicks it; `false` when the bank is closed or the button isn't shown.

### Settings: arrangement, notes, placeholders

Definition:
```luau
function Bankmain.arrangement(): Arrangement?
function Bankmain.set_arrangement(mode: Arrangement, timeout_ms: number?): boolean
function Bankmain.notes(): boolean?
function Bankmain.set_notes(on: boolean, timeout_ms: number?): boolean
function Bankmain.placeholders(): boolean?
function Bankmain.set_placeholders(on: boolean, timeout_ms: number?): boolean
```
Read the settings the buttons toggle from the client (not from how the buttons look: the arrangement button looks the same in both states). `set_*` clicks the button only when the setting differs and waits for it to change (2 seconds by default); `true` when it ends up as asked. `notes` is whether items are withdrawn as notes; `placeholders` is "Always set placeholders".

### Quantity

Definition:
```luau
function Bankmain.quantity(): Quantity?
function Bankmain.custom_quantity(): number?
function Bankmain.quantity_of(amount: number): Quantity
function Bankmain.select_quantity(quantity: Quantity, timeout_ms: number?): boolean
function Bankmain.set_custom_quantity(amount: number): boolean
function Bankmain.set_quantity(amount: number): boolean
```
`quantity` is the selected default quantity and `custom_quantity` the amount of the X button. `quantity_of` is the button that gives an amount: 1, 5 and 10 have their own, 0 or less is `"ALL"` and anything else is `"CUSTOM"`. `select_quantity` clicks a quantity button and waits for it to be the selected one. `set_custom_quantity` right clicks X, picks "Set custom quantity" and types the amount (it selects X too). `set_quantity` does what is needed for an amount: select 1, 5, 10 or all, or set X first.

Example:
```luau
local Bankmain = require("../main/interfaces/mainscreen/bankmain")

Bankmain.set_notes(false)
Bankmain.set_quantity(10)
```

### Deposit buttons

Definition:
```luau
function Bankmain.deposit_inventory(): boolean
function Bankmain.deposit_worn(): boolean
function Bankmain.deposit_containers(): boolean
```
Click "Deposit inventory", "Deposit worn items" and "Empty containers" (the loot bag, herb sack and the like; only shown when the account has something to empty). They return whether the click was made; use the inventory or equipment to see that it worked.

### Search

Definition:
```luau
function Bankmain.is_search_open(): boolean
function Bankmain.open_search(timeout_ms: number?): boolean
function Bankmain.search(text: string): boolean
```
`open_search` clicks the search button and waits for the prompt in the chatbox. `search` opens it, types `text` and presses Enter. Pressing Escape while the prompt is open closes the whole bank, there is no function that only closes the prompt. Clicking the search button while a search is applied clears it (`click_button("SEARCH")`); there is no function that tells whether one is applied, so there is no `clear_search` yet.

### Potion storage

Definition:
```luau
function Bankmain.has_potion_storage(): boolean
function Bankmain.potion_storage_is_open(): boolean
function Bankmain.open_potion_storage(timeout_ms: number?): boolean
function Bankmain.close_potion_storage(timeout_ms: number?): boolean
function Bankmain.toggle_potion_storage(timeout_ms: number?): boolean
```
The potion storage is a view in the bank window itself (its title changes to "Potion storage"), and the same button opens it and goes back. `open_` and `close_` do nothing if it is already in that state.

### Tabs: Bankmain.tab_sizes, count_tabs, tab_of_slot, find_tab

Definition:
```luau
function Bankmain.tab_sizes(): { number }?
function Bankmain.count_tabs(): number?
function Bankmain.tab_of_slot(slot: number): number?
function Bankmain.find_tab(item: Item | { Item }): (number?, number?)
```
The container keeps the items of each tab together: tab 1 first, then tabs 2 to 9, then the items that aren't in a tab (the main tab, 0). `tab_sizes` reads how many items each tab holds (the client keeps those numbers), `count_tabs` is how many tabs have items, and `tab_of_slot` adds the sizes up to say which tab a slot is in (0 when it isn't in one). `find_tab` gives the tab and the slot of an item, read from the bank's contents: no searching, no opening tabs. `nil` when the item isn't in the bank. An item in several slots gives the first slot's tab; use `indices_of` and `tab_of_slot` to see all of them. `open_tab` opens a tab.

### Slots: shown, scroll and show

Definition:
```luau
function Bankmain.is_slot_shown(slot: number): boolean
function Bankmain.scroll_distance(slot: number): number?
function Bankmain.scroll_to(slot: number, timeout_ms: number?): boolean
function Bankmain.show_slot(slot: number): boolean
```
The grid holds one widget per slot, and only the open tab's are shown; their positions are on screen, so how far a slot is from the visible part is read, not guessed. `is_slot_shown` says whether at least half of the slot is inside the grid. `scroll_distance` is how many mouse wheel notches (about 79 units each) it takes to bring the slot fully into the grid: positive is down, negative up, `0` when it is there, `nil` when the slot isn't in the open tab. `scroll_to` turns the wheel until it is: a long way is first scrolled to a random place in the grid, in bursts of 2 to 6 notches with short pauses, and what is left is fixed up. `show_slot` opens the slot's own tab (so there is the least scrolling) and then scrolls to it.

`hover_slot`, `click_slot`, `interact_slot`, `box`, `boxes` and `slot_at` work on the slots that are shown, as described in [Inv](../inv.md). `interact_slot(slot, "Withdraw-5")` uses the item's menu.

Example:
```luau
local Bankmain = require("../main/interfaces/mainscreen/bankmain")

local tab, slot = Bankmain.find_tab("Willow logs")
if slot and Bankmain.show_slot(slot) then
	Bankmain.click_slot(slot)
end
```

### Bankmain.withdraw

Definition:
```luau
Bankmain.ALL_BUT_ONE = -1
function Bankmain.withdraw(item: Item | { Item }, amount: number?, noted: boolean?, use_quantity_buttons: boolean?): boolean
```
Takes an item out of the bank. `amount` is how many (1 by default; 0 or less is all; `Bankmain.ALL_BUT_ONE` is all but one); asking for the whole stack or more takes all of it. `noted` withdraws as notes (`true`) or items (`false`); `nil` leaves the setting as it is. Placeholders are skipped. By default it selects the quantity button that gives the amount (`set_quantity`, so X is set first for other amounts), shows the item and clicks it; with `use_quantity_buttons` false it takes the option from the item's menu instead (`Withdraw-1/5/10/All/All-but-1`, the amount X holds, or `Withdraw-X` and types the amount). Returns `true` once the bank holds less of the item, `false` if the bank is closed, has none of it, or nothing was taken.

It leaves the quantity, X and notes settings as it set them. Save them first (`quantity`, `custom_quantity`, `notes`) if the script needs them back.

Example:
```luau
local Bankmain = require("../main/interfaces/mainscreen/bankmain")

Bankmain.open()
Bankmain.withdraw("Willow logs", 10, false)
Bankmain.withdraw("Charcoal", 0, true, false) -- all of it, as notes, through the menu
```

Not covered: the incinerator button and the Jagex account advert (neither is shown in the bank this was written against), and the settings button (the client's top bar has no such button).

## Bankmain.close

Definition:
```luau
function Bankmain.close(key_probability: number?, timeout_ms: number?): boolean
```
Closes the bank, like `DepositBox.close`: Escape with the chance `key_probability` (by default the `Biometrics.ESCAPE` probability), then the close button, up to 3 times. See `Toplevel.close`.

Example:
```luau
local Bankmain = require("../main/interfaces/mainscreen/bankmain")

Bankmain.close()
```

## Bankmain.tab

Definition:
```luau
function Bankmain.tab(): number?
```
The open bank tab: 0 for the main tab, which shows every item, 1 to 9 for the others. `nil` when it can't be read.

Example:
```luau
local Bankmain = require("../main/interfaces/mainscreen/bankmain")

print("tab:", Bankmain.tab())
```

## Bankmain.tab_button

Definition:
```luau
function Bankmain.tab_button(tab: number): Widget?
```
The button of a bank tab in the tab bar, or `nil` when the bank is closed.

Example:
```luau
local Bankmain = require("../main/interfaces/mainscreen/bankmain")

print(Bankmain.tab_button(0))
```

## Bankmain.open_tab

Definition:
```luau
function Bankmain.open_tab(tab: number, timeout_ms: number?): boolean
```
Opens a bank tab and waits for it to be the open one (2 seconds by default). The item grid only scrolls when the open tab has more than a screen of items, and the grid shows the tab's own items, so open the main tab (0) before looking for an item by its slot in the bank. Returns `true` when the tab is open in the end.

Example:
```luau
local Bankmain = require("../main/interfaces/mainscreen/bankmain")

assert(Bankmain.open_tab(0), "couldn't open the main tab")
print(Bankmain.index_of("Anglerfish"))
```
