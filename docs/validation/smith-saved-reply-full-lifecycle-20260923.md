# Saved Smith reply through the axe lifecycle

`game/tests/smith_saved_reply_full_lifecycle.gd` replays the exact raw Smith
response captured earlier in `local-smith-format-live-20260923/response.json`.
It verifies that response's SHA-256 and the independent `a16` acceptance mapping,
then submits it through the reviewed dialogue adapter and the normal Turns
action gate in a new disposable formal-resident world. The replay makes **zero
new model requests**; the fresh turn archive says `model_returned:false` and the
report separately says `saved_model_reply_replayed:true`.

The replay actually accepted the 2 Col contract and preserved Flint's
`axe_contract_accepted` feedback, owner wallet 8 and escrow 2 across a cold
restart. From there, explicit **scripted host continuation** delivered the axe
to Flint, simulated arrival with `host_move`, advanced 60 seconds of repair,
consumed his one iron, restored the edge to 100, and let Rowan collect the axe.
The final state has Rowan holding the repaired axe with 8 Col, Flint holding
12 Col, and no escrow. A second collection was fenced; a final cold reload
retained the acceptance feedback. These later movements and commands are not
claimed as new autonomous NPC choices or physical navigation.

The [result report](smith-saved-reply-full-lifecycle-20260923.json) records
each phase, funds, custody, iron, work duration, and both restart checks. The
managed Godot 4.7.2 Mono run passed **15 checks**, exited 0, had empty stderr,
and all three owned processes exited. Logs:
`private/iteration-20260923/smith-saved-reply-full-lifecycle-r7/`.
The fixture verifies hashes of its saved inputs and source; an independent
publication check verifies the six protected canonical/user files. No
production save, NPC history or billing ledger was changed.

Several earlier harness revisions failed and were repaired before this final
run. One disposable `user://saved-smith-lifecycle-57348-412133.world.json`
from a timed-out revision remains in Godot's app data. It was identified as
that run's file, but a precise delete was denied by local shell policy, so it
was left untouched. It is not the active world or a published artifact.
