--!strict
local Host = require("../../../host")
type LoginLayout = Host.LoginLayout

local TitleScreen = {}

export type Button = {
	name: string,
	label: string,
	x1: number,
	y1: number,
	x2: number,
	y2: number,
	center_x: number,
	center_y: number,
}

type Base = "box_x" | "center_x"

type Spec = {
	base: Base,
	x1: number,
	x2: number,
	y1: number,
	y2: number,
	label: string,
}

type Screen = {
	name: string,
	buttons: { [string]: Spec },
}

TitleScreen.WELCOME = 0
TitleScreen.CREDENTIALS = 2
TitleScreen.INVALID_CREDENTIALS = 3
TitleScreen.ERROR = 9
TitleScreen.PLAY_NOW = 10
TitleScreen.SIGN_OUT = 11
TitleScreen.TERMS = 12
TitleScreen.DISCONNECTED = 24
TitleScreen.CONNECTION_ERROR = 39

local function spec(base: Base, x1: number, x2: number, y1: number, y2: number, label: string): Spec
	return { base = base, x1 = x1, x2 = x2, y1 = y1, y2 = y2, label = label }
end

local SCREENS: { [number]: Screen } = {
	[TitleScreen.WELCOME] = {
		name = "welcome",
		buttons = {
			new_user = spec("center_x", -155, -5, 100, 140, "New User"),
			existing_user = spec("center_x", 5, 155, 100, 140, "Existing User"),
		},
	},
	[TitleScreen.CREDENTIALS] = {
		name = "credentials",
		buttons = {
			username = spec("center_x", -180, 180, 70, 83, "Login:"),
			password = spec("center_x", -180, 180, 85, 98, "Password:"),
			login = spec("center_x", -155, -5, 130, 170, "Login"),
			cancel = spec("box_x", 185, 335, 130, 170, "Cancel"),
		},
	},
	[TitleScreen.INVALID_CREDENTIALS] = {
		name = "invalid credentials",
		buttons = {
			try_again = spec("box_x", 105, 255, 85, 125, "Try again"),
			forgotten_password = spec("box_x", 105, 255, 135, 175, "Forgotten password?"),
		},
	},
	[TitleScreen.ERROR] = {
		name = "error",
		buttons = {
			try_again = spec("box_x", 105, 255, 120, 160, "Try again"),
		},
	},
	[TitleScreen.PLAY_NOW] = {
		name = "play now",
		buttons = {
			play_now = spec("box_x", 71, 289, 38, 106, "Play Now"),
		},
	},
	[TitleScreen.SIGN_OUT] = {
		name = "sign out",
		buttons = {
			yes = spec("center_x", -155, -5, 100, 140, "Yes"),
			no = spec("center_x", 5, 155, 100, 140, "No"),
		},
	},
	[TitleScreen.TERMS] = {
		name = "terms",
		buttons = {
			accept = spec("center_x", -155, -5, 120, 160, "Accept"),
			decline = spec("center_x", 5, 155, 120, 160, "Decline"),
		},
	},
	[TitleScreen.DISCONNECTED] = {
		name = "disconnected",
		buttons = {
			try_again = spec("box_x", 105, 255, 120, 160, "Try again"),
		},
	},
	[TitleScreen.CONNECTION_ERROR] = {
		name = "connection error",
		buttons = {
			try_again = spec("center_x", -155, -5, 138, 178, "Try again"),
			back = spec("center_x", 5, 155, 138, 178, "Back"),
		},
	},
}

local function box(login: LoginLayout, name: string, button: Spec): Button
	local base = if button.base == "box_x" then login.box_x else login.center_x
	local scale = login.scale or 1
	local function px(v: number): number
		return math.floor(v * scale)
	end
	local x1, y1 = px(base + button.x1), px(login.y + button.y1)
	local x2, y2 = px(base + button.x2), px(login.y + button.y2)
	return {
		name = name,
		label = button.label,
		x1 = x1,
		y1 = y1,
		x2 = x2,
		y2 = y2,
		center_x = (x1 + x2) // 2,
		center_y = (y1 + y2) // 2,
	}
end

function TitleScreen.name(screen: number): string?
	local known: Screen? = SCREENS[screen]
	return known and known.name
end

function TitleScreen.buttons(login: LoginLayout): { [string]: Button }
	local buttons: { [string]: Button } = {}
	local known: Screen? = SCREENS[login.screen]
	if known then
		for name, button in pairs(known.buttons) do
			buttons[name] = box(login, name, button)
		end
	end
	return buttons
end

function TitleScreen.button(login: LoginLayout, name: string): Button?
	local known: Screen? = SCREENS[login.screen]
	local button: Spec? = known and known.buttons[name]
	if button == nil then
		return nil
	end
	return box(login, name, button)
end

return TitleScreen
