enum InputFeedback: Equatable {
    enum Tint: Equatable {
        case red
        case green
    }

    case locked
    case restored

    var title: String {
        switch self {
        case .locked: "Input locked"
        case .restored: "Input restored"
        }
    }

    var tint: Tint {
        switch self {
        case .locked: .red
        case .restored: .green
        }
    }

    var initialSymbol: String {
        switch self {
        case .locked: "lock.open.fill"
        case .restored: "lock.fill"
        }
    }

    var finalSymbol: String {
        switch self {
        case .locked: "lock.fill"
        case .restored: "lock.open.fill"
        }
    }
}

enum InputFeedbackPolicy {
    static func feedback(from oldState: AppModel.State, to newState: AppModel.State) -> InputFeedback? {
        switch (oldState, newState) {
        case (_, .locked) where oldState != .locked:
            .locked
        case (.locked, .restored):
            .restored
        default:
            nil
        }
    }
}
