package com.believoo.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Dedupes FCM pushes before they are displayed.
 *
 * The backend occasionally re-sends the same push many times (e.g. "Host
 * Level Up!"). Notification-payload messages are displayed by the FCM SDK /
 * system tray directly in background & killed state, so the Dart-side dedupe
 * in push_notification_service.dart never sees them. This receiver sits on
 * the same c2dm RECEIVE ordered broadcast at max priority and calls
 * abortBroadcast() for duplicates — suppressing them before the system tray
 * OR the Flutter background handler can show them.
 *
 * Non-duplicates pass through untouched. If the broadcast isn't ordered on a
 * given device, abortBroadcast() is a harmless no-op.
 */
class FcmDedupeReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "FcmDedupe"
        private const val PREFS = "fcm_dedupe"
        private const val DEFAULT_WINDOW_MS = 2 * 60 * 1000L          // 2 min
        private const val LEVEL_UP_WINDOW_MS = 24 * 60 * 60 * 1000L   // 24 h
    }

    override fun onReceive(context: Context, intent: Intent) {
        try {
            val extras = intent.extras ?: return

            // FCM puts notification fields under "gcm.notification.*" (newer
            // SDKs) or "gcm.n.*" keys; data fields sit at the top level.
            val title = extras.getString("gcm.notification.title")
                ?: extras.getString("gcm.n.title")
                ?: extras.getString("title") ?: ""
            val body = extras.getString("gcm.notification.body")
                ?: extras.getString("gcm.n.body")
                ?: extras.getString("body")
                ?: extras.getString("message") ?: ""
            val type = extras.getString("type") ?: ""

            // Nothing displayable — let other receivers decide.
            if (title.isEmpty() && body.isEmpty()) return

            val signature = "$type|$title|$body"
            val window =
                if (type.equals("LEVELUP", ignoreCase = true)) LEVEL_UP_WINDOW_MS
                else DEFAULT_WINDOW_MS

            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()
            val last = prefs.getLong(signature, 0L)

            if (last != 0L && now - last < window) {
                Log.d(TAG, "suppressing duplicate push: $title")
                abortBroadcast()
                return
            }
            prefs.edit().putLong(signature, now).apply()
        } catch (e: Exception) {
            // Never let a dedupe failure break delivery.
            Log.w(TAG, "dedupe check failed: ${e.message}")
        }
    }
}
