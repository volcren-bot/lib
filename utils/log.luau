--!strict
local Host = require("../host")
local Log = {}

local function timestamp(): string
	local ms = math.floor(Host.time())
	return string.format("%02d:%02d:%02d:%03d", ms // 3600000, ms // 60000 % 60, ms // 1000 % 60, ms % 1000)
end

-- prints `[tag][hh:mm:ss:ms]: ...`
function Log.log(tag: string, ...: any)
	local parts = { `[{tag}][{timestamp()}]:` }
	for i = 1, select("#", ...) do
		table.insert(parts, tostring((select(i, ...))))
	end
	print(table.concat(parts, " "))
end

-- one row of a block: a label and its value, or a `section` heading when value is nil
export type Row = { label: string, value: string? }

-- `h:mm:ss` for a duration in milliseconds
function Log.duration(ms: number): string
	local sec = math.floor(ms / 1000)
	return string.format("%d:%02d:%02d", sec // 3600, sec // 60 % 60, sec % 60)
end

-- `count` per hour over `ms` milliseconds, 0 before any time passed
function Log.per_hour(count: number, ms: number): number
	if ms <= 0 then
		return 0
	end
	return count * 3600000 / ms
end

-- 1234567.8 -> "1,234,568"; keeps one decimal below 100
function Log.number(n: number): string
	local text = if math.abs(n) < 100 and n ~= math.floor(n)
		then string.format("%.1f", n)
		else string.format("%d", math.floor(n + 0.5))
	local sign, int, rest = string.match(text, "^(-?)(%d+)(.*)$")
	if sign == nil or int == nil or rest == nil then
		return text
	end
	int = string.reverse((string.gsub(string.reverse(int), "(%d%d%d)", "%1,")))
	if string.sub(int, 1, 1) == "," then
		int = string.sub(int, 2)
	end
	return sign .. int .. rest
end

-- prints one multi-line entry: the `[tag][time]:` title, then aligned rows (a row without a value is a heading)
function Log.block(tag: string, title: string, rows: { Row })
	local width = 0
	for _, row in ipairs(rows) do
		if row.value ~= nil then
			width = math.max(width, #row.label)
		end
	end
	local lines = { `[{tag}][{timestamp()}]: {title}` }
	for _, row in ipairs(rows) do
		if row.value == nil then
			table.insert(lines, `  {row.label}`)
		else
			table.insert(lines, `    {row.label}{string.rep(" ", width - #row.label)}  {row.value}`)
		end
	end
	print(table.concat(lines, "\n"))
end

return Log
