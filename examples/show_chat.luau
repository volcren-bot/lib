--!strict
-- Prints the last chat messages, the displayed rows, the input line, the account type and the tabs.
local Chat = require("../main/interfaces/chatbox/chat")
local ChatTabs = require("../main/interfaces/chatbox/chat_tabs")

local messages = assert(Chat.messages())
print(`{#messages} messages, the last 10:`)
for i = math.max(1, #messages - 9), #messages do
	local m = messages[i]
	local who = if m.name ~= "" then `{m.name}: ` else ""
	print(`  #{m.uid} [{m.time_utc} UTC, {math.floor(m.age / 1000)} s ago] type {m.kind}: {who}{m.text}`)
end

print("shown:")
for _, line in ipairs(assert(Chat.lines())) do
	print(`  {line}`)
end

print("display name:", Chat.display_name())
print("typed:", Chat.input_text())
print("account:", Chat.iron_type())
print("transparent:", Chat.is_transparent(), "open:", Chat.is_open())
print("query:", Chat.query())
print("active tab:", ChatTabs.active())
for _, tab in ipairs(ChatTabs.NAMES) do
	print(`  {tab}:`, ChatTabs.state(tab))
end
