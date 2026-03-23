# Implementation Plan

## Goal

Build a small macOS utility that improves the XENEON EDGE touch experience by moving the pointer onto the XENEON display whenever the XENEON touch device becomes active and the pointer is currently on another display.

The current working assumption is:

- Touch interaction behaves acceptably once the pointer is already on the XENEON display.
- We do not need to rewrite all touch events for the first iteration.
- A fast pointer relocation on touch start may be enough to make the device usable.

## Product strategy

Ship this in phases instead of trying to solve the full macOS touch stack immediately.

### Phase 0: Hardware-validation prototype

Deliverable: command-line utility.

Success criteria:

- Detect the XENEON display.
- Detect the related HID device.
- Observe whether HID callbacks arrive when the display is touched.
- Move the pointer onto the XENEON display only when it is currently elsewhere.
- Produce logs that make it obvious whether the approach is viable.

This is the phase implemented in the current repo skeleton.

### Phase 1: Background utility

Deliverable: menu bar app.

Adds:

- Launch at login
- Status item with connected / disconnected state
- Simple configuration UI
- Persistent logs
- Permission guidance for Accessibility / Input Monitoring

### Phase 2: Better touch targeting

Deliverable: improved pointer placement.

Adds:

- Parse raw touch coordinates if the HID device exposes them
- Warp to the touched point instead of the display center
- Support for display rotation and more precise coordinate mapping

### Phase 3: Robustness and distribution

Deliverable: app bundle suitable for daily use.

Adds:

- Signed app bundle
- Hardened runtime / entitlements review
- More conservative matching rules
- Optional diagnostics export

## Architecture

## Core logic

Keep pure logic outside the process code so it can be tested without hardware.

Current implementation:

- `src/main.m`

Responsibilities:

- Initialize AppKit runtime
- Enumerate `NSScreen` instances
- Match the target display by screen name
- Monitor `IOHIDManager` for likely XENEON devices
- Register input callbacks for matched HID devices
- On each callback:
  - read current pointer location
  - check whether that location is on the target display
  - warp to target display center if not
- React to display reconfiguration

## Why center-warp first

Center-warp is the simplest useful test.

If center-warp does not make the display usable, exact touch-coordinate mapping is unlikely to save the concept unless callback timing is still acceptable. If center-warp does help, then parsing exact coordinates becomes worth the extra complexity.

## Detailed prototype behavior

At startup:

1. Start AppKit.
2. Print trust / permission status.
3. Enumerate all screens and attempt to match the XENEON by localized screen name.
4. Enumerate HID devices and print summary information for each likely candidate.
5. Register callbacks for matched HID devices.
6. Listen indefinitely on the run loop.

On HID input:

1. Ignore the event if no target display is currently matched.
2. Read current pointer location.
3. If the pointer is already on the target display, do nothing.
4. If the pointer is off the target display and cooldown is inactive, warp to target display center.
5. Record the warp timestamp.

On display changes:

1. Re-enumerate screens.
2. Re-match the target display.
3. Continue using existing HID registrations.

## Known technical risks

### Risk 1: Wrong HID device matched

The current heuristics intentionally over-match.

Mitigation:

- Capture real vendor ID, product ID, usage page, and usage from the XENEON
- Tighten matching once the hardware identifiers are known

### Risk 2: HID callback arrives too late

If macOS has already committed the click path by the time the callback fires, the workaround will be unreliable.

Mitigation:

- Log event timing and user experience during real-device validation
- If timing is too late, investigate deeper HID parsing or driver-level work

### Risk 3: Pointer warp causes repeated callbacks

Pointer movement or related synthetic state could retrigger handling.

Mitigation:

- Cooldown is already in place
- Add more precise event filtering if real-world logs show feedback loops

### Risk 4: Display name matching is unstable

Localized display names may differ between connection methods or macOS versions.

Mitigation:

- Add a one-time device pairing flow in the later menu bar app
- Persist the chosen display ID / stable identifier if available

## Build strategy

## Current build shape

Use the lowest-friction toolchain that actually works on the local machine while the project is still a prototype.

Reasons:

- `clang` currently works on this machine while Swift does not
- no external dependencies are required
- easy to convert later into an app target or a Swift rewrite if the local Swift toolchain is repaired

## When to move to an app target

Move to a real macOS app target when one of these becomes necessary:

- menu bar UI
- login item
- bundled permission flow
- signing / notarization
- distribution outside your own machine

At that point, keep the current package-style module boundaries, but host them from an Xcode app project:

- `App/`: menu bar app
- `Core/`: pure logic
- `Platform/`: HID and display integration

## Repo organization recommendation

Keep the repo small and intentional.

- `src/`
- `docs/`
- `build/` ignored by git

Avoid adding generated Xcode state, binary artifacts, screenshots, or ad-hoc shell snippets to the root.

## Git workflow recommendation

For now:

- keep `main` or `master` clean and runnable
- use short-lived feature branches with the `codex/` prefix
- commit in vertical slices, not file dumps

Recommended commit sequence for next work:

1. `codex/bootstrap-prototype`
2. `codex/hid-device-pairing`
3. `codex/menu-bar-shell`
4. `codex/coordinate-mapping`

## Next engineering steps

1. Run the prototype with the XENEON connected and collect the printed HID identifiers.
2. Tighten matching rules to the exact device.
3. Validate whether center-warp alone is enough in practice.
4. If yes, add a menu bar app shell.
5. If no, inspect raw HID reports for exact touch coordinates.
6. Repair or replace the local Swift toolchain only if and when a Swift rewrite becomes worth it.
