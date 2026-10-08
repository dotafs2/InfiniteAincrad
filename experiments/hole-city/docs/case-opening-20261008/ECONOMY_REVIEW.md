# Case-opening economy and persistence review

Date: 2026-10-08. The initial review was read-only. The subsequently authorized
transaction implementation now changes only `fidelity/game.gd` and adds
`tests/skin_case_transaction_acceptance.gd`. No engines, real player saves,
payments or accounts were used by this worker. Root owns UI integration and
running acceptance. The reel itself is outside this worker's implementation.

## Implemented API contract

- `open_skin_case()` returns a compact receipt with `ok: true` and `resumed:
  false` after the atomic save, or `resumed: true` for the existing paid result.
  Failure returns the existing `{ok: false, message, ...}` shape. A title-state
  pending result resumes before wallet or sold-out checks, including the final
  skin when the player has zero coins left.
- `pending_skin_case()` returns a newly built, sanitized deep copy or `{}`.
  Fields are `schema: 1`, `serial`, `case_id: "skin-case-N"`, `id`, `rarity`,
  `price`, `presentation_seed`, and `odds`. Odds contain six `entries` with
  `rarity`, `weight`, `count`, `chance`, plus `total_weight`, `guarantee`, and
  `counters`. No raw catalog, complete ID list or generated reel is persisted.
- `acknowledge_skin_case(case_id)` returns true only when the matching receipt
  is cleared and saved. Wrong/stale/repeated acknowledgement returns false
  without mutation. Failed persistence restores the receipt for retry.
- Collection save keys are `case_serial` and `pending_case`. Debit, ownership,
  pity and this receipt use one temporary-file/rename commit. A restored receipt
  can only reference an already-owned catalog skin; it never creates ownership.
  Odds probabilities are re-derived from saved ticket weights, unknown fields
  are dropped, and invalid presentation metadata cannot alter economic state.
- As explicitly directed for the new case flow, opening does **not** change
  equipment. The result's EQUIP action uses existing `select_skin(id)` on the
  already-owned winner. Legacy `unlock_random_skin(group)` still auto-equips,
  but every old acquisition path rejects new spending while a case is pending.
- A dedicated isolated transaction suite covers durable reentry, delayed
  repeat callbacks, wrong acknowledgements, save failures, explicit equipment,
  final-skin recovery, malformed receipt isolation and unchanged preferences,
  map access, previous commerce receipts and unrelated config sections. It has
  been authored but has not been executed by this worker.

## Existing contract to preserve

- `game.gd::unlock_random_skin(group)` synchronously chooses one currently
  unowned skin, debits exactly 100 coins, equips the result, advances pity, and
  saves all four together. Failure restores coins, ownership, equipment and
  the full previous pity dictionary. The save uses a temporary ConfigFile and
  atomic rename; an unreadable existing file is not overwritten.
- The visible pool is already `collection`, including all 200 stable skin IDs.
  A fresh profile owns `cocoa_square`, so it needs exactly 199 paid draws to
  complete today's collection. Existing profiles keep every owned ID.
- `SkinDraw.offer()` rolls a tier first and then uniformly chooses an unowned
  ID within that tier. Base tier weights are 45 / 28 / 16 / 8 / 2.5 / 0.5.
  Empty tiers and tiers below an eligible due guarantee have zero weight;
  remaining weights are normalized. Therefore individual skin odds are not
  equal across all 199 initially unowned skins.
- Eligible Epic+, Legendary+ and Prismatic guarantees occur within 5, 10 and
  20 draws. The strongest due eligible guarantee wins. A sufficiently high
  award resets each satisfied counter. Unified draws inherit the strongest
  historical counter per tier once and preserve the old records.
- Keep score/10 coins, 100 coins/draw, all diamond exchanges, StoreKit/advertising
  receipts. The legacy method retains auto-equip; the new case result uses the
  explicit EQUIP control requested during implementation. No fragments, duplicates,
  keys, additional currencies or extra acquisition cost are needed.

## Findings requiring integration work

1. **The current repeat guard is shorter than a reel.** The economic path has
   an 800 ms in-memory throttle; `ui.request_unlock()` blocks for only the
   existing 1-second highlight. Neither represents a multi-second opening.
   Menu rebuilds, app restart and elapsed throttle time must not admit another
   debit while the same case result is being presented.
2. **No durable presentation receipt exists.** Ownership survives a crash
   today, but there is no saved record telling a restored UI which opening to
   finish. Commit this receipt alongside the existing debit and ownership.
   Calling the current draw and then saving a receipt separately leaves a
   crash gap and is not sufficient.
3. **The odds heading is stale.** `ui.gd::draw_rates()` currently displays
   `ALL 44 SKINS` despite the 200-entry catalog. Derive it from the catalog.
   Keep the current mathematical odds disclosure, including each-tier count,
   per-skin chance, normalized current odds and eligible guarantees.

## Minimal integration hooks

Keep the pure `SkinDraw.offer/choose/advance` implementation. Add a small
presentation receipt to the existing collection section of the same save;
there is no need for another wallet or settlement system.

Suggested public interface:

```gdscript
func open_skin_case() -> Dictionary
func pending_skin_case() -> Dictionary
func acknowledge_skin_case(case_id: String) -> bool
```

`open_skin_case()` is the sole new visible acquisition action and always uses
the unified collection. If a valid pending receipt already exists, return a
deep copy of that receipt with `resumed: true` and charge nothing. Otherwise
validate title state, affordable price and remaining pool; compute one offer
and one winning ID; then commit the existing economic changes and the receipt
in the same `save_player_progress()` call. Construct the receipt before that
call. On any failure restore all affected in-memory state, including the
receipt/serial, and return the existing no-coins-spent error.

A bounded receipt contains:

