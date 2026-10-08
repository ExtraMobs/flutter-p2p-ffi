// Cenários do motor de rede (`lib/src/net/sys/sys.dart`), independentes de
// plataforma: cada um devolve linhas determinísticas. `net_sys_test.dart`
// roda-os na VM (com as linhas esperadas) e compara a saída de `main.dart`
// compilado para JS e Wasm (Node) com a da VM. Só loopback.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:golib_dart/src/net/sys/sys.dart';
import 'package:golib_dart/src/runtime/output.dart' show getPid;

import 'fake_dns.dart';

final _lo = Uint8List.fromList([127, 0, 0, 1]);
SysAddr _local0() => SysAddr(_lo, 0);
Uint8List _b(String s) => Uint8List.fromList(utf8.encode(s));
DateTime _in(int ms) => DateTime.now().add(Duration(milliseconds: ms));

/// Exceção em uma linha estável.
String describe(Object e) => switch (e) {
  SysError() => 'SysError(${e.syscall}, ${e.code}, ${e.message})',
  SysTimeout() => 'SysTimeout',
  SysClosed() => 'SysClosed',
  SysCanceled() => 'SysCanceled',
  SysDnsError() =>
    'SysDnsError(${e.name}, ${e.message}, notFound=${e.isNotFound}, '
        'timeout=${e.isTimeout}, temporary=${e.isTemporary})',
  _ => 'outro: $e',
};

Future<String> _try(Future<Object?> Function() f) async {
  try {
    return 'ok ${await f()}';
  } catch (e) {
    return describe(e);
  }
}

/// Lê até EOF.
Future<Uint8List> _readAll(SysTcpConn c) async {
  final out = BytesBuilder();
  final buf = Uint8List(64 * 1024);
  while (true) {
    final n = await c.read(buf);
    if (n == 0) return out.takeBytes();
    out.add(Uint8List.sublistView(buf, 0, n));
  }
}

/// Lê exatamente [n] bytes.
Future<String> _readN(SysTcpConn c, int n) async {
  final out = BytesBuilder();
  while (out.length < n) {
    final buf = Uint8List(n - out.length);
    final k = await c.read(buf);
    if (k == 0) break;
    out.add(Uint8List.sublistView(buf, 0, k));
  }
  return utf8.decode(out.takeBytes());
}

/// Listener + par conectado (cliente, aceito).
Future<(SysTcpListener, SysTcpConn, SysTcpConn)> _pair() async {
  final l = await sysListenTcp(_local0());
  final accepted = l.accept();
  final c = await sysDialTcp(l.local);
  return (l, c, await accepted);
}

String _ip(SysAddr a) => a.ip.isEmpty ? '<vazio>' : ipToString(a.ip);

/// Caminho de socket Unix só deste processo (o pid nunca é impresso).
String _sock(String tag) => '/tmp/g2d-sys-${getPid()}-$tag.sock';

