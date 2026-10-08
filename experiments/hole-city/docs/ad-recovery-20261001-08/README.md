# Native rewarded-ad recovery — October 1, 2026

The user deferred Apple login restoration and asked for independent work to
continue. This checkpoint fixes confirmed recovery gaps in the native adapter;
it does not establish the cause of the user's physical `Video is not ready`
message or certify a working production ad.

## Changed behavior

A failed first UMP update or required form now retries while the app is active,
with delays of 15, 30, 60, 120, 240 and then at most 300 seconds. A background
launch or suspended response waits for a current foreground presenter. UMP's
`canRequestAds` remains authoritative, including actual prior-session consent;
failure never manufactures permission. Successful flows that disallow ad
requests do not repeatedly prompt. SDK initialization remains idempotent.

Opening privacy options invalidates the current preload generation. An old
asynchronous callback cannot make that ad ready, and the latest permitted
request starts after both the form and stale callback drain. A privacy action
that cannot obtain a foreground presenter preserves a valid preload and restores
its ready state upon return. Foreground notifications cannot mark a currently
presented video ready again. Rewards still come only from Google's earned
callback with the original round request identity.

Local diagnostics are emitted only by packages explicitly using official test
IDs; they contain a state and numeric error code, with no consent strings,
user/ad identifiers or network payloads. Production packages do not emit those
diagnostics. Production identifiers, nonpersonalized requests, first-party ID
settings, vendor privacy manifests and purchase/wallet logic are unchanged.

## Acceptance evidence and limits

The focused runner extracts the actual Swift advertising methods and compiles
them against controlled SDK/UI boundaries. It replaces only the timer wait
with a manually released clock, retaining the actual computed delay. Each
scenario executes in an isolated process; source, extracted-method and fixture
hashes are retained. It makes no Google/Apple network or payment request.

- [Final report](../../artifacts/ad-recovery-20261001-08/after-03.json):
  **40 checks, zero failures across 11 scenarios**. Native adapter SHA-256 is
  `4b816e5c136a16357f14a16645446256b0444b03999156df264d02d39b95dd4a`.
- [Controlled earlier-source comparison](../../artifacts/ad-recovery-20261001-08/before-02.json):
  36 checks with 19 failures against the preserved build-7 adapter. These cover
  first-request recovery, background handling, bounded consent retries and
  privacy/preload races. The matching intermediate repair passed all 36.
- The first accelerated-clock fixture had unreliable asynchronous waits. Its
  failed output and original fixture files remain in ignored `build/` evidence;
  those failures are not all attributed to the game. The manually controlled
  clock replaces that fixture. Later final tests add presentation/readiness
  cases and pass all 40.

This is method-level behavior acceptance, not live SDK callback acceptance.
The [production build-9 receipt](../../artifacts/ad-recovery-20261001-08/native-09/production-candidate.json)
confirms compilation/linking against the real SDKs, the matching final adapter,
8,547 freshly executed native-PCK checks, production identifiers, 50 SKAdNetwork
IDs and unchanged vendor privacy bundles. Its PCK is 10,680,760 bytes with hash
`f516cc58f6efd266c32b49757604eff1d0bc69f9d83c43c7c6b675d2564bb395`.
It is unsigned, not installed or uploaded. The game/Web inputs remain
the accepted 804-input 0.12.3 snapshot; no unchanged full Web gate is rerun.

Reproduce in a fresh evidence directory:

```sh
python3 tools/test_native_ads_recovery.py \
  --source native/ios/HoleFeastServices.swift \
  --evidence build/ad-recovery-recheck \
  --report artifacts/ad-recovery-recheck.json
```

## Resume

Use the latest accepted production candidate recorded in the
[release handoff](../app-store-release-20261001/README.md). Build 7's signed
archive and build 8's intermediate unsigned package are preserved checkpoints;
both precede the final readiness repair and must not be uploaded as the final
repair. The installed build 6 uses official test IDs and predates these changes.

After the user restores Apple login and unlocks the phone, prepare/sign a
separate official-test-ID package, preserve the actual save before updating,
and accept normal-mode consent, ready, presentation, earned, dismissal and
failure callbacks. Do not exercise production ads for testing. Continue Apple
sandbox purchases, truthful privacy disclosures, current train/collection
captures and the already-authorized US App Review submission. Existing account,
agreement and product requirements remain; no new installation, upload or
submission is implied by this repair.
