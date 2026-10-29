--!strict
local Host = require("../../../host")
local widget_children = Host.widget_children
type Widget = Host.Widget
local BankpinKeypad = require("./bankpin_keypad")
local Inv = require("../inv")
local Mouse = require("../../../utils/input/mouse")
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
	-- the tab bar (child n is tab n) and the setting that holds the open tab (0 is the main tab)
	TABS_CHILD = 10,
	TAB_VARBIT = 4150,
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
	if BankpinKeypad.is_open() then
		-- the injector enters the account's saved PIN; an account without one leaves the keypad to the player
		local entered = BankpinKeypad.enter()
		if entered ~= "entered" and entered ~= "no_pin" then
			Log.log("Bankmain", `the bank PIN wasn't entered: {entered}`)
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

-- The open bank tab: 0 for the main tab (all items), 1 to 9 for the others. nil when it can't be read.
function Bankmain.tab(): number?
	return Host.varbit(Bankmain.TAB_VARBIT)
end

-- The button of a bank tab in the tab bar, nil when the bank is closed.
function Bankmain.tab_button(tab: number): Widget?
	for _, k in ipairs(widget_children(Bankmain.GROUP, Bankmain.TABS_CHILD) or {}) do
		if k.index == tab and not k.hidden then
			return k
		end
	end
	return nil
end

-- Opens a bank tab and waits for it to be open; open tab 0 to find any item by its bank slot. true when open.
function Bankmain.open_tab(tab: number, timeout_ms: number?): boolean
	if Bankmain.tab() == tab then
		return true
	end
	local button = Bankmain.tab_button(tab)
	if button == nil then
		return false
	end
	Mouse.click(button)
	local deadline = Host.time() + (timeout_ms or 2000)
	while Host.time() < deadline do
		if Bankmain.tab() == tab then
			return true
		end
		Host.sleep(100)
	end
	return Bankmain.tab() == tab
end

function Bankmain.close(key_probability: number?, timeout_ms: number?): boolean
	return Toplevel.close(Bankmain.GROUP, Bankmain.close_button, key_probability, timeout_ms)
end

return Bankmain
