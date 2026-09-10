# Architecture boundaries

Status: intended structure, not completed implementation.

The formal game targets one Godot runtime. Keep a small world domain independent of nodes, cameras, rendering and model vendors. Do not introduce services, databases, plugin systems or a generic framework before the one-event slice requires them.

| Boundary | Responsibility | Must not do |
| --- | --- | --- |
| Presentation | Show resident positions, actions, visible needs and consequences; collect player input | Directly invent or change balances, memories or ownership |
| World rules | Validate positions, resources, money, commitments and permitted actions; issue receipts and events | Assume an LLM response is an authoritative fact |
| Persistence | Version state, preserve identity and event continuity, record accepted command IDs | Reset lives on startup or overwrite the source save during migration |
| Model adapter | Give a resident their own available information and return a proposed action | Write arbitrary world state or access another resident's hidden knowledge |

The first command is an offer of existing material, with a unique command ID, explicit validation and a stored result. Refusal and waiting are visible outcomes; a retry cannot transfer the same resource twice. Exact fields are fixed from the verified source behavior when that command is implemented, rather than inventing a broad new protocol here.

Migration reads a separately supplied, verified source save and writes a separate candidate output. Back up and retain the source. Compare world ID, identity IDs, relationships, ownership, money, inventory, outstanding commitments, memories and event position. Unsupported data must be reported and preserved, never silently discarded or treated as successfully migrated.

Test fixtures, public demo copies and the private main world are different environments. A public copy has a distinct world ID and contains no private credentials or operational budget history. At most one runtime writes any maintained world. Multi-user networking is not part of the first release.
