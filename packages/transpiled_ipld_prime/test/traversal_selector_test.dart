// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Ports the executable cases from traversal/selector/{builder,matcher,*_test}.go.
import 'dart:typed_data';

import 'package:test/test.dart' hide Matcher;
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

void main() {
  final specs = SelectorSpecBuilder(prototype.any);

  test('builder round-trips every selector clause', () {
    final edge = specs.exploreRecursiveEdge();
    final all = specs.exploreAll(specs.matcher());
    final selectors = <SelectorSpec>[
      specs.matcher(),
      specs.matcherSubset(1, -1),
      all,
      specs.exploreIndex(2, specs.matcher()),
      specs.exploreRange(1, 3, specs.matcher()),
      specs.exploreFields((fields) => fields.insert('x', specs.matcher())),
      specs.exploreUnion([specs.matcher(), all]),
      specs.exploreInterpretAs('adl', specs.matcher()),
      specs.exploreRecursive(
        const RecursionLimit.depth(2),
        specs.exploreAll(edge),
      ),
      specs.exploreRecursive(
        const RecursionLimit.none(),
        specs.exploreAll(edge),
      ),
    ];
    for (final spec in selectors) {
      expect(spec.selector(), isA<Selector>());
    }
  });

  test('JSON parser validates selector and common selectors compile', () {
    expect(
      () => parseAndCompileJsonSelector('{"a":{">":["bad"]}}'),
      throwsA(isA<Object>()),
    );
    expect(commonSelectorMatchPoint, isA<Node>());
    expect(commonSelectorMatchChildren, isA<Node>());
    expect(commonSelectorExploreAllRecursively, isA<Node>());
    expect(commonSelectorMatchAllRecursively, isA<Node>());
  });

  test('matcher subset matches Go string and bytes boundary vectors', () {
    final text = PlainString('foobarbaz!');
    final bytes = PlainBytes(Uint8List.fromList('foobarbaz!'.codeUnits));
    for (final item in [
      (0, 10, 'foobarbaz!'),
      (1, 4, 'oob'),
      (0, -1, 'foobarbaz'),
      (-2, -1, 'z'),
    ]) {
      final slice = Slice(item.$1, item.$2);
      expect((slice.apply(text)! as PlainString).asString(), item.$3);
      expect(String.fromCharCodes(slice.apply(bytes)!.asBytes()), item.$3);
    }
    expect(const Slice(10, 11).apply(text), isNull);
    expect(const Slice(-1, -2).apply(bytes), isNull);
  });

  test('explore clauses honor field/index/range and recursive depth', () {
    final list = _list([0, 1, 2, 3]);
    final matcher = const Matcher();
    expect(
      const ExploreIndex(
        2,
        Matcher(),
      ).explore(list, const PathSegment.ofInt(2)),
      isA<Matcher>(),
    );
    expect(
      const ExploreIndex(
        2,
        Matcher(),
      ).explore(list, const PathSegment.ofInt(1)),
      isNull,
    );
    expect(
      ExploreRange(1, 3, matcher).explore(list, const PathSegment.ofInt(2)),
      same(matcher),
    );
    expect(
      ExploreRange(1, 3, matcher).explore(list, const PathSegment.ofInt(3)),
      isNull,
    );
    final recursive = specs
        .exploreRecursive(
          const RecursionLimit.depth(2),
          specs.exploreAll(specs.exploreRecursiveEdge()),
        )
        .selector();
    final first = recursive.explore(list, const PathSegment.ofInt(0));
    expect(first, isA<ExploreRecursive>());
    final second = first!.explore(list, const PathSegment.ofInt(0));
    expect(second, isNull);
  });

  test('parse errors retain selector-specific rejection', () {
    final node = prototype.any.newBuilder()..assignInt(0);
    expect(
      () => compileSelector(node.build()),
      throwsA(predicate((e) => e.toString().contains('keyed union'))),
    );
    expect(
      () => parseAndCompileJsonSelector(r'{"r":{"^":2,"$":2,">":{".":{}}}}'),
      throwsA(predicate((e) => e.toString().contains('greater than start'))),
    );
  });
}

Node _list(List<int> values) {
  final builder = prototype.any.newBuilder();
  final list = builder.beginList(values.length);
  for (final value in values) {
    list.assembleValue().assignInt(value);
  }
  list.finish();
  return builder.build();
}
