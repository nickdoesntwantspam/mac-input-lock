import Foundation

struct UnlockSequence: Equatable, Sendable {
    static let defaultValue = "unlock"
    static let minimumLength = 1

    let value: String

    init(_ value: String) throws {
        guard value.count >= Self.minimumLength else {
            throw ValidationError.tooShort
        }
        guard !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw ValidationError.containsControlCharacter
        }
        self.value = value
    }

    enum ValidationError: LocalizedError, Equatable {
        case tooShort
        case containsControlCharacter

        var errorDescription: String? {
            switch self {
            case .tooShort:
                "An unlock sequence is required."
            case .containsControlCharacter:
                "Use visible characters only."
            }
        }
    }
}

struct SequenceMatcher: Sendable {
    private let target: [Character]
    private var recent: [Character] = []

    init(sequence: UnlockSequence) {
        target = Array(sequence.value)
    }

    mutating func consume(_ text: String) -> Bool {
        for character in text {
            recent.append(character)
            if recent.count > target.count {
                recent.removeFirst(recent.count - target.count)
            }
            if recent == target {
                recent.removeAll(keepingCapacity: true)
                return true
            }
        }
        return false
    }

    mutating func reset() {
        recent.removeAll(keepingCapacity: true)
    }
}
