# Contributing

Mac Input Lock deliberately does one thing. Changes should preserve the small native codebase, offline operation, and single Accessibility permission.

## Development

```sh
swift test
SIGNING_IDENTITY=- ./Scripts/build-app.sh
```

Test input suppression on real hardware before submitting behavioral changes. A forced reboot is the last-resort recovery path during manual testing.

## Pull requests

- Keep changes surgical and explain their user-visible effect.
- Add tests for pure logic and document hardware verification where macOS permission state prevents automation.
- Do not add analytics, accounts, telemetry, network calls, background services, Sparkle, or new permissions without an explicit project decision.
- Never commit certificates, `.p12` archives, App Store Connect keys, or passwords.

## Maintainer release setup

The release workflow requires a Developer ID Application certificate for Apple team `G5E7K59HUM` and an App Store Connect API key with notarization access.

Configure these GitHub Actions secrets:

| Secret | Value |
| --- | --- |
| `DEVELOPER_ID_P12_BASE64` | Base64-encoded exported Developer ID certificate and private key |
| `DEVELOPER_ID_P12_PASSWORD` | Password used when exporting the `.p12` |
| `APPLE_API_KEY_P8` | Complete App Store Connect `.p8` private-key contents |
| `APPLE_API_KEY_ID` | App Store Connect API key ID |
| `APPLE_API_ISSUER_ID` | App Store Connect issuer ID |
| `APPLE_TEAM_ID` | `G5E7K59HUM` |

To release:

1. Confirm CI passes on `main`.
2. Tag the release commit, for example `git tag v1.0.0`.
3. Push the tag. GitHub Actions builds and publishes the release only after notarization and validation succeed.
4. Update the Homebrew Cask with the published DMG checksum.
