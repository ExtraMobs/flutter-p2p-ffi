/// Android side of `ipfs_ffi`. Flutter registers it as
/// `IpfsService.platform` when the app starts; there is nothing to call.
///
/// While the service runs, it follows `IpfsService.background` (read when the
/// service starts):
/// - `IpfsBackground.stop` (default): when the app goes to the background,
///   the service stops and `onStop` gets `IpfsStopReason.background`;
/// - `IpfsBackground.foregroundService`: an Android foreground service keeps
///   the app, and the service, running in the background. Android requires
///   a notification for it; the app builds it: [IpfsFfiFlutter.notification]
///   (an [IpfsNotification]: title, text, icon, channel...), updated while
///   it runs with [IpfsFfiFlutter.updateNotification], or, for full control,
///   a native `IpfsForegroundService.setNotificationFactory` (README).
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:ipfs_ffi/ipfs_ffi.dart';

/// The Android [IpfsPlatform].
final class IpfsFfiFlutter implements IpfsPlatform {
  IpfsFfiFlutter._();

  /// Called by Flutter when the app starts.
  static void registerWith() => IpfsService.platform = IpfsFfiFlutter._();

  /// The foreground service notification, read when the service starts.
  static IpfsNotification notification = const IpfsNotification();

  /// Replaces [notification] and, while the foreground service runs, the
  /// notification it shows (allowed from the background).
  static Future<void> updateNotification(IpfsNotification n) async {
    notification = n;
    final p = IpfsService.platform;
    if (p is IpfsFfiFlutter && p._foreground) {
      await _channel.invokeMethod<void>('updateNotification', n._toMap());
    }
  }

  /// Asks for the notification permission (Android 13+), which the
  /// foreground service notification needs to be visible; without it the
  /// service still runs, with the notification hidden. Shows the system
  /// dialog when needed. Returns true when notifications are allowed (or
  /// Android is older than 13), false when denied or when there is no
  /// Activity to ask from. Call it from the foreground before starting
  /// with `IpfsBackground.foregroundService`.
  static Future<bool> requestNotificationPermission() async =>
      await _channel.invokeMethod<bool>('requestNotificationPermission') ??
      false;

  static const _channel = MethodChannel('ipfs_ffi_flutter');
  AppLifecycleListener? _lifecycle;
  var _foreground = false;

  @override
  Future<void> serviceStarted(IpfsBackground mode) async {
    WidgetsFlutterBinding.ensureInitialized();
    _lifecycle ??= AppLifecycleListener(
        onPause: () => unawaited(IpfsService.appInBackground()));
    if (mode != IpfsBackground.foregroundService) {
      await serviceStopped(); // a restart in the other mode
      return;
    }
    // Android 12+ only starts a foreground service from the foreground: it
    // starts with the service and lasts until it stops. A restart after a
    // crash (onStop, possibly in the background) finds it still running.
    if (_foreground) return;
    await _channel.invokeMethod<void>('startForeground', notification._toMap());
    _foreground = true;
  }

  @override
  Future<void> serviceStopped() async {
    if (!_foreground) return;
    _foreground = false;
    await _channel.invokeMethod<void>('stopForeground');
  }
}

/// The importance of the notification channel (Android 8+). Android fixes it
/// when the channel is first created: to change it, use another [channelId].
enum IpfsNotificationImportance {
  min(1),
  low(2),
  normal(3),
  high(4);

  const IpfsNotificationImportance(this.value);

  /// The `NotificationManager.IMPORTANCE_*` value.
  final int value;
}

/// The notification of the Android foreground service that keeps the app in
/// the background ([IpfsFfiFlutter.notification]). Android requires one; the
/// app decides what it says and looks like.
final class IpfsNotification {
  const IpfsNotification({
    this.title = 'IPFS',
    this.text = 'IPFS node running',
    this.subText,
    this.icon,
    this.channelId = 'ipfs_ffi',
    this.channelName = 'IPFS',
    this.channelDescription,
    this.importance = IpfsNotificationImportance.low,
    this.tapOpensApp = true,
    this.showWhen = false,
    this.extras = const {},
  });

  final String title;
  final String text;

  /// The small line next to the app name, if any.
  final String? subText;

  /// The small icon: the name of a drawable (or mipmap) of the app, such as
  /// `'ic_stat_ipfs'` for `res/drawable/ic_stat_ipfs.xml`; null uses the app
  /// icon. Android draws it as a white silhouette.
  final String? icon;

  final String channelId;

  /// The channel name the user sees in the app's notification settings.
  final String channelName;
  final String? channelDescription;
  final IpfsNotificationImportance importance;

  /// Whether tapping the notification opens the app.
  final bool tapOpensApp;

  /// Whether the notification shows the time it was posted.
  final bool showWhen;

  /// Free strings for a native `NotificationFactory` (the `"extras"` Bundle).
  final Map<String, String> extras;

  /// A copy with the given fields replaced.
  IpfsNotification copyWith({
    String? title,
    String? text,
    String? subText,
    Map<String, String>? extras,
  }) =>
      IpfsNotification(
        title: title ?? this.title,
        text: text ?? this.text,
        subText: subText ?? this.subText,
        icon: icon,
        channelId: channelId,
        channelName: channelName,
        channelDescription: channelDescription,
        importance: importance,
        tapOpensApp: tapOpensApp,
        showWhen: showWhen,
        extras: extras ?? this.extras,
      );

  Map<String, Object> _toMap() => {
        'title': title,
        'text': text,
        if (subText != null) 'subText': subText!,
        if (icon != null) 'icon': icon!,
        'channelId': channelId,
        'channelName': channelName,
        if (channelDescription != null)
          'channelDescription': channelDescription!,
        'importance': importance.value,
        'tapOpensApp': tapOpensApp,
        'showWhen': showWhen,
        'extras': extras,
      };
}
