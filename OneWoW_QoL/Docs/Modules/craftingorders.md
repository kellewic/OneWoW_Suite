# Crafting Orders Overlay

Module id: `craftingorders` · Folder: `Modules/external/craftingorders/`

Replaces Blizzard's right-hand crafter order table on the profession Crafting
Orders page. Left recipe list, Search, Favorites, Back, and public claims
remaining stay Blizzard.

## Browse

Hook `SetCraftingOrderType`, `ShowGeneric`, and `SendOrderRequest` on the
`OrdersPage` instance (XML mixin copies those methods; mixin-table hooks after
`Blizzard_Professions` loads do not fire). Hide `BrowseFrame.OrderList` while
the overlay is shown. Patron / Guild / Personal are always a flat order list.

- **Tabs:** Public, Guild, Personal, Patron (`Enum.CraftingOrderType`).
- **Buckets:** Craftable now, Missing mats, and Recipe Unlearned. Public search
  results stay bucketed until you drill into a recipe; Ready/Missing is exact on
  flat lists. Unlearned never sits in Missing mats. Features can hide the
  Recipe Unlearned section.
  Rows use the same striped `BACKDROP_INNER` chrome as Catalog lists.
  Column headers share the same right-edge lanes as the row widgets.
  Each You Provide / Customer Provides / You Receive cluster is a fixed-width
  lane packed left-to-right, so unused slots cannot slide icons into the next
  column. Features owns the layout: show, hide, and reorder those lanes
  (Order name stays pinned left). Defaults show You Provide, Cart,
  Profit / Loss, Time, and Craft, in that order. Gold, Customer Provides,
  and You Receive start hidden. Icon sizes default to 27. "Only mats I still
  need" starts on. Profit / Loss prices default to OneWoW. Compact View
  starts on (Blizzard's 20px row height, icons capped at 16; icon sliders
  apply when Compact View is off). Features has a width slider for each
  shown column (maximums; they still apply in Compact View). Hide list
  scrollbar is off by default. Reset restores the default view.
  The layout applies in place (no frame rebuilds): slider changes resize
  the existing icons live via `ApplyOverlayLayout`. Icon lanes reserve
  width only for the icon slots the current entry list actually uses
  (`SetLaneCounts`, derived on each refresh); a width slider sets the
  lane's preferred width, and the cluster can still grow it if the icons
  need more room. Hidden columns cost zero width. Slider values are the
  preference and render as-is while the visible columns fit the row.
  When they do not, icons scale toward `SIZE_MIN` (skipped in Compact
  View, already 16), then every column width scales toward its floor,
  then the order name can go narrower. No column ever hides
  in normal use; the per-row clipping host (`LaneStripBudget`) exists only
  as a last-resort guard below those floors. The overlay reports its
  interior width via `SetRowContentWidth` on create/show/resize. The list
  scrollbar hides when there is nothing to scroll, or when Hide list
  scrollbar is on; the mouse wheel still scrolls.
- **Mats:** You Provide vs Customer Provides icon columns. Customer Provides is
  every reagent already allocated on the order (`order.reagents` covers that
  slot). You Provide is required recipe slots with no allocation. Owned count
  is bags + character bank + reagent bank + warband bank. Rewards are
  item/currency/gold icons with counts. Optional Gold shows **Your Cut**
  (commission minus Consortium Cut) as a money string; hover a row for
  commission, Consortium Cut, and Your Cut (always, including a 0 cut).
  Public recipe buckets have no cut on the API, so Gold stays as max tip
  and the hover also shows average commission when it differs.
  Optional Profit / Loss is the same net tip, plus
  valued reward items, minus valued You Provide reagents (customer mats are
  not subtracted). Hover a row for that gold breakdown, each reward and
  You Provide line (unpriced items list as Unknown and are skipped in the
  total), and the total. Prices come from `OneWoW.ItemPrices` (TSM, Auctionator, or
  OneWoW scan). A missing price skips that term in the number; nothing is invented.
  Its header reads `+ / - [icon]` as one string (identical in every locale;
  the source icon is |T-embedded in the label so it always sits directly
  after the text): TSM / Auctionator show their addon icon, OneWoW shows the
  brand icon for the player's icon theme (`GetBrandIcon`). Hover the header
  (or Features) for the source name; TSM also shows the price string from
  QoL Tooltips > Value (default `dbmarket`). The full
  "Profit / Loss" name stays on the Features panel.
  Optional Time Left uses Blizzard one-letter abbr (`6 d 15 h 10 m`); hover
  a row for the full `SecondsToTime` string. The lane is wide enough for
  that compact form even as the only extra column.
