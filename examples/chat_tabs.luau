--!strict
-- Switches chat tabs, changes the trade filter and back, and hides and shows the chatbox.
local Chat = require("../main/interfaces/chatbox/chat")
local ChatTabs = require("../main/interfaces/chatbox/chat_tabs")

local start = assert(ChatTabs.active())
print("active:", start)
print("open game:", ChatTabs.open("game"), ChatTabs.active())
print("open all:", ChatTabs.open("all"), ChatTabs.active())

local trade = assert(ChatTabs.state("trade"))
local other = if trade == "filtered" then "enabled" else "filtered"
print(`trade {trade} -> {other}:`, ChatTabs.set_state("trade", other), ChatTabs.state("trade"))
print(`trade back to {trade}:`, ChatTabs.set_state("trade", trade), ChatTabs.state("trade"))
print("public hide on trade:", ChatTabs.set_state("trade", "hide"))

print("close:", Chat.close(), Chat.is_open(), ChatTabs.active())
print("open:", Chat.open(), Chat.is_open(), ChatTabs.active())
