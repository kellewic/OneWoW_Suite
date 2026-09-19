Player-facing chat commands for the OneWoW suite. Commands only work if that addon is **installed and enabled** (see [Manage Features](Getting-Started)).

Home **addon cards** show each feature's primary `/1w…` command. **Command Options** on Home lists Direct Deposit and Shopping List subcommands.

Debug and developer-only commands are omitted here.

## Hub (OneWoW)

| Command | What it does |
|---------|----------------|
| `/1w` | Toggle the OneWoW hub |

Re-open the feature picker anytime from **Settings → Manage Features** (link on the Home tab).

## Feature modules

| Feature | Command | What it does |
|---------|---------|----------------|
| [Bags](Bags) | `/1wbags` | Toggle the Bags UI |
| [Notes](Notes) | `/1wn` | Open Notes in the hub |
| [AltTracker](AltTracker) | `/1wat` | Open AltTracker in the hub |
| [Catalog](Catalog) | `/1wcat` | Open Catalog in the hub |
| [Trackers](Trackers) | `/1wt` | Open Trackers in the hub |
| [QoL](QoL) | `/1wqol` | Open QoL in the hub |
| [Shopping List](Shopping-List) | `/1wsl` | Toggle the shopping-list window |
| [Mail](Mail) | `/1wmail` | Toggle the Mail UI. At a mailbox on WoW UI, switches back to One UI. |
| [Direct Deposit](Direct-Deposit) | `/1wdd` | Toggle the Direct Deposit window |
| Direct Deposit | `/1wdd deposit` | Start a manual deposit |
| Direct Deposit | `/1wdd pause` or `stop` | Stop an in-progress deposit |

## Utilities

| Feature | Command | What it does |
|---------|---------|----------------|
| [DevTools](DevTool) | `/1wdt` | Toggle the DevTools window. `notice` resets and shows the install notice. |
| [DevTools](DevTool) | `/1wdev` | Toggle DEVMODE (floating error list; Copy All dumps this session) |

### Shopping List extras

| Args | Effect |
|------|--------|
| *(none)* | Toggle the window |
| `show` / `hide` | Show or hide |
| `help` | Print help |
| `add <itemID>` | Add that item to the active list (quantity 1) |
| `farm` / `farming` | Open the Farming tab |

## QoL module shortcuts

These require **QoL** loaded. Some only exist while that module is enabled.

| Command | Module | What it does |
|---------|--------|----------------|
| `/1wbb` | Bag Bar | Toggle the Bag Bar module on or off |
| `/1wcopytext` `/1wct` | Copy Text | Capture UI text under the cursor into the copy dialog (only while CopyText is enabled) |

## Related

* [Getting started](Getting-Started)
* [Install](Install)
* [Release notes](Release-Notes)
* [Bags search syntax](Bags-Search-Syntax) — expressions used in Bags search (and related suite search UIs), not slash commands

### Sources

* [suitecommands.md](https://github.com/kellewic/OneWoW_Suite/blob/main/suitecommands.md) — full slash command inventory (including debug)
* [OneWoW/UI/t-home.lua](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW/UI/t-home.lua) — Home addon cards + Command Options
