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

## First launch checklist

Expected startup behavior:

- The app appears in the menu bar.
- The console log lists the built-in display and the XENEON EDGE display.
- The XENEON display is marked as the target display.
- The matching touchscreen HID devices are listed.

If that does not happen, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Build from source

For developers or power users:

```bash
make app
```

The app bundle will be created at:

- `build/XeneonTouchSupport.app`

To prepare a release zip:

```bash
make zip
```

That produces:

- `build/XeneonTouchSupport-macOS.zip`
