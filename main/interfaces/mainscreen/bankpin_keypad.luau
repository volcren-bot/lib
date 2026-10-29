--!strict

local Host = require("../../../host")
local bank_pin_enter = Host.bank_pin_enter
local Toplevel = require("./toplevel")

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

-- Types the logged in account's PIN, which the injector asks the loader for, entirely inside the injector: no PIN or digit reaches the script. One of
-- "entered", "closed" (the keypad isn't open), "no_pin" (none saved for this account), "unavailable", "locked", "wrong" or "failed".
function BankpinKeypad.enter(): string
	return bank_pin_enter()
end

return BankpinKeypad
