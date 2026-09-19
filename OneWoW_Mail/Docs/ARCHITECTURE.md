# OneWoW Mail — Architecture

Standalone LoD load unit that replaces the Blizzard mailbox UI with a OneWoW_GUI shell and adds logistics **Shipments** powered by `OneWoW.PredicateEngine`.

Player overview and install: [`../README.md`](../README.md).

## Load & lifecycle

- TOC: `OneWoW_Mail.toc` (`RequiredDeps: OneWoW`, `LoadOnDemand: 1`)
- Manifest: `OneWoW/Core/AddonLoader.lua` (`/1wmail`)
- FirstRun: standalone catalog entry with datastores Storage, Character
- Init: `OneWoW_Mail:OnAddonLoaded` / `OnPlayerLogin` (no suite lifecycle `RegisterEvent`)
- Gameplay: `MAIL_SHOW` / `MAIL_CLOSED` / `MAIL_INBOX_UPDATE` on the Shell frame

## Modules

| Area | Role |
|------|------|
| `UI/Shell.lua` | Hide Blizzard `MailFrame`, tab host (Inbox / Compose / Shipments / Activity); `useBlizzardUI` chrome swap (WoW UI / One UI) |
| `UI/Inbox.lua` | Filtered collect buttons, selection, Shift-loot / Ctrl-return |
| `UI/Compose.lua` | OneWoW Compose chrome; hidden native `SendMailFrame` via NativeSend; success/fail → RunLog |
| `Engine/NativeSend.lua` | Activate/deactivate `SetSendMailShowing` + park Blizzard send frame |
| `UI/Shipments.lua` | Shipment editor (char/role target, distribute, PE match, keep/max/restock, restockSources) |
| `UI/Activity.lua` | Pending-review groups, session activity log, process/discard, chat mirror |
| `Engine/Collect.lua` | `C_Mail.IsCommandPending` paced take; COD/GM skip; per-mail + pass summary → RunLog |
| `Engine/MailClassify.lua` | AH invoice + subject classification |
| `Engine/AddressBook.lua` | Alts (all realms) + normalize + suggestions |
| `Engine/ShipmentEvaluator.lua` | Expand role → per-member plans; PE match + keep/max/restock; role distribute modes → jobs |
| `Engine/AutoRun.lua` | Session success map `shipmentId → roleId → charKey`; skip already-successful role members; stands down while `useBlizzardUI` |
| `Engine/SendResult.lua` | Ack listener for `MAIL_SEND_SUCCESS` / `MAIL_FAILED`; captures mail `UI_ERROR_MESSAGE` for the activity log |
| `Engine/SendQueue.lua` | Sequential `SendMail` jobs; success/fail → RunLog |
| `Engine/RunLog.lua` | Session activity log; optional chat mirror (`mirrorLogToChat`); errors always print |
| `Engine/InTransit.lua` | Writes recipient Storage in-transit on suite-alt send (items + gold); restock planning counts in-transit toward the target |

## Role-targeted shipments

- Roles live in core (`OneWoW.AltScope` / `OneWoW_DB.global.roles`); Mail does not depend on AltTracker hub UI.
- Shipment fields: `targetKind` (`char`|`role`), `target` / `targetRoleId`, `roleDistribute` (`fill_first`|`round_robin`|`equal_split`).
- Plan-time expand to N recipients (exclude self); keep/cap/restock apply per recipient; shared sender pool uses `roleDistribute` when underfunded.
- `restockSources` (`bags` / `bank` / `warband` / `guild`) is recipient-owned stock for top-up, not sender pull. Sender always mails from bags. Missing `warband` migrates to `true`. In-transit always counts. `shipments.schema_version` and per-row `editedAt` (`time()` on player edit). AutoRun `sessionDone` is memory-only. Soulbound is forced off at plan time.

## Cross-unit

- `OneWoW.Disenchant` — `#disenchantable` / `#de` (PE keyword)
- `OneWoW_AltTracker_Storage_API` — `AddInTransitShipment` / `GetInTransitShipments` / `ClearInTransitBySubject` (recipient key via `AddressBook:ResolveCharKey` → `OneWoW_GUI:GetCharacterKey`)
- Accounting / Storage loot hooks left intact (TakeInbox* still classified there)

## Branding

- TOC / Manage Features: `Interface\Icons\achievement_guildperk_gmail`
- UI atlas: `Crosshair_mail_*`