final scenarios = <String, Future<List<String>> Function()>{
  'tcp_echo': () async {
    final out = <String>[];
    final l = await sysListenTcp(_local0());
    out.add('listener ${_ip(l.local)} porta>0=${l.local.port > 0}');
    final served = () async {
      final s = await l.accept();
      final data = await _readAll(s);
      await s.write(data);
      s.close();
      return s;
    }();
    final c = await sysDialTcp(l.local);
    out
      ..add('remote=listener ${c.remote == l.local}')
      ..add('local ${_ip(c.local)} porta>0=${c.local.port > 0}');
    await c.write(_b('hello, '));
    await c.write(_b('world'));
    c.closeWrite();
    out.add('eco ${utf8.decode(await _readAll(c))}');
    out.add('EOF de novo ${await c.read(Uint8List(8))}');
    final s = await served;
    out
      ..add('aceito.remote=cliente.local ${s.remote == c.local}')
      ..add('aceito.local=cliente.remote ${s.local == c.remote}');
    c.close();
    l.close();
    return out;
  },

  'connection_refused': () async {
    final l = await sysListenTcp(_local0());
    final addr = l.local;
    l.close();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return [await _try(() => sysDialTcp(addr))];
  },

  'dial_deadline_past': () async => [
    await _try(
      () => sysDialTcp(
        SysAddr(_lo, 9),
        deadline: DateTime.now().subtract(const Duration(seconds: 1)),
      ),
    ),
  ],

  'read_deadline': () async {
    final (l, c, s) = await _pair();
    final out = <String>[];
    c.readDeadline = _in(50);
    final t0 = DateTime.now();
    out.add(await _try(() => c.read(Uint8List(4))));
    final waited = DateTime.now().difference(t0).inMilliseconds;
    out.add('esperou>=40ms ${waited >= 40}');
    // Vencido continua vencido até mudar.
    out.add(await _try(() => c.read(Uint8List(4))));
    // Prazo no passado: na hora, mesmo com dado esperando.
    await s.write(_b('abc'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    c.readDeadline = DateTime.now().subtract(const Duration(seconds: 1));
    out.add(await _try(() => c.read(Uint8List(4))));
    // Sem prazo: a conexão segue usável e o dado não se perdeu.
    c.readDeadline = null;
    out.add('lido ${await _readN(c, 3)}');
    c.close();
    s.close();
    l.close();
    return out;
  },

  'deadline_changed_while_pending': () async {
    final (l, c, s) = await _pair();
    final out = <String>[];
    c.readDeadline = _in(10000);
    final pending = _try(() => c.read(Uint8List(4)));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final t0 = DateTime.now();
    c.readDeadline = _in(30);
    out.add(await pending);
    final waited = DateTime.now().difference(t0).inMilliseconds;
    out.add('rápido ${waited < 2000}');
    // Estender o prazo de uma leitura pendente também vale.
    c.readDeadline = _in(30);
    final pending2 = _try(() => c.read(Uint8List(4)));
    c.readDeadline = null;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await s.write(_b('ok!!'));
    out.add(await pending2);
    c.close();
    s.close();
    l.close();
    return out;
  },

  'close_while_pending': () async {
    final (l, c, s) = await _pair();
    final out = <String>[];
    final pending = _try(() => c.read(Uint8List(4)));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    c.close();
    out
      ..add('leitura pendente: ${await pending}')
      ..add('nova leitura: ${await _try(() => c.read(Uint8List(4)))}')
      ..add('escrita: ${await _try(() => c.write(_b('x')))}');
    c.close(); // idempotente
    out.add('par lê EOF: ${await s.read(Uint8List(4))}');
    s.close();
    l.close();
    return out;
  },

  'big_write_slow_reader': () async {
    final (l, c, s) = await _pair();
    const total = 4 * 1024 * 1024;
    final data = Uint8List(total);
    for (var i = 0; i < total; i++) {
      data[i] = (i * 31 + 7) & 0xff;
    }
    final reader = () async {
      var got = 0, sum = 0, round = 0;
      final buf = Uint8List(16 * 1024);
      while (true) {
        // Começa devagar para a escrita ter de esperar o par.
        if (round++ < 20) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        final n = await s.read(buf);
        if (n == 0) break;
        for (var i = 0; i < n; i++) {
          sum = (sum + buf[i] * ((got + i) % 251 + 1)) % 1000000007;
        }
        got += n;
      }
      return (got, sum);
    }();
    final n = await c.write(data);
    c.closeWrite();
    var want = 0;
    for (var i = 0; i < total; i++) {
      want = (want + data[i] * (i % 251 + 1)) % 1000000007;
    }
    final (got, sum) = await reader;
    c.close();
    s.close();
    l.close();
    return ['escrito $n', 'recebido $got', 'soma confere ${sum == want}'];
  },

  'close_write_half_open': () async {
    final (l, c, s) = await _pair();
    await c.write(_b('pergunta'));
    c.closeWrite();
    final q = utf8.decode(await _readAll(s));
    await s.write(_b('resposta'));
    s.close();
    final a = utf8.decode(await _readAll(c));
    c.close();
    l.close();
    return ['par leu "$q" e EOF', 'cliente leu "$a" depois do closeWrite'];
  },

  'close_read': () async {
    final (l, c, s) = await _pair();
    c.closeRead();
    final n = await c.read(Uint8List(4));
    c.close();
    s.close();
    l.close();
    return ['leitura depois do closeRead: $n'];
  },

  'write_after_peer_close': () async {
    final (l, c, s) = await _pair();
    s.close();
    String? got;
    for (var i = 0; i < 50 && got == null; i++) {
      try {
        await c.write(Uint8List(1024));
      } on SysError catch (e) {
        got = '${e.syscall} ${const {'EPIPE', 'ECONNRESET'}.contains(e.code)}';
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    c.close();
    l.close();
    return ['erro de escrita: ${got ?? 'nenhum'}'];
  },

  'accept_deadline_and_close': () async {
    final l = await sysListenTcp(_local0());
    l.deadline = _in(30);
    final out = [await _try(() => l.accept())];
    l.deadline = null;
    final pending = _try(() => l.accept());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    l.close();
    out
      ..add(await pending)
      ..add(await _try(() => l.accept()));
    return out;
  },

  'listen_any': () async {
    final l = await sysListenTcp(SysAddr(Uint8List(0), 0));
    final ip = ipToString(l.local.ip);
    final accepted = l.accept();
    final c = await sysDialTcp(SysAddr(_lo, l.local.port));
    final s = await accepted;
    await c.write(_b('v4'));
    final got = await _readN(s, 2);
    c.close();
    s.close();
    l.close();
    return [
      'escuta em any ${ip == '::' || ip == '0.0.0.0'}',
      'aceitou IPv4: $got',
    ];
  },

  'addr_in_use': () async {
    final l = await sysListenTcp(_local0());
    final out = [await _try(() => sysListenTcp(l.local))];
    l.close();
    final u = await sysListenUdp(_local0());
    out.add(await _try(() => sysListenUdp(u.local)));
    u.close();
    return out;
  },

  'udp': () async {
    final a = await sysListenUdp(_local0());
    final b = await sysListenUdp(_local0());
    final out = <String>[
      'udp local ${_ip(a.local)} porta>0=${a.local.port > 0}',
    ];
    await a.writeTo(_b('ping'), b.local);
    final buf = Uint8List(64);
    var (n, from) = await b.readFrom(buf);
    out.add(
      'b recebeu ${utf8.decode(buf.sublist(0, n))} de a ${from == a.local}',
    );
    await b.writeTo(_b('pong'), from);
    (n, from) = await a.readFrom(buf);
    out.add('a recebeu ${utf8.decode(buf.sublist(0, n))}');
    // Truncamento: o resto do datagrama se perde.
    await a.writeTo(_b('abcdefghij'), b.local);
    await a.writeTo(_b('xyz'), b.local);
    final small = Uint8List(4);
    (n, _) = await b.readFrom(small);
    out.add('truncado ${utf8.decode(small.sublist(0, n))}');
    (n, _) = await b.readFrom(small);
    out.add('seguinte ${utf8.decode(small.sublist(0, n))}');
    b.readDeadline = _in(30);
    out.add(await _try(() => b.readFrom(buf)));
    b.readDeadline = null;
    final pending = _try(() => b.readFrom(buf));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    b.close();
    out.add(await pending);
    a.close();
    return out;
  },

  'lookup_ip': () async {
    final lh = await sysLookupIp('localhost', network: 'ip4');
    final lit = await sysLookupIp('127.0.0.1');
    return [
      'localhost tem 127.0.0.1 ${lh.any((ip) => ipToString(ip) == '127.0.0.1')}',
      'literal ${lit.map(ipToString).join(',')}',
    ];
  },

  'lookup_txt': () async {
    final server = await FakeDns.start();
    final out = <String>[];
    Future<void> q(String name) async {
      try {
        final r = await sysLookupTxt(name, server: server.addr);
        out.add(
          r.length > 3
              ? '$name -> ${r.length} registros, 1º ${r.first.substring(0, 11)}'
              : '$name -> ${r.join(' | ')}',
        );
      } catch (e) {
        out.add('$name -> ${describe(e)}');
      }
    }

    await q('_dnsaddr.example.test');
    await q('big.example.test');
    await q('nx.example.test');
    await q('empty.example.test');
    await q('fail.example.test');
    server.close();
    return out;
  },

  // Sockets Unix de fluxo: caminho em /tmp com o pid (nunca impresso).
  'unix_echo': () async {
    final out = <String>[];
    final path = _sock('echo');
    final l = await sysListenUnix(path);
    out.add('listener é unix ${l.local.isUnix} nome=${l.local.path == path}');
    final served = () async {
      final s = await l.accept();
      out.add('aceito local=${s.local.path == path} remoto=${s.remote.path}');
      final data = await _readAll(s);
      await s.write(data);
      s.closeWrite();
      s.close();
    }();
    final c = await sysDialUnix(path);
    out.add('cliente local=${c.local.path} remoto=${c.remote.path == path}');
    await c.write(_b('olá, unix'));
    c.closeWrite();
    out.add('eco ${utf8.decode(await _readAll(c))}');
    await served;
    c.close();
    l.close();
    sysUnlinkUnix(path);
    out.add(
      'segundo listen no mesmo caminho ${await _try(() async {
        final l2 = await sysListenUnix(path);
        l2.close();
        sysUnlinkUnix(path);
        return 'ok';
      })}',
    );
    return out;
  },

  'unix_errors': () async {
    final path = _sock('err');
    final l = await sysListenUnix(path);
    final out = [
      await _try(() => sysListenUnix(path)),
      await _try(() => sysDialUnix('$path-ausente')),
      await _try(() => sysListenUnix('/tmp/g2d-inexistente/x.sock')),
      await _try(() => sysListenUnix('/tmp/${'a' * 120}')),
      await _try(() => sysDialUnix('/tmp/${'a' * 120}')),
    ];
    l.close();
    sysUnlinkUnix(path);
    out.add(await _try(() => sysDialUnix(path)));
    return out;
  },

  'unix_deadline': () async {
    final path = _sock('dl');
    final l = await sysListenUnix(path);
    l.deadline = _in(-1000);
    final out = [await _try(() => l.accept())];
    l.deadline = null;
    final accepted = l.accept();
    final c = await sysDialUnix(path);
    final s = await accepted;
    c.readDeadline = _in(30);
    out.add(await _try(() => c.read(Uint8List(4))));
    c.readDeadline = null;
    await s.write(_b('abcd'));
    final buf = Uint8List(4);
    out.add('lido ${await _readN(c, 4)} ${buf.length}');
    // EOF do par e prazo vencido: o prazo vence antes do EOF.
    s.closeWrite();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    c.readDeadline = _in(-1000);
    out.add('depois do EOF ${await _try(() => c.read(Uint8List(1)))}');
    c.readDeadline = null;
    out.add('EOF ${await _try(() => c.read(Uint8List(1)))}');
    c.close();
    out.add(await _try(() => c.read(Uint8List(1))));
    s.close();
    l.close();
    sysUnlinkUnix(path);
    return out;
  },

  'interfaces': () async {
    final ifs = await sysInterfaces();
    final lo = ifs.where((i) => i.loopback).toList();
    final first = lo.isEmpty ? null : lo.first;
    final has127 = first?.addrs.any(
      (a) => ipToString(a.$1) == '127.0.0.1' && a.$2 == 8,
    );
    return [
      'tem loopback ${lo.isNotEmpty}',
      'loopback up ${first?.up}',
      'loopback com 127.0.0.1/8 $has127',
      'índices > 0 ${ifs.every((i) => i.index > 0)}',
    ];
  },

  // `stat` do resolvedor (mtime em ms, tamanho), como o do `net` do Go.
  'stat': () async {
    final st = sysStatFile('pubspec.yaml');
    final now = DateTime.now().millisecondsSinceEpoch;
    return [
      'tamanho ${st?.$2 == sysReadFile('pubspec.yaml')?.length}',
      'mtime em ms ${st != null && st.$1 > 1577836800000 && st.$1 <= now}',
      'ausente ${sysStatFile('/nao/existe')}',
    ];
  },
};

/// Roda um cenário com teto de tempo; devolve as linhas (ou o erro).
Future<List<String>> runScenario(String name) async {
  try {
    return await scenarios[name]!().timeout(const Duration(seconds: 20));
  } on TimeoutException {
    return ['TIMEOUT'];
  } catch (e, st) {
    return ['falhou: ${describe(e)}', '$st'];
  }
}
