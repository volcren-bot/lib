--!strict
local Draw = require("@lib/utils/draw")
local Host = require("@lib/host")

local NPC_ID = 2042
local ANIMATION = 5069
local OFFSET = { x = 4, y = 0 }
local ORIENTATION = 1536
local FRAME_MS = 60
local RUN_MS = 60 * 1000
local PAUSE_MS = 600

local COLOR = Draw.color(0, 255, 120)

local function show(model: Host.NpcModel, label: string)
	local segments: { { { x: number, y: number } } } = {}
	for _, face in ipairs(model.faces) do
		table.insert(segments, { face[1], face[2] })
		table.insert(segments, { face[2], face[3] })
		table.insert(segments, { face[3], face[1] })
	end
	Draw.batch(function()
		Draw.clear()
		Draw.lines(segments :: any, COLOR)
		local top = model.hull[1]
		if top then
			Draw.text(label, top.x, top.y - 18, 12, Draw.WHITE)
		end
	end)
end

local started = Host.time()
local shown_frames = false
while Host.time() - started < RUN_MS do
	local pos = Host.game_state().position
	if pos == nil then
		Draw.clear()
		Host.sleep(500)
		continue
	end
	local fine_x, fine_y = pos.local_x + OFFSET.x * 128, pos.local_y + OFFSET.y * 128
	local frame, frames = 0, 1
	while frame < frames do
		local model = Host.npc_type_model(NPC_ID, ANIMATION, frame, fine_x, fine_y, ORIENTATION)
		if model == nil then
			print(`NPC {NPC_ID} has no model`)
			Draw.clear()
			return
		end
		frames = model.frame_count
		if not shown_frames then
			shown_frames = true
			print(
				`NPC {NPC_ID}, animation {ANIMATION}: {frames} frames, {model.vertex_count} vertices, {#model.faces} faces drawn`
			)
		end
		show(model, `NPC {NPC_ID} animation {ANIMATION} frame {frame + 1}/{frames}`)
		frame += 1
		Host.sleep(FRAME_MS)
	end
	Host.sleep(PAUSE_MS)
end
Draw.clear()
