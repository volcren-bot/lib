# Main.OccultAltar

The Altar of the Occult in a player's house, which swaps the spellbook. It offers each other book as a menu option, and "Venerate" (its left click) opens a dialogue listing them.

```luau
local OccultAltar = require("@lib/main/occult_altar")
```

A swap is confirmed by the game's spellbook (`Magic.spellbook`), never assumed from a click. The altar's "Remove" option takes it out of the house; nothing here can click it. Only an account with every book unlocked has been seen, so a book you can't use is only known to be missing from the options if the game leaves it out.

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
The altar's name, the option that opens the dialogue, and the waits: for the dialogue (the walk is part of it), for the book to change, between looks, and after hovering the altar for its menu.

## OccultAltar.Book

Definition:
```luau
export type Book = "standard" | "ancient" | "lunar" | "arceuus"
```
Every spellbook, as `Magic.spellbook` names it. `OccultAltar.Book` is a frozen table of them (`Standard`, `Ancient`, `Lunar`, `Arceuus`).

## OccultAltar.nearest

Definition:
```luau
function OccultAltar.nearest(): Loc?
```
The nearest altar loaded, nil when there is none.

## OccultAltar.books

Definition:
```luau
function OccultAltar.books(altar: Loc?): { Book }?
```
The books the altar's menu offers now, found by hovering it, so never the one in use. Nil when there is no altar to hover.

## OccultAltar.is_dialogue_open

Definition:
```luau
function OccultAltar.is_dialogue_open(): boolean
```
Whether the altar's dialogue is open: a list of options that are all books.

## OccultAltar.venerate

Definition:
```luau
function OccultAltar.venerate(altar: Loc?): (boolean, string?)
```
Opens the dialogue with "Venerate", walking to the altar if needed, and waits for it. True also when it was open already. When it didn't work the second result says why.

## OccultAltar.choose

Definition:
```luau
function OccultAltar.choose(book: Book, key_probability: number?): (boolean, string?)
```
Picks `book` in the open dialogue, by key or click (`key_probability`; nil is the biometric), by click if the key doesn't take, and waits for the book to change. When it didn't work the second result says why.

## OccultAltar.swap_by_menu

Definition:
```luau
function OccultAltar.swap_by_menu(book: Book, altar: Loc?): (boolean, string?)
```
Swaps to `book` with the altar's menu option, walking to it if needed, and waits for the book to change. When it didn't work the second result says why.

## OccultAltar.swap

Definition:
```luau
function OccultAltar.swap(book: Book, via: ("menu" | "dialogue")?, altar: Loc?): (boolean, string?)
```
Swaps to `book`. True at once when it is in use already. A dialogue left open is answered; otherwise the menu option or the dialogue is used, as the account's biometrics favour (`Biometrics.CHOOSEOPTION`). `via` forces one way. When it didn't work the second result says why.

Example:
```luau
local OccultAltar = require("@lib/main/occult_altar")

local ok, why = OccultAltar.swap(OccultAltar.Book.Lunar)
assert(ok, why)
```
