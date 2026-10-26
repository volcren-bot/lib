--!strict
-- Walks the dialogue of each NPC in NAMES, cycling through the options with key and click alternately, printing every step.
local NAMES = { "Captain Pudi", "Gita Prymes", "Mr McGroot", "Aggy", "Rocky", "Phoenix", "Taiman" }
local MAX_MENUS = 12

local Host = require("../host")
local ChatOptions = require("../main/interfaces/chatbox/chat_options")
local Npcs = require("../main/entities/npcs")
local Walker = require("../main/walker")

local function talk(name: string): boolean
	local npc = Npcs.nearest(name, assert(Walker.position()))
	if npc == nil then
		print(`[tour] no {name} around`)
		return false
	end
	print(`[tour] talking to {name} ({npc.index})`)
	if not Npcs.interact(npc, "Talk-to") then
		print(`[tour] Talk-to failed for {name}`)
		return false
	end
	for _ = 1, 40 do
		if ChatOptions.contains_continue() or #(ChatOptions.get() or {}) > 0 then
			return true
		end
		Host.sleep(100)
	end
	print(`[tour] {name} didn't open a dialogue`)
	return false
end

local total = 0
-- an option menu left open from before would be picked by the first talk, so close it
local left = 0
while ChatOptions.contains_continue() or #(ChatOptions.get() or {}) > 0 do
	left += 1
	local options = ChatOptions.get() or {}
	if #options > 0 then
		ChatOptions.select(options[#options].text, true, 1)
	else
		ChatOptions.continue_chat()
	end
	if left > 30 then
		break
	end
end
for _, name in ipairs(NAMES) do
	if talk(name) then
		local menus = 0
		local steps = 0
		while steps < 60 do
			steps += 1
			local options = ChatOptions.get() or {}
			if #options > 0 then
				menus += 1
				print(
					`[tour] menu {menus} title="{ChatOptions.title()}" is_title={ChatOptions.is_title(
						"Select an option"
					)}`
				)
				for _, o in ipairs(options) do
					print(`    {o.index} key={o.key} "{o.text}"`)
				end
				local pick = options[(menus - 1) % #options + 1]
				local by_key = menus % 2 == 0
				local ok = ChatOptions.select(pick.text, true, if by_key then 1 else 0)
				print(`[tour] picked {pick.index} "{pick.text}" by {if by_key then "key" else "click"}: {ok}`)
				if not ok then
					break
				end
				if menus >= MAX_MENUS then
					break
				end
			elseif ChatOptions.contains_continue() then
				local speech = ChatOptions.speech()
				print(`[tour] continue {if speech then `{speech.name}: {speech.text}` else "(no speech box)"}`)
				if not ChatOptions.continue_chat() then
					print("[tour] continue failed")
					break
				end
			else
				break
			end
		end
		print(
			`[tour] {name}: {menus} menu(s), dialogue open after: {ChatOptions.contains_continue() or #(ChatOptions.get() or {}) > 0}`
		)
		total += menus
	end
	-- close whatever is left, so the next NPC starts from a clean chatbox
	while ChatOptions.contains_continue() do
		if not ChatOptions.continue_chat() then
			break
		end
	end
	Host.sleep(600)
end
print(`[tour] done, {total} menu(s) in total`)
