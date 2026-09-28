import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppPreferences {
    private enum DefaultsKey {
        static let showInDock = "showInDock"
        static let updatePreferenceWasChosen = "updatePreferenceWasChosen"
        static let automaticallyChecksForUpdates = "automaticallyChecksForUpdates"
        static let automaticallyDownloadsUpdates = "automaticallyDownloadsUpdates"
        static let hasLaunchedBefore = "hasLaunchedBefore"
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let applyDockVisibility: @MainActor (Bool) -> Void
    @ObservationIgnored private let applyUpdatePreferences: @MainActor (Bool, Bool) -> Void

    var showInDock: Bool {
        didSet {
            guard showInDock != oldValue else { return }
            defaults.set(showInDock, forKey: DefaultsKey.showInDock)
            applyDockVisibility(showInDock)
        }
    }

    private(set) var automaticallyChecksForUpdates: Bool
    private(set) var automaticallyDownloadsUpdates: Bool
    private var updatePreferenceWasChosen: Bool
    private let hasLaunchedBefore: Bool

    var shouldRequestUpdatePermission: Bool {
        hasLaunchedBefore && !updatePreferenceWasChosen
    }

    init(
        defaults: UserDefaults = .standard,
        applyDockVisibility: @escaping @MainActor (Bool) -> Void = AppPreferences.applyDockVisibility,
        applyUpdatePreferences: @escaping @MainActor (Bool, Bool) -> Void = { _, _ in }
    ) {
        self.defaults = defaults
        self.applyDockVisibility = applyDockVisibility
        self.applyUpdatePreferences = applyUpdatePreferences
        showInDock = defaults.bool(forKey: DefaultsKey.showInDock)
        updatePreferenceWasChosen = defaults.bool(forKey: DefaultsKey.updatePreferenceWasChosen)
        hasLaunchedBefore = defaults.bool(forKey: DefaultsKey.hasLaunchedBefore)
        let checksEnabled = defaults.bool(forKey: DefaultsKey.automaticallyChecksForUpdates)
        automaticallyChecksForUpdates = checksEnabled
        automaticallyDownloadsUpdates = checksEnabled
            && defaults.bool(forKey: DefaultsKey.automaticallyDownloadsUpdates)
        applyDockVisibility(showInDock)
        applyUpdatePreferences(automaticallyChecksForUpdates, automaticallyDownloadsUpdates)
        defaults.set(true, forKey: DefaultsKey.hasLaunchedBefore)
    }

    func enableAutomaticUpdateChecks(downloadAutomatically: Bool) {
        saveUpdatePreferences(checksEnabled: true, downloadsEnabled: downloadAutomatically)
    }

    func declineAutomaticUpdateChecks() {
        saveUpdatePreferences(checksEnabled: false, downloadsEnabled: false)
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        saveUpdatePreferences(
            checksEnabled: enabled,
            downloadsEnabled: enabled && automaticallyDownloadsUpdates
        )
    }

    private func saveUpdatePreferences(checksEnabled: Bool, downloadsEnabled: Bool) {
        updatePreferenceWasChosen = true
        automaticallyChecksForUpdates = checksEnabled
        automaticallyDownloadsUpdates = checksEnabled && downloadsEnabled

        defaults.set(true, forKey: DefaultsKey.updatePreferenceWasChosen)
        defaults.set(automaticallyChecksForUpdates, forKey: DefaultsKey.automaticallyChecksForUpdates)
        defaults.set(automaticallyDownloadsUpdates, forKey: DefaultsKey.automaticallyDownloadsUpdates)
        applyUpdatePreferences(automaticallyChecksForUpdates, automaticallyDownloadsUpdates)
    }

    private static func applyDockVisibility(_ showInDock: Bool) {
        NSApplication.shared.setActivationPolicy(showInDock ? .regular : .accessory)
    }
}
