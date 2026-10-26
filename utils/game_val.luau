--!strict
local Host = require("../host")
local game_val_name = Host.game_val_name
local game_val_names = Host.game_val_names

local GameVal = {
	OBJ = 0,
	NPC = 1,
	INV = 2,
	VARP = 3,
	VARBIT = 4,
	LOC = 6,
	SEQ = 7,
	SPOT = 8,
	ROW = 9,
	TABLE = 10,
	JINGLE = 11,
	SPRITE = 12,
	INTERFACE = 14,
	VARC = 15,
}

function GameVal.name(kind: number, id: number): string?
	return game_val_name(kind, id)
end

function GameVal.names(kind: number, ids: { number }): { string? }?
	return game_val_names(kind, ids)
end

function GameVal.interface(group: number): string?
	return game_val_name(GameVal.INTERFACE, group)
end

return GameVal
