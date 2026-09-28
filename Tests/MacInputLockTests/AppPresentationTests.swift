import XCTest
@testable import MacInputLock

@MainActor
final class AppPresentationTests: XCTestCase {
    func testLaunchPointsToStatusItemWhenItIsSafelyVisible() {
        XCTAssertEqual(
            AppPresentationPolicy.launchAction(statusItemIsSafelyVisible: true),
            .showLaunchGuidance
        )
    }

    func testLaunchShowsHiddenItemWindowWhenStatusItemIsNotSafelyVisible() {
        XCTAssertEqual(
            AppPresentationPolicy.launchAction(statusItemIsSafelyVisible: false),
            .showControlWindow(.hiddenStatusItem)
        )
    }

    func testReopeningAlwaysShowsNormalControlWindow() {
        XCTAssertEqual(
            AppPresentationPolicy.reopenAction,
            .showControlWindow(.reopened)
        )
    }

    func testVisibleItemBecomingHiddenShowsRecoveryWindow() {
        XCTAssertEqual(
            AppPresentationPolicy.visibilityChangeAction(wasVisible: true, isVisible: false),
            .showControlWindow(.hiddenStatusItem)
        )
    }

    func testRepeatedHiddenChecksDoNotRepeatedlyShowRecoveryWindow() {
        XCTAssertNil(
            AppPresentationPolicy.visibilityChangeAction(wasVisible: false, isVisible: false)
        )
    }

    func testVisibleOrNewlyVisibleItemsDoNotShowRecoveryWindow() {
        XCTAssertNil(AppPresentationPolicy.visibilityChangeAction(wasVisible: nil, isVisible: true))
        XCTAssertNil(AppPresentationPolicy.visibilityChangeAction(wasVisible: false, isVisible: true))
        XCTAssertNil(AppPresentationPolicy.visibilityChangeAction(wasVisible: true, isVisible: true))
    }

    func testControlWindowReasonsHaveDistinctUserFacingCopy() {
        XCTAssertEqual(ControlWindowReason.reopened.title, "Mac Input Lock")
        XCTAssertEqual(
            ControlWindowReason.reopened.message,
            "Use these controls whenever the menu-bar padlock is unavailable."
        )
        XCTAssertEqual(ControlWindowReason.hiddenStatusItem.title, "The padlock is hidden")
        XCTAssertTrue(ControlWindowReason.hiddenStatusItem.message.contains("menu bar"))
    }

    func testDockPreferenceDefaultsToMenuBarOnlyAndAppliesIt() {
        let defaults = makeDefaults()
        var appliedValues: [Bool] = []

        let preferences = AppPreferences(defaults: defaults) { appliedValues.append($0) }

        XCTAssertFalse(preferences.showInDock)
        XCTAssertEqual(appliedValues, [false])
    }

    func testDockPreferencePersistsAndAppliesChanges() {
        let defaults = makeDefaults()
        var appliedValues: [Bool] = []
        let preferences = AppPreferences(defaults: defaults) { appliedValues.append($0) }

        preferences.showInDock = true

        XCTAssertEqual(appliedValues, [false, true])

        var restoredValues: [Bool] = []
        let restored = AppPreferences(defaults: defaults) { restoredValues.append($0) }
        XCTAssertTrue(restored.showInDock)
        XCTAssertEqual(restoredValues, [true])
    }

    func testControlSectionsHaveAStableVisualHierarchy() {
        XCTAssertEqual(LockMenuSection.allCases, [.inputLock, .access, .updates])
        XCTAssertEqual(LockMenuSection.inputLock.title, "INPUT LOCK")
        XCTAssertEqual(LockMenuSection.access.title, "ACCESS")
        XCTAssertEqual(LockMenuSection.updates.title, "UPDATES")
    }

    func testWindowPlacementCentersOnTheStatusItemsScreen() {
        XCTAssertEqual(
            WindowPlacement.centeredOrigin(
                windowSize: CGSize(width: 600, height: 260),
                in: CGRect(x: 100, y: 200, width: 1_200, height: 800)
            ),
            CGPoint(x: 400, y: 470)
        )
    }

    func testUpdatePermissionIsRequestedOnSecondLaunchAndAutomationStartsDisabled() {
        let defaults = makeDefaults()
        var appliedValues: [(checks: Bool, downloads: Bool)] = []

        let firstLaunchPreferences = AppPreferences(
            defaults: defaults,
            applyDockVisibility: { _ in },
            applyUpdatePreferences: { appliedValues.append(($0, $1)) }
        )

        XCTAssertFalse(firstLaunchPreferences.shouldRequestUpdatePermission)

        let secondLaunchPreferences = AppPreferences(
            defaults: defaults,
            applyDockVisibility: { _ in },
            applyUpdatePreferences: { appliedValues.append(($0, $1)) }
        )

        XCTAssertTrue(secondLaunchPreferences.shouldRequestUpdatePermission)
        XCTAssertFalse(secondLaunchPreferences.automaticallyChecksForUpdates)
        XCTAssertFalse(secondLaunchPreferences.automaticallyDownloadsUpdates)
        XCTAssertEqual(appliedValues.map { [$0.checks, $0.downloads] }, [
            [false, false],
            [false, false]
        ])
    }

