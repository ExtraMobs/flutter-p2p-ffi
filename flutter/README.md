# ipfs_ffi_flutter

Android side of [`ipfs_ffi`](..). The IPFS node runs in the `ipfs_host`, a child
process of the app. On Android 12+ the system kills a child process that uses CPU
while its app is in the background, and the app with it. This plugin handles the
background according to `IpfsService.background`, which is read whenever the service
starts (`start`/`restart`):

- `IpfsBackground.stop` (default): when the app goes to the background
  (`AppLifecycleState.paused`), the service stops. Pending calls fail with
  `IpfsServiceException(reason: IpfsStopReason.background)` and `onStop` gets an
  `IpfsStop` with that reason. Starting it again is up to the app
  (`IpfsService.restart()`).
- `IpfsBackground.foregroundService`: while the service runs, an Android foreground
  service (type `specialUse`, with a notification) keeps the app, and the
  `ipfs_host`, running in the background. It starts with the service, while the app
  is in the foreground (Android 12+ does not allow starting it from the background).
  When the `ipfs_host` crashes in this mode the Android service stays up, so `onStop`
  can call `IpfsService.restart()` from the background; `IpfsService.stop()` ends it.

```yaml
dependencies:
  ipfs_ffi:
    path: <repository root>
  ipfs_ffi_flutter:
    path: <repository root>/flutter
```

```dart
IpfsService.background = IpfsBackground.foregroundService; // or keep the default
IpfsFfiFlutter.notification = const IpfsNotification(
    title: 'My app', text: 'connecting...', icon: 'ic_stat_ipfs', // res/drawable
    channelName: 'IPFS node');
await IpfsFfiFlutter.requestNotificationPermission(); // Android 13+
await IpfsService.start(onStop: (stop) { /* crash or background */ });
// while it runs, from the background too:
await IpfsFfiFlutter.updateNotification(
    IpfsFfiFlutter.notification.copyWith(text: 'online: $n peers'));
```

The notification is the app's: `IpfsNotification` sets its title, text, sub text,
small icon (a drawable or mipmap name; the app icon by default), channel (id, name,
description, importance: Android fixes a channel's importance when it is first
created) and whether a tap opens the app. For full control (actions, styles, custom
layouts) register a native builder before the service starts; the channel is already
created and `config` holds the `IpfsNotification` fields plus `extras` (free strings
from Dart):

```kotlin
IpfsForegroundService.setNotificationFactory { context, channelId, config ->
    Notification.Builder(context, channelId)
        .setContentTitle(config.getString("title"))
        .setSmallIcon(R.drawable.ic_stat_ipfs)
        .build()
}
```

There is nothing to register: Flutter calls `IpfsFfiFlutter.registerWith()` when the
app starts. The plugin's manifest adds `FOREGROUND_SERVICE`,
`FOREGROUND_SERVICE_SPECIAL_USE` and `POST_NOTIFICATIONS`. On Android 13+ the app
asks for the notification permission (`requestNotificationPermission()` shows the
system dialog and returns whether it was granted); without it the service still runs,
but the notification is not shown. Google Play asks for a justification of the
`specialUse` type.

Without Flutter, an app can call `IpfsService.appInBackground()` itself.
