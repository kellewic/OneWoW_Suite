# OneWoW Suite — In-Game Slash Commands

Inventory of every chat slash command registered by OneWoW load units.
Scanned from `SLASH_*` assignments, `SlashCmdList[...]` handlers, and
`OneWoW_GUI.DB:RegisterSlashCommand(...)` calls (excluding `Libs/` and
`.wow_docs/`).

**Last audited:** 2026-09-19

> When you add, rename, or remove a slash command (or a subcommand), update
> this file in the same change. See **Keeping this file current** at the bottom.
>
> **Player-facing suite set:** Home addon cards + Command Options
> (`OneWoW/UI/t-home.lua`) and wiki `Slash-Commands` — one `/1w…` command per
> feature. QoL module shortcuts (BagBar, CopyText) are separate. Debug/dev
> commands stay inventory-only.

---

## Quick index

| Addon / unit | Aliases |
|---|---|
| OneWoW (core) | `/1w` · debug: `/1wtrace` · `/1wlocale` · `/1wpetooltip` · `/1wsc` · `/1wpunch` `/1wpunchlist` |
| OneWoW_Notes | `/1wn` |
| OneWoW_AltTracker | `/1wat` |
| OneWoW_Catalog | `/1wcat` |
| OneWoW_Trackers | `/1wt` |
| OneWoW_QoL | `/1wqol` · BagBar: `/1wbb` · CopyText: `/1wcopytext` `/1wct` |
| OneWoW_DirectDeposit | `/1wdd` (`deposit` / `pause` / `stop`) |
| OneWoW_ShoppingList | `/1wsl` (`show` / `hide` / `add` / `farm` / `help`) |
| OneWoW_Mail | `/1wmail` · debug: `/1wmailtrace` |
| OneWoW_Bags | `/1wbags` · debug: `/1wbprof` `/1wblayout` `/1wboverlay` |
| OneWoW_Utility_DevTool | `/1wdt` · `/1wdev` |

Load units with **no** slash commands: `OneWoW_AltTracker_*` and
`OneWoW_CatDB_*` data packs.

---

## OneWoW (core)

**Source:** `OneWoW/OneWoW.lua`, `OneWoW/Core/Lifecycle.lua`,
`OneWoW/Services/LocaleService.lua`,
`OneWoW/Services/PredicateEngine.lua`, `OneWoW/Services/SearchCatalog.lua`,
`OneWoW/Services/CollectiblesPunchLists.lua`

| Command | Kind | Description |
|---|---|---|
| `/1w` | User | Toggle the OneWoW hub window |
| `/1wtrace` | Debug | Lifecycle trace ring buffer |
| `/1wlocale` | Debug | Print locale coverage report to chat |
| `/1wpetooltip` | Debug | Dump PredicateEngine tooltip debug for hovered / cursor / linked item |
| `/1wsc` | Debug | Search catalog: reference lint, registered sources, former-name prune |
| `/1wpunch` `/1wpunchlist` | Debug | Collectibles punch-list dump |

### `/1wsc` subcommands

Named for the **search** catalog (`#token`, `SAVED(...)`, `CATEGORY(...)`), not
the OneWoW_Catalog addon — that one owns `/1wcat`.

| Args | Effect |
|---|---|
| `lint` | List broken, stale, and rule-less references |
| `sources` | List registered expression stores and how many expressions each sees |
| `prune` | Show which former names are no longer referenced (dry run) |
| `prune apply` | Actually remove them |
| `prune apply force` | Ignore the not-loaded-addon safety gate |
| _(none / other)_ | Print usage |

### `/1wtrace` subcommands

| Args | Effect |
|---|---|
| `on` | Enable recording (clears ring); `/reload` to capture startup |
| `off` | Disable recording (`dump` still works) |
| `clear` / `reset` | Clear ring |
| `dump` | Print ring to chat |
| _(none / other)_ | Print usage |

### `/1wpetooltip` args

Pass nothing (uses hovered bag slot / tooltip item / cursor item), or an
`itemID` / item link.

---

## OneWoW_Notes

