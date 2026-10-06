# BagMemory 0.2.5 — WoW Retail beta

**Clean bags. Keep your best gear.** A dark interface with turquoise accents, following MuscleMemory's visual direction.

## Modes and commands

Open `/bm` or `/bagmemory`. The list shows bags, bank items, and equipped gear, with each item's destination and reason. Settings and authorization are saved per character.

| Mode | Behavior |
| --- | --- |
| **Semi Auto**, default | Manages bags and bank, sells and repairs according to your settings. It does not automatically start or accept quests. |
| **Full Auto**, authorized | Also withdraws quest items from the bank and starts or accepts quests offered by items. It sells all candidates, even beyond the buyback limit. |

- `/bm full`: authorization uses an unchecked checkbox and requires explicit confirmation. The mode button revokes authorization and returns to Semi Auto.
- `/bm pausa`: pauses or resumes automatic operations.
- `/bm banco`: organizes the accessible personal bank.
- `/bm vender`: starts another batch while a merchant is open.
- `/bm ah`: checks bag prices while the Auction House is open.
- `/bm diagnostico`: shows the version, mode, sale summary, and main reasons items were kept.

Authorization is saved for this character. Expanding its scope requires new confirmation. Item rules can be reviewed in the list and manually protected by ID.

## Item level and progression

The sale threshold is based first on **equipped item level minus the margin**, initially **10**, with an inclusive limit. With 232 equipped and 242 overall, candidates are items up to 222. Overall item level and the season's M+2 reference provide context; they do not determine what is discarded.

Before applying the threshold, BagMemory compares bags, personal bank, and equipped items by category, type, and primary stats. It keeps the best PvE/PvP pieces, including ties. At least two rings and dual-wield weapons are kept; trinkets are protected by their effects. A 220 pair of pants stays if it is your best pair, even with a 232 average; a 212 pair may be inferior.

Only gear appropriate for your class receives best-in-category protection. Cloth, leather, and mail are not useful armor alternatives for a Warrior: character-bound pieces are marked for sale even if they have high item level, PvP stats, or upgrades. Cloaks, rings, and neutral slots are still evaluated for usefulness without a plate requirement. Weapon and stat checks consider the entire class, preserving alternatives for other specializations.

Items identified as Warband/account-bound are **Suggest Warband Bank** by default. The **Allow Warband item sales** checkbox is off by default and saved per character; it bypasses only this binding protection. When enabled, an item still follows the normal rules: it can be sold to an NPC when classified **Sell**, but it does not automatically become junk. Account/Warband-bound gear follows the NPC sale path for bound items, even before it is character-bound; it is never sent to the Auction House. Account materials remain protected automatically. Turning the option off restores this protection. Changing it cancels the previous queue, refreshes classification and desaturation, and revalidates the sale. Quests, heirlooms, uncertain data, manual protection, and the best item in a category remain protected. Tradable gear unsuitable for the class follows the Auction House evaluation; heirlooms, special items, quest items, refundable/tradable items, saved sets, and manually protected items remain protected. An uncollected appearance does not block a requested sale of gear proven unsuitable for the class; the classification reason explains this decision.

Gear inferior to the best items in your bags or equipped can be sold without first visiting the bank. Until the bank is confirmed, its old records are excluded from comparisons and can never justify discarding the best item currently known. Open the bank to include its alternatives. Confirmation remains after closing the bank until a change invalidates it. Incomplete bank records never authorize withdrawing or selling bank items.

## Equipment

BagMemory reads equipped items to compare and protect the best pieces in each PvE and PvP category. It does not suggest swaps, equip items, or move equipped gear. Equipment management belongs to the independent **GearMemory** addon; legacy equipment preferences and saved BagMemory suggestions are discarded during migration.

## Quests and bank

**Quest items and quest starters are never sold**, even by manual rule. Items required by active quests stay in your bags. Items for completed quests can be stored if the bank allows it; uncertain quest requirements remain protected. Semi Auto offers **Start Quest** to use the selected item, leaving acceptance to the player.

