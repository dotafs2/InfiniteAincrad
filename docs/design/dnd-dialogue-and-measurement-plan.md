# DND-style NPC dialogue and measurement plan

The dialogue target is a resident who speaks from a character sheet, current evidence and a
concrete situation. The style should feel like a tabletop session: a clear intention, a visible
stake, a bounded choice, a meaningful reaction and a consequence that changes what can be said
next. A long paragraph is not the goal. A useful turn is a small scene beat that another resident
can answer or act on.

## Dialogue turn contract

Keep the model output structured and keep natural language inside one bounded field:

```json
{
  "speech": "The line the resident actually says.",
  "intent": "ask|offer|refuse|warn|agree|disclose|greet|leave",
  "stance": "warm|guarded|curious|firm|uncertain",
  "target_id": "the nearby resident or player, when applicable",
  "claim_ids": ["evidence ids that support factual claims"],
  "stakes": "what the resident risks or wants in this exchange",
  "next_action": "an offered, refused or deferred world action",
  "private_thought": "optional private text, never spoken or sent to the target",
  "confidence": 0.0
}
```

The authoritative world still decides whether a promised action exists, whether a resource is
available and whether consent or ownership allows it. Dialogue can propose, ask or refuse; it cannot
silently create an item, relationship, belief or contract.

## What makes the voice feel like DND

Each resident needs a compact voice card derived from the existing dossier: opening habit, sentence
length, preferred concrete details, humour level, taboo or boundary, tell when nervous, and one
recurring metaphor. The prompt should also provide the scene's visible facts, the resident's goal,
the social relationship and one unresolved tension. The model should answer in one to three spoken
sentences, leave room for the other participant and avoid narrating another person's hidden motive.

Use a light tabletop resolution layer for consequential exchanges. A social check is not a random
permission to override the world; it exposes uncertainty already present in the character's stance.
Record `check_kind`, `difficulty_band`, `roll_seed`, `modifier_source` and `outcome` in the receipt,
then let the resident express the outcome in their own voice. Routine greetings and factual answers
do not need a roll.

## Measurements

Score every sampled turn with deterministic checks first, then use a separate evaluator for the
qualities that require language judgement. Keep the score out of the resident prompt so it cannot
learn to write for the evaluator.

| Dimension | Question | Initial pass condition |
| --- | --- | --- |
| Grounding | Are factual claims supported by the projected view or recorded claim IDs? | 100% unsupported claims blocked |
| Character voice | Does the line match the resident's voice card without becoming a catchphrase? | >= 0.75 on a 1.0 rubric |
| Scene intention | Is the intent clear and aimed at the current target? | >= 0.85 |
| Stakes | Does the resident reveal what can be gained, lost or deferred? | >= 0.70 |
| Agency | Can the other participant answer, refuse or choose an action? | >= 0.80 |
| Consequence | Does the receipt record a changed offer, stance, memory or next action? | >= 0.80 |
| DND readability | Can a player tell who speaks, what they want and what choice is open? | >= 0.85 |
| Economy | Does the turn fit the token and latency budget for its route? | local for routine, cloud only when needed |

Report the distribution, not only an average: worst resident, worst intent, unsupported-claim rate,
repeated-line rate, average spoken length, evaluator disagreement and cloud fallback rate. A high
average with one resident who always sounds identical is a failure.

## Delivery phases

1. **Receipt and schema:** add the bounded dialogue envelope beside the existing action receipt;
   preserve the current free-speech and social capability rules.
2. **Voice cards:** fill the ten dossier-backed cards and create a small golden set for greeting,
   asking for help, refusal, apology, resource warning and farewell.
3. **Local scoring:** use LocalJev for routine intent/stance checks and malformed-output detection;
   send social ambiguity, conflict and story turns to the cloud route.
4. **Controlled conversations:** run 30–50 offline conversations across every resident and intent,
   then replay a small live sample with receipts, cost and latency evidence.
5. **World consequences:** connect only accepted offers, refusals, knowledge updates and contracts
   to authoritative commands; keep spoken flavour separate from state mutation.
6. **Art and embodiment:** show speech bubbles, listening pauses, hand props and stance gestures in
   the Starting City preview, then test the same dialogue while a resident carries a sword, tool,
   book or lantern.

The first concrete implementation should be the receipt/schema and the golden conversation set.
That gives the project a stable target while the town art continues to expand.

## Layout reference boundary

The art pass uses broad published motifs—southern Town of Beginnings, a central plaza and Black
Iron Palace, western forest, northeastern lake/wetland, eastern ruins and a northern labyrinth
approach. The project whitebox remains an authored proportional study; it does not claim to be an
exact canon map.

Reference pages consulted on 2026-09-22:

- https://swordartonline.fandom.com/wiki/Town_of_Beginnings
- https://swordartonline.fandom.com/wiki/1st_Floor_%28Aincrad%29
- https://aincradcodex.com/towns/town-of-beginnings
