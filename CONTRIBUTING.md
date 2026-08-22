# Contributing

Mac Input Lock deliberately does one thing. Changes should preserve the small native codebase, offline operation, and single Accessibility permission.

## Development

```sh
swift test
SIGNING_IDENTITY=- ./Scripts/build-app.sh
```

Test input suppression on real hardware before submitting behavioral changes. Unit tests are not sufficient for changes involving the event tap, hotkey, lock state, or unlock behavior. Before merging or releasing any such change, test the signed app while a different application has focus and verify all of the following together:

1. Ordinary keyboard input does not reach the focused application.
2. Mouse and trackpad clicks, scrolling, and dragging do not reach the focused application.
3. The configured unlock sequence restores keyboard and pointer input.
4. The global hotkey locks and unlocks reliably.

A forced reboot is the last-resort recovery path during manual testing.

## Pull requests

- Keep changes surgical and explain their user-visible effect.
- Add tests for pure logic and document hardware verification where macOS permission state prevents automation.
- Do not add analytics, accounts, telemetry, network calls, background services, Sparkle, or new permissions without an explicit project decision.
- Never commit certificates, `.p12` archives, App Store Connect keys, or passwords.

## Non-negotiable distribution rule

The public repository and every public GitHub Release must remain source-only. Never attach or commit a built `.app`, `.dmg`, `.pkg`, binary archive, or binary checksum. GitHub's automatically generated source archives are expected.

A user-visible feature is not released until all of the following are true:

1. The feature and its tests are merged and tagged.
2. The release workflow produces and validates the signed, notarized DMG as a short-lived private Actions artifact.
3. That exact DMG is encrypted and installed in the private website repository, the protected download version is updated, and the matching Sites decryption secret is deployed.
4. The Stripe-gated purchase and download flow is verified before public documentation describes the feature as available.
5. The corresponding GitHub Release is checked and has zero binary assets.

This rule applies to every feature release, including small fixes. The paid product is convenience: source remains freely available, while the maintained ready-to-install build is delivered only after payment.

## Maintainer release setup

The release workflow requires a Developer ID Application certificate and an App Store Connect API key with notarization access. These credentials are maintained by the project owner and are not required to build or test the app locally.

Configure these GitHub Actions secrets:

| Secret | Value |
| --- | --- |
| `DEVELOPER_ID_P12_BASE64` | Base64-encoded exported Developer ID certificate and private key |
| `DEVELOPER_ID_P12_PASSWORD` | Password used when exporting the `.p12` |
| `APPLE_API_KEY_P8` | Complete App Store Connect `.p8` private-key contents |
| `APPLE_API_KEY_ID` | App Store Connect API key ID |
| `APPLE_API_ISSUER_ID` | App Store Connect issuer ID |
| `APPLE_TEAM_ID` | Apple Developer team identifier used for signing and notarization |

To release:

1. Confirm CI passes on `main`.
2. Tag the release commit, for example `git tag v1.0.0`.
3. Push the tag. GitHub Actions builds and validates the notarized DMG, retains it as a short-lived private maintainer artifact, and publishes a source-only GitHub Release with no binary assets.
4. Download the validated artifact and publish the DMG and checksum through the private website repository.
5. Update the website's version, file size, checksum, and download copy, then verify the Stripe purchase and fulfillment flow before announcing the release.