- **Craft column:** Craftable now rows (not recrafts) get the same Start /
  Craft / Complete click-mirror as the order page. Start loads that order
  behind the list so you stay on the overlay. Other rows dim until that
  order is completed. Recrafts and Missing mats stay without this button.
  Hide or move the column in Features like the others.
- **Cart:** one shopping-cart control per row that still needs crafter mats
  (Missing mats and Recipe Unlearned), in its own column. If no visible row
  would show a cart (Craftable now only, or public recipe buckets), the
  column takes no width even when enabled in Features.
- **Default on:** the module starts on in QoL Features (account-wide). Hide
  unlearned recipes starts on. Use WoW List starts off (One UI list). Turning
  the module off keeps it off on every character.
- **Incompatible addons:** if PatronOffers or PublicOrdersReagentsColumn
  (No Mats No Make) is enabled, Crafting Orders cannot be turned on. Features
  names the addon and asks you to disable it and try again. Off fully
  restores Blizzard's list.
- **WoW UI:** a **WoW UI** / **One UI** button sits on the order-type tab row
  (and a Features toggle) to swap back to Blizzard's table without disabling
  the module. A gear beside it opens this module in QoL Features.
- **Craftable now:** recipe learned and every crafter-provided required reagent
  is in bags, bank, reagent bank, or warband bank. Fully customer-supplied
  counts as now.
- **Patron sort:** knowledge points, then Artisan's Acuity, then gold, until
  you click a header. Click Order, Gold, Profit / Loss, or Time to sort
  each section; click again to reverse. Features Reset clears the sort.
  Column reorder stays in Features, not overlay header drag.
- **Claimed order:** a started order is re-injected into Craftable now (it
  drops off the browse snapshot) and sorted with the rest of the section, so
  Start / Create / Complete stay on the same row.
- **Personal:** right-click Decline matches Blizzard (`RejectOrder`).

Weekly "Services Requested" quest IDs live in `rewards.lua` (Midnight first,
Khaz Algar fallback). Public claims use `GetOrderClaimInfo`, not the weekly.

## Cross-unit

- Shopping List: `OneWoW_ShoppingList_API` (`AddItems`, `CreateNamedList`,
  active list). Call-time presence plus `RegisterDataReadyWatcher`. No
  `OptionalDeps`.
- Item prices: `OneWoW.ItemPrices:GetUnitAHPriceFrom` for the Profit / Loss
  column. No direct TSM / Auctionator calls and no `OptionalDeps` for those
  addons.
- Storage elsewhere: hover a You Provide icon; uses
  `OneWoW_AltTracker_Storage_API.GetItemIndex()` after data-ready, then
  `RegisterStorageChanged`.

## Magic button

Click-mirrors Blizzard Start / Create / Complete via
`InsecureActionButtonTemplate` and a short `/click` chain. The inner click
target stays shown (alpha 0) because `/click` ignores hidden frames. On the
order page the visible button stays on `OrderInfo` (left) so the mouse does
not move. The list Craft column uses the same inner `/click`; `OrderView`
stays shown behind the browse overlay. It wears the standard suite button chrome by hand
(`BACKDROP_INNER`, `BTN_NORMAL`/`BTN_HOVER`/`BTN_PRESSED`, themed border,
muted label when disabled) since it cannot be a `CreateFitTextButton`.
Concentration is an icon beside Craft, tooltip only.
Does not call `ClaimOrder` from Lua. Create-time attributes go through
`RunWhenUnrestricted`; PreClick sets `clickbutton` only when unprotected.
`OrderView:SetOverrideCastBarActive` is no-op'd while the module is on (restore
on disable) so the stock override bar does not fight secrets.
