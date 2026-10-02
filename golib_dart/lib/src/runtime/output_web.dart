import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

@JS('process')
external _Process? get _process;

extension type _Process(JSObject _) implements JSObject {
  external _Stdout? get stdout;
  external JSObject? get env;
  external JSNumber? get pid;
}

extension type _Stdout(JSObject _) implements JSObject {
  external void write(JSUint8Array data);
}

extension type _Stderr(JSObject _) implements JSObject {
  external void write(JSAny data);
}

extension type _ProcessExit(JSObject _) implements JSObject {
  external _Stderr? get stderr;
  external void exit(JSNumber code);
}

final _pending = <int>[];

/// Node: bytes exatos em `process.stdout`. Navegador: `print` por linha
/// completa (o console só aceita texto; bytes inválidos viram U+FFFD).
void writeStdout(List<int> bytes) {
  final out = _process?.stdout;
  if (out != null) {
    out.write(Uint8List.fromList(bytes).toJS);
    return;
  }
  _pending.addAll(bytes);
  var nl = _pending.indexOf(0x0a);
  while (nl >= 0) {
    print(utf8.decode(_pending.sublist(0, nl), allowMalformed: true));
    _pending.removeRange(0, nl + 1);
    nl = _pending.indexOf(0x0a);
  }
}

/// Node: bytes exatos em `process.stderr`; sem Node, o texto (UTF-8 com
/// substituição) por linha completa no console.
void writeStderrBytes(List<int> bytes) {
  final p = _process;
  final err = p == null ? null : _ProcessExit(p).stderr;
  if (err != null) {
    err.write(Uint8List.fromList(bytes).toJS);
  } else {
    writeStdout(bytes);
  }
}

/// Node: `process.env[key]`; sem Node (navegador) não há ambiente: `null`.
String? getEnv(String key) {
  final env = _process?.env;
  if (env == null || !env.has(key)) return null;
  final v = env[key];
  return v.isA<JSString>() ? (v as JSString).toDart : null;
}

/// Node: `process.pid`; sem Node, 0.
int getPid() => _process?.pid?.toDartInt ?? 0;

/// Mensagem em stderr (Node) ou no console.
void writeStderr(String text) {
  final p = _process;
  final err = p == null ? null : _ProcessExit(p).stderr;
  if (err != null) {
    err.write(text.toJS);
  } else {
    print(text);
  }
}

/// Node: `process.exit`; navegador: não há processo, lança.
Never exitProcess(int code) {
  final p = _process;
  if (p != null) _ProcessExit(p).exit(code.toJS);
  throw StateError('exit($code)');
}
