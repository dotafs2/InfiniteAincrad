import Foundation

@main struct Acceptance {
    @MainActor static func main() async {
        let scenario = CommandLine.arguments.dropFirst().first ?? "network"
        let service = HoleFeastServices.shared
        var checks = 0
        var failures: [String] = []
        func check(_ value: Bool, _ label: String) {
            checks += 1
            if !value { failures.append(label) }
        }
        func settle(_ milliseconds: UInt64 = 5) async {
            for _ in 0..<20 { await Task.yield() }
            try? await Task.sleep(nanoseconds: milliseconds * 1_000_000)
        }
        func until(_ condition: () -> Bool) async {
            for _ in 0..<300 {
                if condition() { return }
                await settle(1)
            }
        }
        func fireRetry() async {
            await until { !FixtureClock.pending.isEmpty }
            FixtureClock.fire(); await settle()
        }
        func foreground() {
            UIApplication.shared.applicationState = .active
            NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        }
        if scenario == "haptic" {
            for invalid in [0.0, -1.0, Double.nan, Double.infinity] { service.playSwallowHaptic(invalid) }
            await settle()
            check(Fixture.hapticGenerators == 0 && Fixture.hapticIntensities.isEmpty, "Invalid or disabled intensity cannot create a haptic pulse")
            UIApplication.shared.applicationState = .background
            service.playSwallowHaptic(0.24); await settle()
            check(Fixture.hapticGenerators == 0, "A background receipt cannot vibrate")
            UIApplication.shared.applicationState = .active
            for intensity in [0.18, 0.24, 0.34, 1.0] { service.playSwallowHaptic(intensity) }
            await settle()
            check(Fixture.hapticGenerators == 2, "Items and rival victories reuse distinct UIKit generators")
            check(Fixture.hapticIntensities == [0.45, 0.48, 0.68, 0.90], "Rival victories get a stronger bounded pulse than ordinary items")
            check(Fixture.hapticPrepareCalls == 8, "Every pulse prepares the generator before and after delivery")
            check(Fixture.hapticViews.count == 2, "Both feedback generators are attached to the foreground game view")
            let scene = UIApplication.shared.connectedScenes.first as! UIWindowScene
            scene.windows[0].rootViewController = UIViewController()
            service.playSwallowHaptic(0.18); await settle()
            check(Fixture.hapticGenerators == 3 && Fixture.hapticViews.count == 3, "Replacing the foreground view creates a generator for the new view")
            check(Fixture.updateCalls == 0 && Fixture.loadCalls == 0, "Native haptics do not depend on advertising initialization")
        } else if scenario == "network" {
            Fixture.updateFailures = 1
            service.initializeAds(); await until { Fixture.updateCalls > 0 }; await settle()
            check(Fixture.updateCalls == 1 && Fixture.startCalls == 0, "A failed first update cannot initialize ads without UMP permission")
            check(!service.rewardedAvailable(), "No fabricated ready state before consent recovery")
            await fireRetry(); await until { service.rewardedAvailable() }
            check(Fixture.updateCalls == 2 && Fixture.formCalls == 1, "Automatic retry recovers a failed first-session update")
            check(Fixture.startCalls == 1 && Fixture.loadCalls == 1 && service.rewardedAvailable(), "Recovered consent starts one SDK and loads one ad")
            service.initializeAds(); foreground(); foreground(); await settle()
            check(Fixture.startCalls == 1 && Fixture.loadCalls == 1, "Repeat initialization and foreground do not duplicate a ready ad")
        } else if scenario == "background" {
            UIApplication.shared.applicationState = .background
            service.initializeAds(); await settle(25)
            check(Fixture.updateCalls == 0 && Fixture.startCalls == 0, "Background launch performs no consent form or ad request")
            foreground(); await until { service.rewardedAvailable() }
            check(Fixture.updateCalls == 1 && Fixture.formCalls == 1 && service.rewardedAvailable(), "Foreground recovers a postponed initial request")
        } else if scenario == "suspend-update" {
            Fixture.holdUpdate = true
            service.initializeAds(); await until { Fixture.updateWait != nil }
            check(Fixture.updateCalls == 1 && Fixture.updateWait != nil, "Consent request is genuinely awaiting a boundary callback")
            UIApplication.shared.applicationState = .background
            Fixture.holdUpdate = false; Fixture.updateWait?.resume(); Fixture.updateWait = nil
            await settle(25)
            check(Fixture.formCalls == 0 && Fixture.startCalls == 0, "Returning update does not present from a suspended controller")
            foreground(); await until { service.rewardedAvailable() }
            check(Fixture.updateCalls == 2 && Fixture.formCalls == 1 && service.rewardedAvailable(), "Foreground retries the abandoned presentation path")
        } else if scenario == "denied" {
            Fixture.formAllowsAds = false
            service.initializeAds(); await settle(35)
            foreground(); await settle()
            check(Fixture.updateCalls == 1 && Fixture.formCalls == 1, "Successful privacy flow is not repeatedly prompted when permission is absent")
            check(Fixture.startCalls == 0 && Fixture.loadCalls == 0 && !service.rewardedAvailable(), "Privacy outcome that disallows requests never loads an ad")
        } else if scenario == "cached" {
            ConsentInformation.shared.canRequestAds = true; Fixture.updateFailures = 1
            service.initializeAds(); await until { service.rewardedAvailable() }
            check(Fixture.startCalls == 1 && service.rewardedAvailable(), "A failed refresh can use only actual SDK-granted prior consent")
            await fireRetry()
            check(Fixture.updateCalls == 2 && Fixture.startCalls == 1 && Fixture.loadCalls == 1, "Privacy refresh recovers without duplicate initialization or preloads")
        } else if scenario == "form-failure" {
            Fixture.formFailures = 1
            service.initializeAds(); await settle(); await fireRetry(); await until { service.rewardedAvailable() }
            check(Fixture.formCalls == 2 && Fixture.updateCalls == 2, "Failed required form retries through a fresh consent update")
            check(Fixture.startCalls == 1 && service.rewardedAvailable(), "Only the successful form enables first-session loading")
        } else if scenario == "privacy-race" {
            Fixture.holdLoad = true
            service.initializeAds(); await until { Fixture.loadWait != nil }
            check(Fixture.loadWait != nil && !service.rewardedAvailable(), "Preload waits for its real callback")
            Fixture.holdPrivacy = true
            check(service.showPrivacyOptions(), "Required privacy choices may open before a preload finishes")
            await until { Fixture.privacyWait != nil }
            check(Fixture.privacyCalls == 1, "One privacy form opens")
            Fixture.holdLoad = false; Fixture.loadWait?.resume(); Fixture.loadWait = nil
            await settle()
            check(!service.rewardedAvailable() && Fixture.loadCalls == 1, "Old preload callback cannot become ready while privacy choices are open")
            Fixture.holdPrivacy = false; Fixture.privacyWait?.resume(); Fixture.privacyWait = nil
            await until { service.rewardedAvailable() }
            check(service.rewardedAvailable() && Fixture.loadCalls == 2, "Closing choices reloads using the latest permission generation")
        } else if scenario == "privacy-closes-first" {
            Fixture.holdLoad = true
            service.initializeAds(); await until { Fixture.loadWait != nil }
            check(Fixture.loadWait != nil && service.showPrivacyOptions(), "Privacy choices start while an older preload awaits completion")
            await settle()
            Fixture.holdLoad = false; Fixture.loadWait?.resume(); Fixture.loadWait = nil
            await until { service.rewardedAvailable() }
            check(Fixture.loadCalls == 2 && service.rewardedAvailable(), "A late old callback reloads even when the form already closed")
        } else if scenario == "reward" {
            service.initializeAds(); await until { service.rewardedAvailable() }
            check(service.showRewarded("round-real"), "SDK-ready video accepts its original request ID")
            await settle()
            check(Fixture.presentations == 1 && !service.rewardedAvailable(), "Presentation reserves availability")
            foreground(); await settle()
            check(!service.rewardedAvailable() && Fixture.loadCalls == 1, "Foreground cannot make an already-presented video available again")
            check(!service.drainEvents("ads").contains { $0["name"] as? String == "rewarded_earned" }, "Presenting never fabricates an earned reward")
            Fixture.earned?()
            check(service.drainEvents("ads").contains { $0["name"] as? String == "rewarded_earned" && $0["request_id"] as? String == "round-real" }, "Only SDK earned callback carries the original reward identity")
            if let ad = Fixture.lastAd { service.adDidDismissFullScreenContent(ad) }
            await until { service.rewardedAvailable() }
            check(service.rewardedAvailable() && Fixture.loadCalls == 2, "Actual dismissal enables the next preload")
        } else if scenario == "privacy-inactive" {
            service.initializeAds(); await until { service.rewardedAvailable() }
            let scene = UIApplication.shared.connectedScenes.first as! UIWindowScene
            scene.activationState = .background; UIApplication.shared.applicationState = .background
            check(service.showPrivacyOptions(), "Privacy action can be queued before main-actor visibility is checked")
            await settle()
            check(Fixture.privacyCalls == 0 && Fixture.loadCalls == 1, "Missing foreground presenter never opens a form or requests a replacement ad")
            scene.activationState = .foregroundActive; foreground()
            await until { service.rewardedAvailable() }
            check(service.rewardedAvailable() && Fixture.loadCalls == 1, "Returning foreground restores the untouched valid preload after an unpresentable privacy action")
        } else if scenario == "backoff" {
            Fixture.updateFailures = 8
            service.initializeAds(); await until { !FixtureClock.pending.isEmpty }
            for expected in [15,30,60,120,240,300,300] {
                check(FixtureClock.requested.last == expected, "Consent retry uses bounded computed delay: " + String(expected))
                await fireRetry()
            }
            check(Fixture.startCalls == 0 && Fixture.loadCalls == 0, "Repeated network failure never invents permission or readiness")
        } else { failures.append("Unknown scenario") }
        let result: [String:Any] = ["scenario":scenario,"checks":checks,"failures":failures,"update_calls":Fixture.updateCalls,"sdk_starts":Fixture.startCalls,"load_calls":Fixture.loadCalls,"retry_delays":FixtureClock.requested]
        let data = try! JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
        print(String(data:data,encoding:.utf8)!)
        exit(failures.isEmpty ? 0 : 1)
    }
}
