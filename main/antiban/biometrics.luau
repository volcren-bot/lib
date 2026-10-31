--!strict
local Host = require("../../host")
local sleep = Host.sleep
local sleep_async = Host.sleep_async
local Geometry = require("../../utils/math/geometry")
local Log = require("../../utils/log")
local Mouse = require("../../utils/input/mouse")
local Player = require("../player")
local Random = require("../../utils/math/random")

local Biometrics = {}

export type Biometric = number

Biometrics.MULTIPLIER = 0
Biometrics.SLEEP_H = 1
Biometrics.SLEEP_M = 2
Biometrics.SLEEP_S = 3
Biometrics.SLEEP_LENGTH = 4
Biometrics.BREAKS = 5
Biometrics.MIN_CLICKTIME = 6
Biometrics.MAX_CLICKTIME = 7
Biometrics.MOUSE_SPEED = 8
Biometrics.MOUSE_GRAVITY = 9
Biometrics.MOUSE_WIND = 10
Biometrics.FKEYS = 11
Biometrics.ESCAPE = 12
Biometrics.CHAT_KEYBOARD = 13
Biometrics.CHOOSEOPTION = 14
Biometrics.SPAM_CLICK = 15
Biometrics.PATTERN = 16
Biometrics.BANK_CONSUME = 17
Biometrics.RATING = 18
Biometrics.LIKES = 19
Biometrics.DISLIKES = 20

local COUNT = 21

local HOUR = 3600000
local MINUTE = 60000
local SECOND = 1000
local DAY = 24 * HOUR

local hash: { number }? = nil
local seed_name: string? = nil

function Biometrics.murmur2a(text: string, seed: number?): number
	return Host.murmur2a(text, seed)
end

function Biometrics.hash_string(text: string): number
	return Biometrics.murmur2a(text, 0)
end

local function apply_mouse()
	Mouse.speed = 10 + 4 * Biometrics.get_probability(Biometrics.MOUSE_SPEED)
	Mouse.gravity = 8 + 2 * Biometrics.get_probability(Biometrics.MOUSE_GRAVITY)
	Mouse.wind = 4 + 2 * Biometrics.get_probability(Biometrics.MOUSE_WIND)
	Mouse.press_min = math.floor(30 + 20 * Biometrics.get_probability(Biometrics.MIN_CLICKTIME) + 0.5)
	Mouse.press_max = math.floor(190 + 60 * Biometrics.get_probability(Biometrics.MAX_CLICKTIME) + 0.5)
end

function Biometrics.setup(username: string?)
	if username == nil or username == "" then
		seed_name = nil
		hash = nil
		return
	end
	seed_name = username
	hash = Host.biometrics_profile(username)
	apply_mouse()
	Log.log("Biometrics", `Current account seed: {Biometrics.hash_string(username)}`)
end

function Biometrics.clean_name(name: string): string
	local clean = string.gsub(name, "\u{a0}", " ")
	clean = string.gsub(clean, "\xa0", " ")
	clean = string.gsub(clean, "_", " ")
	clean = string.gsub(clean, "^%s+", "")
	clean = string.gsub(clean, "%s+$", "")
	return string.lower(clean)
end

function Biometrics.setup_player(): boolean
	local name = Player.name()
	if name == nil then
		Log.log("Biometrics", "player name unknown")
		return false
	end
	local clean = Biometrics.clean_name(name)
	if clean == "" then
		return false
	end
	Biometrics.setup(clean)
	return true
end

function Biometrics.seed(): string?
	return seed_name
end

