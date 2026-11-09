--!strict
local Host = require("@lib/host")
local game_state = Host.game_state
local widget = Host.widget
local varc = Host.varc
local sleep = Host.sleep
type Widget = Host.Widget
local Biometrics = require("@lib/main/antiban/biometrics")
local GameState = require("@lib/main/game_state")
local GameVal = require("@lib/utils/game_val")
local Keyboard = require("@lib/utils/input/keyboard")
local Log = require("@lib/utils/log")
local Mouse = require("@lib/utils/input/mouse")
local Random = require("@lib/utils/math/random")

local SidePanels = {}

SidePanels.VARC = 171
SidePanels.KEY_CHANCE = 0.9

SidePanels.COMBAT_INTERFACE = 0
SidePanels.STATS = 1
SidePanels.SIDE_JOURNAL = 2
SidePanels.INVENTORY = 3
SidePanels.WORNITEMS = 4
SidePanels.PRAYERBOOK = 5
SidePanels.MAGIC_SPELLBOOK = 6
SidePanels.SIDE_CHANNELS = 7
SidePanels.ACCOUNT = 8
SidePanels.FRIENDS = 9
SidePanels.LOGOUT = 10
SidePanels.SETTINGS_SIDE = 11
SidePanels.EMOTE = 12
SidePanels.MUSIC = 13

local NAMES: { [number]: string } = {
	[0] = "combat_interface",
	[1] = "stats",
	[2] = "side_journal",
	[3] = "inventory",
	[4] = "wornitems",
	[5] = "prayerbook",
	[6] = "magic_spellbook",
	[7] = "side_channels",
	[8] = "account",
	[9] = "friends",
	[10] = "logout",
	[11] = "settings_side",
	[12] = "emote",
	[13] = "music",
}

local STONES: { [number]: { [number]: number } } = {
	[161] = { [0] = 59, 60, 61, 62, 63, 64, 65, 43, 44, 45, 46, 47, 48, 49 },
}

local KEY_VARBITS: { [number]: { name: string, hint: number } } = {
	[0] = { name = "stone_combat_key", hint = 4675 },
	[1] = { name = "stone_stats_key", hint = 4676 },
	[2] = { name = "stone_journal_key", hint = 4677 },
	[3] = { name = "stone_inv_key", hint = 4678 },
	[4] = { name = "stone_worn_key", hint = 4679 },
	[5] = { name = "stone_prayer_key", hint = 4680 },
	[6] = { name = "stone_magic_key", hint = 4682 },
	[7] = { name = "stone_clanchat_key", hint = 4683 },
	[8] = { name = "stone_account_key", hint = 6517 },
	[9] = { name = "stone_friends_key", hint = 4684 },
	[10] = { name = "stone_logout_key", hint = 4689 },
	[11] = { name = "stone_options1_key", hint = 4686 },
	[12] = { name = "stone_options2_key", hint = 4687 },
	[13] = { name = "stone_music_key", hint = 4688 },
}

local KEY_ESCAPE = 13
local F_KEYS: { number } = {
	Keyboard.keys.F1,
	Keyboard.keys.F2,
	Keyboard.keys.F3,
	Keyboard.keys.F4,
	Keyboard.keys.F5,
	Keyboard.keys.F6,
	Keyboard.keys.F7,
	Keyboard.keys.F8,
	Keyboard.keys.F9,
	Keyboard.keys.F10,
	Keyboard.keys.F11,
	Keyboard.keys.F12,
}
local KEY_VARBIT_SCAN = 20000

local key_varbit_ids: { [number]: number }? = nil
local keys: { [number]: number | false } = {}

local POLL_MS = 100
local DEFAULT_TIMEOUT_MS = 1800

function SidePanels.name(tab: number): string?
	return NAMES[tab]
end

function SidePanels.resolve(tab: number | string): number?
	if type(tab) == "number" and NAMES[tab] then
		return tab
	end
	if type(tab) == "string" then
		local wanted = string.lower(tab)
		for id, name in pairs(NAMES) do
			if name == wanted then
				return id
			end
		end
	end
	Log.log("SidePanels", "unknown side panel: " .. tostring(tab))
	return nil
end

function SidePanels.current(): number?
	return varc(SidePanels.VARC)
end

function SidePanels.is_open(tab: number | string): boolean
	local id = SidePanels.resolve(tab)
	if id == nil then
		return false
	end
	return SidePanels.current() == id
end

