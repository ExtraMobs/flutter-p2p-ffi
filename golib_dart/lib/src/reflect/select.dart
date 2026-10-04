part of '../../reflect.dart';

// `reflect.Select` sobre os canais do runtime (`go.Chan`, `rt.select`);
// as operações de canal de `reflect.Value` estão em chan_ops.dart.
//
// O que pode bloquear tem a versão dupla do D2: a síncrona (`select`,
// `send`, `recv`) só completa o que já está pronto e, se precisaria
// esperar, cai no limite do g2d (como `WaitGroup.wait`); a `$async`
// (`select$async`, `send$async`, `recv$async`) espera de fato. O g2d chama
// sempre a `$async` (`SUSPENDING_SHIM` em g2d/services/concurrency.py).

/// `reflect.SelectDir` (`type SelectDir int`).
final class SelectDir extends Golang.Int64Base<SelectDir> {
  SelectDir([int v = 0]) : super(v);
  SelectDir.from(Golang.IntBase v) : super.from(v);
  SelectDir.fromBigInt(BigInt v) : super.fromBigInt(v);
  SelectDir._(super.$hi, super.$lo) : super.raw();

  @override
  SelectDir $make(int hi, int lo) => SelectDir._(hi, lo);

  @override
  String get $goType => 'reflect.SelectDir';

  @override
  List<String> get $methods => const [];
}

const _selectSend = 1, _selectRecv = 2, _selectDefault = 3;

/// `reflect.SelectCase`.
final class SelectCase extends GoStruct<SelectCase> {
  SelectCase({SelectDir? dir, Value? chan, Value? send})
    : dir = dir ?? SelectDir(),
      chan = chan ?? Value(),
      send = send ?? Value();

  static final SelectCase $nil = SelectCase()..$nilPtr = true;

  SelectDir dir;
  Value chan;
  Value send;

  @override
  String get $goType => 'reflect.SelectCase';

  @override
  SelectCase $copy() =>
      SelectCase(dir: dir, chan: chan.$copy(), send: send.$copy());

  @override
  void $set(SelectCase o) {
    dir = o.dir;
    chan.$set(o.chan);
    send.$set(o.send);
  }

  @override
  List<Object?> get $fields => [dir, chan, send];

  @override
  List<String> get $fieldNames => const ['Dir', 'Chan', 'Send'];
}

/// `go.Elem` de `reflect.SelectCase` (`[]reflect.SelectCase`).
const $selectCaseElem = Elem<SelectCase>(
  56,
  SelectCase.new,
  pointers: true,
  value: true,
);

/// Os casos de um `reflect.Select` já conferidos, no formato do runtime.
final class _Select {
  final cases = <rt.SelectCase>[];

  /// Índice Go de cada caso de [cases].
  final index = <int>[];

  /// Tipo do elemento de cada caso de recebimento (null: envio).
  final elems = <RType?>[];

  int dflt = -1;

  (Golang.Int, Value, bool) result((int, Object?, bool) r) {
    final (j, v, ok) = r;
    final e = elems[j];
    if (e == null) return (Golang.Int(index[j]), Value(), false);
    return (Golang.Int(index[j]), Value._of(e, v), ok);
  }

  (Golang.Int, Value, bool) get none => (Golang.Int(dflt), Value(), false);
}

Never _selectPanic(String msg) => throw Panic(Golang.String.fromDart(msg));

_Select _prepareSelect(Slice<SelectCase> cs) {
  if (cs.length > 65536) {
    _selectPanic('reflect.Select: too many cases (max 65536)');
  }
  final s = _Select();
  for (var i = 0; i < cs.length; i++) {
    final c = cs[i];
    switch (c.dir.toInt()) {
      case _selectDefault:
        if (s.dflt >= 0) _selectPanic('reflect.Select: multiple default cases');
        s.dflt = i;
        if (c.chan.isValid()) {
          _selectPanic('reflect.Select: default case has Chan value');
        }
        if (c.send.isValid()) {
          _selectPanic('reflect.Select: default case has Send value');
        }
      case _selectSend:
        final ch = c.chan;
        Chan? chan;
        Object? rep;
        if (ch.isValid()) {
          final t = ch._chChanType('reflect.Select');
          if (t.$dir & 2 == 0) {
            _selectPanic(
              'reflect.Select: SendDir case using recv-only channel',
            );
          }
          final v = c.send;
          if (!v.isValid()) {
            _selectPanic('reflect.Select: SendDir case missing Send value');
          }
          v._chMustBeExported('reflect.Select');
          rep = _assignRep(v, t.$elem!, 'reflect.Select');
          chan = ch.$rep as Chan?;
        }
        s.cases.add(rt.SendCase<Object?>(chan as Chan<Object?>?, rep));
        s.index.add(i);
        s.elems.add(null);
      case _selectRecv:
        if (c.send.isValid()) {
          _selectPanic('reflect.Select: RecvDir case has Send value');
        }
        final ch = c.chan;
        Chan? chan;
        RType? elem;
        if (ch.isValid()) {
          final t = ch._chChanType('reflect.Select');
          if (t.$dir & 1 == 0) {
            _selectPanic(
              'reflect.Select: RecvDir case using send-only channel',
            );
          }
          chan = ch.$rep as Chan?;
          elem = t.$elem!;
        }
        s.cases.add(rt.RecvCase<Object?>(chan as Chan<Object?>?));
        s.index.add(i);
        // Canal nil nunca é escolhido: o tipo não importa.
        s.elems.add(elem ?? rtAny);
      default:
        _selectPanic('reflect.Select: invalid Dir');
    }
  }
  return s;
}

/// `reflect.Select(cases)` na forma síncrona: só o que não espera (caso
/// pronto ou `default`); esperar é o limite do g2d (ver o topo do arquivo).
(Golang.Int, Value, bool) select(Slice<SelectCase> cases) {
  final s = _prepareSelect(cases);
  final r = rt.selectNow(s.cases);
  if (r.$1 >= 0) return s.result(r);
  if (s.dflt >= 0) return s.none;
  _blockSync('Select');
}

/// `reflect.Select(cases)`: espera um caso ficar pronto (com `default`,
/// nunca espera). Escolha uniforme entre os prontos, como o Go.
Future<(Golang.Int, Value, bool)> select$async(Slice<SelectCase> cases) async {
  final s = _prepareSelect(cases);
  if (s.dflt >= 0) {
    final r = rt.selectNow(s.cases);
    return r.$1 >= 0 ? s.result(r) : s.none;
  }
  return s.result(await rt.select(s.cases));
}

/// Operação síncrona que teria de esperar: sem outra goroutine viva é o
/// deadlock do Go; com outras, o limite do g2d (só a `$async` espera).
Never _blockSync(String op) {
  if (aliveGoroutines <= 1) fatal('all goroutines are asleep - deadlock!');
  fatal(
    'g2d: reflect $op síncrono que precisaria esperar (contexto que não '
    'pode suspender); era preciso a versão \$async aqui',
  );
}
