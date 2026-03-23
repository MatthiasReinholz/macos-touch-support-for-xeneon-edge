# Troubleshooting

## The app starts, but nothing happens on touch

Check these first:

- Accessibility is enabled for `XeneonTouchSupport.app`
- Input Monitoring is enabled for `XeneonTouchSupport.app`
- The app was relaunched after permission changes
- The XENEON display is connected before the app starts
- The `XE` menu does not show a missing-permission or missing-display status

## `make run` works, but the packaged app does not

macOS permissions are granted per app.

That means:

- giving Terminal access does not automatically give the packaged app access
- the packaged app must be granted `Accessibility` and `Input Monitoring` separately
- after changing those permissions, the packaged app must be quit and relaunched

Use the `XE` menu to check:

- `Permissions: Accessibility yes, Input Monitoring yes`
- `Display: ... (connected)`
- `Touch device: ... matched`

If Input Monitoring is still missing, remove the app from `Input Monitoring`, launch it again, approve the prompt, and relaunch once more.

If the app still does not recognize the permissions after that, remove its entries from both `Accessibility` and `Input Monitoring`, then add the app again and relaunch it.

## The wrong display is detected

If the app does not recognize the XENEON correctly:

- quit the app
- confirm the XENEON is connected and visible in macOS display settings
- relaunch the app and re-check the `XE` status menu

If it still selects the wrong display, use `Copy Diagnostics` and include the report in an issue.

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

If you want to report that behavior, use `Copy Diagnostics` and include the app name where the problem happens.

## Advanced debugging

These steps are only for developers or advanced users.

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

## The app is running but I want to stop it

Use the `XE` menu bar item and choose `Quit`.

If the menu bar item is not visible, quit the app from Activity Monitor.

## I want to send diagnostics

Use the `XE` menu and choose `Copy Diagnostics`, then paste the report into an issue or support message.
