# Smith proposal prompt format correction

The saved actual `qwen3:8b` reply put the canonical contract action ID into
`next_action`, where `DialogueReceipt` requires an exported short alias. It was
rejected as `unsupported_next_action` before intent review. The model-facing
prompt now lists each option's alias, human description, and independently
computed expected intent. The canonical `action_id` stays in the validated
fixture metadata for later review and execution, but is omitted from the model
prompt. `next_action` is explicitly restricted to the current context aliases.

A format-only JSON example uses an available mapped alias and a spoken line
consistent with its declared intent. For the saved Smith fixture the example
uses refusal (`a17`, `refuse`); it is explicitly labelled as a format example,
not a recommended action. If no option has a mapped expected intent, the prompt
omits the example. The model still chooses among the actual 18 supplied options.
This may anchor its choice toward the example; that effect has not been measured.

The focused Python suite passes **6 tests**, covering one-call raw preservation,
malformed output without retry, existing-output protection, wrong resident,
unmapped metadata, dynamic aliases, coherent format example, and absence of
canonical contract IDs in the model-facing prompt. On the saved Smith context,
the prompt changed from 7,959 to 7,852 characters, a 107-character reduction.
Those are character counts, not provider token counts or measured savings.

No model request, world action, or production save update occurred in this
batch. The prior response remains preserved unaltered. A future single local
proposal may evaluate whether the format error recurs, but passing the prompt
tests cannot establish language/action consistency or resident autonomy.
