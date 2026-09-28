import XCTest
@testable import MacInputLock

@MainActor
final class UpdateSafetyTests: XCTestCase {
    func testOnlyInactiveStatesAllowUpdateWork() {
        XCTAssertTrue(UpdateSafetyPolicy.allowsUpdateWork(while: .idle))
        XCTAssertTrue(UpdateSafetyPolicy.allowsUpdateWork(while: .error("Not locked")))

        XCTAssertFalse(UpdateSafetyPolicy.allowsUpdateWork(while: .arming(secondsRemaining: 5)))
        XCTAssertFalse(UpdateSafetyPolicy.allowsUpdateWork(while: .locked))
        XCTAssertFalse(UpdateSafetyPolicy.allowsUpdateWork(while: .restored))
    }

    func testBlockedCheckRetriesOnceAfterReturningToIdle() {
        let coordinator = UpdateDeferralCoordinator()
        var retryCount = 0

        coordinator.recordBlockedCheck()
        coordinator.stateDidChange(to: .locked) { retryCount += 1 }
        coordinator.stateDidChange(to: .restored) { retryCount += 1 }
        XCTAssertEqual(retryCount, 0)

        coordinator.stateDidChange(to: .idle) { retryCount += 1 }
        coordinator.stateDidChange(to: .idle) { retryCount += 1 }
        XCTAssertEqual(retryCount, 1)
    }

    func testRelaunchIsPostponedUntilRestoredFeedbackFinishes() {
        let coordinator = UpdateDeferralCoordinator()
        var installCount = 0

        XCTAssertTrue(
            coordinator.postponeInstallation(while: .locked) {
                installCount += 1
            }
        )

        coordinator.stateDidChange(to: .restored) {
            XCTFail("No update check should be retried")
        }
        XCTAssertEqual(installCount, 0)

        coordinator.stateDidChange(to: .idle) {
            XCTFail("No update check should be retried")
        }
        XCTAssertEqual(installCount, 1)
    }

    func testIdleInstallationIsNotPostponed() {
        let coordinator = UpdateDeferralCoordinator()
        var installCount = 0

        XCTAssertFalse(
            coordinator.postponeInstallation(while: .idle) {
                installCount += 1
            }
        )
        XCTAssertEqual(installCount, 0)
    }

    func testPendingInstallationTakesPriorityOverRetryingACheck() {
        let coordinator = UpdateDeferralCoordinator()
        var events: [String] = []

        coordinator.recordBlockedCheck()
        XCTAssertTrue(
            coordinator.postponeInstallation(while: .arming(secondsRemaining: 2)) {
                events.append("install")
            }
        )

        coordinator.stateDidChange(to: .idle) {
            events.append("check")
        }

        XCTAssertEqual(events, ["install"])
    }
}
