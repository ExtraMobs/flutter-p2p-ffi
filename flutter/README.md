# p2p_ffi_flutter

Android side of [`p2p_ffi`](..). The Go code (an IPFS node, a libp2p host) runs in the
`p2p_host`, a child process of the app. On Android 12+ the system kills a child process that uses CPU
while its app is in the background, and the app with it. This plugin handles the
background according to `P2pService.background`, which is read whenever the service
starts (`start`/`restart`):

- `P2pBackground.stop` (default): when the app goes to the background
  (`AppLifecycleState.paused`), the service stops. Pending calls fail with
  `P2pServiceException(reason: P2pStopReason.background)` and `onStop` gets an
  `P2pStop` with that reason. Starting it again is up to the app
  (`P2pService.restart()`).
- `P2pBackground.foregroundService`: while the service runs, an Android foreground
  service (type `specialUse`, with a notification) keeps the app, and the
  `p2p_host`, running in the background. It starts with the service, while the app
  is in the foreground (Android 12+ does not allow starting it from the background).
  When the `p2p_host` crashes in this mode the Android service stays up, so `onStop`
  can call `P2pService.restart()` from the background; `P2pService.stop()` ends it.

```yaml
dependencies:
  p2p_ffi:
    path: <repository root>
  p2p_ffi_flutter:
    path: <repository root>/flutter
```

```dart
P2pService.background = P2pBackground.foregroundService; // or keep the default
P2pFfiFlutter.notification = const P2pNotification(
    title: 'My app', text: 'connecting...', icon: 'ic_stat_ipfs', // res/drawable
    channelName: 'IPFS node');
await P2pFfiFlutter.requestNotificationPermission(); // Android 13+
await P2pService.start(onStop: (stop) { /* crash or background */ });
// while it runs, from the background too:
await P2pFfiFlutter.updateNotification(
    P2pFfiFlutter.notification.copyWith(text: 'online: $n peers'));
```

The notification is the app's: `P2pNotification` sets its title, text, sub text,
small icon (a drawable or mipmap name; the app icon by default), channel (id, name,
description, importance: Android fixes a channel's importance when it is first
created) and whether a tap opens the app. For full control (actions, styles, custom
layouts) register a native builder before the service starts; the channel is already
created and `config` holds the `P2pNotification` fields plus `extras` (free strings
from Dart):

```kotlin
P2pForegroundService.setNotificationFactory { context, channelId, config ->
    Notification.Builder(context, channelId)
        .setContentTitle(config.getString("title"))
        .setSmallIcon(R.drawable.ic_stat_ipfs)
        .build()
}
```

There is nothing to register: Flutter calls `P2pFfiFlutter.registerWith()` when the
app starts. The plugin's manifest adds `FOREGROUND_SERVICE`,
`FOREGROUND_SERVICE_SPECIAL_USE` and `POST_NOTIFICATIONS`. On Android 13+ the app
asks for the notification permission (`requestNotificationPermission()` shows the
system dialog and returns whether it was granted); without it the service still runs,
but the notification is not shown. Google Play asks for a justification of the
`specialUse` type.

Without Flutter, an app can call `P2pService.appInBackground()` itself.
