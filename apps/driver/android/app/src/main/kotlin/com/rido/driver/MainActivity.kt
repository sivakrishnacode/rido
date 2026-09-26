package com.rido.driver

import android.app.ActivityManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Small native bridge for background ride requests (`rido/driver_app`, see lib/overlay/offer_alerts.dart):
 * bring the app to the front after Accept on the floating overlay, and the Android 14+ full-screen-intent
 * permission (check, and open its settings page).
 */
class MainActivity : FlutterActivity() {
    /**
     * One Flutter engine for the whole process, not owned by this screen. Android may destroy a background app's
     * screen while the process lives on (the GPS foreground service keeps it alive while online); a FlutterActivity
     * normally destroys its engine with it, so tapping the bubble / reopening started the app from scratch (online
     * state, request and bubble lost). Now a recreated screen reattaches to the running app.
     */
    override fun provideFlutterEngine(context: Context): FlutterEngine {
        FlutterEngineCache.getInstance().get(ENGINE_ID)?.let { return it }
        val engine = FlutterEngine(context.applicationContext)
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        return engine
    }

    /** Keep the engine (and the driver's session) when this screen is destroyed. */
    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createBubbleChannel()
    }

    /**
     * The floating bubble runs as a foreground service, which Android requires to show a notification. The overlay
     * plugin creates its channel ("Overlay Channel") at default importance, so the notification popped up on every
     * minimise. Creating the channel first at minimum importance wins (Android keeps a channel's first importance):
     * the notification stays silent and collapsed, without a status-bar icon.
     */
    private fun createBubbleChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java) ?: return
        if (nm.getNotificationChannel(OVERLAY_CHANNEL_ID) != null) return
        val channel = NotificationChannel(OVERLAY_CHANNEL_ID, "Floating bubble", NotificationManager.IMPORTANCE_MIN).apply {
            description = "Keeps the Rido bubble on screen while you use other apps"
            setShowBadge(false)
            setSound(null, null)
            enableVibration(false)
        }
        nm.createNotificationChannel(channel)
    }

    /** Moves the existing Rido task to the front (never a second copy); falls back to the launcher intent. */
    private fun bringToFront(): Boolean {
        try {
            val am = getSystemService(ActivityManager::class.java)
            val task = am?.appTasks?.firstOrNull()
            if (task != null) {
                task.moveToFront()
                return true
            }
        } catch (e: Exception) {
            // Fall back below.
        }
        return try {
            val launch = packageManager.getLaunchIntentForPackage(packageName) ?: return false
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            startActivity(launch)
            true
        } catch (e: Exception) {
            false
        }
    }

    companion object {
        private const val ENGINE_ID = "rido_main"
        /** Channel id used by flutter_overlay_window's OverlayService. */
        private const val OVERLAY_CHANNEL_ID = "Overlay Channel"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rido/driver_app").setMethodCallHandler { call, result ->
            when (call.method) {
                "bringToFront" -> result.success(bringToFront())
                "canUseFullScreenIntent" -> {
                    if (Build.VERSION.SDK_INT >= 34) {
                        val nm = getSystemService(NotificationManager::class.java)
                        result.success(nm?.canUseFullScreenIntent() ?: true)
                    } else {
                        result.success(true)
                    }
                }
                "openFullScreenIntentSettings" -> {
                    if (Build.VERSION.SDK_INT >= 34) {
                        try {
                            startActivity(
                                Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:$packageName"))
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                        } catch (e: Exception) {
                            // Older OEM builds without the page.
                        }
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
