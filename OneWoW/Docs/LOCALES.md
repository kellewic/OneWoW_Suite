# OneWoW Suite — Localization guide

The day-to-day reference for working with locale strings in the suite: how the routing
decision works, what is intentionally *not* translated and why, how the suite aligns to
Blizzard's own terminology, the semantic traps, and the tooling.

The **contract** (scopes, resolution order, disjoint rule, centralized `SetLanguage`,
`GetStore`) is authoritative in [`ARCHITECTURE.md`](ARCHITECTURE.md) §6 — read that first.
Contributor workflow summary: [`CONTRIBUTING.md`](../../CONTRIBUTING.md).
(The phase-by-phase rollout history that produced this state lives in git history.)

The 11 supported locales, in TOC/registration order:
`enUS  koKR  frFR  deDE  zhCN  esES  zhTW  esMX  ruRU  ptBR  itIT`
(`enGB` aliases to `enUS`; `esMX` is its own locale, generated from `esES` — see §6.)

---

## 1. The routing decision — before you add a key

Check these in order; only fall through when the prior option genuinely doesn't fit:

1. **Bare Blizzard global.** If the English text exactly matches a Retail global
   (`ADD`, `REMOVE`, `CANCEL`, `CLOSE`, `CUSTOM`, `SETTINGS`, `DELETE`, …), use it at the
   call site (`text = ADD`) — **no locale key at all**. The client already localizes it in
   all 11 languages. Verify the name+value in the GlobalStrings reference (§4), whitelist
   the global in `.luarc.json` `diagnostics.globals`, and never write `_G.CLOSE` / `_G["CLOSE"]`.

2. **`shared` scope.** Grep `OneWoW/Locales/Shared/enUS.lua` for the same phrase
   (`ITEM_ID`, `ADD_ITEM`, `CURRENT_VALUE`, …) and reuse it via `L["KEY"]`. **Check shared
   before inventing a scoped key** — a string translated once in `shared` is translated
   everywhere; a per-scope duplicate is N× the maintenance and drifts over time.

3. **Addon / module scope.** Only for text genuinely unique to that load unit.

**Never** invent a prefixed duplicate (`PORTAL_CUSTOM_ADD` when `ADD` exists,
`PORTAL_CUSTOM_ID_LABEL` when `shared.ITEM_ID` exists). The whole point of the rollout is
*translate once, in one place.*

---

## 2. Scopes

| Scope | Files | Holds |
|---|---|---|
| `shared` | `OneWoW/Locales/Shared/` | Suite-wide strings reused across addons (themes, common buttons, field labels) |
| `OneWoW` (core hub) | `OneWoW/Locales/` | Hub chrome, search, overlays registry |
| load unit | `<Addon>/Locales/` | One addon's own strings (e.g. `OneWoW_Bags`) |
| QoL module | `OneWoW_QoL/Modules/external/<id>/Locales/` | Scope is `OneWoW_QoL.<id>` (module-style header) |

A key is **either shared or scoped, never both** (the disjoint contract — `/1wlocale`
reports collisions). A scoped key must not **shadow** a `shared` key with a *different*
value, and a new shared key's name must not collide with an existing scoped key elsewhere
that holds a different value (it would silently shadow `shared`).

---

## 3. What is NOT translated, and why

Future maintainers and LLMs: these are deliberate, not gaps.

- **Bare Blizzard globals** (§1.1) — resolved to the player's language by the client at
  load, so they leave the Locale system entirely (0 keys, 0 maintenance).
- **Proper nouns / brand names** — `OneWoW`, the module/product names (`Catalog`, `Notes`,
  `Bags`, `QoL`, `Direct Deposit`, `Trackers`, `DevTools`, `Shopping List`), `Discord`, and
  third-party addon names (`Pawn`, `Auctionator`, `TSM`, `Baganator`, `Bagnon`, `ArkInventory`).
  These consolidate to one `shared` key where reused, but the *value* is identical in every
  locale. Descriptive UI *around* a brand name is still localized.
