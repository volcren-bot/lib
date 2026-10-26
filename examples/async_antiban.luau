--!strict
-- Checks the async twins and the async antiban tasks against a live client, logged in: only tabs, hovers and menu-free clicks.
local Host = require("../host")
local Mouse = require("../utils/input/mouse")
local SidePanels = require("../main/interfaces/gametabs/side_panels")
local ChatTabs = require("../main/interfaces/chatbox/chat_tabs")
local Stats = require("../main/interfaces/gametabs/stats")
local Tasks = require("../main/antiban/antiban_tasks")

local function check(name: string, ok: boolean)
	print(`[{if ok then "ok" else "FAIL"}] {name}`)
end

local function settle()
	Mouse.wait()
	Host.sleep(400)
end

local start_panel = SidePanels.current()
local start_chat = ChatTabs.active()
check("logged in", start_panel ~= nil and start_chat ~= nil)

-- Twins return at once and the input lands.
local t = Host.time()
check("ChatTabs.open_async queues", ChatTabs.open_async("trade", true))
check("returns at once", Host.time() - t < 50)
settle()
check("chat tab changed", ChatTabs.is_active("trade"))

SidePanels.open(SidePanels.INVENTORY)
check("SidePanels.open_async force", SidePanels.open_async(SidePanels.STATS, 0, true))
settle()
check("stats open", SidePanels.is_open(SidePanels.STATS))

check("Stats.hover_async", Stats.hover_async("fishing"))
settle()
local menu = Host.menu()
check("menu is readable after", menu ~= nil)

-- Async tasks: toggles restore what they changed.
local active = ChatTabs.active()
Tasks.toggle_chat_tab(true)
check("toggle_chat_tab returns at once", Mouse.busy())
local deadline = Host.time() + 9000
while Mouse.busy() and Host.time() < deadline do
	Host.sleep(100)
end
Host.sleep(400)
check("toggle_chat_tab restored", ChatTabs.active() == active)

local panel = SidePanels.current()
Tasks.toggle_tab(true)
deadline = Host.time() + 12000
while Mouse.busy() and Host.time() < deadline do
	Host.sleep(100)
end
Host.sleep(400)
check("toggle_tab restored", SidePanels.current() == panel)

if start_chat ~= nil and start_chat ~= "none" then
	ChatTabs.open(start_chat)
end
if start_panel ~= nil then
	SidePanels.open(start_panel)
end
