--!strict
local Host = require("@lib/host")
local sleep = Host.sleep
local time = Host.time
local varbit = Host.varbit
type Loc = Host.Loc
local ChatOptions = require("@lib/main/interfaces/chatbox/chat_options")
local Log = require("@lib/utils/log")
local Npcs = require("@lib/main/entities/npcs")
local Objects = require("@lib/main/entities/objects")

local Pinball = {}

Pinball.FLIPPA = 6744
Pinball.ACCEPT = "Yes, pinball is fun."
Pinball.EXIT = 9293
Pinball.EXIT_OPTION = "Exit"
Pinball.TAG = "Tag"
Pinball.CURRENT = 2119
Pinball.SCORE = 2121
Pinball.TAGS = 10
Pinball.POSTS = { [0] = 8982, [1] = 8984, [2] = 9079, [3] = 9081, [4] = 9258 } :: { [number]: number }
Pinball.TAG_TIMEOUT_MS = 8000
Pinball.ARRIVE_TIMEOUT_MS = 8000
Pinball.LEAVE_TIMEOUT_MS = 15000
Pinball.SETTLE_MS = 600
Pinball.POLL_MS = 100

local function exit(): Loc?
	local found = Objects.find(Pinball.EXIT)
	return if found then found[1] else nil
end

function Pinball.inside(): boolean
	return exit() ~= nil
end

function Pinball.post(): Loc?
	local current = varbit(Pinball.CURRENT)
	local id = if current then Pinball.POSTS[current] else nil
	local found = if id then Objects.find(id) else nil
	return if found then found[1] else nil
end

function Pinball.score(): number
	return varbit(Pinball.SCORE) or 0
end

function Pinball.tag(): boolean
	local post = Pinball.post()
	if post == nil then
		Log.log("Pinball", "can't tell which post is lit")
		return false
	end
	local before = Pinball.score()
	if not Objects.interact(post, Pinball.TAG) then
		return false
	end
	local deadline = time() + Pinball.TAG_TIMEOUT_MS
	while Pinball.score() == before and time() < deadline do
		sleep(Pinball.POLL_MS)
	end
	if Pinball.score() == before then
		Log.log("Pinball", "the tag didn't count")
		return false
	end
	sleep(Pinball.SETTLE_MS)
	return true
end

function Pinball.leave(): boolean
	local door = exit()
	if door == nil or not Objects.approach(door, Pinball.EXIT_OPTION) then
		Log.log("Pinball", "couldn't use the cave exit")
		return false
	end
	local deadline = time() + Pinball.LEAVE_TIMEOUT_MS
	while Pinball.inside() and time() < deadline do
		if ChatOptions.contains_continue() then
			ChatOptions.continue_chat()
		end
		sleep(Pinball.POLL_MS)
	end
	return not Pinball.inside()
end

function Pinball.complete(): boolean
	local failures = 0
	while Pinball.inside() and Pinball.score() < Pinball.TAGS do
		if ChatOptions.contains_continue() then
			ChatOptions.continue_chat()
			sleep(Pinball.SETTLE_MS)
		elseif Pinball.tag() then
			failures = 0
		else
			failures += 1
			if failures >= 3 then
				return false
			end
		end
	end
	return not Pinball.inside() or Pinball.leave()
end

function Pinball.accept(flippa: Host.Npc): boolean
	if not Npcs.interact(flippa, "Talk-to") then
		return false
	end
	if not ChatOptions.continue_until_option(Pinball.ACCEPT, Pinball.ARRIVE_TIMEOUT_MS) then
		Log.log("Pinball", "Flippa didn't ask")
		return false
	end
	if not ChatOptions.select(Pinball.ACCEPT) then
		return false
	end
	local deadline = time() + Pinball.ARRIVE_TIMEOUT_MS
	while not Pinball.inside() and time() < deadline do
		if ChatOptions.contains_continue() then
			ChatOptions.continue_chat()
		end
		sleep(Pinball.POLL_MS * 5)
	end
	return Pinball.complete()
end

return Pinball
