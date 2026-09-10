// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-ipld-prime's node/tests/mapSpecs.go (SpecTestMapStrInt,
// SpecTestMapStrMapStrInt, SpecTestMapStrListStr) plus any_test.go's
// TestAnyBeingMapStrInt/TestAnyBeingMapStrMapStrInt, applied directly
// against this package's PlainMap/AnyBuilder (see scalars_test.dart's
// header for why the generic spec-test engine isn't ported).
import 'package:test/test.dart';
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

Node _buildMapStrIntN3(NodePrototype np) {
  final nb = np.newBuilder();
  final ma = nb.beginMap(3);
  ma.assembleKey().assignString('whee');
  ma.assembleValue().assignInt(1);
  ma.assembleKey().assignString('woot');
  ma.assembleValue().assignInt(2);
  ma.assembleKey().assignString('waga');
  ma.assembleValue().assignInt(3);
  ma.finish();
  return nb.build();
}

void _specTestMapStrInt(NodePrototype np) {
  group('map<str,int>, 3 entries', () {
    test('reads back out', () {
      final n = _buildMapStrIntN3(np);
      expect(n.length(), equals(3));
      expect(n.lookupByString('whee').asInt(), equals(1));
      expect(n.lookupByString('waga').asInt(), equals(3));
      expect(n.lookupByString('woot').asInt(), equals(2));
    });

    test('reads via iteration (insertion order)', () {
      final n = _buildMapStrIntN3(np);
      final itr = n.mapIterator()!;

      expect(itr.done(), isFalse);
      var (k, v) = itr.next();
      expect(k.asString(), equals('whee'));
      expect(v.asInt(), equals(1));

      expect(itr.done(), isFalse);
      (k, v) = itr.next();
      expect(k.asString(), equals('woot'));
      expect(v.asInt(), equals(2));

      expect(itr.done(), isFalse);
      (k, v) = itr.next();
      expect(k.asString(), equals('waga'));
      expect(v.asInt(), equals(3));

      expect(itr.done(), isTrue);
      expect(itr.next, throwsA(isA<IteratorOverreadException>()));
    });

    test('reads for absent keys error sensibly', () {
      final n = _buildMapStrIntN3(np);
      expect(
        () => n.lookupByString('nope'),
        throwsA(
          predicate(
            (e) =>
                e is NotExistsException &&
                e.toString() == 'key not found: "nope"',
          ),
        ),
      );
    });
  });

  test('repeated key should error', () {
    final nb = np.newBuilder();
    final ma = nb.beginMap(3);
    ma.assembleKey().assignString('whee');
    ma.assembleValue().assignInt(1);
    expect(
      () => ma.assembleKey().assignString('whee'),
      throwsA(isA<RepeatedMapKeyException>()),
    );
  });

  test('using expired child assemblers should throw', () {
    final nb = np.newBuilder();
    final ma = nb.beginMap(3);

    final ka = ma.assembleKey();
    ka.assignString('whee');
    expect(() => ka.assignString('woo'), throwsStateError);

    final va = ma.assembleValue();
    va.assignInt(1);
    expect(() => va.assignInt(2), throwsStateError);

    ma.finish();
    final n = nb.build();
    expect(n.length(), equals(1));
    expect(n.lookupByString('whee').asInt(), equals(1));
  });
}

void main() {
  group(
    'SpecTestMapStrInt via Prototype.map',
    () => _specTestMapStrInt(prototype.map),
  );
  group(
    'TestAnyBeingMapStrInt via Prototype.any',
    () => _specTestMapStrInt(prototype.any),
  );

  test('SpecTestMapStrMapStrInt: map<str,map<str,int>>', () {
    final nb = prototype.map.newBuilder();
    final ma = nb.beginMap(3);

    ma.assembleKey().assignString('whee');
    final m1 = ma.assembleValue().beginMap(2);
    m1.assembleKey().assignString('m1k1');
    m1.assembleValue().assignInt(1);
    m1.assembleKey().assignString('m1k2');
    m1.assembleValue().assignInt(2);
    m1.finish();

    ma.assembleKey().assignString('woot');
    final m2 = ma.assembleValue().beginMap(2);
    m2.assembleKey().assignString('m2k1');
    m2.assembleValue().assignInt(3);
    m2.assembleKey().assignString('m2k2');
    m2.assembleValue().assignInt(4);
    m2.finish();

    ma.assembleKey().assignString('waga');
    final m3 = ma.assembleValue().beginMap(2);
    m3.assembleKey().assignString('m3k1');
    m3.assembleValue().assignInt(5);
    m3.assembleKey().assignString('m3k2');
    m3.assembleValue().assignInt(6);
    m3.finish();

    ma.finish();
    final n = nb.build();

    expect(n.length(), equals(3));
    final woot = n.lookupByString('woot');
    expect(woot.lookupByString('m2k1').asInt(), equals(3));
    expect(woot.lookupByString('m2k2').asInt(), equals(4));
  });

  test('SpecTestMapStrListStr: map<str,list<str>>', () {
    final nb = prototype.map.newBuilder();
    final ma = nb.beginMap(3);

    ma.assembleKey().assignString('asdf');
    final l1 = ma.assembleValue().beginList(3);
    l1.assembleValue().assignString('eleven');
    l1.assembleValue().assignString('twelve');
    l1.assembleValue().assignString('thirteen');
    l1.finish();

    ma.assembleKey().assignString('qwer');
    final l2 = ma.assembleValue().beginList(2);
    l2.assembleValue().assignString('twentyone');
    l2.assembleValue().assignString('twentytwo');
    l2.finish();

    ma.assembleKey().assignString('zxcv');
    final l3 = ma.assembleValue().beginList(1);
    l3.assembleValue().assignString('thirtyone');
    l3.finish();

    ma.finish();
    final n = nb.build();

    expect(n.length(), equals(3));
    final qwer = n.lookupByString('qwer');
    expect(qwer.lookupByIndex(1).asString(), equals('twentytwo'));
  });
}
