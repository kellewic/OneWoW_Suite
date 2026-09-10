# CatDB packs

Catalog data is one addon per expansion, plus **Other**, plus
**Tradeskills**. Query APIs live on `OneWoW_Catalog`. `PackResolver` loads a Catalog **role** (`journal`, `vendors`,
`quests`, `items`, `tradeskills`); that pulls Catalog and only the
installed expansions whose topics for that role are on.

**Rule:** one home per fact. Everyone else stores IDs.

| Pack | Catalog role | Notes |
|------|--------------|-------|
| `OneWoW_CatDB_<Expansion>` | `journal` / `vendors` / `quests` / `items` | Suite expansion 1-12. `Data/` is DB2/CSV; `DataExtra/` is other warehouse sources. Topic toggles in Manage Features. |
| `OneWoW_CatDB_Other` | same roles | `X-OneWoW-CatDB: 99`. Unassigned rows. Distro always ships it. |
| `OneWoW_CatDB_TradeSkillDB` | `tradeskills` | Not per-expansion. |

Public APIs stay `OneWoW_CatDB_ZoneDB_API`, `OneWoW_CatDB_NPCDB_API`,
`OneWoW_CatDB_ItemDB_API`, `OneWoW_CatDB_QuestDBCurrent_API` (archive
aliases Current), `OneWoW_CatDB_TradeSkillDB_API`. `ns` stays private.

Learned overlays (`OneWoW_CatDB_ZoneDB_DB`, `NPCDB_DB`, `ItemDB_DB`,
`QuestDBCurrent_DB`) are runtime SavedVariables, not pack folder names.
CompSync Contribute reads `sync = true` rows. Contract:
[CATDB_CONTRIBUTE](../../OneWoW/Docs/CATDB_CONTRIBUTE.md).

Emit lives in OneWoW_Workspace:

```bat
python bin/warehouse/update.py
python bin/catalog/emit_base.py
python bin/catalog/emit_extra.py
```

`Data/` is client/Wago. `DataExtra/` is 2-DataSet + Offline drop (new ids; hole-fill existing Data rows). Intermediates: `.warehouse/Generated/CatDB/`. Stats: [`.warehouse/CatalogDataStats.md`](../../../.warehouse/CatalogDataStats.md) in OneWoW_Workspace ([pointer](CatalogDataStats.md)). Contribute lands in `2-DataSet/1wContribute`, then extra emit.
