--!strict
local Host = require("@lib/host")
local Log = {}

local function timestamp(): string
	local ms = math.floor(Host.time())
	return string.format("%02d:%02d:%02d:%03d", ms // 3600000, ms // 60000 % 60, ms // 1000 % 60, ms % 1000)
end

local function line(tag: string, ...: any): string
	local parts = { `[{tag}][{timestamp()}]:` }
	for i = 1, select("#", ...) do
		table.insert(parts, tostring((select(i, ...))))
	end
	return table.concat(parts, " ")
end

function Log.log(tag: string, ...: any)
	print(line(tag, ...))
end

function Log.warn(tag: string, ...: any)
	local text = line(tag, ...)
	if Host.report_warning == nil then
		print(text)
		return
	end
	Host.report_warning(text)
end

export type Row = { label: string, value: string? }

function Log.duration(ms: number): string
	local sec = math.floor(ms / 1000)
	return string.format("%d:%02d:%02d", sec // 3600, sec // 60 % 60, sec % 60)
end

function Log.per_hour(count: number, ms: number): number
	if ms <= 0 then
		return 0
	end
	return count * 3600000 / ms
end

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
