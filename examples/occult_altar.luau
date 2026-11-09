--!strict
local OccultAltar = require("@lib/main/occult_altar")

local books = OccultAltar.books()
assert(books and #books > 0, "no altar to read")
print(table.concat(books, ", "))
local ok, why = OccultAltar.swap(books[1])
assert(ok, why)
