# Main.OccultAltar

The Altar of the Occult in a player's house, which swaps the spellbook through a menu option per book or the "Venerate" dialogue. A swap is confirmed by `Magic.is_spellbook`, never assumed from a click.

```luau
local OccultAltar = require("@lib/main/occult_altar")
```

## Constants

Definition:
```luau
OccultAltar.NAME = "Altar of the Occult"
OccultAltar.OPTION = "Venerate"
OccultAltar.DIALOGUE_TIMEOUT_MS = 8000
OccultAltar.SWAP_TIMEOUT_MS = 8000
OccultAltar.POLL_MS = 100
OccultAltar.HOVER_MS = 350
```
Object name, dialogue option, wait for the dialogue (walk included), wait for the book to change, poll interval, and menu wait after hovering.

## OccultAltar.Book

Definition:
```luau
export type Book = "standard" | "ancient" | "lunar" | "arceuus"
```
Spellbook names as `Magic.spellbook` reports them. `OccultAltar.Book` is a frozen table of them (`Standard`, `Ancient`, `Lunar`, `Arceuus`).

## OccultAltar.nearest

Definition:
```luau
function OccultAltar.nearest(): Loc?
```
The nearest loaded altar, nil when there is none.

## OccultAltar.books

Definition:
```luau
function OccultAltar.books(altar: Loc?): { Book }?
```
Hovers the altar and returns the books its menu offers, which never includes the one in use. Nil when there is no altar or it can't be hovered.

## OccultAltar.is_dialogue_open

Definition:
```luau
function OccultAltar.is_dialogue_open(): boolean
```
True when the chat options are open and every one is a book.

## OccultAltar.venerate

Definition:
```luau
function OccultAltar.venerate(altar: Loc?): (boolean, string?)
```
Opens the dialogue with "Venerate", walking if needed, and waits for it. True at once when already open; on failure the second result says why.

## OccultAltar.choose

Definition:
```luau
function OccultAltar.choose(book: Book, key_probability: number?): (boolean, string?)
```
Picks `book` in the open dialogue by key or click (`key_probability`, nil uses the biometric), retries by click if the key doesn't take, and waits for the book to change. On failure the second result says why.

## OccultAltar.swap_by_menu

Definition:
```luau
function OccultAltar.swap_by_menu(book: Book, altar: Loc?): (boolean, string?)
```
Swaps with the altar's menu option for `book`, walking if needed, and waits for the change. On failure the second result says why.

## OccultAltar.swap

Definition:
```luau
function OccultAltar.swap(book: Book, via: ("menu" | "dialogue")?, altar: Loc?): (boolean, string?)
```
Swaps to `book`; true at once when it is already in use. An open dialogue is answered, otherwise menu or dialogue is chosen by `Biometrics.CHOOSEOPTION`; `via` forces one. Failures are logged and the second result says why.

Example:
```luau
local ok, why = OccultAltar.swap(OccultAltar.Book.Lunar)
assert(ok, why)
```
