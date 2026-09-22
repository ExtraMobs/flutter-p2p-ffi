// Port of go-libp2p's `p2p/transport/webtransport/cert_manager.go`: which
// short-lived certificate a WebTransport listener is presenting right now,
// which `/certhash/` values it advertises alongside it, and when it rolls
// over to the next one.
//
// A WebTransport certificate is valid for at most fourteen days, so a
// long-running node has to replace it -- and cannot simply swap it in, since
// peers may be holding a multiaddr that pins the old one. Upstream solves
// this by advertising up to three certhashes at once (the one just retired,
// the current one, and the next one) and by deriving each certificate's
// validity window from a bucket of wall-clock time, so the same node computes
// the same windows again after a restart without persisting anything.
//
// Go keeps `certManager` unexported. Dart has no package-private visibility,
// so it is public here, exactly as `p2p/security/tls/crypto.dart` already
// does for `keyToCertificate`; it is deliberately left out of the package's
// exported API in `transpiled_libp2p.dart`.
import 'dart:async';
import 'dart:typed_data';

import '../../../core/crypto/key_types.dart';
import 'crypto.dart';

/// How long a certificate this node issues is valid for.
///
/// Go: `certValidity` (`transport.go:41`).
const Duration certValidity = Duration(days: 14);

/// Slack for disagreeing clocks: a certificate's `NotBefore` is set this far
/// before its bucket starts, and this side stops using a certificate this
/// long before it expires.
///
/// Go: `clockSkewAllowance` (`cert_manager.go:22`).
const Duration clockSkewAllowance = Duration(hours: 1);

/// The stride between consecutive certificate buckets: [certValidity] less
/// two [clockSkewAllowance]s, written out because Dart has no const
/// arithmetic over [Duration].
///
/// Go: `validityMinusTwoSkew` (`cert_manager.go:23`). Buckets overlap by two
/// skew allowances so a certificate is always still live while the next one
/// has already become valid.
const Duration validityMinusTwoSkew = Duration(days: 14, hours: -2);

/// The canonical start of the bucket [now] falls in, given [offset].
///
/// Go: `getCurrentBucketStartTime` (`cert_manager.go:82-85`). Bucketing the
/// Unix epoch by [validityMinusTwoSkew] is what makes the window -- and so
/// the certificate derived from it -- come out the same after a restart with
/// no stored state at all.
DateTime currentBucketStartTime(DateTime now, Duration offset) {
  final stride = validityMinusTwoSkew.inMilliseconds;
  final bucket =
      (now.toUtc().millisecondsSinceEpoch - offset.inMilliseconds) ~/ stride;
  return DateTime.fromMillisecondsSinceEpoch(
    offset.inMilliseconds + bucket * stride,
    isUtc: true,
  );
}

/// Holds the certificates a WebTransport listener presents, and rolls them
/// over before they expire.
///
/// Go: `certManager` (`cert_manager.go:48-61`).
///
/// One divergence from upstream: `cacheAddrComponent` (`:201-215`) is not
/// here. Its helper, `addrComponentForCert`, lives in this package's
/// multiaddr file, which imports this one, so the listener builds the
/// `/certhash/` components from [certHashes] instead.
class CertManager {
  CertManager._(this._hostKey);

  /// Builds a [CertManager] for [hostKey] and generates its first two
  /// certificates.
  ///
  /// Go: `newCertManager` (`cert_manager.go:63-71`) and `init`
  /// (`cert_manager.go:87-108`). The offset moves each node's bucket
  /// boundaries by a per-key amount, so certificates across the network do
  /// not all roll at the same instant: the first two bytes of the public key
  /// read little-endian, in minutes, modulo [certValidity]
  /// (`cert_manager.go:100`).
  static Future<CertManager> create(PrivKey hostKey) async {
    final pubKeyBytes = hostKey.getPublic().raw();
    final offsetMinutes = pubKeyBytes.length >= 2
        ? pubKeyBytes[0] | (pubKeyBytes[1] << 8)
        : 0;
    final offset = Duration(
      milliseconds:
          Duration(minutes: offsetMinutes).inMilliseconds %
          certValidity.inMilliseconds,
    );

    final manager = CertManager._(hostKey);
    // The certificate has to have been valid for one skew allowance already.
    final start = DateTime.now().toUtc().subtract(clockSkewAllowance);
    final bucketStart = currentBucketStartTime(start, offset);
    manager._next = await generateCert(
      hostKey,
      bucketStart,
      bucketStart.add(certValidity),
    );
    await manager._roll();
    manager._scheduleRoll();
    return manager;
  }

  final PrivKey _hostKey;

  WebtransportCertificate? _last;
  WebtransportCertificate? _current;
  late WebtransportCertificate _next;
  Timer? _timer;
  bool _closed = false;

  /// The certificate the TLS handshake presents right now.
  ///
  /// Go: `GetConfig` (`cert_manager.go:156-160`), which hands back the whole
  /// `tls.Config`; this port has no `tls.Config` to hand back.
  WebtransportCertificate get current => _current!;

  /// The certificate that takes over at the next rollover.
  WebtransportCertificate get next => _next;

  /// The SHA-256 digests of every certificate currently worth accepting: the
  /// one just retired, when there is one, then the current one, then the
  /// next.
  ///
  /// Go: `SerializedCertHashes` (`cert_manager.go:169-177`), minus the
  /// multihash envelope -- callers here want raw digests, and the one place
  /// that needs an envelope builds it itself.
  List<Uint8List> get certHashes => [
    if (_last != null) _last!.sha256,
    _current!.sha256,
    _next.sha256,
  ];

  /// Retires the current certificate, promotes the next one, and generates
  /// the one after it.
  ///
  /// Go: `rollConfig` (`cert_manager.go:110-125`).
  Future<void> _roll() async {
    // This side stops using a certificate one skew allowance before it
    // expires, at which point the next one already has to be valid.
    final nextStart = _next.notAfter.subtract(clockSkewAllowance * 2);
    final upcoming = await generateCert(
      _hostKey,
      nextStart,
      nextStart.add(certValidity),
    );
    _last = _current;
    _current = _next;
    _next = upcoming;
  }

  /// Arms the timer that rolls the certificates over.
  ///
  /// Go: `background` (`cert_manager.go:127-154`), which fires one skew
  /// allowance before the current certificate expires.
  void _scheduleRoll() {
    if (_closed) return;
    final due = _current!.notAfter
        .subtract(clockSkewAllowance)
        .difference(DateTime.now().toUtc());
    _timer = Timer(due.isNegative ? Duration.zero : due, () async {
      if (_closed) return;
      await _roll();
      _scheduleRoll();
    });
  }

  /// Stops the rotation timer.
  ///
  /// Go: `Close` (`cert_manager.go:217-221`).
  void close() {
    _closed = true;
    _timer?.cancel();
    _timer = null;
  }
}