- **WoW expansion names** — `The War Within`, `Dragonflight`, … are Blizzard product titles.
  They stay **English in the Latin/Cyrillic locales** (deDE/frFR/esES/esMX/ruRU/ptBR/itIT, which
  is how the live clients render them) and are translated **only in zhCN/zhTW/koKR**.
- **API names, slash commands, format tokens** — `C_GossipInfo`, `QuestLabelPrepend`,
  `FlagsUtil`, slash commands (`/copytext`, `/ct`, `/reload`), printf tokens (`%s`, `%d`,
  `%.0f`), color escapes (`|cFFFFD100…|r`), in-string `\n`, note/parse markers
  (`[OneWoW Inspect Mog]`), filter keywords (`#potion`, `#usable & #mount`), and file paths
  (`World of Warcraft\_retail_\Screenshots`). Keep these byte-identical across every locale.
- **`esMX`** — not hand-authored; generated from `esES` (§6).
- **Descriptive phrasings of game concepts** — e.g. "warbound" is rendered as the suite's
  "bound to <Warband>" phrasing rather than swapped for Blizzard's `ITEM_ACCOUNTBOUND` term;
  the embedded Warband term itself *is* aligned to Blizzard (§4).

---

## 4. Alignment to Blizzard terms

Established WoW terminology must match what the player sees in their own client — not a
plausible-sounding alternative. The **source of truth** is Blizzard's per-locale
GlobalStrings, in **OneWoW_Workspace** at:

```
.wow_docs/blizzard-interface-resources/Resources/GlobalStrings/<locale>.lua   (all 11 locales)
```

These are indexed in OneWoW_Workspace `.wow_docs/manifest.json` — use it as a quick scan for what reference
material is available. To find an official term: locate the English value's key in
`…/GlobalStrings/enUS.lua`, then read that same key in each locale file.

**Do not assume an existing suite translation is canonical** — verify against GlobalStrings.
(A 2026-06 audit found the suite's own pre-rollout terms were inconsistent and partly
non-official for several languages; everything was normalized to the table below.)

**Worked example — "Warband"** (`ACCOUNT_QUEST_LABEL` = "Warband",
`ACCOUNT_BANK_PANEL_TITLE` = "Warband Bank", `ITEM_ACCOUNTBOUND` = "Warbound"):

| Locale | Warband | Warband Bank | Warbound |
|---|---|---|---|
| deDE | Kriegsmeute | Kriegsmeutenbank | Kriegsmeutengebunden |
| frFR | Bataillon | Banque de bataillon | Lié au bataillon |
| esES/esMX | Banda guerrera | Banco de **la** banda guerrera | Ligado a **la** banda guerrera |
| ptBR | Bando de Guerra | Banco do Bando de Guerra | Vinculado ao Bando |
| itIT | Brigata | Banca della Brigata | Vincolato alla Brigata |
| ruRU | Отряд | Банк отряда | Привязано к отряду |
| zhCN | 战团 | 战团银行 | 战团绑定 |
| zhTW | 戰隊 | 戰隊銀行 | 戰隊綁定 |
| koKR | 전투부대 | 전투부대 은행 | 전투귀속 |

Note the per-language grammar: Spanish takes the article (*la* banda guerrera), Portuguese
"Bando" is masculine (so `da`→`do`, `à`→`ao`), German builds compounds (`Kriegsmeuten-`).

**Auditing for term drift:** translator synonyms slip past a source-string find/replace (e.g.
koKR `전역 은행`/`전쟁대`, ruRU `Банк боевого отряда`, a German `Kriegsmeer` typo, a stray English
`Warband`). To catch them, scan every key whose **name** contains the concept (`*WARBAND*`,
`*WARBOUND*`) and confirm each value carries the official stem for its locale (`전투부대`, `отряд`,
`Kriegsmeute`, `Bataillon`, `guerrera`, `Bando`, `Brigata`, `战团`, `戰隊`) — skipping keys whose
enUS value is descriptive and doesn't use the term (e.g. "Completed on a tracked alt").

