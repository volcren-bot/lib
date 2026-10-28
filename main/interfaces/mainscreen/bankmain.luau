--!strict
local Host = require("../../../host")
local widget_children = Host.widget_children
type Widget = Host.Widget
local BankpinKeypad = require("./bankpin_keypad")
local Inv = require("../inv")
local Log = require("../../../utils/log")
local Toplevel = require("./toplevel")

local CONTAINER = 95
-- The frame the close button is in, and the button's index in it (like the deposit box's frame).
local FRAME_CHILD = 2
local CLOSE_INDEX = 11
local CLOSE_MAX_SIZE = 40
local items = Inv.new(CONTAINER)

local Bankmain = {
	CONTAINER = CONTAINER,
	GROUP = 12,
	pin = nil :: string?,
	slots = items.slots,
	items = items.items,
	indices_of = items.indices_of,
	index_of = items.index_of,
	find = items.find,
	contains = items.contains,
	contains_any = items.contains_any,
	contains_all = items.contains_all,
	count = items.count,
	count_ex = items.count_ex,
	wait_count = items.wait_count,
}

function Bankmain.is_open(): boolean
	local pin = Bankmain.pin
	if pin ~= nil and BankpinKeypad.is_open() then
		if not BankpinKeypad.wait_loading(3000) then
			Log.log("Bankmain", "the bank PIN buttons didn't load within 3 seconds")
			return false
		end
		local entered = BankpinKeypad.enter(pin)
		if not entered then
			return false
		end
	end
	return Toplevel.is_open(Bankmain.GROUP)
end

-- The bank's close button, nil if it isn't where the frame keeps it (or doesn't look like a button).
function Bankmain.close_button(): Widget?
	local kids = widget_children(Bankmain.GROUP, FRAME_CHILD)
	if kids == nil then
		return nil
	end
	for _, k in ipairs(kids) do
		if k.index == CLOSE_INDEX then
			if k.hidden or k.width > CLOSE_MAX_SIZE or k.height > CLOSE_MAX_SIZE then
				return nil
			end
			return k
		end
	end
	return nil
end

function Bankmain.close(key_probability: number?, timeout_ms: number?): boolean
	return Toplevel.close(Bankmain.GROUP, Bankmain.close_button, key_probability, timeout_ms)
end

return Bankmain
