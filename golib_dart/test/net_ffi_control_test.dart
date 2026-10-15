// Rede FFI ligada ao shim `net` (etapas E2/E7 do plano D10): o que não cabe
// num fixture comum às três plataformas (o Node diverge sem ser "não
// suportado"). Os textos esperados vêm do `go run` (Go 1.26.5, linux):
//
//   c, _ := net.Dial("udp", "127.0.0.1:9"); c.Write(...); c.Read(...)
//   → read udp L->127.0.0.1:9: read: connection refused
//   u, _ := net.ListenUDP("udp", nil); u.Write(...)
//   → write udp L: write: destination address required
@TestOn('vm && linux')
library;

import 'package:golib_dart/builtin.dart';
import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:golib_dart/net.dart' as net;
import 'package:golib_dart/syscall.dart' as syscall;
import 'package:golib_dart/time.dart' as time;
import 'package:test/test.dart';

Golang.String _s(String s) => Golang.String.fromDart(s);

const _b = Elem<Golang.Uint8>(1, Golang.Uint8.new, ofInt: Golang.Uint8.from);

Slice<Golang.Uint8> _bytes(String s) =>
    Slice.of([for (final c in s.codeUnits) Golang.Uint8(c)], _b);

String _clean(GoError? e, net.Conn c) =>
    e!.error().toString().replaceAll(c.localAddr()!.string().toString(), 'L');

void main() {
  test('UDP conectado recebe o ECONNREFUSED do ICMP no read', () async {
    final (c, err) = await net.dial(_s('udp'), _s('127.0.0.1:9'));
    expect(err, isNull);
    final (_, werr) = await c!.write$async(_bytes('x'));
    expect(werr, isNull);
    c.setReadDeadline(time.now().add(time.Duration(1000000000)));
    final (_, rerr) = await c.read$async(Slice.make(8, 8, _b));
    expect(
      _clean(rerr, c),
      'read udp L->127.0.0.1:9: read: connection refused',
    );
    c.close();
  });

  test('Write sem destino num UDP não conectado é o write(2) do Go', () async {
    final (u, err) = await net.listenUDP(_s('udp'), null);
    expect(err, isNull);
    final (_, werr) = await u!.write$async(_bytes('x'));
    expect(_clean(werr, u), 'write udp L: write: destination address required');
    u.close();
  });

  test('RawConn.Read com prazo vencido falha antes do f', () async {
    final (u, _) = await net.listenUDP(_s('udp'), null);
    final (raw, rerr) = u!.syscallConn();
    expect(rerr, isNull);
    u.setReadDeadline(time.now().add(time.Duration(-1)));
    var called = false;
    final err = await raw!.read((_) => called = true);
    expect(called, isFalse);
    expect(
      err!.error().toString().replaceAll(
        u.localAddr()!.string().toString(),
        'L',
      ),
      'raw-read udp L: i/o timeout',
    );
    u.close();
  });

  test(
    'descritor virtual: opções pelo dart:io, EBADF depois do Close',
    () async {
      final (ln, _) = await net.listen(_s('tcp'), _s('127.0.0.1:0'));
      final (c, _) = await net.dial(_s('tcp'), ln!.addr$()!.string());
      final (raw, _) = (c as net.TCPConn).syscallConn();
      var fd = Golang.Int(-1);
      raw!.control((f) => fd = Golang.Int.from(f));
      expect(fd.toInt() >= 1 << 30, isTrue);
      expect(
        syscall.setsockoptInt(fd, Golang.Int(1), Golang.Int(9), Golang.Int(0)),
        isNull,
      );
      final (ka, kerr) = syscall.getsockoptInt(
        fd,
        Golang.Int(1),
        Golang.Int(9),
      );
      expect((ka.toInt(), kerr), (0, null));
      c.close();
      final (_, cerr) = syscall.getsockoptInt(fd, Golang.Int(1), Golang.Int(9));
      expect(cerr, syscall.ebadf);
      ln.close();
    },
  );
}
