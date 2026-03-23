# XENEON Touch Support for macOS

`XENEON Touch Support` is a small macOS menu bar utility that improves the CORSAIR XENEON EDGE touchscreen experience on Mac.

When the touchscreen is touched while the pointer is on another display, the app moves the pointer onto the XENEON and posts the synthetic click path needed for the touchscreen to act on that display. If the pointer is already on the XENEON, the app leaves the touch alone and lets native macOS behavior handle it.

## What normal users should do

1. Download `XeneonTouchSupport-macOS.zip` from a GitHub release.
2. Unzip it.
3. Drag `XeneonTouchSupport.app` to `/Applications`.
4. Launch the app.
5. Grant:
   - `Accessibility`
   - `Input Monitoring`
6. Relaunch the app.

After launch, the app runs in the menu bar as `XE`.

Full install steps are in [INSTALL.md](docs/INSTALL.md).

The menu bar app now shows:

- live runtime status
- whether the XENEON display is currently recognized
- whether Accessibility and Input Monitoring are granted
- whether a matching touch device is connected
- a `Copy Diagnostics` action with recent in-memory logs from the last 5 minutes
- an `Info` window with project details and the GitHub link

## What the app currently does

- detects the XENEON EDGE display at startup
- identifies likely touchscreen HID devices
- tracks touch X/Y coordinates from the HID stream
- when the pointer is off the XENEON, arms a takeover session and clicks at the mapped XENEON point on touch release
- briefly suppresses native mouse events during takeover
- leaves touches alone when the pointer is already on the XENEON

## Current limitations

This is still a user-space workaround, not a custom driver.

That means:

- some apps behave better than others
- the visible cursor can still drift to the top edge of the XENEON during takeover
- the native touchscreen path is not fully replaced at the OS level

If behavior is strange in a specific app, see [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

If permissions seem stuck even after you have granted them, fully remove the app’s entries from both `Accessibility` and `Input Monitoring`, then add the app again and relaunch it.

## GitHub releases

The repo includes a GitHub Actions release workflow at [.github/workflows/release.yml](.github/workflows/release.yml).

You can publish a release in either of these ways:

- push a tag like `v0.1.0`
- open GitHub Actions and manually run `Release macOS App`, then choose a `patch`, `minor`, or `major` bump

The workflow will:

- build the macOS app bundle on GitHub-hosted macOS runners
- calculate the next `vX.Y.Z` tag automatically for manual runs
- package `XeneonTouchSupport.app` into `XeneonTouchSupport-macOS.zip`
- upload the zip as a workflow artifact
- create or update the GitHub release and attach the zip

## Build from source

If you want to build from source, see [DEVELOPMENT.md](docs/DEVELOPMENT.md).

## Repo layout

- [src/main.m](src/main.m): runtime and menu bar app wrapper
- [Makefile](Makefile): build, app, and zip targets
- [packaging/Info.plist](packaging/Info.plist): app bundle metadata
- [docs/INSTALL.md](docs/INSTALL.md): end-user install guide
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md): troubleshooting guide
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md): development notes
