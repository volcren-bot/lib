--!strict
-- Lists the books the Altar of the Occult offers, then swaps to the first of them. Run it in a house with the altar.
local OccultAltar = require("@lib/main/occult_altar")

local books = OccultAltar.books()
assert(books and #books > 0, "no altar to read")
print(table.concat(books, ", "))
local ok, why = OccultAltar.swap(books[1])
assert(ok, why)
