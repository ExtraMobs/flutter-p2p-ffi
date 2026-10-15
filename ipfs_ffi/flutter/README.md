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

```yaml
dependencies:
  ipfs_ffi:
    path: <...>/ipfs_ffi
  ipfs_ffi_flutter:
    path: <...>/ipfs_ffi/flutter
```

```dart
IpfsService.background = IpfsBackground.foregroundService; // or keep the default
IpfsFfiFlutter.notificationTitle = 'My app';
IpfsFfiFlutter.notificationText = 'IPFS node online';
await IpfsService.start(onStop: (stop) { /* crash or background */ });
```

There is nothing to register: Flutter calls `IpfsFfiFlutter.registerWith()` when the
app starts. The plugin's manifest adds `FOREGROUND_SERVICE`,
`FOREGROUND_SERVICE_SPECIAL_USE` and `POST_NOTIFICATIONS`. On Android 13+ the app
asks for the notification permission itself; without it the service still runs, but
the notification is not shown. Google Play asks for a justification of the
`specialUse` type.

Without Flutter, an app can call `IpfsService.appInBackground()` itself.
