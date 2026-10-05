/// O `/etc/resolv.conf` do resolvedor puro do Go: servidores, busca e
/// opções, e a ordem dos nomes a tentar. Puro Dart.
library;

import 'dart:typed_data';

/// O `/etc/resolv.conf`, com os padrões do Go (`dnsconfig_unix.go`):
/// servidores `127.0.0.1:53` e `[::1]:53`, `ndots:1`, `timeout:5`,
/// `attempts:2`.
final class ResolvConf {
  ResolvConf({
    required this.servers,
    this.search = const [],
    this.ndots = 1,
    this.timeout = const Duration(seconds: 5),
    this.attempts = 2,
  });

  /// `(ip, porta)` de cada `nameserver`.
  final List<(Uint8List, int)> servers;
  final List<String> search;
  final int ndots;
  final Duration timeout;
  final int attempts;

  /// Lê o texto do arquivo (`null`: arquivo ausente → padrões).
  static ResolvConf parse(
    String? text, {
    required Uint8List? Function(String) parseIp,
  }) {
    final servers = <(Uint8List, int)>[];
    var search = <String>[];
    var ndots = 1, attempts = 2;
    var timeout = const Duration(seconds: 5);
    for (final raw in (text ?? '').split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith(';')) {
        continue;
      }
      final f = line.split(RegExp(r'\s+'));
      switch (f[0]) {
        case 'nameserver' when f.length > 1 && servers.length < 3:
          final ip = parseIp(f[1].split('%').first);
          if (ip != null) servers.add((ip, 53));
        case 'domain' when f.length > 1:
          search = [_rooted(f[1])];
        case 'search':
          search = [for (final d in f.skip(1)) _rooted(d)];
        case 'options':
          for (final o in f.skip(1)) {
            final kv = o.split(':');
            final n = kv.length > 1 ? int.tryParse(kv[1]) : null;
            if (n == null) continue;
            switch (kv[0]) {
              case 'ndots':
                ndots = n.clamp(0, 15);
              case 'timeout':
                timeout = Duration(seconds: n < 1 ? 1 : n);
              case 'attempts':
                attempts = n < 1 ? 1 : n;
            }
          }
      }
    }
    if (servers.isEmpty) {
      servers
        ..add((Uint8List.fromList([127, 0, 0, 1]), 53))
        ..add((Uint8List(16)..[15] = 1, 53));
    }
    return ResolvConf(
      servers: servers,
      search: search,
      ndots: ndots,
      timeout: timeout,
      attempts: attempts,
    );
  }

  static String _rooted(String d) => d.endsWith('.') ? d : '$d.';

  /// Nomes a tentar, na ordem do `dnsConfig.nameList` do Go.
  List<String> nameList(String name) {
    if (name.endsWith('.')) return [name];
    final dots = '.'.allMatches(name).length;
    final rooted = '$name.';
    final withSuffix = [for (final s in search) '$name.$s'];
    return dots >= ndots ? [rooted, ...withSuffix] : [...withSuffix, rooted];
  }
}
