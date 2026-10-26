--!strict
-- Read only: dumps every open interface's text while a level up shows.
local Host = require("../host")

local function scan(tag: string)
	local open = Host.sub_interfaces() or {}
	print(tag, "open:", #open)
	for _, si in ipairs(open) do
		local group = si.group
		for child = 0, 15 do
			local w = Host.widget(group, child)
			if w and not w.hidden and w.text and w.text ~= "" then
				print(`  {group}:{child} parent={si.parent_group}:{si.parent_child} text="{w.text}"`)
			end
			for _, k in ipairs(Host.widget_children(group, child) or {}) do
				if not k.hidden and k.text and k.text ~= "" then
					print(`    {group}:{child}.{k.index} text="{k.text}"`)
				end
			end
		end
	end
end

local last_continue = ""
local function has_continue(): boolean
	for _, si in ipairs(Host.sub_interfaces() or {}) do
		if si.group == 231 or si.group == 217 then
			continue
		end
		for child = 0, 15 do
			local w = Host.widget(si.group, child)
			if w and string.find(w.text or "", "Click here to continue", 1, true) then
				return true
			end
			for _, k in ipairs(Host.widget_children(si.group, child) or {}) do
				if string.find(k.text or "", "Click here to continue", 1, true) then
					return true
				end
			end
		end
	end
	return false
end

local since = -1
for _, m in ipairs(Host.chat_messages() or {}) do
	since = math.max(since, m.uid)
end
print("watching after uid", since)
while true do
	for _, m in ipairs(Host.chat_messages() or {}) do
		if m.uid > since then
			since = m.uid
			print(`[{m.time_utc}] chat kind={m.kind} {m.text}`)
			if string.find(m.text, "Congratulations", 1, true) then
				print("LEVEL UP chat message")
				scan("chat-dump")
			end
		end
	end
	local key = if has_continue() then "shown" else ""
	if key ~= "" and key ~= last_continue then
		print("CONTINUE on screen")
		scan("continue-dump")
	end
	last_continue = key
	Host.sleep(250)
end
