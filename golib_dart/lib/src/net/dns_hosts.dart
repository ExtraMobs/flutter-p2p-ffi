part of '../../net.dart';

// O `/etc/hosts` (`hosts.go`: conferido no máximo a cada 5 s, relido se o
// mtime ou o tamanho mudou) e o
// `/etc/services` (`port_unix.go`, lido uma vez) do resolvedor puro do Go.

// ------------------------------------------------------------ /etc/hosts

typedef _ByName = ({List<String> addrs, String canonical});

Map<String, _ByName> _hostsByName = const {};
Map<String, List<String>> _hostsByAddr = const {};
DateTime _hostsExpire = DateTime.fromMillisecondsSinceEpoch(0);
String _hostsPath = '';
(int, int)? _hostsStat;

/// `absDomainName`: nome com ponto ganha o ponto final.
String _absDomainName(String s) =>
    s.contains('.') && !s.endsWith('.') ? '$s.' : s;

/// `parseLiteralIP`: a forma canônica do IP, ou vazio.
String _parseLiteralIP(String addr) {
  final (ip, err) = netip.parseAddr(_gs(addr));
  return err != null ? '' : ip.string().toString();
}

/// `readHosts()`.
void _readHosts() {
  final now = DateTime.now();
  final hp = sys.sysHostsPath;
  if (now.isBefore(_hostsExpire) &&
      _hostsPath == hp &&
      _hostsByName.isNotEmpty) {
    return;
  }
  final st = sys.sysStatFile(hp);
  if (st != null && _hostsPath == hp && st == _hostsStat) {
    _hostsExpire = now.add(_cacheMaxAge);
    return;
  }
  final hs = <String, _ByName>{};
  final is$ = <String, List<String>>{};
  for (var line in _readLines(hp) ?? const <String>[]) {
    final hash = line.indexOf('#');
    if (hash >= 0) line = line.substring(0, hash);
    final f = _fields(line);
    if (f.length < 2) continue;
    final addr = _parseLiteralIP(f[0]);
    if (addr.isEmpty) continue;
    var canonical = '';
    for (var i = 1; i < f.length; i++) {
      final name = _absDomainName(f[i]);
      final key = _absDomainName(_lowerAscii(f[i]));
      if (i == 1) canonical = key;
      (is$[addr] ??= []).add(name);
      final v = hs[key];
      if (v != null) {
        hs[key] = (addrs: [...v.addrs, addr], canonical: v.canonical);
        continue;
      }
      hs[key] = (addrs: [addr], canonical: canonical);
    }
  }
  _hostsExpire = now.add(_cacheMaxAge);
  _hostsPath = hp;
  _hostsStat = st;
  _hostsByName = hs;
  _hostsByAddr = is$;
}

/// `lookupStaticHost(host)`: (endereços, nome canônico) do `/etc/hosts`.
(List<String>, String) _lookupStaticHost(String host) {
  _readHosts();
  final v = _hostsByName[_absDomainName(_lowerAscii(host))];
  if (v == null) return (const [], '');
  return ([...v.addrs], v.canonical);
}

/// `lookupStaticAddr(addr)`: os nomes do IP no `/etc/hosts`.
List<String> _lookupStaticAddr(String addr) {
  _readHosts();
  addr = _parseLiteralIP(addr);
  if (addr.isEmpty) return const [];
  return [...?_hostsByAddr[addr]];
}

// ------------------------------------------------------------ /etc/services

bool _servicesRead = false;

/// `readServices()`: o `/etc/services` (uma vez) completa a tabela embutida;
/// a porta do arquivo vence.
void _readServices() {
  if (_servicesRead) return;
  _servicesRead = true;
  for (var line in _readLines('/etc/services') ?? const <String>[]) {
    final hash = line.indexOf('#');
    if (hash >= 0) line = line.substring(0, hash);
    final f = _fields(line);
    if (f.length < 2) continue;
    final portnet = f[1];
    final (port, j, ok) = _dtoiS(portnet);
    if (!ok || port <= 0 || j >= portnet.length || portnet[j] != '/') continue;
    final m = _services[portnet.substring(j + 1)] ??= {};
    for (var i = 0; i < f.length; i++) {
      if (i != 1) m[f[i]] = port;
    }
  }
}
