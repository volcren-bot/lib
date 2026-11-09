--!strict

local Host = require("@lib/host")
local widget = Host.widget
local menu = Host.menu
local sleep = Host.sleep
type Widget = Host.Widget
local Chatbox = require("@lib/main/interfaces/chatbox/chatbox")
local Log = require("@lib/utils/log")
local Mouse = require("@lib/utils/input/mouse")
local Widgets = require("@lib/main/interfaces/widgets")

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
	return (widget(RecommendSurvey.GROUP, child))
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
	if not RecommendSurvey.is_open() then
		return false
	end
	local w = component(child)
	if w == nil then
		return false
	end
	Mouse.move(w)
	if not hovering(w) then
		return false
	end
	Mouse.click()
	return true
end

local function answer(child: number): boolean
	if not press(child) then
		return false
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
	return Widgets.checkbox(box) == "ticked"
end

function RecommendSurvey.toggle_dont_ask(): boolean
	return press(RecommendSurvey.DONT_ASK)
end

function RecommendSurvey.set_dont_ask(ticked: boolean): boolean
	if RecommendSurvey.dont_ask() == ticked then
		return true
	end
	if not RecommendSurvey.toggle_dont_ask() then
		return false
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
