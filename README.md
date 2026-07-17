<p align="center">
  <img src="Resources/AppIcon/MacInputLock-1024.png" width="160" alt="Mac Input Lock icon">
</p>

# Mac Input Lock

Temporarily disable every keyboard, mouse, and trackpad connected to your Mac without interrupting video calls, playback, audio, camera, microphone, or anything already running.

Mac Input Lock is a focused, open-source menu-bar utility for toddlers, pets, keyboard cleaning, presentations, and any situation where accidental input needs to stop. It has no accounts, analytics, network access, background service, or telemetry.

## Requirements

- macOS 14 Sonoma or later
- Accessibility permission, used only to observe and suppress input events

## Install

Download the notarized DMG from [GitHub Releases](https://github.com/nickdoesntwantspam/mac-input-lock/releases), open it, and drag **Mac Input Lock** to Applications.

After the first Homebrew release, it will also be available with:

```sh
brew install --cask nickdoesntwantspam/tap/mac-input-lock
```

On first use, enable **Mac Input Lock** in **System Settings → Privacy & Security → Accessibility**, then press Start again.

## Use

1. Open the lock icon in the menu bar.
2. Choose a case-sensitive unlock sequence containing at least one visible character. This is a convenience mechanism, not a password.
3. Press **Start**. A five-second countdown gives you time to cancel or remember the sequence.
4. The app confirms that input is locked, remains visible briefly, and fades away. The menu bar says **Input Locked**.
5. Type the exact sequence to unlock. A large animated lock opens in the center of the screen and fades away.

The sequence is stored only in local macOS preferences.

## Privacy and permissions

Accessibility permission is required because ordinary macOS applications cannot consume system-wide keyboard and pointer events. Mac Input Lock processes events locally, retains only enough recent characters to recognize the configured sequence, and never records or transmits input.

The complete permission-sensitive implementation is in [`InputBlocker.swift`](Sources/MacInputLock/InputBlocker.swift). The app requests no camera, microphone, Screen Recording, file, notification, or network permission.

## Safety and limitations

- Test the unlock sequence before handing the Mac to a child.
- Built-in and external keyboards, mice, trackpads, scrolling, dragging, and media-key events are blocked through the macOS session event stream.
- Hardware controls outside that event stream, including the physical power button, remain controlled by macOS.
- The normal Force Quit window is not a practical recovery method because local input is blocked.
- If the configured sequence does not work, hold the physical power/Touch ID button until the Mac turns off, then restart it. This can discard unsaved work. Mac Input Lock does not automatically launch or relock after restart.

## Build from source

Xcode 16 or later is required.

```sh
swift test
SIGNING_IDENTITY=- ./Scripts/build-app.sh
open "dist/Mac Input Lock.app"
```

The build script uses an installed Developer ID Application, Apple Development, or Apple Distribution certificate when available and otherwise falls back to ad-hoc signing. Ad-hoc rebuilds may need to be removed and re-added in Accessibility Settings because their macOS identity changes.

Set `UNIVERSAL=1` to build both Apple Silicon and Intel slices. Release versions come from an exact `v*` Git tag; untagged builds use version `0.0.0`.

## Release process

Tagged releases are built, tested, signed with Hardened Runtime, notarized, stapled, packaged as a DMG, and published by GitHub Actions. Maintainers must configure the signing and notarization secrets documented in [CONTRIBUTING.md](CONTRIBUTING.md).

The authoritative release artifact is always the notarized DMG attached to a GitHub Release. Mac Input Lock does not include an automatic updater; Homebrew users update with `brew upgrade`, and direct-download users install a newer release manually.

## Contributing

Bug reports and focused pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md).

## License

MIT. See [LICENSE](LICENSE).
