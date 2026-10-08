# Independent review: collection, store and progression

Status: PASS after one review correction. Reviewer: expand_skin_catalog; implementation author: root.

The initial source review found that paging left the preview focus on an invisible card from the previous page. That produced a static visible page and a mismatched detail panel. The author changed paging to focus the first visible card when necessary, without equipping it. The independent screen-touch test reproduces this navigation and verifies the correction.

The reviewer authored tests/review_ui_collection.gd rather than calling button signals. It sends actual InputEventScreenTouch and InputEventScreenDrag events through the viewport. All 156 assertions pass: store entry, initial gift and duplicate rejection, exact gem-to-coin purchase, insufficient-funds preservation, cold restore, both collection tabs, swipe and button paging, boundary pages with three Classic and five Special cards, last-slot equipment, restoring the equipped Special group and page, actual manual/automatic/cosmetic skill information, exactly one active visible model with an advancing shader clock, repeated navigation cleanup, selected skin entering play, one-time level advancement, separated score/win rewards, repeated-settlement rejection, and cold restore of the new level and selected skin.

The reviewer also independently reran the author's 17 store assertions, including transaction rollback on save failure. Static inspection confirms store actions reject active gameplay, invalid offers and insufficient balances; save updates include coins, gems and gift eligibility in the same atomic configuration replacement. Existing unknown configuration sections are retained.

Text was measured with the actual loaded Fredoka font. Across all 44 definitions, the widest 18-pixel card label is 130 pixels within a 148-pixel safe width; every 17-pixel skill description wraps to at most two lines inside the detail panel. Phone-safe control positions and bounded preview ownership are asserted in the touch test.

This is input, source, font geometry and persistence evidence. It is not a browser screenshot, a phone touch-device test or a GPU performance result. Only observed reference pack amounts are claimed matched; the per-level gem gift and unlock price progression remain authored tuning.

Evidence: artifacts/fixes-20260928/reviews/ui-collection.json, store.json, layout-traffic-probe.gd and reviewed-source-hashes.json. All saves were PID-specific files under /tmp and were removed. No real user save or foreground window was used.
