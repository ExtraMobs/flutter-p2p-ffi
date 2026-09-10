// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'package:test/test.dart' hide Matcher;
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

import 'fixtures/simple_node.dart';

void main() {
  final tree = SimpleNode.ofMap({
    'a': SimpleNode.ofList([SimpleNode.ofInt(1), SimpleNode.ofInt(2)]),
    'b': SimpleNode.ofString('three'),
  });

  test('WalkLocal is depth-first, reports paths, and SkipMeException stops a subtree', () {
    final seen = <String>[];
    walkLocal(tree, (progress, node) {
      seen.add('${progress.path}:${node.kind()}');
      if (progress.path.toString() == 'a') throw const SkipMeException();
    });
    expect(seen, ['${Path.empty}:map', 'a:list', 'b:string']);
  });

  test('WalkMatching follows selector order and reports match paths', () {
    final seen = <String>[];
    walkMatching(tree, ExploreFields({'b': const Matcher()}), (progress, node) {
      seen.add('${progress.path}:${node.asString()}');
    });
    expect(seen, ['b:three']);
  });

  test('Get and Focus retain the reached path', () {
    expect(get(tree, Path.parse('a/1')).asInt(), 2);
    var path = '';
    focus(tree, Path.parse('a/0'), (progress, node) {
      path = progress.path.toString();
      expect(node.asInt(), 1);
    });
    expect(path, 'a/0');
  });

  test('WalkAdv reports candidates and StartAtPath skips earlier matches', () {
    final reasons = <String>[];
    Progress().walkAdv(tree, ExploreFields({'b': const Matcher()}), (
      progress,
      _,
      reason,
    ) {
      reasons.add('${progress.path}:$reason');
    });
    expect(reasons, [':VisitReason.selectionCandidate', 'b:VisitReason.selectionMatch']);

    final seen = <String>[];
    Progress(cfg: Config(startAtPath: Path.parse('a/1'))).walkMatching(
      tree,
      const ExploreAll(ExploreAll(Matcher())),
      (progress, _) => seen.add(progress.path.toString()),
    );
    expect(seen, ['a/1']);
  });

  test('walk crosses links through configured LinkSystem and tracks LastBlock', () {
    const link = _TestLink(1);
    final system = LinkSystem(
      encoderChooser: (_) => (_, _) {},
      decoderChooser: (_) => (assembler, _) => assembler.assignString('loaded'),
      hasherChooser: (_, _) => Uint8List(0),
      storageReadOpener: (_, _) => Uint8List.fromList([0]),
      trustedStorage: true,
    );
    final seen = <String>[];
    Progress(
      cfg: Config(
        linkSystem: system,
        linkTargetNodePrototypeChooser: (_, _) => const PrototypeAny(),
      ),
    ).walkMatching(
      SimpleNode.ofMap({'link': SimpleNode.ofLink(link)}),
      const ExploreAll(Matcher()),
      (progress, node) {
        seen.add('${progress.path}:${node.asString()}:${progress.lastBlock.path}');
        expect(progress.lastBlock.link, link);
      },
    );
    expect(seen, ['link:loaded:link']);
  });

  test('link traversal fails without its required loader configuration', () {
    expect(
      () => walkMatching(
        SimpleNode.ofMap({'link': SimpleNode.ofLink(const _TestLink(3))}),
        const ExploreAll(Matcher()),
        (_, _) {},
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('budget, link selection, and transforming follow traversal semantics', () {
    expect(
      () => Progress(budget: Budget(nodeBudget: 1, linkBudget: 10)).walkLocal(
        tree,
        (_, _) {},
      ),
      throwsA(isA<BudgetExceededException>()),
    );
    const link = _TestLink(2);
    expect(
      selectLinks(
        SimpleNode.ofList([SimpleNode.ofLink(link), SimpleNode.ofLink(link)]),
      ),
      [link, link],
    );
    final transformed = walkTransforming(
      tree,
      ExploreFields({'b': const Matcher()}),
      (_, node) => node!.kind() == Kind.string
          ? SimpleNode.ofString(node.asString().toUpperCase())
          : node,
    );
    expect(transformed.lookupByString('b').asString(), 'THREE');
    final focused = focusedTransform(
      tree,
      Path.parse('a/0'),
      (_, __) => SimpleNode.ofInt(10),
      false,
    );
    expect(focused.lookupByString('a').lookupByIndex(0).asInt(), 10);
  });
}

final class _TestLink implements Link {
  const _TestLink(this.value);
  final int value;
  @override
  Uint8List binary() => Uint8List.fromList([value]);
  @override
  LinkPrototype prototype() => const _TestLinkPrototype();
  @override
  String toString() => 'test:$value';
  @override
  bool operator ==(Object other) => other is _TestLink && other.value == value;
  @override
  int get hashCode => value;
}

final class _TestLinkPrototype implements LinkPrototype {
  const _TestLinkPrototype();
  @override
  Link buildLink(List<int> hash) => _TestLink(hash.isEmpty ? 0 : hash.first);
}
