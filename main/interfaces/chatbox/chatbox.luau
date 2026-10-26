--!strict
local Host = require("../../../host")
local sub_interfaces = Host.sub_interfaces
local widget = Host.widget
local widget_children = Host.widget_children
local GameVal = require("../../../utils/game_val")

local Chatbox = {
	GROUP = 162,
	MODAL = 568,
	SKILLMULTI = 270,
	CHATMENU = 219,
	CHAT_LEFT = 231,
	CHAT_RIGHT = 217,
	MESSAGEBOX = 229,
	OBJECTBOX = 193,
	OBJECTBOX_DOUBLE = 11,
	LEVELUP_DISPLAY = 233,
	RECOMMEND_SURVEY = 709,
}

function Chatbox.interfaces(): { number }?
	local open = sub_interfaces()
	if open == nil then
		return nil
	end
	local groups: { number } = {}
	for _, s in ipairs(open) do
		-- the level up display isn't always in the chatbox slot, so it's read wherever it is
		if
			(s.parent_group == Chatbox.GROUP and s.parent_child == Chatbox.MODAL)
			or s.group == Chatbox.LEVELUP_DISPLAY
		then
			table.insert(groups, s.group)
		end
	end
	return groups
end

function Chatbox.interface(): number?
	local groups = Chatbox.interfaces()
	if groups == nil then
		return nil
	end
	return groups[1]
end

function Chatbox.interface_name(): string?
	local group = Chatbox.interface()
	if group == nil then
		return nil
	end
	return GameVal.interface(group)
end

function Chatbox.is_open(interface: number | string): boolean
	local groups = Chatbox.interfaces()
	if groups == nil then
		return false
	end
	for _, group in ipairs(groups) do
		if group == interface then
			return true
		end
		if type(interface) == "string" then
			local name = GameVal.interface(group)
			if name and string.lower(name) == string.lower(interface) then
				return true
			end
		end
	end
	return false
end

function Chatbox.text(): string?
	local groups = Chatbox.interfaces()
	if groups == nil then
		return nil
	end
	local lines: { string } = {}
	local function add(text: string?)
		if text and text ~= "" then
			table.insert(lines, text)
		end
	end
	for _, group in ipairs(groups) do
		local child = 0
		while true do
			local w = widget(group, child)
			if w == nil then
				break
			end
			if not w.hidden then
				add(w.text)
				for _, created in ipairs(widget_children(group, child) or {}) do
					if not created.hidden then
						add(created.text)
					end
				end
			end
			child += 1
		end
	end
	return table.concat(lines, "\n")
end

return Chatbox
