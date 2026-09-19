# SearchCatalog

SearchCatalog is the suite's registry of **named search expressions**, published on the `OneWoW` global as `OneWoW.SearchCatalog` (a core service in `OneWoW/Services/`). It answers one question for the whole suite: given a name someone typed into a search box, what expression does it stand for?

Source: [`OneWoW/Services/SearchCatalog.lua`](../Services/SearchCatalog.lua).

Related: [`PREDICATE_ENGINE.md`](PREDICATE_ENGINE.md) evaluates the expressions this file names. [`OneWoW_Bags/Docs/SEARCH_SYNTAX.md`](../../OneWoW_Bags/Docs/SEARCH_SYNTAX.md) is the user-facing syntax. [`ARCHITECTURE.md`](ARCHITECTURE.md) is the suite context.

---

## The problem it solves

Before it existed there were three parallel systems for "a name that stands for an expression": keyword aliases (`#token`), named expressions (`SAVED(Name)`), and Bags categories (`CATEGORY(Name)`). Each stored its own names, and each had the same defect — **renaming broke every stored expression that referenced the old name.** Expression text lives in a dozen places across five addons: Bags category rules, Mail shipment matches, QoL filters, overlay definitions, search history, saved profiles. Nothing could rewrite all of it, so renames silently broke rules the user could not see.

The catalog replaces all three with one model:

- Every entry has a **stable internal id** that never changes and never appears in expression text.
- Renaming keeps the old name as a **former name** that still resolves.
- Therefore **no store is ever rewritten on rename**, and stale text keeps working.

---

## Entry model

```lua
{
    id          = "sc_1785026522_2351",  -- stable, internal, never in expression text
    kind        = "saved",
    name        = "E Mats",              -- current display name
    formerNames = { "Enchanting Mats" }, -- oldest first, capped at MAX_FORMER_NAMES (5)
    body        = "#enchanting_mats",    -- the expression this name stands for
}
```

### Kinds

| kind | written as | storage | editable from |
| --- | --- | --- | --- |
| `token` | `#name` | core SV (`native`) | Search Shortcuts tab |
| `saved` | `SAVED(Name)` | core SV (`native`) | Search Shortcuts tab |
| `category` | `CATEGORY(Name)` | Bags, via a registered provider | Bags category manager |

`KINDS` drives behaviour rather than branching at call sites: `pattern` is the name grammar, `lowerNames` forces lowercase (tokens are written `#name`, so case would mislead), and `isReserved` rejects names the engine already owns. `native` says whether the entry lives in core SavedVariables or behind a provider.

Namespaces are **kind-scoped**: `#sell`, `SAVED(Sell)` and `CATEGORY(Sell)` may be three different things. That was a deliberate call — it makes name collision a non-issue and duplicate *bodies* the likely mistake instead, which is what the duplicate-body warning guards.

### The former-name uniqueness invariant

A name resolves to at most one entry. Current names beat former names; a name being claimed is stripped from whichever entry held it as a former name. `ClaimName` enforces this in one place, so a provider creating an entry through its own code path cannot leave two entries answering to one name.

`MAX_FORMER_NAMES` caps the list per entry. When a rename would overflow it, the **oldest** former name is evicted — which is silent data loss if anything still references it, hence the preflight below.

---

## Reading

```lua
local SC = OneWoW.SearchCatalog

SC:Resolve(kind, name)      --> entry, status   status: "current" | "former" | nil
SC:GetBody(kind, name)      --> body, status    nil + "missing"/"empty" when unusable
SC:GetById(kind, id)        --> entry
SC:GetAll(kind)             --> entry[]         sorted by name, case-insensitive
SC:ValidateName(kind, name) --> normalized, errorKey
SC:ValidateWritableName(kind, name, exceptId?) --> normalized, errorKey
SC:RegisterChangedCallback(id, fn)  -- fire after mutations (batched via WithBatch)
SC:UnregisterChangedCallback(id)
```

`Resolve` returning `status == "former"` is not an error — it resolved, through a redirect. It is the set a prune or a name reclaim would break, which is why the lint reports it separately from a genuine miss.

`ValidateName` is public so no other file restates a name grammar. `ValidateWritableName` adds reserved / live-clash checks for create and rename before confirm dialogs. Both return the catalog's own `CATALOG_*` error codes; callers map those to their own message keys (see `SAVED_ERRORS` / `ALIAS_ERRORS` and `SearchExpand:MapCatalogError`) rather than letting internal codes reach user-facing text.

---

## Writing

```lua
SC:Set(kind, name, body)        --> entry, errorKey   create, or update an existing body
SC:Rename(kind, id, newName)    --> ok, errorKey
SC:Delete(kind, id)             --> ok
SC:ClaimName(kind, name)        -- providers only, when creating
SC:RenameExternal(kind, id, newName) -- providers only
```