---

## 5. Different meanings in different languages

**Value identity ≠ translation identity.** Two strings equal in English can diverge once
translated — never collapse keys by value without a meaning check:

- **Homographs.** `Close` the verb (a button) vs `Close` the adjective (proximity) translate
  differently in es/fr/de. Same for `Free`, `Order`, `Current`.
- **Gendered adjectives.** `Rested`, `Untitled`, color names like `Priest White` need
  per-context gender/number agreement (fr *reposé/ée*, es *descansado/a*) — kept scoped, not
  folded to one shared key. Each such exception is commented at the key in its `enUS.lua`.
- **Matched pairs stay together.** `ON`/`OFF` (only `OFF` has a usable global) → keep *both*
  in `shared` rather than splitting the pair. Likewise any matched set.
- **Verb vs state.** `ENABLE`/`DISABLE` (verbs, Blizzard globals) are distinct keys from
  `ENABLED`/`DISABLED` (adjective states, consolidated to shared).

---

## 6. Tooling

All under `OneWoW_Workspace/bin/` unless noted. Run from the **OneWoW_Workspace** repo
root (Suite pre-commit calls the same scripts via `bin/run_devs.py`).

| Tool | Purpose | When |
|---|---|---|
| `locale_verify.py [Locales… \| files… \| (none)]` | **Parity gate.** Per locale vs `enUS`: key parity (missing/extra), matching printf specifiers (`%s`/`%d`/`%d%%`), and duplicate keys (checks `enUS` too). Accepts Locales dirs, individual locale files (mapped to their scope), or no args (scans every scope). Exits non-zero. | After every locale edit. **Wired as the `locale-parity` pre-commit hook** (runs on changed locale files; a changed `enUS.lua` re-checks all siblings). |
| `check_locale_encoding.py [Locales… \| files… \| (none)]` | **Encoding gate.** Register() string values must be real UTF-8, not Windows-1252 mojibake of UTF-8 (`ÐŸÐ¾Ñ‡Ñ‚Ð°` instead of `Почта`). Comments are ignored. Same args as `locale_verify`. | After locale edits, especially paste/import from a Windows editor. **Wired as the `locale-encoding` pre-commit hook** (changed `Locales/*.lua`). |
| `locale_keydiff.py [--scope X] [--consolidate]` | **Value analysis.** Flags Blizzard-global adoption candidates (B), cross-scope consolidation (C), and name-match traps (E); `--scope` prints a delete/blizzard/consolidate/translate worklist. Reads the enUS GlobalStrings (§4). | Before adding keys; when auditing a scope. |
| `locale_gen.py --enus … --locale … [--existing …] [--dict …] --out …` | Regenerate a locale file from the `enUS` template, overlaying existing translations + a `--dict` JSON; preserves layout/comments/escapes; handles addon-table **and** module-style headers; unmapped keys fall back to `enUS` (reported as TODO). | Authoring/refilling a whole locale. |
| `gen_esmx.py <Locales…>` | Generate `esMX` from `esES` + apply the Latin-American term map (`LATAM_SUBS`: `presionar`, `mouse`) + machine-draft header. Re-runnable (terms live in the tool). | After any `esES` change. |
| `locale_usage.py` | **Scope-leak audit** — keys read cross-scope through the wrong `L` binding (`ns.L` vs `OneWoW.L`). | After moving features between addons. |
| `locale_migrate.py` | Relocate keys between scopes (remove from src locales, insert into dst), e.g. core→`shared` or core→`OneWoW_QoL`. Inserts a `-- migrated from <scope> scope` provenance line on move. `--remove-migrate-comments all` (or `OneWoW,shared`, …) strips those lines after a scope move is settled. | Restructuring scopes; cleaning provenance after a move is complete. |
| `check_no_g_literal.py` | Guard: forbids `_G.CLOSE` / `_G["CLOSE"]` (use the bare global). | CI / pre-commit. |
| `check_tooltip_patterns.py` | **GlobalStrings match-source gate.** Builds `ITEM_SPELL_CHARGES` search patterns for all 11 Blizzard locales (`\|4` and plain `%d`); asserts use/equip/unique globals exist. Distinct from suite `locale-parity`. | When editing TooltipScanner or refreshing GlobalStrings. **Wired as `tooltip-globalstrings-patterns`.** |
| `/1wlocale` (in-game) | Per-scope key counts, shared/scope collisions, registered locales not in `SUPPORTED`. The only locale debug command (no debug builds). | In-client sanity check. |