**Source:** `OneWoW_Notes/OneWoW_Notes.lua` via `DB:RegisterSlashCommand`

| Command | Kind | Description |
|---|---|---|
| `/1wn` | User | Open Notes in the OneWoW hub |

---

## OneWoW_AltTracker

**Source:** `OneWoW_AltTracker/OneWoW_AltTracker.lua` via `DB:RegisterSlashCommand`

| Command | Kind | Description |
|---|---|---|
| `/1wat` | User | Open AltTracker in the OneWoW hub |

---

## OneWoW_Catalog

**Source:** `OneWoW_Catalog/OneWoW_Catalog.lua` via `DB:RegisterSlashCommand`

| Command | Kind | Description |
|---|---|---|
| `/1wcat` | User | Open Catalog in the OneWoW hub |

---

## OneWoW_Trackers

**Source:** `OneWoW_Trackers/OneWoW_Trackers.lua` via `DB:RegisterSlashCommand`

| Command | Kind | Description |
|---|---|---|
| `/1wt` | User | Open Trackers in the OneWoW hub |

---

## OneWoW_QoL

**Source:** `OneWoW_QoL/OneWoW_QoL.lua`, plus module files under
`OneWoW_QoL/Modules/external/`

### Hub

| Command | Kind | Description |
|---|---|---|
| `/1wqol` | User | Open QoL in the OneWoW hub |

### Module: BagBar (`bagbar/bagbar.lua`)

Registered at file load (always available once QoL is loaded).

| Command | Kind | Description |
|---|---|---|
| `/1wbb` | User | Toggle the BagBar module on/off |

### Module: CopyText (`copytext/copytext.lua`)

Registered only while the CopyText module is **enabled**; cleared on disable.

| Command | Kind | Description |
|---|---|---|
| `/1wcopytext` `/1wct` | User | Capture UI text under the cursor into the copy dialog |

---

## OneWoW_DirectDeposit

**Source:** `OneWoW_DirectDeposit/OneWoW_DirectDeposit.lua`

| Command | Kind | Description |
|---|---|---|
| `/1wdd` | User | Toggle Direct Deposit window; `deposit` starts a manual run; `pause` / `stop` cancel |

### `/1wdd` subcommands

| Args | Effect |
|---|---|
| _(none)_ | Toggle Direct Deposit window |
| `deposit` | Start manual deposit |
| `pause` / `stop` | Stop an in-progress deposit |

---

## OneWoW_ShoppingList

**Source:** `OneWoW_ShoppingList/OneWoW_ShoppingList.lua`

| Command | Kind | Description |
|---|---|---|
| `/1wsl` | User | Toggle shopping-list window (default) |

### Subcommands

| Args | Effect |
|---|---|
| `help` | Print command help |
| `show` | Show window |
| `hide` | Hide window |
| `add <itemID>` | Add item to the active list (qty 1) |
| `farm` / `farming` | Open the Farming tab |
| _(none)_ | Toggle window |

---

## OneWoW_Mail

**Source:** `OneWoW_Mail/OneWoW_Mail.lua`, `Engine/MailTrace.lua`

| Command | Kind | Description |
|---|---|---|
| `/1wmail` | User | Toggle the OneWoW Mail UI shell. At a mailbox on WoW UI, switches back to One UI. |
| `/1wmailtrace` | Debug | Mail send/shipment pipeline debug ring (on by default, ring 2048, session-only) |

### `/1wmailtrace` subcommands

| Args | Effect |
|---|---|
| `on` | Enable + clear ring |
| `off` | Disable (`dump` still works) |
| `clear` / `reset` | Clear ring |
| `dump` | Print full ring (chronological) |
| _(none / other)_ | Print usage (notes default ON) |

---

## OneWoW_Bags

**Source:** `OneWoW_Bags/OneWoW_Bags.lua`, `Core/Profile.lua`,
`Core/LayoutDebug.lua`, `Core/OverlayFlashDebug.lua`

