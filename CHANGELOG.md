# Changelog

## 0.4.0 — Gray junk and identical copies

- **Gray junk is always sold.** Poor-quality items in bags are sold like the vendor's **Sell Junk** button, before appearance, upgrade, and category checks (those checks protect useful gear, never junk). Hard protections still apply: quest items, heirlooms, manual keep/bank rules, Warband/account-bound items (unless allowed), saved equipment sets, special bindings, locked or worthless items. Items with unconfirmed tooltip data still go to review.
- **For identical copies, the more valuable one is sold.** When two items have exactly the same item level and stats, only as many cheaper copies as the slot needs stay protected as the best in that category. More expensive copies follow the usual sale rules, since they earn more gold. The price difference must be at least 1 silver. Works with GearMemory 0.3.0-beta, which equips the cheaper twin when the equipped copy is the more expensive one.
- Validation: offline simulations only (junk rules and identical-item logic); in-game validation is ongoing.

## 0.3.0 — English interface, smarter PvP, and bank handling

- **English and Portuguese.** The interface, messages, and tooltips follow the game client language (Portuguese for ptBR; English for all other clients). New English commands: `/bm simulate`, `/bm simulate all`, `/bm diagnostics`, `/bm sell`, and `/bm bank` (Portuguese commands still work).
- **Dry run.** `/bm simulate` lists what would be sold and why without selling anything. Item tooltips now show BagMemory's decision and reason.
- **PvP is evaluated separately.** PvP gear is compared only with PvP gear at its effective (post-buff) item level, and PvE only with PvE. A piece is protected only when it is close to the best in its slot, not the character average. A PvP item whose scaling cannot be read no longer blocks the rest of its category.
- **Tier and equipment sets.** Set pieces and saved-set pieces lose protection once they fall more than 25 effective item levels behind the best item in that slot. Crafted gear is never sold because it can be recrafted.
- **Older content.** Consumables, spare bags, miscellaneous goods, and common materials from earlier expansions are sold when a vendor will buy them. PvP consumables, mounts, pets, and toys are kept.
- **Bank.** The bank is reread whenever it opens or its tab changes, including the Warband bank. Items marked for the bank are deposited only in the character bank, and items marked for sale are withdrawn from the active tab. Bank decisions are logged for diagnostics.
- **Auction House.** BagMemory no longer queries the Auction House on its own. Items marked for the AH are tinted yellow for manual listing.

## 0.2.5 — Scan when bags open

- Inventory, data-loading, and equipment-change listeners are registered only while a native bag is open and removed when the last bag closes.
- Opening a bag rereads the inventory; closing it before a scheduled scan cancels the background analysis.
- Background scans triggered by quests, login, or specialization changes also wait for bags to open.
- Direct merchant/bank/AH interactions and manual commands continue reading the data needed for authorized operations.
- Hidden bag icons no longer trigger unnecessary queries.
- In-game validation is pending; no CPU measurements were made for this update.

## 0.2.4 — Fewer scans and lower CPU cost

- Item-data events now trigger a scan only when BagMemory is waiting for that item ID.
- Pending requests are reused; loading failures no longer trigger repeated analysis cycles.
- Automatic scans are deferred during combat and coalesced into a 0.25-second window after combat.
- Localized tooltip patterns and constant tables are prepared once.
- Binding, quest, refund, PvP, and sale rules continue to be evaluated using current data.
- Visual validation and in-game performance measurements are still pending.

## 0.2.3 — Warband bank and separate equipment management

- Added **Allow Warband Item Sales**, off by default and saved per character.
- The option bypasses only account/Warband binding protection. Other rules still apply, including quest, heirloom, best-in-category, manual, and uncertain-data protections.
- Account/Warband gear is never sent to the AH, even before it is character-bound; with the bypass enabled, it can follow the normal NPC sale rules. Materials remain automatically protected.
- Changing the option stops the previous queue and immediately refreshes classification, desaturation, and merchant candidates; each sale still revalidates its item.
- Removed equipment suggestions, the Equip button, Auto/PvE/PvP context, and automatic equipment changes. Full Auto manages the bank, item quests, and sales without changing equipped gear.
- Retained equipped-item reads and PvE/PvP comparison protection; class compatibility lives in `ClassRules.lua`.
- Migrates old equipment preferences and clears suggestions stored in bank snapshots.
- Lua syntax was checked without executing modules or tests; in-game validation is still pending.

## 0.2.2 — Class suitability and batched sales

- Best-in-category protection now excludes gear unsuitable for the class.
- Incompatible character-bound armor can be sold regardless of item level, PvP stats, upgrades, or appearance; quest items, heirlooms, special items, and explicit protections remain safe.
- Bound-to-Warband/account items are suggested for the Warband bank and are not automatically sold or deposited in the personal bank.
- Replaced the sequential queue with native batches of up to 12 sales, confirmed together through bag state and buyback.
- Bag and merchant events confirm a batch; the next sales no longer wait for individual delays.
- Intact rejections get limited retries in smaller batches; ambiguous results stop the queue.
- Semi Auto retains its 12-sale limit per interaction; authorized Full Auto continues through all candidates.
- Lua syntax was checked; real performance and in-game interactions still need validation.

## 0.2.1 — Sale pacing and diagnostics

- Removed repeated full-stack analysis; use a lightweight inventory check and reread each item before sale.
- Bag changes caused by our own sales no longer rebuild the full analysis during the queue; external changes invalidate the context.
- Reduced scheduled sale delays while retaining global removal and buyback confirmation.
- If the game rejects an item and it remains intact, other candidates continue; ambiguous removal still requires review.
- Shows mode, progress, and when the Semi Auto limit stops a batch; authorized Full Auto remains unlimited.
- Gear proven inferior to the best carried/equipped items no longer requires a bank visit first; old bank records never justify discarding items.
- Added `/bm diagnostico` to show the version and reasons stacks remain.
- Lua syntax was checked; performance measurements and in-game operation are still needed.

## 0.2.0 — Bank, quests, and equipment

- Semi Auto manages bags/bank; Full Auto adds equipment and item quests, with explicit per-character authorization.
- A complete bank read participates in best-item protection; old records prevent equipment sales.
- Deposits storable items, withdraws sellable items, and desaturates items in Blizzard's personal bank.
- Quest items/starters are excluded from sale; active items are available in bags; Full Auto accepts only the exact offer from an item.
- Suggestions consider class, armor, specialization, stats, slots, weapons, and unique-item limits; Semi Auto has an Equip Suggestions button.
- Native out-of-combat swaps in Full Auto, with identity confirmation and review for effects, sets, and protections.
- Adds Auto/PvE/PvP equipment context and a view of equipped items.
- Full Auto can exceed the 12 buyback entries; pause, revocation, and blockers stop queues.
- Beta: the new operations still need validation in WoW.

## 0.1.0 — Initial beta

- Character-first cleanup based on equipped item level and a configurable margin.
- Best-in-category protection across carried and equipped items, including ties and paired slots.
- Separate PvE/PvP comparisons, localized PvP tooltip parsing, and conservative PvP preservation.
- Automatic vendor batches, buyback confirmation, and repair with optional guild funds.
- Recent Auction House observations for low-profit vendor decisions; native auction preparation.
- Blizzard bag desaturation, per-character rules, searchable preview, and sale history.
- Preserves heirlooms, equipment sets, uncollected appearances, special items, and uncertain data.
