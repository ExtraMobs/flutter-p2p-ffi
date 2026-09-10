// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Parity cases from go-boxo's bitswap/client/wantlist/wantlist_test.go.
import 'package:test/test.dart';
import 'package:transpiled_boxo/transpiled_boxo.dart';
import 'package:transpiled_cid/transpiled_cid.dart';

final _testCids = [
  'QmQL8LqkEgYXaDHdNYCG2mmpow7Sp8Z8Kt3QS688vyBeC7',
  'QmcBDsdjgSXU7BP4A4V8LJCXENE5xVwnhrhRGVTJr9YCVj',
  'QmQakgd2wDxc3uUF4orGdEm28zUT9Mmimp5pyPG2SFS9Gj',
].map(Cid.decode).toList(growable: false);

void _expectHasCid(Wantlist wantlist, Cid cid) {
  final entry = wantlist.get(cid);
  expect(entry, isNotNull);
  expect(entry!.cid, equals(cid));
}

void main() {
  test('TestBasicWantlist', () {
    final wantlist = Wantlist();

    expect(wantlist.add(_testCids[0], 5, WantType.block), isTrue);
    _expectHasCid(wantlist, _testCids[0]);
    expect(wantlist.add(_testCids[1], 4, WantType.block), isTrue);
    _expectHasCid(wantlist, _testCids[0]);
    _expectHasCid(wantlist, _testCids[1]);
    expect(wantlist.length, equals(2));

    expect(wantlist.add(_testCids[1], 4, WantType.block), isFalse);
    _expectHasCid(wantlist, _testCids[0]);
    _expectHasCid(wantlist, _testCids[1]);
    expect(wantlist.length, equals(2));

    expect(wantlist.removeType(_testCids[0], WantType.block), isTrue);
    _expectHasCid(wantlist, _testCids[1]);
    expect(wantlist.has(_testCids[0]), isFalse);
  });

  test('TestAddHaveThenBlock', () {
    final wantlist = Wantlist()
      ..add(_testCids[0], 5, WantType.have)
      ..add(_testCids[0], 5, WantType.block);

    expect(wantlist.get(_testCids[0])?.wantType, WantType.block);
  });

  test('TestAddBlockThenHave', () {
    final wantlist = Wantlist()
      ..add(_testCids[0], 5, WantType.block)
      ..add(_testCids[0], 5, WantType.have);

    expect(wantlist.get(_testCids[0])?.wantType, WantType.block);
  });

  test('TestAddHaveThenRemoveBlock', () {
    final wantlist = Wantlist()
      ..add(_testCids[0], 5, WantType.have)
      ..removeType(_testCids[0], WantType.block);

    expect(wantlist.has(_testCids[0]), isFalse);
  });

  test('TestAddBlockThenRemoveHave', () {
    final wantlist = Wantlist()
      ..add(_testCids[0], 5, WantType.block)
      ..removeType(_testCids[0], WantType.have);

    expect(wantlist.get(_testCids[0])?.wantType, WantType.block);
  });

  test('TestAddHaveThenRemoveAny', () {
    final wantlist = Wantlist()
      ..add(_testCids[0], 5, WantType.have)
      ..remove(_testCids[0]);

    expect(wantlist.has(_testCids[0]), isFalse);
  });

  test('TestAddBlockThenRemoveAny', () {
    final wantlist = Wantlist()
      ..add(_testCids[0], 5, WantType.block)
      ..remove(_testCids[0]);

    expect(wantlist.has(_testCids[0]), isFalse);
  });

  test('TestSortEntries', () {
    final entries =
        (Wantlist()
              ..add(_testCids[0], 3, WantType.block)
              ..add(_testCids[1], 5, WantType.have)
              ..add(_testCids[2], 4, WantType.have))
            .entries();

    expect(entries.map((entry) => entry.cid), [
      _testCids[1],
      _testCids[2],
      _testCids[0],
    ]);
  });

  test('TestCache', () {
    final wantlist = Wantlist()..add(_testCids[0], 3, WantType.block);
    final first = wantlist.entries();
    expect(first, hasLength(1));
    expect(identical(first, wantlist.entries()), isTrue);

    wantlist.add(_testCids[1], 3, WantType.block);
    final second = wantlist.entries();
    expect(second, hasLength(2));
    expect(identical(first, second), isFalse);

    wantlist.remove(_testCids[1]);
    expect(wantlist.entries(), hasLength(1));
  });

  test('Entry.ref and WantType wire values', () {
    final entry = Entry.ref(_testCids[0], 5);
    expect(entry.cid, _testCids[0]);
    expect(entry.priority, 5);
    expect(entry.wantType, WantType.block);
    expect(WantType.block.code, 0);
    expect(WantType.have.code, 1);
  });
}
