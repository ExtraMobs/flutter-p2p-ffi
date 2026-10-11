/// Runtime das libraries geradas (go/gen): chama o `IpfsCall` da lib nativa
/// com os argumentos em JSON e decodifica a resposta. Não é API pública.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

/// Erro devolvido pelo Go (o `error` de um `(T, error)`, ou um panic).
class IpfsException implements Exception {
  IpfsException(this.message);

  final String message;

  @override
  String toString() => 'IpfsException: $message';
}

/// Caminho da lib nativa; padrão `native/libipfs.so` ou `native\ipfs.dll`
/// relativo ao diretório atual. Mude antes da primeira chamada.
String ipfsLibraryPath =
    Platform.isWindows ? r'native\ipfs.dll' : 'native/libipfs.so';

typedef _CbNative = Void Function(Int64, Int32, Pointer<Uint8>);
typedef _CallNative = Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Uint8>,
    Int32, Pointer<NativeFunction<_CbNative>>, Int64);
typedef _Call = Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Uint8>, int,
    Pointer<NativeFunction<_CbNative>>, int);

final class _Native {
  _Native(DynamicLibrary l)
      : call = l.lookupFunction<_CallNative, _Call>('IpfsCall'),
        malloc = l.lookupFunction<Pointer<Void> Function(Size),
            Pointer<Void> Function(int)>('GoMalloc'),
        free = l.lookupFunction<Void Function(Pointer<Void>),
            void Function(Pointer<Void>)>('GoFree'),
        finalizer = NativeFinalizer(l.lookup('IpfsHandleFree'));

  final _Call call;
  final Pointer<Void> Function(int) malloc;
  final void Function(Pointer<Void>) free;
  final NativeFinalizer finalizer;

  Pointer<Uint8> cstr(String s) {
    final b = utf8.encode(s);
    final p = malloc(b.length + 1).cast<Uint8>();
    if (p == nullptr) throw IpfsException('GoMalloc falhou');
    p.asTypedList(b.length + 1)
      ..setAll(0, b)
      ..[b.length] = 0;
    return p;
  }

  /// Lê e libera uma string C devolvida pela lib.
  String take(Pointer<Uint8> p) {
    var n = 0;
    while (p[n] != 0) {
      n++;
    }
    final s = utf8.decode(p.asTypedList(n));
    free(p.cast());
    return s;
  }
}

final _native = _Native(DynamicLibrary.open(ipfsLibraryPath));

// Modos do IpfsCall e eventos do callback (go/runtime.go).
const _sync = 0, _async = 1, _streamMode = 2;
const _evValue = 0, _evItem = 1, _evEnd = 2, _evError = 3;

/// Chamadas pendentes desta isolate: Completer ou StreamController, e os
/// argumentos (mantêm os handles vivos até o Go terminar).
final _pending = <int, (Object, List<Object?>)>{};
var _nextId = 0;

final _listener = NativeCallable<_CbNative>.listener(_onEvent)
  ..keepIsolateAlive = false;

void _onEvent(int id, int kind, Pointer<Uint8> data) {
  final text = _native.take(data);
  final (sink, _) = _pending[id]!;
  switch ((kind, sink)) {
    case (_evValue, Completer<Object?> c):
      c.complete(jsonDecode(text));
    case (_evItem, StreamController<Object?> s):
      s.add(jsonDecode(text));
      return;
    case (_evEnd, StreamController<Object?> s):
      s.close();
    case (_evError, Completer<Object?> c):
      c.completeError(IpfsException(text));
    case (_evError, StreamController<Object?> s):
      s
        ..addError(IpfsException(text))
        ..close();
  }
  _pending.remove(id);
  if (_pending.isEmpty) _listener.keepIsolateAlive = false;
}

Pointer<Uint8> _start(String fn, List<Object?> args, int mode, int id) {
  final name = _native.cstr(fn);
  final json = _native.cstr(jsonEncode($enc(args)));
  try {
    return _native.call(name, json, mode, _listener.nativeFunction, id);
  } finally {
    _native
      ..free(name.cast())
      ..free(json.cast());
  }
}

// Mantém os handles dos argumentos vivos durante a chamada síncrona (o
// NativeFinalizer não pode soltá-los enquanto o Go os lê).
// ignore: unused_element
List<Object?>? _keep;

/// Chamada síncrona: bloqueia a isolate até o Go responder.
Object? $callSync(String fn, List<Object?> args) {
  _keep = args;
  try {
    final reply = jsonDecode(_native.take(_start(fn, args, _sync, 0))) as Map;
    if (reply['e'] case final String e) throw IpfsException(e);
    return reply['v'];
  } finally {
    _keep = null;
  }
}

int _register(Object sink, List<Object?> args) {
  final id = ++_nextId;
  _pending[id] = (sink, args);
  _listener.keepIsolateAlive = true;
  return id;
}

/// Chamada assíncrona: o Go roda numa goroutine e responde pelo listener.
Future<Object?> $call(String fn, List<Object?> args) {
  final c = Completer<Object?>();
  _start(fn, args, _async, _register(c, args));
  return c.future;
}

/// Canal do Go: um item por evento, até o Go fechar o canal.
Stream<Object?> $stream(String fn, List<Object?> args) {
  final s = StreamController<Object?>();
  _start(fn, args, _streamMode, _register(s, args));
  return s.stream;
}

/// Objeto que vive no Go: o Dart guarda o handle; o NativeFinalizer o solta.
abstract class GoHandle implements Finalizable {
  GoHandle(this.$h) {
    _native.finalizer.attach(this, Pointer.fromAddress($h), detach: this);
  }

  final int $h;
}

/// Tipo-valor do Go (CID, path, peer ID, multiaddr) guardado como string.
abstract class GoValue {
  const GoValue(this.value);

  final String value;

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      other is GoValue &&
      other.runtimeType == runtimeType &&
      other.value == value;

  @override
  int get hashCode => Object.hash(runtimeType, value);
}

/// Valor do Go que atravessa como o JSON do próprio Go (config.Config).
abstract class GoJsonValue implements GoJson {
  GoJsonValue(this.json);

  final Map<String, Object?> json;

  @override
  Object? $toJson() => json;
}

/// Struct do Go (DTO) que atravessa como objeto JSON.
abstract interface class GoJson {
  Object? $toJson();
}

/// Opção funcional do Go: o caminho do construtor e os argumentos.
abstract class GoOption {
  GoOption(this.p, this.a);

  final String p;
  final List<Object?> a;
}

/// Argumento Dart → JSON do runtime Go.
Object? $enc(Object? v) => switch (v) {
      null || bool() || int() || double() || String() => v,
      Uint8List() => base64Encode(v),
      GoHandle() => v.$h,
      GoValue() => v.value,
      GoJson() => v.$toJson(),
      GoOption() => {'P': v.p, 'A': $enc(v.a)},
      DateTime() => v.toUtc().toIso8601String(),
      Duration() => v.inMicroseconds * 1000,
      List() => [for (final e in v) $enc(e)],
      Map() => {for (final e in v.entries) e.key as String: $enc(e.value)},
      _ => throw ArgumentError.value(v, 'v', 'não atravessa a ponte FFI'),
    };

/// []byte do Go (base64; nil → vazio).
Uint8List $bytes(Object? v) =>
    v == null ? Uint8List(0) : base64Decode(v as String);

/// Resultado não nulo: nil do Go vira IpfsException.
Object $nn(Object? v) => v ?? (throw IpfsException('o Go devolveu nil'));
