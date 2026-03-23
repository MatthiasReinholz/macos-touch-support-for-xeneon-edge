# Development

This document is for development, packaging, and release maintenance. Normal app installation and usage are documented in [INSTALL.md](INSTALL.md) and [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Build targets

Run these from the repository root.

- `make build`: build the raw executable
- `make run`: run the raw executable from Terminal
- `make app`: build the macOS app bundle
- `make zip`: build the app bundle and package it as a release zip

## GitHub Actions release pipeline

The repository includes a release workflow in [.github/workflows/release.yml](../.github/workflows/release.yml).

Supported release paths:

- push a tag like `v0.1.0`
- manually trigger `Release macOS App` from the GitHub Actions UI

For manual runs, the workflow accepts:

- `release_type`: required semantic bump choice: `patch`, `minor`, or `major`
- `release_name`: optional release title
- `prerelease`: whether the GitHub release should be marked as a prerelease

The workflow:

1. checks out the repository on a macOS runner
2. calculates the next `vX.Y.Z` tag from the latest existing release tag for manual runs
3. creates that tag if it does not already exist
4. signs the app with `Developer ID Application` if Apple signing secrets are configured
5. notarizes and staples the app if Apple notarization secrets are configured
6. falls back to ad-hoc signing if those secrets are not configured
7. packages `build/XeneonTouchSupport-macOS.zip`
8. uploads the zip
9. publishes a GitHub release and attaches the zip

This gives you an end-to-end remote build path for release generation without requiring a local macOS packaging step each time.

### Optional Apple signing and notarization

The workflow is prepared for two modes:

- no Apple credentials configured: builds an ad-hoc signed app, like the current local developer flow
- Apple signing credentials configured: builds a `Developer ID Application` signed app
- Apple signing and notarization credentials configured: builds a signed, notarized, and stapled app

Configure these GitHub secrets when you are ready:

- `APPLE_SIGNING_CERTIFICATE_P12_BASE64`: base64-encoded `.p12` certificate export
- `APPLE_SIGNING_CERTIFICATE_PASSWORD`: password for that `.p12`
- `APPLE_SIGNING_IDENTITY`: full signing identity, for example `Developer ID Application: Your Name (TEAMID)`
- `APPLE_ID`: Apple ID email used for notarization
- `APPLE_APP_SPECIFIC_PASSWORD`: app-specific password for notarization
- `APPLE_TEAM_ID`: Apple Developer Team ID

Recommended setup:

1. export your `Developer ID Application` certificate as a `.p12`
2. base64-encode it
3. store the values above as GitHub repository secrets
4. rerun the release workflow

If only the signing secrets are present, the workflow signs but does not notarize.
If both signing and notarization secrets are present, the workflow signs, notarizes, staples, and then packages the final zip.

## Output paths

- executable: `build/xeneon-touch-support`
- app bundle: `build/XeneonTouchSupport.app`
- release zip: `build/XeneonTouchSupport-macOS.zip`

## Architecture summary

The repo currently ships one Objective-C implementation in [main.m](../src/main.m):

- enumerate screens and identify the XENEON display
- identify candidate touchscreen HID devices
- monitor HID input values
- if the pointer is off the XENEON, arm a takeover session
- move the cursor toward the touched XENEON point
- suppress native mouse events during takeover
- post synthetic mouse clicks on touch release

The packaged app is a thin menu bar wrapper around the same runtime.

The menu bar shell also exposes:

- current runtime status
- recognized display status
- permission status
- matched touch-device count
- a `Copy Diagnostics` action backed by in-memory logs with a 5-minute retention window

## Runtime overrides

The packaged app is meant for normal use without Terminal. When debugging from a shell, the runtime also accepts environment overrides such as:

```bash
XENEON_DISPLAY_ID=2 make run
XENEON_CLICK_COUNT=2 make run
XENEON_ACTIVATION_DELAY_MS=60 make run
```
