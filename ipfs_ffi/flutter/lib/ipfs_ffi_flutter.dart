/// Android side of `ipfs_ffi`. Flutter registers it as
/// `IpfsService.platform` when the app starts; there is nothing to call.
///
/// While the service runs, it follows `IpfsService.background` (read when the
/// service starts):
/// - `IpfsBackground.stop` (default): when the app goes to the background,
///   the service stops and `onStop` gets `IpfsStopReason.background`;
/// - `IpfsBackground.foregroundService`: an Android foreground service (with
///   a notification) keeps the app, and the service, running in the
///   background.
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

  /// Title of the foreground service notification.
  static String notificationTitle = 'IPFS';

  /// Text of the foreground service notification.
  static String notificationText = 'IPFS node running';

  static const _channel = MethodChannel('ipfs_ffi_flutter');
  AppLifecycleListener? _lifecycle;
  var _foreground = false;

  @override
  Future<void> serviceStarted(IpfsBackground mode) async {
    WidgetsFlutterBinding.ensureInitialized();
    _lifecycle ??= AppLifecycleListener(
        onPause: () => unawaited(IpfsService.appInBackground()));
    if (mode != IpfsBackground.foregroundService) return;
    // Android 12+ only starts a foreground service from the foreground: it
    // starts with the service and lasts until it stops.
    await _channel.invokeMethod<void>('startForeground',
        {'title': notificationTitle, 'text': notificationText});
    _foreground = true;
  }

  @override
  Future<void> serviceStopped() async {
    if (!_foreground) return;
    _foreground = false;
    await _channel.invokeMethod<void>('stopForeground');
  }
}
