part of '../../net.dart';

// Configuração do resolvedor puro do Go (`CGO_ENABLED=0`): o
// `/etc/resolv.conf` (`dnsconfig_unix.go`), a ordem de `hosts:` do
// `/etc/nsswitch.conf` (`conf.go`, ramo sem cgo), o `/etc/hosts`
// (`hosts.go`) e o `/etc/services` (`port_unix.go`). Como o Go, o
// resolv.conf e o hosts são relidos no máximo a cada 5 s (⚠️ sem comparar
// o mtime: o Go relê antes se o arquivo mudou e o prazo venceu).

const _cacheMaxAge = Duration(seconds: 5);

/// `dnsConfig`.
final class _DnsConfig {
  List<String> servers = const [];
  List<String> search = const [];
  int ndots = 1;
  Duration timeout = const Duration(seconds: 5);
  int attempts = 2;
  bool rotate = false;
  bool unknownOpt = false;
  bool singleRequest = false;
  bool useTCP = false;
  bool trustAD = false;
  int _soffset = 0;

  /// `serverOffset()`: com `rotate`, 0, 1, 2... a cada consulta.
  int serverOffset() => rotate ? _soffset++ : 0;

  /// `nameList(name)`: os nomes a tentar, em ordem.
  List<String> nameList(String name) {
    final l = name.length;
    final rooted = l > 0 && name.endsWith('.');
    if (l > 254 || l == 254 && !rooted) return const [];
    if (rooted) return _avoidDNS(name) ? const [] : [name];
    final hasNdots = '.'.allMatches(name).length >= ndots;
    final n = '$name.';
    final names = <String>[];
    if (hasNdots && !_avoidDNS(n)) names.add(n);
    for (final suffix in search) {
      final fqdn = n + suffix;
      if (!_avoidDNS(fqdn) && fqdn.length <= 254) names.add(fqdn);
    }
    if (!hasNdots && !_avoidDNS(n)) names.add(n);
    return names;
  }
}

/// `avoidDNS`: vazio e `.onion` (RFC 7686) não vão ao DNS.
bool _avoidDNS(String name) {
  if (name.isEmpty) return true;
  if (name.endsWith('.')) name = name.substring(0, name.length - 1);
  return _hasSuffixFold(name, '.onion');
}

bool _hasSuffixFold(String s, String suffix) =>
    s.length >= suffix.length &&
    _lowerAscii(s.substring(s.length - suffix.length)) == suffix;

String _lowerAscii(String s) {
  final b = StringBuffer();
  for (final c in s.codeUnits) {
    b.writeCharCode(c >= 0x41 && c <= 0x5a ? c + 0x20 : c);
  }
  return b.toString();
}

/// `getFields`: campos separados por espaço, tab, CR ou LF.
List<String> _fields(String s) =>
    s.split(RegExp('[ \r\t\n]')).where((f) => f.isNotEmpty).toList();

/// `dtoi` sobre texto Dart.
(int, int, bool) _dtoiS(String s) => _dtoi(_gs(s));

/// Linhas de um arquivo de texto (sem o `\n`), ou `null` se ele não abre.
List<String>? _readLines(String path) {
  final text = sys.sysReadFile(path);
  if (text == null) return null;
  final lines = text.split('\n');
  if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
  return lines;
}

/// `defaultNS`.
const _defaultNS = ['127.0.0.1:53', '[::1]:53'];

/// `ensureRooted`.
String _ensureRooted(String s) => s.endsWith('.') ? s : '$s.';

/// `dnsDefaultSearch`: o domínio do nome do host.
List<String> _dnsDefaultSearch() {
  final hn = sys.sysHostname();
  final i = hn.indexOf('.');
  if (i >= 0 && i < hn.length - 1) return [_ensureRooted(hn.substring(i + 1))];
  return const [];
}

/// `dnsReadConfig(filename)`.
_DnsConfig _dnsReadConfig(String filename) {
  final conf = _DnsConfig();
  final lines = _readLines(filename);
  if (lines == null) {
    conf
      ..servers = _defaultNS
      ..search = _dnsDefaultSearch();
    return conf;
  }
  final servers = <String>[];
  List<String>? search;
  for (final line in lines) {
    if (line.isNotEmpty && (line[0] == ';' || line[0] == '#')) continue;
    final f = _fields(line);
    if (f.isEmpty) continue;
    switch (f[0]) {
      case 'nameserver':
        if (f.length > 1 && servers.length < 3) {
          final (_, err) = netip.parseAddr(_gs(f[1]));
          if (err == null) {
            servers.add(joinHostPort(_gs(f[1]), _gs('53')).toString());
          }
        }
      case 'domain':
        if (f.length > 1) search = [_ensureRooted(f[1])];
      case 'search':
        search = [
          for (final d in f.skip(1))
            if (_ensureRooted(d) != '.') _ensureRooted(d),
        ];
      case 'options':
        for (final s in f.skip(1)) {
          if (s.startsWith('ndots:')) {
            final (n, _, _) = _dtoiS(s.substring(6));
            conf.ndots = n < 0 ? 0 : (n > 15 ? 15 : n);
          } else if (s.startsWith('timeout:')) {
            final (n, _, _) = _dtoiS(s.substring(8));
            conf.timeout = Duration(seconds: n < 1 ? 1 : n);
          } else if (s.startsWith('attempts:')) {
            final (n, _, _) = _dtoiS(s.substring(9));
            conf.attempts = n < 1 ? 1 : n;
          } else if (s == 'rotate') {
            conf.rotate = true;
          } else if (s == 'single-request' || s == 'single-request-reopen') {
            conf.singleRequest = true;
          } else if (s == 'use-vc' || s == 'usevc' || s == 'tcp') {
            conf.useTCP = true;
          } else if (s == 'trust-ad') {
            conf.trustAD = true;
          } else if (s == 'edns0' || s == 'no-reload') {
            // edns0: o Go sempre usa; no-reload: só muda o recarregamento.
          } else {
            conf.unknownOpt = true;
          }
        }
      case 'lookup':
        break; // OpenBSD
      default:
        conf.unknownOpt = true;
    }
  }
  conf
    ..servers = servers.isEmpty ? _defaultNS : servers
    ..search = (search == null || search.isEmpty)
        ? _dnsDefaultSearch()
        : search;
  return conf;
}

