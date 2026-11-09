--!strict
local Prayer = require("@lib/main/interfaces/gametabs/prayer")

local points, level = Prayer.points()
print(`prayer points: {points}/{level}`)
assert(Prayer.activate({ "Thick Skin", "Burst of Strength" }), "couldn't activate the prayers")
for _, p in ipairs(Prayer.active()) do
	print("active:", p.name)
end
assert(Prayer.deactivate_all(), "couldn't deactivate the prayers")
print("any active:", Prayer.is_any_active())

local before = Prayer.quick_prayers()
assert(Prayer.set_quick_prayers({ "Thick Skin", "Burst of Strength" }), "couldn't set the quick prayers")
assert(Prayer.set_quick_active(true), "couldn't turn the quick prayers on")
print("quick prayers on:", Prayer.is_quick_active())
assert(Prayer.set_quick_active(false), "couldn't turn the quick prayers off")
Prayer.set_quick_prayers(before)
