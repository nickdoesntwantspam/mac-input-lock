import XCTest
@testable import MacInputLock

final class UnlockSequenceTests: XCTestCase {
    func testRejectsEmptySequence() {
        XCTAssertThrowsError(try UnlockSequence(""))
    }

    func testAcceptsSingleCharacterSequence() throws {
        let sequence = try UnlockSequence("x")
        var matcher = SequenceMatcher(sequence: sequence)

        XCTAssertTrue(matcher.consume("x"))
    }

    func testRejectsControlCharacters() {
        XCTAssertThrowsError(try UnlockSequence("abc\n"))
    }

    func testMatcherUnlocksOnExactSequence() throws {
        var matcher = SequenceMatcher(sequence: try UnlockSequence("unlock"))

        XCTAssertFalse(matcher.consume("unloc"))
        XCTAssertTrue(matcher.consume("k"))
    }

    func testMatcherIgnoresUnrelatedInput() throws {
        var matcher = SequenceMatcher(sequence: try UnlockSequence("unlock"))

        XCTAssertFalse(matcher.consume("noiseun"))
        XCTAssertFalse(matcher.consume("xxunloc"))
        XCTAssertTrue(matcher.consume("k"))
    }

    func testMatcherHandlesOverlappingPrefix() throws {
        var matcher = SequenceMatcher(sequence: try UnlockSequence("aabc"))

        XCTAssertTrue(matcher.consume("aaabc"))
    }

    func testMatcherIsCaseSensitive() throws {
        var matcher = SequenceMatcher(sequence: try UnlockSequence("Open"))

        XCTAssertFalse(matcher.consume("open"))
        XCTAssertTrue(matcher.consume("Open"))
    }

    func testMatcherSupportsUnicodeCharacters() throws {
        var matcher = SequenceMatcher(sequence: try UnlockSequence("🔓é"))

        XCTAssertFalse(matcher.consume("🔓"))
        XCTAssertTrue(matcher.consume("é"))
    }

    func testIncorrectSequenceDoesNotUnlock() throws {
        let sequence = try UnlockSequence("open")
        var firstMatcher = SequenceMatcher(sequence: sequence)
        var secondMatcher = SequenceMatcher(sequence: sequence)

        XCTAssertFalse(firstMatcher.consume("opne"))
        XCTAssertFalse(secondMatcher.consume("nope"))
    }

    func testInstantLockShortcutRequiresExactKeyAndModifiers() {
        let required: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]

        XCTAssertTrue(InstantLockShortcut.matches(keyCode: InstantLockShortcut.keyCode, flags: required))
        XCTAssertFalse(InstantLockShortcut.matches(keyCode: 0, flags: required))
        XCTAssertFalse(InstantLockShortcut.matches(keyCode: InstantLockShortcut.keyCode, flags: [.maskCommand]))
        XCTAssertFalse(InstantLockShortcut.matches(keyCode: InstantLockShortcut.keyCode, flags: required.union(.maskShift)))
    }

    func testInstantLockShortcutIgnoresUnrelatedEventFlags() {
        let flags: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand, .maskAlphaShift]

        XCTAssertTrue(InstantLockShortcut.matches(keyCode: InstantLockShortcut.keyCode, flags: flags))
    }
}
