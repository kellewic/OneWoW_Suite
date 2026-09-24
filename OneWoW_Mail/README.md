# OneWoW - Mail

**A OneWoW-styled mailbox with smarter collect/compose workflows and reusable Shipments to characters or roles — using the same search language as Bags.**

---

## Features

### Mailbox shell
Replaces the default mailbox UI while you are at a mailbox:
- **Inbox** — filtered collect actions, selection, Shift-click to collect, Ctrl-click to return
- Expandable mail details (body and attachments) where there is something to preview
- Richer Auction House invoice breakdown when that mail type is recognized
- **Compose** — OneWoW chrome with address suggestions for your alts (all realms)
- **Activity** — session run log for collect/send results; pending shipment reviews when auto-run holds a plan for Process/Discard
- **WoW UI / One UI** — switch to the default WoW mailbox and back without turning Mail off. Auto-collect and shipment auto-run do not run while WoW UI is on. `/1wmail` or the minimap while WoW UI is showing returns to One UI.

### Shipments
Reusable logistics plans for mailing items and gold:
- Target a **character** or a **role** (suite Roles & Alts — AltTracker hub not required)
- **Match** bag items with Bags search syntax (`#` keywords, operators, saved searches); soulbound items are always excluded
- Per-item rules: leave some on this character, cap send amount, or **top up** the target using known alt inventory (bags, bank, Warband Bank, optional guild bank; in-transit mail always counts)
- Gold rules: keep / cap / restock on the recipient
- Role distribute modes: fill first, round-robin, or equal split
- **Other realms** (under the target): Send keeps today's full letter. Cancel shipment sends nothing when someone outside this realm group cannot take the whole letter, and Activity says who. Warbound items only still sends the full letter inside this realm group, and sends Warbound items to your alts on other realms. Connected realms count as this realm. Existing shipments stay on Send until you change them.
- Auto-run modes can plan on mailbox open and wait for review on Activity, or send according to shipment settings
- Skip role members already successfully shipped this session

---

## Installation

1. Extract the `OneWoW_Mail` folder to your `World of Warcraft\_retail_\Interface\AddOns\` directory
2. Extract the `OneWoW` folder (required dependency) to the same directory
3. (Recommended) Keep `OneWoW_AltTracker_Storage` and `OneWoW_AltTracker_Character` available — Manage Features can pull them with Mail for alt addressing, restock, and in-transit tracking
4. Restart World of Warcraft or type `/reload` in-game
5. Enable **Mail** under OneWoW **Manage Features**
6. Open a mailbox, or type `/1wmail`

## Requirements

- **OneWoW** — Core hub addon (required)
- **OneWoW_AltTracker_Storage** / **OneWoW_AltTracker_Character** — Recommended for shipments that top up alts and track mail in transit (pulled when Mail is enabled; AltTracker hub not required)

## Slash Commands

- `/1wmail` — Toggle the Mail UI shell. At a mailbox on WoW UI, switches back to One UI.

## Localization

Supports all 11 suite locales — see [LOCALES.md](../OneWoW/Docs/LOCALES.md).

## Documentation

- Player wiki: [Mail](https://github.com/kellewic/OneWoW_Suite/wiki/Mail)
- Search expressions: [OneWoW_Bags/Docs/SEARCH_SYNTAX.md](../OneWoW_Bags/Docs/SEARCH_SYNTAX.md) (player wiki: [Bags Search Syntax](https://github.com/kellewic/OneWoW_Suite/wiki/Bags-Search-Syntax))
- Contributor architecture: [Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md)

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md).

## Support

**Website:** https://onewow.net/

**Report issues:** Through Discord community or our website

## OneWoW Suite

Part of the [OneWoW Suite](../README.md). See the suite README for the full addon catalog and install guide.

---

**Author:** OneWoW Development Team

**Website:** https://onewow.net/

**License:** See [LICENSE.md](../LICENSE.md). Copyright the OneWoW Development Team. All rights reserved.
