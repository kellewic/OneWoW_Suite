<p align="center">
  <img src="onewow_icon.png" alt="OneWoW" width="160">
</p>

**OneWoW** is a modular World of Warcraft addon suite for **Retail**. One shared hub, unified themes, eleven locales, and optional feature addons you turn on only when you need them.

**Website:** [https://onewow.net/](https://onewow.net/)

This wiki is the **player** reference — install, hub setup, slash commands, and how each feature works in-game. Engineering docs stay in the [repository](https://github.com/kellewic/OneWoW_Suite) (`OneWoW/Docs/` and per-addon `Docs/`). See [Developers](Developers) for links.

---

## Start here

1. **[Install](Install)** — CurseForge or Discord zip into `Interface\AddOns\`
2. **[Getting started](Getting-Started)** — open `/1w`, run the wizard, enable features
3. **[Slash commands](Slash-Commands)** — open each part of the suite from chat
4. **[Release notes](Release-Notes)** — what changed in recent ships

## What you get

**Core hub (OneWoW)** — always installed: portal/teleport hub, smarter item tooltips and status indicators, collection toasts, universal search, shared themes, and **Manage Features** for everything else.

**Optional features** (enable what you use):

| Feature | What it is |
|---------|------------|
| [Bags](Bags) | Bag organization, categories, and [search syntax](Bags-Search-Syntax) |
| [QoL](QoL) | Dozens of toggleable quality-of-life modules |
| [AltTracker](AltTracker) | Account-wide alts, gold, professions, progress |
| [Catalog](Catalog) | Instances, vendors, professions, recipes, collectibles, housing |
| [Trackers](Trackers) | Custom lists — guides, dailies, todos, farm value |
| [Notes](Notes) | Notes on players, NPCs, zones, items, collectibles, quests; OneWay Pins |
| [Shopping List](Shopping-List) | Shopping and Farming lists with stock checks |
| [Mail](Mail) | Mailbox UI and shipment helpers |
| [Direct Deposit](Direct-Deposit) | Warband Bank gold and item transfers |
| [DevTools](DevTool) | Optional developer inspector (frames, events, errors). Not required to play. |

You do **not** need every folder. Catalog uses companion **CatDB** folders (one per expansion, plus Other and Tradeskills). AltTracker uses its `OneWoW_AltTracker_*` stores. Those companions load with their parent when that feature is enabled.

## Help

* [FAQ](FAQ) — common install and setup questions
* [About](About) — who ships it, public source, quality bar
* [Compare](Compare) — vs Altoholic, All The Things, and Bagnon
* Support (docs, email, Discord, CurseForge, GitHub): [https://onewow.net/support/](https://onewow.net/support/)

## Related

* [Install](Install) · [Getting started](Getting-Started) · [Slash commands](Slash-Commands) · [Release notes](Release-Notes)
* [Developers](Developers)

### Sources

* [README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/README.md) — suite overview and addon catalog
* [OneWoW/README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW/README.md) — core hub features
