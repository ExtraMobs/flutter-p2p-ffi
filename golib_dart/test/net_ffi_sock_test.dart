// Socket genérico da rede FFI (`src/net/sys/ffi/sock.dart`, etapas E3–E6):
// `sysSocket` e `FfiSock` direto, sem o shim `net` (o `_sock` daqui faz só
// `bind`/`listen`/`connect`; a sequência completa do `socket()` do Go é o
// `_goSocket` do shim) (os fixtures
// `netunixgram`, `netunixpacket`, `netunixmsg` e `netiprawsock` cobrem o
// shim contra o `go run`). Aqui ficam o que o fixture não pode imprimir de
// forma determinística: o fd que chega por SCM_RIGHTS funciona, o nome do
// autobind tem o formato do kernel, o `close` adiado é esperado pelo
// próximo `bind`, e o eco ICMP pelo IP bruto (só com privilégio; sem ele,
// o `EPERM` do Go).
//
// Só linux/amd64 (F3); só loopback e nomes abstratos.
@TestOn('vm && linux')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show AllocatorAlloc, Uint8;
import 'dart:io';
import 'dart:typed_data';

import 'package:golib_dart/src/net/sys/ffi/vm.dart' show FfiFd, FfiSock;
import 'package:golib_dart/src/net/sys/sys.dart';
import 'package:golib_dart/src/sysffi/sysffi.dart' as sf;
import 'package:test/test.dart';

final _tag = '@golib-sock-test-$pid';

SysAddr _u(String name) => SysAddr.unix('$_tag-$name');

/// Socket montado: com [laddr] e sem [raddr], `bind` (e `listen` no
/// fluxo/seqpacket); com [raddr], `connect`.
Future<FfiSock> ffiSocket({
  required int family,
  required int sotype,
  int proto = 0,
  SysAddr? laddr,
  SysAddr? raddr,
}) async {
  await sysClosesSettled();
  final s = sysSocket(family, sotype, proto);
  try {
    if (laddr != null) s.bind(laddr);
    if (raddr != null) {
      await s.connect(raddr);
    } else if (sotype == sf.SOCK_STREAM || sotype == sf.SOCK_SEQPACKET) {
      s.listen(16);
    }
    return s.toSockConn() as FfiSock;
  } catch (_) {
    s.close();
    rethrow;
  }
}

Future<FfiSock> _gram(String name) => ffiSocket(
  family: sf.AF_UNIX,
  sotype: sf.SOCK_DGRAM,
  laddr: name.isEmpty ? SysAddr.unix('') : _u(name),
);

/// `SCM_RIGHTS` com [fd] (o `syscall.UnixRights` do Go).
Uint8List _rights(int fd) {
  final b = Uint8List(24);
  ByteData.sublistView(b)
    ..setUint64(0, 20, Endian.little)
    ..setInt32(8, sf.SOL_SOCKET, Endian.little)
    ..setInt32(12, sf.SCM_RIGHTS, Endian.little)
    ..setInt32(16, fd, Endian.little);
  return b;
}

/// Pedido de eco ICMP com [ident].
Uint8List _echo(int ident, String payload) {
  final m = Uint8List.fromList([
    8,
    0,
    0,
    0,
    ident >> 8,
    ident & 0xff,
    0,
    1,
    ...ascii.encode(payload),
  ]);
  var s = 0;
  for (var i = 0; i + 1 < m.length; i += 2) {
    s += m[i] << 8 | m[i + 1];
  }
  if (m.length.isOdd) s += m.last << 8;
  while (s >> 16 != 0) {
    s = (s & 0xffff) + (s >> 16);
  }
  s = ~s & 0xffff;
  m[2] = s >> 8;
  m[3] = s & 0xff;
  return m;
}