Full Auto attempts to use and accept only the quest offered by the identified item, when the quest log has room. It does not indiscriminately accept NPC quests or turn in quests automatically. Unconfirmed offers remain protected for manual use.

The organizer deposits **Store in Bank** items first to free space, then withdraws items marked **Sell**. Full Auto also withdraws required quest items and quest offers. Items with no sale value are suggested for storage; consumables, usable items, and utilities remain available. Manual rules can request storage when the protections allow it.

Only the **character bank**, in currently accessible modern personal tabs, is managed. Guild and Warband/account banks are not moved. Open the bank, then the merchant; the addon does not create remote access. Lack of space, a busy cursor, combat, incomplete data, or closing a window interrupts operations.

## Sales, repairs, and protections

Selling, repairing, bank organization, desaturation, and Auction House lookups are enabled by default in Semi Auto. **Protect upgradeable gear** is also enabled by default.

Semi Auto sells up to **12 stacks per batch**; review the result and click Sell to continue. Full Auto removes this limit: **sales beyond the most recent 12 may not be recoverable**. Buyback depends on the game. A 60-sale history does not guarantee recovery. Opening Buyback interrupts automatic selling for that interaction.

Each sale revalidates item identity, count, and rules, then confirms removal/buyback. Repairs require enough currency. Guild repairs are optional, off by default, and require permission, balance, and a spending limit.

The global analysis is reused while only BagMemory's own sales change the bags; external changes require a new analysis. Each candidate is reread, but **up to 12 sales are submitted in one batch**, without a per-sale delay. Bag/merchant events confirm the batch through global item removal and recent buyback entries; a timer is only a fallback for delayed events. Full Auto continues with subsequent batches. Rejected sales whose items remain intact get up to two retries in smaller batches; ambiguous removal stops the queue. Latency and server limits can reduce the pace. Chat and the window show progress, mode, and why the process stopped.

Heirlooms, legendaries, artifacts, quests, best-in-category items, identified PvP gear, saved sets, account items (when the checkbox is off), refundable/tradable items, uncollected appearances, set pieces, and trinkets are protected from sale. Uncertain information is left for review. Manual rules do not remove these protections.

## Auction House and older items

An older expansion alone does not make materials or collectibles junk. Bound inferior gear can be sold after protections are checked. Tradable materials/gear go to an NPC only when a recent, complete Auction House quote is confirmed.

BagMemory compares the full stack's listed price minus a 5% cut against its NPC value. The initial minimum profit is 5 gold. Quotes expire after 12 hours and are saved per character/realm. Without complete data or active listings, the item is kept. A listed price does not guarantee a sale; this beta does not estimate demand, time to sell, or deposit cost.

Lookups require the Auction House to be open and respect its request pacing. **Prepare in the Auction House** selects an item in the native window; the player confirms price, quantity, deposit, and posting, including in Full Auto. The mode respects Blizzard's interaction requirements.

## Compatibility and validation

Interface 120100, with no required libraries. Items marked Sell are desaturated in bags and the default Blizzard personal bank. Other addons' interfaces require specific integration.

This version's Lua syntax was checked with `loadfile`; the modules were not executed. No behavior tests were run. **In-game validation is still required** for the checkbox, UI, localized PvP data, bank, quest offers, sale/buyback, repairs, and coexistence with other addons. Syntax checking does not replace the game client. The historical harness in `tests/run.lua` predates GearMemory's separation.

## Performance

Automatic inventory scans are coalesced over 0.25 seconds, deferred during combat, and run only while bags are open. The menu still allows a manual refresh.

## Inventory analysis

Item events and background scans are suspended while the native bags are closed. Opening a bag refreshes the analysis; during combat, automatic refresh waits until combat ends. Direct merchant/bank/Auction House operations and manual menu actions still perform the required reads. GearMemory starts automatic equipment only while bags are open; closing the bags stops its automatic sequence.
