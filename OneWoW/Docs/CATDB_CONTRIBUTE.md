# CatDB Contribute

Players can send **missing Catalog facts** they found in-game so those rows
may be included in a later OneWoW release. This file is the addon contract.
CompSync builds a compact JSON payload from it. app.onewow.net stores the
accepted rows and we merge them into the existing CatDB shards later — not
as a side file.

This is not a Cloud snapshot. Bags, gold, settings, name caches, and
completion maps stay on the player’s PC.

## Flag

`sync = true` means “Companion should gather this row.”

| Where | When it is set |
| --- | --- |
| `OneWoW_DB.global.catdbLearn.{npc,quest,recipe}[id]` | Pending facts while the CatDB pack is still LoadOnDemand. Every queued row is `sync = true`. |
| `OneWoW_CatDB_NPCDB_DB.global.learned[npcID]` | New NPC, or a new role / pin / quest ID / vendor stock we did not ship. |
| `OneWoW_CatDB_QuestDBCurrent_DB.global.learned[questID]` | New quest, or new text / givers / objects / rewards. |
| `OneWoW_CatDB_TradeSkillDB_DB.global.learned[recipeID]` | Recipe missing from TradeSkillDB, or missing / extra reagents. |

Talking to an NPC, opening a quest dialog, or opening a profession window
writes the overlay. Opening a profession does **not** flag every known
shipped recipe — only gaps.

Do not mutate shipped shards. `GetSyncQueue()` on each pack returns
`learned` rows that still have `sync`. `OneWoW.CatDBSync.GetQueue()` merges
the pending queue with those pack queues (in-game only). CompSync reads the
SavedVariables files after logout.

## What Companion is allowed to send

Allowlisted fields only. See CompSync `contribute.go`.

- **NPCs** — id, name, title, displayID, roles, map pins (0–100), quest IDs, vendor item IDs
- **Quests** — id, name, description, objectives text, starts/ends (`{ npcID }`), start/end objects + object pins, reward IDs, map
- **Recipes** — id, name, profession, output item, reagent list (`rg`)

Never send: `nameCache`, `itemCache`, `vendorVisits`, `completion`,
`settings`, profiles, AltTracker stores, or a raw `OneWoW_*.lua` file.

## After a successful site ack (later)

Clear `sync` on accepted ids (keep the learned overlay). Do not clear
until the site returns `ok`. CompSync must not rewrite SavedVariables
while WoW is running.

## Into Suite shards

This is the developer import path. Players never do this.

1. Site: `php OneWoW_ComWeb/tools/export_contribute.php --out PATH`
2. Workspace: `python bin/warehouse/contribute_pull.py` (also inside
   `python bin/warehouse/update.py`). Export lands in
   `.warehouse/Sources/2-DataSet/1wContribute`.
3. Extra emit: `python bin/catalog/emit_extra.py` — hole-fill existing
   `Data/` rows or write new ids to `DataExtra/`.

Do not merge test Contribute rows. Extra emit writes era `Data/` / `DataExtra/`.
New rows look like every other shipped row. Do not add a Contribute.lua pack.
Full notes: Companion `OneWoW_ComWeb/docs/CONTRIBUTE.md` and Workspace
`Docs/CATDB_CONTRIBUTE.md`.

## Related

- In-game queue: `OneWoW/Services/CatDBSync.lua`
- CompSync extract + UI: Companion `OneWoW_CompSync/Docs/CONTRIBUTE.md`
- Site ingest: Companion `OneWoW_ComWeb/docs/CONTRIBUTE.md`
