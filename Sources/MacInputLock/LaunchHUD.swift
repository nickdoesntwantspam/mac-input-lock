import AppKit
import SwiftUI

@MainActor
final class LaunchHUDController {
    static let shared = LaunchHUDController()

    private var panel: NSPanel?
    private var dismissalTask: Task<Void, Never>?

    private init() {}

    func show(pointingAt statusItemFrame: NSRect) {
        dismissalTask?.cancel()

        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(statusItemFrame) }) ?? NSScreen.main else {
            return
        }
        let placement = placement(pointingAt: statusItemFrame, on: screen)
        let panel = makePanel(arrowX: placement.arrowX)
        self.panel = panel
        panel.setFrameOrigin(placement.origin)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            panel.animator().alphaValue = 1
        }

        dismissalTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissalTask?.cancel()
        dismissalTask = nil
        guard let panel else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self, weak panel] in
            Task { @MainActor in
                panel?.orderOut(nil)
                if self?.panel === panel {
                    self?.panel = nil
                }
            }
        })
    }

    private func makePanel(arrowX: CGFloat) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 180),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView = NSHostingView(rootView: LaunchHUDView(arrowX: arrowX, onDismiss: { [weak self] in
            self?.dismiss()
        }))
        return panel
    }

    private func placement(pointingAt statusItemFrame: NSRect, on screen: NSScreen) -> (origin: NSPoint, arrowX: CGFloat) {
        let panelSize = NSSize(width: 430, height: 180)
        let horizontalMargin: CGFloat = 12
        let desiredX = statusItemFrame.midX - panelSize.width / 2
        let minX = screen.visibleFrame.minX + horizontalMargin
        let maxX = screen.visibleFrame.maxX - panelSize.width - horizontalMargin
        let panelX = min(max(desiredX, minX), maxX)
        let panelY = statusItemFrame.minY - panelSize.height - 2
        return (NSPoint(x: panelX, y: panelY), statusItemFrame.midX - panelX)
    }
}

private struct LaunchHUDView: View {
    let arrowX: CGFloat
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.green.opacity(0.14))
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.green)
                }
                .frame(width: 62, height: 62)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Mac Input Lock is running")
                        .font(.headline)
                    Text("Click the open lock directly above to choose an unlock sequence and start.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Got it", action: onDismiss)
                        .buttonStyle(.link)
                        .font(.caption.weight(.medium))
                }
            }
            .padding(18)
            .frame(width: 430, height: 150)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.primary.opacity(0.1), lineWidth: 1)
            }
            .offset(y: 30)

            Path { path in
                path.move(to: CGPoint(x: arrowX, y: 5))
                path.addLine(to: CGPoint(x: arrowX - 9, y: 15))
                path.move(to: CGPoint(x: arrowX, y: 5))
                path.addLine(to: CGPoint(x: arrowX + 9, y: 15))
                path.move(to: CGPoint(x: arrowX, y: 5))
                path.addLine(to: CGPoint(x: arrowX, y: 34))
            }
            .stroke(.green, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
        }
        .frame(width: 430, height: 180)
    }
}
