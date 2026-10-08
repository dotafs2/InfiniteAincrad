# Coin-based skin collection — v0.7.0

The requested reference is Hole.io's Classic/Special collection with a coin
balance, three-column grid and green UNLOCK RANDOM action. This replaces the
v0.6.0 large preview/detail layout and score-threshold acquisition.

## Shipped behavior

- HOLES displays the wallet above Classic/Special tabs, selected/locked model
  cards in three columns, the green unlock action and Home/Holes/Play dock.
- The existing ten authored skins remain available: five Classic cosmetics and
  five Special skill forms. Counts reflect actual owned/available forms; there
  are no placeholder slots claiming 27 or 17 implemented skins.
- The new-player wallet starts at 50 coins. Each tab starts at a 50-coin unlock.
  Subsequent prices are 70, 90, 110 and 140 coins, based on already-owned forms
  in that tab, excluding the free Core Shell. These later prices are authored
  tuning, not a verified reproduction of the reference game's full economy.
- A purchase draws uniformly from the active tab's unowned forms, spends the
  displayed price, adds ownership and selects the new skin. The highlighted
  card briefly enlarges. The UI locks for one second and the transaction API
  rejects sub-800 ms repeats. Failed/empty/insufficient-funds purchases never
  deduct coins. Completed tabs show COLLECTION COMPLETE.
- At timeout, defeat or completion, every ten scored points yield one coin,
  rounded down. A completed nonempty round adds 20 coins. Repeated settlement
  cannot pay twice; abandoning a round or losing with zero points earns zero.
  The result panel shows the actual coin reward. Both maps use the same rule.
- The chosen owned skin appears on the player in the next round. Special
  abilities retain their existing cooldowns and physics behavior.

## Persistence and migration

Ownership is stored separately from best-round score in schema 2 of the
existing progress file. A legacy save grants all forms earned by its previous
best score, retains wallet, gems, stage, map, selected owned skin and unrelated
configuration sections, and first preserves a byte-identical pre-coins backup.
Future scores do not grant additional forms, including after restart.

Wallet, owned IDs and selected ID are written together to a temporary config
and renamed over the save. A failed purchase write rolls back memory without
spending coins. Corrupt existing files are refused rather than overwritten.
A failed round save retains the pending session balance and retries with a
bounded delay. Unknown/duplicate saved skin IDs are normalized, with Core Shell
as the fallback. Browser persistence still depends on the browser's user-data
storage; browser reload behavior was not directly verified in this session.

## QA and evidence

The dedicated `coin_skins_acceptance.gd` suite uses actual viewport pointer
input, isolated process-owned `/tmp` save files and fresh game instances. It
covers both tabs, displayed charges, duplicate exclusion, category boundaries,
insufficient funds, rapid clicks, completed collections, actual round equipment,
both-map settlement, cold restore after every purchase and a round, save failure
rollback, legacy migration, preserved unrelated fields and corrupt-file safety.
All test files are removed after completion. `--test` never writes player data.

The updated UI suite verifies phone-scaled 44-point targets, non-overlap,
thumbnail framing, pointer navigation, PLAY/pause/results and cleanup. The
skill suite now seeds explicit owned fixtures and confirms scores no longer
unlock forms; it still exercises every Special ability in the actual city.
The guarded release passes **5,285 checks in 16 suites on both source and
the exported PCK**, including 119 coin/save checks and 310 UI checks.
Final counts and hashes are recorded in
[`release/release.json`](../artifacts/coin-skins-20260928/release/release.json).

The five thumbnail viewports render once and are released on exit. The large
skin detail viewport stays disabled. Scene populations, graphics settings,
physics, traffic and map geometry are unchanged. No new phone FPS claim is made.

## Reference and visual scope

The reference is the classic collection generation pictured in the
[Hole.io screenshot gallery](https://apkpure.net/hole-io/io.voodoo.holeio) and the
[Apple-hosted collection image](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/12/dc/cd/12dccd53-ff1d-57e7-4455-755d76212e5b/4_skins_30.jpg/471x1024.jpeg).
The earlier [direct observation ledger](../fidelity/REFERENCE.md) corroborates
the Classic/Special tabs and three-column collection. It does not establish
all unlock probabilities, later prices or reward rules for the installed build.

`artifacts/coin-skins-20260928/layouts` reconstructs the actual 2D draw commands
and original SVG assets, with explicit omitted-3D placeholders. The additional
fixtures show a new unlock, insufficient coins and a completed collection.
They are layout reconstructions, not Godot/browser screenshots or user progress.
The browser tool again returned `User unavailable`; no alternate browser
control, foreground game window or phone visual verification was used.
