part of 'sys_js.dart';

// Acesso ao Node por `dart:js_interop_unsafe` (propriedades e métodos por
// nome): os objetos do Node (Socket, Server, dgram.Socket...) são usados por
// poucos métodos cada, e assim o mesmo código serve ao dart2js e ao
// dart2wasm sem uma extension type por classe.

@JS('process')
external JSObject? get _jsProcess;

/// O `process` do Node, se este JS roda sob Node com
/// `process.getBuiltinModule` (Node ≥ 22.3); `null` no navegador.
final JSObject? _node = () {
  final p = _jsProcess;
  if (p == null) return null;
  final versions = p['versions'];
  if (versions == null || !versions.isA<JSObject>()) return null;
  if (!(versions as JSObject).has('node')) return null;
  if (!p.has('getBuiltinModule')) return null;
  return p;
}();

JSObject _module(String name) =>
    _node!.callMethod<JSObject>('getBuiltinModule'.toJS, name.toJS);

final JSObject _net = _module('node:net');
final JSObject _dgram = _module('node:dgram');
final JSObject _dns = _module('node:dns');
final JSObject _os = _module('node:os');
final JSObject _fs = _module('node:fs');

/// `process.platform`.
String get _platform => _str(_node!['platform']) ?? '';

String? _str(JSAny? v) =>
    v != null && v.isA<JSString>() ? (v as JSString).toDart : null;

int? _int(JSAny? v) => v != null && v.isA<JSNumber>()
    ? (v as JSNumber).toDartDouble.toInt()
    : null;

bool _bool(JSAny? v) =>
    v != null && v.isA<JSBoolean>() && (v as JSBoolean).toDart;

/// `emitter.on(event, f)`.
void _on(JSObject emitter, String event, JSFunction f) {
  emitter.callMethod<JSAny?>('on'.toJS, event.toJS, f);
}

/// Objeto JS a partir de pares (só valores já JS).
JSObject _obj(Map<String, JSAny?> fields) {
  final o = JSObject();
  fields.forEach((k, v) => o[k] = v);
  return o;
}

/// Bytes de um `Buffer`/`Uint8Array` do Node, copiados para memória Dart.
Uint8List _bytes(JSAny? v) {
  if (v == null || !v.isA<JSUint8Array>()) return Uint8List(0);
  return Uint8List.fromList((v as JSUint8Array).toDart);
}

/// `ip` em texto do Node (`::ffff:1.2.3.4`, `fe80::1%eth0`) → [SysAddr].
SysAddr _addr(JSAny? address, JSAny? port) {
  final parsed = parseIpZone(_str(address) ?? '');
  return SysAddr(parsed?.$1 ?? Uint8List(0), _int(port) ?? 0, parsed?.$2 ?? '');
}

/// [SysAddr] → host em texto para o Node (mapeado fica `::ffff:`).
String _host(Uint8List ip, String zone) {
  if (ip.isEmpty) return '127.0.0.1';
  final s = ipToSystemString(ip);
  return zone.isEmpty ? s : '$s%$zone';
}

/// Erro do Node (`err.code` já é o nome do errno) → exceção do motor.
SysException _mapNode(JSAny? err, String syscall, {int written = 0}) {
  final o = err != null && err.isA<JSObject>() ? err as JSObject : null;
  var code = _str(o?['code']) ?? 'EOTHER';
  // Escrever depois do `end()` (CloseWrite) ou num socket já destruído pelo
  // par: o EPIPE do Go.
  if (code == 'ERR_STREAM_WRITE_AFTER_END' ||
      code == 'ERR_STREAM_DESTROYED' ||
      code == 'ERR_SOCKET_CLOSED') {
    code = 'EPIPE';
  }
  if (code == 'ENOTSUP') code = 'EOPNOTSUPP';
  if (errnoText.containsKey(code)) {
    return SysError.errno(syscall, code, written: written);
  }
  final msg = _str(o?['message']) ?? '$err';
  return SysError(syscall, 'EOTHER', msg, written: written);
}

/// `listen`/`bind`: a syscall que o Go mostraria.
SysException _mapNodeBind(JSAny? err, String otherwise) {
  final m = _mapNode(err, otherwise);
  if (m is SysError &&
      const {'EADDRINUSE', 'EADDRNOTAVAIL', 'EACCES'}.contains(m.code)) {
    return SysError('bind', m.code, m.message);
  }
  return m;
}

String? _readFile(String path) {
  try {
    return _str(
      _fs.callMethod<JSAny?>('readFileSync'.toJS, path.toJS, 'utf8'.toJS),
    );
  } catch (_) {
    return null;
  }
}

List<String>? _listDir(String path) {
  try {
    final arr = _fs.callMethod<JSArray<JSString>>(
      'readdirSync'.toJS,
      path.toJS,
    );
    return [for (final s in arr.toDart) s.toDart];
  } catch (_) {
    return null;
  }
}
