/// Runtime das libraries geradas (go/gen): codifica os argumentos em binário
/// (ipfs_ffi/WIRE.md), manda o pedido ao ipfs_host pelo canal de memória
/// compartilhada (shm.dart) e entrega a resposta. O app não carrega Go. Não é
/// API pública.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'shm.dart';

part 'runtime/codec.dart';

/// Erro devolvido pelo Go (o `error` de um `(T, error)`, ou um panic dentro
/// de uma chamada).
class IpfsException implements Exception {
  IpfsException(this.message);

  final String message;

  @override
  String toString() => 'IpfsException: $message';
}

/// Por que o serviço parou.
enum IpfsStopReason {
  /// O ipfs_host caiu (um panic do Go, ou o sistema o matou).
  crash,

  /// O app foi para o segundo plano e o pacote parou o serviço
  /// (`IpfsService.background` = `IpfsBackground.stop`).
  background,
}

/// O serviço parou ([reason]: caiu ou foi parado no segundo plano), o canal
/// fechou, o serviço não foi iniciado ou o handle é de um serviço anterior
/// ([reason] null nesses dois). Relance com `IpfsService.restart()`.
class IpfsServiceException extends IpfsException {
  IpfsServiceException(super.message, {this.reason});

  final IpfsStopReason? reason;

  @override
  String toString() => 'IpfsServiceException: $message';
}

// Modos do pedido e tipos de resposta (WIRE.md).
const _sync = 0, _async = 1, _streamMode = 2;
const _evValue = 0, _evItem = 1, _evEnd = 2, _evError = 3;

/// Função Free (WIRE.md): `u32 n` + n × `i64`, sem resposta (id 0).
const _fnFree = 3;

/// O canal do serviço desta isolate (null = não iniciado ou parado).
ShmChannel? _ch;

/// Época do serviço: sobe a cada [$attach]. Um handle guarda a época em que
/// nasceu e só vale nela (os objetos do host morrem com o processo).
var _epoch = 0;

/// Por que o serviço parou (até o próximo [$attach]); null se nunca subiu ou
/// foi parado pelo app.
IpfsServiceException? _stopped;

ShmChannel get _channel =>
    _ch ??
    (throw _stopped ??
        IpfsServiceException(
            'o serviço não foi iniciado (await IpfsService.start())'));

/// Liga o runtime a um canal recém-aberto (IpfsService.start, depois do Hello).
void $attach(ShmChannel ch) {
  _ch = ch;
  _stopped = null;
  _epoch++;
  _toFree.clear();
  ch
    ..onMessage = _onMessage
    ..onDead = _onDead;
}

/// Desliga o runtime do canal (IpfsService.stop); as pendentes falham quando o
/// canal fecha. [why]: a parada (queda, segundo plano), que as chamadas novas
/// recebem até o serviço subir de novo.
void $detach([IpfsServiceException? why]) {
  _ch = null;
  _stopped = why;
  _toFree.clear();
}

/// Chamada pendente: o Completer (assíncrona), StreamController (stream) ou
/// GoSink; o escritor dos argumentos (mantém vivos os handles enviados até a
/// resposta, para o Finalizer não soltá-los antes) e os ids dos sinks dela.
final class _Pending {
  _Pending(this.sink, this.keep, this.sinks);

  final Object sink;
  final Object? keep;
  final List<int> sinks;
}

final _pending = <int, _Pending>{};

/// Sinks já fechados pelo Go, à espera da resposta da chamada deles: o
/// `close()` só completa quando o ouvinte recebeu o fim.
final _sinkDone = <int, Future<void>>{};

void _onMessage(int id, int kind, Uint8List data) {
  final p = _pending[id];
  if (p == null) return; // sink já fechado pelo fim da chamada
  switch ((kind, p.sink)) {
    case (_evValue, Completer<$R> c):
      final r = $R(data);
      _finish(id, p).then((_) => c.complete(r));
      return;
    case (_evItem, StreamController<$R> s):
      s.add($R(data));
      return;
    case (_evItem, GoSink<Object?> s):
      s._add($R(data));
      return;
    case (_evEnd, StreamController<$R> s):
      s.close();
    case (_evEnd, GoSink<Object?> s):
      _sinkDone[id] = s.sink.close();
    case (_evError, GoSink<Object?> s):
      s.sink.addError(IpfsException(utf8.decode(data)));
      _sinkDone[id] = s.sink.close();
    case (_evError, Completer<$R> c):
      final e = IpfsException(utf8.decode(data));
      _finish(id, p).then((_) => c.completeError(e));
      return;
    case (_evError, final sink):
      _failSink(sink, IpfsException(utf8.decode(data)));
    default:
      return; // tipo que não cabe nesta pendente: ignora
  }
  _finish(id, p);
}

/// Fim de uma chamada: os sinks que o Go não fechou fecham agora (o Go os
/// fecha antes da resposta; WIRE.md). Completa quando os ouvintes de todos os
/// sinks dela já receberam o fim, para a chamada responder depois deles.
Future<void> _finish(int id, _Pending p) {
  _pending.remove(id);
  final done = [
    for (final s in p.sinks)
      if (_sinkDone.remove(s) case final f?) f
  ];
  _closeSinks(p.sinks, null, done);
  return done.isEmpty ? Future.value() : Future.wait(done);
}

