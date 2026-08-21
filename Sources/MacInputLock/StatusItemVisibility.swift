import AppKit

enum StatusItemVisibility {
    static func isVisible(frame: NSRect, on screen: NSScreen) -> Bool {
        let safeMenuBarAreas = [screen.auxiliaryTopLeftArea, screen.auxiliaryTopRightArea].compactMap { $0 }
        guard !safeMenuBarAreas.isEmpty else {
            return screen.frame.contains(frame)
        }
        return safeMenuBarAreas.contains { $0.contains(frame) }
    }

    static func isVisible(frame: NSRect, screenFrame: NSRect, safeMenuBarAreas: [NSRect]) -> Bool {
        guard !safeMenuBarAreas.isEmpty else {
            return screenFrame.contains(frame)
        }
        return safeMenuBarAreas.contains { $0.contains(frame) }
    }
}
