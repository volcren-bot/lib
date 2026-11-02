--!strict
-- Opens the fairy ring dials at the nearest ring, prints the code they spell and the travel log's codes, and closes them again. Travels nowhere.
local Fairyring = require("@lib/main/interfaces/mainscreen/fairyring")

local ok, why = Fairyring.open()
assert(ok, why)
print("dials:", Fairyring.Dial.code())
for _, d in ipairs(Fairyring.Log.destinations() or {}) do
	print(`{d.code}: {d.name}`)
end
-- To travel, by a code or a part of a place's name (any case): Fairyring.travel("aiq") or Fairyring.travel("mudskipper")
assert(Fairyring.close(), "couldn't close the dials")
