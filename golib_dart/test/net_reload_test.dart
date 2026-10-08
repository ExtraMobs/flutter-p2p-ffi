// Recarga do resolv.conf, do nsswitch.conf e do hosts pelo mtime, como o
// `resolverConfig.tryUpdate`, o `nsswitchConfig.tryUpdate` e o `readHosts`
// do Go: conferidos no máximo a cada 5 s, relidos só se o `stat` mudou (no
// hosts, mtime e tamanho), e o resolv.conf com `no-reload` nunca mais. Os
// caminhos vão para arquivos temporários, como o `hostsFilePath` dos testes
// do Go. Arquivo próprio: o cache é global ao isolate.
@TestOn('vm')
library;

import 'dart:io';

import 'package:golib_dart/context.dart' as context;
import 'package:golib_dart/errors.dart' as errors;
import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:golib_dart/net.dart' as net;
import 'package:golib_dart/src/net/sys/sys.dart' as sys;
import 'package:test/test.dart';

void main() {
  test('mtime decide a recarga', () async {
    final tmp = Directory.systemTemp.createTempSync('golib_reload_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final hosts = File('${tmp.path}/hosts');
    final nss = File('${tmp.path}/nsswitch.conf');
    final resolv = File('${tmp.path}/resolv.conf');
    sys.sysHostsPath = hosts.path;
    sys.sysNssPath = nss.path;
    sys.sysResolvConfPath = resolv.path;

    final t0 = DateTime(2024, 1, 1);
    void write(File f, String s, DateTime mtime) {
      f.writeAsStringSync(s);
      f.setLastModifiedSync(mtime);
    }

    String? dialed;
    final r = net.Resolver(
      preferGo: true,
      dial: (ctx, network, address) async {
        dialed = address.toString();
        return (null, errors.new$(Golang.String.fromDart('refused')));
      },
    );
    Future<String> state() async {
      dialed = null;
      final (a, err) = await r.lookupHost(
        context.background(),
        Golang.String.fromDart('h.test'),
      );
      final h = err == null ? a.items.join(',') : 'erro';
      dialed = null;
      await r.lookupHost(
        context.background(),
        Golang.String.fromDart('x.test'),
      );
      return 'h=$h dns=$dialed';
    }

    const wait = Duration(milliseconds: 5100);

    write(hosts, '10.0.0.1 h.test\n', t0);
    write(nss, 'hosts: files dns\n', t0);
    write(resolv, 'nameserver 192.0.2.1\n', t0);
    expect(await state(), 'h=10.0.0.1 dns=192.0.2.1:53');

    // Conteúdo novo com o mesmo mtime (e o hosts do mesmo tamanho): nem
    // antes nem depois dos 5 s o Go relê.
    write(hosts, '10.0.0.2 h.test\n', t0);
    write(nss, 'hosts: dns\n', t0);
    write(resolv, 'nameserver 192.0.2.2\n', t0);
    expect(await state(), 'h=10.0.0.1 dns=192.0.2.1:53');
    await Future<void>.delayed(wait);
    expect(await state(), 'h=10.0.0.1 dns=192.0.2.1:53');

    // mtime novo: relido depois dos 5 s.
    final t1 = t0.add(const Duration(hours: 1));
    write(hosts, '10.0.0.3 h.test\n', t1);
    write(nss, 'hosts: files dns\n', t1);
    write(resolv, 'nameserver 192.0.2.3\noptions no-reload\n', t1);
    expect(await state(), 'h=10.0.0.1 dns=192.0.2.1:53');
    await Future<void>.delayed(wait);
    expect(await state(), 'h=10.0.0.3 dns=192.0.2.3:53');

    // `no-reload`: o resolv.conf fica; o nsswitch.conf (só DNS) é relido.
    final t2 = t1.add(const Duration(hours: 1));
    write(nss, 'hosts: dns\n', t2);
    write(resolv, 'nameserver 192.0.2.4\n', t2);
    await Future<void>.delayed(wait);
    expect(await state(), 'h=erro dns=192.0.2.3:53');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
