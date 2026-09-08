**OneWoW DevTools** is an optional **developer inspector**. It is for addon work, UI poking, and troubleshooting — not required to play.

**Requires:** [OneWoW](Home) core. Enable **DevTools** under [Manage Features](Getting-Started) (it sits in the utility group, not the regular feature list).

**Open:** `/1wdt` (see [Slash commands](Slash-Commands))

The window is resizable. Size and position are remembered. It **closes when you enter combat**.

---

## Who it is for

* Addon authors who need to inspect frames, events, or Lua errors
* UI tinkerers browsing textures, fonts, and colors
* Anyone chasing a conflict or a Lua error

If you only want Bags, QoL, and the rest of the player suite, leave DevTools off.

---

## What you can do

Tabs, in order: **Frame**, **Events**, **Errors**, **Monitor**, **Globals**, **Textures**, **Fonts**, **Sounds**, **Colors**, **Layout**, **Editor**, **Settings**.

### Frame

Pick a frame under the cursor, walk the parent/child tree, search by name, and copy details. Combat secrets (12.0+) are masked when they cannot be read.

### Events

Start, pause, and filter a live event log. Optional firehose (all events — noisy).

### Errors

Session Lua errors with stack traces and copy. Optional DEVMODE floating list (`/1wdev`) with **Copy All** for every distinct error this session (same button on the Errors tab). If **!BugGrabber** is installed, the same captures show here. When this session has an error, the DevTools icon on Home and in the OneWoW collector row turns red. Click it to open this tab.

### Monitor

Per-addon memory and optional CPU / engine-profiler columns.

### Globals

Browse globals, `Enum` tables, and addon data. Bookmarks and copy helpers. Secrets stay masked.

### Textures, Fonts, Sounds, Colors, Layout

Browse atlases, font objects, sounds, color pickers, and an on-screen grid. On Textures, double-click a sheet region to collect names and copy the whole list at once.

### Editor

In-game Lua snippets. **Run** executes addon-level Lua — only run code you understand.

### Settings

Theme, language (all 11 suite locales), and minimap button.

---

## Tips

* Enable it only when you need it. It is a utility, not part of the default player set.
* The window will not stay open in combat.
* Errors and frame details are safer to copy from here than from chat spam.
* A red DevTools icon means this session has an error. Click it to open Errors. Clearing the log turns the icon gold again.

## Related

* [Getting started](Getting-Started)
* [Slash commands](Slash-Commands)
* [Developers](Developers)

### Sources

* [OneWoW_Utility_DevTool/README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_Utility_DevTool/README.md)
* [suitecommands.md](https://github.com/kellewic/OneWoW_Suite/blob/main/suitecommands.md)
