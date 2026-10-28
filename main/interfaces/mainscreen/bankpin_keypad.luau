--!strict

local Host = require("../../../host")
local widget = Host.widget
local widget_children = Host.widget_children
local menu = Host.menu
local sleep = Host.sleep
type Widget = Host.Widget
local Biometrics = require("../../antiban/biometrics")
local Chatbox = require("../chatbox/chatbox")
local Keyboard = require("../../../utils/input/keyboard")
local Log = require("../../../utils/log")
local Mouse = require("../../../utils/input/mouse")
local Toplevel = require("./toplevel")
local Widgets = require("../widgets")

local BankpinKeypad = {
	GROUP = 213,
	TITLE = 2,
	ENTERED = table.freeze({ 3, 4, 5, 6 }),
	INSTRUCTION = 7,
	PROMPT = 10,
	EXIT = 13,
	FORGOT = 15,
	BUTTONS = table.freeze({ 16, 18, 20, 22, 24, 26, 28, 30, 32, 34 }),
}

local POLL_MS = 50
local HOVER_TIMEOUT_MS = 600
local DIGIT_TIMEOUT_MS = 5000
local UNLOCK_TIMEOUT_MS = 3000
local REOPEN_TIMEOUT_MS = 3000
local FORGOTTEN_TIMEOUT_MS = 20000
local ORDINALS = { "FIRST", "SECOND", "THIRD", "FOURTH" }

local function wait_until(timeout_ms: number, check: () -> boolean): boolean
	local waited = 0
	while true do
		if check() then
			return true
		end
		if waited >= timeout_ms then
			return false
		end
		sleep(POLL_MS)
		waited += POLL_MS
	end
end

function BankpinKeypad.is_open(): boolean
	return Toplevel.is_open(BankpinKeypad.GROUP)
end

function BankpinKeypad.wait_open(timeout_ms: number?): boolean
	return wait_until(timeout_ms or 600, function()
		return BankpinKeypad.is_open() == true
	end)
end

local function digit_of(button: Widget, mouse: { x: number, y: number }?): (string?, boolean)
	for _, created in ipairs(widget_children(BankpinKeypad.GROUP, button.child) or {}) do
		local text = created.text
		if text and string.match(text, "^%d$") then
			local shown = not created.hidden or (mouse ~= nil and Widgets.contains(button, mouse.x, mouse.y))
			return text, shown
		end
	end
	return nil, false
end

function BankpinKeypad.buttons(): { [string]: Widget }?
	local mouse = Mouse.position()
	local found: { [string]: Widget } = {}
	for _, child in ipairs(BankpinKeypad.BUTTONS) do
		local button = widget(BankpinKeypad.GROUP, child)
		if button and not button.hidden then
			local digit, shown = digit_of(button, mouse)
			if digit and shown then
				found[digit] = button
			end
		end
	end
	return found
end

function BankpinKeypad.is_loading(): boolean
	local open = BankpinKeypad.is_open()
	if not open then
		return open
	end
	local buttons = BankpinKeypad.buttons()
	if buttons == nil then
		return false
	end
	for digit = 0, 9 do
		if buttons[tostring(digit)] == nil then
			return true
		end
	end
	return false
end

function BankpinKeypad.wait_loading(timeout_ms: number?): boolean
	return wait_until(timeout_ms or 600, function()
		return BankpinKeypad.is_loading() == false
	end)
end

function BankpinKeypad.digit_index(): number?
	local prompt = widget(BankpinKeypad.GROUP, BankpinKeypad.PROMPT)
	if prompt == nil or prompt.hidden or prompt.text == nil then
		return 0
	end
	for i, ordinal in ipairs(ORDINALS) do
		if string.find(prompt.text, ordinal, 1, true) then
			return i
		end
	end
	return 0
end

function BankpinKeypad.find_digit(digit: string | number): Widget?
	local buttons = BankpinKeypad.buttons()
	if buttons == nil then
		return nil
	end
	return buttons[tostring(digit)]
end

local function hovering(button: Widget): boolean
	local over = false
	wait_until(HOVER_TIMEOUT_MS, function()
		local entries = menu()
		if entries == nil then
			return true
		end
		over = entries[1] ~= nil and entries[1].id == button.id
		return over
	end)
	return over
end

function BankpinKeypad.click_digit(digit: string | number): boolean
	local open = BankpinKeypad.is_open()
	if not open then
		return open
	end
	local button = BankpinKeypad.find_digit(digit)
	if button == nil then
		return false
	end
	Mouse.move(button)
	local over = hovering(button)
	if over == nil then
		return false
	end
	if not over then
		return false
	end
	Mouse.click()
	return true
end

local function chat_has(text: string, needle: string): boolean
	return string.find(string.lower(text), string.lower(needle), 1, true) ~= nil
end

local function chat(): string
	return Chatbox.text() or ""
end

local function failed(text: string): boolean
	return chat_has(text, "try again")
		or chat_has(text, "forgotten your PIN")
		or chat_has(text, "PIN incorrectly several")
end

local function type_digits(pin: string): boolean
	for _ = 1, 4 do
		local index = BankpinKeypad.digit_index()
		if index == nil then
			return false
		end
		if index == 0 then
			break
		end
		if not BankpinKeypad.wait_loading(3000) then
			Log.log("BankpinKeypad", "the bank PIN buttons didn't load within 3 seconds")
			return false
		end
		local clicked = BankpinKeypad.click_digit(string.sub(pin, index, index))
		if not clicked then
			return clicked
		end
		Biometrics.sleep(200, 1500, "left")
		wait_until(DIGIT_TIMEOUT_MS, function()
			return BankpinKeypad.digit_index() ~= index and BankpinKeypad.is_loading() ~= true
		end)
	end
	return true
end

function BankpinKeypad.enter(pin: string, attempts: number?): boolean
	if not string.match(pin, "^%d%d%d%d$") then
		return false
	end
	local open = BankpinKeypad.is_open()
	if not open then
		return open
	end

	for _ = 1, attempts or 3 do
		local typed = type_digits(pin)
		if typed == nil then
			return false
		end

		local text = chat()
		if chat_has(text, "PIN incorrectly several") then
			return false
		elseif chat_has(text, "try again") then
			Keyboard.key_press(Keyboard.keys.SPACE)
			if not BankpinKeypad.wait_open(REOPEN_TIMEOUT_MS) then
				return false
			end
		elseif chat_has(text, "forgotten your PIN") then
			wait_until(FORGOTTEN_TIMEOUT_MS, function()
				return not chat_has(chat(), "forgotten your PIN")
			end)
		elseif
			wait_until(UNLOCK_TIMEOUT_MS, function()
				return BankpinKeypad.is_open() == false and not failed(chat())
			end)
		then
			return true
		end

		if BankpinKeypad.is_open() == false and not failed(chat()) then
			return true
		end
	end
	return false
end

return BankpinKeypad
