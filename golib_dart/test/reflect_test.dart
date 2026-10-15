// ignore_for_file: library_prefixes
import 'package:golib_dart/builtin.dart' as go;
import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:golib_dart/reflect.dart' as reflect;
import 'package:test/test.dart';

// Como o g2d emitiria `type P struct { X int `json:"x"`; Y string; n *P }`.
class P extends go.GoStruct<P> implements go.Typed {
  P({Golang.Int? x, Golang.String? y, this.n})
    : x = x ?? Golang.Int(),
      y = y ?? Golang.String();
  static final P $nil = P()..$nilPtr = true;
  Golang.Int x;
  Golang.String y;
  P? n;

  static final go.RType<P> $rt = go.rtStruct<P>(
    'main',
    'P',
    'main.P',
    size: 32,
    align: 8,
    ptrs: true,
    zero: P.new,
    nil: () => P.$nil,
    fields: () => [
      go.rtField(
        'X',
        '',
        () => go.rtInt,
        tag: 'json:"x,omitempty"',
        get: (o) => (o as P).x,
        set: (o, v) => (o as P).x = v as Golang.Int,
      ),
      go.rtField(
        'Y',
        '',
        () => go.rtString,
        offset: 8,
        get: (o) => (o as P).y,
        set: (o, v) => (o as P).y = v as Golang.String,
      ),
      go.rtField(
        'n',
        'main',
        () => go.rtPtr(P.$rt),
        offset: 24,
        get: (o) => (o as P).n,
        set: (o, v) => (o as P).n = v as P?,
      ),
    ],
  );
  @override
  go.RType get $rtype => $rt;
  @override
  String get $goType => 'main.P';
  @override
  P $copy() => P(x: x, y: y, n: n);
  @override
  void $set(P o) {
    x = o.x;
    y = o.y;
    n = o.n;
  }

  @override
  List<Object?> get $fields => [x, y, go.Addr(n)];
  @override
  List<String> get $fieldNames => const ['X', 'Y', 'n'];
}

Golang.String s(String x) => Golang.String.fromDart(x);

void main() {
  test('TypeOf básicos e compostos', () {
    expect(reflect.typeOf(Golang.Int(3))!.kind().string().toString(), 'int');
    final ints = go.Slice<Golang.Int>.of([
      Golang.Int(1),
    ], const go.Elem<Golang.Int>(8, Golang.Int.new));
    final t = reflect.typeOf(ints)!;
    expect(t.string().toString(), '[]int');
    expect(identical(t, reflect.sliceOf(go.rtInt)), isTrue);
    final m = go.GoMap<Golang.String, Object?>.of(
      {},
      const go.Elem<Object?>(16, go.zeroNull),
    );
    expect(reflect.typeOf(m)!.string().toString(), 'map[string]interface {}');
    expect(
      reflect.typeOf(go.Box<Golang.Int>(Golang.Int()))!.string().toString(),
      '*int',
    );
    expect(reflect.typeOf(true)!.kind().toInt(), go.kBool);
  });

  test('struct: campos, tag, ponteiro', () {
    final p = P(x: Golang.Int(1), y: s('a'));
    final t = reflect.typeOf(p.$ifaceCopy())!;
    expect(t.name().toString(), 'P');
    expect(t.pkgPath().toString(), 'main');
    expect(t.numField().toInt(), 3);
    expect(t.field(Golang.Int(0)).tag.get(s('json')).toString(), 'x,omitempty');
    expect(t.field(Golang.Int(2)).pkgPath.toString(), 'main');
    expect(reflect.typeOf(p)!.string().toString(), '*main.P');
    expect(t.field(Golang.Int(2)).type!.string().toString(), '*main.P');
    final v = reflect.valueOf(p).elem$();
    expect(v.canSet(), isTrue);
    v.field(Golang.Int(0)).setInt(Golang.Int64(42));
    expect(p.x.toInt(), 42);
    v.field(Golang.Int(1)).setString(s('b'));
    expect(p.y.toString(), 'b');
    expect(v.field(Golang.Int(2)).canSet(), isFalse);
    final cp = v.interface() as P;
    expect(cp.$isValue, isTrue);
    expect(cp.x.toInt(), 42);
    final nv = reflect.valueOf(p.$ifaceCopy());
    expect(nv.field(Golang.Int(0)).canSet(), isFalse);
  });

  test('New, MakeSlice, MakeMap, Append, DeepEqual', () {
    final pv = reflect.new$(go.rtInt);
    pv.elem$().setInt(Golang.Int64(7));
    final box = pv.interface();
    expect(box, isA<go.Ptr<Golang.Int>>());
    expect((box as go.Ptr<Golang.Int>).value.toInt(), 7);
    final sv = reflect.makeSlice(
      reflect.sliceOf(go.rtString),
      Golang.Int(0),
      Golang.Int(0),
    );
    final out = reflect.append$(
      sv,
      go.Slice<reflect.Value>.of([reflect.valueOf(s('x'))], reflect.$valueElem),
    );
    expect(out.interface(), isA<go.Slice<Golang.String>>());
    expect(out.len().toInt(), 1);
    final mv = reflect.makeMap(reflect.mapOf(go.rtString, go.rtInt));
    mv.setMapIndex(reflect.valueOf(s('k')), reflect.valueOf(Golang.Int(5)));
    expect(
      (mv.interface() as go.GoMap<Golang.String, Golang.Int>)[s('k')].toInt(),
      5,
    );
    expect(
      reflect.typeOf(mv.interface())!.string().toString(),
      'map[string]int',
    );
    expect(
      reflect.deepEqual(
        P(x: Golang.Int(1)).$ifaceCopy(),
        P(x: Golang.Int(1)).$ifaceCopy(),
      ),
      isTrue,
    );
    expect(
      reflect.deepEqual(
        P(x: Golang.Int(1)).$ifaceCopy(),
        P(x: Golang.Int(2)).$ifaceCopy(),
      ),
      isFalse,
    );
    final pp = reflect.new$(P.$rt);
    expect(pp.interface(), isA<P>());
    expect((pp.interface() as P).$isValue, isFalse);
  });
}
