--!strict

local Host = require("@lib/host")
local bank_pin_enter = Host.bank_pin_enter
local Toplevel = require("@lib/main/interfaces/mainscreen/toplevel")

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

function BankpinKeypad.is_open(): boolean
	return Toplevel.is_open(BankpinKeypad.GROUP)
end

-- Types the logged in account's PIN entirely inside the injector, returning "entered", "closed", "no_pin", "unavailable", "locked", "wrong" or "failed".
function BankpinKeypad.enter(): string
	return bank_pin_enter()
end

return BankpinKeypad
