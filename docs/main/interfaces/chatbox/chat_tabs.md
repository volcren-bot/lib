# Main.Interfaces.Chatbox.ChatTabs

The buttons under the chat (All, Game, Public, Private, Channel, Clan, Trade): which one is open, switching between them, and the filter each one has (the "On", "Friends" or "Off" written under its name).

```luau
local ChatTabs = require("../main/interfaces/chatbox/chat_tabs")
```

Which tab is open comes from a game setting and the filters from the text under each tab's name, so nothing depends on the screen's colours. Filters are changed from the tab's right-click menu.

## Constants

Definition:
```luau
ChatTabs.NAMES = { "all", "game", "public", "private", "channel", "clan", "trade" }
```
The tabs, left to right.

## Types

Definition:
```luau
export type Tab = "all" | "game" | "public" | "private" | "channel" | "clan" | "trade"
export type State = "enabled" | "filtered" | "disabled" | "hide" | "autochat"
```
A tab, and a tab's filter: "enabled" shows everything ("On"), "filtered" only friends ("Friends", or "Filtered" for the game tab), "disabled" nothing ("Off"). Only the public tab has "hide" and "autochat".

## ChatTabs.active

Definition:
```luau
function ChatTabs.active(): (Tab | "none")?
```
The open tab, or "none" while the chatbox is hidden.

Example:
```luau
local ChatTabs = require("../main/interfaces/chatbox/chat_tabs")

print(ChatTabs.active())
```

## ChatTabs.is_active

Definition:
```luau
function ChatTabs.is_active(tab: Tab): boolean
```
True when `tab` is the open tab.

Example:
```luau
local ChatTabs = require("../main/interfaces/chatbox/chat_tabs")

print(ChatTabs.is_active("all"))
```

## ChatTabs.open

Definition:
```luau
function ChatTabs.open(tab: Tab): boolean
```
Clicks `tab` if it isn't the open one (this also shows a hidden chatbox) and waits for it to open.

Example:
```luau
local ChatTabs = require("../main/interfaces/chatbox/chat_tabs")

print(ChatTabs.open("game"))
```

## ChatTabs.open_async

Definition:
```luau
function ChatTabs.open_async(tab: Tab, force: boolean?): boolean
```
Like `ChatTabs.open`, but queues the click as async input and returns at once, without waiting for the tab to open. Returns `true` if the tab is active or the click was queued, `false` if the tab's button isn't there. `force` clicks even when the tab is active now, for a tab that an earlier queued input leaves.

Example:
```luau
local ChatTabs = require("../main/interfaces/chatbox/chat_tabs")

print(ChatTabs.open_async("game"))
```

## ChatTabs.state

Definition:
```luau
function ChatTabs.state(tab: Tab): State?
```
The tab's filter. The "all" tab has none, so it gives nil.

Example:
```luau
local ChatTabs = require("../main/interfaces/chatbox/chat_tabs")

for _, tab in ipairs(ChatTabs.NAMES) do
	print(tab, ChatTabs.state(tab))
end
```

## ChatTabs.set_state

Definition:
```luau
function ChatTabs.set_state(tab: Tab, state: State): boolean
```
Picks the option of the tab's right-click menu that sets its filter to `state`, and waits for the filter to change. The game tab only switches between "enabled" and "filtered", and only the public tab can be set to "hide" or "autochat"; anything else returns false.

Example:
```luau
local ChatTabs = require("../main/interfaces/chatbox/chat_tabs")

print(ChatTabs.set_state("public", "filtered"))
```
