--!strict
local BankpinKeypad = require("../main/interfaces/mainscreen/bankpin_keypad")

-- The PIN is the account's, set in the loader; the script never sees it.
local open = BankpinKeypad.is_open()
if not open then
	print("the bank PIN keypad isn't open")
else
	print("bank PIN:", BankpinKeypad.enter())
end
