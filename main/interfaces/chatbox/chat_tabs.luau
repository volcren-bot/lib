--!strict
local Host = require("@lib/host")
local widget = Host.widget
local varc = Host.varc
local Chat = require("@lib/main/interfaces/chatbox/chat")
local Interact = require("@lib/main/interact")
local Log = require("@lib/utils/log")
local Widgets = require("@lib/main/interfaces/widgets")

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
	return active ~= nil and active == tab
end

function ChatTabs.open(tab: Tab): boolean
	if ChatTabs.is_active(tab) then
		return true
	end
	if not Widgets.click(Chat.GROUP, component(tab)) then
		return false
	end
	return Widgets.wait_until(function()
		return ChatTabs.is_active(tab)
	end, CHANGE_TIMEOUT_MS)
end

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
	if not Interact.with(tab_widget, option, nil, false) then
		return false
	end
	return Widgets.wait_until(function()
		local now = ChatTabs.state(tab)
		return now ~= nil and now == state
	end, CHANGE_TIMEOUT_MS)
end

return ChatTabs
