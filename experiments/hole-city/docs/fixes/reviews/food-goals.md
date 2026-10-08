# Independent review: food city objectives and guide

Status: PASS for receipt accounting, objective gating and guide integration. Reviewer: expand_skin_catalog; implementation authors: root and fix_food_city.

The reviewer authored tests/review_food_goals.gd and ran its 34 checks against the actual game scene. It uses the real finish_swallow → game.collect → city.record_collection path to isolate accounting, while keeping the scene controllers and rain disabled. This is deliberately not a substitute for the separate physical full-round route test.

The scene provides more than the required ordinary buildings, landmark and large heaps. Only the player's receipts enter the city objective ledger; rival-owned items cannot advance it. Below sixty percent of a structure's pieces, the building, landmark or large-heap goal remains incomplete. The threshold receipt advances it once; additional or duplicate receipts do not add a second structure. Finishing the same physical body twice leaves both score and total collection count unchanged. Eating the entire starter pile does not count as the large-heap objective. One qualifying landmark contributes both a building and the distinct landmark goal.

The review exercises the exact combined gate. Complete food and city goals at 499 points remain in play. At 500 points, missing one building, the landmark, the heap, one small-food receipt, one donut, or the cake each independently prevent completion. Meeting every threshold completes the round once, advances the stage, and awards the expected 50 score coins plus 20 win coins. A physical receipt after settlement cannot alter settled score or goal progress. Starting a new round resets counters and cached guidance.

The guide returns an actual fitting uneaten piece, excludes a rival-claimed target, remains cached between updates, refreshes on the one-second schedule and clears after city completion. The HUD food counts agree with the gate. Actual Fredoka measurements confirm the maximum city-progress line and new tutorial sentence fit the portrait width. Source inspection verifies the food intro shade starts at y=282 while the complete goal panel ends at y=273, leaving the goals unobscured. The tutorial now explicitly names 12 buildings, a landmark and a heap.

No accounting or gate defect remained in this review. This evidence does not demonstrate the time needed by a human player, guarantee a successful route with all rival strategies, show a browser-rendered arrow, or certify phone GPU performance. The full physics round and mobile rendering remain separate checks.

Evidence: artifacts/fixes-20260928/reviews/food-goals.json and food-goals-source-hashes.json. No user save or foreground window was touched.
