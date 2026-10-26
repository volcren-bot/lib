--!strict
local Host = require("../../../host")
local game_state = Host.game_state
local widget = Host.widget
local sub_interfaces = Host.sub_interfaces
local varp = Host.varp
local sleep = Host.sleep
type Widget = Host.Widget
local GameState = require("../../game_state")
local SidePanels = require("./side_panels")
local Mouse = require("../../../utils/input/mouse")
local Random = require("../../../utils/math/random")
local Biometrics = require("../../antiban/biometrics")
local Log = require("../../../utils/log")

local Logout = {
	GROUP = 182,
	WORLD_SWITCHER = 3,
	LOGOUT = 8,
	RATINGS = 18,
	FIRST_STAR = 19,
	RATING_VARP = 1707,
	SWITCHER_GROUP = 69,
	SWITCHER_CLOSE = 5,
	SWITCHER_LOGOUT = 25,
}

local POLL_MS = 100
local RATE_TIMEOUT_MS = 1800
local CLOSE_TIMEOUT_MS = 1200
local LOGOUT_ATTEMPTS = 5
local LOGOUT_TIME_MS = 20000

local function wait_until(condition: () -> boolean, timeout_ms: number): boolean
	local waited = 0
	while true do
		if condition() then
			return true
		end
		if waited >= timeout_ms then
			return false
		end
		sleep(POLL_MS)
		waited += POLL_MS
	end
end

local function logged_in(): boolean
	local state = game_state()
	return state.game_state == GameState.LOGGED_IN
end

function Logout.is_open(): boolean
	return SidePanels.is_open(SidePanels.LOGOUT)
end

function Logout.shows_world_switcher(): boolean
	local open = Logout.is_open()
	if not open then
		return open
	end
	local list = sub_interfaces()
	if list == nil then
		return false
	end
	for _, s in list do
		if s.group == Logout.SWITCHER_GROUP then
			return true
		end
	end
	return false
end

local function component(child: number): Widget?
	local w = widget(Logout.GROUP, child)
	if w == nil then
		return nil
	end
	return w
end

local function click_switcher(child: number): boolean
	local w = widget(Logout.SWITCHER_GROUP, child)
	if w == nil then
		return false
	end
	Mouse.click(w)
	return true
end

function Logout.open(): boolean
	local opened = SidePanels.open(SidePanels.LOGOUT)
	if not opened then
		return opened
	end
	local switcher = Logout.shows_world_switcher()
	if switcher == nil then
		return false
	end
	if not switcher then
		return true
	end
	local clicked = click_switcher(Logout.SWITCHER_CLOSE)
	if not clicked then
		return clicked
	end
	if not wait_until(function()
		return Logout.shows_world_switcher() == false
	end, CLOSE_TIMEOUT_MS) then
		Log.log("Logout", `the world switcher didn't close within {CLOSE_TIMEOUT_MS} ms`)
		return false
	end
	return true
end

export type Buttons = {
	ratings: { Widget },
	world_switcher: Widget,
	logout: Widget,
}

function Logout.buttons(): Buttons?
	local ratings: { Widget } = {}
	for stars = 1, 5 do
		local w = component(Logout.FIRST_STAR + stars - 1)
		if w == nil then
			return nil
		end
		table.insert(ratings, w)
	end
	local switcher = component(Logout.WORLD_SWITCHER)
	if switcher == nil then
		return nil
	end
	local logout = component(Logout.LOGOUT)
	if logout == nil then
		return nil
	end
	return { ratings = ratings, world_switcher = switcher, logout = logout }
end

function Logout.rating(): number?
	local value = varp(Logout.RATING_VARP)
	if value == nil then
		return nil
	end
	return bit32.band(bit32.rshift(value, 2), 7)
end

function Logout.is_rated(): boolean
	local rating = Logout.rating()
	if rating == nil then
		return false
	end
	return rating > 0
end

function Logout.rate(stars: number): boolean
	if stars < 1 or stars > 5 or stars % 1 ~= 0 then
		return false
	end
	local current = Logout.rating()
	if current == nil then
		return false
	end
	if current == stars then
		return true
	end
	local opened = Logout.open()
	if not opened then
		return opened
	end
	local star = component(Logout.FIRST_STAR + stars - 1)
	if star == nil then
		return false
	end
	Mouse.click(star)
	if not wait_until(function()
		return Logout.rating() == stars
	end, RATE_TIMEOUT_MS) then
		Log.log("Logout", `the rating didn't change to {stars} within {RATE_TIMEOUT_MS} ms`)
		return false
	end
	return true
end

local function press_until_logged_out(click: () -> boolean, attempts: number, time_ms: number): boolean
	local interval = time_ms // attempts
	for _ = 1, attempts do
		local clicked = click()
		if not clicked then
			return clicked
		end
		if
			wait_until(function()
				return not logged_in()
			end, math.max(POLL_MS, interval + Random.int(-2000, 2000)))
		then
			return true
		end
	end
	Log.log("Logout", `still logged in after {attempts} logout clicks`)
	return false
end

function Logout.logout_from_world_switcher(attempts: number?, time_ms: number?): boolean
	local switcher = Logout.shows_world_switcher()
	if not switcher then
		return switcher
	end
	return press_until_logged_out(function()
		return click_switcher(Logout.SWITCHER_LOGOUT)
	end, attempts or LOGOUT_ATTEMPTS, time_ms or LOGOUT_TIME_MS)
end

function Logout.logout(attempts: number?, time_ms: number?): boolean
	if not logged_in() then
		return true
	end
	local opened = SidePanels.open(SidePanels.LOGOUT)
	if not opened then
		return opened
	end
	attempts = attempts or LOGOUT_ATTEMPTS
	time_ms = time_ms or LOGOUT_TIME_MS
	if Logout.shows_world_switcher() then
		return Logout.logout_from_world_switcher(attempts, time_ms)
	end

	if Biometrics.biometric_boolean(Biometrics.RATING) then
		local skew = Random.trunc(Random.left(0, 4))
		local stars = if Biometrics.biometric_boolean(Biometrics.LIKES) then 5 - skew else 1 + skew
		Log.log("Logout", `rating the game {stars} stars before logging out`)
		Logout.rate(stars)
	end

	return press_until_logged_out(function()
		local button = component(Logout.LOGOUT)
		if button == nil then
			return false
		end
		Mouse.click(button)
		return true
	end, attempts :: number, time_ms :: number)
end

return Logout
