--!strict
-- Prints the instance flag, source map chunks and position whenever the instance changes; stops after RUN_MS.
local Host = require("../host")
local Player = require("../main/player")

local RUN_MS = 30 * 60 * 1000
local POLL_MS = 500

local function describe(): string
	local flag = Host.in_instance()
	local chunks = Player.instance_chunks()
	local sources = {}
	for _, chunk in ipairs(chunks or {}) do
		table.insert(sources, `{chunk.x},{chunk.y} (id {chunk:id()})`)
	end
	return `flag={flag} in_instance={Player.in_instance()} instance_id={Player.instance_id()} `
		.. `sources=[{table.concat(sources, "; ")}]`
end

local started = Host.time()
local last = ""
while Host.time() - started < RUN_MS do
	if Player.is_logged_in() then
		local now = describe()
		if now ~= last then
			last = now
			local pos = Player.position()
			print(`{now} at {if pos then `({pos.x}, {pos.y})` else "(no position)"}`)
		end
	end
	Host.sleep(POLL_MS)
end
