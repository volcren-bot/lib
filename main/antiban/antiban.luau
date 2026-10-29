--!strict
local Host = require("../../host")
local sleep = Host.sleep
local Biometrics = require("./biometrics")
local Camera = require("../camera")
local GameState = require("../game_state")
local Log = require("../../utils/log")
local Login = require("../interfaces/login/login")
local Logout = require("../interfaces/gametabs/logout")
local Mouse = require("../../utils/input/mouse")
local Random = require("../../utils/math/random")

local Antiban = {}

Antiban.SECOND = 1000

Antiban.MINUTE = 60 * Antiban.SECOND
Antiban.HOUR = 60 * Antiban.MINUTE
Antiban.DAY = 24 * Antiban.HOUR

local SECONDS_PER_DAY = 86400
local CALLBACK_MS = 5 * Antiban.SECOND
local SLEEP_CALLBACK_MS = 5 * Antiban.MINUTE

export type Task = {
	method: (async: boolean?) -> (),
	async: boolean?,
	interval: number,
	std_var: number,
	next: number,
}

export type Scope = "game" | "outside" | "any"

export type AsyncTask = {
	method: (async: boolean?) -> (),
	scope: Scope,
	interval: number,
	std_var: number,
	next: number,
}

export type Break = {
	interval: number,
	length: number,
	std_var: number,
	logout_chance: number,
	next: number,
}

export type Sleep = {
	time: string,
	length: number,
	std_var: number,
	logout_chance: number,
	next: number,
}

export type Countdown = {
	finish: number,
}

Antiban.tasks = {} :: { Task }
Antiban.walk_tasks = {} :: { Task }
Antiban.async_tasks = {} :: { AsyncTask }
Antiban.breaks = {} :: { Break }
Antiban.sleeps = {} :: { Sleep }
Antiban.doing_antiban = false

-- The raw camera range the zoom and pitch tasks stay in.
Antiban.zoom = { min = Camera.ZOOM_MIN, max = Camera.ZOOM_MAX }
Antiban.pitch = { min = Camera.PITCH_MIN, max = Camera.PITCH_MAX }

Antiban.on_start_task = nil :: ((task: Task) -> ())?
Antiban.on_finish_task = nil :: ((task: Task) -> ())?
Antiban.on_start_break = nil :: ((task: Break) -> ())?
Antiban.on_finish_break = nil :: ((task: Break) -> ())?
Antiban.on_start_sleep = nil :: ((task: Sleep) -> ())?
Antiban.on_finish_sleep = nil :: ((task: Sleep) -> ())?
Antiban.on_breaking = nil :: ((task: Break, countdown: Countdown) -> ())?
Antiban.on_sleeping = nil :: ((task: Sleep, countdown: Countdown) -> ())?

local paused_total = 0
local paused_at: number? = nil

local function running_ms(): number
	local now = Host.time()
	local paused = paused_total
	if paused_at ~= nil then
		paused += now - paused_at
	end
	return now - paused
end

local function pause_clock(): boolean
	if paused_at ~= nil then
		return false
	end
	paused_at = Host.time()
	return true
end

local function resume_clock(paused_here: boolean)
	local since = paused_at
	if not paused_here or since == nil then
		return
	end
	paused_total += Host.time() - since
	paused_at = nil
end

local function paused(fn: () -> ())
	local here = pause_clock()
	fn()
	resume_clock(here)
end

local function around(interval: number, std_var: number): number
	return math.abs(Random.gauss(interval, interval * std_var))
end

local PUBLISH_MS = 30 * Antiban.SECOND
local last_published = -PUBLISH_MS

-- Sends the schedule to the loader's Breaks tab, which counts the times down itself, so unless `force` is set
-- (the schedule changed) it goes out at most every `PUBLISH_MS`.
local function publish(force: boolean?, active: Host.ActiveBreak?)
	local now = Host.time()
	if not force and now - last_published < PUBLISH_MS then
		return
	end
	last_published = now
	local running = running_ms()
	local clock = Host.clock()
	local breaks: { Host.PlannedBreak } = {}
	for _, task in Antiban.breaks do
		table.insert(breaks, { remaining = math.max(0, task.next - running), length = task.length })
	end
	local sleeps: { Host.PlannedBreak } = {}
	for _, task in Antiban.sleeps do
		local remaining = math.max(0, task.next - running)
		table.insert(
			sleeps,
			{ remaining = remaining, length = task.length, at = (clock + remaining / Antiban.SECOND) % SECONDS_PER_DAY }
		)
	end
	Host.report_breaks({ breaks = breaks, sleeps = sleeps, active = active })
