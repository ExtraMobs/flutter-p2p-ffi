part of 'sys_js.dart';

/// Erro do `node:dns` → [SysDnsError] no formato do Go.
SysDnsError _dnsError(String name, JSAny? err, String server) {
  final o = err != null && err.isA<JSObject>() ? err as JSObject : null;
  final code = _str(o?['code']) ?? '';
  switch (code) {
    case 'ENOTFOUND' || 'ENODATA' || 'NOTFOUND' || 'NODATA':
      return SysDnsError.notFound(name, server: server);
    case 'ETIMEOUT' || 'TIMEOUT':
      return SysDnsError(
        name,
        'i/o timeout',
        server: server,
        isTimeout: true,
        isTemporary: true,
      );
    case 'ESERVFAIL' || 'SERVFAIL' || 'EAI_AGAIN':
      return SysDnsError(
        name,
        'server misbehaving',
        server: server,
        isTemporary: true,
      );
    case 'EREFUSED' || 'REFUSED' || 'EFORMERR' || 'EBADRESP':
      return SysDnsError(name, 'server misbehaving', server: server);
  }
  final msg = _str(o?['message']) ?? code;
  return SysDnsError(name, msg, server: server);
}

Future<List<Uint8List>> _lookupIp(String host, String network) async {
  final family = switch (network) {
    'ip4' => 4,
    'ip6' => 6,
    _ => 0,
  };
  final done = Completer<List<Uint8List>>();
  _dns.callMethod<JSAny?>(
    'lookup'.toJS,
    host.toJS,
    _obj({'all': true.toJS, 'family': family.toJS, 'order': 'verbatim'.toJS}),
    (([JSAny? err, JSAny? addrs]) {
      if (err != null) {
        done.completeError(_dnsError(host, err, ''));
        return;
      }
      final out = <Uint8List>[];
      for (final a in (addrs as JSArray<JSObject>).toDart) {
        final ip = parseIpZone(_str(a['address']) ?? '')?.$1;
        if (ip == null) continue;
        if (!out.any((o) => _sameIp(o, ip))) out.add(ip);
      }
      if (out.isEmpty) {
        done.completeError(SysDnsError.notFound(host));
      } else {
        done.complete(out);
      }
    }).toJS,
  );
  return done.future;
}

bool _sameIp(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Future<List<String>> _lookupTxt(String name, SysAddr? server) async {
  var resolver = _dns;
  var serverText = '';
  if (server != null) {
    // Padrões do Go (timeout 5s, 2 tentativas).
    resolver = (_dns['Resolver'] as JSFunction).callAsConstructor<JSObject>(
      _obj({'timeout': 5000.toJS, 'tries': 2.toJS}),
    );
    serverText = server.toString();
    resolver.callMethod<JSAny?>('setServers'.toJS, [serverText.toJS].toJS);
  }
  final done = Completer<List<String>>();
  resolver.callMethod<JSAny?>(
    'resolveTxt'.toJS,
    name.toJS,
    (([JSAny? err, JSAny? records]) {
      if (err != null) {
        done.completeError(_dnsError(name, err, serverText));
        return;
      }
      final out = [
        for (final r in (records as JSArray<JSArray<JSString>>).toDart)
          r.toDart.map((s) => s.toDart).join(),
      ];
      if (out.isEmpty) {
        done.completeError(SysDnsError.notFound(name, server: serverText));
      } else {
        done.complete(out);
      }
    }).toJS,
  );
  return done.future;
}

/// `os.networkInterfaces()` dá endereços, prefixo (`cidr`), MAC e
/// `internal`; no linux, `/sys/class/net` dá índice, MTU, flags e as
/// interfaces sem endereço (como na VM). ⚠️ Fora do linux: índice pela
/// ordem, sem MTU, `up`/`running` para toda interface listada.
Future<List<SysInterface>> _interfaces() async => _interfacesSync();

List<SysInterface> _interfacesSync() {
  final osIfaces = _os.callMethod<JSObject>('networkInterfaces'.toJS);
  final names = _keys(osIfaces);
  final byName = <String, SysInterface>{};
  var i = 0;
  for (final name in names) {
    final list = (osIfaces[name] as JSArray<JSObject>).toDart;
    final addrs = <(Uint8List, int)>[];
    var mac = Uint8List(0);
    var internal = false;
    for (final a in list) {
      final ip = parseIpZone(_str(a['address']) ?? '')?.$1;
      final cidr = _str(a['cidr']);
      final prefix = cidr == null ? null : int.tryParse(cidr.split('/').last);
      if (ip != null) addrs.add((ip, prefix ?? 0));
      internal = internal || _bool(a['internal']);
      final m = _str(a['mac']);
      if (m != null && mac.isEmpty) mac = _parseMac(m);
    }
    byName[name] = SysInterface(
      index: ++i,
      name: name,
      hardwareAddr: mac,
      up: true,
      running: true,
      loopback: internal,
      addrs: addrs,
    );
  }
  if (_platform == 'linux') {
    final sys = linuxSysInterfaces(_readFile, _listDir);
    if (sys != null) {
      for (final s in sys) {
        s.addrs = byName[s.name]?.addrs ?? [];
      }
      return sys;
    }
  }
  return byName.values.toList();
}

List<String> _keys(JSObject o) {
  final object = globalContext['Object'] as JSObject;
  final keys = object.callMethod<JSArray<JSString>>('keys'.toJS, o);
  return [for (final k in keys.toDart) k.toDart];
}

Uint8List _parseMac(String s) {
  final parts = s.split(':');
  final out = Uint8List(parts.length);
  for (var i = 0; i < parts.length; i++) {
    out[i] = int.tryParse(parts[i], radix: 16) ?? 0;
  }
  return out.every((b) => b == 0) ? Uint8List(0) : out;
}
