--!strict
-- Talks to an NPC and goes through its dialogue with ChatOptions, then prints the lines the chat history logged.
local NAME = "Captain Pudi"
local FIRST = "tell me more"
local LAST = "Goodbye"

local Chat = require("../main/interfaces/chatbox/chat")
local ChatOptions = require("../main/interfaces/chatbox/chat_options")
local Host = require("../host")
local Npcs = require("../main/entities/npcs")
local Walker = require("../main/walker")

local last = Chat.last_message()
local since = if last then last.uid else -1

if not (ChatOptions.contains_continue() or #assert(ChatOptions.get()) > 0) then
	local npc = assert(Npcs.nearest(NAME, assert(Walker.position())), `no {NAME} around`)
	assert(Npcs.interact(npc, "Talk-to"))
end
for _ = 1, 40 do
	if ChatOptions.contains_continue() or #(ChatOptions.get() or {}) > 0 then
		break
	end
	Host.sleep(100)
end

local function talk_until_options()
	for _ = 1, 30 do
		if #assert(ChatOptions.get()) > 0 then
			return
		end
		local speech = ChatOptions.speech()
		print("  continue:", if speech then `{speech.name}: {speech.text}` else "(no speech box)")
		assert(ChatOptions.continue_chat())
	end
	error("no options showed up")
end

talk_until_options()
print("title:", ChatOptions.title(), "is 'Select an option':", ChatOptions.is_title("Select an option"))
print("options:\n" .. assert(ChatOptions.to_string()))
print(`"{LAST}" is option`, ChatOptions.index_of(LAST))
print(`select "{FIRST}" (click):`, ChatOptions.select(FIRST, false, 0))
print(
	`continue until "{LAST}" (key):`,
	(function()
		local deadline = Host.time() + 60000
		while Host.time() < deadline do
			if ChatOptions.contains(LAST) then
				return ChatOptions.select(LAST, false, 1)
			end
			local speech = ChatOptions.speech()
			if speech then
				print("  continue:", `{speech.name}: {speech.text}`)
			end
			assert(ChatOptions.continue_chat())
		end
		return false
	end)()
)
while ChatOptions.contains_continue() do
	assert(ChatOptions.continue_chat())
end

print("logged dialogue:")
for _, m in ipairs(assert(Chat.new_messages(since))) do
	print(`  [{m.time_utc}] type {m.kind} {m.name}: {m.text}`)
end
