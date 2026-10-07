// Programa inteiro da rede FFI (E1), rodado por `test/net_ffi_test.dart` em
// subprocesso na VM (`dart run`) e compilado AOT (`dart compile exe`): poller
// (prazo, leitura, interesse armado sem ninguém esperando), connect/accept
// TCP pelo FFI e a ponte para o `dart:io`. Termina sem `exit()`: a VM tem de
// encerrar sozinha com o poller vivo.
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:golib_dart/src/net/sys/common.dart';
import 'package:golib_dart/src/net/sys/ffi/vm.dart';
import 'package:golib_dart/src/sysffi/sysffi.dart' as sf;

Future<void> main() async {
  // Par Unix: prazo vencendo e leitura acordada pelo poller.
  final sv = sf.libcAlloc<Int32>(2);
  final r = sf.socketpair(
    sf.AF_UNIX,
    sf.SOCK_STREAM | sf.SOCK_NONBLOCK | sf.SOCK_CLOEXEC,
    0,
    sv,
  );
  if (r < 0) throw FfiErrno('socketpair', -r);
  final a = FfiFd.adopt(sv[0]), b = FfiFd.adopt(sv[1]);
  sf.libcAlloc.free(sv);
  a.readDeadline = DateTime.now().add(const Duration(milliseconds: 30));
  try {
    await a.waitRead();
    print('prazo: não venceu');
  } on SysTimeout catch (e) {
    print('prazo: $e');
  }
  a.readDeadline = null;
  final buf = Uint8List(16);
  final pending = a.read(buf);
  await Future<void>.delayed(const Duration(milliseconds: 10));
  await b.write(Uint8List.fromList(utf8.encode('ping')));
  print('leitura: ${utf8.decode(buf.sublist(0, await pending))}');

  // TCP pelo FFI: listen, connect não bloqueante, accept.
  final l = FfiFd.socket(sf.AF_INET, sf.SOCK_STREAM);
  final sa = sf.libcAlloc<Uint8>(sf.sockaddrStorageSize);
  final lo = sf.Sockaddr.inet(Uint8List.fromList([127, 0, 0, 1]), 0);
  if (sf.bind(l.fd, sa, sf.encodeSockaddr(lo, sa)) < 0 ||
      sf.listen(l.fd, 8) < 0) {
    throw StateError('listen');
  }
  sf.libcAlloc.free(sa);
  final port = l.localAddr()!.port;
  final c = FfiFd.socket(sf.AF_INET, sf.SOCK_STREAM);
  final accepted = l.accept();
  await c.connect(sf.Sockaddr.inet(lo.ip, port));
  final (srv, peer) = await accepted;
  print(
    'accept: par ${peer.ip.join('.')} porta igual ${peer.port == c.localAddr()!.port}',
  );

  // Ponte: o cliente vira `RawSocket` do `dart:io`.
  final raw = await ffiToRawSocket(c);
  print(
    'ponte: fd do FFI fechado ${c.isClosed}, remoto ${raw.remoteAddress.address}:${raw.remotePort == port}',
  );
  raw.write(utf8.encode('olá'));
  final got = Uint8List(16);
  final n = await srv.read(got);
  print('dart:io → FFI: ${utf8.decode(got.sublist(0, n))}');
  await srv.write(Uint8List.fromList(utf8.encode('eco')));
  final back = Completer<String>();
  raw.listen((ev) {
    if (ev == RawSocketEvent.read && !back.isCompleted) {
      back.complete(utf8.decode(raw.read()!));
    }
  });
  print('FFI → dart:io: ${await back.future}');
  await raw.close();
  srv.close();
  l.close();

  // Interesse armado sem ninguém esperando: não segura a VM.
  final cancel = Completer<void>();
  final w = a.waitRead(cancel: cancel.future);
  cancel.complete();
  try {
    await w;
  } on SysCanceled catch (e) {
    print('cancelado: $e');
  }
  b.close();
  print('fim');
}
