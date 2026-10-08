# Web notice packaging verification

The authored `tools/package_web_notices.py` exposes
`install_notices(candidate, godot) -> dict[str, str]`, returning nine relative
artifact paths and their SHA-256 hashes. It is intended only for an unpublished
export candidate. The helper and its 15-test suite are frozen at the hashes in
`smoke-result.json`.

The bundle copies the game's LICENSE, THIRD_PARTY.md, Fredoka OFL, mbMayer MIT
notice and music credits without changing their bytes. The exact Godot
executable runs the existing license generator with `--headless --test`, strict
error handling and absolute output/log paths. The real run produced 94,795 bytes
of engine/dependency notices. Source notices, generator and engine hashes are
checked again before installation. The local credits page includes all notice
links and a provenance manifest.

The head metadata link and the visible credits link are inserted once. The
visible link lives inside the existing loading-status overlay, outside the
canvas, and the engine's existing `statusOverlay.remove()` removes it on startup
completion. There is deliberately no permanent gameplay touch target. Discovery
is limited after loading: `credits.html` remains directly accessible, but the
helper does not add an in-game menu button. No browser or visual capture was used.

## Checks and evidence

- `unit-initial.log`: all 15 Python tests pass, including missing/unsafe template
  refusal before mutation, exact notice bytes, strict exit-zero error rejection,
  input races, symlink refusal, idempotence and rollback at every rename step.
- `smoke-result.json`: 17 checks pass with the actual bundled Godot executable
  and a copy of the served export HTML/JavaScript. Two actual installs produce
  identical bytes. Logs are preserved in `smoke-engine-0.log` and
  `smoke-engine-1.log`. The engine reports only the explicitly allowed macOS
  system certificate diagnostic.
- `copied-export/`: inspectable local result; it is not published or a full game
  export. The smoke copied only the existing HTML and JavaScript needed for the
  packaging/entry checks.
- `first-smoke/`: retained failure in the artifact probe's assertion, which
  expected a different DOM removal spelling. Reading the actual existing export
  showed `statusOverlay.remove()`. Only the artifact assertion was corrected;
  packaging/runtime/test files were unchanged.

## Independent release integration review

The helper author separately reviewed root's release integration in
`tools/release_web.py` (hash bound in `smoke-result.json`). The notice inputs,
helper, generator and tests participate in the source guard. The Python suite
runs before source acceptance; notices install after export and device-QA
injection, before isolated-package acceptance. Recursive artifact enumeration
and `copytree` retain nested notices. The existing staged/final digest checks now
cover those relative paths. The final unchanged-input check still runs before
publication.

The smoke directly exercised root's publication function only in an isolated
synthetic temporary directory: a nested notice is copied correctly, a changed
nested notice is rejected without changing the old preview, and an injected
final-swap failure restores the previous nested preview. The verifier's
`importlib` loading path resolves the sibling helper successfully.

No blocking integration issue was found. All release inputs and served Web
artifacts hashed identically before and after this review. Every owned helper
has exited. This does not claim the concurrently running full release gate has
finished, nor does it claim browser rendering, legal advice or phone testing.
