part of '../../net.dart';

// `dialParallel`/`dialSerial`/`dialSingle` do Go (`dial.go`): com mais de um
// endereço, um por vez com o prazo repartido (`partialDeadline`); na rede
// `tcp` com as duas famílias, o "Happy Eyeballs" (RFC 6555): a família do
// primeiro endereço sai na frente e a outra entra depois de
// `Dialer.FallbackDelay` (300 ms no zero; negativo desliga), ou na hora se a
// primeira falhar. Vence a primeira conexão; as outras são canceladas ou
// fechadas.

/// `Dialer.fallbackDelay()`.
Duration _fallbackDelay(time.Duration d) => d.toInt() > 0
    ? Duration(microseconds: d.toInt() ~/ 1000)
    : const Duration(milliseconds: 300);

/// Um `_Cancel` que dispara junto com [parent] (o `context.WithCancel` de
/// cada corredor).
_Cancel _childCancel(_Cancel parent) {
  final c = _Cancel();
  if (parent.done) {
    c.fire();
  } else {
    parent.future.then((_) => c.fire());
  }
  return c;
}

/// `partialDeadline(now, deadline, addrsRemaining)`: `null` se o prazo já
/// venceu.
DateTime? _partialDeadline(DateTime now, DateTime deadline, int remaining) {
  final left = deadline.difference(now);
  if (left <= Duration.zero) return null;
  var timeout = left ~/ remaining;
  const saneMinimum = Duration(seconds: 2);
  if (timeout < saneMinimum) {
    timeout = left < saneMinimum ? left : saneMinimum;
  }
  return now.add(timeout);
}

/// Estado de um `Dial` (o `sysDialer` do Go).
final class _SysDialer {
  _SysDialer(this.d, this.ctx, this.net, this.deadline);

  final Dialer d;
  final context.Context? ctx;
  final String net;

  /// O prazo do Dial inteiro (`Timeout`, `Deadline` e o do `ctx`).
  final DateTime? deadline;

  /// `dialParallel(ctx, primaries, fallbacks)`.
  Future<(Conn?, GoError?)> dialParallel(
    _Cancel cancel,
    List<sys.SysAddr> primaries,
    List<sys.SysAddr> fallbacks,
  ) async {
    if (fallbacks.isEmpty) return dialSerial(cancel, primaries);
    final done = Completer<(Conn?, GoError?)>();
    final primaryCancel = _childCancel(cancel);
    final fallbackCancel = _childCancel(cancel);
    (Conn?, GoError?)? primary, fallback;
    var fallbackStarted = false;
    Timer? timer;

    void finish((Conn?, GoError?) r) {
      timer?.cancel();
      primaryCancel.fire();
      fallbackCancel.fire();
      done.complete(r);
    }

    void race(bool isPrimary) {
      final ras = isPrimary ? primaries : fallbacks;
      dialSerial(isPrimary ? primaryCancel : fallbackCancel, ras).then((res) {
        if (done.isCompleted) {
          res.$1?.close(); // chegou depois do vencedor
          return;
        }
        if (res.$2 == null) {
          finish(res);
          return;
        }
        if (isPrimary) {
          primary = res;
        } else {
          fallback = res;
        }
        if (primary != null && fallback != null) {
          finish((null, primary!.$2));
          return;
        }
        if (isPrimary && !fallbackStarted) {
          // O primário falhou antes do prazo: o reserva sai na hora.
          timer?.cancel();
          fallbackStarted = true;
          race(false);
        }
      });
    }

    race(true);
    timer = Timer(_fallbackDelay(d.fallbackDelay), () {
      if (done.isCompleted || fallbackStarted) return;
      fallbackStarted = true;
      race(false);
    });
    return done.future;
  }

