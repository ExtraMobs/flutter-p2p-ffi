package dev.extramobs.ipfs_ffi_flutter;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.os.Build;
import android.os.Bundle;
import android.os.IBinder;

/**
 * Foreground service that keeps the app process, and the ipfs_host child
 * process, out of the background limits (IpfsBackground.foregroundService).
 * It runs nothing itself: the IPFS node lives in the ipfs_host.
 *
 * <p>Its notification (Android requires one) is the app's: built from the
 * {@code IpfsNotification} set in Dart, or by a {@link NotificationFactory}
 * registered from native code for full control (actions, styles, layouts).
 */
public class IpfsForegroundService extends Service {
    static final int NOTIFICATION_ID = 0x1af5;

    /**
     * Builds the service notification. Called on the main thread with the
     * channel already created and {@code config} holding the Dart
     * {@code IpfsNotification} ("title", "text", "channelId", "extras", a
     * Bundle of the developer's own strings...).
     */
    public interface NotificationFactory {
        Notification create(Context context, String channelId, Bundle config);
    }

    private static volatile NotificationFactory factory;

    /**
     * Registers the builder of the service notification (for instance in
     * {@code MainActivity.onCreate}, before the service starts); null goes
     * back to the one built from the Dart configuration.
     */
    public static void setNotificationFactory(NotificationFactory f) {
        factory = f;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Bundle config = intent == null ? null : intent.getBundleExtra("config");
        Notification notification = build(this, config == null ? new Bundle() : config);
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFICATION_ID, notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE);
        } else {
            startForeground(NOTIFICATION_ID, notification);
        }
        // if the system kills the app, the ipfs_host goes with it: do not
        // recreate the service alone
        return START_NOT_STICKY;
    }

    /** Replaces the notification of the running service. */
    static void update(Context context, Bundle config) {
        context.getSystemService(NotificationManager.class)
                .notify(NOTIFICATION_ID, build(context, config));
    }

    static Notification build(Context context, Bundle config) {
        String channel = config.getString("channelId", "ipfs_ffi");
        if (Build.VERSION.SDK_INT >= 26) {
            // the importance of an existing channel cannot change (Android)
            NotificationChannel c = new NotificationChannel(channel,
                    config.getString("channelName", "IPFS"),
                    config.getInt("importance", NotificationManager.IMPORTANCE_LOW));
            c.setDescription(config.getString("channelDescription"));
            context.getSystemService(NotificationManager.class).createNotificationChannel(c);
        }
        NotificationFactory f = factory;
        if (f != null) return f.create(context, channel, config);

        Notification.Builder builder = Build.VERSION.SDK_INT >= 26
                ? new Notification.Builder(context, channel)
                : new Notification.Builder(context);
        if (config.getBoolean("tapOpensApp", true)) {
            Intent launch = context.getPackageManager()
                    .getLaunchIntentForPackage(context.getPackageName());
            if (launch != null) {
                builder.setContentIntent(PendingIntent.getActivity(
                        context, 0, launch, PendingIntent.FLAG_IMMUTABLE));
            }
        }
        String sub = config.getString("subText");
        if (sub != null) builder.setSubText(sub);
        return builder
                .setContentTitle(config.getString("title", "IPFS"))
                .setContentText(config.getString("text", "IPFS node running"))
                .setSmallIcon(icon(context, config.getString("icon")))
                .setOngoing(true)
                .setShowWhen(config.getBoolean("showWhen", false))
                .build();
    }

    // a drawable (or mipmap) of the app by name; the app icon otherwise
    private static int icon(Context context, String name) {
        if (name != null) {
            for (String type : new String[] {"drawable", "mipmap"}) {
                int id = context.getResources().getIdentifier(name, type, context.getPackageName());
                if (id != 0) return id;
            }
        }
        return context.getApplicationInfo().icon;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
