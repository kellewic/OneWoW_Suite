Common questions about installing and using OneWoW. More entries will land here as they come up in community support.

## Install and folders

### Do I need every `OneWoW_*` folder?

No. Install **OneWoW** (required) plus the optional features you want. See [Install](Install).

### Catalog or AltTracker looks empty

Those features need their companion data folders (`OneWoW_CatDB_*` / `OneWoW_AltTracker_*`) present and enabled. Catalog data is one addon per expansion, plus Other and Tradeskills. Enable the parent feature in **Manage Features**; companions load with it. Turning Catalog off also turns the encyclopedia off (ESC zone cards, item sources, profession extras). After an update, delete a leftover `OneWoW_CatDB` folder in AddOns if Curse left one; keep the expansion folders. See [Catalog](Catalog) and [AltTracker](AltTracker).

### Where do I get the package?

CurseForge or the Discord community bot zip — same layout either way. Site: [https://onewow.net/](https://onewow.net/).

## Manage Features

### I disabled a module but it still feels “there”

Disabling in **Manage Features** **unloads** the addon — it is not just hidden. If something still appears, confirm the folder is not force-enabled only in the character-select AddOns list, then `/reload`.

### Can I use Shopping List without AltTracker?

Yes. Enable Shopping List in Manage Features; Storage can load for alt/bank scanning even when the AltTracker hub is off. See [Shopping List](Shopping-List).

## Search and keywords

### Why don’t localized `#` keywords from another addon work?

OneWoW keywords are **English-only** (`#epic`, `#armor`, …). Import foreign category dialects through Bags **Import from…** so they convert. See [Search syntax](Bags-Search-Syntax).

### Slash commands do nothing

The feature must be **installed and enabled**. Open [Slash commands](Slash-Commands) for the list, then check Manage Features.

## Companion site

### How do I send missing Catalog facts?

Play with OneWoW. Talk to NPCs, open quests, and open professions. Log out of WoW. In CompSync, paste your [app.onewow.net](https://app.onewow.net/) upload token on **Cloud**, then upload from **Contribute** or leave **Also upload Contribute data** checked when you Cloud sync. Only flagged Catalog facts go. Bags and gold stay on your PC. Those facts do not show on the website; they wait for a later OneWoW release. See [About](About).

### Why don’t my Contribute facts show on app.onewow.net?

That upload is not a site Catalog. It only stores the facts for a future addon release. Your roster, bags, and lockouts still come from the normal Cloud snapshot.

## The project

### Is the source public?

Yes. The suite lives at [https://github.com/kellewic/OneWoW_Suite](https://github.com/kellewic/OneWoW_Suite). Anyone can read it, open an issue, or send a pull request (including original QoL modules). That is **not** permission to republish OneWoW as your own addon. See [About](About) and [LICENSE.md](https://github.com/kellewic/OneWoW_Suite/blob/main/LICENSE.md).

### Who wrote a QoL module?

Open the module in QoL and use **Details**. That name is the credit line. The OneWoW team may edit shipped modules; credit stays with the original author until a complete rewrite, then they keep concept credit. Community list: [MODULE_CREDITS.md](https://github.com/kellewic/OneWoW_Suite/blob/main/MODULE_CREDITS.md). Empty credit means the OneWoW Development Team.

### Is OneWoW written by AI?

The suite is **AI-assisted** and shipped by two full-time developers. Humans set the architecture, review what ships, and stand behind it. If you want to judge the code, read the repo. See [About](About).

### Does it pass Wow API and LuaLS checks?

Yes. OneWoW targets **Retail 12.1+** Wow API and uses LuaLS / Ketho-style API definitions plus the same class of checks people talk about when they review addons. See [Developers](Developers).

### I found another OneWoW Alt Tracker on CurseForge

The official site is [https://onewow.net/](https://onewow.net/). Download and CurseForge links on that site are the ones we ship. Older or similarly named CurseForge projects are not this suite.

## Conflicts and help

### Bags vs default bags / other bag addons

Enable only one primary bag UI you intend to use, or expect overlapping keybinds and frames. OneWoW Bags opens with `/1wbags` (see [Bags](Bags)).

### Where do I get help?

[https://onewow.net/support/](https://onewow.net/support/) lists every channel: this site's docs, email, Discord, CurseForge comments, and GitHub issues. Pick one. Prefer those over editing the GitHub wiki UI.

## Related

* [About](About)
* [Compare](Compare)
* [Install](Install)
* [Getting started](Getting-Started)
* [Slash commands](Slash-Commands)

### Sources

* [LICENSE.md](https://github.com/kellewic/OneWoW_Suite/blob/main/LICENSE.md)
* [MODULE_CREDITS.md](https://github.com/kellewic/OneWoW_Suite/blob/main/MODULE_CREDITS.md)
* [README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/README.md)
* [OneWoW/README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW/README.md)
* Feature READMEs linked from each wiki feature page
