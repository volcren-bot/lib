--!strict
local Host = require("../host")

local GameState = {
	STARTING = 0,
	LOGIN_SCREEN = 10,
	LOGIN_SCREEN_AUTHENTICATOR = 11,
	LOGGING_IN = 20,
	LOADING = 25,
	LOGGED_IN = 30,
	CONNECTION_LOST = 40,
	HOPPING = 45,
}

local NAMES: { [number]: string } = {
	[GameState.STARTING] = "starting",
	[GameState.LOGIN_SCREEN] = "login screen",
	[GameState.LOGIN_SCREEN_AUTHENTICATOR] = "authenticator",
	[GameState.LOGGING_IN] = "logging in",
	[GameState.LOADING] = "loading",
	[GameState.LOGGED_IN] = "logged in",
	[GameState.CONNECTION_LOST] = "connection lost",
	[GameState.HOPPING] = "hopping",
}

GameState.FADE_GROUP = 174

function GameState.name(value: number): string?
	return NAMES[value]
end

function GameState.fading(): boolean
	return Host.widget(GameState.FADE_GROUP, 0) ~= nil
end

return GameState
