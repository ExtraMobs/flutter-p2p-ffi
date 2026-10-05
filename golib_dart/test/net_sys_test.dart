// Motor de rede por plataforma (`lib/src/net/sys/`, decisão D4).
//
// - VM: os cenários de `net_sys_node/scenarios.dart` rodam aqui, com as
//   linhas esperadas; mais testes só da VM (IPv6 dual-stack quando há,
//   detector de deadlock, formatos).
// - Node: `net_sys_node/main.dart` compilado com `dart compile js` e
//   `dart compile wasm` roda no `node` e tem de imprimir exatamente o mesmo
//   que na VM (`dart run`).
// - "Navegador": `net_sys_node/browser_main.dart` compilado roda no Node com
//   o `process` escondido (`run_as_browser.mjs`): toda operação falha com
//   `operation not supported`.
//
// Só loopback (127.0.0.1/::1) e servidores locais; nada de rede externa.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:golib_dart/src/net/sys/dns_msg.dart';
import 'package:golib_dart/src/net/sys/resolv_conf.dart';
import 'package:golib_dart/src/net/sys/sys.dart';
import 'package:golib_dart/src/runtime/sched.dart';
import 'package:test/test.dart';

import 'net_sys_node/scenarios.dart';

const _expected = <String, List<String>>{
  'tcp_echo': [
    'listener 127.0.0.1 porta>0=true',
    'remote=listener true',
    'local 127.0.0.1 porta>0=true',
    'eco hello, world',
    'EOF de novo 0',
    'aceito.remote=cliente.local true',
    'aceito.local=cliente.remote true',
  ],
  'connection_refused': ['SysError(connect, ECONNREFUSED, connection refused)'],
  'dial_deadline_past': ['SysTimeout'],
  'read_deadline': [
    'SysTimeout',
    'esperou>=40ms true',
    'SysTimeout',
    'SysTimeout',
    'lido abc',
  ],
  'deadline_changed_while_pending': ['SysTimeout', 'rápido true', 'ok 4'],
  'close_while_pending': [
    'leitura pendente: SysClosed',
    'nova leitura: SysClosed',
    'escrita: SysClosed',
    'par lê EOF: 0',
  ],
  'big_write_slow_reader': [
    'escrito 4194304',
    'recebido 4194304',
    'soma confere true',
  ],
  'close_write_half_open': [
    'par leu "pergunta" e EOF',
    'cliente leu "resposta" depois do closeWrite',
  ],
  'close_read': ['leitura depois do closeRead: 0'],
  'write_after_peer_close': ['erro de escrita: write true'],
  'accept_deadline_and_close': ['SysTimeout', 'SysClosed', 'SysClosed'],
  'listen_any': ['escuta em any true', 'aceitou IPv4: v4'],
  'addr_in_use': [
    'SysError(bind, EADDRINUSE, address already in use)',
    'SysError(bind, EADDRINUSE, address already in use)',
  ],
  'udp': [
    'udp local 127.0.0.1 porta>0=true',
    'b recebeu ping de a true',
    'a recebeu pong',
    'truncado abcd',
    'seguinte xyz',
    'SysTimeout',
    'SysClosed',
  ],
  'lookup_ip': ['localhost tem 127.0.0.1 true', 'literal 127.0.0.1'],
  'lookup_txt': [
    '_dnsaddr.example.test -> dnsaddr=/ip4/1.2.3.4/tcp/4001 | parte1parte2',
    'big.example.test -> 20 registros, 1º registro-0-',
    'nx.example.test -> SysDnsError(nx.example.test, no such host, '
        'notFound=true, timeout=false, temporary=false)',
    'empty.example.test -> SysDnsError(empty.example.test, no such host, '
        'notFound=true, timeout=false, temporary=false)',
    'fail.example.test -> SysDnsError(fail.example.test, server misbehaving, '
        'notFound=false, timeout=false, temporary=true)',
  ],
  'unix_echo': [
    'listener é unix true nome=true',
    'aceito local=true remoto=@',
    'cliente local=@ remoto=true',
    'eco olá, unix',
    'segundo listen no mesmo caminho ok ok',
  ],
  'unix_errors': [
    'SysError(bind, EADDRINUSE, address already in use)',
    'SysError(connect, ENOENT, no such file or directory)',
    'SysError(bind, ENOENT, no such file or directory)',
    'SysError(bind, EINVAL, invalid argument)',
    'SysError(connect, EINVAL, invalid argument)',
    'SysError(connect, ENOENT, no such file or directory)',
  ],
  'unix_deadline': [
    'SysTimeout',
    'SysTimeout',
    'lido abcd 4',
    'depois do EOF SysTimeout',
    'EOF ok 0',
    'SysClosed',
  ],
  'interfaces': [
    'tem loopback true',
    'loopback up true',
    'loopback com 127.0.0.1/8 true',
    'índices > 0 true',
  ],
};

