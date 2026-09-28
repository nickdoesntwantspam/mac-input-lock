import Foundation
import Sparkle

@MainActor
final class AppUpdater: NSObject, SPUUpdaterDelegate {
    private let stateProvider: () -> AppModel.State
    private let deferralCoordinator = UpdateDeferralCoordinator()
    private var updaterController: SPUStandardUpdaterController?

    init(stateProvider: @escaping () -> AppModel.State) {
        self.stateProvider = stateProvider
        super.init()
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }

    func canCheckForUpdates(while state: AppModel.State) -> Bool {
        UpdateSafetyPolicy.allowsUpdateWork(while: state)
            && updaterController?.updater.canCheckForUpdates == true
    }

    func checkForUpdates() {
        guard UpdateSafetyPolicy.allowsUpdateWork(while: stateProvider()) else {
            return
        }
        updaterController?.checkForUpdates(nil)
    }

    func applyAutomaticUpdatePreferences(checksEnabled: Bool, downloadsEnabled: Bool) {
        guard let updater = updaterController?.updater else { return }
        updater.automaticallyChecksForUpdates = checksEnabled
        updater.automaticallyDownloadsUpdates = checksEnabled && downloadsEnabled
    }

    func stateDidChange(to state: AppModel.State) {
        deferralCoordinator.stateDidChange(to: state) { [weak self] in
            self?.updaterController?.updater.resetUpdateCycleAfterShortDelay()
        }
    }

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        guard UpdateSafetyPolicy.allowsUpdateWork(while: stateProvider()) else {
            deferralCoordinator.recordBlockedCheck()
            throw NSError(
                domain: "com.nicholaswilliams.MacInputLock.Updates",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Mac Input Lock will check for updates after input is restored."
                ]
            )
        }
    }

    func updater(
        _ updater: SPUUpdater,
        shouldPostponeRelaunchForUpdate item: SUAppcastItem,
        untilInvokingBlock installHandler: @escaping () -> Void
    ) -> Bool {
        deferralCoordinator.postponeInstallation(
            while: stateProvider(),
            installHandler: installHandler
        )
    }
}