```text
schema, serial, case_id, id, rarity, price, presentation_seed,
odds {entries: [{rarity, weight, count, chance}], total_weight, guarantee, counters}
```

Keep `id` as the awarded skin ID for compatibility; use a separate `case_id`
for presentation identity. A persisted monotonic serial can identify the
opening. The implemented snapshot stores only tier counts/tickets, avoiding a
full ID pool. Do not persist an entire generated reel or a live engine node.

The existing economic method may share a private commit helper with the new
case method, or take an internal receipt option. Preserve legacy test/API
coverage of the former foundation/resonance groups, but do not expose them as
separate cases. All acquisition entry points must reject a second economic
draw while a pending opening exists; an old method must not bypass the new
guard after 800 ms. Pure offer inspection remains free and side-effect-free.

`pending_skin_case()` returns a deep copy, never the mutable saved dictionary.
On load, accept only a supported bounded receipt with a nonempty case ID and
an existing, already-owned awarded skin. Reading a receipt must never grant a
skin, spend money, advance pity, or alter previously stored ownership. A bad
presentation receipt must not reset the wallet or valid ownership; discard
only invalid presentation metadata through the normal recoverable save path.

`acknowledge_skin_case(case_id)` clears only the matching pending receipt and
saves that change. A late acknowledgement for an older case must not clear a
new one. If saving fails, retain the pending receipt and allow retry/resume;
do not charge a new opening. Repeated acknowledgement is harmless. No refund
or second grant is appropriate: the award was already committed before the
animation began.

## Reel and interruption behavior

- The reel is presentation of a committed result. Compute its winner slot
  from the saved receipt; never run `SkinDraw.choose()` at animation completion,
  on skip, on a resize, or after returning to the menu.
- Use a separate `RandomNumberGenerator` for decorative slots, seeded from
  the receipt. Cosmetic draws must not mutate pity or ownership. Use the
  pre-draw eligible pool, and do not deliberately place impossible high-tier
  near misses beside the winning slot. The pointer stops on the awarded ID.
- The UI should have explicit idle / spinning / result states. Block new
  openings for both spinning and result states until the receipt is
  acknowledged. A skip action advances directly to the same result for free.
- Persisted receipt recovery can show the result immediately instead of
  replaying the full reel. Closing the app after payment must reveal that
  same skin on reentry without another charge. Resizing, opening another
  menu, pausing, or resuming must not be interpreted as a new purchase.
- New case openings preserve current equipment. The explicit result EQUIP
  control selects the already-owned winner and cannot buy it. Legacy direct
  draw callers retain their existing automatic equipment behavior.
- Tick/reveal sounds must use the existing SFX bus and honor SFX mute, focus
  and app suspension. Bound the number of tick voices and avoid firing a burst
  for every skipped reel card after a delayed frame. Disabling music must not
  unexpectedly enable it to play the reveal.
- Prefer cached images of original Hole Feast skins for the strip, with a
  bounded visible-card pool. There should not be 200 continuously rendering
  skin viewports behind the reel.

## Odds presentation

Before payment, show the 100-coin price and link to odds generated from the
same `skin_draw_offer("collection")` state used by the transaction. A static
base-weight banner is not a substitute for the current adjusted odds.

For each tier, display its current chance, number of unowned eligible skins,
and `tier chance / remaining count` as each skin's chance. A zero-weight tier
must display zero even if it still contains skins but is excluded by a due
guarantee. Display guarantee countdowns only with the existing eligibility
qualification; a collected-out higher tier is not an available reward.

During or after an opening, label any displayed receipt odds as the odds for
that opening. The next-opening odds must be recomputed from the updated
ownership and pity state. Completed collections have no payable action and
no invented reward. Total counts and remaining counts must come from actual
catalog/ownership data rather than the old 44/60/200 UI literals.

## Focused acceptance expectations

Existing meaningful coverage should remain: `skin_collection_acceptance.gd`
buys all 199 remaining forms and cold-restores each transaction;
`coin_skins_acceptance.gd` exercises actual pointer input, wallet boundaries,
no duplicates, failed saves, legacy ownership and corrupt-file protection;
`skin_rarity_review.gd` independently checks all 10,000 weight tickets, uniform
within-tier selection, availability masks and guarantees;
`future_collection_economy_acceptance.gd` fixes 100 coins/draw and the accepted
diamond exchange; retention suites cover current on-screen odds and pity
rollback. Update presentation-specific expectations without weakening these
economic assertions.

Add focused case tests for:

1. One real pointer opening debits exactly 100 and grants one new ID
   before presentation starts, retaining the previous equipment until EQUIP;
   receipt, ownership and pity cold-restore
   together. Fast taps and delayed callbacks throughout the full reel do not
   add another draw.
2. Interrupt immediately after commit, mid-reel and at result. Reload each
   isolated save; the same case ID and awarded ID return, with no extra debit
   or pity advancement. Skip/resize/menu reentry have the same invariant.
3. Force commit failure: no receipt, debit, grant, equipment change or pity
   change survives. Force acknowledgement failure: the already-earned award
   remains and the same pending receipt is available for retry.
4. A stale case acknowledgement cannot clear a newer pending receipt; callers
   cannot change stored state by mutating a returned dictionary. Old acquisition
   methods cannot spend around a pending case.
5. Exact-balance, insufficient-balance, last-unowned-skin, complete-collection,
   due-guarantee and exhausted-tier cases preserve the current outcomes.
6. Actual reel stop/skip result matches the committed ID, and muted/focus-lost
   playback remains silent with bounded audio/render resources. Test actual
   input routing and reentry rather than only private helper calls.

Only isolated process-owned save fixtures are appropriate. The transaction
implementation and new test are ready for root's serialized engine run; this
worker has not executed or certified them.
