This wiki is for **players**. Contributor and integrator documentation lives in the **repository** — do not treat this page as a second Docs tree. When wiki tips and Docs disagree, **Docs and code win**.

## How the suite is shaped

* **`OneWoW`** is always loaded: hub UI, shared `OneWoW_GUI` toolkit, themes, locales, Manage Features, and shared services (search/predicate engine, collectibles, overlays, and more).
* **Feature modules** (`OneWoW_Bags`, `OneWoW_QoL`, `OneWoW_Mail`, …) are separate Load-on-Demand addons. Disabling one in Manage Features **unloads** it.
* **Data stores** (`OneWoW_CatDB_*`, `OneWoW_AltTracker_*`) feed parent features (and some consumers like Shopping List / Mail) without their own player hub. Catalog databases are per-expansion CatDB addons, Other, and Tradeskills. Turning Catalog off stops those Catalog packs from loading.
* Cross-unit reads go through published `_API` surfaces and core services — not by reaching into another unit’s SavedVariables.

Clone the repo (or browse on GitHub) and start with **CONTRIBUTING** + **ARCHITECTURE** before changing load order, lifecycle hooks, or DB defaults.

## Start here

| Topic | Doc |
|-------|-----|
| How to contribute (PRs, locales) | [CONTRIBUTING.md](https://github.com/kellewic/OneWoW_Suite/blob/main/CONTRIBUTING.md) |
| QoL module authoring | [OneWoW_QoL/DEVELOPERS.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_QoL/DEVELOPERS.md) |
| Community QoL module credits | [MODULE_CREDITS.md](https://github.com/kellewic/OneWoW_Suite/blob/main/MODULE_CREDITS.md) |
| Docs index | [OneWoW/Docs/README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW/Docs/README.md) |
| CatDB Contribute (sync flags → existing shards) | [CATDB_CONTRIBUTE.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW/Docs/CATDB_CONTRIBUTE.md) |
| Load units, lifecycle, enable model, hub | [ARCHITECTURE.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW/Docs/ARCHITECTURE.md) |
| SavedVariables / `OneWoW_GUI.DB` | [DATABASE.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW/Docs/DATABASE.md) |
| UI toolkit | [GUI.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW/Docs/GUI.md) |
| Localization (11 locales) | [LOCALES.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW/Docs/LOCALES.md) |
| Search / `#` expression engine | [PREDICATE_ENGINE.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW/Docs/PREDICATE_ENGINE.md) · player syntax: [Bags Search Syntax](Bags-Search-Syntax) |
| Named searches / catalog | [SEARCH_CATALOG.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW/Docs/SEARCH_CATALOG.md) |

## Feature integration

| Area | Doc |
|------|-----|
| Bags third-party API | [OneWoW_Bags/API/README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_Bags/API/README.md) |
| Bags internals | [OneWoW_Bags/Docs/README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_Bags/Docs/README.md) |
| QoL external modules | [OneWoW_QoL/DEVELOPERS.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_QoL/DEVELOPERS.md) · [MODULES.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_QoL/MODULES.md) |
| Mail shipments pipeline | [OneWoW_Mail/Docs/ARCHITECTURE.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_Mail/Docs/ARCHITECTURE.md) |
| Trackers | [OneWoW_Trackers/Docs/ARCHITECTURE.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_Trackers/Docs/ARCHITECTURE.md) |
| Slash command inventory | [suitecommands.md](https://github.com/kellewic/OneWoW_Suite/blob/main/suitecommands.md) |
| In-game inspector (opt-in) | Player page: [DevTools](DevTool) · [OneWoW_Utility_DevTool/README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_Utility_DevTool/README.md) |

## Conventions

| Location | Audience |
|----------|----------|
| GitHub Wiki (this site) | Players |
| Addon `README.md` | Players |
| `ADDON/Docs/` and `OneWoW/Docs/` | Contributors / integrators |
| `CONTRIBUTING.md` | Anyone opening a PR |

## Related

* [Home](Home) — player wiki entry
* [FAQ](FAQ)

### Sources

* [OneWoW/Docs/README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW/Docs/README.md)
* [CONTRIBUTING.md](https://github.com/kellewic/OneWoW_Suite/blob/main/CONTRIBUTING.md)
* [MODULE_CREDITS.md](https://github.com/kellewic/OneWoW_Suite/blob/main/MODULE_CREDITS.md)
* [OneWoW/Docs/ARCHITECTURE.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW/Docs/ARCHITECTURE.md)
* [OneWoW_Catalog/Docs/CATDB.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_Catalog/Docs/CATDB.md)
* [OneWoW/Docs/CATDB_CONTRIBUTE.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW/Docs/CATDB_CONTRIBUTE.md)
