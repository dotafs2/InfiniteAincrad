# LocalJev-first resident provider

The resident host now has an optional local decision layer. It is disabled unless
`AINCRAD_LOCALJEV_ENABLED=1`, so existing offline fixtures and ordinary budget runs
keep the previous provider path.

When enabled, `LocalFirstProvider` sends the bounded resident view to the loopback
LocalJev `/v1/route` endpoint. Waiting, movement and other routine turns may then use
`/v1/systemone` to choose one offered action. Dialogue, contracts, scarce materials,
irreversible work and story-sensitive actions are policy-forced to the existing budget
gateway. A route or action confidence below the configured threshold (default `0.75`),
a stopped local service or a malformed local response also falls back to that gateway.
LocalJev never receives cloud credentials and never writes a world or fee ledger.

The Windows LocalJev launcher in the neighboring deployment uses these values:

```powershell
$env:AINCRAD_LOCALJEV_ENABLED = "1"
$env:AINCRAD_LOCALJEV_URL = "http://127.0.0.1:8080"
$env:AINCRAD_LOCALJEV_API_KEY = "local-dev-key"
$env:AINCRAD_LOCALJEV_MODEL = "qwen3:8b"
```

The host records the router model, selected route, route confidence, local decision
confidence, final model and fallback reason in the response metadata. The metadata is
kept beside the archived provider reply and is never inserted into the resident's
action object, so world validation still sees the unchanged decision contract.

The adapter's default-off behavior is covered by the existing gateway acceptance
fixtures. `game/tests/localjev_routing_metadata_acceptance.gd` checks the strict
metadata boundary without making a provider request. A live service check should use
`GET /ready` followed by one safe `/v1/route` and `/v1/systemone` request; those calls
are local and do not consume the Kimi budget.
