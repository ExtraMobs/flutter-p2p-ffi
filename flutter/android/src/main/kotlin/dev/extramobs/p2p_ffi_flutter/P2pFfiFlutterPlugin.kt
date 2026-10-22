package dev.extramobs.p2p_ffi_flutter

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * Starts and stops [P2pForegroundService] for the Dart side, and asks for the
 * notification permission its notification needs (Android 13+).
 */
class P2pFfiFlutterPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    PluginRegistry.RequestPermissionsResultListener {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: ActivityPluginBinding? = null
    private var pendingPermission: MethodChannel.Result? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "p2p_ffi_flutter")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startForeground" -> {
                val intent = Intent(context, P2pForegroundService::class.java)
                    .putExtra("config", bundle(call.arguments))
                try {
                    P2pForegroundService.start(context, intent)
                    result.success(null)
                } catch (e: RuntimeException) {
                    // e.g. ForegroundServiceStartNotAllowedException (app in
                    // the background, Android 12+)
                    result.error("startForeground", e.toString(), null)
                }
            }
            "stopForeground" -> {
                P2pForegroundService.stop(context)
                result.success(null)
            }
            "updateNotification" -> {
                P2pForegroundService.update(context, bundle(call.arguments))
                result.success(null)
            }
            "requestNotificationPermission" -> requestNotificationPermission(result)
            else -> result.notImplemented()
        }
    }

    // true if notifications may be shown: granted now or before, or Android
    // below 13 (no runtime permission); false if denied or without an Activity.
    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33 ||
            context.checkSelfPermission(NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        val a = activity?.activity
        if (a == null || pendingPermission != null) {
            result.success(false)
            return
        }
        pendingPermission = result
        a.requestPermissions(arrayOf(NOTIFICATIONS), REQUEST_NOTIFICATIONS)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        val pending = pendingPermission
        if (requestCode != REQUEST_NOTIFICATIONS || pending == null) return false
        pending.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        pendingPermission = null
        return true
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        activity?.removeRequestPermissionsResultListener(this)
        activity = null
        pendingPermission?.success(false)
        pendingPermission = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private companion object {
        const val NOTIFICATIONS = "android.permission.POST_NOTIFICATIONS"
        const val REQUEST_NOTIFICATIONS = 0x1f5

        // the Dart P2pNotification (a map of strings, ints, bools and the
        // extras map) as the Bundle the service reads
        fun bundle(args: Any?): Bundle {
            val b = Bundle()
            (args as? Map<*, *>)?.forEach { (k, v) ->
                val key = k.toString()
                when (v) {
                    is String -> b.putString(key, v)
                    is Int -> b.putInt(key, v)
                    is Boolean -> b.putBoolean(key, v)
                    is Map<*, *> -> b.putBundle(key, bundle(v))
                }
            }
            return b
        }
    }
}
