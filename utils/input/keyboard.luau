--!strict
local Host = require("../../host")
local Log = require("../log")
local Random = require("../math/random")
local key_down = Host.key_down
local key_up = Host.key_up
local type_text = Host.type_text
local sleep = Host.sleep
local key_down_async = Host.key_down_async
local key_up_async = Host.key_up_async
local type_text_async = Host.type_text_async
local sleep_async = Host.sleep_async
local input_busy = Host.input_busy
local input_wait = Host.input_wait
local input_cancel = Host.input_cancel

local Keyboard = {}

Keyboard.keys = table.freeze({
	UNKNOWN = 0,
	LBUTTON = 1,
	RBUTTON = 2,
	CANCEL = 3,
	MBUTTON = 4,
	XBUTTON1 = 5,
	XBUTTON2 = 6,
	BACK = 8,
	TAB = 9,
	CLEAR = 12,
	RETURN = 13,
	SHIFT = 16,
	CONTROL = 17,
	MENU = 18,
	PAUSE = 19,
	CAPITAL = 20,
	ESCAPE = 27,
	CONVERT = 28,
	NONCONVERT = 29,
	ACCEPT = 30,
	MODECHANGE = 31,
	SPACE = 32,
	PRIOR = 33,
	NEXT = 34,
	END_KEY = 35,
	HOME = 36,
	LEFT = 37,
	UP = 38,
	RIGHT = 39,
	DOWN = 40,
	SELECT = 41,
	PRINT = 42,
	EXECUTE = 43,
	SNAPSHOT = 44,
	INSERT = 45,
	DELETE = 46,
	HELP = 47,
	NUM_0 = 48,
	NUM_1 = 49,
	NUM_2 = 50,
	NUM_3 = 51,
	NUM_4 = 52,
	NUM_5 = 53,
	NUM_6 = 54,
	NUM_7 = 55,
	NUM_8 = 56,
	NUM_9 = 57,
	A = 65,
	B = 66,
	C = 67,
	D = 68,
	E = 69,
	F = 70,
	G = 71,
	H = 72,
	I = 73,
	J = 74,
	K = 75,
	L = 76,
	M = 77,
	N = 78,
	O = 79,
	P = 80,
	Q = 81,
	R = 82,
	S = 83,
	T = 84,
	U = 85,
	V = 86,
	W = 87,
	X = 88,
	Y = 89,
	Z = 90,
	LWIN = 91,
	RWIN = 92,
	APPS = 93,
	SLEEP = 95,
	NUMPAD_0 = 96,
	NUMPAD_1 = 97,
	NUMPAD_2 = 98,
	NUMPAD_3 = 99,
	NUMPAD_4 = 100,
	NUMPAD_5 = 101,
	NUMPAD_6 = 102,
	NUMPAD_7 = 103,
	NUMPAD_8 = 104,
	NUMPAD_9 = 105,
	MULTIPLY = 106,
	ADD = 107,
	SEPARATOR = 108,
	SUBTRACT = 109,
	DECIMAL = 110,
	DIVIDE = 111,
	F1 = 112,
	F2 = 113,
	F3 = 114,
	F4 = 115,
	F5 = 116,
	F6 = 117,
	F7 = 118,
	F8 = 119,
	F9 = 120,
	F10 = 121,
	F11 = 122,
	F12 = 123,
	F13 = 124,
	F14 = 125,
	F15 = 126,
	F16 = 127,
	F17 = 128,
	F18 = 129,
	F19 = 130,
	F20 = 131,
	F21 = 132,
	F22 = 133,
	F23 = 134,
	F24 = 135,
	NUMLOCK = 144,
	SCROLL = 145,
	LSHIFT = 160,
	RSHIFT = 161,
	LCONTROL = 162,
	RCONTROL = 163,
	LMENU = 164,
	RMENU = 165,
	BROWSER_BACK = 166,
	BROWSER_FORWARD = 167,
	BROWSER_REFRESH = 168,
	BROWSER_STOP = 169,
	BROWSER_SEARCH = 170,
	BROWSER_FAVORITES = 171,
	BROWSER_HOME = 172,
	VOLUME_MUTE = 173,
	VOLUME_DOWN = 174,
	VOLUME_UP = 175,
	MEDIA_NEXT_TRACK = 176,
	MEDIA_PREV_TRACK = 177,
	MEDIA_STOP = 178,
	MEDIA_PLAY_PAUSE = 179,
	LAUNCH_MAIL = 180,
	LAUNCH_MEDIA_SELECT = 181,
	LAUNCH_APP1 = 182,
	LAUNCH_APP2 = 183,
	OEM_1 = 186,
	OEM_PLUS = 187,
	OEM_COMMA = 188,
	OEM_MINUS = 189,
	OEM_PERIOD = 190,
	OEM_2 = 191,
	OEM_3 = 192,
	OEM_4 = 219,
	OEM_5 = 220,
	OEM_6 = 221,
	OEM_7 = 222,
	OEM_8 = 223,
	OEM_102 = 226,
	PROCESSKEY = 231,
	ATTN = 246,
	CRSEL = 247,
	EXSEL = 248,
	EREOF = 249,
	PLAY = 250,
	ZOOM = 251,
})
local keys = Keyboard.keys