void _closeSinks(List<int> sinks, [Object? error, List<Future<void>>? done]) {
  for (final s in sinks) {
    _sinkDone.remove(s);
    if (_pending.remove(s)?.sink case final GoSink<Object?> sink) {
      if (error != null) sink.sink.addError(error);
      final f = sink.sink.close();
      done?.add(f);
    }
  }
}

void _failSink(Object sink, Object e, [StackTrace? st]) {
  switch (sink) {
    case Completer<$R> c:
      c.completeError(e, st);
    case StreamController<$R> s:
      s
        ..addError(e, st)
        ..close();
    case GoSink<Object?> s:
      s.sink
        ..addError(e, st)
        ..close();
  }
}

void _onDead(IpfsServiceException e) {
  final all = [..._pending.values];
  _pending.clear();
  _sinkDone.clear();
  _toFree.clear();
  for (final p in all) {
    _failSink(p.sink, e);
  }
}

/// Registra os sinks do escritor como pendentes e devolve os ids.
List<int> _register($W? w) {
  if (w == null || w._sinks.isEmpty) return const [];
  for (final (id, s) in w._sinks) {
    _pending[id] = _Pending(s, null, const []);
  }
  return [for (final (id, _) in w._sinks) id];
}

/// Chamada síncrona: bloqueia a isolate até o host responder (gira, depois
/// dorme), entregando no caminho as mensagens das outras.
$R $callSync(int fn, [$W? w]) {
  final ch = _channel;
  w?._check();
  final id = ch.newId();
  final sinks = _register(w);
  try {
    ch.send(id, fn, _sync, w?.take());
    final (kind, data) = ch.waitFor(id);
    if (kind == _evError) throw IpfsException(utf8.decode(data));
    return $R(data);
  } catch (e) {
    _closeSinks(sinks, e);
    rethrow;
  } finally {
    _closeSinks(sinks);
  }
}

/// Chamada assíncrona: a resposta chega pelo canal.
Future<$R> $call(int fn, [$W? w]) {
  final c = Completer<$R>();
  _start(fn, _async, w, c);
  return c.future;
}

/// Stream: um `item` por valor do canal do Go, até `fim` ou `erro`.
Stream<$R> $stream(int fn, [$W? w]) {
  final s = StreamController<$R>();
  _start(fn, _streamMode, w, s);
  return s.stream;
}

void _start(int fn, int mode, $W? w, Object sink) {
  var sinks = const <int>[];
  try {
    final ch = _channel;
    w?._check();
    final id = ch.newId();
    sinks = _register(w);
    _pending[id] = _Pending(sink, w, sinks);
    try {
      ch.send(id, fn, mode, w?.take());
    } catch (_) {
      _pending.remove(id);
      rethrow;
    }
  } catch (e, st) {
    _closeSinks(sinks, e);
    _failSink(sink, e, st); // falha pelo Future/Stream, não na hora
  }
}

/// Canal `chan<- T` que o Go recebe numa opção (options.Unixfs.Events): o
/// sink é registrado com um id próprio na chamada; os itens vão para [sink],
/// que fecha quando a chamada termina.
final class GoSink<T> {
  GoSink(this.sink, this.decode);

  final StreamSink<T> sink;
  final T Function($R r) decode;

  void _add($R r) => sink.add(decode(r));
}

// Handles soltos pelo Finalizer, mandados em lote ao host (função Free).
final _toFree = <int>[];
final _finalizer = Finalizer<(int, int)>((t) {
  final (epoch, h) = t;
  // o serviço em que o handle nasceu já acabou: o objeto morreu com ele
  if (epoch != _epoch || _ch == null) return;
  if (_toFree.isEmpty) Timer.run(_flushFree);
  _toFree.add(h);
});

void _flushFree() {
  final ch = _ch;
  if (ch == null || _toFree.isEmpty) return;
  final w = $W()..u32(_toFree.length);
  for (final h in _toFree) {
    w.i64(h);
  }
  _toFree.clear();
  try {
    ch.send(0, _fnFree, _sync, w.take());
  } on IpfsServiceException {
    // o host caiu: os objetos foram com ele
  }
}

/// Objeto que vive no host: o Dart guarda o handle e a época do serviço; o
/// Finalizer o solta (em lote) quando o objeto Dart some.
abstract class GoHandle {
  GoHandle(this.$h) : $e = _epoch {
    _finalizer.attach(this, ($e, $h));
  }

  final int $h;

  /// A época do serviço em que o handle nasceu.
  final int $e;
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

/// Valor do Go que atravessa como o JSON do próprio kubo (config.Config).
abstract class GoJsonValue {
  GoJsonValue(this.json);

  final Map<String, Object?> json;
}

/// Struct do Go (DTO): escreve os campos que atravessam, em ordem.
abstract interface class GoDto {
  void $enc($W w);
}

/// Opção funcional do Go: o índice do construtor (em `tinfo.ctors` do
/// gerador) e quem escreve os parâmetros dele.
abstract class GoOption {
  GoOption(this.$i, this.$a);

  final int $i;
  final void Function($W w) $a;
}

/// Resultado não nulo: nil do Go vira IpfsException.
Never $nil() => throw IpfsException('o Go devolveu nil');

/// Getter de instantâneo com erro: o valor, ou null se o Go deu erro.
T? $orErr<T>(T v, String? err) => err == null ? v : null;
