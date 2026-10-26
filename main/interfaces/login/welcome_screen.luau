--!strict
local Host = require("../../../host")
local game_state = Host.game_state
local widget = Host.widget
type ClientState = Host.ClientState
type Widget = Host.Widget
local GameState = require("../../game_state")
local Mouse = require("../../../utils/input/mouse")

local WelcomeScreen = {}

WelcomeScreen.ROOT_INTERFACE = 165
WelcomeScreen.GROUP = 378
WelcomeScreen.PLAY_BUTTON = 72

function WelcomeScreen.is_open(state: ClientState): boolean
	return state.game_state == GameState.LOGGED_IN and state.root_interface == WelcomeScreen.ROOT_INTERFACE
end

function WelcomeScreen.play_button(): Widget?
	return widget(WelcomeScreen.GROUP, WelcomeScreen.PLAY_BUTTON)
end

function WelcomeScreen.play(): boolean
	local state = game_state()
	if not WelcomeScreen.is_open(state) then
		return false
	end
	local button = WelcomeScreen.play_button()
	if button == nil then
		return false
	end
	Mouse.click(button)
	return true
end

return WelcomeScreen
