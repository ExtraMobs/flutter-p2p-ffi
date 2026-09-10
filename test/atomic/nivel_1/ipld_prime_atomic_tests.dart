import 'dart:typed_data';

import 'package:test/test.dart' hide Matcher;
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

// go-ipld-prime ab9fe751f33fca77e7b8c4f7bb3dee40f6974313:
// datamodel/path{,Segment}.go and traversal/selector/*.go; indexed in
// go-ipfs-reference/go-ipld-prime-index/{datamodel,traversal_selector}.md.
// Path append/parent delegate to segment construction/pop; selectors delegate
// through Selector and PathSegment.Index, all within this upstream module.
void main() {
  test('BaseNode.lookupByString()', () {
    final BaseNode n = PlainBool(true);
    expect(() => n.lookupByString('x'), throwsA(isA<WrongKindException>()));
  });
  test('BaseNode.lookupByNode()', () {
    final BaseNode n = PlainBool(true);
    expect(
      () => n.lookupByNode(PlainString('x')),
      throwsA(isA<WrongKindException>()),
    );
  });
  test('BaseNode.lookupByIndex()', () {
    final BaseNode n = PlainBool(true);
    expect(() => n.lookupByIndex(0), throwsA(isA<WrongKindException>()));
  });
  test('BaseNode.lookupBySegment()', () {
    final BaseNode n = PlainBool(true);
    expect(
      () => n.lookupBySegment(const PathSegment.ofInt(0)),
      throwsA(isA<WrongKindException>()),
    );
  });
  test('BaseNode.asInt()', () {
    final BaseNode n = PlainBool(true);
    expect(() => n.asInt(), throwsA(isA<WrongKindException>()));
  });
  test('BaseNode.asFloat()', () {
    final BaseNode n = PlainBool(true);
    expect(() => n.asFloat(), throwsA(isA<WrongKindException>()));
  });
  test('BaseNode.asString()', () {
    final BaseNode n = PlainBool(true);
    expect(() => n.asString(), throwsA(isA<WrongKindException>()));
  });
  test('BaseNode.asBytes()', () {
    final BaseNode n = PlainBool(true);
    expect(() => n.asBytes(), throwsA(isA<WrongKindException>()));
  });
  test('BaseNode.asLink()', () {
    final BaseNode n = PlainBool(true);
    expect(() => n.asLink(), throwsA(isA<WrongKindException>()));
  });
  test('BaseNode.asBool()', () {
    final BaseNode n = PlainInt(1);
    expect(n.asBool, throwsA(isA<WrongKindException>()));
  });
  test('BaseNode.mapIterator()', () {
    final BaseNode n = PlainBool(true);
    expect(n.mapIterator(), isNull);
  });
  test('BaseNode.listIterator()', () {
    final BaseNode n = PlainBool(true);
    expect(n.listIterator(), isNull);
  });
  test('BaseNode.length()', () {
    final BaseNode n = PlainBool(true);
    expect(n.length(), -1);
  });
  test('BaseNode.isAbsent()', () {
    final BaseNode n = PlainBool(true);
    expect(n.isAbsent(), isFalse);
  });
  test('BaseNode.isNull()', () {
    final BaseNode n = PlainBool(true);
    expect(n.isNull(), isFalse);
  });
  test('Node.lookupByString()', () {
    final Node n = PlainBool(true);
    expect(() => n.lookupByString('x'), throwsA(isA<WrongKindException>()));
  });
  test('Node.lookupByNode()', () {
    final Node n = PlainBool(true);
    expect(
      () => n.lookupByNode(PlainString('x')),
      throwsA(isA<WrongKindException>()),
    );
  });
  test('Node.lookupByIndex()', () {
    final Node n = PlainBool(true);
    expect(() => n.lookupByIndex(0), throwsA(isA<WrongKindException>()));
  });
  test('Node.lookupBySegment()', () {
    final Node n = PlainBool(true);
    expect(
      () => n.lookupBySegment(const PathSegment.ofInt(0)),
      throwsA(isA<WrongKindException>()),
    );
  });
  test('Node.asInt()', () {
    final Node n = PlainBool(true);
    expect(() => n.asInt(), throwsA(isA<WrongKindException>()));
  });
  test('Node.asFloat()', () {
    final Node n = PlainBool(true);
    expect(() => n.asFloat(), throwsA(isA<WrongKindException>()));
  });
  test('Node.asString()', () {
    final Node n = PlainBool(true);
    expect(() => n.asString(), throwsA(isA<WrongKindException>()));
  });
  test('Node.asBytes()', () {
    final Node n = PlainBool(true);
    expect(() => n.asBytes(), throwsA(isA<WrongKindException>()));
  });
  test('Node.asLink()', () {
    final Node n = PlainBool(true);
    expect(() => n.asLink(), throwsA(isA<WrongKindException>()));
  });
  test('Node.asBool()', () {
    final Node n = PlainInt(1);
    expect(n.asBool, throwsA(isA<WrongKindException>()));
  });
  test('Node.mapIterator()', () {
    final Node n = PlainBool(true);
    expect(n.mapIterator(), isNull);
  });
  test('Node.listIterator()', () {
    final Node n = PlainBool(true);
    expect(n.listIterator(), isNull);
  });
  test('Node.length()', () {
    final Node n = PlainBool(true);
    expect(n.length(), -1);
  });
  test('Node.isAbsent()', () {
    final Node n = PlainBool(true);
    expect(n.isAbsent(), isFalse);
  });
  test('Node.isNull()', () {
    final Node n = PlainBool(true);
    expect(n.isNull(), isFalse);
  });
  test('BaseNode.typeName()', () {
    final BaseNode n = PlainBool(true);
    expect(n.typeName, 'bool');
  });
  test('Node.kind()', () {
    final Node n = PlainBool(true);
    expect(n.kind(), Kind.bool_);
  });
  test('Node.prototype()', () {
    final Node n = PlainBool(true);
    expect(n.prototype(), isA<PrototypeBool>());
  });
  test('BaseAssembler.beginMap()', () {
    final BaseAssembler b = PlainIntAssembler();
    expect(() => b.beginMap(0), throwsA(isA<WrongKindException>()));
  });
  test('BaseAssembler.beginList()', () {
    final BaseAssembler b = PlainIntAssembler();
    expect(() => b.beginList(0), throwsA(isA<WrongKindException>()));
  });
  test('BaseAssembler.assignNull()', () {
    final BaseAssembler b = PlainIntAssembler();
    expect(() => b.assignNull(), throwsA(isA<WrongKindException>()));
  });
  test('BaseAssembler.assignBool()', () {
    final BaseAssembler b = PlainIntAssembler();
    expect(() => b.assignBool(true), throwsA(isA<WrongKindException>()));
  });
  test('BaseAssembler.assignFloat()', () {
    final BaseAssembler b = PlainIntAssembler();
    expect(() => b.assignFloat(1.0), throwsA(isA<WrongKindException>()));
  });
  test('BaseAssembler.assignString()', () {
    final BaseAssembler b = PlainIntAssembler();
    expect(() => b.assignString('x'), throwsA(isA<WrongKindException>()));
  });
  test('BaseAssembler.assignBytes()', () {
    final BaseAssembler b = PlainIntAssembler();
    expect(
      () => b.assignBytes(Uint8List(0)),
      throwsA(isA<WrongKindException>()),
    );
  });
  test('BaseAssembler.assignLink()', () {
    final BaseAssembler b = PlainIntAssembler();
    expect(
      () => b.assignLink(
        CidLink(
          Cid.decode(
            'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
          ),
        ),
      ),
      throwsA(isA<WrongKindException>()),
    );
  });
  test('BaseAssembler.assignInt()', () {
    final BaseAssembler b = PlainBoolAssembler();
    expect(() => b.assignInt(1), throwsA(isA<WrongKindException>()));
  });
  test('BaseAssembler.typeName()', () {
    final BaseAssembler b = PlainIntAssembler();
    expect(b.typeName, 'int');
  });
  test('BaseAssembler.selfKind()', () {
    final BaseAssembler b = PlainIntAssembler();
    expect(b.selfKind, Kind.int_);
  });
  test('PlainList.typeName()', () {
    expect(PlainList([PlainInt(7)]).typeName, 'list');
  });
  test('PlainList.kind()', () {
    expect(PlainList([PlainInt(7)]).kind(), Kind.list);
  });
  test('PlainList.length()', () {
    expect(PlainList([PlainInt(7)]).length(), 1);
  });
  test('PlainList.prototype()', () {
    expect(PlainList([PlainInt(7)]).prototype(), isA<PrototypeList>());
  });
  test('PlainList.lookupByIndex()', () {
    expect(PlainList([PlainInt(7)]).lookupByIndex(0).asInt(), 7);
    expect(
      () => PlainList([PlainInt(7)]).lookupByIndex(1),
      throwsA(isA<NotExistsException>()),
    );
  });
  test('PlainList.lookupBySegment()', () {
    expect(
      PlainList([
        PlainInt(7),
      ]).lookupBySegment(const PathSegment.ofInt(0)).asInt(),
      7,
    );
  });
  test('PlainList.listIterator()', () {
    expect(PlainList([PlainInt(7)]).listIterator().next().$2.asInt(), 7);
  });
  test('PrototypeList.newBuilder()', () {
    final b = const PrototypeList().newBuilder();
    b.beginList(0).finish();
    expect(b.build().length(), 0);
  });
  test('PlainListAssembler.typeName()', () {
    expect(PlainListAssembler().typeName, 'list');
  });
  test('PlainListAssembler.selfKind()', () {
    expect(PlainListAssembler().selfKind, Kind.list);
  });
  test('PlainListAssembler.beginList()', () {
    final b = PlainListAssembler();
    expect(b.beginList(0), same(b));
  });
  test('PlainListAssembler.assignNode()', () {
    final b = PlainListAssembler();
    b.assignNode(PlainList([PlainInt(7)]));
    expect(b.build().lookupByIndex(0).asInt(), 7);
  });
  test('PlainListAssembler.prototype()', () {
    expect(PlainListAssembler().prototype(), isA<PrototypeList>());
  });
  test('PlainListAssembler.build()', () {
    final b = PlainListAssembler();
    expect(b.build, throwsStateError);
    b.beginList(0).finish();
    expect(b.build().length(), 0);
  });
  test('PlainListAssembler.reset()', () {
    final b = PlainListAssembler();
    b.assignNode(PlainList([PlainInt(7)]));
    b.reset();
    b.beginList(0).finish();
    expect(b.build().length(), 0);
  });
  test('PlainListAssembler.finish()', () {
    final a = PlainListAssembler();
    final b = a;
    a.beginList(1);
    a.finish();
    expect(b.build().length(), 0);
    expect(a.finish, throwsStateError);
  });
  test('PlainListAssembler.valuePrototype()', () {
    final a = PlainListAssembler();
    final b = a;
    a.beginList(1);
    expect(a.valuePrototype(0), isA<PrototypeAny>());
  });
  test('PlainListAssembler.assembleValue()', () {
    final a = PlainListAssembler();
    final b = a;
    a.beginList(1);
    a.assembleValue().assignInt(7);
    a.finish();
    expect(b.build().lookupByIndex(0).asInt(), 7);
  });
  test('ListAssembler.finish()', () {
    final b = PlainListAssembler();
    final ListAssembler a = b.beginList(1);
    a.finish();
    expect(b.build().length(), 0);
    expect(a.finish, throwsStateError);
  });
  test('ListAssembler.valuePrototype()', () {
    final b = PlainListAssembler();
    final ListAssembler a = b.beginList(1);
    expect(a.valuePrototype(0), isA<PrototypeAny>());
  });
  test('ListAssembler.assembleValue()', () {
    final b = PlainListAssembler();
    final ListAssembler a = b.beginList(1);
    a.assembleValue().assignInt(7);
    a.finish();
    expect(b.build().lookupByIndex(0).asInt(), 7);
  });
  test('ListIterator.done()', () {
    final ListIterator it = PlainList([PlainInt(7)]).listIterator();
    expect(it.done(), isFalse);
    expect(it.next().$2.asInt(), 7);
    expect(it.done(), isTrue);
    expect(it.next, throwsA(isA<IteratorOverreadException>()));
  });
  test('ListIterator.next()', () {
    final ListIterator it = PlainList([PlainInt(7)]).listIterator();
    expect(it.done(), isFalse);
    expect(it.next().$2.asInt(), 7);
    expect(it.done(), isTrue);
    expect(it.next, throwsA(isA<IteratorOverreadException>()));
  });
  test('PlainMap.typeName()', () {
    expect(PlainMap({'x': PlainInt(7)}).typeName, 'map');
  });
  test('PlainMap.kind()', () {
    expect(PlainMap({'x': PlainInt(7)}).kind(), Kind.map);
  });
  test('PlainMap.length()', () {
    expect(PlainMap({'x': PlainInt(7)}).length(), 1);
  });
  test('PlainMap.prototype()', () {
    expect(PlainMap({'x': PlainInt(7)}).prototype(), isA<PrototypeMap>());
  });
  test('PlainMap.lookupByString()', () {
    expect(PlainMap({'x': PlainInt(7)}).lookupByString('x').asInt(), 7);
    expect(
      () => PlainMap({'x': PlainInt(7)}).lookupByString('missing'),
      throwsA(isA<NotExistsException>()),
    );
  });
  test('PlainMap.lookupBySegment()', () {
    expect(
      PlainMap({
        'x': PlainInt(7),
      }).lookupBySegment(const PathSegment.ofString('x')).asInt(),
      7,
    );
  });
  test('PlainMap.mapIterator()', () {
    expect(PlainMap({'x': PlainInt(7)}).mapIterator().next().$2.asInt(), 7);
  });
  test('PlainMap.lookupByNode()', () {
    expect(
      PlainMap({'x': PlainInt(7)}).lookupByNode(PlainString('x')).asInt(),
      7,
    );
  });
  test('PrototypeMap.newBuilder()', () {
    final b = const PrototypeMap().newBuilder();
    b.beginMap(0).finish();
    expect(b.build().length(), 0);
  });
  test('PlainMapAssembler.typeName()', () {
    expect(PlainMapAssembler().typeName, 'map');
  });
  test('PlainMapAssembler.selfKind()', () {
    expect(PlainMapAssembler().selfKind, Kind.map);
  });
  test('PlainMapAssembler.beginMap()', () {
    final b = PlainMapAssembler();
    expect(b.beginMap(0), same(b));
  });
  test('PlainMapAssembler.assignNode()', () {
    final b = PlainMapAssembler();
    b.assignNode(PlainMap({'x': PlainInt(7)}));
    expect(b.build().lookupByString('x').asInt(), 7);
  });
  test('PlainMapAssembler.prototype()', () {
    expect(PlainMapAssembler().prototype(), isA<PrototypeMap>());
  });
  test('PlainMapAssembler.build()', () {
    final b = PlainMapAssembler();
    expect(b.build, throwsStateError);
    b.beginMap(0).finish();
    expect(b.build().length(), 0);
  });
  test('PlainMapAssembler.reset()', () {
    final b = PlainMapAssembler();
    b.assignNode(PlainMap({'x': PlainInt(7)}));
    b.reset();
    b.beginMap(0).finish();
    expect(b.build().length(), 0);
  });
  test('PlainMapAssembler.finish()', () {
    final a = PlainMapAssembler();
    final b = a;
    a.beginMap(1);
    a.finish();
    expect(b.build().length(), 0);
    expect(a.finish, throwsStateError);
  });
  test('PlainMapAssembler.valuePrototype()', () {
    final a = PlainMapAssembler();
    final b = a;
    a.beginMap(1);
    expect(a.valuePrototype('x'), isA<PrototypeAny>());
  });
  test('PlainMapAssembler.assembleValue()', () {
    final a = PlainMapAssembler();
    final b = a;
    a.beginMap(1);
    a.assembleKey().assignString('x');
    a.assembleValue().assignInt(7);
    a.finish();
    expect(b.build().lookupByString('x').asInt(), 7);
  });
  test('PlainMapAssembler.assembleKey()', () {
    final a = PlainMapAssembler();
    final b = a;
    a.beginMap(1);
    a.assembleKey().assignString('x');
    a.assembleValue().assignInt(7);
    a.finish();
    expect(b.build().lookupByString('x').asInt(), 7);
  });
  test('PlainMapAssembler.assembleEntry()', () {
    final a = PlainMapAssembler();
    final b = a;
    a.beginMap(1);
    a.assembleEntry('x').assignInt(7);
    expect(() => a.assembleEntry('x'), throwsA(isA<RepeatedMapKeyException>()));
    a.finish();
    expect(b.build().lookupByString('x').asInt(), 7);
  });
  test('PlainMapAssembler.keyPrototype()', () {
    final a = PlainMapAssembler();
    final b = a;
    a.beginMap(1);
    expect(a.keyPrototype(), isA<PrototypeString>());
  });
  test('MapAssembler.finish()', () {
    final b = PlainMapAssembler();
    final MapAssembler a = b.beginMap(1);
    a.finish();
    expect(b.build().length(), 0);
    expect(a.finish, throwsStateError);
  });
  test('MapAssembler.valuePrototype()', () {
    final b = PlainMapAssembler();
    final MapAssembler a = b.beginMap(1);
    expect(a.valuePrototype('x'), isA<PrototypeAny>());
  });
  test('MapAssembler.assembleValue()', () {
    final b = PlainMapAssembler();
    final MapAssembler a = b.beginMap(1);
    a.assembleKey().assignString('x');
    a.assembleValue().assignInt(7);
    a.finish();
    expect(b.build().lookupByString('x').asInt(), 7);
  });
  test('MapAssembler.assembleKey()', () {
    final b = PlainMapAssembler();
    final MapAssembler a = b.beginMap(1);
    a.assembleKey().assignString('x');
    a.assembleValue().assignInt(7);
    a.finish();
    expect(b.build().lookupByString('x').asInt(), 7);
  });
  test('MapAssembler.assembleEntry()', () {
    final b = PlainMapAssembler();
    final MapAssembler a = b.beginMap(1);
    a.assembleEntry('x').assignInt(7);
    expect(() => a.assembleEntry('x'), throwsA(isA<RepeatedMapKeyException>()));
    a.finish();
    expect(b.build().lookupByString('x').asInt(), 7);
  });
  test('MapAssembler.keyPrototype()', () {
    final b = PlainMapAssembler();
    final MapAssembler a = b.beginMap(1);
    expect(a.keyPrototype(), isA<PrototypeString>());
  });
  test('MapIterator.done()', () {
    final MapIterator it = PlainMap({'x': PlainInt(7)}).mapIterator();
    expect(it.done(), isFalse);
    expect(it.next().$2.asInt(), 7);
    expect(it.done(), isTrue);
    expect(it.next, throwsA(isA<IteratorOverreadException>()));
  });
  test('MapIterator.next()', () {
    final MapIterator it = PlainMap({'x': PlainInt(7)}).mapIterator();
    expect(it.done(), isFalse);
    expect(it.next().$2.asInt(), 7);
    expect(it.done(), isTrue);
    expect(it.next, throwsA(isA<IteratorOverreadException>()));
  });
  test('ValueAssembler.assignBool()', () {
    Node? result;
    final a = ValueAssembler((n) => result = n);
    a.assignBool(true);
    expect(result!.kind(), Kind.bool_);
    expect(() => a.assignBool(true), throwsStateError);
  });
  test('ValueAssembler.assignInt()', () {
    Node? result;
    final a = ValueAssembler((n) => result = n);
    a.assignInt(7);
    expect(result!.kind(), Kind.int_);
    expect(() => a.assignInt(7), throwsStateError);
  });
  test('ValueAssembler.assignFloat()', () {
    Node? result;
    final a = ValueAssembler((n) => result = n);
    a.assignFloat(1.5);
    expect(result!.kind(), Kind.float);
    expect(() => a.assignFloat(1.5), throwsStateError);
  });
  test('ValueAssembler.assignString()', () {
    Node? result;
    final a = ValueAssembler((n) => result = n);
    a.assignString('x');
    expect(result!.kind(), Kind.string);
    expect(() => a.assignString('x'), throwsStateError);
  });
  test('ValueAssembler.assignBytes()', () {
    Node? result;
    final a = ValueAssembler((n) => result = n);
    a.assignBytes(Uint8List(1));
    expect(result!.kind(), Kind.bytes);
    expect(() => a.assignBytes(Uint8List(1)), throwsStateError);
  });
  test('ValueAssembler.assignLink()', () {
    Node? result;
    final a = ValueAssembler((n) => result = n);
    a.assignLink(
      CidLink(
        Cid.decode(
          'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
        ),
      ),
    );
    expect(result!.kind(), Kind.link);
    expect(
      () => a.assignLink(
        CidLink(
          Cid.decode(
            'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
          ),
        ),
      ),
      throwsStateError,
    );
  });
  test('ValueAssembler.assignNull()', () {
    Node? result;
    final a = ValueAssembler((n) => result = n);
    a.assignNull();
    expect(result!.kind(), Kind.null_);
    expect(() => a.assignNull(), throwsStateError);
  });
  test('ValueAssembler.assignNode()', () {
    Node? result;
    final a = ValueAssembler((n) => result = n);
    final n = PlainInt(7);
    a.assignNode(n);
    expect(result, same(n));
  });
  test('ValueAssembler.prototype()', () {
    expect(ValueAssembler((_) {}).prototype(), isA<PrototypeAny>());
  });
  test('ValueAssembler.beginMap()', () {
    Node? result;
    final a = ValueAssembler((n) => result = n);
    final nested = a.beginMap(0);
    expect(result, isNull);
    nested.finish();
    expect(result!.kind(), Kind.map);
  });
  test('ValueAssembler.beginList()', () {
    Node? result;
    final a = ValueAssembler((n) => result = n);
    final nested = a.beginList(0);
    expect(result, isNull);
    nested.finish();
    expect(result!.kind(), Kind.list);
  });

  test('Basicnode.ofBool()', () {
    expect(Basicnode.ofBool(true).asBool(), true);
  });
  test('Basicnode.boolNode()', () {
    expect(Basicnode.boolNode(true).asBool(), true);
  });
  test('PlainBool.typeName()', () {
    expect(PlainBool(true).typeName, 'bool');
  });
  test('PlainBool.kind()', () {
    expect(PlainBool(true).kind(), Kind.bool_);
  });
  test('PlainBool.asBool()', () {
    final value = true;
    expect(PlainBool(value).asBool(), true);
  });
  test('PlainBool.prototype()', () {
    expect(PlainBool(true).prototype(), isA<PrototypeBool>());
  });
  test('PrototypeBool.newBuilder()', () {
    final b = const PrototypeBool().newBuilder();
    b.assignBool(true);
    expect(b.build().kind(), Kind.bool_);
  });
  test('PlainBoolAssembler.typeName()', () {
    expect(PlainBoolAssembler().typeName, 'bool');
  });
  test('PlainBoolAssembler.selfKind()', () {
    expect(PlainBoolAssembler().selfKind, Kind.bool_);
  });
  test('PlainBoolAssembler.assignBool()', () {
    final b = PlainBoolAssembler();
    b.assignBool(true);
    expect(b.build().kind(), Kind.bool_);
  });
  test('PlainBoolAssembler.assignNode()', () {
    final b = PlainBoolAssembler();
    b.assignNode(PlainBool(true));
    expect(b.build().kind(), Kind.bool_);
  });
  test('PlainBoolAssembler.build()', () {
    final b = PlainBoolAssembler();
    b.assignBool(true);
    expect(b.build().kind(), Kind.bool_);
  });
  test('PlainBoolAssembler.prototype()', () {
    expect(PlainBoolAssembler().prototype(), isA<PrototypeBool>());
  });
  test('PlainBoolAssembler.reset()', () {
    final b = PlainBoolAssembler();
    b.assignBool(true);
    b.reset();
    expect(b.build, throwsA(isA<TypeError>()));
    b.assignBool(true);
    expect(b.build().kind(), Kind.bool_);
  });
  test('Basicnode.ofInt()', () {
    expect(Basicnode.ofInt(42).asInt(), 42);
  });
  test('Basicnode.intNode()', () {
    expect(Basicnode.intNode(42).asInt(), 42);
  });
  test('PlainInt.typeName()', () {
    expect(PlainInt(42).typeName, 'int');
  });
  test('PlainInt.kind()', () {
    expect(PlainInt(42).kind(), Kind.int_);
  });
  test('PlainInt.asInt()', () {
    final value = 42;
    expect(PlainInt(value).asInt(), 42);
  });
  test('PlainInt.prototype()', () {
    expect(PlainInt(42).prototype(), isA<PrototypeInt>());
  });
  test('PrototypeInt.newBuilder()', () {
    final b = const PrototypeInt().newBuilder();
    b.assignInt(42);
    expect(b.build().kind(), Kind.int_);
  });
  test('PlainIntAssembler.typeName()', () {
    expect(PlainIntAssembler().typeName, 'int');
  });
  test('PlainIntAssembler.selfKind()', () {
    expect(PlainIntAssembler().selfKind, Kind.int_);
  });
  test('PlainIntAssembler.assignInt()', () {
    final b = PlainIntAssembler();
    b.assignInt(42);
    expect(b.build().kind(), Kind.int_);
  });
  test('PlainIntAssembler.assignNode()', () {
    final b = PlainIntAssembler();
    b.assignNode(PlainInt(42));
    expect(b.build().kind(), Kind.int_);
  });
  test('PlainIntAssembler.build()', () {
    final b = PlainIntAssembler();
    b.assignInt(42);
    expect(b.build().kind(), Kind.int_);
  });
  test('PlainIntAssembler.prototype()', () {
    expect(PlainIntAssembler().prototype(), isA<PrototypeInt>());
  });
  test('PlainIntAssembler.reset()', () {
    final b = PlainIntAssembler();
    b.assignInt(42);
    b.reset();
    expect(b.build, throwsA(isA<TypeError>()));
    b.assignInt(42);
    expect(b.build().kind(), Kind.int_);
  });
  test('Basicnode.ofFloat()', () {
    expect(Basicnode.ofFloat(1.5).asFloat(), 1.5);
  });
  test('Basicnode.floatNode()', () {
    expect(Basicnode.floatNode(1.5).asFloat(), 1.5);
  });
  test('PlainFloat.typeName()', () {
    expect(PlainFloat(1.5).typeName, 'float');
  });
  test('PlainFloat.kind()', () {
    expect(PlainFloat(1.5).kind(), Kind.float);
  });
  test('PlainFloat.asFloat()', () {
    final value = 1.5;
    expect(PlainFloat(value).asFloat(), 1.5);
  });
  test('PlainFloat.prototype()', () {
    expect(PlainFloat(1.5).prototype(), isA<PrototypeFloat>());
  });
  test('PrototypeFloat.newBuilder()', () {
    final b = const PrototypeFloat().newBuilder();
    b.assignFloat(1.5);
    expect(b.build().kind(), Kind.float);
  });
  test('PlainFloatAssembler.typeName()', () {
    expect(PlainFloatAssembler().typeName, 'float');
  });
  test('PlainFloatAssembler.selfKind()', () {
    expect(PlainFloatAssembler().selfKind, Kind.float);
  });
  test('PlainFloatAssembler.assignFloat()', () {
    final b = PlainFloatAssembler();
    b.assignFloat(1.5);
    expect(b.build().kind(), Kind.float);
  });
  test('PlainFloatAssembler.assignNode()', () {
    final b = PlainFloatAssembler();
    b.assignNode(PlainFloat(1.5));
    expect(b.build().kind(), Kind.float);
  });
  test('PlainFloatAssembler.build()', () {
    final b = PlainFloatAssembler();
    b.assignFloat(1.5);
    expect(b.build().kind(), Kind.float);
  });
  test('PlainFloatAssembler.prototype()', () {
    expect(PlainFloatAssembler().prototype(), isA<PrototypeFloat>());
  });
  test('PlainFloatAssembler.reset()', () {
    final b = PlainFloatAssembler();
    b.assignFloat(1.5);
    b.reset();
    expect(b.build, throwsA(isA<TypeError>()));
    b.assignFloat(1.5);
    expect(b.build().kind(), Kind.float);
  });
  test('Basicnode.ofString()', () {
    expect(Basicnode.ofString('abc').asString(), 'abc');
  });
  test('Basicnode.stringNode()', () {
    expect(Basicnode.stringNode('abc').asString(), 'abc');
  });
  test('PlainString.typeName()', () {
    expect(PlainString('abc').typeName, 'string');
  });
  test('PlainString.kind()', () {
    expect(PlainString('abc').kind(), Kind.string);
  });
  test('PlainString.asString()', () {
    final value = 'abc';
    expect(PlainString(value).asString(), 'abc');
  });
  test('PlainString.prototype()', () {
    expect(PlainString('abc').prototype(), isA<PrototypeString>());
  });
  test('PrototypeString.newBuilder()', () {
    final b = const PrototypeString().newBuilder();
    b.assignString('abc');
    expect(b.build().kind(), Kind.string);
  });
  test('PlainStringAssembler.typeName()', () {
    expect(PlainStringAssembler().typeName, 'string');
  });
  test('PlainStringAssembler.selfKind()', () {
    expect(PlainStringAssembler().selfKind, Kind.string);
  });
  test('PlainStringAssembler.assignString()', () {
    final b = PlainStringAssembler();
    b.assignString('abc');
    expect(b.build().kind(), Kind.string);
  });
  test('PlainStringAssembler.assignNode()', () {
    final b = PlainStringAssembler();
    b.assignNode(PlainString('abc'));
    expect(b.build().kind(), Kind.string);
  });
  test('PlainStringAssembler.build()', () {
    final b = PlainStringAssembler();
    b.assignString('abc');
    expect(b.build().kind(), Kind.string);
  });
  test('PlainStringAssembler.prototype()', () {
    expect(PlainStringAssembler().prototype(), isA<PrototypeString>());
  });
  test('PlainStringAssembler.reset()', () {
    final b = PlainStringAssembler();
    b.assignString('abc');
    b.reset();
    expect(b.build, throwsA(isA<TypeError>()));
    b.assignString('abc');
    expect(b.build().kind(), Kind.string);
  });
  test('Basicnode.ofBytes()', () {
    expect(Basicnode.ofBytes(Uint8List.fromList([1, 2])).asBytes(), [1, 2]);
  });
  test('Basicnode.bytesNode()', () {
    expect(Basicnode.bytesNode(Uint8List.fromList([1, 2])).asBytes(), [1, 2]);
  });
  test('PlainBytes.typeName()', () {
    expect(PlainBytes(Uint8List.fromList([1, 2])).typeName, 'bytes');
  });
  test('PlainBytes.kind()', () {
    expect(PlainBytes(Uint8List.fromList([1, 2])).kind(), Kind.bytes);
  });
  test('PlainBytes.asBytes()', () {
    final value = Uint8List.fromList([1, 2]);
    expect(PlainBytes(value).asBytes(), [1, 2]);
  });
  test('PlainBytes.prototype()', () {
    expect(
      PlainBytes(Uint8List.fromList([1, 2])).prototype(),
      isA<PrototypeBytes>(),
    );
  });
  test('PrototypeBytes.newBuilder()', () {
    final b = const PrototypeBytes().newBuilder();
    b.assignBytes(Uint8List.fromList([1, 2]));
    expect(b.build().kind(), Kind.bytes);
  });
  test('PlainBytesAssembler.typeName()', () {
    expect(PlainBytesAssembler().typeName, 'bytes');
  });
  test('PlainBytesAssembler.selfKind()', () {
    expect(PlainBytesAssembler().selfKind, Kind.bytes);
  });
  test('PlainBytesAssembler.assignBytes()', () {
    final b = PlainBytesAssembler();
    b.assignBytes(Uint8List.fromList([1, 2]));
    expect(b.build().kind(), Kind.bytes);
  });
  test('PlainBytesAssembler.assignNode()', () {
    final b = PlainBytesAssembler();
    b.assignNode(PlainBytes(Uint8List.fromList([1, 2])));
    expect(b.build().kind(), Kind.bytes);
  });
  test('PlainBytesAssembler.build()', () {
    final b = PlainBytesAssembler();
    b.assignBytes(Uint8List.fromList([1, 2]));
    expect(b.build().kind(), Kind.bytes);
  });
  test('PlainBytesAssembler.prototype()', () {
    expect(PlainBytesAssembler().prototype(), isA<PrototypeBytes>());
  });
  test('PlainBytesAssembler.reset()', () {
    final b = PlainBytesAssembler();
    b.assignBytes(Uint8List.fromList([1, 2]));
    b.reset();
    expect(b.build, throwsA(isA<TypeError>()));
    b.assignBytes(Uint8List.fromList([1, 2]));
    expect(b.build().kind(), Kind.bytes);
  });
  test('Basicnode.ofLink()', () {
    final link = CidLink(
      Cid.decode('bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi'),
    );
    expect(Basicnode.ofLink(link).asLink(), same(link));
  });
  test('Basicnode.linkNode()', () {
    final link = CidLink(
      Cid.decode('bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi'),
    );
    expect(Basicnode.linkNode(link).asLink(), same(link));
  });
  test('PlainLink.typeName()', () {
    expect(
      PlainLink(
        CidLink(
          Cid.decode(
            'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
          ),
        ),
      ).typeName,
      'link',
    );
  });
  test('PlainLink.kind()', () {
    expect(
      PlainLink(
        CidLink(
          Cid.decode(
            'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
          ),
        ),
      ).kind(),
      Kind.link,
    );
  });
  test('PlainLink.asLink()', () {
    final value = CidLink(
      Cid.decode('bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi'),
    );
    expect(PlainLink(value).asLink(), same(value));
  });
  test('PlainLink.prototype()', () {
    expect(
      PlainLink(
        CidLink(
          Cid.decode(
            'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
          ),
        ),
      ).prototype(),
      isA<PrototypeLink>(),
    );
  });
  test('PrototypeLink.newBuilder()', () {
    final b = const PrototypeLink().newBuilder();
    b.assignLink(
      CidLink(
        Cid.decode(
          'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
        ),
      ),
    );
    expect(b.build().kind(), Kind.link);
  });
  test('PlainLinkAssembler.typeName()', () {
    expect(PlainLinkAssembler().typeName, 'link');
  });
  test('PlainLinkAssembler.selfKind()', () {
    expect(PlainLinkAssembler().selfKind, Kind.link);
  });
  test('PlainLinkAssembler.assignLink()', () {
    final b = PlainLinkAssembler();
    b.assignLink(
      CidLink(
        Cid.decode(
          'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
        ),
      ),
    );
    expect(b.build().kind(), Kind.link);
  });
  test('PlainLinkAssembler.assignNode()', () {
    final b = PlainLinkAssembler();
    b.assignNode(
      PlainLink(
        CidLink(
          Cid.decode(
            'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
          ),
        ),
      ),
    );
    expect(b.build().kind(), Kind.link);
  });
  test('PlainLinkAssembler.build()', () {
    final b = PlainLinkAssembler();
    b.assignLink(
      CidLink(
        Cid.decode(
          'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
        ),
      ),
    );
    expect(b.build().kind(), Kind.link);
  });
  test('PlainLinkAssembler.prototype()', () {
    expect(PlainLinkAssembler().prototype(), isA<PrototypeLink>());
  });
  test('PlainLinkAssembler.reset()', () {
    final b = PlainLinkAssembler();
    b.assignLink(
      CidLink(
        Cid.decode(
          'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
        ),
      ),
    );
    b.reset();
    expect(b.build, throwsA(isA<TypeError>()));
    b.assignLink(
      CidLink(
        Cid.decode(
          'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
        ),
      ),
    );
    expect(b.build().kind(), Kind.link);
  });
  test('AnyBuilder.assignBool()', () {
    final AnyBuilder b = AnyBuilder();
    b.assignBool(true);
    expect((b as NodeBuilder).build().kind(), Kind.bool_);
  });
  test('AnyBuilder.assignInt()', () {
    final AnyBuilder b = AnyBuilder();
    b.assignInt(42);
    expect((b as NodeBuilder).build().kind(), Kind.int_);
  });
  test('AnyBuilder.assignFloat()', () {
    final AnyBuilder b = AnyBuilder();
    b.assignFloat(1.5);
    expect((b as NodeBuilder).build().kind(), Kind.float);
  });
  test('AnyBuilder.assignString()', () {
    final AnyBuilder b = AnyBuilder();
    b.assignString('abc');
    expect((b as NodeBuilder).build().kind(), Kind.string);
  });
  test('AnyBuilder.assignBytes()', () {
    final AnyBuilder b = AnyBuilder();
    b.assignBytes(Uint8List.fromList([1, 2]));
    expect((b as NodeBuilder).build().kind(), Kind.bytes);
  });
  test('AnyBuilder.assignLink()', () {
    final AnyBuilder b = AnyBuilder();
    b.assignLink(
      CidLink(
        Cid.decode(
          'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
        ),
      ),
    );
    expect((b as NodeBuilder).build().kind(), Kind.link);
  });
  test('AnyBuilder.assignNull()', () {
    final AnyBuilder b = AnyBuilder();
    b.assignNull();
    expect((b as NodeBuilder).build().isNull(), isTrue);
  });
  test('AnyBuilder.assignNode()', () {
    final AnyBuilder b = AnyBuilder();
    final n = PlainInt(9);
    b.assignNode(n);
    expect((b as NodeBuilder).build(), same(n));
  });
  test('AnyBuilder.prototype()', () {
    final AnyBuilder b = AnyBuilder();
    expect(b.prototype(), isA<PrototypeAny>());
  });
  test('AnyBuilder.beginMap()', () {
    final AnyBuilder b = AnyBuilder();
    b.beginMap(0).finish();
    expect((b as NodeBuilder).build().kind(), Kind.map);
  });
  test('AnyBuilder.beginList()', () {
    final AnyBuilder b = AnyBuilder();
    b.beginList(0).finish();
    expect((b as NodeBuilder).build().kind(), Kind.list);
  });
  test('NodeAssembler.assignBool()', () {
    final NodeAssembler b = AnyBuilder();
    b.assignBool(true);
    expect((b as NodeBuilder).build().kind(), Kind.bool_);
  });
  test('NodeAssembler.assignInt()', () {
    final NodeAssembler b = AnyBuilder();
    b.assignInt(42);
    expect((b as NodeBuilder).build().kind(), Kind.int_);
  });
  test('NodeAssembler.assignFloat()', () {
    final NodeAssembler b = AnyBuilder();
    b.assignFloat(1.5);
    expect((b as NodeBuilder).build().kind(), Kind.float);
  });
  test('NodeAssembler.assignString()', () {
    final NodeAssembler b = AnyBuilder();
    b.assignString('abc');
    expect((b as NodeBuilder).build().kind(), Kind.string);
  });
  test('NodeAssembler.assignBytes()', () {
    final NodeAssembler b = AnyBuilder();
    b.assignBytes(Uint8List.fromList([1, 2]));
    expect((b as NodeBuilder).build().kind(), Kind.bytes);
  });
  test('NodeAssembler.assignLink()', () {
    final NodeAssembler b = AnyBuilder();
    b.assignLink(
      CidLink(
        Cid.decode(
          'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
        ),
      ),
    );
    expect((b as NodeBuilder).build().kind(), Kind.link);
  });
  test('NodeAssembler.assignNull()', () {
    final NodeAssembler b = AnyBuilder();
    b.assignNull();
    expect((b as NodeBuilder).build().isNull(), isTrue);
  });
  test('NodeAssembler.assignNode()', () {
    final NodeAssembler b = AnyBuilder();
    final n = PlainInt(9);
    b.assignNode(n);
    expect((b as NodeBuilder).build(), same(n));
  });
  test('NodeAssembler.prototype()', () {
    final NodeAssembler b = AnyBuilder();
    expect(b.prototype(), isA<PrototypeAny>());
  });
  test('NodeAssembler.beginMap()', () {
    final NodeAssembler b = AnyBuilder();
    b.beginMap(0).finish();
    expect((b as NodeBuilder).build().kind(), Kind.map);
  });
  test('NodeAssembler.beginList()', () {
    final NodeAssembler b = AnyBuilder();
    b.beginList(0).finish();
    expect((b as NodeBuilder).build().kind(), Kind.list);
  });
  test('AnyBuilder.build()', () {
    final AnyBuilder b = AnyBuilder();
    expect(b.build, throwsStateError);
    b.assignInt(2);
    expect(b.build().asInt(), 2);
  });
  test('AnyBuilder.reset()', () {
    final AnyBuilder b = AnyBuilder();
    b.assignInt(2);
    b.reset();
    expect(b.build, throwsStateError);
    b.assignString("x");
    expect(b.build().asString(), "x");
  });
  test('NodeBuilder.build()', () {
    final NodeBuilder b = AnyBuilder();
    expect(b.build, throwsStateError);
    b.assignInt(2);
    expect(b.build().asInt(), 2);
  });
  test('NodeBuilder.reset()', () {
    final NodeBuilder b = AnyBuilder();
    b.assignInt(2);
    b.reset();
    expect(b.build, throwsStateError);
    b.assignString("x");
    expect(b.build().asString(), "x");
  });
  test('PrototypeAny.newBuilder()', () {
    final PrototypeAny p = const PrototypeAny();
    final b = p.newBuilder();
    b.assignNull();
    expect(b.build().isNull(), isTrue);
  });
  test('NodePrototype.newBuilder()', () {
    final NodePrototype p = const PrototypeAny();
    final b = p.newBuilder();
    b.assignNull();
    expect(b.build().isNull(), isTrue);
  });
  test('PlainUint.typeName()', () {
    expect(const PlainUint(42).typeName, 'int');
  });
  test('PlainUint.kind()', () {
    expect(const PlainUint(42).kind(), Kind.int_);
  });
  test('PlainUint.asInt()', () {
    expect(const PlainUint(42).asInt(), 42);
  });
  test('PlainUint.asUint()', () {
    expect(const PlainUint(42).asUint(), 42);
  });
  test('PlainUint.prototype()', () {
    expect(const PlainUint(42).prototype(), isA<PrototypeInt>());
  });
  test('UintNode.asUint()', () {
    final UintNode n = PlainUint(42);
    expect(n.asUint(), 42);
  });

  final specs = SelectorSpecBuilder(prototype.any);
  Node body(SelectorSpec spec) => spec.node().mapIterator()!.next().$2;
  group('SelectorSpecBuilder [Atomic Audit]', () {
    test('matcher()', () {
      expect(specs.matcher().selector().decide(nullNode), isTrue);
    });
    test('matcherSubset()', () {
      expect(
        specs
            .matcherSubset(1, 3)
            .selector()
            .match(PlainString('abcd'))!
            .asString(),
        'bc',
      );
    });
    test('exploreRecursiveEdge()', () {
      expect(
        specs.exploreRecursiveEdge().node().lookupByString('@').kind(),
        Kind.map,
      );
    });
    test('exploreAll()', () {
      expect(specs.exploreAll(specs.matcher()).selector().interests(), isNull);
    });
    test('exploreIndex()', () {
      expect(
        specs
            .exploreIndex(2, specs.matcher())
            .selector()
            .interests()!
            .single
            .index(),
        2,
      );
    });
    test('exploreRange()', () {
      expect(
        specs
            .exploreRange(1, 3, specs.matcher())
            .selector()
            .interests()!
            .map((s) => s.index()),
        [1, 2],
      );
    });
    test('exploreUnion()', () {
      expect(
        specs.exploreUnion([specs.matcher()]).selector().decide(nullNode),
        isTrue,
      );
    });
    test('exploreFields()', () {
      expect(
        specs
            .exploreFields((f) => f.insert('x', specs.matcher()))
            .selector()
            .interests()!
            .single
            .toString(),
        'x',
      );
    });
    test('exploreInterpretAs()', () {
      expect(
        (specs.exploreInterpretAs('adl', specs.matcher()).selector()
                as Reifiable)
            .namedReifier,
        'adl',
      );
    });
    test('exploreRecursive()', () {
      expect(
        (specs
                    .exploreRecursive(
                      const RecursionLimit.depth(2),
                      specs.exploreAll(specs.exploreRecursiveEdge()),
                    )
                    .selector()
                as ExploreRecursive)
            .limit
            .depth,
        2,
      );
    });
  });
  group('SelectorSpec [Atomic Audit]', () {
    test('node()', () {
      expect(specs.matcher().node().lookupByString('.').length(), 0);
    });
    test('selector()', () {
      expect(specs.matcher().selector().decide(nullNode), isTrue);
    });
  });
  group('ExploreFieldsSpecBuilder [Atomic Audit]', () {
    test('insert()', () {
      final spec = specs.exploreFields((fields) {
        fields.insert('x', specs.matcher());
        fields.insert('y', specs.matcher());
      });
      expect(spec.selector().interests()!.map((s) => s.toString()), ['x', 'y']);
    });
  });
  group('ParseContext [Atomic Audit]', () {
    final parser = ParseContext();
    test('parseSelector()', () {
      expect(parser.parseSelector(specs.matcher().node()), isA<Matcher>());
      expect(
        () => parser.parseSelector(nullNode),
        throwsA(isA<SelectorParseException>()),
      );
    });
    test('parseMatcher()', () {
      expect(
        parser
            .parseMatcher(body(specs.matcherSubset(1, 3)))
            .match(PlainString('abcd'))!
            .asString(),
        'bc',
      );
      expect(
        () => parser.parseMatcher(nullNode),
        throwsA(isA<SelectorParseException>()),
      );
    });
    test('parseExploreAll()', () {
      expect(
        parser.parseExploreAll(body(specs.exploreAll(specs.matcher()))).next,
        isA<Matcher>(),
      );
    });
    test('parseExploreFields()', () {
      expect(
        parser
            .parseExploreFields(
              body(specs.exploreFields((f) => f.insert('x', specs.matcher()))),
            )
            .selections
            .keys,
        ['x'],
      );
    });
    test('parseExploreIndex()', () {
      expect(
        parser
            .parseExploreIndex(body(specs.exploreIndex(2, specs.matcher())))
            .index,
        2,
      );
    });
    test('parseExploreRange()', () {
      expect(
        parser
            .parseExploreRange(body(specs.exploreRange(1, 3, specs.matcher())))
            .end,
        3,
      );
      expect(
        () => parser.parseExploreRange(
          body(specs.exploreRange(3, 1, specs.matcher())),
        ),
        throwsA(isA<SelectorParseException>()),
      );
    });
    test('parseExploreUnion()', () {
      expect(
        parser
            .parseExploreUnion(body(specs.exploreUnion([specs.matcher()])))
            .members
            .single,
        isA<Matcher>(),
      );
    });
    test('parseExploreRecursiveEdge()', () {
      expect(
        () => parser.parseExploreRecursiveEdge(
          body(specs.exploreRecursiveEdge()),
        ),
        throwsA(isA<SelectorParseException>()),
      );
    });
    test('parseExploreRecursive()', () {
      expect(
        parser
            .parseExploreRecursive(
              body(
                specs.exploreRecursive(
                  const RecursionLimit.none(),
                  specs.exploreAll(specs.exploreRecursiveEdge()),
                ),
              ),
            )
            .limit
            .mode,
        RecursionLimitMode.none,
      );
    });
    test('parseExploreInterpretAs()', () {
      expect(
        parser
            .parseExploreInterpretAs(
              body(specs.exploreInterpretAs('adl', specs.matcher())),
            )
            .namedReifier,
        'adl',
      );
    });
    test('parseCondition()', () {
      expect(
        () => parser.parseCondition(specs.matcher().node()),
        throwsA(isA<SelectorParseException>()),
      );
    });
  });
  test('compileSelector()', () {
    expect(compileSelector(specs.matcher().node()), isA<Matcher>());
  });
  test('parseSelector()', () {
    expect(parseSelector(specs.matcher().node()), isA<Matcher>());
  });
  test('parseJsonSelector()', () {
    expect(parseJsonSelector('{".":{}}').lookupByString('.').kind(), Kind.map);
  });
  test('parseAndCompileJsonSelector()', () {
    expect(parseAndCompileJsonSelector('{".":{}}').decide(nullNode), isTrue);
  });
  group('Path [Atomic Audit]', () {
    test('toString()', () {
      expect(Path.parse('/a//2/').toString(), 'a/2');
    });
    test('segments()', () {
      final source = [const PathSegment.ofString('a')];
      final path = Path(source);
      source.clear();
      expect(path.segments.single.toString(), 'a');
    });
    test('length()', () {
      expect(Path.parse('a/2').length, 2);
      expect(Path.empty.length, 0);
    });
    test('join()', () {
      final path = Path.parse('a');
      expect(path.join(Path.parse('b/c')).toString(), 'a/b/c');
      expect(path.toString(), 'a');
    });
    test('appendSegment()', () {
      expect(
        Path.empty
            .appendSegment(const PathSegment.ofString('/'))
            .segments
            .single
            .toString(),
        '/',
      );
    });
    test('appendSegmentString()', () {
      expect(Path.parse('a').appendSegmentString('b').toString(), 'a/b');
    });
    test('appendSegmentInt()', () {
      expect(Path.parse('a').appendSegmentInt(2).toString(), 'a/2');
    });
    test('parent()', () {
      expect(Path.parse('a/b').parent.toString(), 'a');
      expect(Path.empty.parent.length, 0);
    });
    test('truncate()', () {
      expect(Path.parse('a/b/c').truncate(2).toString(), 'a/b');
    });
    test('last()', () {
      expect(Path.parse('a/b').last.toString(), 'b');
      expect(Path.empty.last.toString(), '');
    });
    test('pop()', () {
      expect(Path.parse('a/b').pop().toString(), 'a');
      expect(Path.empty.pop().length, 0);
    });
    test('shift()', () {
      final pair = Path.parse('a/b').shift();
      expect(pair.$1.toString(), 'a');
      expect(pair.$2.toString(), 'b');
      expect(Path.empty.shift().$2.length, 0);
    });
  });
  group('PathSegment [Atomic Audit]', () {
    test('toString()', () {
      expect(const PathSegment.ofInt(42).toString(), '42');
      expect(PathSegment.empty.toString(), '');
    });
    test('index()', () {
      expect(const PathSegment.ofString('42').index(), 42);
      expect(const PathSegment.ofInt(0).index(), 0);
      expect(
        () => const PathSegment.ofString('x').index(),
        throwsFormatException,
      );
    });
    test('equals()', () {
      expect(
        const PathSegment.ofString('2').equals(const PathSegment.ofInt(2)),
        isTrue,
      );
      expect(
        const PathSegment.ofString('02').equals(const PathSegment.ofInt(2)),
        isFalse,
      );
    });
  });
  final node = PlainString('foobarbaz!');
  const child = PathSegment.ofInt(1);
  const matcher = Matcher();
  final builder = prototype.list.newBuilder();
  final listAssembler = builder.beginList(3);
  for (var i = 0; i < 3; i++) {
    listAssembler.assembleValue().assignInt(i);
  }
  listAssembler.finish();
  final list = builder.build();
  group('Matcher [Atomic Audit]', () {
    test('interests()', () {
      expect(matcher.interests(), isEmpty);
    });
    test('explore()', () {
      expect(matcher.explore(node, child), isNull);
    });
    test('decide()', () {
      expect(matcher.decide(node), isTrue);
    });
    test('match()', () {
      expect(matcher.match(node), same(node));
    });
  });
  group('Slice [Atomic Audit]', () {
    test('apply()', () {
      expect(const Slice(1, 4).apply(node)!.asString(), 'oob');
      expect(const Slice(10, 11).apply(node), isNull);
      expect(
        const Slice(-2, -1)
            .apply(PlainBytes(Uint8List.fromList(node.asString().codeUnits)))!
            .asBytes(),
        [122],
      );
    });
    test('slice()', () {
      expect(const Slice(1, 4).slice(node)!.asString(), 'oob');
    });
  });
  group('ExploreAll [Atomic Audit]', () {
    const selector = ExploreAll(matcher);
    test('interests()', () {
      expect(selector.interests(), isNull);
    });
    test('explore()', () {
      expect(selector.explore(list, child), same(matcher));
    });
    test('decide()', () {
      expect(selector.decide(node), isFalse);
    });
    test('match()', () {
      expect(selector.match(node), isNull);
    });
  });
  group('ExploreFields [Atomic Audit]', () {
    final selector = ExploreFields({'x': matcher});
    test('interests()', () {
      expect(selector.interests().single.toString(), 'x');
    });
    test('explore()', () {
      expect(
        selector.explore(node, const PathSegment.ofString('x')),
        same(matcher),
      );
      expect(selector.explore(node, child), isNull);
    });
    test('decide()', () {
      expect(selector.decide(node), isFalse);
    });
    test('match()', () {
      expect(selector.match(node), isNull);
    });
  });
  group('ExploreIndex [Atomic Audit]', () {
    const selector = ExploreIndex(1, matcher);
    test('interests()', () {
      expect(selector.interests().single.index(), 1);
    });
    test('explore()', () {
      expect(selector.explore(list, child), same(matcher));
      expect(selector.explore(list, const PathSegment.ofInt(2)), isNull);
      expect(selector.explore(list, const PathSegment.ofString('x')), isNull);
      expect(selector.explore(node, child), isNull);
    });
    test('decide()', () {
      expect(selector.decide(list), isFalse);
    });
    test('match()', () {
      expect(selector.match(list), isNull);
    });
  });
  group('ExploreRange [Atomic Audit]', () {
    final selector = ExploreRange(1, 3, matcher);
    test('interests()', () {
      expect(selector.interests().map((s) => s.index()), [1, 2]);
    });
    test('explore()', () {
      expect(selector.explore(list, child), same(matcher));
      expect(selector.explore(list, const PathSegment.ofInt(3)), isNull);
      expect(selector.explore(list, const PathSegment.ofString('x')), isNull);
      expect(selector.explore(node, child), isNull);
    });
    test('decide()', () {
      expect(selector.decide(list), isFalse);
    });
    test('match()', () {
      expect(selector.match(list), isNull);
    });
  });
  group('ExploreUnion [Atomic Audit]', () {
    test('interests()', () {
      expect(const ExploreUnion([ExploreAll(matcher)]).interests(), isNull);
      expect(
        const ExploreUnion([
          ExploreIndex(1, matcher),
        ]).interests()!.single.index(),
        1,
      );
    });
    test('explore()', () {
      expect(const ExploreUnion([]).explore(list, child), isNull);
      expect(
        const ExploreUnion([ExploreAll(matcher)]).explore(list, child),
        same(matcher),
      );
      expect(
        const ExploreUnion([
          ExploreAll(matcher),
          ExploreAll(matcher),
        ]).explore(list, child),
        isA<ExploreUnion>(),
      );
    });
    test('decide()', () {
      expect(const ExploreUnion([]).decide(node), isFalse);
      expect(const ExploreUnion([matcher]).decide(node), isTrue);
    });
    test('match()', () {
      expect(const ExploreUnion([]).match(node), isNull);
      expect(const ExploreUnion([matcher]).match(node), same(node));
    });
  });
  group('ExploreRecursiveEdge [Atomic Audit]', () {
    const selector = ExploreRecursiveEdge();
    test('interests()', () {
      expect(selector.interests(), isEmpty);
    });
    test('explore()', () {
      expect(() => selector.explore(list, child), throwsStateError);
    });
    test('decide()', () {
      expect(selector.decide(node), isFalse);
    });
    test('match()', () {
      expect(selector.match(node), isNull);
    });
  });
  group('ExploreRecursive [Atomic Audit]', () {
    const sequence = ExploreAll(ExploreRecursiveEdge());
    const selector = ExploreRecursive(
      sequence,
      sequence,
      RecursionLimit.depth(2),
    );
    test('interests()', () {
      expect(selector.interests(), isNull);
    });
    test('explore()', () {
      final next = selector.explore(list, child)! as ExploreRecursive;
      expect(next.limit.depth, 1);
      expect(next.explore(list, child), isNull);
    });
    test('decide()', () {
      expect(selector.decide(node), isFalse);
    });
    test('match()', () {
      expect(selector.match(node), isNull);
    });
  });
  group('ExploreInterpretAs [Atomic Audit]', () {
    const selector = ExploreInterpretAs('adl', matcher);
    test('namedReifier()', () {
      expect(selector.namedReifier, 'adl');
    });
    test('interests()', () {
      expect(selector.interests(), isEmpty);
    });
    test('explore()', () {
      expect(selector.explore(node, child), same(matcher));
    });
    test('decide()', () {
      expect(selector.decide(node), isFalse);
    });
    test('match()', () {
      expect(selector.match(node), isNull);
    });
  });
  group('SegmentIterator [Atomic Audit]', () {
    test('done()', () {
      final iterator = SegmentIterator(list);
      expect(iterator.done, isFalse);
      for (var i = 0; i < 3; i++) {
        iterator.next();
      }
      expect(iterator.done, isTrue);
    });
    test('next()', () {
      final iterator = SegmentIterator(list);
      for (var i = 0; i < 3; i++) {
        final item = iterator.next();
        expect(item.$1.index(), i);
        expect(item.$2.asInt(), i);
      }
      expect(iterator.next, throwsA(isA<IteratorOverreadException>()));
    });
  });
  test('recursionLimitDepth()', () {
    expect(recursionLimitDepth(3).depth, 3);
  });
  test('recursionLimitNone()', () {
    expect(recursionLimitNone().mode, RecursionLimitMode.none);
  });
  test('SelectorParseException.toString()', () {
    expect(SelectorParseException('invalid').toString(), 'invalid');
  });
}