Native kinds only, except the two provider entry points. `RenameExternal` keeps every rule about what a rename *means* in one place — former-name bookkeeping, the cap, the uniqueness invariant, index invalidation — because a provider hand-rolling it would get the easy half right and the invariant wrong.

### Batching

Change notification is expensive downstream: one fire drops PredicateEngine's token and expression caches and drags Bags through a re-categorize plus a layout refresh.

```lua
SC:WithBatch(function()
    -- many mutations here, one notification at the end
end)
```

`BeginBatch` / `EndBatch` are the manual form. `WithBatch` is `pcall`-wrapped so an error inside cannot leave the depth counter stuck.

---

## Preflight: warn before destructive writes

The catalog **never prompts**. Each hazardous write has a matching preflight that returns a structured account of what it would cost — or `nil` when it costs nothing — and the mutators stay unconditional so a caller that means it can still force through.

```lua
SC:PreflightDelete(kind, id)              --> report | nil
SC:PreflightClaim(kind, name, exceptId)   --> report | nil
SC:PreflightRename(kind, id, newName)     --> report | nil
```

Three hazards exist, and they are the only ways the no-rewrite promise can still change behaviour:

1. **Delete** — the entry's current name *and every former name it answers to* stop resolving.
2. **Reclaim** — taking a name that is another entry's former name strips it from that entry, and every stale reference silently means something else. Worse, deleting the *new* holder later does not give the name back: those references degrade to matching nothing.
3. **Cap eviction** — a rename that overflows `MAX_FORMER_NAMES` drops the oldest former name.

A report is `{ action, kind, losses[], total, restorableTotal, incomplete[] }`. It is `nil` only when **both** counts are zero.

`OneWoW_GUI:ConfirmCatalogWrite(report, onProceed, opts)` turns a report into a question. A `nil` report runs `onProceed` immediately, so no call site branches on whether a warning is warranted.

---

## The reference index

Any store that persists user-authored expression text registers itself, so the catalog can answer "who references this name".

```lua
SC:RegisterExpressionSource(id, {
    sourceLabel = "Mail — Shipments",
    class       = "live",   -- or "restorable"; defaults to "live"
    Enumerate   = function()
        return { { expression = "...", label = "Weekly mats" } }
    end,
})
```

`label` identifies the individual item inside the store, so a report can point somewhere rather than count. "Mail — Shipments (1: *Weekly mats*)" is actionable; "3 references" is not.

### Source classes

| class | example | in a delete warning | in prune / lint |
| --- | --- | --- | --- |
| `live` | Bags categories, Mail shipments, QoL filters, catalog bodies | headline count | yes |
| `restorable` | saved profiles, the Bags import undo snapshot | separate line | yes |

A `restorable` source holds an alternate state the user can switch to. Nothing breaks today; it breaks when that state is loaded. Counting the two together inflates a **safety** number, and a warning that overstates gets dismissed — so the report carries `total` / `groups` and `restorableTotal` / `restorableGroups` separately. Both halves are always returned rather than selected by an argument, so a caller cannot ask for the wrong one.

Note the distinction is about *references*, not copies. A profile that stores an entry's **definition** is not a reference to it — restoring the profile brings the entry back. A profile that stores an expression **pointing at** the name is, because restoring gives back the text without the target.

### Queries

```lua
SC:FindReferences(kind, name)        --> report, grouped by source
SC:CountReferencesByName(kind)       --> { [name] = count }, live sources only
SC:GetUnscannableAddons()            --> string[] installed but not loaded
```

`CountReferencesByName` walks every source **once** and counts what it finds. `FindReferences` re-walks per call, which is right for a single preflight and quadratic for a list.

### Completeness

Every answer is a lower bound when a suite unit that owns expressions is installed but not loaded — its SavedVariables are not in memory. `GetUnscannableAddons` reports that, and every consumer discloses it rather than presenting a partial count as whole. There is no way to fix this without loading foreign SV.

---

## Lint

```lua
SC:Lint()        --> findings[], incomplete[]   findings: { kind, name, status, sourceLabel, label }
SC:LintExtras()  --> groups[] contributed by registered lint sources
```

`Lint` classifies every reference in every registered source. A `#token` that is a built-in keyword is not a catalog reference at all, and neither is a reserved sentinel, so both are skipped.

`RegisterLintSource` is the second registry, and answers a different question: not "who references this name" but "what else is wrong in here". The owner supplies **finished text**, because why something is wrong is its knowledge — this is what keeps Bags' `UNKNOWN_TYPE` and `SUBTYPE_NOT_IN_TYPE` distinct, where collapsing them would send users to re-pick a name that is already correct.

