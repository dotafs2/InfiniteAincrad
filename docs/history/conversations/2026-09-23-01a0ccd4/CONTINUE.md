# Continuation handoff — 2026-09-23

## Current state

- Active public lineage: `shared:restart-20260918-01`, canonical seq323.
- Canonical save and public checkpoint SHA-256: `2d80c92778c34dc7de1434d48a6203faa1bd3638aef5830cf63936e68656774e`.
- Provider ledger: 378 settled, zero reserved or unknown. The last two requests were disposable adventure visibility samples and were not promoted into the active world usage book.
- Active world usage and GM records remain append-only; historical partial and unknown GM usage stays marked unknown.

## Completed in this task

- H141–H142: real GM observation/feedback and seq323 persistence/gameplay audit.
- H143–H148: adventure contract, source review, host effect decision, isolated reducer and disposable live install.
- H149–H150: offline resident action boundary and collision-aware disposable scene route.
- H151–H152: two real Kimi resident turns saw the host-gated wilderness option and voluntarily chose ordinary town actions. No autonomous adventure adoption is claimed.

## Verification

- Offline resident adoption fixture: 15/15.
- Disposable scene gate route: 1,005 frames, 22.568 m, floor collision observed.
- Two real model runs: one chose `life:harvest_ration`; one chose `ability:talk:shared:innkeeper`; both settled with no current provider error.
- `python -m py_compile`, `python -m json.tool` and `git diff --check` passed. No owned Godot process remains.

## Next work

1. Decide whether to collect a voluntary real adventure adoption sample or obtain a host-approved policy for canonical integration.
2. If adoption is observed, run GM effect feedback against the exact disposable receipt.
3. Only after that consider canonical TownActions wiring, combat authority and floor progression.
4. Before publication, refresh this archive, inspect staged files and verify the remote commit and archive hashes.

The archive covers visible messages through the cutoff recorded in `manifest.json`; later messages are not included.
