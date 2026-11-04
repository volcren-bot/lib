--!strict
-- Opens the master scroll book, prints the scrolls and how many of each it holds, and closes it again. Teleports nowhere.
local Scrollbook = require("@lib/main/interfaces/mainscreen/scrollbook")

local ok, why = Scrollbook.open()
assert(ok, why)
for _, s in ipairs(Scrollbook.scrolls() or {}) do
	print(s.name, s.count)
end
-- To teleport, spending a scroll: Scrollbook.select(Scrollbook.Name.Watson)
assert(Scrollbook.close(), "couldn't close the book")
