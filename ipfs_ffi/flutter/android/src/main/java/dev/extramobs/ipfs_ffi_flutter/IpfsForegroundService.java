package dev.extramobs.ipfs_ffi_flutter;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.os.Build;
import android.os.IBinder;

/**
 * Foreground service that keeps the app process, and the ipfs_host child
 * process, out of the background limits (IpfsBackground.foregroundService).
 * It runs nothing itself: the IPFS node lives in the ipfs_host.
 */
public class IpfsForegroundService extends Service {
    private static final String CHANNEL = "ipfs_ffi";
    private static final int NOTIFICATION_ID = 0x1af5;

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        String title = intent == null ? null : intent.getStringExtra("title");
        String text = intent == null ? null : intent.getStringExtra("text");
        Notification.Builder builder;
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationManager manager = getSystemService(NotificationManager.class);
            manager.createNotificationChannel(
                    new NotificationChannel(CHANNEL, "IPFS", NotificationManager.IMPORTANCE_LOW));
            builder = new Notification.Builder(this, CHANNEL);
        } else {
            builder = new Notification.Builder(this);
        }
        Intent launch = getPackageManager().getLaunchIntentForPackage(getPackageName());
        if (launch != null) {
            builder.setContentIntent(
                    PendingIntent.getActivity(this, 0, launch, PendingIntent.FLAG_IMMUTABLE));
        }
        Notification notification = builder
                .setContentTitle(title == null ? "IPFS" : title)
                .setContentText(text == null ? "IPFS node running" : text)
                .setSmallIcon(getApplicationInfo().icon)
                .setOngoing(true)
                .build();
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

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
