--!strict
local Host = require("../host")
local game_state = Host.game_state
local sleep = Host.sleep
local Draw = require("../utils/draw")
local TitleScreen = require("../main/interfaces/login/titlescreen")
local WelcomeScreen = require("../main/interfaces/login/welcome_screen")

local function box(x1: number, y1: number, x2: number, y2: number, label: string)
	Draw.rect(x1, y1, x2, y2, Draw.GREEN)
	print(string.format("  %s: (%d, %d)-(%d, %d)", label, x1, y1, x2, y2))
end

local last: string? = nil
while true do
	local state = game_state()

	local key: string
	local draw: () -> ()
	local login = state.login
	if login ~= nil then
		key = string.format("login %d %d %d", login.screen, login.box_x, login.y)
		draw = function()
			print(string.format("login screen %d (%s)", login.screen, TitleScreen.name(login.screen) or "unknown"))
			for _, b in pairs(TitleScreen.buttons(login)) do
				box(b.x1, b.y1, b.x2, b.y2, b.label)
			end
		end
	elseif WelcomeScreen.is_open(state) then
		local button = WelcomeScreen.play_button()
		key = if button then string.format("lobby %d %d", button.x, button.y) else "lobby ?"
		draw = function()
			print("lobby")
			if button then
				box(button.x, button.y, button.x + button.width - 1, button.y + button.height - 1, "CLICK HERE TO PLAY")
			else
				print("  play button not found")
			end
		end
	else
		key = "none"
		draw = function()
			print("not on the login screen or in the lobby")
		end
	end

	if key ~= last then
		last = key
		-- the screen's buttons in one overlay update
		Draw.batch(function()
			Draw.clear()
			draw()
		end)
	end
	sleep(1000)
end
