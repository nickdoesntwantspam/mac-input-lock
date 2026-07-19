import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    enum State: Equatable {
        case idle
        case arming(secondsRemaining: Int)
        case locked
        case restored
        case error(String)
    }

    private enum DefaultsKey {
        static let unlockSequence = "unlockSequence"
    }

    private let blocker: InputBlocker
    private let defaults: UserDefaults
    private let hotKey: GlobalHotKey
    private var transitionTask: Task<Void, Never>?

    var state: State = .idle
    var sequenceText: String

    init(
        blocker: InputBlocker = InputBlocker(),
        defaults: UserDefaults = .standard,
        hotKey: GlobalHotKey = GlobalHotKey()
    ) {
        self.blocker = blocker
        self.defaults = defaults
        self.hotKey = hotKey
        sequenceText = defaults.string(forKey: DefaultsKey.unlockSequence) ?? UnlockSequence.defaultValue
        hotKey.onPress = { [weak self] in
            self?.toggleInstantLock()
        }
    }

    var validationMessage: String? {
        do {
            _ = try UnlockSequence(sequenceText)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func saveSequence() {
        guard validationMessage == nil else { return }
        defaults.set(sequenceText, forKey: DefaultsKey.unlockSequence)
    }

    func start() {
        transitionTask?.cancel()
        do {
            let sequence = try preparedSequence()
            state = .arming(secondsRemaining: 5)
            transitionTask = Task { [weak self] in
                for remaining in stride(from: 4, through: 1, by: -1) {
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { return }
                    self?.state = .arming(secondsRemaining: remaining)
                }
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.activate(sequence: sequence)
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func cancelArming() {
        transitionTask?.cancel()
        transitionTask = nil
        state = .idle
    }

    func stop() {
        transitionTask?.cancel()
        transitionTask = nil
        blocker.stop()
        state = .idle
    }

    func toggleInstantLock() {
        switch state {
        case .locked:
            unlock()
        case .idle, .arming, .restored, .error:
            transitionTask?.cancel()
            transitionTask = nil
            do {
                activate(sequence: try preparedSequence())
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    private func preparedSequence() throws -> UnlockSequence {
        let sequence = try UnlockSequence(sequenceText)
        guard AccessibilityPermission.isGranted else {
            AccessibilityPermission.request()
            throw ShortcutError.accessibilityRequired
        }
        saveSequence()
        return sequence
    }

    private func activate(sequence: UnlockSequence) {
        do {
            try blocker.start(sequence: sequence) { [weak self] in
                Task { @MainActor in self?.unlock() }
            }
            hotKey.stop()
            state = .locked
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func unlock() {
        blocker.stop()
        hotKey.start()
        state = .restored
        UnlockHUDController.shared.show()
        transitionTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.state = .idle
        }
    }

    private enum ShortcutError: LocalizedError {
        case accessibilityRequired

        var errorDescription: String? {
            "Accessibility access is required. Enable Mac Input Lock in System Settings → Privacy & Security → Accessibility, then try again."
        }
    }
}
