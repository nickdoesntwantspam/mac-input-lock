import AppKit
import SwiftUI

@MainActor
final class UnlockHUDController {
    static let shared = UnlockHUDController()

    private var panel: NSPanel?
    private var dismissalTask: Task<Void, Never>?

    func show() {
        dismissalTask?.cancel()
        panel?.close()

        let size = NSSize(width: 240, height: 200)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView: UnlockHUDView())

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(
                x: frame.midX - size.width / 2,
                y: frame.midY - size.height / 2
            ))
        } else {
            panel.center()
        }

        panel.alphaValue = 1
        panel.orderFrontRegardless()
        self.panel = panel

        dismissalTask = Task { [weak self, weak panel] in
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled, let panel else { return }

            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0.45
            NSAnimationContext.current.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 0
            NSAnimationContext.endGrouping()

            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            panel.close()
            if self?.panel === panel {
                self?.panel = nil
            }
        }
    }
}

private struct UnlockHUDView: View {
    @State private var isUnlocked = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.green.opacity(0.16))
                    .frame(width: 104, height: 104)

                Image(systemName: "lock.fill")
                    .opacity(isUnlocked ? 0 : 1)
                    .scaleEffect(isUnlocked ? 0.72 : 1)

                Image(systemName: "lock.open.fill")
                    .opacity(isUnlocked ? 1 : 0)
                    .scaleEffect(isUnlocked ? 1 : 0.72)
                    .rotationEffect(.degrees(isUnlocked ? 0 : -10))
            }
            .font(.system(size: 54, weight: .semibold))
            .foregroundStyle(.green)

            Text("Input restored")
                .font(.headline)
                .opacity(isUnlocked ? 1 : 0)
                .offset(y: isUnlocked ? 0 : 5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.16))
        }
        .padding(2)
        .task {
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.spring(response: 0.48, dampingFraction: 0.68)) {
                isUnlocked = true
            }
        }
    }
}
