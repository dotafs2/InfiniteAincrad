# Resident action capability standard

H110 introduced one resident-action boundary with 33 versioned definitions: 27 adapters over established rules and six native entry points. H114 adds `production.self_repair`; H116 adds `knowledge.share_material_location`, bringing the current registry to 35. This is a foundation for adding behavior, not a claim that every possible profession or social system exists.

The production world is `game/core/town_actions.gd`. It composes reviewed modules under `game/core/actions/`; new modules do not extend the world's inheritance chain. Existing reducers, command identities, inventory rules, save histories and physical movement remain authoritative.

## Execution contract

| Interface | Responsibility |
| --- | --- |
| `capability_definitions()` | Detached definitions with stable ID/version, module owner, lifecycle, speech policy, resource constraints, preconditions, effects and cancellation policy. |
| `action_options(actor)` | Pure discovery from the actor's own knowledge and current authoritative conditions. Every option has a registered capability ID/version. Discovery grants nothing. |
| `execute_action(actor, option, command, provenance, speech)` | Re-derive availability at submission; enforce actor and speech policy; run the authoritative reducer; roll back unsuccessful effects. Invoke inside a world transaction. |
| `perform_action(path, ...)` | Acquire the existing single-writer transaction and durably save successful execution. |
| `execute_atomic_actions(steps)` | Trusted composition of at most eight uniquely identified children. Revalidate each child after preceding children; any refusal rolls back the complete batch. NPCs reach this only through consent-checked modules. |
| `action_receipt(command)` | Common command identity and pending/completed/rejected status. Native records carry versioned payload/result; legacy records retain their original journal evidence. Admission is not completion. |
| `advance(delta)` | Continue existing jobs and reconcile module-owned protocols against actual child outcomes. |

`trade_options` and `submit_trade` remain compatibility aliases. Production resident turns, ordinary offline life choices, the playable scene, maintenance writers and checkpoint restoration use the common boundary. Internal world reducers and explicit legacy player-assisted repair remain lower-level mechanisms; this delivery does not rewrite the entire historical kernel.

Definitions describe resource constraints; their strings are not a generic lock scheduler. The owning reducers enforce those constraints. One writer serializes commits, while independent residents' body jobs progress together across simulation ticks. The same body cannot start conflicting jobs. Ownership, consent, escrow, current range and finite stock are rechecked by the relevant reducer; stock checked at completion is not promised by discovery. No module creates a second writer or writes from a model worker thread.

## Available capability families

| Family | Implemented behavior |
| --- | --- |
| Life | Wait, eat a held ration, rest. |
| Movement | Approach someone, walk to a workstation, visit a personally known public place. |
| Perception | Observe actual nearby work; privately record current surroundings. |
| Knowledge and learning | Announce a real skill, relay an attributed skill notice, request an existing consensual repair lesson; explicitly tell a nearby resident a personally known material route. |
| Social | Ask/reply/cancel help, reply to the visitor; independently speak to a nearby resident. |
| Inventory | Voluntary food gift, deliver a contracted item, collect a repaired item. |
| Contracts | Offer, accept, decline or cancel an existing repair contract. |
| Production | Forage, contracted repair, repair an owned axe part, use a functional tool, collect/cancel material recovery, bake using finite flour. |
| Cooperation | Invite, accept, decline or withdraw a joint visit; accepted visits compose two existing physical journeys. |

The complete IDs and machine-readable contracts live in the registry definitions, not a second manually maintained runtime list. `social.talk`, `perception.observe_surroundings`, the four `cooperation.*` entry points, `production.self_repair` and `knowledge.share_material_location` are native modules; the other 27 reuse established mechanics.

## Sharing a material route

`knowledge.share_material_location` is an explicit optional speaking action. The speaker must personally know the installed source, be available and have an active recipient within the existing three-metre hearing range. An attributed route statement names the source, direction and labor requirements while declaring current stock unknown. The action generates these actual words from the source evidence; arbitrary model speech cannot replace them. The model's private reason remains separate from the delivered utterance.

Only a previously uninformed recipient gains location knowledge, linked to the actual disclosure and immediate speaker. Existing observations, including known depletion, remain intact. Discovery and feedback never reveal whether the recipient already knew the source. A ten-second cooldown and the speaker's own disclosure history prevent repeatedly telling the same person the same route. Recipients may independently relay, collect or do something else. Knowing a route grants no material, skill, contract or completed work.

Cold restore validates the command, exact utterance, recipients, hearing distance and earlier personal evidence chain. A redundant report cannot replace a direct stock observation with unknown stock. GM public-life evidence includes actual spoken words, without exposing private source history or treating the utterance as an achievement. This reviewed knowledge action does not turn arbitrary free conversation into verified beliefs.