Keyboard.ARROWS = table.freeze({ keys.LEFT, keys.UP, keys.RIGHT, keys.DOWN })
Keyboard.FKEYS = table.freeze({
	keys.F1,
	keys.F2,
	keys.F3,
	keys.F4,
	keys.F5,
	keys.F6,
	keys.F7,
	keys.F8,
	keys.F9,
	keys.F10,
	keys.F11,
	keys.F12,
})
Keyboard.MISC = table.freeze({ keys.LCONTROL, keys.CONTROL, keys.SPACE, keys.SHIFT, keys.RSHIFT })

Keyboard.press_min = 30
Keyboard.press_max = 60
Keyboard.last_key = 0

local MODIFIERS: { [number]: string } = {
	[keys.SHIFT] = "shift",
	[keys.LSHIFT] = "shift",
	[keys.RSHIFT] = "shift",
	[keys.CONTROL] = "ctrl",
	[keys.LCONTROL] = "ctrl",
	[keys.RCONTROL] = "ctrl",
	[keys.MENU] = "alt",
	[keys.LMENU] = "alt",
	[keys.RMENU] = "alt",
}
local held_modifiers: { [string]: boolean } = {}
local held: { [number]: boolean } = {}

function Keyboard.interval_min(): number
	return Keyboard.press_min + 10
end

function Keyboard.interval_max(): number
	return Keyboard.press_max + 25
end

function Keyboard.key_down(key: number)
	local modifier = MODIFIERS[key]
	if modifier == nil then
		key_down(key)
	elseif not held_modifiers[modifier] then
		key_down(key)
		held_modifiers[modifier] = true
	end
	held[key] = true
	Keyboard.last_key = key
end

function Keyboard.key_up(key: number)
	local modifier = MODIFIERS[key]
	if modifier == nil then
		key_up(key)
	elseif held_modifiers[modifier] then
		key_up(key)
		held_modifiers[modifier] = false
		for other, name in MODIFIERS do
			if name == modifier then
				held[other] = nil
			end
		end
	end
	held[key] = nil
end

function Keyboard.key_press(key: number)
	Keyboard.key_down(key)
	sleep(Random.trunc(Random.left(Keyboard.press_min, Keyboard.press_max)))
	Keyboard.key_up(key)
end

local function key_of(char: string): number
	local code = string.byte(string.upper(char))
	if code ~= nil and ((code >= 48 and code <= 57) or (code >= 65 and code <= 90) or code == 32) and #char == 1 then
		return code
	end
	return 0
end

-- Async versions queue the input and return at once; held keys are released on cancel, blocking input, a minimenu read or script end.
function Keyboard.key_down_async(key: number)
	key_down_async(key)
	Keyboard.last_key = key
end

function Keyboard.key_up_async(key: number)
	key_up_async(key)
end

function Keyboard.key_press_async(key: number)
	Keyboard.key_down_async(key)
	sleep_async(Random.trunc(Random.left(Keyboard.press_min, Keyboard.press_max)))
	key_up_async(key)
end

function Keyboard.send_async(text: string, key_after: number?)
	local last = ""
	for char in string.gmatch(text, "[%z\1-\127\194-\244][\128-\191]*") do
		type_text_async(char, Random.trunc(Random.left(Keyboard.press_min, Keyboard.press_max)))
		sleep_async(Random.int(Keyboard.interval_min(), Keyboard.interval_max()))
		last = char
	end
	if last ~= "" then
		Keyboard.last_key = key_of(last)
	end

	if key_after ~= nil then
		sleep_async(Random.int(30, 120))
		Keyboard.key_press_async(key_after)
	end
end

-- Whether async keyboard (and mouse) input is still running or queued.
function Keyboard.busy(): boolean
	return input_busy()
end

-- Waits for async input to finish. False if one failed (the reason is printed).
function Keyboard.wait(): boolean
	local err = input_wait()
	if err then
		Log.log("Keyboard", `async input failed: {err}`)
		return false
	end
	return true
end

-- Stops async input, releasing the keys and buttons it holds, and drops what was queued.
function Keyboard.cancel()
	input_cancel()
end

function Keyboard.is_key_down(key: number): boolean
	return held[key] == true
end

function Keyboard.send(text: string, key_after: number?)
	for _, down in held_modifiers do
		if down then
			error("release Shift/Ctrl/Alt (Keyboard.key_up) before typing", 2)
		end
	end

	local last = ""
	for char in string.gmatch(text, "[%z\1-\127\194-\244][\128-\191]*") do
		type_text(char, Random.trunc(Random.left(Keyboard.press_min, Keyboard.press_max)))
		sleep(Random.int(Keyboard.interval_min(), Keyboard.interval_max()))
		last = char
	end
	if last ~= "" then
		Keyboard.last_key = key_of(last)
	end

	if key_after ~= nil then
		Random.sleep(30, 120, "left")
		Keyboard.key_press(key_after)
	end
end

function Keyboard.random_key()
	local roll = math.random(0, 99)
	if roll < 75 then
		local arrows = { keys.LEFT, keys.RIGHT, keys.UP }
		Keyboard.key_press(arrows[math.random(1, 3)])
	elseif roll < 90 then
		Keyboard.key_press(Keyboard.FKEYS[math.random(1, #Keyboard.FKEYS)])
	else
		Keyboard.key_press(Keyboard.MISC[math.random(1, #Keyboard.MISC)])
	end
end

return Keyboard
