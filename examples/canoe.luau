--!strict
-- Standing by a canoe station: says what it needs next and who keeps axes here. Paddles nowhere.
local Canoe = require("@lib/main/interfaces/mainscreen/canoe")

print("next step", Canoe.stage())
local keeper = Canoe.keeper()
print("keeper", keeper and keeper.name)
-- To paddle, making the smallest canoe for 1 stop: Canoe.travel("The Clock Tower", Canoe.Kind.Log)
