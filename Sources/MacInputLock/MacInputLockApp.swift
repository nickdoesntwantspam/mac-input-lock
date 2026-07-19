import SwiftUI

@main
struct MacInputLockApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            LockMenu(model: model)
        } label: {
            MenuBarLabel(state: model.state)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarLabel: View {
    let state: AppModel.State

    var body: some View {
        switch state {
        case .locked:
            Label("Input Locked", systemImage: "lock.fill")
        case let .arming(seconds):
            Label("Locking in \(seconds)…", systemImage: "timer")
        case .restored:
            Label("Input Restored", systemImage: "checkmark.circle.fill")
        case .idle, .error:
            Image(systemName: "lock.open")
                .accessibilityLabel("Mac Input Lock")
        }
    }
}

private struct LockMenu: View {
    @Bindable var model: AppModel
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
            NSApplication.shared.keyWindow?.orderOut(nil)
            lockedPresentationOpacity = 1
        }
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
