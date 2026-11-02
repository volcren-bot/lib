--!strict
-- Takes the best transport toward the Edgeville bank, one leg at a time, then walks the last stretch: a teleport, a ship
-- or a lever pull where one saves walking. Needs a logged-in client, and the loader for the transport data (a bare
-- `injector run` has none and only walks).
local Host = require("@lib/host")
local Player = require("@lib/main/player")
local Transports = require("@lib/main/transports")
local Walker = require("@lib/main/walker")

local BANK = { x = 3097, y = 3496, plane = 0 }
local LEGS = 10

local function there(p: { x: number, y: number, plane: number }): boolean
	return p.plane == BANK.plane and math.abs(p.x - BANK.x) <= 4 and math.abs(p.y - BANK.y) <= 4
end

local function where(): string
	local p = Player.position()
	return p == nil and "nowhere" or `{p.x}, {p.y} plane {p.plane}`
end

local data = Host.transports()
if data == nil or #data.transports == 0 then
	print("no transport data (run this through the loader): only walking is possible")
end

for leg = 1, LEGS do
	local p = Player.position()
	if p == nil then
		error("no player position: log in first")
	end
	if there(p) then
		break
	end

	local used, failed = Transports.travel(p, BANK)
	print(
		`leg {leg} from {p.x}, {p.y}: {if used
			then "took a transport"
			else if failed then "a transport failed" else "walking"}`
	)
	if used then
		Transports.settle(p)
	elseif failed then
		-- a failed transport is left out of the next plan, so plan again from here
		continue
	else
		break
	end
end

if not there(Player.position() or BANK) and not Walker.walk_tile(BANK, 60_000) then
	error(`no route to the Edgeville bank from {where()}`)
end
print(`at the Edgeville bank ({where()})`)
