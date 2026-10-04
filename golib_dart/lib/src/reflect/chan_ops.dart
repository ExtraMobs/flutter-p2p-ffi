part of '../../reflect.dart';

// `reflect.ChanOf`, `MakeChan` e as operações de canal de `reflect.Value`
// sobre `go.Chan`, com a versão dupla do D2 (ver o topo de select.dart).

/// `reflect.ChanOf(dir, t)`.
RType? chanOf(ChanDir dir, RType? t) {
  final rt0 = _needType(t, 'ChanOf');
  if (rt0.$size >= 1 << 16) {
    _selectPanic('reflect.ChanOf: element size too large');
  }
  final d = dir.toInt();
  if (d < 1 || d > 3) _selectPanic('reflect.ChanOf: invalid dir');
  return rt0.chanOf(d);
}

/// `reflect.MakeChan(typ, buffer)`.
Value makeChan(RType? typ, Golang.Int buffer) {
  final t = _needType(typ, 'MakeChan');
  if (t.$kind != kChan) _selectPanic('reflect.MakeChan of non-chan type');
  final n = buffer.toInt();
  if (n < 0) _selectPanic('reflect.MakeChan: negative buffer size');
  if (t.$dir != 3)
    _selectPanic('reflect.MakeChan: unidirectional channel type');
  final e = t.$elem!;
  final Object c = e.$elemDesc.$with(<E>() => Chan<E>(n, e.$zero() as E));
  return Value._of(t, t.$name.isNotEmpty && t.$conv != null ? t.$conv!(c) : c);
}

/// Operações de canal de `reflect.Value`.
extension ValueChan on Value {
  void _chMustBeExported(String m) {
    if (_t == null) _kindPanic(m, kInvalid);
    if (_flag & _fRO != 0) {
      throw Panic(
        Golang.String.fromDart(
          'reflect: $m using value obtained using unexported field',
        ),
      );
    }
  }

  /// O tipo do canal (kind chan e valor exportado, como o `mustBe(Chan)` +
  /// `mustBeExported` do Go).
  RType _chChanType(String m) {
    _mustBe(kChan, m);
    _chMustBeExported(m);
    return _t!;
  }

  Chan? get _chRep => $rep as Chan?;

  /// Representação de [x] para enviar (canal de envio, x exportado e
  /// atribuível ao elemento).
  Object? _sendRep(Value x, String m) {
    final t = _chChanType(m);
    if (t.$dir & 2 == 0) {
      _selectPanic('reflect: send on recv-only channel');
    }
    x._chMustBeExported(m);
    // O `send` interno do Go converte com o nome do Send (também no TrySend).
    return _assignRep(x, t.$elem!, 'reflect.Value.Send');
  }

  RType _recvElem(String m) {
    final t = _chChanType(m);
    if (t.$dir & 1 == 0) _selectPanic('reflect: recv on send-only channel');
    return t.$elem!;
  }

  /// `Value.Send(x)`, forma síncrona: só um envio que não espera.
  void send(Value x) {
    final rep = _sendRep(x, 'reflect.Value.Send');
    final c = _chRep;
    if (c == null || !c.$sendReady()) _blockSync('Value.Send');
    (c as Chan<Object?>).$commitSend(rep);
  }

  /// `Value.Send(x)`.
  Future<void> send$async(Value x) {
    final rep = _sendRep(x, 'reflect.Value.Send');
    return chanSend<Object?>(_chRep as Chan<Object?>?, rep);
  }

  /// `Value.TrySend(x)`: envia se não precisa esperar.
  bool trySend(Value x) {
    final rep = _sendRep(x, 'reflect.Value.TrySend');
    final c = _chRep;
    if (c == null || !c.$sendReady()) return false;
    (c as Chan<Object?>).$commitSend(rep);
    return true;
  }

  /// `Value.Recv()`, forma síncrona: só um recebimento que não espera.
  (Value, bool) recv() {
    final e = _recvElem('reflect.Value.Recv');
    final c = _chRep;
    if (c == null || !c.$recvReady()) _blockSync('Value.Recv');
    final (v, ok) = c.$commitRecv();
    return (Value._of(e, v), ok);
  }

  /// `Value.Recv()`.
  Future<(Value, bool)> recv$async() async {
    final e = _recvElem('reflect.Value.Recv');
    final (v, ok) = await chanRecv2<Object?>(_chRep as Chan<Object?>?);
    return (Value._of(e, v), ok);
  }

  /// `Value.TryRecv()`: Value inválido se precisaria esperar.
  (Value, bool) tryRecv() {
    final e = _recvElem('reflect.Value.TryRecv');
    final c = _chRep;
    if (c == null || !c.$recvReady()) return (Value(), false);
    final (v, ok) = c.$commitRecv();
    return (Value._of(e, v), ok);
  }

  /// `Value.Close()`.
  void close() {
    final t = _chChanType('reflect.Value.Close');
    if (t.$dir & 2 == 0) _selectPanic('reflect: close of receive-only channel');
    chanClose(_chRep);
  }
}
