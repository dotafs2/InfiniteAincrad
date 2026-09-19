# Natural edge-repair follow-up (2026-09-19)

H121 continued `shared:restart-20260918-01` from seq194 to seq209 with twelve serial Kimi calls. All twelve settled for CNY 0.2612845; no new unknown charge or pending worker remained. The canonical checkpoint is `seq000209-34feaca504817a22.world.json` with SHA-256 `34feaca504817a22fdaa33efcc423a8a5aaab8a48f46a64a82ad5916131d4ad9`. The world now has 184 archived attempts and 198 usage records.

The concrete target was an edge repair for Rowan's axe. The read-only route review and a disposable TownTrade probe show that the existing implementation already supports the complete bounded path: physical approach within 3 m, a fresh 2/5/8 Col offer, voluntary acceptance with escrow, delivery, 60 seconds of work using the worker's own iron, and collection with one payment. The probe passed 30/30 generic repair checks and preserved conservation; it did not write the canonical world or call a provider.

The live window did not complete that path. Smith (Flint) naturally observed the iron source again and moved between the market and artisans' forecourt while retaining one iron. Carpenter (Rowan) had no new model turn in this 600-second window; his axe therefore remains edge 20 / handle 100 and the old rejected contract remains rejected. The correct next live condition is a new Carpenter decision after the due boundary. The old contract must not be revived.

A separate natural material event did occur: Weaver (Iris), using her own prior source knowledge, recovered one iron from the same finite source. The source changed from stock 2/recovered 1 to stock 1/recovered 2, preserving `stock + recovered = initial_stock = 3`. This is real material adoption evidence, but it is not edge-repair adoption.

The live engine exited cleanly with drained gateway state and no `ERROR:` lines. It still emitted the known four-edge navigation merge warning. H120's particle and MultiMesh renderer messages remain historical evidence; no cache deletion or renderer suppression was attempted.

Evidence: [live observation](../../worlds/restart-20260918-01/observations/iteration-20260919/live-06-observation.json), [session summary](../../worlds/restart-20260918-01/observations/iteration-20260919/live-06-summary.json), [route facts](material-repair-2026-09-19/route-facts.json), [checkpoint manifest](../../worlds/restart-20260918-01/checkpoints/manifest.json), and [usage manifest](../../worlds/restart-20260918-01/usage/manifest.json).
