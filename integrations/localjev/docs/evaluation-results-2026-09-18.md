# First bake-off: 2026-09-18

**Completed:** 1,200 measured requests in about 23.5 minutes, on this Apple M5 Max
with 64 GiB RAM, AC power, oMLX 0.6.4 and Bun 1.4.0. Five installed 4-bit models,
120 gold-labeled examples, two input conditions. This tests the current LocalJev
prompted JSON-probability pipeline, **not** direct logits or single-pass inference.

- [Full generated report: all task/calibration/timing matrices](../eval/reports/2026-09-18-bakeoff/report.md)
- [Machine-readable summary](../eval/reports/2026-09-18-bakeoff/summary.json)
- [Per-example results and attempt telemetry](../eval/reports/2026-09-18-bakeoff/results.jsonl)
- [Reproduction manifest](../eval/reports/2026-09-18-bakeoff/manifest.json)
- [Methodology and rerun instructions](evaluation.md)

## Short-input results

40 balanced examples per task. Accuracy counts inference failures as wrong.
SST-5 accuracy picks the highest-probability level; MAE measures the expected
score on the 0–4 scale. Latency is full-decision wall time, not TTFT.

| Model | AG News accuracy | BoolQ accuracy | SST-5 accuracy | SST-5 MAE ↓ | Macro accuracy | p50 seconds ↓ | p95 seconds ↓ |
|---|---:|---:|---:|---:|---:|---:|---:|
| Gemma 4 E2B | 32.5% | 70.0% | 35.0% | 0.926 | 45.8% | 0.522 | 0.642 |
| Gemma 4 E4B | 65.0% | 75.0% | 50.0% | 0.611 | 63.3% | 0.543 | 0.714 |
| Gemma 4 26B-A4B | 87.5% | 85.0% | 52.5% | **0.533** | 75.0% | 0.675 | 0.874 |
| Qwen3.6-35B-A3B | **90.0%** | 85.0% | **55.0%** | 0.599 | **76.7%** | 0.889 | 1.007 |
| DiffusionGemma 26B-A4B | 87.5% | **87.5%** | 47.5% | 0.603 | 74.2% | 1.207 | 1.897 |

## Same targets with 2,048 unrelated background words

The target is retained intact in the middle of the background and explicitly
identified in the instructions. No context-window maximum was changed. Mean prompt
length grows from roughly 330–540 tokens to 3,090–3,290 tokens depending on the model.
This is an artificial distraction/prefill test, not a natural long-document task.

| Model | AG News accuracy | BoolQ accuracy | SST-5 accuracy | SST-5 MAE ↓ | Macro accuracy | p50 seconds ↓ | p95 seconds ↓ | Failures |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Gemma 4 E2B | 27.5% | 80.0% | 15.0% | 1.625 | 40.8% | 0.698 | 2.076 | 3/120 |
| Gemma 4 E4B | 75.0% | 62.5% | 12.5% | 1.748 | 50.0% | 1.079 | 1.299 | 0/120 |
| Gemma 4 26B-A4B | 85.0% | 85.0% | 37.5% | **0.648** | **69.2%** | 1.750 | 2.108 | 0/120 |
| Qwen3.6-35B-A3B | **87.5%** | 80.0% | **40.0%** | 0.764 | **69.2%** | 1.499 | 1.772 | 0/120 |
| DiffusionGemma 26B-A4B | 82.5% | **87.5%** | 25.0% | 0.937 | 65.0% | 2.050 | 3.139 | 0/120 |

## Interpretation

1. **Gemma 4 26B-A4B is a promising short-input default to investigate.** Its
   p50 was only ~0.13 s slower than E4B while gaining 11.7 percentage points in
   macro accuracy. It also had the lowest expected-score MAE and needed no retries
   in either context condition. The LocalJev serving default has **not** been changed.
2. **Qwen is also a strong candidate.** It had the highest short-input accuracy,
   but the difference from Gemma 26B-A4B is only two correct answers out of 120—not
   evidence of a statistically clear winner. With the longer inputs the two tied
   on macro accuracy, and Qwen had lower latency.
3. **E2B bought little short-input latency improvement in this pipeline.** It was
   only ~0.02 s faster at p50 than E4B, with substantially worse accuracy. E4B
   generated fewer output tokens on average, which helps offset its larger size.
   These results concern probability-array prompting and the installed quantizations,
   not each model's best possible classification performance.
4. **DiffusionGemma did not win on speed here.** It had the highest BoolQ accuracy
   by one example, but was slower for these one-question, short-output requests.
   The oMLX diffusion path has different schema/prompt handling and more input tokens.
   This says nothing definitive about many-question canvases, wider outputs or the
   patched-vLLM structured-read approach, none of which was tested.
5. **Longer input hurt quality as well as time.** Every model's macro accuracy
   declined. Sentiment was particularly affected: E4B's accuracy fell from 50% to
   12.5%, and its MAE rose to 1.748. On this balanced SST-5 set, an always-middle
   score of 2 has MAE 1.2. Background did not hurt every task/model combination:
   E4B's news accuracy and E2B's BoolQ accuracy improved on this sample. Inspect task
   results rather than assuming a monotonic effect.
6. **JSON correctness is not semantic correctness.** E2B retried 21/120 longer
   requests, exhausted retries on three all-zero distributions, and had five
   length-limited attempts. All other models completed every request. The full
   report includes first-pass validity, retries and length diagnostics.
7. **Do not treat these outputs as calibrated probabilities.** For example, high
   confidence in wrong BoolQ answers produces large NLL even when accuracy looks
   reasonable. Calibration scores here are noisy (40 samples/task) and are for
   model-written probability values normalized by LocalJev.

## What this does not establish

- No reliable fine ranking among the three larger models: the quality differences
  are small relative to sampling uncertainty. Per-task Wilson intervals are in the
  generated report; these are indicative, not a multiple-comparison significance test.
- No claim that one architecture is inherently faster: this is the deployed
  checkpoint + oMLX + LocalJev combination, including tokenizer, quantization,
  schema enforcement and generated response length.
- No multi-question batching, saturated concurrency, repeated-run variance,
  target-position sweep, larger relevant contexts, or private application labels.
- Public benchmark contamination is possible; performance may not transfer to your
  domain. Model order was fixed; thermal/runtime drift was not counterbalanced.
- No warm-cache advantage: the benchmark deliberately varied the first prompt prefix;
  oMLX reported zero cached input tokens. Normal shared-prefix caching may change
  latency. Initial model-load/warm-up requests were excluded and logged separately.

## Next useful experiment

Take **Gemma 26B-A4B and Qwen3.6**, keep E4B as a small-model comparison, and evaluate
200+ examples per task plus a labeled sample from your actual workflow. Separately
compare one question with multiple questions per state, and try shared-prefix caching.
For the small models, a discrete-label backend or trained classification head may
be more suitable than asking them to generate full probability vectors—but test that
as a new experiment without tuning on this evaluation sample.

To reproduce this matrix:

```sh
bun install --frozen-lockfile
bun run eval --config eval/default.json --out eval/runs/repeat
```

To regenerate the published tables without making any inference calls:

```sh
bun run eval:report eval/reports/2026-09-18-bakeoff
```

The manifest records exact data revisions, SHA-256 checksums, sampled rows, runtime
metadata and inference-code hashes. Original dataset texts and credentials are not
included in the published result artifacts.
