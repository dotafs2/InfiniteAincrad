import Foundation
import UIKit
import StoreKit
import GoogleMobileAds
import UserMessagingPlatform

/// UIKit/StoreKit work stays on the main actor; Godot drains immutable events.
/// No callback invokes Godot from an SDK thread and no unverified order earns currency.
@objc(HoleFeastServices)
final class HoleFeastServices: NSObject, FullScreenContentDelegate {
    @objc static let shared = HoleFeastServices()
    private let lock = NSLock()
    private var events: [[String: Any]] = []
    private var adReady = false
    private var storeReady = false
    private var privacyRequired = false
    private var storeBusy = false
    private var finishing = Set<String>()
    private var knownTransactions = Set<String>()
    private var products: [String: Product] = [:]
    private var transactions: [String: Transaction] = [:]
    private var requestBindings: [UInt64: String] = [:]
    private var purchaseTask: Task<Void, Never>?
    private var updatesTask: Task<Void, Never>?
    private var replayTask: Task<Void, Never>?
    private var rewardedAd: RewardedAd?
    private var loadedAt: Date?
    private var adRequest = ""
    private var adsStarted = false
    private var sdkStarted = false
    private var loadingAd = false
    private var retryTask: Task<Void, Never>?
    private var loadFailures = 0
    private var updatingConsent = false
    private var needsConsentRecovery = true
    private var consentFailures = 0
    private var consentRetryTask: Task<Void, Never>?
    private var foregroundObserver: NSObjectProtocol?
    private var privacyFormOpen = false
    private var adLoadGeneration: UInt64 = 0
    @MainActor private var swallowHaptic: UIImpactFeedbackGenerator?
    @MainActor private var rivalHaptic: UIImpactFeedbackGenerator?
    @MainActor private weak var swallowHapticView: UIView?
    @MainActor private var hapticTestCount = 0
    private let allowedIDs: Set<String> = [
        "sink_city.coins_320", "sink_city.coins_2000", "sink_city.coins_9600",
        "sink_city.diamonds_60", "sink_city.diamonds_100", "sink_city.diamonds_360", "sink_city.diamonds_1800"
    ]

