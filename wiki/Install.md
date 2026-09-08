Install **OneWoW** (required) plus only the optional `OneWoW_*` folders you want. You are not required to copy every addon in the package.

## Get the package

| Source | Notes |
|--------|--------|
| **CurseForge** | Install and update like any other addon |
| **Discord** | Community bot command that gives a zip in the same shape CurseForge would |
| **GitHub** | Fine if you already clone repos — this page does not teach git |

Site and community: [https://onewow.net/](https://onewow.net/)

## Put folders in AddOns

1. Unpack the zip so you see folders named like `OneWoW`, `OneWoW_Bags`, `OneWoW_QoL` — not one extra wrapper folder around everything.
2. Copy those folders into:

   ```text
   World of Warcraft\_retail_\Interface\AddOns\
   ```

3. At the character select screen, open **AddOns** and enable `OneWoW` plus any optional modules you installed.
4. Log in (or `/reload` if you already were in-world).
5. Type `/1w` to open the hub.
6. Use **Manage Features** to enable or disable optional modules. Disabling a feature **unloads** it — it is not just hidden.

## What the folders mean

| Kind | Examples | Notes |
|------|----------|--------|
| **Required** | `OneWoW` | Core hub and shared UI |
| **Feature modules** | `OneWoW_Bags`, `OneWoW_QoL`, `OneWoW_AltTracker`, `OneWoW_Catalog`, `OneWoW_Trackers`, `OneWoW_Notes`, `OneWoW_ShoppingList`, `OneWoW_Mail`, `OneWoW_DirectDeposit` | Enable in Manage Features |
| **Catalog data** | `OneWoW_CatDB_*` | Per-expansion Catalog data, Other, and Tradeskills — enable with Catalog |
| **AltTracker data** | `OneWoW_AltTracker_*` | Companion data for AltTracker — enable with AltTracker |
| **Tools** | `OneWoW_Utility_DevTool` | Optional in-game developer inspector |

If a feature seems empty after you enable it, confirm its companion data folders are also present under `AddOns` and enabled.

## Related

* [Getting started](Getting-Started)
* [FAQ](FAQ)

### Sources

* [README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/README.md) — quick start and addon catalog
* [OneWoW/README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW/README.md) — core install notes
