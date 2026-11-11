--!strict
local Host = require("@lib/host")
type InventoryLayout = Host.InventoryLayout
type InventoryLayoutSlot = Host.InventoryLayoutSlot
type LayoutItem = Host.LayoutItem
local BankPouch = require("@lib/main/interfaces/mainscreen/bankpouch")
local Bankmain = require("@lib/main/interfaces/mainscreen/bankmain")
local Inv = require("@lib/main/interfaces/inv")
local Inventory = require("@lib/main/interfaces/gametabs/inventory")
local Item = require("@lib/utils/item")
local LayoutItems = require("@lib/main/layout_item")
local Log = require("@lib/utils/log")
local Runepouch = require("@lib/main/interfaces/mainscreen/runepouch")
local Widgets = require("@lib/main/interfaces/widgets")

local InventoryLayout = {}

export type Layout = InventoryLayout
export type Slot = InventoryLayoutSlot
export type Rune = LayoutItem

export type Entry = {
	items: { Item.Item },
	stackable: boolean,
	min: number,
	max: number,
	copies: number,
	label: string,
}

InventoryLayout.SIZE = 28
InventoryLayout.POUCH_TIMEOUT_MS = 2500
InventoryLayout.POLL_MS = 50

function InventoryLayout.from_client(name: string?): Layout?
	local items = Inventory.items()
	if items == nil then
		return nil
	end
	local slots: { Slot } = {}
	for _, s in ipairs(items) do
		if s.id ~= -1 then
			local stackable = s.quantity > 1
			local amount = if stackable then s.quantity else 1
			table.insert(slots, {
				slot = s.slot,
				id = s.id,
				ids = { s.id },
				name = s.name or "",
				stackable = stackable,
				min = amount,
				max = amount,
				locked = false,
			})
		end
	end
	local pouch: { Rune }? = nil
	local held = if Runepouch.held() then Runepouch.runes() else nil
	if held then
		local runes: { Rune } = {}
		for _, rune in ipairs(held) do
			table.insert(runes, {
				id = rune.id,
				ids = { rune.id },
				name = rune.name,
				stackable = true,
				min = rune.quantity,
				max = rune.quantity,
				locked = false,
			})
		end
		pouch = runes
	end
	return { name = name or "From client", slots = slots, pouch = pouch }
end

function InventoryLayout.entries(layout: Layout): { Entry }
	local by_key: { [string]: Entry } = {}
	local list: { Entry } = {}
	for _, slot in ipairs(layout.slots) do
		local items = LayoutItems.items(slot)
		local parts: { string } = {}
		for i, item in ipairs(items) do
			parts[i] = tostring(item)
		end
		local key = (if slot.stackable then "stack:" else "copies:") .. table.concat(parts, ",")
		local entry = by_key[key]
		if entry == nil then
			entry = {
				items = items,
				stackable = slot.stackable,
				min = slot.min,
				max = slot.max,
				copies = 0,
				label = if slot.name ~= "" then slot.name else `item {slot.id}`,
			}
			by_key[key] = entry
			table.insert(list, entry)
		end
		entry.copies += 1
	end
	return list
end

local function pouch_missing(layout: Layout): { [number]: number }?
	local missing: { [number]: number } = {}
	if layout.pouch == nil then
		return missing
	end
	local held = Runepouch.runes()
	if held == nil then
		return nil
	end
	local have: { [number]: number } = {}
	for _, rune in ipairs(held) do
		have[rune.id] = rune.quantity
	end
	for _, rune in ipairs(layout.pouch :: { Rune }) do
		local need = LayoutItems.top_up(rune, have[rune.id] or 0)
		if need then
			missing[rune.id] = need
		end
	end
	return missing
end

local function entry_matches(entry: Entry): boolean?
	if entry.stackable then
		local have = Inventory.count_ex(entry.items)
		return if have == nil then nil else LayoutItems.in_range(entry, have)
	end
	local have = Inventory.count(entry.items)
	return if have == nil then nil else have >= entry.copies
end

function InventoryLayout.matches(layout: Layout): boolean?
	for _, entry in ipairs(InventoryLayout.entries(layout)) do
		local ok = entry_matches(entry)
		if ok ~= true then
			return ok
		end
	end
	local missing = pouch_missing(layout)
	if missing == nil then
		return nil
	end
	return next(missing) == nil
