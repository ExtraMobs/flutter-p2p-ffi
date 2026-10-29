// A codificação binária do WIRE.md no lado Dart (src/runtime/codec.dart),
// ida e volta de cada tipo, sem o p2p_host.
import 'dart:typed_data';

import 'package:p2p_ffi/src/runtime.dart';
import 'package:test/test.dart';
import 'package:p2p_ffi/p2p_ffi.dart';

final class _H extends GoHandle {
  _H(super.$h);
}

$R _back($W w) => $R(Uint8List.fromList(w.take()));

void main() {
  test('básicos, little-endian', () {
    final w = $W()
      ..u8(7)
      ..u32(0xdeadbeef)
      ..i32(-2)
      ..i64(-1 << 40)
      ..i64(0xaee9320e3f959234) // um u64 acima de 2^63
      ..f64(1.5)
      ..b(true)
      ..b(false)
      ..str('olá');
    final b = w.take();
    expect(b.sublist(1, 5), [0xef, 0xbe, 0xad, 0xde]);
    expect(b.sublist(b.length - 8), [4, 0, 0, 0, 0x6f, 0x6c, 0xc3, 0xa1]);
    final r = _back(w);
    expect(r.u8(), 7);
    expect(r.u32(), 0xdeadbeef);
    expect(r.i32(), -2);
    expect(r.i64(), -1 << 40);
    expect(r.i64(), 0xaee9320e3f959234);
    expect(r.f64(), 1.5);
    expect(r.b(), isTrue);
    expect(r.b(), isFalse);
    expect(r.str(), 'olá');
  });

  test(
      'uint64 acima de 2^63: os mesmos bits (int negativo); BigInt lê sem sinal',
      () {
    // o Go escreve uint64(math.MaxUint64) como i64 (go/wire_test.go)
    final r = _back($W()..i64(-1));
    final v = r.i64();
    expect(v, -1);
    expect(BigInt.from(v).toUnsigned(64), (BigInt.one << 64) - BigInt.one);
  });

  test('bytes: nil (-1), vazio e com dados; erro e presença', () {
    final w = $W()
      ..bytes(null)
      ..bytes(Uint8List(0))
      ..bytes(Uint8List.fromList(List.generate(100, (i) => i)))
      ..err(null)
      ..err('falhou');
    expect(w.take().sublist(0, 4), [0xff, 0xff, 0xff, 0xff]);
    final r = _back(w);
    expect(r.bytes(), isNull);
    expect(r.bytes(), isEmpty);
    expect(r.bytes(), List.generate(100, (i) => i));
    expect(r.err(), isNull);
    expect(r.err(), 'falhou');
  });

  test('tipos-valor, time.Time e config.Config', () {
    final t = DateTime.utc(2026, 10, 15, 12, 30, 1, 2, 3);
    final w = $W()
      ..val(const Cid('bafy'))
      ..val(null)
      ..time(t)
      ..time(null)
      ..json(KuboConfig({
        'a': [1, 2]
      }));
    final r = _back(w);
    expect(r.p() ? Cid(r.str()) : null, const Cid('bafy'));
    expect(r.p(), isFalse);
    expect(r.p(), isTrue);
    expect(r.time(), t);
    expect(r.p(), isFalse);
    expect(r.p(), isTrue);
    expect(r.json(), {
      'a': [1, 2]
    });
  });

  test('handles: 0 = nil; hnn falha no nil', () {
    final w = $W()
      ..h(_H(42))
      ..h(null)
      ..i64(0);
    final r = _back(w);
    expect(r.hn(_H.new)!.$h, 42);
    expect(r.hn(_H.new), isNull);
    expect(() => r.hnn(_H.new), throwsA(isA<GolangException>()));
  });

  test('listas (nil = -1, lido como vazio) e mapas sem presença na chave', () {
    final w = $W()
      ..list(<String>['a', 'b'], (w, e) => w.str(e))
      ..list<int>(null, (w, e) => w.i64(e))
      ..list(<List<int>>[
        [1],
        [2, 3]
      ], (w, e) => w.list(e, (w, x) => w.i64(x)))
      ..map(<String, bool>{'x': true, 'y': false}, (w, k) => w.str(k),
          (w, v) => w.b(v));
    final r = _back(w);
    expect(r.list(r.str), ['a', 'b']);
    expect(r.list(r.i64), isEmpty);
    expect(r.list(() => r.list(r.i64)), [
      [1],
      [2, 3]
    ]);
    expect(r.map(r.str, r.b), {'x': true, 'y': false});
  });

  test('DTO gerado: presença + campos na ordem', () {
    final link = IpldFormatLink(name: 'n', size: 9, cid: const Cid('bafy'));
    final w = $W()
      ..dto(link)
      ..dto(null)
      ..dto(IpldFormatLink());
    final r = _back(w);
    expect(r.p(), isTrue);
    final got = IpldFormatLink.$dec(r);
    expect((got.name, got.size, got.cid), ('n', 9, const Cid('bafy')));
    expect(r.p(), isFalse);
    expect(r.p(), isTrue);
    final empty = IpldFormatLink.$dec(r);
    expect((empty.name, empty.size, empty.cid), ('', 0, null));
  });

  test('opção funcional: índice do construtor + parâmetros', () {
    final o = go.ipfs.kubo.core.coreiface.options.unixfs.cidVersion(1);
    final w = $W()
      ..list([o, go.ipfs.kubo.core.coreiface.options.pin.ls.all()],
          (w, e) => w.opt(e));
    final r = _back(w);
    expect(r.i32(), 2);
    expect(r.u32(), o.$i);
    expect(r.i64(), 1);
    r.u32(); // Pin.Ls.All: sem parâmetros
    expect(() => r.u8(), throwsRangeError); // acabou
  });

  test('io.Reader: bytes (u8 0) ou handle (u8 1)', () {
    final w = $W()
      ..reader(Uint8List.fromList([1, 2]))
      ..reader(_H(5));
    final r = _back(w);
    expect(r.u8(), 0);
    expect(r.bytes(), [1, 2]);
    expect(r.u8(), 1);
    expect(r.i64(), 5);
  });

  test('sem o serviço: síncrona lança, assíncrona falha pelo Future', () async {
    expect(() => $callSync(0), throwsA(isA<P2pServiceException>()));
    await expectLater($call(0), throwsA(isA<P2pServiceException>()));
    await expectLater($stream(0).toList(), throwsA(isA<P2pServiceException>()));
  });

  test('release determinístico: idempotente e bloqueia uso posterior', () {
    final h = _H(99);
    expect(h.isReleased, isFalse);
    h.release();
    expect(h.isReleased, isTrue);
    // Repeated release calls are a safe no-op.
    h.release();
    expect(h.isReleased, isTrue);

    // Passing a released handle into a call fails on the Dart side.
    expect(
      () => $callSync(0, $W()..h(h)),
      throwsA(isA<GolangException>().having(
        (e) => e.message,
        'message',
        contains('handle already released'),
      )),
    );
  });

  test('use: libera no retorno síncrono, em exceção e após Future', () async {
    final h1 = _H(101);
    final v = h1.use((x) {
      expect(x.isReleased, isFalse);
      return x.$h * 2;
    });
    expect(v, 202);
    expect(h1.isReleased, isTrue);

    final h2 = _H(102);
    expect(
      () => h2.use<void>((_) => throw StateError('boom')),
      throwsStateError,
    );
    expect(h2.isReleased, isTrue);

    final h3 = _H(103);
    final future = h3.use((x) async {
      await Future<void>.delayed(Duration.zero);
      expect(x.isReleased, isFalse);
      return x.$h;
    });
    expect(h3.isReleased, isFalse);
    expect(await future, 103);
    expect(h3.isReleased, isTrue);
  });

  test('withGoScope e GoScope: libera múltiplos handles em ordem reversa',
      () async {
    late _H a;
    late _H b;
    final sum = withGoScope((scope) {
      a = scope.manage(_H(10));
      b = scope.manage(_H(20));
      expect(a.isReleased, isFalse);
      expect(b.isReleased, isFalse);
      return a.$h + b.$h;
    });
    expect(sum, 30);
    expect(a.isReleased, isTrue);
    expect(b.isReleased, isTrue);

    // Async withGoScope keeps handles alive until the Future completes.
    late _H c;
    final asyncFuture = withGoScope((scope) async {
      c = scope.manage(_H(30));
      await Future<void>.delayed(Duration.zero);
      expect(c.isReleased, isFalse);
      return c.$h;
    });
    expect(c.isReleased, isFalse);
    expect(await asyncFuture, 30);
    expect(c.isReleased, isTrue);

    // Managing a handle on a closed GoScope releases the handle and throws.
    final scope = GoScope()..close();
    expect(scope.isClosed, isTrue);
    final orphan = _H(40);
    expect(() => scope.manage(orphan), throwsStateError);
    expect(orphan.isReleased, isTrue);
  });
}
