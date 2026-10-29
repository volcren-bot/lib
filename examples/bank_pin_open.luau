--!strict
-- Opens the nearest bank and lets the injector enter the account's saved bank PIN if the keypad shows up.
-- Run it from the loader with the account saved on the Accounts page (it needs the loader to answer the PIN request).
local NAME = "Bank booth"
local OPTION = "Bank"
local TIMEOUT_MS = 20000

local Host = require("../host")
local sleep = Host.sleep
local time = Host.time
local Bankmain = require("../main/interfaces/mainscreen/bankmain")
local BankpinKeypad = require("../main/interfaces/mainscreen/bankpin_keypad")
local Objects = require("../main/entities/objects")
local Walker = require("../main/walker")

if Bankmain.is_open() then
	print("the bank is already open")
	return
end

local me = assert(Walker.position())
local booth = Objects.nearest(NAME, me)
if booth == nil then
	print(`no {NAME} around`)
	return
end
print(`{booth.name} is {Objects.distance(booth, me)} tiles away`)
if not Objects.interact(booth, OPTION) then
	print(`couldn't {OPTION} {booth.name}`)
	return
end

local started = time()
local entered: string? = nil
while time() - started < TIMEOUT_MS do
	-- The injector asks the loader for the logged in account's PIN and clicks the digits itself; the script only sees how it went.
	if BankpinKeypad.is_open() then
		if entered == nil then
			print("the PIN keypad is open")
		end
		entered = BankpinKeypad.enter()
		print(`bank PIN: {entered}`)
		if entered ~= "entered" then
			print(
				if entered == "no_pin"
					then "no saved PIN for this account (or the loader is too old to be asked): save it on the Accounts page"
					else "stopping"
			)
			return
		end
	end
	if Bankmain.is_open() then
		print(if entered then "the bank is open, PIN accepted" else "the bank is open, no PIN was asked for")
		return
	end
	sleep(600)
end
print(if entered then "the PIN went in but the bank never opened" else "the bank never opened")