function SidePanels.button(tab: number | string): Widget?
	local id = SidePanels.resolve(tab)
	if id == nil then
		return nil
	end
	local state = game_state()
	local root = state.root_interface
	if state.game_state ~= GameState.LOGGED_IN or root == nil then
		return nil
	end
	local stones: { [number]: number }? = STONES[root]
	if stones == nil then
		return nil
	end
	return (widget(root, stones[id]))
end

local function resolve_key_varbits(): { [number]: number }
	local tabs: { number } = {}
	local hints: { number } = {}
	for tab, entry in KEY_VARBITS do
		tabs[#tabs + 1] = tab
		hints[#hints + 1] = entry.hint
	end
	local found: { [number]: number } = {}
	local names = GameVal.names(GameVal.VARBIT, hints)
	local missing = false
	for i, tab in tabs do
		if names ~= nil and names[i] == KEY_VARBITS[tab].name then
			found[tab] = hints[i]
		else
			missing = true
		end
	end
	if not missing then
		return found
	end

	local ids: { number } = {}
	for i = 0, KEY_VARBIT_SCAN do
		ids[i + 1] = i
	end
	local all = GameVal.names(GameVal.VARBIT, ids)
	if all == nil then
		return found
	end
	local by_name = {}
	for i, name in all do
		by_name[name] = ids[i]
	end
	for tab, entry in KEY_VARBITS do
		found[tab] = by_name[entry.name]
	end
	return found
end

local function key_varbit(id: number): number?
	if key_varbit_ids == nil then
		key_varbit_ids = resolve_key_varbits()
	end
	return (key_varbit_ids :: { [number]: number })[id]
end

function SidePanels.key(tab: number | string): number?
	local id = SidePanels.resolve(tab)
	if id == nil then
		return nil
	end
	local cached = keys[id]
	if cached == false then
		return nil
	elseif cached ~= nil then
		return cached
	end
	local varbit_id = key_varbit(id)
	if varbit_id == nil then
		return nil
	end
	local value = Host.varbit(varbit_id)
	if value == nil then
		return nil
	end
	local key: number? = nil
	if value == KEY_ESCAPE then
		key = Keyboard.keys.ESCAPE
	elseif value > 0 then
		key = F_KEYS[value]
	end
	keys[id] = if key == nil then false else key
	return key
end

local function key_chance(key: number, key_probability: number?): number
	return key_probability
		or if key == Keyboard.keys.ESCAPE
			then Biometrics.get_probability(Biometrics.ESCAPE)
			else Biometrics.random_double(SidePanels.KEY_CHANCE)
end

local function no_button(id: number)
	Log.log("SidePanels", "the " .. NAMES[id] .. " tab's button isn't available")
end

local function wait_open(id: number, timeout_ms: number): boolean
	local waited = 0
	while waited < timeout_ms do
		sleep(POLL_MS)
		waited += POLL_MS
		if SidePanels.is_open(id) then
			return true
		end
	end
	return false
end

function SidePanels.open(tab: number | string, key_probability: number?, timeout_ms: number?): boolean
	local id = SidePanels.resolve(tab)
	if id == nil then
		return false
	end
	if SidePanels.is_open(id) then
		return true
	end

	local timeout = timeout_ms or DEFAULT_TIMEOUT_MS
	local key = SidePanels.key(id)
	if key ~= nil and Random.chance(key_chance(key, key_probability)) then
		Keyboard.key_press(key)
		if wait_open(id, timeout) then
			return true
		end
	end

	for _ = 1, 3 do
		local button = SidePanels.button(id)
		if button == nil then
			no_button(id)
			return false
		end
		Mouse.click(button)
		if wait_open(id, timeout) then
			return true
		end
	end
	Log.log("SidePanels", "the " .. NAMES[id] .. " tab didn't open within " .. tostring(timeout) .. " ms")
	return false
end

function SidePanels.open_async(tab: number | string, key_probability: number?, force: boolean?): boolean
	local id = SidePanels.resolve(tab)
	if id == nil then
		return false
	end
	if not force and SidePanels.is_open(id) then
		return true
	end

	local key = SidePanels.key(id)
	if key ~= nil and Random.chance(key_chance(key, key_probability)) then
		Keyboard.key_press_async(key)
		return true
	end

	local button = SidePanels.button(id)
	if button == nil then
		no_button(id)
		return false
	end
	return Mouse.click_async(button)
end

return SidePanels
