package dev.extramobs.p2p_ffi_flutter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Bundle
import android.os.IBinder

/**
 * Foreground service that keeps the app process, and the p2p_host child
 * process, out of the background limits (P2pBackground.foregroundService).
 * It runs nothing itself: the IPFS node lives in the p2p_host.
 *
 * Its notification (Android requires one) is the app's: built from the
 * `P2pNotification` set in Dart, or by a [NotificationFactory] registered from
 * native code for full control (actions, styles, layouts).
 */
class P2pForegroundService : Service() {
    /**
     * Builds the service notification. Called on the main thread with the
     * channel already created and `config` holding the Dart `P2pNotification`
     * ("title", "text", "channelId", "extras", a Bundle of the developer's own
     * strings...).
     */
    fun interface NotificationFactory {
        fun create(context: Context, channelId: String, config: Bundle): Notification
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = build(this, intent?.getBundleExtra("config") ?: Bundle())
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        starting = false
        if (stopPending) {
            stopPending = false
            stopSelf()
        }
        // if the system kills the app, the p2p_host goes with it: do not
        // recreate the service alone
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        internal const val NOTIFICATION_ID = 0x1af5

        @Volatile
        private var factory: NotificationFactory? = null

        // A stopService between startForegroundService and the service's
        // startForeground makes Android kill the app
        // (ForegroundServiceDidNotStartInTimeException): a stop that arrives in
        // that window waits, and the service stops itself once in the
        // foreground. Only touched on the main thread (the plugin's method
        // channel and onStartCommand).
        private var starting = false
        private var stopPending = false

        /** Starts the service (from the plugin, with the app in the foreground). */
        internal fun start(context: Context, intent: Intent) {
            starting = true
            stopPending = false
            try {
                if (Build.VERSION.SDK_INT >= 26) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: RuntimeException) {
                starting = false
                throw e
            }
        }

        /** Stops the service, or schedules the stop if it is still starting. */
        internal fun stop(context: Context) {
            if (starting) {
                stopPending = true
            } else {
                context.stopService(Intent(context, P2pForegroundService::class.java))
            }
        }

        /**
         * Registers the builder of the service notification (for instance in
         * `MainActivity.onCreate`, before the service starts); null goes back
         * to the one built from the Dart configuration.
         */
        @JvmStatic
        fun setNotificationFactory(f: NotificationFactory?) {
            factory = f
        }

        /** Replaces the notification of the running service. */
        internal fun update(context: Context, config: Bundle) {
            context.getSystemService(NotificationManager::class.java)
                .notify(NOTIFICATION_ID, build(context, config))
        }

        internal fun build(context: Context, config: Bundle): Notification {
            val channel = config.getString("channelId", "p2p_ffi")
            if (Build.VERSION.SDK_INT >= 26) {
                // the importance of an existing channel cannot change (Android)
                val c = NotificationChannel(
                    channel,
                    config.getString("channelName", "IPFS"),
                    config.getInt("importance", NotificationManager.IMPORTANCE_LOW),
                )
                c.description = config.getString("channelDescription")
                context.getSystemService(NotificationManager::class.java)
                    .createNotificationChannel(c)
            }
            factory?.let { return it.create(context, channel, config) }

            val builder = if (Build.VERSION.SDK_INT >= 26) {
                Notification.Builder(context, channel)
            } else {
                @Suppress("DEPRECATION") Notification.Builder(context)
            }
            if (config.getBoolean("tapOpensApp", true)) {
                context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
                    builder.setContentIntent(
                        PendingIntent.getActivity(context, 0, it, PendingIntent.FLAG_IMMUTABLE)
                    )
                }
            }
            config.getString("subText")?.let { builder.setSubText(it) }
            return builder
                .setContentTitle(config.getString("title", "IPFS"))
                .setContentText(config.getString("text", "IPFS node running"))
                .setSmallIcon(icon(context, config.getString("icon")))
                .setOngoing(true)
                .setShowWhen(config.getBoolean("showWhen", false))
                .build()
        }

        // a drawable (or mipmap) of the app by name; the app icon otherwise
        private fun icon(context: Context, name: String?): Int {
            if (name != null) {
                for (type in arrayOf("drawable", "mipmap")) {
                    val id = context.resources.getIdentifier(name, type, context.packageName)
                    if (id != 0) return id
                }
            }
            return context.applicationInfo.icon
        }
    }
}
