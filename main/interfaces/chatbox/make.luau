--!strict
local Host = require("@lib/host")
local sleep = Host.sleep
local Chat = require("@lib/main/interfaces/chatbox/chat")
local Chatbox = require("@lib/main/interfaces/chatbox/chatbox")
local Geometry = require("@lib/utils/math/geometry")
local Interact = require("@lib/main/interact")
local Log = require("@lib/utils/log")
local Minimenu = require("@lib/main/interfaces/minimenu")
local Mouse = require("@lib/utils/input/mouse")
local Widgets = require("@lib/main/interfaces/widgets")
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
	if
		Widgets.wait_until(function()
			return Make.is_open() and #(Make.amounts() or {}) > 0
		end, timeout_ms or Make.SELECT_TIMEOUT)
	then
		return true
	end
	Log.log("Make", "the make menu never opened")
	return false
end

function Make.wait_closed(timeout_ms: number?): boolean
	if Widgets.wait_until(function()
		return not Make.is_open()
	end, timeout_ms or Make.SELECT_TIMEOUT) then
		return true
	end
	Log.log("Make", "the make menu is still open")
	return false
end

function Make.amounts(): { Amount }?
	if not Make.is_open() then
		return {}
	end
	local amounts: { Amount } = {}
	for _, child in ipairs(Make.AMOUNT_CHILDREN) do
		local w = Host.widget(Make.GROUP, child)
		if w and not w.hidden then
			local label: string? = nil
			local selected = false
			for _, k in ipairs(Host.widget_children(Make.GROUP, child) or {}) do
				if k.kind == 4 and k.text and k.text ~= "" then
					label = Chat.clean(k.text)
				elseif k.kind == 3 and not k.hidden then
					selected = true
				end
			end
			if label then
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
			if not Make.set_amount("All") then
				return false
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
		if not Interact.with(button.box, top.option, nil, false) then
			return false
		end
	end
	local expected = label
	if type(amount) == "number" then
		if not Chat.answer_query(Make.QUERY, tostring(amount)) then
			return false
		end
		expected = tostring(amount)
	end
	if Widgets.wait_until(function()
		return Make.amount() == expected
	end, Make.SELECT_TIMEOUT) then
		return true
	end
	Log.log("Make", `the quantity didn't change to "{expected}"`)
	return false
end

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
	if not Make.is_open() then
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
		if not Make.set_amount(amount) then
			return false
		end
	end
	local option = Make.option(name)
	if option == nil then
		return false
	end
	return (Interact.with(option.box, option.verb, option.name, false))
end

return Make
