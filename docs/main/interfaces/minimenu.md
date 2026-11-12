# Main.Interfaces.Minimenu

The menu that shows what a click does: the up-text line when hovering ("Talk-to Man") and the full right-click list.

```luau
local Minimenu = require("@lib/main/interfaces/minimenu")
```

A line has an `option` ("Talk-to") and a `target` ("Man"). A `Target` argument is either text that must appear in the line's target (case-insensitive) or a function `(MenuEntry) -> boolean`. Submenu `level` counts from the menu: 0 is the menu, 1 the submenu opened from it, and so on.

## Constants

Definition:
```luau
Minimenu.MARGIN = 40
Minimenu.SWAPS_TTL_MS = 1000
Minimenu.CLICK_TIMEOUT = 600
Minimenu.SUBMENU_TIMEOUT = 600
```
- `MARGIN`: interface units `Minimenu.close` keeps the mouse away from the menu.
- `SWAPS_TTL_MS`: how long `Minimenu.swaps` caches the entry swaps.
- `CLICK_TIMEOUT`: default ms `Minimenu.wait_click` waits.
- `SUBMENU_TIMEOUT`: default ms `Minimenu.open_submenu` waits.

## Minimenu.entries

Definition:
```luau
function Minimenu.entries(): { MenuEntry }?
```
All menu lines, top first. While open, exactly the rows shown, so indices match `Minimenu.row`; while closed, line 1 is the default left click.

Example:
```luau
for i, entry in ipairs(Minimenu.entries() or {}) do
	print(i, entry.option, entry.target)
end
```

## Minimenu.text

Definition:
```luau
function Minimenu.text(entry: MenuEntry): string
```
A line as text, like `"Talk-to Man"`.

Example:
```luau
local entries = Minimenu.entries() or {}
print(entries[1] and Minimenu.text(entries[1]))
```

## Minimenu.uptext

Definition:
```luau
function Minimenu.uptext(): string?
```
Text of what a left click does, with the account's entry swaps applied (the game's own up-text ignores them). Empty when nothing is under the mouse.

Example:
```luau
print(Minimenu.uptext())
```

## Minimenu.swaps

Definition:
```luau
function Minimenu.swaps(): { Host.EntrySwap }
```
The account's plain entry swaps from `Host.entry_swaps` (alternate-key swaps are not applied), cached for `SWAPS_TTL_MS`. Empty when they can't be read.

Example:
```luau
print(#Minimenu.swaps())
```

## Minimenu.reload_swaps

Definition:
```luau
function Minimenu.reload_swaps()
```
Expires the swap cache so the next `Minimenu.swaps` reads them again.

Example:
```luau
Minimenu.reload_swaps()
```

## Minimenu.left_click_index

Definition:
```luau
function Minimenu.left_click_index(entries: { MenuEntry }?): number?
```
Index of the line a left click runs: for the top line's target (a `(level-N)` suffix ignored), the first swapped option the menu offers, else 1. Nil when `entries` is nil or empty.

Example:
```luau
print(Minimenu.left_click_index(Minimenu.entries()))
```

## Minimenu.left_click

Definition:
```luau
function Minimenu.left_click(): MenuEntry?
```
The line a left click runs now, via `left_click_index`. `Interact.with` uses it so a swapped option is left-clicked instead of picked from the menu.

Example:
```luau
local entry = Minimenu.left_click()
print(entry and Minimenu.text(entry))
```

## Minimenu.matches

Definition:
```luau
function Minimenu.matches(entry: MenuEntry, option: string, target: Target?): boolean
```
Whether a line has `option` and matches `target`.

Example:
```luau
local entries = Minimenu.entries() or {}
print(entries[1] and Minimenu.matches(entries[1], "Walk here"))
```

## Minimenu.find