void main() {
  test('unixgram: endereços, remetente sem nome, datagrama vazio', () async {
    final a = await _gram('a');
    addTearDown(a.close);
    expect(a.localAddr?.path, '$_tag-a');
    expect(a.remoteAddr, isNull);
    expect(a.isConnected, isFalse);
    final c = await ffiSocket(
      family: sf.AF_UNIX,
      sotype: sf.SOCK_DGRAM,
      raddr: _u('a'),
    );
    addTearDown(c.close);
    expect(c.localAddr?.path, '@', reason: 'sem nome, como o Go');
    expect(c.remoteAddr?.path, '$_tag-a');
    expect(await c.write(Uint8List(0)), 0);
    final (n, from) = await a.readFrom(Uint8List(8));
    expect((n, from), (0, null));
  });

  test('autobind: nome abstrato de 5 dígitos hexadecimais', () async {
    final s = await _gram('');
    addTearDown(s.close);
    expect(s.localAddr?.path, matches(RegExp(r'^@[0-9a-f]{5}$')));
  });

  test('SCM_RIGHTS: o fd recebido é outro número e funciona', () async {
    final a = await _gram('r1');
    final b = await _gram('r2');
    final (p, q) = await (
      ffiSocket(family: sf.AF_UNIX, sotype: sf.SOCK_DGRAM, laddr: _u('p')),
      ffiSocket(family: sf.AF_UNIX, sotype: sf.SOCK_DGRAM, laddr: _u('q')),
    ).wait;
    addTearDown(() {
      for (final s in [a, b, p, q]) {
        s.close();
      }
    });
    final pfd = p.fd;
    final (n, oobn) = await a.writeMsg(
      ascii.encode('fd'),
      _rights(pfd),
      _u('r2'),
    );
    expect((n, oobn), (2, 24));
    final oob = Uint8List(64);
    final (k, got, flags, from) = await b.readMsg(
      Uint8List(4),
      oob,
      sf.MSG_CMSG_CLOEXEC,
    );
    expect((k, got, from?.path), (2, 24, '$_tag-r1'));
    expect(flags & sf.MSG_CMSG_CLOEXEC, sf.MSG_CMSG_CLOEXEC);
    final nfd = ByteData.sublistView(oob).getInt32(16, Endian.little);
    expect(nfd, isNot(pfd));
    // O fd novo é o mesmo socket `p`: o que ele manda chega com o nome dele.
    final out = FfiFd.adopt(nfd);
    addTearDown(out.close);
    final sa = sf.libcAlloc<Uint8>(sf.sockaddrStorageSize);
    addTearDown(() => sf.libcAlloc.free(sa));
    final len = sf.encodeSockaddr(sf.Sockaddr.unix('$_tag-q'), sa);
    expect(sf.sendto(nfd, ascii.encode('oi'), 0, sa, len), 2);
    final (m, src) = await q.readFrom(Uint8List(4));
    expect((m, src?.path), (2, '$_tag-p'));
  });

  test(
    'close adiado: o próximo bind no mesmo nome espera o close(2)',
    () async {
      final s = await _gram('c');
      final pending = s.readFrom(Uint8List(4));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      s.close();
      await expectLater(pending, throwsA(isA<SysClosed>()));
      final again = await _gram('c');
      again.close();
    },
  );

  test('seqpacket: mensagem vazia é 0 (o EOF é do shim)', () async {
    final l = await ffiSocket(
      family: sf.AF_UNIX,
      sotype: sf.SOCK_SEQPACKET,
      laddr: _u('sp'),
    );
    addTearDown(l.close);
    final acc = l.accept();
    final c = await ffiSocket(
      family: sf.AF_UNIX,
      sotype: sf.SOCK_SEQPACKET,
      raddr: _u('sp'),
    );
    addTearDown(c.close);
    final s = await acc;
    addTearDown(s.close);
    expect(s.remoteAddr?.path, '@');
    await c.write(ascii.encode('abc'));
    await c.write(Uint8List(0));
    final buf = Uint8List(2);
    expect(await s.read(buf), 2, reason: 'excesso descartado');
    expect(await s.read(buf), 0);
  });

  test('erros no vocabulário do Go', () async {
    await expectLater(
      ffiSocket(family: sf.AF_UNIX, sotype: sf.SOCK_DGRAM, raddr: _u('nada')),
      throwsA(
        isA<SysError>().having(
          (e) => '$e',
          'texto',
          'connect: connection refused',
        ),
      ),
    );
    final g = await _gram('e');
    addTearDown(g.close);
    await expectLater(
      g.accept(),
      throwsA(
        isA<SysError>().having(
          (e) => '$e',
          'texto',
          'accept4: operation not supported',
        ),
      ),
    );
    await expectLater(
      ffiSocket(
        family: sf.AF_INET,
        sotype: sf.SOCK_RAW,
        proto: 255,
        laddr: SysAddr(Uint8List(16)..[15] = 1, 0),
      ),
      throwsA(anyOf(isA<SysAddrError>(), isA<SysError>())),
    );
  });

  test('IP bruto: eco ICMP no loopback (ou o EPERM do Go)', () async {
    final SysSockConn s;
    try {
      s = await ffiSocket(
        family: sf.AF_INET,
        sotype: sf.SOCK_RAW,
        proto: sf.IPPROTO_ICMP,
        laddr: SysAddr(Uint8List.fromList([127, 0, 0, 1]), 0),
      );
    } on SysError catch (e) {
      expect('$e', 'socket: operation not permitted');
      return;
    }
    addTearDown(s.close);
    final ident = pid & 0xffff;
    final lo = SysAddr(Uint8List.fromList([127, 0, 0, 1]), 0);
    expect(await s.writeTo(_echo(ident, 'ffi'), lo), 11);
    s.readDeadline = DateTime.now().add(const Duration(seconds: 3));
    final buf = Uint8List(128);
    while (true) {
      final (n, from) = await s.readFrom(buf);
      final hl = (buf[0] & 0x0f) << 2;
      final icmp = Uint8List.sublistView(buf, hl, n);
      if (icmp[0] == 0 && (icmp[4] << 8 | icmp[5]) == ident) {
        expect(from?.ip, [127, 0, 0, 1]);
        expect(buf[0] >> 4, 4, reason: 'o FFI devolve o cabeçalho IPv4');
        expect(ascii.decode(icmp.sublist(8)), 'ffi');
        break;
      }
    }
  });
}
