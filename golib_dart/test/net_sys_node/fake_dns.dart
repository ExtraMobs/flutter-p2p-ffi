// Servidor DNS falso dos cenários (`scenarios.dart`): UDP e TCP na mesma
// porta de 127.0.0.1, sobre o próprio motor, respondendo TXT, NXDOMAIN,
// SERVFAIL, resposta vazia e resposta truncada (para a retomada por TCP).
import 'dart:async';
import 'dart:typed_data';

import 'package:golib_dart/src/net/sys/dns_msg.dart';
import 'package:golib_dart/src/net/sys/sys.dart';

final _lo = Uint8List.fromList([127, 0, 0, 1]);

/// Servidor DNS falso (UDP + TCP na mesma porta) sobre o próprio motor.
final class FakeDns {
  FakeDns(this._udp, this._tcp);

  static Future<FakeDns> start() async {
    final udp = await sysListenUdp(SysAddr(_lo, 0));
    final tcp = await sysListenTcp(SysAddr(_lo, udp.local.port));
    final f = FakeDns(udp, tcp);
    unawaited(f._serveUdp());
    unawaited(f._serveTcp());
    return f;
  }

  final SysUdpConn _udp;
  final SysTcpListener _tcp;

  SysAddr get addr => _udp.local;

  Uint8List? _answer(Uint8List query, {required bool overTcp}) {
    final q = parseDnsQuestion(query);
    if (q == null) return null;
    return switch (q.name) {
      '_dnsaddr.example.test.' => buildDnsResponse(
        q,
        txt: [
          ['dnsaddr=/ip4/1.2.3.4/tcp/4001'],
          ['parte1', 'parte2'],
        ],
      ),
      'big.example.test.' when !overTcp => buildDnsResponse(q, truncated: true),
      'big.example.test.' => buildDnsResponse(
        q,
        txt: [
          for (var i = 0; i < 20; i++) ['registro-$i-${'x' * 60}'],
        ],
      ),
      'nx.example.test.' => buildDnsResponse(q, rcode: dnsRcodeNameError),
      'fail.example.test.' => buildDnsResponse(q, rcode: dnsRcodeServerFailure),
      _ => buildDnsResponse(q),
    };
  }

  Future<void> _serveUdp() async {
    final buf = Uint8List(4096);
    while (true) {
      final int n;
      final SysAddr from;
      try {
        (n, from) = await _udp.readFrom(buf);
      } catch (_) {
        return;
      }
      final r = _answer(Uint8List.fromList(buf.sublist(0, n)), overTcp: false);
      if (r != null) await _udp.writeTo(r, from);
    }
  }

  Future<void> _serveTcp() async {
    while (true) {
      final SysTcpConn c;
      try {
        c = await _tcp.accept();
      } catch (_) {
        return;
      }
      unawaited(() async {
        try {
          while (true) {
            final len = await _readExact(c, 2);
            if (len == null) break;
            final msg = await _readExact(c, (len[0] << 8) | len[1]);
            if (msg == null) break;
            final r = _answer(msg, overTcp: true);
            if (r == null) break;
            await c.write(
              Uint8List.fromList([r.length >> 8, r.length & 0xff, ...r]),
            );
          }
        } catch (_) {
          // conexão do cliente caiu
        }
        c.close();
      }());
    }
  }

  static Future<Uint8List?> _readExact(SysTcpConn c, int n) async {
    final out = BytesBuilder();
    while (out.length < n) {
      final buf = Uint8List(n - out.length);
      final k = await c.read(buf);
      if (k == 0) return null;
      out.add(Uint8List.sublistView(buf, 0, k));
    }
    return out.takeBytes();
  }

  void close() {
    _udp.close();
    _tcp.close();
  }
}