Definition:
```luau
function Minimenu.find(option: string, target: Target?): (number?, { MenuEntry }?)
```
Index of the first matching line (nil when absent) and all lines (nil only when the menu can't be read). Nil index with lines means "not there yet".

Example:
```luau
print(Minimenu.find("Walk here"))
```

## Minimenu.has

Definition:
```luau
function Minimenu.has(option: string, target: Target?): boolean
```
Whether the menu currently offers the option.

Example:
```luau
print(Minimenu.has("Walk here"))
```

## Minimenu.row

Definition:
```luau
function Minimenu.row(index: number, level: number?): Geometry.Box?
```
Click box for line `index` of the open menu or its submenu at `level`, from the client's layout (`Host.menu_layout`), kept near the mouse. Nil when the menu isn't open or the line is scrolled out of view.

Example:
```luau
local box = Minimenu.row(2)
print(box and box.x1, box and box.y1)
```

## Minimenu.select

Definition:
```luau
function Minimenu.select(option: string, target: Target?): boolean
```
Right-clicks at the mouse, waits up to 1.5 s for the menu and clicks the option. `false` without right-clicking when the option isn't offered; if it vanished after opening, clicks the last line (Cancel) and returns `false`.

Example:
```luau
local Mouse = require("@lib/utils/input/mouse")

Mouse.move({ x = 300, y = 300 })
print(Minimenu.select("Walk here"))
```

## Minimenu.clicked

Definition:
```luau
function Minimenu.clicked(): MenuClick?
```
The line the game last acted on, with the mouse position and its age. Nil when unavailable.

Example:
```luau
local click = Minimenu.clicked()
print(click and Minimenu.text(click.entry))
```

## Minimenu.wait_click

Definition:
```luau
function Minimenu.wait_click(before: MenuClick?, timeout_ms: number?): MenuClick?
```
Waits up to `timeout_ms` (default `CLICK_TIMEOUT`) for a click newer than `before` (read with `Minimenu.clicked()` just before clicking). Nil on timeout or when unavailable.

Example:
```luau
local Mouse = require("@lib/utils/input/mouse")

local before = Minimenu.clicked()
Mouse.click({ x = 300, y = 300 })
local click = Minimenu.wait_click(before)
print(click and Minimenu.text(click.entry))
```

## Minimenu.is_open

Definition:
```luau
function Minimenu.is_open(): boolean
```
Whether the right-click menu is open, read from the client's menu object. Errors when the agent lacks the offset.

Example:
```luau
print(Minimenu.is_open())
```

## Minimenu.open

Definition:
```luau
function Minimenu.open(timeout_ms: number?): boolean
```
Right-clicks at the mouse and waits up to `timeout_ms` (default 600) for the menu. Returns `true` at once when already open.

Example:
```luau
print(Minimenu.open())
```

## Minimenu.bounds

Definition:
```luau
function Minimenu.bounds(margin: number?, level: number?): (Geometry.Box?, Host.Connection?)
```
Client-pixel box of the open menu (or submenu at `level`) from the client's layout, grown by `margin` interface units (default 0), plus the connection. Fixed while open. Nil when closed.

Example:
```luau
local box = Minimenu.bounds()
print(box and box.x1, box and box.y2)
```

## Minimenu.hover_bounds

Definition:
```luau
function Minimenu.hover_bounds(level: number?): Geometry.Box?
```
Client-pixel area the mouse can stay in without the client closing the menu (or submenu at `level`): the layout grown by the client's own margin plus rounding. Nil when closed.

Example:
```luau
local area = Minimenu.hover_bounds()
print(area and area.x1, area and area.x2)
```

## Minimenu.overlaps

Definition:
```luau
function Minimenu.overlaps(area: Geometry.Box): boolean
```
True when the menu is open and the hover area of it or any open submenu touches `area`. `Clickbox.hover` uses it to close a menu covering its target.

Example:
```luau
local Geometry = require("@lib/utils/math/geometry")

print(Minimenu.overlaps(Geometry.Box.new(300, 200, 340, 240)))
```

## Minimenu.close

Definition:
```luau
function Minimenu.close(timeout_ms: number?): boolean
```
Closes the menu by moving the mouse to a random client spot outside every open level grown by `MARGIN` (Escape doesn't close it), then waits up to `timeout_ms` (default 600). `true` when closed.

Example:
```luau
print(Minimenu.close())
```

## Submenus

A line with `entry.submenu == true` opens a submenu when hovered.

## Minimenu.submenu

Definition:
```luau
function Minimenu.submenu(level: number?): Host.MenuSubmenu?
```
The open submenu at `level` (deepest by default): its `entries`, the parent `row` and its layout. Nil when none is open.

Example:
```luau
local sub = Minimenu.submenu()
print(sub and sub.row, sub and #sub.entries)
```

## Minimenu.has_submenu

Definition:
```luau
function Minimenu.has_submenu(option: string?, target: Target?): boolean
```
Whether the open menu has a line (matching `option`/`target` when given) that opens a submenu. Always `false` while closed.

Example:
```luau
print(Minimenu.has_submenu("Reminisce"))
```

## Minimenu.is_submenu_open

Definition:
```luau
function Minimenu.is_submenu_open(level: number?): boolean
```
Whether a submenu at `level` (default 1) is open.

Example:
```luau
print(Minimenu.is_submenu_open())
```

## Minimenu.open_submenu

Definition:
```luau
function Minimenu.open_submenu(option: string?, target: Target?, timeout_ms: number?): boolean
```
Opens the menu if needed, hovers the first submenu line (matching `option`/`target`) and waits up to `timeout_ms` (default `SUBMENU_TIMEOUT`). No-op when already open; `false` when no line has a submenu.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

Inventory.hover_slot(0)
print(Minimenu.open_submenu("Reminisce"))
```

## Minimenu.submenu_entries

Definition:
```luau
function Minimenu.submenu_entries(option: string?, target: Target?): { MenuEntry }?
```
Lines of the open submenu, opening one with `open_submenu(option, target)` first when none is open.

Example:
```luau
for i, entry in ipairs(Minimenu.submenu_entries("Reminisce") or {}) do
	print(i, entry.option)
end
```

## Minimenu.find_submenu

Definition:
```luau
function Minimenu.find_submenu(option: string, target: Target?): (number?, { MenuEntry }?)
```
Like `Minimenu.find` for the deepest open submenu; lines are nil when none is open.

Example:
```luau
print(Minimenu.find_submenu("History and Hearsay"))
```

## Minimenu.hover_submenu

Definition:
```luau
function Minimenu.hover_submenu(option: string, target: Target?): boolean
```
Moves sideways from the parent line into the submenu, then onto the matching line, so no other line's submenu opens; never uses deliberate mouse misses. `false` when no submenu is open or the option is absent.

Example:
```luau
if Minimenu.open_submenu("Reminisce") then
	print(Minimenu.hover_submenu("History and Hearsay"))
end
```

## Minimenu.select_submenu

Definition:
```luau
function Minimenu.select_submenu(option: string, target: Target?, parent: string?): boolean
```
`open_submenu(parent)`, `hover_submenu(option, target)`, then a click. `parent` nil means any submenu line.

Example:
```luau
local Inventory = require("@lib/main/interfaces/gametabs/inventory")

Inventory.hover_slot(0)
print(Minimenu.select_submenu("A Dark Disposition", nil, "Reminisce"))
```
