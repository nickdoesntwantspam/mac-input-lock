import AppKit

@MainActor
final class GlobalHotKey {
    var onPress: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?

    init() {
        start()
    }

    func start() {
        guard globalMonitor == nil, localMonitor == nil else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard InstantLockShortcut.matches(event: event) else { return }
            Task { @MainActor in
                self?.onPress?()
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard InstantLockShortcut.matches(event: event) else { return event }
            MainActor.assumeIsolated {
                self?.onPress?()
            }
            return nil
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

}
