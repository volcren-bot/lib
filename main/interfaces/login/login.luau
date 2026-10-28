--!strict
local Host = require("../../../host")
local game_state = Host.game_state
local sleep = Host.sleep
type ClientState = Host.ClientState
local GameState = require("../../game_state")
local Log = require("../../../utils/log")
local Mouse = require("../../../utils/input/mouse")
local RecommendSurvey = require("../chatbox/recommend_survey")
local TitleScreen = require("./titlescreen")
local WelcomeScreen = require("./welcome_screen")

local Login = {}

local NEXT: { [number]: string } = {
	[TitleScreen.PLAY_NOW] = "play_now",
	[TitleScreen.DISCONNECTED] = "try_again",
	[TitleScreen.ERROR] = "try_again",
	[TitleScreen.INVALID_CREDENTIALS] = "try_again",
	[TitleScreen.CONNECTION_ERROR] = "try_again",
}

function Login.login(): boolean
	local state = game_state()
	if state.game_state == nil then
		Log.log("Login", "game state unknown")
		return false
	end
	if state.game_state ~= GameState.LOGIN_SCREEN and state.game_state ~= GameState.LOGIN_SCREEN_AUTHENTICATOR then
		return false
	end
	local layout = state.login
	if layout == nil then
		Log.log("Login", "login screen layout unknown (agent didn't find it, or is older than protocol 7)")
		return false
	end

	local name: string? = NEXT[layout.screen]
	local button = if name then TitleScreen.button(layout, name) else nil
	if button == nil then
		return false
	end
	Mouse.click(button)
	return true
end

local POLL_MS = 250
local PRESS_MS = 1000
local LOBBY_TIMEOUT_MS = 8000
local SURVEY_TIMEOUT_MS = 2000

function Login.sign_in(timeout_ms: number?): boolean
	local limit = timeout_ms or 60000
	local elapsed = 0

	local function wait(ms: number): boolean
		sleep(ms)
		elapsed += ms
		return elapsed < limit
	end

	while true do
		local state = game_state()
		if state.game_state == GameState.LOGGED_IN then
			break
		end
		local layout = state.login
		if layout ~= nil and layout.screen == TitleScreen.INVALID_CREDENTIALS then
			Log.log("Login", "invalid credentials")
			return false
		end
		local pressed = Login.login()
		if pressed == nil then
			return false
		end
		if not wait(if pressed then PRESS_MS else POLL_MS) then
			Log.log("Login", "timed out logging in")
			return false
		end
	end

	local lobby_waited = 0
	local played = false
	while true do
		local state = game_state()
		if WelcomeScreen.is_open(state) then
			local clicked = WelcomeScreen.play()
			if clicked == nil then
				return false
			end
			played = true
			if not wait(PRESS_MS) then
				Log.log("Login", "timed out on the lobby")
				return false
			end
		else
			if played or lobby_waited >= LOBBY_TIMEOUT_MS then
				break
			end
			if not wait(POLL_MS) then
				Log.log("Login", "timed out waiting for the lobby")
				return false
			end
			lobby_waited += POLL_MS
		end
	end

	local survey_waited = 0
	while survey_waited <= SURVEY_TIMEOUT_MS do
		local open = RecommendSurvey.is_open()
		if open == nil then
			return false
		end
		if open then
			local skipped = RecommendSurvey.skip()
			if skipped == nil then
				return false
			end
			return true
		end
		if not wait(POLL_MS) then
			break
		end
		survey_waited += POLL_MS
	end
	return true
end

return Login