end

local function deposit_extra(entry: Entry): boolean
	if entry.stackable then
		local extra = LayoutItems.excess(entry, Inventory.count_ex(entry.items) or 0)
		return extra == 0 or Bankmain.deposit(entry.items, extra)
	end
	local extra = (Inventory.count(entry.items) or 0) - entry.copies
	for i = #entry.items, 1, -1 do
		if extra <= 0 then
			break
		end
		local held = Inventory.count(entry.items[i]) or 0
		if held > 0 then
			if not Bankmain.deposit(entry.items[i], math.min(held, extra)) then
				return false
			end
			extra = (Inventory.count(entry.items) or 0) - entry.copies
		end
	end
	return true
end

function InventoryLayout.deposit_diff(layout: Layout): boolean
	if not Bankmain.is_open() then
		Log.log("InventoryLayout", "deposit_diff: the bank isn't open")
		return false
	end
	local entries = InventoryLayout.entries(layout)
	local keep: { Item.Item } = {}
	for _, entry in ipairs(entries) do
		for _, item in ipairs(entry.items) do
			table.insert(keep, item)
		end
	end
	if #keep == 0 then
		return Bankmain.deposit_inventory()
	end
	if not Bankmain.deposit_different(keep) then
		return false
	end
	for _, entry in ipairs(entries) do
		if not deposit_extra(entry) then
			return false
		end
	end
	return true
end

local function take(entry: Entry, buttons: boolean): boolean
	if entry.stackable then
		local amount = LayoutItems.top_up(entry, Inventory.count_ex(entry.items) or 0)
		return amount == nil or Bankmain.withdraw(entry.items, amount, false, buttons)
	end
	local need = entry.copies - (Inventory.count(entry.items) or 0)
	for _, item in ipairs(entry.items) do
		if need <= 0 then
			break
		end
		local stock = Bankmain.count_ex(item) or 0
		if stock > 0 then
			if not Bankmain.withdraw(item, math.min(need, stock), false, buttons) then
				return false
			end
			need = entry.copies - (Inventory.count(entry.items) or 0)
		end
	end
	return need <= 0
end

local function custom_amount(entry: Entry): number?
	local amount: number?
	if entry.stackable then
		amount = LayoutItems.top_up(entry, Inventory.count_ex(entry.items) or 0)
	else
		amount = entry.copies - (Inventory.count(entry.items) or 0)
	end
	if amount == nil or amount <= 0 or Bankmain.quantity_of(amount) ~= "CUSTOM" then
		return nil
	end
	return if amount < (Bankmain.count_ex(entry.items) or 0) then amount else nil
end

local function withdraw_plan(entries: { Entry }): { { entry: Entry, shared: boolean } }
	local amounts: { [number]: number } = {}
	local uses: { [number]: number } = {}
	for i, entry in ipairs(entries) do
		local amount = custom_amount(entry)
		if amount then
			amounts[i] = amount
			uses[amount] = (uses[amount] or 0) + 1
		end
	end
	local groups: { { number } } = {}
	local group_of: { [number]: number } = {}
	local rest: { number } = {}
	for i in ipairs(entries) do
		local amount = amounts[i]
		if amount and uses[amount] > 1 then
			if group_of[amount] == nil then
				table.insert(groups, {})
				group_of[amount] = #groups
			end
			table.insert(groups[group_of[amount]], i)
		else
			table.insert(rest, i)
		end
	end
	local plan: { { entry: Entry, shared: boolean } } = {}
	for _, group in ipairs(groups) do
		for _, i in ipairs(group) do
			table.insert(plan, { entry = entries[i], shared = true })
		end
	end
	for _, i in ipairs(rest) do
		table.insert(plan, { entry = entries[i], shared = false })
	end
	return plan
end

local function missing(entry: Entry): boolean
	if entry.stackable then
		return LayoutItems.top_up(entry, Inventory.count_ex(entry.items) or 0) ~= nil
	end
	return entry.copies > (Inventory.count(entry.items) or 0)
end