const _browserExpected = '''
suportado false
dial: SysError(socket, EOPNOTSUPP, operation not supported)
listen: SysError(socket, EOPNOTSUPP, operation not supported)
udp: SysError(socket, EOPNOTSUPP, operation not supported)
lookupIp: SysError(lookup, EOPNOTSUPP, operation not supported)
lookupTxt: SysError(lookup, EOPNOTSUPP, operation not supported)
interfaces: SysError(netlink, EOPNOTSUPP, operation not supported)
''';

const _wasmRunner = '''
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
const [mjs, wasm] = process.argv.slice(2);
const mod = await import(pathToFileURL(mjs).href);
const app = await mod.compile(await readFile(wasm));
const instance = await app.instantiate({});
instance.invokeMain();
''';

Future<String> _run(String exe, List<String> args) async {
  final r = await Process.run(exe, args);
  if (r.exitCode != 0) {
    fail('$exe ${args.join(' ')}: ${r.exitCode}\n${r.stdout}\n${r.stderr}');
  }
  return r.stdout as String;
}

bool _hasNode() {
  try {
    return Process.runSync('node', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

Future<bool> _hasIpv6() async {
  try {
    final s = await ServerSocket.bind(InternetAddress.loopbackIPv6, 0);
    await s.close();
    return true;
  } on SocketException {
    return false;
  }
}

void main() {
  group('cenários na VM', () {
    for (final name in scenarios.keys) {
      test(name, () async {
        expect(await runScenario(name), _expected[name]);
      });
    }
    test('toda cena tem linhas esperadas', () {
      expect(_expected.keys.toSet(), scenarios.keys.toSet());
    });
  });

  group('VM', () {
    test('espera de rede segura o detector de deadlock', () async {
      final l = await sysListenTcp(
        SysAddr(Uint8List.fromList([127, 0, 0, 1]), 0),
      );
      final accepted = l.accept();
      final c = await sysDialTcp(l.local);
      final s = await accepted;
      // A única goroutine fica "bloqueada" numa leitura que só termina
      // depois de alguns turnos de eventos: sem `holdEvents`, o runtime
      // acusaria `all goroutines are asleep` e sairia com 2.
      goroutineBlocked();
      Future<void>.delayed(const Duration(milliseconds: 100))
          .then((_) => s.write(Uint8List.fromList([1])));
      final n = await c.read(Uint8List(1));
      goroutineUnblocked();
      expect(n, 1);
      c.close();
      s.close();
      l.close();
    });

    test('IPv6 e dual-stack (se houver IPv6)', () async {
      if (!await _hasIpv6()) {
        markTestSkipped('sem IPv6 neste ambiente');
        return;
      }
      final v6lo = Uint8List(16)..[15] = 1;
      final l = await sysListenTcp(SysAddr(Uint8List(0), 0));
      expect(ipToString(l.local.ip), '::');
      for (final ip in [
        Uint8List.fromList([127, 0, 0, 1]),
        v6lo,
      ]) {
        final accepted = l.accept();
        final c = await sysDialTcp(SysAddr(ip, l.local.port));
        final s = await accepted;
        expect(ipTo4(s.remote.ip) != null, ip.length == 4);
        c.close();
        s.close();
      }
      l.close();
    });

    test('IP em texto', () {
      Uint8List p(String s) => parseIp(s)!;
      expect(ipToString(p('::1')), '::1');
      expect(ipToString(p('fe80::1:2:3:4')), 'fe80::1:2:3:4');
      expect(ipToString(p('2001:db8:0:0:1:0:0:1')), '2001:db8::1:0:0:1');
      expect(ipToString(p('::ffff:10.0.0.1')), '10.0.0.1');
      expect(ipToSystemString(p('::ffff:10.0.0.1')), '::ffff:10.0.0.1');
      expect(ipToString(p('1.2.3.4')), '1.2.3.4');
      expect(parseIp('1.2.3'), isNull);
      expect(parseIp('01.2.3.4'), isNull);
      expect(parseIp('1::2::3'), isNull);
      expect(parseIpZone('fe80::1%eth0')!.$2, 'eth0');
      expect(SysAddr(p('::1'), 80, 'lo').toString(), '[::1%lo]:80');
      expect(SysAddr(p('1.2.3.4'), 80).toString(), '1.2.3.4:80');
    });

    test('resolv.conf e lista de nomes (como o Go)', () {
      final c = ResolvConf.parse(
        'nameserver 10.0.0.1\nsearch a.test b.test\noptions ndots:2 timeout:1 attempts:3\n',
        parseIp: parseIp,
      );
      expect(c.servers.map((s) => ipToString(s.$1)), ['10.0.0.1']);
      expect(c.timeout, const Duration(seconds: 1));
      expect(c.attempts, 3);
      expect(c.nameList('x.y'), ['x.y.a.test.', 'x.y.b.test.', 'x.y.']);
      expect(c.nameList('x.y.z'), ['x.y.z.', 'x.y.z.a.test.', 'x.y.z.b.test.']);
      expect(c.nameList('abs.'), ['abs.']);
      final d = ResolvConf.parse(null, parseIp: parseIp);
      expect(d.servers.map((s) => ipToString(s.$1)), ['127.0.0.1', '::1']);
      expect(d.timeout, const Duration(seconds: 5));
    });

    test('mensagem DNS: consulta e resposta TXT', () {
      final q = buildDnsQuery(0x1234, 'Example.Test', dnsTypeTxt)!;
      final question = parseDnsQuestion(q)!;
      expect(question.id, 0x1234);
      expect(question.name, 'example.test.');
      expect(question.qtype, dnsTypeTxt);
      final r = DnsResponse.parse(
        buildDnsResponse(
          question,
          txt: [
            ['a', 'b'],
            ['ç'],
          ],
        ),
      );
      expect(r.txt, ['ab', 'ç']);
      expect(r.question, 'example.test.');
      expect(buildDnsQuery(1, '${'x' * 64}.test', dnsTypeTxt), isNull);
    });

    test('TXT sem resposta do servidor: i/o timeout', () async {
      // Um UDP que nunca responde: o cliente esgota as tentativas (timeout
      // e attempts do /etc/resolv.conf do sistema).
      final mute = await sysListenUdp(
        SysAddr(Uint8List.fromList([127, 0, 0, 1]), 0),
      );
      try {
        await sysLookupTxt(
          'x.test',
          server: mute.local,
        ).timeout(const Duration(seconds: 50));
        fail('devia falhar');
      } on SysDnsError catch (e) {
        expect(e.isTimeout, isTrue);
        expect(e.isTemporary, isTrue);
        expect(e.message, 'i/o timeout');
        expect(e.toString(), startsWith('lookup x.test on 127.0.0.1:'));
      } finally {
        mute.close();
      }
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('Node', () {
    final node = _hasNode();
    late Directory tmp;
    late String vmOut;
    setUpAll(() async {
      if (!node) return;
      tmp = await Directory.systemTemp.createTemp('golib_net_sys_');
      await File('${tmp.path}/run_wasm.mjs').writeAsString(_wasmRunner);
      vmOut = await _run('dart', ['run', 'test/net_sys_node/main.dart']);
      final lines = LineSplitter.split(vmOut).toList();
      expect(lines.first, 'suportado true');
    });
    tearDownAll(() async {
      if (node) await tmp.delete(recursive: true);
    });

    test('a saída da VM é a esperada', () {
      final want = StringBuffer('suportado true\n');
      for (final MapEntry(:key, :value) in _expected.entries) {
        want.writeln('== $key');
        for (final l in value) {
          want.writeln(l);
        }
      }
      expect(vmOut, want.toString());
    }, skip: node ? false : 'sem node');

    test('JS (dart2js) igual à VM', () async {
      final js = '${tmp.path}/net.js';
      await _run('dart', [
        'compile', 'js', '-O1', '-o', js, 'test/net_sys_node/main.dart', //
      ]);
      expect(await _run('node', [js]), vmOut);
    }, skip: node ? false : 'sem node');

    test('Wasm (dart2wasm) igual à VM', () async {
      final wasm = '${tmp.path}/net.wasm';
      await _run('dart', [
        'compile', 'wasm', '-o', wasm, 'test/net_sys_node/main.dart', //
      ]);
      expect(
        await _run('node', [
          '${tmp.path}/run_wasm.mjs',
          '${tmp.path}/net.mjs',
          wasm,
        ]),
        vmOut,
      );
    }, skip: node ? false : 'sem node');

    test('navegador (JS): operation not supported', () async {
      final js = '${tmp.path}/browser.js';
      await _run('dart', [
        'compile',
        'js',
        '-O1',
        '-o',
        js,
        'test/net_sys_node/browser_main.dart',
      ]);
      expect(
        await _run('node', ['test/net_sys_node/run_as_browser.mjs', 'js', js]),
        _browserExpected.trimLeft(),
      );
    }, skip: node ? false : 'sem node');

    test('navegador (Wasm): operation not supported', () async {
      final wasm = '${tmp.path}/browser.wasm';
      await _run('dart', [
        'compile',
        'wasm',
        '-o',
        wasm,
        'test/net_sys_node/browser_main.dart',
      ]);
      expect(
        await _run('node', [
          'test/net_sys_node/run_as_browser.mjs',
          'wasm',
          '${tmp.path}/browser.mjs',
          wasm,
        ]),
        _browserExpected.trimLeft(),
      );
    }, skip: node ? false : 'sem node');
  });
}
