--!strict
local Chatbox = require("../main/interfaces/chatbox/chatbox")
local GameVal = require("../utils/game_val")

local groups = Chatbox.interfaces()
if groups == nil or #groups == 0 then
	print("no chatbox interface open")
else
	for _, group in ipairs(groups) do
		print(`chatbox interface open: {GameVal.interface(group) or "?"} ({group})`)
	end
end
