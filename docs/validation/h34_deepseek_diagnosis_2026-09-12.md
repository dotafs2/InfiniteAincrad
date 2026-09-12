# H34 native access violation: harness correction, fault capture and current obstacle

DeepSeek diagnosis, 2026-09-12, continued in the same session. No NPC/GM gameplay model
calls were made; DeepSeek development usage is accounted separately and is not part of this
document. No runtime, core or C# source was edited. All new outputs are under
`tmp/h34-deepseek-20260912/`; the maintained seed (`01ef0bf8ed3f6054d9715036ee0a826ea90997cc2d23f3fd33b201f6747e6541`),
the accepted lifecycle world (`e9bb577ee883e27c96f4a5e1f2f84ea70097ee410c08afaf1df98cdaafb83178`)
and the preserved sprint failure files/locks were not written. Diagnosis baseline is a byte
copy of the failed save (`40ddd40f6dae5169073d854d831743cb7a665c3d36d350f0ea177a6791822470`),
whose eight original jobs are still pending, seq 25, stock 2.

## 1. The earlier diagnostic hooks never bound (cause found)

`h34_instrumented_town.gd` declares `extends "res://core/town_life.gd"`, but the street scene's
member is typed `res://core/town_runtime.gd`. That earlier run's 42 occupancy assertions keep
the scope they were written for; what it never did was exercise the diagnostic hooks, so it
cannot support any claim about instrumentation or fault location. Paused identity probe
(`harness/h34_probe.gd`, `out/identity-paused.json`): production identity
`res://core/town_runtime.gd`; after `set("town", <old subclass>)` the member is **still**
`res://core/town_runtime.gd` (assignment refused; only a console error was emitted, so the
old run's silence was not proof of anything); after setting a subclass that extends
`town_runtime.gd`, the member is that subclass. The identity run's first version failed 1 of
11 checks precisely on the assertion that the old subclass binds — that failure is kept here
as the counterexample. A second ordering fact: the scene loads inside `_ready`, so an
instrumented instance must be in place before `add_child`.

## 2. What confirmed hooks show, and what they do not show

With a binding subclass, decode → transaction → save → encode all return normally
(paused run: `paused_transaction {"ok": true}`). Heavier marks: the occupied run's own report
records 306 trace lines (`out/occupied-instrumented.json`, `out/occupied-gl.json`, 20.0 s
each); a later ordinary `run` wrote 864 lines to one trace file before passing. Those are
per-run figures from different marker sets; the "~38 cycles" figure is derived (306/8 marks
per cycle), not a measured counter.

Fault-time trace (light marker set, ordinary `run`, `out/phases-light.tsv`): the last returned
phase was `save.after` at 45.575 s, then a heartbeat at frame 2672 (45.617 s), then the
process died. That establishes **the last returned phase**, and nothing more: it does not
exclude latent corruption produced by earlier encode/release work, and the harness has no
separate marker around `Release()` itself.

## 3. The fault is not specific to the acceptance harness (new, measured)

One ordinary production entry — `res://scenes/town_street.tscn`, no acceptance MotionSampler,
no layout reset, no time scaling, gl_compatibility, Dummy audio, 60 s condition on a new byte
copy — **also faulted**: exit `3221225477`, 45.657 s (`next-ordinary/logs/next-ordinary-60.process.json`).
So the QA-sampler theory is weakened; the fault reproduces without that helper.

Saved outcomes before that fault (`next-ordinary/worlds/ordinary-60.json`, sha256
`6ab103e62893bd26baac578e092fc0b1f4e8f89b62f196f14339512d77dccb87`): seq 25→27, two new
`harvest_ration` events, stock 2→0, food 4→6, commands 32→34, pending 8→1 (`shared:herder`
still unfinished). Cold read-only reopen of a copy (`next-ordinary/out`, `capture-cold/evidence.json`)
reports the same world (`shared:aincrad-trial-1`, 10 active, seq 27, stock 0, 1 pending) and
left the post-crash file hash unchanged.

## 4. Fault capture (existing dump, no new instrumentation)

Windows Error Reporting already writes user-mode dumps to `%LOCALAPPDATA%\CrashDumps`, and a
local `cdb.exe` exists (`C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\cdb.exe`).
Whole-run symbol-server analysis hung (no symbol access) and was stopped; the bounded
symbol-free analysis is `next-ordinary/out/dump-47500-raw.txt`, produced read-only from the
dump of my own crashed engine process:

```
(b98c.4188): Access violation - code c0000005
rax=2f rbx=2f rcx=0000000000000000 rdx=0000022b053deb40 ...
rip=00007ff7`c4cb377d
Godot_v4_7_2_stable_mono_win64!NoHotPatch+0x1410b4d:
  movss xmm0, dword ptr [rcx+10h]      ; rcx = 0 ; faulting read at 0x10
```

The fault is a read through a **null base pointer** (`[0x0 + 0x10]`) inside the engine binary,
during frame work, with the caller chain in the same module. Windows Application Error events
map the crashes: 15:43:49 (control `run`), 15:46:33 (light-marker `run`) and both sprint
crashes share fault offset `0x14454ac`; the new ordinary-entry crash is a **different**
instruction, `0x141377d`. Same exception class, two sites.

## 5. Obstacle and next experiments

No source repair is justified by this evidence: the faulting instruction is inside the Godot
binary, our GDScript/C# code has no frame in the crash data, and changing the
renderer/audio/physics or removing the deterministic `Release()` would hide rather than repair
it. A null dereference with no project frame does not by itself absolve project code of
producing bad state, so project-level source diagnostics stay open. Official Godot binaries
ship without debug symbols, per the engine documentation on
[build system debugging symbols](https://docs.godotengine.org/en/stable/engine_details/development/compiling/introduction_to_the_buildsystem.html#debugging-symbols),
so downloading public symbols for this binary is not an available step; a matching debug build
would be needed for private symbols (large, out of scope here).

Next, smallest first:

1. **Trigger isolation (cheap, in-scope).** The same ordinary 60 s entry on the same copy,
   contrasted on exactly one dimension at a time — first the renderer configuration
   (default Vulkan/Forward+ versus the gl_compatibility used by every crash), then audio
   driver — recording exit code and dump offset for each. This isolates a trigger; it is not
   a fix, and no configuration change will be presented as one.
2. **Retain capture for the next fault.** Keep using the WER dump plus the bounded symbol-free
   `cdb` register/stack read; if deeper symbols are ever required, the only sound route is a
   matching debug build of 4.7.2.
3. Reconsider our own code only if a reproduced before/after difference or a clear ownership
   contract violation appears (the codec `Release()` path is a hypothesis, not a finding).

H34 stays open; H33 stays partial; the ROADMAP is unchanged.

## 6. Renderer comparison: the desktop default passes where the explicit GL path faulted

Same Godot 4.7.2 binary, same ordinary `town_street.tscn` entry and scene arguments, same
Dummy audio, same baseline bytes (`40ddd40f…`, seq 25, stock 2, eight pending jobs), no
acceptance MotionSampler and no instrumented runtime. The two runs were **not literally
identical CLI invocations and their durations differ by design** (60 s bound versus 90 s
requested; 45.657 s versus 92.9 s observed): the renderer argument is the only *deliberate*
variable, while the duration was extended to compare past the earlier fault time.
`project.godot` already defaults to `forward_plus`, so `gl_compatibility` is the explicit
test override.

| condition | renderer | wall clock | engine exit | result |
| --- | --- | --- | --- | --- |
| ordinary entry (`next-ordinary`) | gl_compatibility | 60 s bound | `3221225477` | fault at 45.657 s, offset `0x141377d` |
| ordinary entry (`next-forward/worlds/forward-90.json`) | forward_plus | 92.9 s | 0 (all owned members 0) | completed 90 s, capture + evidence written (sha256 `faff92435adf3b12760bf755ed31fb37cf3a031c43460801e15ee512fbe22963`) |
| occupied workspot negative (`next-forward/out/fwd-occupied.json`) | forward_plus | 23.2 s | 0 | 42/42 checks, stock 2→0, seq 25→27 |
| scripted-idle protection (`fwd-idle-policy.json`) | forward_plus | 4.6 s | 0 | 41/41 checks, seq 25 and stock 2 unchanged |
| paused cold (`fwd-cold.json`) | forward_plus | 2.8 s | 0 | 38/38 checks |

Independent disk inspection of the Forward+ 90 s world: the eight original jobs ended as
**2 earned food gains** (`shared:baker`, `shared:well-keeper`) and **6 truthful depletions**
(`resources_unavailable`: carpenter, fisher, gardener, herder, innkeeper, smith), with 0 lost
commands and 0 still pending; `stock 0 + harvested_total 6 == initial_stock 6 + produced_total 0`;
food total 4→6 equals the number of gains; resident ids/names/coins and every pre-existing
event are unchanged, so no task loss, reset or duplicated stock occurred. The 20 s occupied
window (sha256 `e3dae75435693b6e086341114c2a1f4038769d5e07eadee2eb730efe285fe0a3`) resolves the
same 2 gains plus 3 depletions and leaves 3 jobs genuinely unfinished, which is how a short
window is distinguished from a reset.

Reading: the explicit compatibility-renderer path is the configuration in which every observed
H34 fault occurs; the project's desktop default completed the longer ordinary condition plus the
occupied, idle and cold checks without faulting. This is a **bounded configuration comparison,
not a source repair**: compatibility crashes stay open and unrepaired, long-term stability is
unproven, and both preserved fault offsets (`0x14454ac`, `0x141377d`) remain. For the first
real resident/GM cycle the desktop default is usable within this observed scope; that phase
still needs its own accounting and does not depend on a renderer change.

Status: H34 open (compatibility sighting preserved, no causal fix); H33 may be proposed green
only with a label restricted to this observed default-mode foraging behaviour.