function Biometrics.hash(): { number }
	local current = hash
	if current ~= nil then
		return current
	end
	local bytes: { number } = {}
	for _ = 1, COUNT do
		bytes[#bytes + 1] = math.random(0, 255)
	end
	hash = bytes
	apply_mouse()
	Log.log("Biometrics", "Random hash created, call Biometrics.setup(username) for a permanent one.")
	return bytes
end

function Biometrics.get_biometric(biometric: Biometric): number
	return Biometrics.hash()[biometric + 1]
end

function Biometrics.get_probability(biometric: Biometric): number
	return Biometrics.get_biometric(biometric) / 255
end

function Biometrics.random_double(input: number): number
	local dev = input * Biometrics.get_probability(Biometrics.MULTIPLIER)
	return Random.gauss(input, dev)
end

function Biometrics.random_integer(input: number): number
	return math.floor(Biometrics.random_double(input) + 0.5)
end

function Biometrics.random_mode_double(input: number, minimum: number, maximum: number): number
	local dev = input * Biometrics.get_probability(Biometrics.MULTIPLIER)
	local value = Random.gauss(Random.mode(input, minimum, maximum), dev)
	return math.min(math.max(minimum, value), maximum)
end

function Biometrics.random_mode_integer(input: number, minimum: number, maximum: number): number
	return math.floor(Biometrics.random_mode_double(input, minimum, maximum) + 0.5)
end

function Biometrics.random_boolean(probability: number?): boolean
	if probability == nil then
		return Random.chance(Biometrics.random_double(0.5))
	end
	return Random.chance(Biometrics.random_double(probability))
end

function Biometrics.biometric_boolean(biometric: Biometric): boolean
	return Random.chance(Biometrics.get_probability(biometric))
end

local function two(n: number): string
	return string.format("%02d", n)
end

function Biometrics.sleep_hour(): string
	local ms = 23 * HOUR
	ms += 4 * Biometrics.get_probability(Biometrics.SLEEP_H) * HOUR
	ms += 59.99 * Biometrics.get_probability(Biometrics.SLEEP_M) * MINUTE
	ms += 59.99 * Biometrics.get_probability(Biometrics.SLEEP_S) * SECOND
	if ms > DAY then
		ms -= DAY
	end
	ms = math.floor(ms + 0.5)
	local h = math.floor(ms / HOUR)
	local m = math.floor(ms % HOUR / MINUTE)
	local s = math.floor(ms % MINUTE / SECOND)
	return `{two(h)}:{two(m)}:{two(s)}`
end

function Biometrics.sleep_length(): number
	local value = 6 + 4 * Biometrics.get_probability(Biometrics.SLEEP_LENGTH)
	return math.floor(value * 100 + 0.5) / 100
end

function Biometrics.sleep(minimum: number, maximum: number?, dir: Random.Dir?)
	if maximum == nil then
		sleep(math.max(0, Biometrics.random_integer(minimum)))
		return
	end
	local a = math.max(0, Biometrics.random_mode_integer(minimum, minimum, maximum))
	local b = math.max(0, Biometrics.random_mode_integer(maximum, minimum, maximum))
	Random.sleep(a, b, dir or "mean")
end

function Biometrics.sleep_async(minimum: number, maximum: number?, dir: Random.Dir?)
	if maximum == nil then
		sleep_async(math.max(0, Biometrics.random_integer(minimum)))
		return
	end
	local a = math.max(0, Biometrics.random_mode_integer(minimum, minimum, maximum))
	local b = math.max(0, Biometrics.random_mode_integer(maximum, minimum, maximum))
	Random.sleep_async(a, b, dir or "mean")
end

function Biometrics.click(button: Mouse.Button?, clicks: number?, probability: number?)
	local count = clicks or 3
	Mouse.click(nil, button)
	if not Biometrics.random_boolean(probability or 0.08) then
		return
	end
	for _ = 1, Biometrics.random_mode_integer(math.floor(count / 2), 1, count) do
		local at = Mouse.position()
		if at ~= nil then
			Mouse.click(Geometry.Circle.random_point(Geometry.Circle.new(at.x, at.y, 5)), button)
		else
			Mouse.click(nil, button)
		end
		Random.sleep(0, 100, "left")
	end
end

return Biometrics
