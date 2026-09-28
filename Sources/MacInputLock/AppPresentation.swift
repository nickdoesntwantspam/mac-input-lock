import Foundation

enum LockMenuSection: CaseIterable, Equatable {
    case inputLock
    case access
    case updates

    var title: String {
        switch self {
        case .inputLock: "INPUT LOCK"
        case .access: "ACCESS"
        case .updates: "UPDATES"
        }
    }
}

enum WindowPlacement {
    static func centeredOrigin(windowSize: CGSize, in visibleFrame: CGRect) -> CGPoint {
        CGPoint(
            x: visibleFrame.midX - windowSize.width / 2,
            y: visibleFrame.midY - windowSize.height / 2
        )
    }
}

enum ControlWindowReason: Equatable {
    case reopened
    case hiddenStatusItem

    var title: String {
        switch self {
        case .reopened:
            "Mac Input Lock"
        case .hiddenStatusItem:
            "The padlock is hidden"
        }
    }

    var message: String {
        switch self {
        case .reopened:
            "Use these controls whenever the menu-bar padlock is unavailable."
        case .hiddenStatusItem:
            "Your menu bar is too full for macOS to display the padlock. You can use Mac Input Lock here. Remove or rearrange other menu-bar items to make the padlock visible."
        }
    }

    var systemImage: String {
        switch self {
        case .reopened:
            "lock.open"
        case .hiddenStatusItem:
            "menubar.rectangle"
        }
    }
}

enum AppPresentationAction: Equatable {
    case showLaunchGuidance
    case showControlWindow(ControlWindowReason)
}

enum AppPresentationPolicy {
    static func launchAction(statusItemIsSafelyVisible: Bool) -> AppPresentationAction {
        statusItemIsSafelyVisible
            ? .showLaunchGuidance
            : .showControlWindow(.hiddenStatusItem)
    }

    static var reopenAction: AppPresentationAction {
        .showControlWindow(.reopened)
    }

    static func visibilityChangeAction(wasVisible: Bool?, isVisible: Bool) -> AppPresentationAction? {
        guard wasVisible == true, !isVisible else { return nil }
        return .showControlWindow(.hiddenStatusItem)
    }
}
