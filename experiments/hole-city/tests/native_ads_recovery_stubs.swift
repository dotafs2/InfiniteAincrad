import Foundation

// SDK/UI boundary fixtures only. The runner extracts and compiles the actual
// native ad methods; no recovery or reward logic is reimplemented here.
enum FixtureError: Error { case network }
@MainActor enum FixtureClock {
    static var next = 0
    static var pending: [Int:(Int,CheckedContinuation<Void,Error>)] = [:]
    static var requested: [Int] = []
    static func sleep(seconds: Int) async throws {
        let ticket = next; next += 1; requested.append(seconds)
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { pending[ticket] = (seconds,$0) }
        }, onCancel: {
            Task { @MainActor in pending.removeValue(forKey: ticket)?.1.resume(throwing: CancellationError()) }
        })
    }
    static func fire() {
        guard let ticket = pending.keys.min(), let item = pending.removeValue(forKey: ticket) else { return }
        item.1.resume()
    }
}
enum Fixture {
    static var updateCalls = 0
    static var updateFailures = 0
    static var updateWait: CheckedContinuation<Void, Never>?
    static var holdUpdate = false
    static var formCalls = 0
    static var formFailures = 0
    static var formAllowsAds = true
    static var privacyCalls = 0
    static var privacyWait: CheckedContinuation<Void, Never>?
    static var holdPrivacy = false
    static var loadCalls = 0
    static var loadFailures = 0
    static var loadWait: CheckedContinuation<Void, Never>?
    static var holdLoad = false
    static var startCalls = 0
    static var initializedConfiguration = false
    static var lastAd: RewardedAd?
    static var presentations = 0
    static var earned: (() -> Void)?
    static var hapticGenerators = 0
    static var hapticIntensities: [CGFloat] = []
    static var hapticPrepareCalls = 0
    static var hapticViews: [UIView] = []
}
class UIImpactFeedbackGenerator: NSObject {
    enum Style { case soft, light, medium }
    init(style: Style) { Fixture.hapticGenerators += 1 }
    init(style: Style, view: UIView) {
        Fixture.hapticGenerators += 1
        Fixture.hapticViews.append(view)
    }
    func impactOccurred(intensity: CGFloat) { Fixture.hapticIntensities.append(intensity) }
    func prepare() { Fixture.hapticPrepareCalls += 1 }
}
class UIView: NSObject {}
class UIViewController: NSObject {
    var presentedViewController: UIViewController?
    var view = UIView()
}
class UIScene: NSObject {
    enum ActivationState { case foregroundActive, background }
    var activationState = ActivationState.foregroundActive
}
class UIWindow: NSObject { var isKeyWindow = true; var rootViewController: UIViewController? = UIViewController() }
class UIWindowScene: UIScene { var windows = [UIWindow()] }
class UIApplication: NSObject {
    enum State { case active, background }
    static let shared = UIApplication()
    static let didBecomeActiveNotification = Notification.Name("FixtureForeground")
    var applicationState = State.active
    var connectedScenes: Set<UIScene> = [UIWindowScene()]
}
protocol FullScreenPresentingAd: AnyObject {}
protocol FullScreenContentDelegate: AnyObject {}
enum Personalization { case disabled }
enum ContentRating { case general }
class RequestConfiguration {
    var publisherPrivacyPersonalizationState = Personalization.disabled
    var maxAdContentRating = ContentRating.general
    func setPublisherFirstPartyIDEnabled(_ enabled: Bool) { Fixture.initializedConfiguration = !enabled }
}
class MobileAds {
    static let shared = MobileAds()
    let requestConfiguration = RequestConfiguration()
    func start() async { Fixture.startCalls += 1 }
}
class Request { func register(_ extra: Extras) {} }
class Extras { var additionalParameters: [String:String] = [:] }
class RewardedAd: FullScreenPresentingAd {
    weak var fullScreenContentDelegate: FullScreenContentDelegate?
    static func load(with unit: String, request: Request) async throws -> RewardedAd {
        Fixture.loadCalls += 1
        if Fixture.holdLoad { await withCheckedContinuation { Fixture.loadWait = $0 } }
        if Fixture.loadFailures > 0 { Fixture.loadFailures -= 1; throw FixtureError.network }
        let ad = RewardedAd(); Fixture.lastAd = ad; return ad
    }
    func present(from controller: UIViewController, userDidEarnRewardHandler: @escaping () -> Void) {
        Fixture.presentations += 1; Fixture.earned = userDidEarnRewardHandler
    }
}
class RequestParameters {}
class ConsentInformation {
    enum Requirement { case required, notRequired }
    static let shared = ConsentInformation()
    var canRequestAds = false
    var privacyOptionsRequirementStatus = Requirement.required
    func requestConsentInfoUpdate(with parameters: RequestParameters) async throws {
        Fixture.updateCalls += 1
        if Fixture.holdUpdate { await withCheckedContinuation { Fixture.updateWait = $0 } }
        if Fixture.updateFailures > 0 { Fixture.updateFailures -= 1; throw FixtureError.network }
    }
}
class ConsentForm {
    static func loadAndPresentIfRequired(from controller: UIViewController) async throws {
        Fixture.formCalls += 1
        if Fixture.formFailures > 0 { Fixture.formFailures -= 1; throw FixtureError.network }
        ConsentInformation.shared.canRequestAds = Fixture.formAllowsAds
    }
    static func presentPrivacyOptionsForm(from controller: UIViewController) async throws {
        Fixture.privacyCalls += 1
        if Fixture.holdPrivacy { await withCheckedContinuation { Fixture.privacyWait = $0 } }
    }
}
// Commerce is not executed or represented by this focused ad-flow harness.
struct Product {}
struct Transaction {}