### Known limitation: the scanner is textual

`KIND_REF_PATTERN` regexes over raw expression text, so a `#` inside a quoted string — `tooltip~"#1 seller"` — reads as a token reference. Consequences, in order of how much they matter: the lint reports a spurious `missing` finding; a prune keeps a former name it did not need to (over-retention, the safe direction); the export closure resolves nothing and includes nothing. Fixing it properly means tokenizing rather than pattern-matching, reusing PredicateEngine's tokenizer, which knows about quoting.

---

## Pruning former names

```lua
SC:PruneFormerNames({ dryRun = true })   --> count, blockedBy, dropped[]
```

A former name exists only to keep stale text resolving. Once nothing points at it, it is dead weight occupying a capped slot.

This is **the one operation here that destroys data rather than warning about it**, and a source that under-reports makes it silent. Hence:

- `dryRun` is how the UI previews it, and the default in `/owsc prune`.
- It **refuses to run** when a unit that owns expressions is installed but not loaded, because pruning against a partial view deletes exactly the redirects that unit still needs. `force` overrides, deliberately awkwardly.
- There is **no automatic invocation**. Running it unattended on login would put the riskiest path on the most frequent trigger, before anything could show what it removed.

Both live and restorable sources count here — a former name must outlive any snapshot depending on it.

---

## Export and import

Core owns the payload format; Bags' import/export carries it.

```lua
SC:BuildExportPayload(seeds)   --> payload, referencedCategories
SC:PlanImport(payload)         --> plan[]      per item: create | merge | conflict
SC:ApplyImportPlan(plan)       --> created[]   { kind, id }
SC:RollbackImportedEntries(created)
```

Export takes the **transitive closure** from a set of seed expressions: a category referencing `SAVED(Sell)` pulls in `Sell`, which pulls in whatever `Sell` references, across all three kinds. Bodies are canonicalized on the way out — former names are rewritten to current ones — so a payload does not carry redirects the receiver has no reason to know about.

Import returns a **plan** rather than applying:

- `create` — no local entry of that name. Carries `reclaims` when the name is some entry's former name, so the UI can say so.
- `merge` — identical body. A no-op.
- `conflict` — same name, different body. Carries `existingBody`, `suggestedName`, and `options` (`import_as_new` / `keep_mine`) for the UI to resolve.

Because only `create` and `import_as_new` write, `ApplyImportPlan`'s returned `created` list is a **complete delta** of what an import did — which is what makes `RollbackImportedEntries` a precise undo.

> Rolling back an import that *reclaimed* a former name does not restore the old redirect. The reclaimed entry is deleted, and the name then resolves to nothing rather than to its former holder.

---

## Slash command

`/owsc` (`/1wsc`) — `lint`, `sources`, `prune`, `prune apply`, `prune apply force`. Named for the **search** catalog; the OneWoW_Catalog addon owns `/1wcat`. See [`suitecommands.md`](../../suitecommands.md).

---

## Storage

`OneWoW_DB.global.searchCatalog`:

```lua
searchCatalog = {
    schemaVersion = 1,
    entries = {
        ["sc_1785026522_2351"] = { id = ..., kind = ..., name = ..., body = ..., formerNames = {...}, created = ... },
    },
}
```

Native kinds only. Provider-backed kinds keep their entries in their own addon's SavedVariables and expose them through the provider contract — storage locality was a deliberate decision, so a unit owns its own data and an uninstalled unit simply contributes nothing.

A saved profile captures this table wholesale and restores it by deep copy, which preserves ids and former names. That is why a profile load is safe where a name-keyed round-trip would not be: re-creating entries by name mints new ids and drops every redirect.

---

## Provider contract

For non-native kinds:

```lua
SC:RegisterProvider("category", {
    Enumerate = function() ... end,   -- read-only: entry[]
    Get       = function(id) ... end,
    SetName   = function(id, name) ... end,
})
```

Read-only enumeration plus catalog-mediated rename. Providers never hand-roll `formerNames`; `RenameExternal` and `ClaimName` keep the uniqueness invariant and the cap in one place. `formerNames` is passed by reference, so the catalog's bookkeeping writes into the provider's own record.

Registration is deliberately **silent** — it does not fire a change notification. It happens during load with nothing listening, and firing would drag every consumer through a rebuild for a kind whose contents have not changed yet.

---

## Cache invalidation vs notification

Two things that look alike and are not:

- `DropIndex(kind)` (file-local) — drops the cached name index. Silent.
- `SC:InvalidateKind(kind)` — that, plus `FireChanged()`.

They shared a name once, and a call site meaning "and tell the UI" read identically to one meaning "just drop the cache". That is how the prune ended up mutating former names with nothing listening. If you add a mutation path, **decide which you mean.**