_DnsConfig? _resolvConf;
DateTime _resolvChecked = DateTime.fromMillisecondsSinceEpoch(0);

/// `getSystemDNSConfig()`: o `/etc/resolv.conf`, relido a cada 5 s.
_DnsConfig _systemDNSConfig() {
  final now = DateTime.now();
  var conf = _resolvConf;
  if (conf == null || now.difference(_resolvChecked) >= _cacheMaxAge) {
    conf = _resolvConf = _dnsReadConfig('/etc/resolv.conf');
    _resolvChecked = now;
  }
  return conf;
}

// ------------------------------------------------------------ nsswitch

/// `hostLookupOrder`.
enum _HostLookupOrder { filesDNS, dnsFiles, files, dns }

/// `systemConf().hostLookupOrder(r, host)` sem cgo: o `hosts:` do
/// `/etc/nsswitch.conf` (ausente ou sem `hosts`: arquivos e depois DNS).
_HostLookupOrder _hostLookupOrder() {
  final lines = _readLines('/etc/nsswitch.conf');
  if (lines == null) return _HostLookupOrder.filesDNS;
  final srcs = _nssHosts(lines);
  if (srcs == null || srcs.isEmpty) return _HostLookupOrder.filesDNS;
  var hasDNSSource = false, hasDNSSourceChecked = false;
  var filesSource = false, dnsSource = false;
  String? first;
  for (var i = 0; i < srcs.length; i++) {
    final src = srcs[i];
    if (src == 'files' || src == 'dns') {
      if (src == 'files') {
        filesSource = true;
      } else {
        hasDNSSource = hasDNSSourceChecked = dnsSource = true;
      }
      first ??= src;
      continue;
    }
    if (!hasDNSSourceChecked) {
      hasDNSSourceChecked = true;
      hasDNSSource = srcs.skip(i + 1).contains('dns');
    }
    // Fonte desconhecida, sem `dns` em lugar nenhum: conta como DNS.
    if (!hasDNSSource) {
      dnsSource = true;
      first ??= 'dns';
    }
  }
  if (filesSource && dnsSource) {
    return first == 'files'
        ? _HostLookupOrder.filesDNS
        : _HostLookupOrder.dnsFiles;
  }
  if (filesSource) return _HostLookupOrder.files;
  if (dnsSource) return _HostLookupOrder.dns;
  return _HostLookupOrder.filesDNS;
}

/// As fontes de `hosts:` (`parseNSSConf`); `null` se o arquivo é inválido
/// (o Go cai no padrão, arquivos e DNS).
List<String>? _nssHosts(List<String> lines) {
  List<String>? hosts;
  for (var line in lines) {
    final hash = line.indexOf('#');
    if (hash >= 0) line = line.substring(0, hash);
    line = _trimSpace(line);
    if (line.isEmpty) continue;
    final colon = line.indexOf(':');
    if (colon < 0) return null;
    final db = _trimSpace(line.substring(0, colon));
    var srcs = line.substring(colon + 1);
    final out = <String>[];
    while (true) {
      srcs = _trimSpace(srcs);
      if (srcs.isEmpty) break;
      final sp = srcs.indexOf(' ');
      String src;
      if (sp < 0) {
        src = srcs;
        srcs = '';
      } else {
        src = srcs.substring(0, sp);
        srcs = _trimSpace(srcs.substring(sp + 1));
      }
      if (srcs.startsWith('[')) {
        final close = srcs.indexOf(']');
        if (close < 0 || !_validCriteria(srcs.substring(1, close))) return null;
        srcs = srcs.substring(close + 1);
      }
      out.add(src);
    }
    if (db == 'hosts') (hosts ??= []).addAll(out);
  }
  return hosts ?? const [];
}

/// `parseCriteria` só para validar (`foo=bar !foo=bar`).
bool _validCriteria(String x) {
  for (var f in _fields(x)) {
    if (f.startsWith('!')) f = f.substring(1);
    if (f.length < 3 || !f.contains('=')) return false;
  }
  return true;
}

/// `trimSpace` do `parse.go`: espaço, tab, CR e LF nas pontas.
String _trimSpace(String s) {
  var i = 0, j = s.length;
  bool sp(int c) => c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d;
  while (i < j && sp(s.codeUnitAt(i))) {
    i++;
  }
  while (j > i && sp(s.codeUnitAt(j - 1))) {
    j--;
  }
  return s.substring(i, j);
}
