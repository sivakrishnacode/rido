# Vendored flutter_overlay_window 0.5.0 (MIT, Iheb Briki) with Rido patches

Used by `apps/driver` via `dependency_overrides`. Patches (search for "Rido patch"):

1. `OverlayService.onStartCommand`: `START_NOT_STICKY`, and a null intent (system restart after the app process was
   killed) stops the service instead of showing an orphan bubble / crashing.
2. Showing again no longer calls `stopSelf()` right after adding the new window (the bubble vanished).
3. Bubble (drag) mode: the service owns the touches. A tap opens the app natively (`openApp`, launcher intent), a drag
   moves the bubble (8 dp slop); Flutter never sees them (drags used to register as taps, taps were missed).
4. `openApp` on the overlay channel (+ `FlutterOverlayWindow.openApp()` in Dart): moves the app's existing task to the
   front (`ActivityManager.getAppTasks()`), falling back to the launcher intent.
5. `closeOverlay` always stops the service (even while it is still starting) and always completes (the Future never
   completed when the overlay wasn't running, which blocked the driver app's overlay queue).
6. `overlayListener` is a broadcast stream (re-listening threw "Stream has already been listened to").
