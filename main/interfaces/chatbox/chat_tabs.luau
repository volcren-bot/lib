--!strict
local Host = require("../../../host")
local widget = Host.widget
local varc = Host.varc
local sleep = Host.sleep
local Chat = require("./chat")
local Interact = require("../../interact")
local Log = require("../../../utils/log")
local Widgets = require("../widgets")

local ChatTabs = {}

export type Tab = "all" | "game" | "public" | "private" | "channel" | "clan" | "trade"
export type State = "enabled" | "filtered" | "disabled" | "hide" | "autochat"

ChatTabs.NAMES = table.freeze({ "all", "game", "public", "private", "channel", "clan", "trade" } :: { Tab })
local LABELS: { [Tab]: string } = {
	game = "Game",
	public = "Public",
	private = "Private",
	channel = "Channel",
	clan = "Clan",
	trade = "Trade",
}
local FILTER = 3
local STATES: { [string]: State } = {
	on = "enabled",
	all = "enabled",
	standard = "enabled",
	friends = "filtered",
	filtered = "filtered",
	off = "disabled",
	none = "disabled",
	hide = "hide",
	autochat = "autochat",
}
local OPTIONS: { [State]: string } = {
	enabled = "Show all",
	filtered = "Show friends",
	disabled = "Show none",
	hide = "Hide",
	autochat = "Show autochat",
}

local POLL_MS = 50
local CHANGE_TIMEOUT_MS = 1500

local function component(tab: Tab): number
	local index = table.find(ChatTabs.NAMES, tab)
	assert(index, `unknown chat tab "{tab}"`)
	return Chat.TABS[index]
end

function ChatTabs.active(): (Tab | "none")?
	local view = varc(Chat.VIEW_VARC)
	if view == nil then
		return nil
	end
	return ChatTabs.NAMES[view + 1] or "none"
end

function ChatTabs.is_active(tab: Tab): boolean
	local active = ChatTabs.active()
	if active == nil then
		return false
	end
	return active == tab
end

local function wait(check: () -> boolean, timeout_ms: number): boolean
	local waited = 0
	while true do
		local done = check()
		if done == nil then
			return false
		end
		if done or waited >= timeout_ms then
			return done
		end
		sleep(POLL_MS)
		waited += POLL_MS
	end
end

function ChatTabs.open(tab: Tab): boolean
	local active = ChatTabs.is_active(tab)
	if active == nil then
		return false
	end
	if active then
		return true
	end
	local clicked = Widgets.click(Chat.GROUP, component(tab))
	if not clicked then
		return clicked
	end
	return wait(function()
		return ChatTabs.is_active(tab)
	end, CHANGE_TIMEOUT_MS)
end

-- Queues the click and returns at once; true if the tab is active or queued, `force` clicks even when active.
function ChatTabs.open_async(tab: Tab, force: boolean?): boolean
	if not force and ChatTabs.is_active(tab) then
		return true
	end
	return Widgets.click_async(Chat.GROUP, component(tab))
end

function ChatTabs.state(tab: Tab): State?
	if tab == "all" then
		return nil
	end
	local w = widget(Chat.GROUP, component(tab) + FILTER)
	if w == nil then
		return nil
	end
	local text = string.lower(Chat.clean(w.text or ""))
	local state = STATES[text]
	if state == nil then
		Log.log("ChatTabs", `unknown filter "{text}" on the {tab} tab`)
		return nil
	end
	return state
end

function ChatTabs.set_state(tab: Tab, state: State): boolean
	local current = ChatTabs.state(tab)
	if current == nil then
		return false
	end
	if current == state then
		return true
	end
	local option: string
	if tab == "game" then
		if state ~= "enabled" and state ~= "filtered" then
			return false
		end
		option = "Game: Filter"
	elseif tab == "public" and state == "enabled" then
		option = "Public: Show standard"
	elseif tab ~= "public" and (state == "hide" or state == "autochat") then
		return false
	else
		option = `{LABELS[tab]}: {OPTIONS[state]}`
	end
	local tab_widget = widget(Chat.GROUP, component(tab))
	if tab_widget == nil then
		return false
	end
	local ok = Interact.with(tab_widget, option, nil, false)
	if not ok then
		return ok
	end
	return wait(function()
		local now = ChatTabs.state(tab)
		if now == nil then
			return false
		end
		return now == state
	end, CHANGE_TIMEOUT_MS)
end

return ChatTabs
