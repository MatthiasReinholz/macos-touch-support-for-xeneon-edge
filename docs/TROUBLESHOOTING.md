# Troubleshooting

## The app starts, but nothing happens on touch

Check these first:

- Accessibility is enabled for `XeneonTouchSupport.app`
- Input Monitoring is enabled for `XeneonTouchSupport.app`
- The app was relaunched after permission changes
- The XENEON display is connected before the app starts

## The wrong display is detected

The app matches the target display by:

- explicit `XENEON_DISPLAY_ID`, if set
- otherwise by display-name hints such as `XENEON`, `EDGE`, and `CORSAIR`

For debugging, launch from Terminal once and inspect the startup log:

```bash
make run
```

If needed, pin the display:

```bash
XENEON_DISPLAY_ID=2 make run
```

## Touches are seen, but taps still behave strangely

The current implementation is still a user-space workaround. Known limitations:

- macOS may still move the visible cursor to the top edge of the XENEON during takeover
- some apps require focus handoff before the synthetic release click works reliably
- the touchscreen’s native path is not fully replaced by a driver-level implementation

The app is most reliable when:

- the XENEON is in a stable monitor arrangement
- the app already has Accessibility and Input Monitoring access
- the pointer starts on another display and the app performs the takeover

## Touches work only after the pointer is already on the XENEON

That usually means the native macOS path is handling the second touch well, but the takeover path still needs tuning for that specific app.

Check the startup log for:

- the matched target display
- matched HID devices
- the takeover point
- whether the synthetic click was posted on release

## The app is running but I want to stop it

Use the `XE` menu bar item and choose `Quit`.

If the menu bar item is not visible, quit the app from Activity Monitor.
