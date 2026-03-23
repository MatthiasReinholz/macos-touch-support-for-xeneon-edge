# Development

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
4. runs `make clean zip`
5. uploads `build/XeneonTouchSupport-macOS.zip`
6. publishes a GitHub release and attaches the zip

This gives you an end-to-end remote build path for release generation without requiring a local macOS packaging step each time.

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
- recent in-memory logs with a 5-minute retention window

## Runtime overrides

The packaged app is meant for normal use without Terminal. When debugging from a shell, the runtime also accepts environment overrides such as:

```bash
XENEON_DISPLAY_ID=2 make run
XENEON_CLICK_COUNT=2 make run
XENEON_ACTIVATION_DELAY_MS=60 make run
```
