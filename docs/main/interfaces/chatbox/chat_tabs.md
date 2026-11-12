# Main.Interfaces.Chatbox.ChatTabs

The tabs under the chat (All, Game, Public, Private, Channel, Clan, Trade): which is open, switching, and each tab's filter. The open tab comes from a client variable and filters from the text under each tab; filters are changed through the tab's right-click menu.

```luau
local ChatTabs = require("@lib/main/interfaces/chatbox/chat_tabs")
```

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
A tab and its filter: "enabled" ("On"), "filtered" ("Friends", or "Filtered" on the game tab), "disabled" ("Off"). Only the public tab has "hide" and "autochat".

## ChatTabs.active

Definition:
```luau
function ChatTabs.active(): (Tab | "none")?
```
The open tab, or "none" while the chatbox is hidden.

Example:
```luau
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
print(ChatTabs.is_active("all"))
```

## ChatTabs.open

Definition:
```luau
function ChatTabs.open(tab: Tab): boolean
```
Clicks `tab` if it isn't open (this also shows a hidden chatbox) and waits up to 1.5 seconds for it.

Example:
```luau
print(ChatTabs.open("game"))
```

## ChatTabs.open_async

Definition:
```luau
function ChatTabs.open_async(tab: Tab, force: boolean?): boolean
```
Queues the click as async input and returns at once. `true` when the tab is active or the click was queued, `false` when the button is missing. `force` clicks even if the tab is active now, for when earlier queued input will leave it.

Example:
```luau
print(ChatTabs.open_async("game"))
```

## ChatTabs.state

Definition:
```luau
function ChatTabs.state(tab: Tab): State?
```
The tab's filter; `nil` for "all", which has none, or for unreadable text.

Example:
```luau
for _, tab in ipairs(ChatTabs.NAMES) do
	print(tab, ChatTabs.state(tab))
end
```

## ChatTabs.set_state

Definition:
```luau
function ChatTabs.set_state(tab: Tab, state: State): boolean
```
Picks the right-click option that sets the filter to `state` and waits up to 1.5 seconds for it. The game tab only takes "enabled" or "filtered" and only the public tab takes "hide" or "autochat"; anything else returns `false`.

Example:
```luau
print(ChatTabs.set_state("public", "filtered"))
```
