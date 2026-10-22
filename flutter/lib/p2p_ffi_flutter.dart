/// Android side of `p2p_ffi`. Flutter registers it as
/// `P2pService.platform` when the app starts; there is nothing to call.
///
/// While the service runs, it follows `P2pService.background` (read when the
/// service starts):
/// - `P2pBackground.stop` (default): when the app goes to the background,
///   the service stops and `onStop` gets `P2pStopReason.background`;
/// - `P2pBackground.foregroundService`: an Android foreground service keeps
///   the app, and the service, running in the background. Android requires
///   a notification for it; the app builds it: [P2pFfiFlutter.notification]
///   (an [P2pNotification]: title, text, icon, channel...), updated while
///   it runs with [P2pFfiFlutter.updateNotification], or, for full control,
///   a native `P2pForegroundService.setNotificationFactory` (README).
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:p2p_ffi/p2p_ffi.dart';

/// The Android [P2pPlatform].
final class P2pFfiFlutter implements P2pPlatform {
  P2pFfiFlutter._();

  /// Called by Flutter when the app starts.
  static void registerWith() => P2pService.platform = P2pFfiFlutter._();

  /// The foreground service notification, read when the service starts.
  static P2pNotification notification = const P2pNotification();

  /// Replaces [notification] and, while the foreground service runs, the
  /// notification it shows (allowed from the background).
  static Future<void> updateNotification(P2pNotification n) async {
    notification = n;
    final p = P2pService.platform;
    if (p is P2pFfiFlutter && p._foreground) {
      await _channel.invokeMethod<void>('updateNotification', n._toMap());
    }
  }

  /// Asks for the notification permission (Android 13+), which the
  /// foreground service notification needs to be visible; without it the
  /// service still runs, with the notification hidden. Shows the system
  /// dialog when needed. Returns true when notifications are allowed (or
  /// Android is older than 13), false when denied or when there is no
  /// Activity to ask from. Call it from the foreground before starting
  /// with `P2pBackground.foregroundService`.
  static Future<bool> requestNotificationPermission() async =>
      await _channel.invokeMethod<bool>('requestNotificationPermission') ??
      false;

  static const _channel = MethodChannel('p2p_ffi_flutter');
  AppLifecycleListener? _lifecycle;
  var _foreground = false;

  @override
  Future<void> serviceStarted(P2pBackground mode) async {
    WidgetsFlutterBinding.ensureInitialized();
    _lifecycle ??= AppLifecycleListener(
        onPause: () => unawaited(P2pService.appInBackground()));
    if (mode != P2pBackground.foregroundService) {
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
enum P2pNotificationImportance {
  min(1),
  low(2),
  normal(3),
  high(4);

  const P2pNotificationImportance(this.value);

  /// The `NotificationManager.IMPORTANCE_*` value.
  final int value;
}

/// The notification of the Android foreground service that keeps the app in
/// the background ([P2pFfiFlutter.notification]). Android requires one; the
/// app decides what it says and looks like.
final class P2pNotification {
  const P2pNotification({
    this.title = 'IPFS',
    this.text = 'IPFS node running',
    this.subText,
    this.icon,
    this.channelId = 'p2p_ffi',
    this.channelName = 'IPFS',
    this.channelDescription,
    this.importance = P2pNotificationImportance.low,
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
  final P2pNotificationImportance importance;

  /// Whether tapping the notification opens the app.
  final bool tapOpensApp;

  /// Whether the notification shows the time it was posted.
  final bool showWhen;

  /// Free strings for a native `NotificationFactory` (the `"extras"` Bundle).
  final Map<String, String> extras;

  /// A copy with the given fields replaced.
  P2pNotification copyWith({
    String? title,
    String? text,
    String? subText,
    Map<String, String>? extras,
  }) =>
      P2pNotification(
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