  /// `dialSerial(ctx, ras)`: um endereço por vez; o erro do primeiro é o
  /// que conta.
  Future<(Conn?, GoError?)> dialSerial(
    _Cancel cancel,
    List<sys.SysAddr> ras,
  ) async {
    GoError? firstErr;
    final la = d.localAddr;
    for (var i = 0; i < ras.length; i++) {
      final ra = ras[i];
      if (cancel.done) {
        final cerr = ctx?.err();
        return (
          null,
          _opError(
            'dial',
            net,
            null,
            _addrFor(net, ra),
            _mapErr(cerr) ?? _errCanceled,
          ),
        );
      }
      var when = deadline;
      if (when != null) {
        final partial = _partialDeadline(
          DateTime.now().toUtc(),
          when,
          ras.length - i,
        );
        if (partial == null) {
          firstErr ??= _opError(
            'dial',
            net,
            la,
            _addrFor(net, ra),
            _errTimeout,
          );
          break;
        }
        if (partial.isBefore(when)) when = partial;
      }
      final (c, err) = await dialSingle(cancel, ra, when);
      if (err == null) return (c, null);
      firstErr ??= err;
    }
    return (
      null,
      firstErr ?? _opError('dial', net, null, null, _errMissingAddress),
    );
  }

  /// `dialSingle(ctx, ra)`.
  Future<(Conn?, GoError?)> dialSingle(
    _Cancel cancel,
    sys.SysAddr a,
    DateTime? when,
  ) async {
    final la = d.localAddr;
    final ctrl = _dialerCtrl(d);
    try {
      if (net.startsWith('udp') && (sys.sysFfiAvailable || ctrl != null)) {
        // Rede FFI (E7): o socket conectado do Go, com o `Control`.
        final fd = await _udpGo(
          ctx ?? context.background(),
          net,
          la is UDPAddr ? _sysAddrOf(la.ip, la.port.toInt(), la.zone) : null,
          a,
          ctrl,
        );
        final peer = (fd as sys.SysUdpMsg).remote;
        return (
          UDPConn._(fd, net, _udpAddrOf(fd.local), _udpAddrOf(peer ?? a))
              as Conn,
          null,
        );
      }
      if (net.startsWith('tcp') && ctrl != null) {
        final fd = await _dialTcpGo(
          ctx ?? context.background(),
          net,
          la is TCPAddr ? _sysAddrOf(la.ip, la.port.toInt(), la.zone) : null,
          a,
          ctrl,
          deadline: when,
          cancel: cancel.future,
        );
        return (
          _newTCPConn(
            fd,
            net,
            keepAlive: d.keepAlive,
            keepAliveConfig: d.keepAliveConfig,
          ) as Conn,
          null,
        );
      }
      if (net.startsWith('udp')) {
        final local = la is UDPAddr
            ? _sysAddrOf(la.ip, la.port.toInt(), la.zone)
            : sys.SysAddr(a.ip.length == 4 ? Uint8List(4) : Uint8List(16), 0);
        final fd = await sys.sysListenUdp(local);
        return (
          UDPConn._(fd, net, _udpAddrOf(fd.local), _udpAddrOf(a)) as Conn,
          null,
        );
      }
      final local = la is TCPAddr
          ? _sysAddrOf(la.ip, la.port.toInt(), la.zone)
          : null;
      final fd = await sys.sysDialTcp(
        a,
        local: local,
        deadline: when,
        cancel: cancel.future,
      );
      return (
        _newTCPConn(
          fd,
          net,
          keepAlive: d.keepAlive,
          keepAliveConfig: d.keepAliveConfig,
        ) as Conn,
        null,
      );
    } on _GoErr catch (e) {
      // O erro do `Control` (ou de endereço) vai sem embrulho.
      return (null, _opError('dial', net, la, _addrFor(net, a), e.err));
    } on sys.SysCanceled {
      return (
        null,
        _opError('dial', net, null, _addrFor(net, a), _errCanceled),
      );
    } on sys.SysTimeout {
      return (
        null,
        _opError(
          'dial',
          net,
          null,
          _addrFor(net, a),
          cancel.done ? _errCanceled : _errTimeout,
        ),
      );
    } on Object catch (e) {
      return (
        null,
        _opError(
          'dial',
          net,
          la,
          _addrFor(net, a),
          cancel.done ? _errCanceled : _sysError(e),
        ),
      );
    }
  }
}

/// `addrList.partition(isIPv4)`: os da família do primeiro e os outros.
(List<sys.SysAddr>, List<sys.SysAddr>) _partitionByFamily(
  List<sys.SysAddr> addrs,
) {
  bool v4(sys.SysAddr a) => a.ip.length == 4 || _isV4Mapped(a.ip);
  final first = v4(addrs.first);
  return (
    [
      for (final a in addrs)
        if (v4(a) == first) a,
    ],
    [
      for (final a in addrs)
        if (v4(a) != first) a,
    ],
  );
}