    func testAcceptingUpdateConsentPersistsAndAppliesBothChoices() {
        let defaults = makeDefaults()
        var appliedValues: [(checks: Bool, downloads: Bool)] = []
        let preferences = AppPreferences(
            defaults: defaults,
            applyDockVisibility: { _ in },
            applyUpdatePreferences: { appliedValues.append(($0, $1)) }
        )

        preferences.enableAutomaticUpdateChecks(downloadAutomatically: true)

        XCTAssertFalse(preferences.shouldRequestUpdatePermission)
        XCTAssertTrue(preferences.automaticallyChecksForUpdates)
        XCTAssertTrue(preferences.automaticallyDownloadsUpdates)
        XCTAssertEqual(appliedValues.map { [$0.checks, $0.downloads] }, [
            [false, false],
            [true, true]
        ])

        var restoredValues: [(checks: Bool, downloads: Bool)] = []
        let restored = AppPreferences(
            defaults: defaults,
            applyDockVisibility: { _ in },
            applyUpdatePreferences: { restoredValues.append(($0, $1)) }
        )
        XCTAssertFalse(restored.shouldRequestUpdatePermission)
        XCTAssertTrue(restored.automaticallyChecksForUpdates)
        XCTAssertTrue(restored.automaticallyDownloadsUpdates)
        XCTAssertEqual(restoredValues.map { [$0.checks, $0.downloads] }, [[true, true]])
    }

    func testDecliningUpdateConsentPersistsWithoutRepeatedPrompting() {
        let defaults = makeDefaults()
        var appliedValues: [(checks: Bool, downloads: Bool)] = []
        let preferences = AppPreferences(
            defaults: defaults,
            applyDockVisibility: { _ in },
            applyUpdatePreferences: { appliedValues.append(($0, $1)) }
        )

        preferences.declineAutomaticUpdateChecks()

        XCTAssertFalse(preferences.shouldRequestUpdatePermission)
        XCTAssertFalse(preferences.automaticallyChecksForUpdates)
        XCTAssertFalse(preferences.automaticallyDownloadsUpdates)
        XCTAssertEqual(appliedValues.map { [$0.checks, $0.downloads] }, [
            [false, false],
            [false, false]
        ])
    }

    func testDisablingAutomaticChecksAlsoDisablesAutomaticDownloads() {
        let defaults = makeDefaults()
        var appliedValues: [(checks: Bool, downloads: Bool)] = []
        let preferences = AppPreferences(
            defaults: defaults,
            applyDockVisibility: { _ in },
            applyUpdatePreferences: { appliedValues.append(($0, $1)) }
        )
        preferences.enableAutomaticUpdateChecks(downloadAutomatically: true)

        preferences.setAutomaticallyChecksForUpdates(false)

        XCTAssertFalse(preferences.automaticallyChecksForUpdates)
        XCTAssertFalse(preferences.automaticallyDownloadsUpdates)
        XCTAssertEqual(appliedValues.last?.checks, false)
        XCTAssertEqual(appliedValues.last?.downloads, false)
    }

    func testSuccessfulCountdownLockShowsLockedFeedback() {
        XCTAssertEqual(
            InputFeedbackPolicy.feedback(from: .arming(secondsRemaining: 1), to: .locked),
            .locked
        )
    }

    func testSuccessfulHotKeyLockShowsLockedFeedback() {
        XCTAssertEqual(
            InputFeedbackPolicy.feedback(from: .idle, to: .locked),
            .locked
        )
    }

    func testUnlockShowsRestoredFeedback() {
        XCTAssertEqual(
            InputFeedbackPolicy.feedback(from: .locked, to: .restored),
            .restored
        )
    }

    func testUnsuccessfulOrIntermediateStatesDoNotShowFeedback() {
        XCTAssertNil(InputFeedbackPolicy.feedback(from: .idle, to: .arming(secondsRemaining: 5)))
        XCTAssertNil(InputFeedbackPolicy.feedback(from: .arming(secondsRemaining: 1), to: .error("Failed")))
        XCTAssertNil(InputFeedbackPolicy.feedback(from: .restored, to: .idle))
    }

    func testLockedFeedbackUsesRedClosedLockPresentation() {
        XCTAssertEqual(InputFeedback.locked.title, "Input locked")
        XCTAssertEqual(InputFeedback.locked.tint, .red)
        XCTAssertEqual(InputFeedback.locked.initialSymbol, "lock.open.fill")
        XCTAssertEqual(InputFeedback.locked.finalSymbol, "lock.fill")
    }

    func testRestoredFeedbackUsesGreenOpenLockPresentation() {
        XCTAssertEqual(InputFeedback.restored.title, "Input restored")
        XCTAssertEqual(InputFeedback.restored.tint, .green)
        XCTAssertEqual(InputFeedback.restored.initialSymbol, "lock.fill")
        XCTAssertEqual(InputFeedback.restored.finalSymbol, "lock.open.fill")
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AppPresentationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
