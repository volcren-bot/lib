--!strict
-- Readers for two kinds of file in the client's cache: compiled CS2 scripts (cache index 12) and database rows (index 2, archive 38).
-- Both are bytes as `Host.cache_file` returns them. A reader returns nil when the bytes aren't shaped as expected, so a changed format fails safe.
local Cs2 = {}

export type Instruction = { op: number, value: number | string }

export type Script = {
	instructions: { Instruction },
	-- the switch tables, each key -> jump (a switch at instruction `i` continues at instruction `i + 1 + jump`)
	tables: { { [number]: number } },
}

-- opcodes this module names (the others are read for their operands only)
Cs2.PUSH_INT = 0
Cs2.GET_VARP = 1
Cs2.RETURN = 21
Cs2.GET_VARBIT = 25
Cs2.GOSUB = 40
Cs2.SWITCH = 60
Cs2.DB_GETFIELD = 7502

local function read(bytes: string): () -> Script?
	return function(): Script?
		local n = #bytes
		if n < 20 then
			return nil
		end
		-- the file ends with the size of the switch tables; before them is a 16 byte footer of counts
		local tables_size = string.unpack(">I2", bytes, n - 1)
		local header = n - 2 - tables_size - 16
		if header < 1 then
			return nil
		end
		local count = string.unpack(">i4", bytes, header + 1)
		local p = header + 1 + 4 + 12
		local table_count = string.byte(bytes, p)
		p += 1
		local tables: { { [number]: number } } = {}
		for _ = 1, table_count do
			local size = string.unpack(">I2", bytes, p)
			p += 2
			local t: { [number]: number } = {}
			for _ = 1, size do
				local key, jump = string.unpack(">i4i4", bytes, p)
				p += 8
				t[key] = jump
			end
			table.insert(tables, t)
		end
		-- the instructions follow the script's name (a zero-ended string)
		local q = string.find(bytes, "\0", 1, true)
		if q == nil then
			return nil
		end
		q += 1
		local instructions: { Instruction } = {}
		while q <= header do
			local op = string.unpack(">I2", bytes, q)
			q += 2
			local value: number | string
			if op == 3 then
				local e = string.find(bytes, "\0", q, true)
				if e == nil then
					return nil
				end
				value = string.sub(bytes, q, e - 1)
				q = e + 1
			elseif op == 21 or op == 38 or op == 39 or op == 62 or op == 63 then
				value = string.byte(bytes, q)
				q += 1
			elseif op == 61 then
				value = 0
				q += 8
			elseif op <= 100 then
				value = string.unpack(">i4", bytes, q)
				q += 4
			else
				value = string.byte(bytes, q)
				q += 1
			end
			table.insert(instructions, { op = op, value = value })
		end
		if #instructions ~= count then
			return nil
		end
		return { instructions = instructions, tables = tables }
	end
end

-- A compiled script's instructions and switch tables, or nil when the bytes aren't a script.
function Cs2.script(bytes: string): Script?
	local ok, result = pcall(read(bytes))
	if ok then
		return result
	end
	return nil
end

export type Column = { types: { number }, values: { { number | string } } }

-- The type of a string column; every other type is a 4 byte integer.
Cs2.STRING_TYPE = 36

-- A database row's columns by column number, or nil when the bytes aren't a row. Each column has the type of each of its fields and its values (a list of tuples).
function Cs2.dbrow(bytes: string): { [number]: Column }?
	local ok, result = pcall(function(): { [number]: Column }?
		local columns: { [number]: Column } = {}
		local p = 1
		while true do
			local op = string.byte(bytes, p)
			if op == nil then
				return nil
			end
			p += 1
			if op == 0 then
				return columns
			elseif op == 4 then
				-- the table's number
				p += 1
			elseif op == 3 then
				-- the column count, then each column until 255
				p += 1
				while true do
					local c = string.byte(bytes, p)
					if c == nil then
						return nil
					end
					p += 1
					if c == 255 then
						break
					end
					local type_count = string.byte(bytes, p)
					p += 1
					local types: { number } = {}
					for i = 1, type_count do
						types[i] = string.byte(bytes, p)
						p += 1
					end
					local tuples = string.byte(bytes, p)
					p += 1
					local values: { { number | string } } = {}
					for t = 1, tuples do
						local tuple: { number | string } = {}
						for i = 1, type_count do
							if types[i] == Cs2.STRING_TYPE then
								local e = string.find(bytes, "\0", p, true)
								if e == nil then
									return nil
								end
								tuple[i] = string.sub(bytes, p, e - 1)
								p = e + 1
							else
								tuple[i] = string.unpack(">i4", bytes, p)
								p += 4
							end
						end
						values[t] = tuple
					end
					columns[c] = { types = types, values = values }
				end
			else
				return nil
			end
		end
	end)
	if ok then
		return result
	end
	return nil
end

return Cs2