| Command | Kind | Description |
|---|---|---|
| `/1wbags` | User | Toggle bags UI |
| `/1wbprof` | Debug | Bags performance profiler |
| `/1wblayout` | Debug | Layout refresh debug ring |
| `/1wboverlay` | Debug | Overlay-flash debug ring (guild bank, etc.) |

### `/1wbprof` subcommands

| Args | Effect |
|---|---|
| `on` | Enable + reset counters |
| `off` | Disable (`dump` still works) |
| `reset` | Reset counters |
| `dump` | Print profile table |
| _(none / other)_ | Print usage |

### `/1wblayout` subcommands

| Args | Effect |
|---|---|
| `on` | Enable + clear ring |
| `off` | Disable (`dump` still works) |
| `clear` / `reset` | Clear ring |
| `dump` | Print ring |
| _(none / other)_ | Print usage |

### `/1wboverlay` subcommands

| Args | Effect |
|---|---|
| `on` | Enable live + ring |
| `quiet` | Enable ring only (no live spam) |
| `off` | Disable (`dump` still works) |
| `mark` | Reset epoch to now |
| `clear` / `reset` | Clear ring |
| `dump` | Print ring |
| _(none / other)_ | Print usage |

---

## OneWoW_Utility_DevTool

**Source:** `OneWoW_Utility_DevTool/OneWoW_Utility_DevTool.lua`

| Command | Kind | Description |
|---|---|---|
| `/1wdt` | Dev | Toggle DevTools main window |
| `/1wdev` | Dev | Toggle DEVMODE (floating error list) |

### `/1wdt` subcommands

| Args | Effect |
|---|---|
| `notice` | Reset + show install notice |
| _(none)_ | Toggle main window |

---

## Registration patterns (for maintainers)

Commands are registered in three ways:

1. **Direct globals** — `SLASH_FOO1 = "/foo"` + `SlashCmdList["FOO"] = handler`
2. **`_G["SLASH_…"]`** — same idea, used by some QoL modules
3. **`OneWoW_GUI.DB:RegisterSlashCommand(name, handler)`** — creates
   `SLASH_ONEWOW_<NAME>1 = "/<name>"` and `SlashCmdList["ONEWOW_<NAME>"]`

In-hub documentation: `OneWoW/UI/t-home.lua` (Home addon cards + Command Options).
Keep that list in sync when changing user-facing commands.

---

## Keeping this file current

**Policy:** any PR/commit that adds, removes, renames, or changes the behavior
of a slash command (including subcommands or alias sets) must update
`suitecommands.md` in the same change.

### Recommended automation (not yet installed)

Would live in **OneWoW_Workspace** `bin/` if added.

1. **Generator script** — `OneWoW_Workspace/bin/gen_suite_commands.py`
   - Scan `OneWoW*/**/*.lua` (exclude `Libs/`) for:
     - `SLASH_<KEY>N = "/alias"`
     - `_G["SLASH_<KEY>N"] = "/alias"`
     - `DB:RegisterSlashCommand("alias", …)` / `OneWoW_GUI.DB:RegisterSlashCommand`
   - Emit / refresh the Quick Index + per-addon alias tables
   - Subcommand docs stay hand-maintained in annotated blocks (or extracted from
     nearby `usage:` print strings where present)

2. **Pre-commit check** — `OneWoW_Workspace/bin/check_suite_commands.py` wired in
   Suite `.pre-commit-config.yaml` via `run_devs.py`
   - Fail if registered aliases are missing from `suitecommands.md`, or if the
     markdown lists an alias that no longer exists in code
   - Same style as existing local hooks (`check_no_g_literal.py`, etc.)

3. **Agent rule** — add a short note to
   `.cursor/rules/OneWoW-Suite-Architecture.mdc` (or a dedicated rule):
   - Touching slash registration → update `suitecommands.md` and Home tab help
     in `OneWoW/UI/t-home.lua` when the command is user-facing

4. **Optional CI** — run the same checker in GitHub Actions so drift cannot land
   on `main` even if someone bypasses local hooks

Until the generator/hook lands: treat this file as **source of truth for humans**
and update it manually whenever slash registration changes.
