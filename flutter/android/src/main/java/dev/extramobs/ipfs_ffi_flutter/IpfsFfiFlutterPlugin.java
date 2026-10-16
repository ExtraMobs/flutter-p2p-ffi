package dev.extramobs.ipfs_ffi_flutter;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

import java.util.Map;

/**
 * Starts and stops {@link IpfsForegroundService} for the Dart side, and asks
 * for the notification permission its notification needs (Android 13+).
 */
public class IpfsFfiFlutterPlugin
        implements FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler,
                PluginRegistry.RequestPermissionsResultListener {
    private static final String NOTIFICATIONS = "android.permission.POST_NOTIFICATIONS";
    private static final int REQUEST_NOTIFICATIONS = 0x1f5;

    private MethodChannel channel;
    private Context context;
    private ActivityPluginBinding activity;
    private MethodChannel.Result pendingPermission;

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "ipfs_ffi_flutter");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        Intent intent = new Intent(context, IpfsForegroundService.class);
        switch (call.method) {
            case "startForeground":
                intent.putExtra("config", bundle(call.arguments));
                try {
                    if (Build.VERSION.SDK_INT >= 26) {
                        context.startForegroundService(intent);
                    } else {
                        context.startService(intent);
                    }
                    result.success(null);
                } catch (RuntimeException e) {
                    // e.g. ForegroundServiceStartNotAllowedException (app in
                    // the background, Android 12+)
                    result.error("startForeground", e.toString(), null);
                }
                break;
            case "stopForeground":
                context.stopService(intent);
                result.success(null);
                break;
            case "updateNotification":
                IpfsForegroundService.update(context, bundle(call.arguments));
                result.success(null);
                break;
            case "requestNotificationPermission":
                requestNotificationPermission(result);
                break;
            default:
                result.notImplemented();
        }
    }

    // the Dart IpfsNotification (a map of strings, ints, bools and the extras
    // map) as the Bundle the service reads
    private static Bundle bundle(Object args) {
        Bundle b = new Bundle();
        if (!(args instanceof Map)) return b;
        for (Map.Entry<?, ?> e : ((Map<?, ?>) args).entrySet()) {
            String k = String.valueOf(e.getKey());
            Object v = e.getValue();
            if (v instanceof String) b.putString(k, (String) v);
            else if (v instanceof Integer) b.putInt(k, (Integer) v);
            else if (v instanceof Boolean) b.putBoolean(k, (Boolean) v);
            else if (v instanceof Map) b.putBundle(k, bundle(v));
        }
        return b;
    }

    // true if notifications may be shown: granted now or before, or Android
    // below 13 (no runtime permission); false if denied or without an Activity.
    private void requestNotificationPermission(MethodChannel.Result result) {
        if (Build.VERSION.SDK_INT < 33
                || context.checkSelfPermission(NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            result.success(true);
            return;
        }
        Activity a = activity == null ? null : activity.getActivity();
        if (a == null || pendingPermission != null) {
            result.success(false);
            return;
        }
        pendingPermission = result;
        a.requestPermissions(new String[] {NOTIFICATIONS}, REQUEST_NOTIFICATIONS);
    }

    @Override
    public boolean onRequestPermissionsResult(int code, String[] permissions, int[] grants) {
        if (code != REQUEST_NOTIFICATIONS || pendingPermission == null) return false;
        boolean granted = grants.length > 0 && grants[0] == PackageManager.PERMISSION_GRANTED;
        pendingPermission.success(granted);
        pendingPermission = null;
        return true;
    }

    @Override
    public void onAttachedToActivity(ActivityPluginBinding binding) {
        activity = binding;
        binding.addRequestPermissionsResultListener(this);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) {
        onAttachedToActivity(binding);
    }

    @Override
    public void onDetachedFromActivity() {
        if (activity != null) activity.removeRequestPermissionsResultListener(this);
        activity = null;
        if (pendingPermission != null) {
            pendingPermission.success(false);
            pendingPermission = null;
        }
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }
}
