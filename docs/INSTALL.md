# Install Guide

## End-user install

The intended end-user artifact is a zipped macOS app bundle:

- `XeneonTouchSupport-macOS.zip`

Install it like a normal Mac app:

1. Download the zip from the GitHub release.
2. Unzip it.
3. Drag `XeneonTouchSupport.app` into `/Applications`.
4. Launch it once from Finder.
5. Grant the requested permissions in:
   - `System Settings > Privacy & Security > Accessibility`
   - `System Settings > Privacy & Security > Input Monitoring`
6. Quit and relaunch the app after changing permissions.

The app runs as a menu bar utility with a small `XE` status item.
The `XE` menu shows whether the XENEON display is recognized, whether permissions are granted, whether a matching touch device is present, and offers a `Copy Diagnostics` action.

If permissions still do not seem to apply, remove the app from both `Accessibility` and `Input Monitoring`, add it again, and relaunch it.

## First launch checklist

Expected startup behavior:

- The app appears in the menu bar.
- The `XE` menu shows the XENEON display as connected.
- The `XE` menu shows the touchscreen device as matched.
- The `XE` menu shows `Status: Ready` once permissions and device matching are in place.

If that does not happen, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
