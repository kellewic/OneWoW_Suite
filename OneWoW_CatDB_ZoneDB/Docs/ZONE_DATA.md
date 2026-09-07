# CatDB Zones — data rules

Runtime rules for `OneWoW_CatDB_ZoneDB` and how place / encounter shards are
built. Build-time source order lives in OneWoW_Workspace
[`Docs/WAREHOUSE_PLAN.md`](../../../Docs/WAREHOUSE_PLAN.md).

Load-unit wiring: [`ARCHITECTURE.md`](ARCHITECTURE.md).

This is the Catalog Zones store.

## One home

ZoneDB owns the **place** and the **encounter**: world and in-instance pins,
valid difficulties, and loot **links** (itemIDs only).

Adventure Guide overview text and boss abilities are live
(`EJ_GetInstanceInfo`, `EJ_GetEncounterInfo`,
`C_EncounterJournal.GetSectionInfo`) when you open a Journal card. They are
not shipped.

Everyone else stores IDs:

| Fact | Home | On the ZoneDB row |
|------|------|-------------------|
| Item name / icon / quality | ItemDB | `loot[].itemID` |
| NPC pin / display / roles | NPCDB | `npcIDs` |
| Quest text / rewards | QuestDB | `loot[].questIDs` |
| Recipe / craft | TradeSkillDB | (not stored here) |

Do not dump `Creature.csv` or full ItemSparse into this addon.

## What it owns

- World entrance pin and queue / meeting-stone pin
- In-instance boss pin + UiMap
- Encounter difficulties and `DungeonEncounter` kill-credit → npcID
- Encounter creature display IDs
- Valid difficulties and difficulty names
- AreaTable + UiMap parent / continent
- Covenant lock
- Delve vs bountiful door pins (`areaPoiID` / `bountifulPoiID` on entrance)
- Journal membership, flags, listing overrides, achievements as IDs

Place kinds: `zone` | `instance` | `delve` | `hub` | `world`.

## IDs only

`npcIDs`, `achievementIDs`, and `loot[].itemID` are joins. Identity for
those rows lives in the other CatDB packs (or Blizzard APIs for
achievements). Extra loot may carry `questIDs` for Journal quest-source
groups.

## Expansion IDs

Place `expansion` is **1-based** warehouse / Journal `ZONE_SEED` (Classic = 1,
TWW = 11, Midnight = 12). Dual-list places may set `expansions = { 1, 3 }`
and still have one home shard. NPCDB and QuestDB use `LE_EXPANSION_*`
(Classic = 0). Do not mix the two without converting.

## Schema

### Place row

Keyed by place key (`"instance:63"`, `"zone:84"`, `"delve:<mapID>"`,
`"hub:<instanceID>"`, `"world:<expansion>"`).

| Group | Keys |
| --- | --- |
| Identity | `kind`, `name`, `expansion`, `expansions`, `instanceID`, `mapID`, `uiMapID`, `areaID`, `parentUiMapID`, `instanceType`, `isCity`, `flags`, `covenantID`, `order` |
| Joins | `difficultyIDs`, `encounterIDs`, `npcIDs`, `achievementIDs` |
| Pins | `entrance[]`, `queue[]` — `{ mapID, x, y, faction, uiMapID?, areaPoiID?, bountifulPoiID? }` |

Instance and encounter flavor, mechanic writeups, button / background art,
lock messages, object IDs, vignette IDs, and place-level quest ID dumps
are not shipped. Journal reads Guide text live. Card backgrounds use
`EJ_GetInstanceInfo`. Vignettes stay on NPCDB.

### Encounter row

Keyed by `encounterID`. World rares use the same shape (`npcIDs` + `loot`).

| Group | Keys |
| --- | --- |
| Identity | `encounterID`, `instanceID`, `order`, `name`, `dungeonEncounterID` |
| Pin | `uiMapID`, `pin = { x, y }` (0–1), `difficultyIDs`, `displayIDs` |
| Joins | `npcIDs`, `loot[] = { itemID, diffs, faction, season?, questIDs?, achievementID? }` |

`loot.achievementID` is optional (live overlay). The shipped item →
achievement join is ItemDB `ItemAchievements`.

Synthetic IDs (emit, `bin/lib/catdb_zone.py`) are not Journal encounter IDs:

| Range | Meaning | Hydrate |
| --- | --- | --- |
| `1 .. 9999999` | Adventure Guide / world boss | Named encounter |
| `10000000 + npcID` | Outdoor rare | `worldRare`, NPC name |
| `>= 20000000` | Unplaced leftover bucket | **General Loot** only |

`EnsureEncounters` matches old Journal grouping: World Bosses, World Rares by
NPC name, General Loot for leftovers. Rows with no loot are omitted. Rare
and leftover rows ship with an empty `name`; the API fills it at hydrate.

Also in this addon: `Difficulties` (`name`, `maxPlayers`, `instanceType`),
`TierMembership` (`[expansionID][instanceID] = order`), `ListingOverrides`
(`forceHide` / `forceShow` keyed by `"expansionID:instanceID"`).

## Build (Workspace)

```bash
# from OneWoW_Workspace
python bin/journal_extras.py emit
python bin/catdb_zone_emit.py
python bin/catdb_status.py zone
```

`journal_extras.py emit` writes `Data/Generated` extras (not shipped). Zone emit
reads those for world rares and leftover loot. Without them, a re-emit drops
those encounters.
