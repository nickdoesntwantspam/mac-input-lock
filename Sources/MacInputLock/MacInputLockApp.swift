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
        statusBarController?.showControlsForReopen()
        return true
    }
}

@MainActor
private final class StatusBarController: NSObject {
    private let model: AppModel
    private let preferences: AppPreferences
    private let updater: AppUpdater
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private var controlWindow: NSWindow?
    private var updateConsentWindow: NSWindow?
    private var lastKnownStatusItemVisibility: Bool?
    private var automaticRecoveryAlreadyPresented = false
    private var lastObservedState: AppModel.State?
    private var visibilityCheckTask: Task<Void, Never>?
    private var updateConsentTask: Task<Void, Never>?

    override init() {
        let model = AppModel()
        let updater = AppUpdater { [weak model] in
            model?.state ?? .idle
        }
        let preferences = AppPreferences(applyUpdatePreferences: { checksEnabled, downloadsEnabled in
            updater.applyAutomaticUpdatePreferences(
                checksEnabled: checksEnabled,
                downloadsEnabled: downloadsEnabled
            )
        })
        self.model = model
        self.updater = updater
        self.preferences = preferences
        super.init()

        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: LockMenu(model: model, preferences: preferences, updater: updater) { [weak popover] in
                popover?.performClose(nil)
            }
        )

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp])
        }
        observeDisplayChanges()
        observeState()
    }

    func showLaunchGuidance() {
        let frame = statusItemScreenFrame
        let isVisible = statusItemIsSafelyVisible(frame: frame)
        lastKnownStatusItemVisibility = isVisible

        if isVisible, preferences.shouldRequestUpdatePermission {
            scheduleUpdateConsentIfNeeded()
            return
        }

        perform(
            AppPresentationPolicy.launchAction(statusItemIsSafelyVisible: isVisible),
            statusItemFrame: frame
        )
    }

    func showControlsForReopen() {
        perform(AppPresentationPolicy.reopenAction, statusItemFrame: statusItemScreenFrame)
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

    private func statusItemIsSafelyVisible(frame: NSRect?) -> Bool {
        guard let frame,
              let screen = NSScreen.screens.first(where: { $0.frame.intersects(frame) }) ?? NSScreen.main else {
            return false
        }
        return StatusItemVisibility.isVisible(frame: frame, on: screen)
    }

    private func perform(_ action: AppPresentationAction, statusItemFrame: NSRect?) {
        switch action {
        case .showLaunchGuidance:
            guard let statusItemFrame else {
                showControlWindow(reason: .hiddenStatusItem)
                return
            }
            LaunchHUDController.shared.show(pointingAt: statusItemFrame)
        case let .showControlWindow(reason):
            if reason == .hiddenStatusItem {
                automaticRecoveryAlreadyPresented = true
            }
            showControlWindow(reason: reason)
        }
    }

    private func showControlWindow(reason: ControlWindowReason) {
        LaunchHUDController.shared.dismiss()
        popover.performClose(nil)

        if let controlWindow {
            controlWindow.contentViewController = NSHostingController(
                rootView: ControlWindowView(
                    reason: reason,
                    model: model,
                    preferences: preferences,
                    updater: updater
                ) { [weak controlWindow] in
                    controlWindow?.close()
                }
            )
            NSApp.activate(ignoringOtherApps: true)
            controlWindow.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 432, height: 680),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Mac Input Lock"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: ControlWindowView(
                reason: reason,
                model: model,
                preferences: preferences,
                updater: updater
            ) { [weak window] in window?.close() }
        )
        window.center()
        controlWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func scheduleUpdateConsentIfNeeded() {
        updateConsentTask?.cancel()
        guard preferences.shouldRequestUpdatePermission else { return }

        updateConsentTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled,
                  let self,
                  preferences.shouldRequestUpdatePermission else { return }
            showUpdateConsentWindow()
        }
    }

    private func showUpdateConsentWindow() {
        LaunchHUDController.shared.dismiss()

        let content = UpdateConsentView(preferences: preferences) { [weak self] in
            self?.updateConsentWindow?.close()
        }

        if let updateConsentWindow {
            updateConsentWindow.contentViewController = NSHostingController(rootView: content)
            sizeWindowToFitContent(updateConsentWindow)
            NSApp.activate(ignoringOtherApps: true)
            updateConsentWindow.makeKeyAndOrderFront(nil)
            centerOnStatusItemScreen(updateConsentWindow)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 260),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Mac Input Lock"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: content)
        sizeWindowToFitContent(window)
        updateConsentWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        centerOnStatusItemScreen(window)
    }

    private func sizeWindowToFitContent(_ window: NSWindow) {
        guard let view = window.contentViewController?.view else { return }
        view.layoutSubtreeIfNeeded()
        window.setContentSize(view.fittingSize)
    }

    private func centerOnStatusItemScreen(_ window: NSWindow) {
        guard let screen = statusItemScreenFrame.flatMap({ frame in
            NSScreen.screens.first(where: { $0.frame.intersects(frame) })
        }) ?? NSScreen.main else { return }

        window.setFrameOrigin(
            WindowPlacement.centeredOrigin(
                windowSize: window.frame.size,
                in: screen.visibleFrame
            )
        )
    }

    private func observeDisplayChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displayEnvironmentDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displayEnvironmentDidChange),
            name: NSWindow.didChangeScreenNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(displayEnvironmentDidChange),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(displayEnvironmentDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    @objc private func displayEnvironmentDidChange(_ notification: Notification) {
        visibilityCheckTask?.cancel()
        visibilityCheckTask = Task { @MainActor [weak self] in
            // Let AppKit finish moving and laying out the status item first.
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled, let self else { return }
            let frame = statusItemScreenFrame
            let isVisible = statusItemIsSafelyVisible(frame: frame)
            let action = AppPresentationPolicy.visibilityChangeAction(
                wasVisible: lastKnownStatusItemVisibility,
                isVisible: isVisible,
                automaticRecoveryAlreadyPresented: automaticRecoveryAlreadyPresented
            )
            lastKnownStatusItemVisibility = isVisible
            if let action {
                perform(action, statusItemFrame: frame)
            }
        }
    }

    private func observeState() {
        withObservationTracking {
            let state = model.state
            updateStatusItem(for: state)
            updater.stateDidChange(to: state)
            if let lastObservedState,
               let feedback = InputFeedbackPolicy.feedback(from: lastObservedState, to: state) {
                InputFeedbackHUDController.shared.show(feedback)
            }
            lastObservedState = state
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

private struct UpdateConsentView: View {
    @Bindable var preferences: AppPreferences
    let dismiss: () -> Void
    @State private var downloadsAutomatically = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 18) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Keep Mac Input Lock up to date?")
                        .font(.title3.weight(.semibold))

                    Text("Mac Input Lock can periodically check for new versions. You can also check manually at any time from the controls.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Toggle("Download and install updates automatically", isOn: $downloadsAutomatically)
                        .toggleStyle(.checkbox)
                        .font(.callout)

                    Text("Update checks send no analytics or usage information.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 26)
            .padding(.bottom, 18)

            HStack(spacing: 10) {
                Spacer()
                Button("Not Now") {
                    preferences.declineAutomaticUpdateChecks()
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Check Automatically") {
                    preferences.enableAutomaticUpdateChecks(
                        downloadAutomatically: downloadsAutomatically
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .frame(width: 600)
    }
}

private struct ControlWindowView: View {
    let reason: ControlWindowReason
    @Bindable var model: AppModel
    @Bindable var preferences: AppPreferences
    let updater: AppUpdater
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Label(reason.title, systemImage: reason.systemImage)
                    .font(.headline)
                Text(reason.message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding([.top, .horizontal], 16)

            LockMenu(model: model, preferences: preferences, updater: updater, dismiss: dismiss)

            Divider()

            HStack {
                Spacer()
                Button(reason.dismissButtonTitle, action: dismiss)
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 432)
    }
}

private struct LockMenu: View {
    @Bindable var model: AppModel
    @Bindable var preferences: AppPreferences
    let updater: AppUpdater
    let dismiss: () -> Void
    @FocusState private var sequenceFocused: Bool
    @State private var lockedPresentationOpacity = 1.0
    @State private var lockedWindowTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusHeader
                .padding(16)

            Divider()

            if showsConfiguration {
                inputLockSection

                Divider()

                accessSection

                Divider()

                updatesSection

                Divider()

                Button("Quit") {
                    model.stop()
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q")
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            } else {
                activeStateSection
                    .padding(16)
            }
        }
        .frame(width: 400)
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

    private var statusHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.14))
                Image(systemName: statusIcon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(statusColor)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.headline)
                Text(statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var inputLockSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(.inputLock)

            Text("Unlock sequence")
                .font(.caption.weight(.medium))

            HStack(alignment: .center, spacing: 10) {
                TextField("unlock", text: $model.sequenceText)
                    .textFieldStyle(.roundedBorder)
                    .focused($sequenceFocused)
                    .onSubmit { model.saveSequence() }

                Button("Start", systemImage: "lock.fill") {
                    sequenceFocused = false
                    model.start()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.validationMessage != nil)
                .tint(model.validationMessage == nil ? .accentColor : .gray)
                .opacity(model.validationMessage == nil ? 1 : 0.48)
            }

            Text("Case-sensitive · \(model.sequenceText.count) characters")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack(spacing: 8) {
                Text(InstantLockShortcut.symbol)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(.quaternary, lineWidth: 1)
                    }
                Text("Lock instantly · Press again to unlock")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 2)

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
        .padding(16)
    }

    private var accessSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle(.access)

            Toggle(isOn: $preferences.showInDock) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Show Mac Input Lock in the Dock")
                        .font(.callout.weight(.medium))
                    Text("Provides another way to open these controls when the menu-bar padlock is hidden.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(16)
    }

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(.updates)

            Toggle(isOn: automaticUpdateChecksBinding) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Check for updates automatically")
                        .font(.callout.weight(.medium))
                    Text("Checks periodically. No analytics or usage information is sent.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            HStack {
                Button("Check Now…") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates(while: model.state))

                Spacer()

                Text("Version \(appVersion)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private var activeStateSection: some View {
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
            EmptyView()
        }
    }

    private func sectionTitle(_ section: LockMenuSection) -> some View {
        Text(section.title)
            .font(.caption2.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(.secondary)
    }

    private var automaticUpdateChecksBinding: Binding<Bool> {
        Binding(
            get: { preferences.automaticallyChecksForUpdates },
            set: { preferences.setAutomaticallyChecksForUpdates($0) }
        )
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
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

    private var showsConfiguration: Bool {
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
