--!strict
local Position = {}
Position.__index = Position

local Chunk = {}
Chunk.__index = Chunk

export type Chunk = typeof(setmetatable({} :: { x: number, y: number }, Chunk))
export type Position = typeof(setmetatable(
	{} :: { local_x: number, local_y: number, x: number, y: number, plane: number },
	Position
))

function Chunk.id(self: Chunk): number
	return bit32.bor(bit32.lshift(self.x, 8), self.y)
end

local function new_chunk(x: number, y: number): Chunk
	return setmetatable({ x = x, y = y }, Chunk)
end

function Chunk.new(x: number, y: number): Chunk
	return new_chunk(x, y)
end

function Position.new(local_x: number, local_y: number, x: number, y: number, plane: number?): Position
	return setmetatable({ local_x = local_x, local_y = local_y, x = x, y = y, plane = plane or 0 }, Position)
end

function Position.chunk(self: Position): Chunk
	return new_chunk(bit32.rshift(self.x, 6), bit32.rshift(self.y, 6))
end

-- the game allocates instances in the map east of this x, the overworld never reaches it
local INSTANCE_MIN_X = 6400

function Position.in_instance(self: Position): boolean
	return self.x >= INSTANCE_MIN_X
end

Position.Chunk = Chunk

return Position
