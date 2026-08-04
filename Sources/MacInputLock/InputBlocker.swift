import CoreGraphics
import Foundation

final class InputBlocker: @unchecked Sendable {
    enum BlockerError: LocalizedError {
        case eventTapUnavailable

        var errorDescription: String? {
            "Input blocking could not start. Grant Accessibility access in System Settings, then try again."
        }
    }

    private let lock = NSLock()
    private let eventQueue = DispatchQueue(label: "com.nicholaswilliams.MacInputLock.event-tap")
    private var matcher: SequenceMatcher?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var eventRunLoop: CFRunLoop?
    private var onUnlock: (@Sendable () -> Void)?

    var isRunning: Bool {
        lock.withLock { eventTap != nil }
    }

    func start(sequence: UnlockSequence, onUnlock: @escaping @Sendable () -> Void) throws {
        stop()

        lock.withLock {
            matcher = SequenceMatcher(sequence: sequence)
            self.onUnlock = onUnlock
        }

        let ready = DispatchSemaphore(value: 0)
        eventQueue.async { [weak self] in
            guard let self else {
                ready.signal()
                return
            }
            self.installEventTap(ready: ready)
        }
        ready.wait()

        guard isRunning else {
            lock.withLock {
                matcher = nil
                self.onUnlock = nil
            }
            throw BlockerError.eventTapUnavailable
        }
    }

    func stop() {
        let resources = lock.withLock { () -> (CFMachPort?, CFRunLoopSource?, CFRunLoop?) in
            let result = (eventTap, runLoopSource, eventRunLoop)
            eventTap = nil
            runLoopSource = nil
            eventRunLoop = nil
            matcher = nil
            onUnlock = nil
            return result
        }

        if let tap = resources.0 {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = resources.1, let runLoop = resources.2 {
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
            CFRunLoopStop(runLoop)
        }
    }

    private func installEventTap(ready: DispatchSemaphore) {
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask.max,
            callback: inputBlockerCallback,
            userInfo: context
        ) else {
            ready.signal()
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        let runLoop = CFRunLoopGetCurrent()
        lock.withLock {
            eventTap = tap
            runLoopSource = source
            eventRunLoop = runLoop
        }
        CFRunLoopAddSource(runLoop, source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        ready.signal()
        CFRunLoopRun()
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = lock.withLock({ eventTap }) {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown {
            if InstantLockShortcut.matches(
                keyCode: CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode)),
                flags: event.flags
            ) {
                let callback = lock.withLock { onUnlock }
                if let callback {
                    DispatchQueue.main.async(execute: callback)
                }
                return nil
            }

            var length = 0
            var buffer = [UniChar](repeating: 0, count: 16)
            event.keyboardGetUnicodeString(maxStringLength: buffer.count, actualStringLength: &length, unicodeString: &buffer)
            let text = String(utf16CodeUnits: buffer, count: length)
            let callback = lock.withLock { () -> (@Sendable () -> Void)? in
                guard var currentMatcher = matcher else { return nil }
                let unlocked = currentMatcher.consume(text)
                matcher = currentMatcher
                return unlocked ? onUnlock : nil
            }
            if let callback {
                DispatchQueue.main.async(execute: callback)
            }
        }

        return nil
    }

    deinit {
        stop()
    }
}

private let inputBlockerCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let blocker = Unmanaged<InputBlocker>.fromOpaque(userInfo).takeUnretainedValue()
    return blocker.handle(type: type, event: event)
}
