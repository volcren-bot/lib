--!strict
local Host = require("../../../host")
local sleep = Host.sleep
local Chat = require("./chat")
local Chatbox = require("./chatbox")
local Geometry = require("../../../utils/math/geometry")
local Interact = require("../../interact")
local Log = require("../../../utils/log")
local Minimenu = require("../minimenu")
local Mouse = require("../../../utils/input/mouse")
type Widget = Host.Widget
type MenuEntry = Host.MenuEntry
type Box = Geometry.Box

local Make = {
	GROUP = Chatbox.SKILLMULTI,
	AMOUNT_CHILDREN = { 7, 8, 9, 10, 11, 12 },
	QUERY = "Enter amount",
	HOVER_TIMEOUT = 600,
	SELECT_TIMEOUT = 1500,
}

export type Option = {
	verb: string,
	name: string,
	id: number,
	child: number,
	box: Box,
}

export type Amount = {
	label: string,
	id: number,
	box: Box,
	selected: boolean,
}

export type AmountArg = string | number

local function box_of(w: Widget): Box
	return { x1 = w.x, y1 = w.y, x2 = w.x + w.width, y2 = w.y + w.height }
end

local function component_id(child: number): number
	return Make.GROUP * 65536 + child
end

local function hover(box: Box, id: number): MenuEntry?
	Mouse.move(box, true)
	local waited = 0
	while true do
		local entries = Minimenu.entries()
		if entries == nil then
			return nil
		end
		local top = entries[1]
		if top and top.id == id then
			return top
		end
		if waited >= Make.HOVER_TIMEOUT then
			Log.log("Make", `the menu never showed component {id}`)
			return nil
		end
		sleep(50)
		waited += 50
	end
end

local function text_of(w: Widget): string?
	local found: string? = nil
	for _, child in ipairs(Host.widget_children(Make.GROUP, w.child) or {}) do
		if child.kind == 4 and child.text and child.text ~= "" then
			found = Chat.clean(child.text)
		end
	end
	return found
end

local function has_visible_model(child: number): boolean
	for _, k in ipairs(Host.widget_children(Make.GROUP, child) or {}) do
		if k.kind == 6 and not k.hidden then
			return true
		end
	end
	return false
end

function Make.is_open(): boolean
	return Chatbox.is_open(Make.GROUP)
end

function Make.wait_open(timeout_ms: number?): boolean
	local waited = 0
	local timeout = timeout_ms or Make.SELECT_TIMEOUT
	while true do
		local open = Make.is_open()
		if open == nil then
			return false
		end
		if open then
			return true
		end
		if waited >= timeout then
			Log.log("Make", "the make menu never opened")
			return false
		end
		sleep(50)
		waited += 50
	end
end

function Make.wait_closed(timeout_ms: number?): boolean
	local waited = 0
	local timeout = timeout_ms or Make.SELECT_TIMEOUT
	while true do
		local open = Make.is_open()
		if open == nil then
			return false
		end
		if not open then
			return true
		end
		if waited >= timeout then
			Log.log("Make", "the make menu is still open")
			return false
		end
		sleep(50)
		waited += 50
	end
end

function Make.amounts(): { Amount }?
	local open = Make.is_open()
	if open == nil then
		return nil
	end
	if not open then
		return {}
	end
	local amounts: { Amount } = {}
	for _, child in ipairs(Make.AMOUNT_CHILDREN) do
		local w = Host.widget(Make.GROUP, child)
		if w and not w.hidden then
			local label = text_of(w)
			if label then
				local selected = false
				for _, k in ipairs(Host.widget_children(Make.GROUP, child) or {}) do
					if k.kind == 3 and not k.hidden then
						selected = true
					end
				end
				table.insert(amounts, {
					label = label,
					id = component_id(child),
					box = box_of(w),
					selected = selected,
				})
			end
		end
	end
	return amounts
end

function Make.amount(): string?
	local amounts = Make.amounts()
	if amounts == nil then
		return nil
	end
	for _, a in ipairs(amounts) do
		if a.selected then
			return a.label
		end
	end
	return nil
end

function Make.set_amount(amount: AmountArg): boolean
	local label = if type(amount) == "number" then "X" else amount
	local amounts = Make.amounts()
	if amounts == nil then
		return false
	end
	local button: Amount? = nil
	for _, a in ipairs(amounts) do
		if a.label == label then
			button = a
		end
	end
	if button == nil then
		if type(amount) == "number" and label == "X" then
			local all = Make.set_amount("All")
			if not all then
				return all
			end
			return Make.set_amount(amount)
		end
		return false
	end
	if type(amount) == "number" and button.selected then
		return false
	end
	if not button.selected then
		local top = hover(button.box, button.id)
		if top == nil then
			return false
		end
		local clicked = Interact.with(button.box, top.option, nil, false)
		if not clicked then
			return clicked
		end
	end
	local expected = label
	if type(amount) == "number" then
		local answered = Chat.answer_query(Make.QUERY, tostring(amount))
		if not answered then
			return answered
		end
		expected = tostring(amount)
	end
	local waited = 0
	while true do
		local current = Make.amount()
		if current == expected then
			return true
		end
		if waited >= Make.SELECT_TIMEOUT then
			Log.log("Make", `the quantity didn't change to "{expected}"`)
			return false
		end
		sleep(50)
		waited += 50
	end
end

-- Queues the click on an amount button and returns at once, without checking the menu or the result; "X" needs `set_amount`. `force` clicks even when it is selected now.
function Make.set_amount_async(label: string, force: boolean?): boolean
	local amounts = Make.amounts()
	if amounts == nil then
		return false
	end
	for _, a in ipairs(amounts) do
		if a.label == label then
			if a.selected and not force then
				return true
			end
			return Mouse.click_async(a.box)
		end
	end
	return false
end

function Make.options(): { Option }?
	local open = Make.is_open()
	if open == nil then
		return nil
	end
	if not open then
		return {}
	end
	local options: { Option } = {}
	local child = 0
	while true do
		local w = Host.widget(Make.GROUP, child)
		if w == nil then
			break
		end
		if not w.hidden and has_visible_model(child) then
			local id = component_id(child)
			local box = box_of(w)
			local top = hover(box, id)
			if top == nil then
				return nil
			end
			table.insert(options, {
				verb = top.option,
				name = Chat.clean(top.target),
				id = id,
				child = child,
				box = box,
			})
		end
		child += 1
	end
	return options
end

function Make.option(name: string): Option?
	local options = Make.options()
	if options == nil then
		return nil
	end
	local wanted = string.lower(name)
	for _, option in ipairs(options) do
		if string.lower(option.name) == wanted then
			return option
		end
	end
	return nil
end

function Make.make(name: string, amount: AmountArg?): boolean
	if amount ~= nil then
		local set = Make.set_amount(amount)
		if not set then
			return set
		end
	end
	local option = Make.option(name)
	if option == nil then
		return false
	end
	local clicked = Interact.with(option.box, option.verb, option.name, false)
	return clicked
end

return Make