---

## 7. Adding or changing a key

1. Route it (§1). If it's a Blizzard global or an existing `shared` key, you add **no key**.
2. Add to **`enUS.lua` first**, beside related keys (same section as neighbors).
3. Add the **same key to all 11 locales** in that scope. Machine-draft the 10 non-enUS values
   using the official Blizzard term per language (§4); head a fresh machine draft with
   `-- Machine-drafted — <loc>, pending native review.`. Don't hand-edit `esMX` — run `gen_esmx.py`.
4. Keep `%s`/`%d`/`|c…|r`/`\n` byte-identical across every locale file.
5. **Punctuation in string values** (not comments): use the ASCII table below. Do not put
   typographic Unicode (`→`, `—`, `…`, `«»`) in locale values — suite fonts omit those
   glyphs. CJK fullwidth punctuation (`。` `，` `「」`) is legitimate script, not this table.
6. **Gate before done:** `locale_keydiff.py --scope <Scope>` (no new keys in the BLIZZARD or
   CONSOLIDATE buckets unless you intend to route them), `locale_verify.py <Locales>`,
   and `check_locale_encoding.py <Locales>` (must exit 0).

**ASCII punctuation (locale values and player-facing Lua):**

| Glyph | ASCII |
| --- | --- |
| `→` / `←` | `>>` / `<<` (spaces around, same as existing Mail Lua) |
| `…` | `...` |
| `—` / `–` in a sentence | ` - ` |
| standalone empty placeholder | `-` |
| `×` | `x` (quantity: `" x"` / `"%s x%d"`) |
| middle dot as a list separator | `\|` with spaces (`gold \| items`) |
| `«` `»` `“` `”` `„` | ASCII `"` |
| `‘` `’` | ASCII `'` |

Icon-like glyphs (`★`, `▸`, `✓`, `●`, `○`, emoji) stay textures/atlases, not ASCII
fake-icons. Expand carets stay ASCII `>` / `v`. Comments may keep em dashes.

**Banned:** enUS-only additions; `L["KEY"] or "literal"` fallbacks (a miss already shows the
key name — use `OneWoW.Locale:GetOptional(scope, key)` for genuinely optional text); a scoped
key that shadows `shared`; and deleting a key that is referenced dynamically.

**Dynamic-reference audit (before deleting/adopting a key).** The call-site swap and key
deletion only handle *literal* `L["KEY"]` references. A key reached via a stored or constructed
string is invisible to a literal grep and breaks silently if removed:

- **Stored key strings** — `BUILTIN_LOCALE_KEYS = { ["Armor"] = "CAT_ARMOR" }`,
  `labelKey = "SORT_X"`, `{ "TAB_GENERAL", … }`. Audit:
  `grep -rnE '"KEY"' <addon> --include=*.lua | grep -v Locales`.
- **Constructed keys** — `"CAT_" .. upper(name)`, `L["FONT_WIDGET_SIZE_" .. n]`. No literal to
  grep; find the construction site and exclude every key it can produce.

---

## 8. Known gaps

- Machine-drafted locales (zhCN/zhTW/ptBR/itIT, plus machine-drafted koKR/EU and the esMX LatAm
  pass) await native-speaker review; files carry a `-- Machine-drafted … pending native review.` header.
