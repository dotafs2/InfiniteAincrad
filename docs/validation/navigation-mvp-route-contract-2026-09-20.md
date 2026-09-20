# Navigation MVP Route Contract

This contract is intentionally smaller than the physical navigation system. It
covers the current loaded world only and treats the world layout as static for
the duration of a run.

## Runtime contract

- `TownRouteGraph` stores abstract walkable regions and authored connector edges.
- A connector is a straight graph edge. The MVP does not validate endpoint
  placement, clearance, collision, or floor geometry at runtime.
- `TownRouteConnector` may trigger a semantic action such as `open_door` and
  then force the actor to its exit position.
- NPCs may overlap and the connector executor does not perform physics checks.
- The target is a stable resident ID. A matching position is not enough when
  multiple residents overlap.
- The graph is populated once for the loaded scene. Adding, removing, or moving
  world components during the run is outside the MVP.

## Acceptance contract

For a route from resident `A` to resident `B`:

1. Every region transition must be represented by a registered graph connector.
2. The route must finish with target ID `B`.
3. Connector actions must be emitted in route order.
4. The actor's final position must equal the target position used by the test.
5. Reverse traversal is accepted only for bidirectional connectors.

The acceptance suite deliberately does not assert physical collision behavior.
Scene authoring and later physical validation can add those checks without
changing the MVP route contract.
