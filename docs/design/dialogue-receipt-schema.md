# Dialogue receipt schema

`game/core/dialogue_receipt.gd` accepts a bounded dialogue envelope and validates it against an explicit caller-supplied context. The context has exactly three allow-lists:

```json
{
  "target_ids": ["player", "resident:b"],
  "claim_ids": ["claim:rain"],
  "action_ids": ["offer:lantern"]
}
```

Each context ID is a unique nonempty string of at most 96 characters; each list has at most 256 IDs. The envelope requires `speech`, `intent`, `stance`, `target_id`, `claim_ids`, `stakes`, `next_action`, and `confidence`. `private_thought` is optional and is retained only in the private receipt. `target_id` and `next_action` may be empty when the turn has no applicable target or proposed action. Nonempty targets, claims, and actions must be present in the corresponding allow-list. Unknown fields, malformed JSON, wrong types, duplicate claims, unsupported enum values, oversized text, and out-of-range confidence are rejected.

Successful parsing returns `{ok: true, receipt, proposed: bool, execution: "not_attempted"}`. `next_action` is a proposal string; this module does not execute it, create world state, grant resources, or verify the truth of natural-language claims. `public_projection()` removes `private_thought` before delivery to another participant.

The offline acceptance test covers valid JSON and dictionary input, required fields, malformed and unsupported values, type and length limits, private/public projection, context failures, and the execution boundary. It does not claim language-semantic truth verification; claim IDs only assert that the caller supplied the claim in its allowed view.