local function fills_with_click(entry: Entry): boolean
	if entry.stackable or Bankmain.notes() ~= false then
		return false
	end
	local free = InventoryLayout.SIZE - (Inventory.count_used() or InventoryLayout.SIZE)
	local need = entry.copies - (Inventory.count(entry.items) or 0)
	local selected = Bankmain.selected_amount()
	return free > 0
		and need >= free
		and selected ~= nil
		and selected >= free
		and (Bankmain.count_ex(entry.items) or 0) >= free
end

local function pouch_slot(layout: Layout): Slot?
	for _, slot in ipairs(layout.slots) do
		if table.find(Runepouch.POUCHES, slot.name) then
			return slot
		end
	end
	return nil
end

local function fill_pouch(layout: Layout): boolean
	local missing = pouch_missing(layout)
	if missing == nil then
		return false
	end
	if next(missing) == nil then
		return true
	end
	if not Runepouch.held() then
		local pouch = pouch_slot(layout)
		if pouch == nil or not Bankmain.withdraw(pouch.id, 1, false) then
			Log.log(
				"InventoryLayout",
				"withdraw: the layout has runes for a pouch, but no pouch is in the inventory or the bank"
			)
			return false
		end
	end
	if not BankPouch.open() then
		Log.log("InventoryLayout", "withdraw: couldn't open the rune pouch in the bank")
		return false
	end
	for id, need in pairs(missing) do
		if not BankPouch.withdraw(id, need) then
			BankPouch.close()
			return false
		end
	end
	local filled = Widgets.wait_within(function(): boolean
		local left = pouch_missing(layout)
		return left ~= nil and next(left) == nil
	end, InventoryLayout.POUCH_TIMEOUT_MS, InventoryLayout.POLL_MS)
	if not BankPouch.close() then
		return false
	end
	if not filled then
		Log.log("InventoryLayout", "withdraw: the pouch didn't take every rune")
	end
	return filled
end

function InventoryLayout.withdraw(layout: Layout): boolean
	if not Bankmain.is_open() then
		Log.log("InventoryLayout", "withdraw: the bank isn't open")
		return false
	end
	if not BankPouch.close() then
		return false
	end
	if InventoryLayout.matches(layout) then
		return true
	end
	if (Inventory.count_used() or 0) > 0 and not InventoryLayout.deposit_diff(layout) then
		return false
	end
	if not fill_pouch(layout) then
		return false
	end
	local plan = withdraw_plan(InventoryLayout.entries(layout))
	local last = 0
	for i, step in ipairs(plan) do
		if missing(step.entry) then
			last = i
		end
	end
	for i, step in ipairs(plan) do
		if i == last and fills_with_click(step.entry) then
			if not Bankmain.withdraw_selected(step.entry.items) then
				Log.log("InventoryLayout", `withdraw: couldn't take {step.entry.label}`)
				return false
			end
			continue
		end
		local amount = custom_amount(step.entry)
		local buttons = step.shared or amount == nil or Bankmain.custom_quantity() == amount
		if not take(step.entry, buttons) then
			Log.log("InventoryLayout", `withdraw: couldn't take {step.entry.label}`)
			return false
		end
	end
	return InventoryLayout.matches(layout) == true
end

function InventoryLayout.reorder(layout: Layout): boolean
	local by_slot: { [number]: Slot } = {}
	for _, slot in ipairs(layout.slots) do
		by_slot[slot.slot] = slot
	end
	for destination = 0, InventoryLayout.SIZE - 1 do
		local wanted = by_slot[destination]
		if wanted == nil then
			continue
		end
		local held = Inventory.items()
		if held == nil then
			return false
		end
		local at_slot: { [number]: Inv.Slot } = {}
		for _, s in ipairs(held) do
			at_slot[s.slot] = s
		end
		local function settled(at: number): boolean
			local here, now = by_slot[at], at_slot[at]
			return here ~= nil and now ~= nil and LayoutItems.counts_as(here, now.id, now.name)
		end
		if settled(destination) then
			continue
		end
		local from: number? = nil
		for _, at in ipairs(Inventory.indices_of(LayoutItems.items(wanted)) or {}) do
			if at ~= destination and not settled(at) then
				from = at
				break
			end
		end
		if from == nil then
			Log.log("InventoryLayout", `reorder: nothing to put in slot {destination} ({wanted.name})`)
			return false
		end
		if not Inventory.move_slot(from, destination) then
			return false
		end
	end
	return true
end

return InventoryLayout
