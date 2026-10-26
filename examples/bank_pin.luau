--!strict
local Host = require("../host")
local form = Host.form
local BankpinKeypad = require("../main/interfaces/mainscreen/bankpin_keypad")

local open = BankpinKeypad.is_open()
if not open then
	print("the bank PIN keypad isn't open")
else
	local values = form({
		title = "Bank PIN",
		submit = "Enter",
		fields = { { id = "pin", kind = "text", label = "PIN", default = "" } },
	})
	if values == nil then
		print("cancelled")
	else
		print("entered:", BankpinKeypad.enter(tostring(values.pin)))
	end
end
