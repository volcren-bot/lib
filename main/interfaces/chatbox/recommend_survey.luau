--!strict

local Host = require("../../../host")
local widget = Host.widget
local menu = Host.menu
local sleep = Host.sleep
type Widget = Host.Widget
local Chatbox = require("./chatbox")
local Log = require("../../../utils/log")
local Mouse = require("../../../utils/input/mouse")
local Widgets = require("../widgets")

local RecommendSurvey = {
	GROUP = Chatbox.RECOMMEND_SURVEY,
	FOOTNOTE = 1,
	DONT_ASK = 2,
	TITLE = 3,
	NO = 4,
	SKIP = 5,
	YES = 6,
	DONT_ASK_LABEL = 9,
	DONT_ASK_BOX = 10,
}

local POLL_MS = 50
local HOVER_TIMEOUT_MS = 600
local CLOSE_TIMEOUT_MS = 3000
local TOGGLE_TIMEOUT_MS = 1200

function RecommendSurvey.is_open(): boolean
	return Chatbox.is_open(RecommendSurvey.GROUP)
end

local function component(child: number): Widget?
	local w = widget(RecommendSurvey.GROUP, child)
	if w == nil then
		return nil
	end
	return w
end

local function hovering(w: Widget): boolean
	local waited = 0
	while true do
		local entries = menu()
		if entries == nil then
			return false
		end
		if entries[1] and entries[1].id == w.id then
			return true
		end
		if waited >= HOVER_TIMEOUT_MS then
			return false
		end
		sleep(POLL_MS)
		waited += POLL_MS
	end
end

local function press(child: number): boolean
	local open = RecommendSurvey.is_open()
	if open == nil then
		return false
	end
	if not open then
		return false
	end
	local w = component(child)
	if w == nil then
		return false
	end
	Mouse.move(w)
	local over = hovering(w)
	if over == nil then
		return false
	end
	if not over then
		return false
	end
	Mouse.click()
	return true
end

local function answer(child: number): boolean
	local pressed = press(child)
	if not pressed then
		return pressed
	end
	local waited = 0
	while waited < CLOSE_TIMEOUT_MS do
		sleep(POLL_MS)
		waited += POLL_MS
		if RecommendSurvey.is_open() == false then
			return true
		end
	end
	Log.log("RecommendSurvey", `the survey didn't close within {CLOSE_TIMEOUT_MS} ms`)
	return false
end

function RecommendSurvey.yes(): boolean
	return answer(RecommendSurvey.YES)
end

function RecommendSurvey.no(): boolean
	return answer(RecommendSurvey.NO)
end

function RecommendSurvey.skip(): boolean
	return answer(RecommendSurvey.SKIP)
end

function RecommendSurvey.dont_ask(): boolean
	local box = component(RecommendSurvey.DONT_ASK_BOX)
	if box == nil then
		return false
	end
	local state = Widgets.checkbox(box)
	if state == nil then
		return false
	end
	return state == "ticked"
end

function RecommendSurvey.toggle_dont_ask(): boolean
	return press(RecommendSurvey.DONT_ASK)
end

function RecommendSurvey.set_dont_ask(ticked: boolean): boolean
	local current = RecommendSurvey.dont_ask()
	if current == nil then
		return false
	end
	if current == ticked then
		return true
	end
	local pressed = RecommendSurvey.toggle_dont_ask()
	if not pressed then
		return pressed
	end
	local waited = 0
	while waited < TOGGLE_TIMEOUT_MS do
		sleep(POLL_MS)
		waited += POLL_MS
		if RecommendSurvey.dont_ask() == ticked then
			return true
		end
	end
	Log.log("RecommendSurvey", `"Don't ask again" didn't change within {TOGGLE_TIMEOUT_MS} ms`)
	return false
end

return RecommendSurvey
