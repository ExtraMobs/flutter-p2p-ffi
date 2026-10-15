package dev.extramobs.ipfs_ffi_flutter;

import android.content.Context;
import android.content.Intent;
import android.os.Build;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/** Starts and stops {@link IpfsForegroundService} for the Dart side. */
public class IpfsFfiFlutterPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    private MethodChannel channel;
    private Context context;

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
                intent.putExtra("title", call.<String>argument("title"));
                intent.putExtra("text", call.<String>argument("text"));
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
            default:
                result.notImplemented();
        }
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }
}