end

local function format_ms(ms: number): string
	local total = math.max(0, math.floor(ms / Antiban.SECOND + 0.5))
	return string.format("%02d:%02d:%02d", total // 3600, total % 3600 // 60, total % 60)
end

local function logged_in(): boolean
	local state = Host.game_state()
	return state.game_state == GameState.LOGGED_IN
end

local function clock_seconds(value: string): number
	local h, m, s = string.match(value, "^(%d%d?):(%d%d)(:?%d*)$")
	assert(h ~= nil and m ~= nil and s ~= nil, `sleep time must be HH:MM or HH:MM:SS, not {value}`)
	local seconds = (tonumber(h) or 0) * 3600 + (tonumber(m) or 0) * 60
	local secs = string.gsub(s, ":", "")
	return seconds + (tonumber(secs) or 0)
end

function Antiban.time_running_at_clock(value: string, randomness: number?): number
	local target = clock_seconds(value)
	local diff = target - Host.clock()
	if diff < 0 then
		diff += SECONDS_PER_DAY
	end
	local offset = math.abs(Random.gauss(0, (randomness or 0.1) * Antiban.DAY / 2))
	return running_ms() + math.floor(diff * Antiban.SECOND) + math.floor(offset)
end

local function first_due(interval: number, std_var: number): number
	return running_ms() + Random.float(0, math.floor(around(interval, std_var)))
end

-- Limits the zoom tasks to a percent range of the camera's range (0 farthest, 100 closest).
function Antiban.set_zoom_range(min_percent: number, max_percent: number)
	local span = Camera.ZOOM_MAX - Camera.ZOOM_MIN
	Antiban.zoom.min = math.round(Camera.ZOOM_MIN + span * math.clamp(min_percent, 0, 100) / 100)
	Antiban.zoom.max = math.round(Camera.ZOOM_MIN + span * math.clamp(max_percent, 0, 100) / 100)
end

-- Limits the pitch tasks to a percent range of the camera's range (0 lowest, 100 highest).
function Antiban.set_pitch_range(min_percent: number, max_percent: number)
	local span = Camera.PITCH_MAX - Camera.PITCH_MIN
	Antiban.pitch.min = math.round(Camera.PITCH_MIN + span * math.clamp(min_percent, 0, 100) / 100)
	Antiban.pitch.max = math.round(Camera.PITCH_MIN + span * math.clamp(max_percent, 0, 100) / 100)
end

function Antiban.add_task(method: (async: boolean?) -> (), interval: number, randomness: number?, async: boolean?)
	local std_var = randomness or 0.2
	table.insert(Antiban.tasks, {
		method = method,
		async = async,
		interval = interval,
		std_var = std_var,
		next = first_due(interval, std_var),
	})
end

function Antiban.add_walk_task(method: (async: boolean?) -> (), interval: number, randomness: number?, async: boolean?)
	local std_var = randomness or 0.2
	table.insert(Antiban.walk_tasks, {
		method = method,
		async = async,
		interval = interval,
		std_var = std_var,
		next = first_due(interval, std_var),
	})
end

-- Tasks that queue input and return at once, run by `do_async_tasks` for `scope`: "game", "outside" or "any".
function Antiban.add_async_task(method: (async: boolean?) -> (), interval: number, randomness: number?, scope: Scope?)
	local std_var = randomness or 0.2
	table.insert(Antiban.async_tasks, {
		method = method,
		scope = scope or "any",
		interval = interval,
		std_var = std_var,
		next = first_due(interval, std_var),
	})
end

-- Pushes every task's due time back by `ms`; breaks and sleeps are untouched.
function Antiban.delay_tasks(ms: number)
	for _, list in { Antiban.tasks, Antiban.walk_tasks, Antiban.async_tasks } do
		for _, task in list do
			task.next += ms
		end
	end
end

function Antiban.add_break(interval: number, length: number, randomness: number?, logout_chance: number?)
	local std_var = randomness or 0.2
	table.insert(Antiban.breaks, {
		interval = interval,
		length = length,
		std_var = std_var,
		logout_chance = logout_chance or 0.33,
		next = running_ms() + around(interval, std_var),
	})
	publish(true)
end

function Antiban.add_sleep(time: string, length: number, randomness: number?, logout_chance: number?)
	local std_var = randomness or 0.1
	table.insert(Antiban.sleeps, {
		time = time,
		length = length,
		std_var = std_var,
		logout_chance = logout_chance or 0.5,
		next = Antiban.time_running_at_clock(time, std_var),
	})
	publish(true)
end

function Antiban.lose_focus(): boolean
	local conn = Host.connection()
	local x = if Random.chance(0.5) then conn.width + Random.int(5, 40) else -Random.int(5, 40)
	local y = Random.int(0, conn.height)
	Mouse.move({ x = x, y = y })
	return true
end

local function run_task(task: Task, start: (Task) -> (), finish: (Task) -> ())
	start(task)
	task.method(task.async)
	task.next = running_ms() + math.floor(around(task.interval, task.std_var))
	finish(task)
end

local function do_tasks(list: { Task }): boolean
	local ran = false
	for _, task in list do
		if running_ms() >= task.next then
			ran = true
			paused(function()
				run_task(task, Antiban.on_start_task or function() end, Antiban.on_finish_task or function() end)
			end)
		end
	end
	return ran
end

function Antiban.do_task(): boolean
	return do_tasks(Antiban.tasks)
end

function Antiban.do_walk_task(): boolean
	return do_tasks(Antiban.walk_tasks)
end

-- Queues the first due async task of `scope` (or "any"), unless input is still queued; never blocks or pauses the clock.
function Antiban.do_async_tasks(scope: "game" | "outside"): boolean
	if Mouse.busy() then
		return false
	end
	local now = running_ms()
	for _, task in Antiban.async_tasks do
		if now >= task.next and (task.scope == scope or task.scope == "any") then
			task.method(true)
			task.next = running_ms() + math.floor(around(task.interval, task.std_var))
			return true
		end
	end
	return false
end

function Antiban.take_break(task: Break)
	paused(function()
		local countdown: Countdown =
			{ finish = Host.time() + math.floor(math.abs(Random.gauss(task.length, task.length * task.std_var))) }
		Log.log("Antiban", `Taking a break for {format_ms(countdown.finish - Host.time())}`)
		publish(true, { kind = "break", remaining = countdown.finish - Host.time() })

		if Antiban.on_start_break then
			Antiban.on_start_break(task)
		end

		if Random.chance(task.logout_chance) then
			Log.log("Antiban", "Logging out.")
			local ok = Logout.logout()
			if not ok then
				Log.log("Antiban", `Logout failed`)
			end
		end

		if Biometrics.random_boolean(0.5) then
			Antiban.lose_focus()
		end

		local steps = 0
		repeat
			steps += 1
			local remaining = countdown.finish - Host.time()
			if steps % 12 == 0 then
				Log.log("Antiban", `Break time remaining: {format_ms(remaining)}`)
			end
			if Antiban.on_breaking then
				Antiban.on_breaking(task, countdown)
			end
			sleep(math.floor(math.max(0, math.min(countdown.finish - Host.time(), CALLBACK_MS))))
		until countdown.finish - Host.time() <= 0

		Log.log("Antiban", "Break finished")

		if Antiban.on_finish_break then
			Antiban.on_finish_break(task)
		end

		task.next = running_ms() + around(task.interval, task.std_var)
		publish(true)
	end)
end

function Antiban.take_sleep(task: Sleep)
	paused(function()
		local countdown: Countdown =
			{ finish = Host.time() + math.floor(math.abs(Random.gauss(task.length, task.length * task.std_var))) }
		Log.log("Antiban", `Sleeping for {format_ms(countdown.finish - Host.time())}`)
		publish(true, { kind = "sleep", remaining = countdown.finish - Host.time() })

		if Antiban.on_start_sleep then
			Antiban.on_start_sleep(task)
		end

		if Random.chance(task.logout_chance) then
			Log.log("Antiban", "Logging out.")
			local ok = Logout.logout()
			if not ok then
				Log.log("Antiban", `Logout failed`)
			end
		end

		if Random.chance(0.7) then
			Antiban.lose_focus()
		end

		local next_callback = 0
		repeat
			if Host.time() > next_callback then
				Log.log("Antiban", `Sleep time remaining: {format_ms(countdown.finish - Host.time())}`)
				if Antiban.on_sleeping then
					Antiban.on_sleeping(task, countdown)
				end
				next_callback = Host.time() + SLEEP_CALLBACK_MS
			end
			sleep(math.floor(math.max(0, math.min(countdown.finish - Host.time(), CALLBACK_MS))))
		until countdown.finish - Host.time() <= 0

		Log.log("Antiban", "Sleep finished.")

		if Antiban.on_finish_sleep then
			Antiban.on_finish_sleep(task)
		end

		task.next = Antiban.time_running_at_clock(task.time, task.std_var)
		publish(true)
	end)
end

function Antiban.do_break(): boolean
	publish()
	local taken = false
	for _, task in Antiban.breaks do
		if running_ms() > task.next then
			taken = true
			Antiban.take_break(task)
		end
	end
	return taken
end

function Antiban.do_sleep(): boolean
	publish()
	local taken = false
	for _, task in Antiban.sleeps do
		if running_ms() > task.next then
			taken = true
			Antiban.take_sleep(task)
		end
	end
	return taken
end

-- Whether a break or a sleep is due, so the next `do_antiban` would take it.
function Antiban.break_due(): boolean
	publish()
	local now = running_ms()
	for _, list in { Antiban.breaks, Antiban.sleeps } do
		for _, task in list do
			if now > task.next then
				return true
			end
		end
	end
	return false
end

function Antiban.do_antiban(check_tasks: boolean?, check_breaks: boolean?, check_sleeps: boolean?): boolean
	if Antiban.doing_antiban then
		return false
	end
	Antiban.doing_antiban = true
	local here = pause_clock()

	local done = false
	if check_tasks ~= false and Antiban.do_task() then
		done = true
	end
	if check_breaks ~= false and Antiban.do_break() then
		done = true
	end
	if check_sleeps ~= false and Antiban.do_sleep() then
		done = true
	end

	if not logged_in() then
		local ok = Login.sign_in()
		if not ok then
			Log.log("Antiban", `Log in failed`)
		end
	end

	Antiban.doing_antiban = false
	resume_clock(here)
	return done
end

function Antiban.do_walking_antiban(): boolean
	if Antiban.doing_antiban then
		return false
	end
	Antiban.doing_antiban = true
	local here = pause_clock()
	local done = Antiban.do_walk_task()
	Antiban.doing_antiban = false
	resume_clock(here)
	return done
end

function Antiban.time_until_break(task: Break): string
	return format_ms(math.max(0, task.next - running_ms()))
end

function Antiban.time_until_sleep(task: Sleep): string
	return format_ms(math.max(0, task.next - running_ms()))
end

function Antiban.simulate_breaks(botting_days: number?)
	local days = botting_days or 1000
	assert(#Antiban.breaks > 0, "add a break before simulating breaks")
	local copies: { Break } = {}
	for i, b in Antiban.breaks do
		copies[i] = table.clone(b)
	end

	local active, inactive, prev = 0, 0, 0
	while active + inactive < days * Antiban.DAY do
		local task = copies[1]
		for _, b in copies do
			if b.next < task.next then
				task = b
			end
		end

		local length = math.abs(Random.gauss(task.length, task.length * task.std_var))
		active += task.next - prev
		inactive += length

		for _, b in copies do
			b.next += length
		end

		prev = task.next
		task.next += around(task.interval, task.std_var)
	end

	inactive /= days
	active /= days
	Log.log("Antiban", `Running for {format_ms(active)} per day, on average.`)
end

return Antiban
