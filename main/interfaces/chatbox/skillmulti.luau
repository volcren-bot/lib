--!strict
local Chatbox = require("./chatbox")

local Skillmulti = {
	GROUP = Chatbox.SKILLMULTI,
}

function Skillmulti.is_open(): boolean
	return Chatbox.is_open(Skillmulti.GROUP)
end

return Skillmulti