    private func synchronized<T>(_ body: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }; return body()
    }
    private func emit(_ channel: String, _ name: String, _ values: [String: Any] = [:]) {
        var event = values; event["channel"] = channel; event["name"] = name
        synchronized { events.append(event) }
    }
    @objc func drainEvents(_ channel: String) -> [[String: Any]] {
        synchronized {
            let result = events.filter { $0["channel"] as? String == channel }
            events.removeAll { $0["channel"] as? String == channel }
            return result
        }
    }
    @objc func rewardedAvailable() -> Bool { synchronized { adReady } }
    @objc func retryRewarded() {
        Task { @MainActor in
            // A player may change VPN/network route while the app remains open.
            // Cancel the long backoff and ask UMP/GMA for a fresh preload now.
            self.retryTask?.cancel(); self.retryTask = nil
            self.consentRetryTask?.cancel(); self.consentRetryTask = nil
            self.loadFailures = 0; self.consentFailures = 0
            self.adLoadGeneration &+= 1
            self.rewardedAd = nil
            self.synchronized { self.adReady = false }
            self.needsConsentRecovery = true
            self.emit("ads", "availability_changed")
            self.refreshConsent()
            if ConsentInformation.shared.canRequestAds { await self.startAdsIfPermitted() }
        }
    }
    @objc func purchasesAvailable() -> Bool { synchronized { storeReady && !storeBusy } }
    @objc func privacyOptionsRequired() -> Bool { synchronized { privacyRequired } }

    @objc func playSwallowHaptic(_ amplitude: Double) {
        guard amplitude.isFinite, amplitude > 0 else { return }
        Task { @MainActor in
            guard UIApplication.shared.applicationState == .active else {
                self.hapticTestDiagnostic("inactive", intensity: 0)
                return
            }
            let view = self.presentingController()?.view
            if self.swallowHapticView !== view {
                self.swallowHaptic = nil
                self.rivalHaptic = nil
                self.swallowHapticView = view
            }
            let rival = amplitude >= 0.70
            if rival && self.rivalHaptic == nil {
                if #available(iOS 17.5, *), let view {
                    self.rivalHaptic = UIImpactFeedbackGenerator(style: .medium, view: view)
                } else {
                    self.rivalHaptic = UIImpactFeedbackGenerator(style: .medium)
                }
            } else if !rival && self.swallowHaptic == nil {
                if #available(iOS 17.5, *), let view {
                    self.swallowHaptic = UIImpactFeedbackGenerator(style: .light, view: view)
                } else {
                    self.swallowHaptic = UIImpactFeedbackGenerator(style: .light)
                }
            }
            // A light, view-bound tap remains perceptible on current iPhones.
            // Gameplay still limits dense piles to one receipt every 90 ms.
            let generator = rival ? self.rivalHaptic : self.swallowHaptic
            let intensity = CGFloat(rival ? 0.90 : min(0.70, max(0.45, amplitude * 2)))
            generator?.prepare()
            generator?.impactOccurred(intensity: intensity)
            generator?.prepare()
            let route = (view == nil ? "unbound" : "view_bound") + (rival ? "_rival" : "_item")
            self.hapticTestDiagnostic(route, intensity: intensity)
        }
    }

    @MainActor private func hapticTestDiagnostic(_ route: String, intensity: CGFloat) {
        guard Bundle.main.object(forInfoDictionaryKey: "HoleFeastTestAds") as? Bool == true else { return }
        hapticTestCount += 1
        guard hapticTestCount <= 8 || hapticTestCount % 25 == 0 else { return }
        // Test packages only: no identifiers, network content or player data.
        let report: [String: Any] = ["calls": hapticTestCount, "route": route,
            "intensity": Double(intensity), "physical_sensation_verified": false]
        if let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
           let data = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]) {
            try? data.write(to: directory.appendingPathComponent("haptic-test-diagnostic.json"), options: .atomic)
        }
        NSLog("[HoleFeastHaptics] %@ call=%d intensity=%.2f", route, hapticTestCount, Double(intensity))
    }

    @MainActor private func presentingController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let window = scenes.filter({ $0.activationState == .foregroundActive })
            .flatMap({ $0.windows }).first(where: { $0.isKeyWindow }) else { return nil }
        var controller = window.rootViewController
        while let presented = controller?.presentedViewController { controller = presented }
        return controller
    }
    @objc func initializeAds() {
        Task { @MainActor in
            if self.adsStarted {
                if self.needsConsentRecovery { self.refreshConsent() }
                return
            }
            self.adsStarted = true
            let config = MobileAds.shared.requestConfiguration
            config.setPublisherFirstPartyIDEnabled(false)
            config.publisherPrivacyPersonalizationState = .disabled
            config.maxAdContentRating = .general
            // Age is not inferred from a store rating. No COPPA/TFUA certification is invented.
            self.foregroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { _ in
                Task { @MainActor in
                    // The plugin always uses the process-wide shared service.
                    // Do not capture its non-Sendable instance across queues.
                    let service = HoleFeastServices.shared
                    if service.needsConsentRecovery { service.refreshConsent() }
                    else { await service.startAdsIfPermitted() }
                }
            }
            self.refreshConsent()
        }
    }
    @MainActor private func testAdDiagnostic(_ state: String, error: Error? = nil) {
        // Only local official-test-ID packages log diagnostic codes. No user/ad
        // identifiers, consent strings or network payloads are logged.
        guard Bundle.main.object(forInfoDictionaryKey: "HoleFeastTestAds") as? Bool == true else { return }
        let code = error.map { ($0 as NSError).code } ?? 0
        NSLog("HoleFeast test ads: %@ code=%ld", state, code)
    }
    @MainActor private func refreshConsent() {
        guard !updatingConsent, !privacyFormOpen, adRequest.isEmpty else { return }
        guard UIApplication.shared.applicationState == .active,
              presentingController() != nil else {
            needsConsentRecovery = true
            scheduleConsentRetry(after: 1)
            return
        }
        consentRetryTask?.cancel(); consentRetryTask = nil
        updatingConsent = true
        Task { @MainActor in
            defer { self.updatingConsent = false }
            do {
                try await ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters())
                // The app can suspend while the update is awaiting the network.
                // Never present a form from the old/background controller.
                guard UIApplication.shared.applicationState == .active,
                      let controller = self.presentingController() else {
                    self.needsConsentRecovery = true
                    self.updatePrivacyRequirement()
                    self.scheduleConsentRetry(after: 1)
                    return
                }
                try await ConsentForm.loadAndPresentIfRequired(from: controller)
                self.needsConsentRecovery = false; self.consentFailures = 0
                self.testAdDiagnostic("consent_update_completed")
            } catch {
                self.needsConsentRecovery = true; self.consentFailures += 1
                self.testAdDiagnostic("consent_update_failed", error: error)
                let delay = min(300, 15 * (1 << min(5, self.consentFailures - 1)))
                self.scheduleConsentRetry(after: delay)
                // Google's own canRequestAds remains authoritative, including
                // valid prior-session consent. Failure never manufactures consent.
            }
            self.updatePrivacyRequirement()
            await self.startAdsIfPermitted()
        }
    }
    @MainActor private func scheduleConsentRetry(after delay: Int) {
        guard consentRetryTask == nil, UIApplication.shared.applicationState == .active else { return }
        consentRetryTask = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000) }
            catch { return }
            self.consentRetryTask = nil
            guard self.needsConsentRecovery else { return }
            self.refreshConsent()
        }
    }
    @MainActor private func updatePrivacyRequirement() {
        synchronized {
            privacyRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        }
        emit("ads", "availability_changed")
    }
    @MainActor private func startAdsIfPermitted() async {
        guard ConsentInformation.shared.canRequestAds,
              UIApplication.shared.applicationState == .active, !privacyFormOpen,
              adRequest.isEmpty else { return }
        if sdkStarted {
            if let loaded = loadedAt, Date().timeIntervalSince(loaded) >= 3600 {
                rewardedAd = nil; synchronized { adReady = false }
            }
            if rewardedAd != nil {
                synchronized { adReady = true }
                emit("ads", "availability_changed")
                return
            }
            loadRewarded(); return
        }
        sdkStarted = true
        await MobileAds.shared.start()
        testAdDiagnostic("sdk_started")
        loadRewarded()
    }
    @MainActor private func loadRewarded() {
        guard sdkStarted, ConsentInformation.shared.canRequestAds,
              UIApplication.shared.applicationState == .active, !privacyFormOpen,
              !loadingAd, adRequest.isEmpty, rewardedAd == nil else { return }
        guard let unit = Bundle.main.object(forInfoDictionaryKey: "HoleFeastRewardedUnit") as? String,
              !unit.isEmpty else { return }
        loadingAd = true
        let generation = adLoadGeneration
        retryTask?.cancel(); retryTask = nil
        Task { @MainActor in
            defer {
                self.loadingAd = false
                // Privacy choices may invalidate an in-flight request. Once its
                // callback drains, load under the latest choices if permitted.
                if generation != self.adLoadGeneration { self.loadRewarded() }
            }
            do {
                let request = Request()
                let extras = Extras(); extras.additionalParameters = ["npa": "1"]
                request.register(extras)
                let ad = try await RewardedAd.load(with: unit, request: request)
                guard generation == self.adLoadGeneration, !self.privacyFormOpen,
                      ConsentInformation.shared.canRequestAds else { return }
                self.rewardedAd = ad; self.loadedAt = Date(); self.loadFailures = 0
                ad.fullScreenContentDelegate = self
                self.synchronized { self.adReady = true }
                self.testAdDiagnostic("rewarded_ready")
                self.emit("ads", "availability_changed")
            } catch {
                guard generation == self.adLoadGeneration else { return }
                self.rewardedAd = nil; self.synchronized { self.adReady = false }
                self.emit("ads", "availability_changed")
                self.testAdDiagnostic("rewarded_load_failed", error: error)
                self.loadFailures += 1
                let delay = min(300, 15 * (1 << min(5, self.loadFailures - 1)))
                self.retryTask = Task { @MainActor in
                    do { try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000) }
                    catch { return }
                    self.loadRewarded()
                }
            }
        }
    }
    @objc func showRewarded(_ requestID: String) -> Bool {
        guard !requestID.isEmpty else { return false }
        let accepted = synchronized { () -> Bool in
            guard adReady else { return false }; adReady = false; return true
        }
        guard accepted else { return false }
        Task { @MainActor in
            guard let ad = self.rewardedAd, let loaded = self.loadedAt,
                  Date().timeIntervalSince(loaded) < 3600,
                  ConsentInformation.shared.canRequestAds,
                  let controller = self.presentingController(), self.adRequest.isEmpty else {
                self.emit("ads", "rewarded_failed", ["request_id": requestID,
                    "message": "The ad is no longer available. Please try again."])
                self.rewardedAd = nil; self.loadRewarded(); return
            }
            self.adRequest = requestID
            ad.present(from: controller) {
                // This is the SDK's earned-reward callback, never a timer/dismissal.
                self.testAdDiagnostic("rewarded_earned")
                self.emit("ads", "rewarded_earned", ["request_id": requestID])
            }
            self.emit("ads", "availability_changed")
        }
        return true
    }
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            let request = self.adRequest; self.adRequest = ""; self.rewardedAd = nil
            self.testAdDiagnostic("rewarded_closed")
            if !request.isEmpty { self.emit("ads", "rewarded_closed", ["request_id": request]) }
            self.loadRewarded()
            if self.needsConsentRecovery { self.refreshConsent() }
        }
    }
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            let request = self.adRequest; self.adRequest = ""; self.rewardedAd = nil
            self.testAdDiagnostic("rewarded_present_failed", error: error)
            if !request.isEmpty { self.emit("ads", "rewarded_failed", ["request_id": request,
                "message": "The video could not open. Please try again later."]) }
            self.loadRewarded()
            if self.needsConsentRecovery { self.refreshConsent() }
        }
    }
    @objc func showPrivacyOptions() -> Bool {
        guard privacyOptionsRequired() else { return false }
        synchronized { adReady = false }
        Task { @MainActor in
            guard let controller = self.presentingController(), self.adRequest.isEmpty,
                  !self.updatingConsent, !self.privacyFormOpen else {
                self.updatePrivacyRequirement()
                await self.startAdsIfPermitted()
                return
            }
            self.privacyFormOpen = true
            self.adLoadGeneration &+= 1
            self.consentRetryTask?.cancel(); self.consentRetryTask = nil
            self.retryTask?.cancel(); self.retryTask = nil
            self.rewardedAd = nil
            do { try await ConsentForm.presentPrivacyOptionsForm(from: controller) }
            catch { self.testAdDiagnostic("privacy_options_failed", error: error) }
            self.privacyFormOpen = false
            self.updatePrivacyRequirement(); await self.startAdsIfPermitted()
            if self.needsConsentRecovery { self.scheduleConsentRetry(after: 15) }
        }
        return true
    }

    @objc func initializeCommerce() {
        Task { @MainActor in
            guard self.updatesTask == nil else { return }
            self.synchronized { self.storeReady = AppStore.canMakePayments }
            self.updatesTask = Task { @MainActor in
                for await result in Transaction.updates { self.receive(result) }
            }
            self.replayTask = Task { @MainActor in
                // Retry unfinished verified transactions until durable wallet acknowledgement.
                while !Task.isCancelled {
                    for await result in Transaction.unfinished { self.receive(result) }
                    do { try await Task.sleep(nanoseconds: 10_000_000_000) }
                    catch { return }
                }
            }
            self.emit("commerce", "availability_changed")
        }
    }
    @objc func requestProducts(_ identifiers: [String]) {
        Task { @MainActor in
            let requested = Set(identifiers).intersection(self.allowedIDs)
            do {
                let result = try await Product.products(for: requested)
                self.products = Dictionary(uniqueKeysWithValues: result
                    .filter { $0.type == .consumable && requested.contains($0.id) }.map { ($0.id, $0) })
                let values = self.products.values.sorted { $0.id < $1.id }.map {
                    ["product_id": $0.id, "localized_price": $0.displayPrice]
                }
                self.emit("commerce", "products_received", ["products": values])
            } catch {
                self.products = [:]
                self.emit("commerce", "products_received", ["products": [[String: String]]()])
            }
        }
    }
    @objc func purchase(_ productID: String, requestID: String) -> Bool {
        guard allowedIDs.contains(productID), !requestID.isEmpty else { return false }
        let accepted = synchronized { () -> Bool in
            guard storeReady, !storeBusy else { return false }; storeBusy = true; return true
        }
        guard accepted else { return false }
        purchaseTask = Task { @MainActor in
            defer { self.synchronized { self.storeBusy = false }; self.emit("commerce", "availability_changed") }
            guard let product = self.products[productID], AppStore.canMakePayments else {
                self.emit("commerce", "purchase_failed", ["request_id": requestID,
                    "message": "The store product is unavailable."]); return
            }
            do {
                switch try await product.purchase() {
                case .success(let result):
                    if case .verified(let transaction) = result,
                       transaction.productID == productID {
                        self.requestBindings[transaction.id] = requestID
                        self.receive(result)
                    } else {
                        self.emit("commerce", "purchase_failed", ["request_id": requestID,
                            "message": "The App Store could not verify this purchase."])
                    }
                case .pending:
                    self.emit("commerce", "purchase_pending", ["request_id": requestID])
                case .userCancelled:
                    self.emit("commerce", "purchase_failed", ["request_id": requestID,
                        "message": "Purchase cancelled. No currency added."])
                @unknown default:
                    self.emit("commerce", "purchase_failed", ["request_id": requestID,
                        "message": "Purchase not completed."])
                }
            } catch {
                self.emit("commerce", "purchase_failed", ["request_id": requestID,
                    "message": "Purchase not completed. Please try again later."])
            }
        }
        return true
    }
    @MainActor private func receive(_ result: VerificationResult<Transaction>) {
        guard case .verified(let transaction) = result,
              allowedIDs.contains(transaction.productID), transaction.productType == .consumable,
              transaction.revocationDate == nil, transaction.purchasedQuantity == 1 else { return }
        let identity = String(transaction.id)
        guard !synchronized({ finishing.contains(identity) }) else { return }
        transactions[identity] = transaction
        synchronized { _ = knownTransactions.insert(identity) }
        emit("commerce", "purchase_verified", ["transaction_id": identity,
            "product_id": transaction.productID, "request_id": requestBindings[transaction.id] ?? ""])
    }
    @objc func acknowledge(_ identity: String) -> Bool {
        // Returning accepted only schedules finish. A crash before finish redelivers safely.
        let disposition = synchronized { () -> Int in
            guard knownTransactions.contains(identity) else { return 0 }
            guard !finishing.contains(identity) else { return 1 }
            finishing.insert(identity); return 2
        }
        guard disposition != 0 else { return false }
        if disposition == 1 { return true }
        Task { @MainActor in
            guard let transaction = self.transactions[identity] else {
                self.synchronized { _ = self.finishing.remove(identity) }; return
            }
            await transaction.finish()
            self.transactions.removeValue(forKey: identity)
            self.requestBindings.removeValue(forKey: transaction.id)
            self.synchronized {
                _ = self.finishing.remove(identity); _ = self.knownTransactions.remove(identity)
            }
        }
        return true
    }
}
