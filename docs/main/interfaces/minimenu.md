# Main.Interfaces.Minimenu

The small menu that shows what a click will do, both the line at the top of the screen when you hover something ("Talk-to Man") and the full list when you right-click.

```luau
local Minimenu = require("../main/interfaces/minimenu")
```

A menu line has an `option` ("Talk-to") and a `target` ("Man"). Functions that look for an option take an optional `target`: either a text that must appear in the line's target (not case sensitive), or a function that receives the line and returns `true` for the ones you want.

## Constants

Definition:
```luau
Minimenu.MARGIN = 40
Minimenu.CLICK_TIMEOUT = 600
Minimenu.SUBMENU_TIMEOUT = 600
```
`MARGIN` is how far (interface units, scaled by the client's UI scale) `Minimenu.close` keeps the mouse from the menu. `CLICK_TIMEOUT` is how long (milliseconds) to wait for the game to react to a click. `SUBMENU_TIMEOUT` is how long `Minimenu.open_submenu` waits for a submenu to open.

## Minimenu.entries

Definition:
```luau
function Minimenu.entries(): { MenuEntry }?
```
All lines of the menu, top line first. While the menu is open, these are exactly the rows it shows, in its order (entries the client hides aren't listed), so their positions match `Minimenu.row`. While it's closed, the top line is what a normal left click would do.

Example:
```luau
local Minimenu = require("../main/interfaces/minimenu")

for i, entry in ipairs(Minimenu.entries() or {}) do
	print(i, entry.option, entry.target)
end
```

## Minimenu.text

Definition:
```luau
function Minimenu.text(entry: MenuEntry): string
```
A line as readable text, like `"Talk-to Man"`.

Example:
```luau
local Minimenu = require("../main/interfaces/minimenu")

local entries = Minimenu.entries() or {}
if entries[1] then
	print(Minimenu.text(entries[1]))
end
```

## Minimenu.uptext

Definition:
```luau
function Minimenu.uptext(): string?
```
The text of the top line: what the game says will happen if you left click. Empty when nothing is under the mouse.

Example:
```luau
local Minimenu = require("../main/interfaces/minimenu")

print(Minimenu.uptext())
```

## Minimenu.matches

Definition:
```luau
function Minimenu.matches(entry: MenuEntry, option: string, target: Target?): boolean
```
Whether a line is the option (and target) you are looking for.

Example:
```luau
local Minimenu = require("../main/interfaces/minimenu")

for _, entry in ipairs(Minimenu.entries() or {}) do
	if Minimenu.matches(entry, "Walk here") then
		print("found it")
	end
end
```

## Minimenu.find

Definition:
```luau
function Minimenu.find(option: string, target: Target?): (number?, { MenuEntry }?)
```
Finds the position of an option in the menu. Returns the position, followed by all lines.

Example:
```luau
local Minimenu = require("../main/interfaces/minimenu")

local index = Minimenu.find("Walk here")
print(index)
```

## Minimenu.has

Definition:
```luau
function Minimenu.has(option: string, target: Target?): boolean
```
Whether the menu currently has that option.

Example:
```luau
local Minimenu = require("../main/interfaces/minimenu")

print("can walk here:", Minimenu.has("Walk here"))
```

## Minimenu.row

Definition:
```luau
function Minimenu.row(index: number, level: number?): Box?
```
Where to click on line `index` of the open right-click menu (or of its open submenu `level` levels deep: 1 is the submenu opened from the menu), from the client's own layout of it (`Host.menu_layout`), so it's right for long menus and menus pushed in from the client's edges. The box is kept near the mouse so the move stays short. Returns an error when the menu isn't open or the line is scrolled out of view.

Example:
```luau
local Minimenu = require("../main/interfaces/minimenu")

local box = Minimenu.row(2)
print(box and box.x1, box and box.y1)
```

## Minimenu.select

Definition:
```luau
function Minimenu.select(option: string, target: Target?): boolean
```
Opens the right-click menu where the mouse is and clicks the option you asked for. Returns `false` if the option isn't in the menu.

Example:
```luau
local Minimenu = require("../main/interfaces/minimenu")
local Mouse = require("../utils/input/mouse")

Mouse.move({ x = 300, y = 300 })
print(Minimenu.select("Walk here"))
```

## Minimenu.clicked

Definition:
```luau
function Minimenu.clicked(): MenuClick?
```
The line the game last acted on, with where the mouse was and how long ago. Returns `nil` without an error if this isn't available.

Example:
```luau
local Minimenu = require("../main/interfaces/minimenu")

local click = Minimenu.clicked()
print(click and Minimenu.text(click.entry))
```

## Minimenu.wait_click

Definition:
```luau
function Minimenu.wait_click(before: MenuClick?, timeout_ms: number?): MenuClick?
```
After you click, waits for the game to react and tells you which line it acted on. Pass the result of `Minimenu.clicked()` read just before the click, so an older click isn't mistaken for the new one.

Example:
```luau
local Minimenu = require("../main/interfaces/minimenu")
local Mouse = require("../utils/input/mouse")

local before = Minimenu.clicked()
Mouse.click({ x = 300, y = 300 })
local click = Minimenu.wait_click(before)
print(if click then Minimenu.text(click.entry) else "unavailable")
```

## Minimenu.is_open

Definition:
```luau
function Minimenu.is_open(): boolean
```
Whether the choose-option menu (the right-click menu) is open. Read from the client's menu object, so it stays correct when the menu is opened or closed by something other than this module. Returns an error when the agent doesn't know where the client keeps the flag.

Example:
```luau
local Minimenu = require("../main/interfaces/minimenu")

print("menu open:", Minimenu.is_open())
```

## Minimenu.open

Definition:
```luau
function Minimenu.open(timeout_ms: number?): boolean
```
Right-clicks where the mouse is and waits up to `timeout_ms` (default 600) for the menu to open. Does nothing when it's already open, so it's safe to call twice. Returns `true` once it's open.

Example:
```luau
local Minimenu = require("../main/interfaces/minimenu")
local Mouse = require("../utils/input/mouse")

Mouse.move({ x = 300, y = 300 })
print(Minimenu.open())
```

## Minimenu.bounds

Definition:
```luau
function Minimenu.bounds(margin: number?, level: number?): (Geometry.Box?, Connection?)
```
The area the open menu (or its open submenu `level` levels deep) covers in client pixels, grown by `margin` (default 0, interface units). It's the client's own layout of the menu (`Host.menu_layout`), so it's exact for any number of lines, for menus pushed in from the client's edges and for menus too tall for the client. Once the menu is open its bounds don't change, wherever the mouse goes. Returns an error when the menu isn't open. `Minimenu.close` uses it with `Minimenu.MARGIN` (40). `tests/minimenu_bounds.luau` draws it.

Example:
```luau
local Minimenu = require("../main/interfaces/minimenu")

local box = Minimenu.bounds()
print(box and box.x1, box and box.y1, box and box.x2, box and box.y2)
```

## Minimenu.hover_bounds

Definition:
```luau
function Minimenu.hover_bounds(level: number?): Geometry.Box?
```
The area, in client pixels, the mouse can move in without the client closing the open menu (or around its open submenu `level` levels deep; the menu stays open while the mouse is in the area of any open level): the menu grown by the client's own margin (`Host.menu_layout().margin`, 10 interface units, read from the client), with the client's rounding of the mouse to interface units taken into account. The client checks it when the mouse moves. Returns an error when the menu isn't open. `tests/minimenu_bounds.luau` draws it in yellow.

Example:
```luau
local Minimenu = require("../main/interfaces/minimenu")

local area = Minimenu.hover_bounds()
print(area and area.x1, area and area.x2)
```

## Minimenu.close

Definition:
```luau
function Minimenu.close(timeout_ms: number?): boolean
```
Closes the menu by moving the mouse to a random spot in the client that is outside the menu and every open submenu, grown by `Minimenu.MARGIN`. Escape doesn't close it. Waits up to `timeout_ms` (default 600). Returns `true` once it's closed, and does nothing when it's already closed.

Example:
```luau
local Minimenu = require("../main/interfaces/minimenu")

print(Minimenu.close())
```

## Submenus

A line with an arrow (`entry.submenu` is `true`) opens a submenu when the mouse rests on it, like "Reminisce" on Kharedst's memoirs. The functions below work on submenus. Levels count from the menu: 1 is the submenu opened from the menu, 2 one opened from that, and so on.

## Minimenu.submenu

Definition:
```luau
function Minimenu.submenu(level: number?): MenuSubmenu?
```
The open submenu `level` levels deep (the deepest open one by default), as the client lays it out: its `entries`, the `row` of the menu above that opened it and its layout (see `Host.menu_layout`). Returns an error when none is open.

Example:
```luau
local Minimenu = require("../main/interfaces/minimenu")

local sub = Minimenu.submenu()
if sub then
	print("opened from line", sub.row, "with", #sub.entries, "lines")
end
```

## Minimenu.has_submenu

Definition:
```luau
function Minimenu.has_submenu(option: string?, target: Target?): boolean
```
Whether the open menu has a line that opens a submenu (one matching `option` and `target` when given). `false` while the menu is closed: the client only marks the lines of an open menu.

Example:
```luau
local Minimenu = require("../main/interfaces/minimenu")

print(Minimenu.has_submenu("Reminisce"))
```

## Minimenu.is_submenu_open

Definition:
```luau
function Minimenu.is_submenu_open(level: number?): boolean
```
Whether a submenu `level` levels deep (default 1) is open.

Example:
```luau
local Minimenu = require("../main/interfaces/minimenu")

print(Minimenu.is_submenu_open())
```

## Minimenu.open_submenu

Definition:
```luau
function Minimenu.open_submenu(option: string?, target: Target?, timeout_ms: number?): boolean
```
Opens the submenu of the menu's first line that has one (or the first matching `option` and `target`): right-clicks where the mouse is when the menu is closed, moves onto the line and waits up to `timeout_ms` (default `SUBMENU_TIMEOUT`) for its submenu to open. Does nothing when that submenu is already open. Returns `false` with a reason when no line opens a submenu.

Example:
```luau
local Inventory = require("../main/interfaces/gametabs/inventory")
local Minimenu = require("../main/interfaces/minimenu")

Inventory.hover_slot(0)
print(Minimenu.open_submenu("Reminisce"))
```

## Minimenu.submenu_entries

Definition:
```luau
function Minimenu.submenu_entries(option: string?, target: Target?): { MenuEntry }?
```
The lines of the open submenu, top to bottom. When none is open, opens one first with `Minimenu.open_submenu(option, target)`.

Example:
```luau
local Minimenu = require("../main/interfaces/minimenu")

for i, entry in ipairs(Minimenu.submenu_entries("Reminisce") or {}) do
	print(i, entry.option)
end
```

## Minimenu.find_submenu

Definition:
```luau
function Minimenu.find_submenu(option: string, target: Target?): (number?, { MenuEntry }?)
```
The position of an option in the open submenu (the deepest one), followed by all its lines.

Example:
```luau
local Minimenu = require("../main/interfaces/minimenu")

print(Minimenu.find_submenu("History and Hearsay"))
```

## Minimenu.hover_submenu

Definition:
```luau
function Minimenu.hover_submenu(option: string, target: Target?): boolean
```
Moves the mouse onto the line of the open submenu matching `option` and `target`. It first moves sideways from the line that opened the submenu into it, then to the line. That way the mouse doesn't rest on another line of the menu, which would open that line's submenu instead. The moves never use the mouse's deliberate misses, which could leave the menu and close it. Returns `false` with a reason when no submenu is open or the option isn't in it.

Example:
```luau
local Minimenu = require("../main/interfaces/minimenu")

if Minimenu.open_submenu("Reminisce") then
	print(Minimenu.hover_submenu("History and Hearsay"))
end
```

## Minimenu.select_submenu

Definition:
```luau
function Minimenu.select_submenu(option: string, target: Target?, parent: string?): boolean
```
Clicks `option` (and `target`) in the submenu opened from the menu's line `parent` (any line with a submenu when `nil`). Opens the menu and the submenu first when needed: `open_submenu`, then `hover_submenu`, then a click.

Example:
```luau
local Inventory = require("../main/interfaces/gametabs/inventory")
local Minimenu = require("../main/interfaces/minimenu")

Inventory.hover_slot(0)
print(Minimenu.select_submenu("A Dark Disposition", nil, "Reminisce"))
```

## Minimenu.overlaps

Definition:
```luau
function Minimenu.overlaps(area: Geometry.Box): boolean
```
True when the minimenu is open and it, or one of its open submenus, covers `area` or is close enough to it that the menu stays open while the mouse is over it. Used by `Clickbox.hover` to close a menu that sits over the target.

Example:
```luau
local Minimenu = require("../main/interfaces/minimenu")
local Geometry = require("../utils/math/geometry")

print(Minimenu.overlaps(Geometry.Box.new(300, 200, 340, 240)))
```
