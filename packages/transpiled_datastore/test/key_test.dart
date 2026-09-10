// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-datastore's key_test.go: TestKeyBasic (via the shared
// subtestKey helper), TestKeyAncestry, TestType, TestRandom, TestLess,
// TestKeyMarshalJSON, TestKey_RootNamespace.
//
// TestKeyUnmarshalJSON's exact-Go-error-string assertions are not ported --
// Key.unmarshalJson throws a Dart FormatException on invalid input instead
// of leaving a mutable receiver unchanged (Go's `*Key` UnmarshalJSON idiom
// has no clean Dart equivalent for a factory constructor); see the
// doc comment on Key.unmarshalJson.
import 'dart:convert';

import 'package:test/test.dart';
import 'package:transpiled_datastore/transpiled_datastore.dart';

void subtestKey(String s) {
  final fixed = cleanPath('/$s');
  final namespaces = fixed.split('/').sublist(1);
  final lastNamespace = namespaces.last;
  final lnparts = lastNamespace.split(':');
  final ktype = lnparts.length > 1 ? lnparts.sublist(0, lnparts.length - 1).join(':') : '';
  final kname = lnparts.last;

  final kchild = cleanPath('$fixed/cchildd');
  final kparent = '/${namespaces.sublist(0, namespaces.length - 1).join('/')}';
  final kpath = cleanPath('$kparent/$ktype');
  final kinstance = '$fixed:inst';

  expect(Key(s).value, equals(fixed));
  expect(Key(s), equals(Key(s)));
  expect(Key(s).value, equals(Key(s).value));
  expect(Key(s).name, equals(kname));
  expect(Key(s).type, equals(ktype));
  expect(Key(s).path.value, equals(kpath));
  expect(Key(s).instance('inst').value, equals(kinstance));

  expect(Key(s).child(Key('cchildd')).value, equals(kchild));
  expect(Key(s).child(Key('cchildd')).parent.value, equals(fixed));
  expect(Key(s).childString('cchildd').value, equals(kchild));
  expect(Key(s).childString('cchildd').parent.value, equals(fixed));
  expect(Key(s).parent.value, equals(kparent));
  expect(Key(s).list, hasLength(namespaces.length));
  expect(Key(s).namespaces, hasLength(namespaces.length));
  for (var i = 0; i < Key(s).list.length; i++) {
    expect(Key(s).list[i], equals(namespaces[i]));
  }

  expect(Key(s), equals(Key(s)));
  expect(Key(s).equalTo(Key(s)), isTrue);
  expect(Key(s).equalTo(Key('/fdsafdsa/$s')), isFalse);

  expect(Key(s).less(Key(s).parent), isFalse);
  expect(Key(s).less(Key(s).childString('foo')), isTrue);
}

void main() {
  test('TestKeyBasic', () {
    for (final s in [
      '',
      'abcde',
      'disahfidsalfhduisaufidsail',
      '/fdisahfodisa/fdsa/fdsafdsafdsafdsa/fdsafdsa/',
      '4215432143214321432143214321',
      '/fdisaha////fdsa////fdsafdsafdsafdsa/fdsafdsa/',
      'abcde:fdsfd',
      'disahfidsalfhduisaufidsail:fdsa',
      '/fdisahfodisa/fdsa/fdsafdsafdsafdsa/fdsafdsa/:',
      '4215432143214321432143214321:',
      'fdisaha////fdsa////fdsafdsafdsafdsa/fdsafdsa/f:fdaf',
    ]) {
      subtestKey(s);
    }
  });

  test('TestKeyAncestry', () {
    final k1 = Key('/A/B/C');
    final k2 = Key('/A/B/C/D');
    final k3 = Key('/AB');
    final k4 = Key('/A');

    expect(k1.value, equals('/A/B/C'));
    expect(k2.value, equals('/A/B/C/D'));
    expect(k1.isAncestorOf(k2), isTrue);
    expect(k2.isDescendantOf(k1), isTrue);
    expect(k4.isAncestorOf(k2), isTrue);
    expect(k4.isAncestorOf(k1), isTrue);
    expect(k4.isDescendantOf(k2), isFalse);
    expect(k4.isDescendantOf(k1), isFalse);
    expect(k3.isDescendantOf(k4), isFalse);
    expect(k4.isAncestorOf(k3), isFalse);
    expect(k2.isDescendantOf(k4), isTrue);
    expect(k1.isDescendantOf(k4), isTrue);
    expect(k2.isAncestorOf(k4), isFalse);
    expect(k1.isAncestorOf(k4), isFalse);
    expect(k2.isAncestorOf(k2), isFalse);
    expect(k1.isAncestorOf(k1), isFalse);
    expect(k1.child(Key('D')).value, equals(k2.value));
    expect(k1.childString('D').value, equals(k2.value));
    expect(k2.parent.value, equals(k1.value));
    expect(k2.parent.path.value, equals(k1.path.value));
  });

  test('TestType', () {
    final k1 = Key('/A/B/C:c');
    final k2 = Key('/A/B/C:c/D:d');

    expect(k1.isAncestorOf(k2), isTrue);
    expect(k2.isDescendantOf(k1), isTrue);
    expect(k1.type, equals('C'));
    expect(k2.type, equals('D'));
    expect(k1.type, equals(k2.parent.type));
  });

  test('TestRandom: 1000 random keys are all unique', () {
    final keys = <Key>{};
    for (var i = 0; i < 1000; i++) {
      final r = randomKey();
      expect(keys.contains(r), isFalse);
      keys.add(r);
    }
    expect(keys, hasLength(1000));
  });

  test('TestLess', () {
    expect(Key('/a/b/c').less(Key('/a/b/c/d')), isTrue);
    expect(Key('/a/b').less(Key('/a/b/c/d')), isTrue);
    expect(Key('/a').less(Key('/a/b/c/d')), isTrue);
    expect(Key('/a/a/c').less(Key('/a/b/c')), isTrue);
    expect(Key('/a/a/d').less(Key('/a/b/c')), isTrue);
    expect(Key('/a/b/c/d/e/f/g/h').less(Key('/b')), isTrue);
    expect(Key('/').less(Key('/a')), isTrue);
  });

  test('TestKeyMarshalJSON', () {
    for (final c in [
      (Key('/a/b/c'), '"/a/b/c"'),
      (Key('/shouldescapekey"/with/quote'), '"/shouldescapekey\\"/with/quote"'),
    ]) {
      final (key, expectedJson) = c;
      final out = utf8.decode(key.marshalJson());
      expect(out, equals(expectedJson));
      expect(Key.unmarshalJson(utf8.encode(out)).equalTo(key), isTrue);
    }
  });

  test('TestKey_RootNamespace', () {
    expect(Key.raw('/').rootNamespace, equals(''));
    expect(Key.raw('/Comedy').rootNamespace, equals('Comedy'));
    expect(Key.raw('/Comedy/MontyPython/Actor:JohnCleese').rootNamespace, equals('Comedy'));
    expect(Key.raw('/Comedy:MontyPython').rootNamespace, equals('Comedy:MontyPython'));
  });
}
