import SwiftUI

@main
struct MacInputLockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = StatusBarController()
        statusBarController = controller
        Task { @MainActor in
            // The status button receives its window on the next AppKit layout pass.
            try? await Task.sleep(for: .milliseconds(150))
            controller.showLaunchGuidance()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusBarController?.showLaunchGuidance()
        return true
    }
}

@MainActor
private final class StatusBarController: NSObject {
    private let model = AppModel()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var fallbackWindow: NSWindow?

    override init() {
        super.init()

        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: LockMenu(model: model) { [weak popover] in
                popover?.performClose(nil)
            }
        )

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp])
        }
        observeState()
    }

    func showLaunchGuidance() {
        guard let frame = statusItemScreenFrame,
              let screen = NSScreen.screens.first(where: { $0.frame.intersects(frame) }) ?? NSScreen.main else {
            showFallbackWindow()
            return
        }
        if StatusItemVisibility.isVisible(frame: frame, on: screen) {
            LaunchHUDController.shared.show(pointingAt: frame)
        } else {
            showFallbackWindow()
        }
    }

    @objc private func togglePopover() {
        LaunchHUDController.shared.dismiss()
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private var statusItemScreenFrame: NSRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func showFallbackWindow() {
        LaunchHUDController.shared.dismiss()
        if let fallbackWindow {
            NSApp.activate(ignoringOtherApps: true)
            fallbackWindow.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 590),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Mac Input Lock"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: HiddenStatusItemView(model: model) { [weak window] in
                window?.close()
            }
        )
        window.center()
        fallbackWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func observeState() {
        withObservationTracking {
            updateStatusItem(for: model.state)
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeState()
            }
        }
    }

    private func updateStatusItem(for state: AppModel.State) {
        guard let button = statusItem.button else { return }
        let symbol: String
        let label: String
        switch state {
        case .idle, .error:
            symbol = "lock.open"
            label = "Mac Input Lock"
        case .arming:
            symbol = "timer"
            label = "Mac Input Lock: locking soon"
        case .locked:
            symbol = "lock.fill"
            label = "Mac Input Lock: input locked"
        case .restored:
            symbol = "checkmark.circle.fill"
            label = "Mac Input Lock: input restored"
        }
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        button.toolTip = label
    }
}

private struct HiddenStatusItemView: View {
    @Bindable var model: AppModel
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Label("The padlock is hidden", systemImage: "menubar.rectangle")
                    .font(.headline)
                Text("Your menu bar is too full for macOS to display it. You can use Mac Input Lock here. Remove or rearrange other menu-bar items to make the padlock visible.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding([.top, .horizontal], 16)

            LockMenu(model: model, dismiss: dismiss)
        }
        .frame(width: 380)
    }
}

private struct LockMenu: View {
    @Bindable var model: AppModel
    let dismiss: () -> Void
    @FocusState private var sequenceFocused: Bool
    @State private var lockedPresentationOpacity = 1.0
    @State private var lockedWindowTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.14))
                    Image(systemName: statusIcon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(statusColor)
                }
                .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(.headline)
                    Text(statusDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            switch model.state {
            case let .arming(seconds):
                VStack(spacing: 12) {
                    Text("\(seconds)")
                        .font(.system(size: 42, weight: .semibold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("Keep the unlock sequence in mind:\n“\(model.sequenceText)”")
                        .multilineTextAlignment(.center)
                        .font(.callout)
                    Button("Cancel") { model.cancelArming() }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)

            case .locked:
                Text("Type “\(model.sequenceText)” or press \(InstantLockShortcut.symbol) to unlock. Every other keyboard, mouse, and trackpad action is blocked until then.")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)

            case .idle, .restored, .error:
                VStack(alignment: .leading, spacing: 6) {
                    Text("Unlock sequence")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("unlock", text: $model.sequenceText)
                        .textFieldStyle(.roundedBorder)
                        .focused($sequenceFocused)
                        .onSubmit { model.saveSequence() }
                    Text("Case-sensitive · \(model.sequenceText.count) characters")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Button("Start", systemImage: "lock.fill") {
                    sequenceFocused = false
                    model.start()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.validationMessage != nil)
                .tint(model.validationMessage == nil ? .accentColor : .gray)
                .opacity(model.validationMessage == nil ? 1 : 0.48)
                .frame(maxWidth: .infinity, alignment: .trailing)

                Text("\(InstantLockShortcut.symbol) locks instantly · Press it again to unlock")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let reason = model.validationMessage {
                    Label(reason, systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if case let .error(message) = model.state {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Open Accessibility Settings") {
                            openAccessibilitySettings()
                        }
                        .font(.caption)
                    }
                }
            }

            if showsQuitButton {
                Divider()
                Button("Quit") {
                    model.stop()
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 340)
        .opacity(lockedPresentationOpacity)
        .onChange(of: model.state) { _, newState in
            if newState == .locked {
                beginLockedWindowDismissal()
            } else {
                lockedWindowTask?.cancel()
                lockedPresentationOpacity = 1
            }
        }
    }

    private var statusTitle: String {
        switch model.state {
        case .idle: "Mac Input Lock"
        case .arming: "Get ready"
        case .locked: "Input is locked"
        case .restored: "Input restored"
        case .error: "Action needed"
        }
    }

    private var statusDetail: String {
        switch model.state {
        case .idle:
            "Blocks keyboard, mouse, and trackpad input"
        case .arming:
            "Input will lock after the countdown"
        case .locked:
            "Your call, audio, and video keep running"
        case .restored:
            "Keyboard, mouse, and trackpad are active"
        case .error:
            "Could not start"
        }
    }

    private var statusIcon: String {
        switch model.state {
        case .idle: "lock.open"
        case .arming: "timer"
        case .locked: "lock.fill"
        case .restored: "checkmark"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch model.state {
        case .idle: .secondary
        case .arming: .orange
        case .locked: .green
        case .restored: .green
        case .error: .red
        }
    }

    private var showsQuitButton: Bool {
        switch model.state {
        case .arming, .locked:
            false
        case .idle, .restored, .error:
            true
        }
    }

    private func beginLockedWindowDismissal() {
        lockedWindowTask?.cancel()
        lockedPresentationOpacity = 1
        lockedWindowTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, model.state == .locked else { return }

            withAnimation(.easeInOut(duration: 0.4)) {
                lockedPresentationOpacity = 0
            }

            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled, model.state == .locked else { return }
            dismiss()
            lockedPresentationOpacity = 1
        }
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