## Own-property repair

`production.self_repair` offers only an actor's own damaged axe part in their own custody, with the matching real repair skill, one uncommitted material unit and no active contract on that item. A profession name grants no skill. The resident chooses the action; admission starts a physical trip to their existing work point. Only time within the existing 0.45-metre arrival gate counts toward 60 seconds of work. The same body cannot start another job or speaking turn while repairing.

Completion rechecks ownership, custody, skill, damage, contracts and uncommitted material. It consumes exactly one wood for a handle or one iron for an edge and restores only that part to 100, following existing prototype repair rules. It creates no currency, contract, lesson, material or speech. These costs and thresholds are compatible project extensions, not claims about exact novel formulas. Missing prerequisites yield an explicit failed receipt with no consumption. A trip making no progress for 90 seconds closes as unfinished. Material is not consumed or guaranteed on admission.

The module keeps its job in its versioned command receipt, with immutable admission evidence and a separate terminal event. The common boundary exposes native jobs to physics and body-conflict checks. Work progress, command identity and completed/failed outcomes survive cold restore. Old saves acquire no new namespace merely by loading. A controlled seq148 copy verified actual movement and restart; natural model adoption remains unobserved.

## Conversation, privacy and consent

Free conversation requires explicit speech and a recipient currently in hearing range. It records the speaker, recipient, text and statement status. Words create neither a contract nor a verified belief, resource or skill. A ten-second world-time cooldown persists across restart. A busy resident cannot start a new speaking turn; the recipient may listen without stopping their work.

Private observation records only the actor's existing sensors: own position/needs, nearby identities and personally known places. It carries an explicit non-speech receipt, remains in the observer's personal history, and has a thirty-second cooldown. It reveals no other dossier or hidden inventory and grants no skill.

A joint visit requires an invitation and a separate decision by the invited resident. Both must be available, in hearing range and personally know the destination when accepting. Each starts its own existing travel primitive with its own arrival slot. The parent completes only after both children finish successfully; a failed child yields a blocked parent after all children settle, preserving any completed journey. An invitation may be declined, withdrawn or expire after 300 world seconds. At most one active plan per resident is allowed.

This first composition does not implement arbitrary teams, synchronized arrival, equal walking pace, shared farming/repair, a generic planner or cancellation of an already running visit. Those additions must extend explicit lifecycle and consent rules.

## Persistence and replay

The optional `godot.capabilities` namespace is created only by a successful native action. Loading an older save does not create it or alter its bytes. Each native command persists the exact actor/option/provenance/speech payload, capability version, admission event sequence, creation time, status and result. Identical replay has no second effect; changed payloads and cross-journal ID collisions are refused.

Shared plans retain their invitation, participants, place, expiry, accepted command and deterministic child IDs. Validation binds commands to actual attributed events, checks the consent/terminal event order, and compares the parent state with its real travel children. Unsupported versions, substituted consent, orphaned plans and claimed completion without child outcomes fail restoration. Historical versions require an explicit tested migration; they are never silently replaced with the current implementation.

An atomic child failure also rolls back when the outer resident-turn transaction intentionally retains a rejected model reply. The controller rebinds its turn record after rollback and archives the real rejection. This prevents either a lost paid reply or a partial departure. Unknown provider outcomes continue to use the existing recovery protocol.

## Model menu and extension workflow

All offered aliases remain available. Repeated descriptions use `action_groups`: a shared template and a mapping from each action alias to its arguments. The controller groups only when expansion exactly reproduces the original label; otherwise it sends the ordinary individual description. Speech permissions remain explicit and the authoritative frozen alias mapping is unchanged. Both the GDScript input boundary and C# provider forward the group descriptions and the actor's own active plans. Full profiles and canonical history stay in the save.

1. Add a reviewed module with `definitions`, pure `options`, `execute` and `validate_command`. Add `validate_state` and `reconcile` when it owns a durable protocol.
2. Register it in the world composition. Declare actual resource/consent/knowledge gates and a stable version; implement them in the reducer.
3. Compose existing actions for larger behavior. Use separate deterministic child IDs, all-or-nothing admission, and durable outcome reconciliation. Do not claim success when only work has started.
4. Define attributed events and personal projections. Keep private observations out of public speech and GM public-life feeds.
5. Verify a successful path, stale/conflicting input, resource or consent refusal, exact replay, partial failure, mid-job cold restore and a physical scene path when movement is involved. Check the real model input budget with rich profiles and crowded menus.
6. Publish the reviewed code and evidence, then observe voluntary adoption in the same live world. Installation and test success do not establish autonomous use.

Independent modules and bounded interfaces make engineering tasks easier to separate. They do not authorize multiple agents or parallel writes to one world.
