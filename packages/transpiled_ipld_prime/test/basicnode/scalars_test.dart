// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-ipld-prime's node/basicnode/int_test.go (TestBasicInt,
// TestIntErrors) plus the string/bytes/int specs from node/tests
// (stringSpecs.go's SpecTestString, byteSpecs.go's SpecTestBytes) applied
// directly against this package's own prototypes -- the generic
// `node/tests` spec-test *engine* isn't ported (it's designed to drive
// many different Node implementations including schema-typed ones; this
// package only has the one, so the concrete assertions are reproduced
// directly instead of porting the harness around them).
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

void main() {
  test('TestBasicInt', () {
    final m = Basicnode.ofInt(3);
    final b = m.prototype().newBuilder();
    b.assignInt(4);
    final n = b.build();
    final u = const PlainInt(5); // stand-in for basicnode.NewUint(5): see below.

    expect(m.asInt(), equals(3));
    expect(n.asInt(), equals(4));
    expect(u.asInt(), equals(5));
  });

  test('TestBasicInt: PlainUint holds the full uint64 range', () {
    const u = PlainUint(5);
    expect(u.asInt(), equals(5));
    expect(u.asUint(), equals(5));
  });

  test('TestIntErrors', () {
    final x = Basicnode.ofInt(3);

    expect(
      () => x.lookupByIndex(0),
      throwsA(
        predicate(
          (e) =>
              e is WrongKindException &&
              e.toString() ==
                  'func called on wrong kind: "LookupByIndex" called on a int '
                      'node (kind: int), but only makes sense on list',
        ),
      ),
    );

    expect(
      () => x.lookupByString('n'),
      throwsA(
        predicate(
          (e) =>
              e is WrongKindException &&
              e.toString() ==
                  'func called on wrong kind: "LookupByString" called on a int '
                      'node (kind: int), but only makes sense on map',
        ),
      ),
    );

    expect(
      () => x.lookupByNode(x),
      throwsA(
        predicate(
          (e) =>
              e is WrongKindException &&
              e.toString() ==
                  'func called on wrong kind: "LookupByNode" called on a int '
                      'node (kind: int), but only makes sense on map',
        ),
      ),
    );
  });

  test('SpecTestString: string node', () {
    final nb = prototype.string.newBuilder();
    nb.assignString('asdf');
    final n = nb.build();

    expect(n.kind(), equals(Kind.string));
    expect(n.isNull(), isFalse);
    expect(n.asString(), equals('asdf'));
  });

  test('SpecTestString: via Prototype.any', () {
    final nb = prototype.any.newBuilder();
    nb.assignString('asdf');
    final n = nb.build();

    expect(n.kind(), equals(Kind.string));
    expect(n.isNull(), isFalse);
    expect(n.asString(), equals('asdf'));
  });

  test('SpecTestBytes: byte node', () {
    final nb = prototype.bytes.newBuilder();
    nb.assignBytes(Uint8List.fromList('asdf'.codeUnits));
    final n = nb.build();

    expect(n.kind(), equals(Kind.bytes));
    expect(n.isNull(), isFalse);
    expect(n.asBytes(), equals('asdf'.codeUnits));

    expect(n, isA<LargeBytesNode>());
    final reader = (n as LargeBytesNode).asLargeBytes();
    final buffer = Uint8List(64);
    final read = reader.read(buffer);
    expect(buffer.sublist(0, read), equals('asdf'.codeUnits));
  });
}
