import Foundation

enum UpdateSafetyPolicy {
    static func allowsUpdateWork(while state: AppModel.State) -> Bool {
        switch state {
        case .idle, .error:
            true
        case .arming, .locked, .restored:
            false
        }
    }
}

@MainActor
final class UpdateDeferralCoordinator {
    private var shouldRetryCheck = false
    private var pendingInstallHandler: (() -> Void)?

    func recordBlockedCheck() {
        shouldRetryCheck = true
    }

    func postponeInstallation(
        while state: AppModel.State,
        installHandler: @escaping () -> Void
    ) -> Bool {
        guard !UpdateSafetyPolicy.allowsUpdateWork(while: state) else {
            return false
        }

        pendingInstallHandler = installHandler
        return true
    }

    func stateDidChange(
        to state: AppModel.State,
        retryCheck: () -> Void
    ) {
        guard UpdateSafetyPolicy.allowsUpdateWork(while: state) else {
            return
        }

        if let installHandler = pendingInstallHandler {
            pendingInstallHandler = nil
            shouldRetryCheck = false
            installHandler()
        } else if shouldRetryCheck {
            shouldRetryCheck = false
            retryCheck()
        }
    }
}
