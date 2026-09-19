# OneWoW Suite — Documentation Index

Player-facing suite overview and addon catalog: [README.md](../../README.md) (repo root).
Player docs (install, features, search syntax): [GitHub Wiki](https://github.com/kellewic/OneWoW_Suite/wiki).

Contributor and integrator documentation for the suite.

## Core hub (`OneWoW`)

| Document | Contents |
|----------|----------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Load units, lifecycle, enable model, hub UI, cross-unit sharing, GUI integration |
| [DATABASE.md](DATABASE.md) | `OneWoW_GUI.DB` — SavedVariables, defaults, init bridges, scope resolution |
| [GUI.md](GUI.md) | `OneWoW_GUI` toolkit — components, themes, settings, window persistence |
| [LOCALES.md](LOCALES.md) | Localization routing, scopes, Blizzard-term alignment, tooling |

## Shared services

| Document | Contents |
|----------|----------|
| [PREDICATE_ENGINE.md](PREDICATE_ENGINE.md) | Shared `OneWoW.PredicateEngine` — tokenizer, keywords, extension API |
| [SEARCH_CATALOG.md](SEARCH_CATALOG.md) | Shared `OneWoW.SearchCatalog` — named expressions, former-name redirects, reference index, export/import |
| [COLLECTIBLES.md](COLLECTIBLES.md) | Collectible identity, keys, live collection state |
| [INVENTORY.md](INVENTORY.md) | Live bag/bank/guild-bank event funnel (`OneWoW.Inventory`) |
| [MERCHANT.md](MERCHANT.md) | Merchant scan funnel (`OneWoW.Merchant`) |
| [PROFESSION_RECIPE.md](PROFESSION_RECIPE.md) | Trade-skill recipe scan funnel (`OneWoW.ProfessionRecipe`) |
| [TOOLTIP_SCANNER.md](TOOLTIP_SCANNER.md) | Structured tooltip line scanning (`OneWoW.TooltipScanner`) |
| [GEAR_PROFICIENCY.md](GEAR_PROFICIENCY.md) | Class weapon/armor proficiency masks |
| [GUILD_BANK_TRANSFER.md](GUILD_BANK_TRANSFER.md) | Bag-to-guild deposit plan and paced queue |
| [CATDB_CONTRIBUTE.md](CATDB_CONTRIBUTE.md) | Player-found Catalog facts: addon `sync` flag, CompSync payload, merge into existing shards |

## Feature addons

| Document | Contents |
|----------|----------|
| [OneWoW_Bags/Docs/README.md](../../OneWoW_Bags/Docs/README.md) | Bags architecture, categorization, search syntax, import/export, item-button API |
| [OneWoW_QoL/DEVELOPERS.md](../../OneWoW_QoL/DEVELOPERS.md) | External QoL module authoring (`module.lua`, `ModuleRegistry`, locale scope) |
| [OneWoW_QoL/MODULES.md](../../OneWoW_QoL/MODULES.md) | QoL external module catalog (36 modules by category) |
| [OneWoW_Trackers/Docs/ARCHITECTURE.md](../../OneWoW_Trackers/Docs/ARCHITECTURE.md) | Tracker lists, engine, presets, farm value |
| [OneWoW_Mail/Docs/ARCHITECTURE.md](../../OneWoW_Mail/Docs/ARCHITECTURE.md) | Mail shell, shipments, send/collect pipeline, Storage in-transit |
| [OneWoW_Catalog/Docs/CATDB.md](../../OneWoW_Catalog/Docs/CATDB.md) | Catalog packs (per-expansion CatDB, Other, Tradeskills) and query APIs |

Quest query APIs (`OneWoW_CatDB_QuestDBCurrent_API` and the archive alias) live on Catalog; there is no `OneWoW_CatDB_QuestDBCurrent` load unit.

## Contributing

| Document | Contents |
|----------|----------|
| [README.md](../../README.md) | Suite overview, addon catalog, quick start |
| [CONTRIBUTING.md](../../CONTRIBUTING.md) | Suite-wide contribution guide (code, locales, PR process) |

## Conventions

| Location | Audience | Content |
|----------|----------|---------|
| [GitHub Wiki](https://github.com/kellewic/OneWoW_Suite/wiki) | Players | Install, getting started, feature guides, search syntax |
| Repo `README.md` | Players | Suite overview, addon catalog, quick start |
| `ADDON/README.md` | Players | What the addon does, install, slash commands |
| `ADDON/Docs/` | Contributors | Architecture, APIs, data models |
| Repo `CONTRIBUTING.md` | Contributors | How to contribute to any load unit |

The shared UI toolkit ships inside `OneWoW` (`OneWoW/GUI/`, global `OneWoW_GUI`).
