// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Port of go-ipld-prime/traversal/selector/builder.
// ignore_for_file: duplicate_ignore, public_member_api_docs
library;

import 'src/datamodel/node.dart';
import 'src/datamodel/node_builder.dart';
import 'src/traversal/selector/selector.dart';

abstract interface class SelectorSpec {
  Node node();
  Selector selector();
}

final class SelectorSpecBuilder {
  const SelectorSpecBuilder(this.prototype);
  final NodePrototype prototype;
  SelectorSpec matcher() => _Spec(_map({selectorKeyMatcher: _map({})}));
  SelectorSpec matcherSubset(int from, int to) => _Spec(
    _map({
      selectorKeyMatcher: _map({
        selectorKeySubset: _map({selectorKeyFrom: from, selectorKeyTo: to}),
      }),
    }),
  );
  SelectorSpec exploreRecursiveEdge() =>
      _Spec(_map({selectorKeyExploreRecursiveEdge: _map({})}));
  SelectorSpec exploreAll(SelectorSpec next) => _Spec(
    _map({
      selectorKeyExploreAll: _map({selectorKeyNext: next.node()}),
    }),
  );
  SelectorSpec exploreIndex(int index, SelectorSpec next) => _Spec(
    _map({
      selectorKeyExploreIndex: _map({
        selectorKeyIndex: index,
        selectorKeyNext: next.node(),
      }),
    }),
  );
  SelectorSpec exploreRange(int start, int end, SelectorSpec next) => _Spec(
    _map({
      selectorKeyExploreRange: _map({
        selectorKeyStart: start,
        selectorKeyEnd: end,
        selectorKeyNext: next.node(),
      }),
    }),
  );
  SelectorSpec exploreUnion(List<SelectorSpec> members) => _Spec(
    _map({
      selectorKeyExploreUnion: _list(members.map((e) => e.node()).toList()),
    }),
  );
  SelectorSpec exploreFields(void Function(ExploreFieldsSpecBuilder) build) {
    final fields = <String, Node>{};
    build(ExploreFieldsSpecBuilder._(fields));
    return _Spec(
      _map({
        selectorKeyExploreFields: _map({selectorKeyFields: _map(fields)}),
      }),
    );
  }

  SelectorSpec exploreInterpretAs(String adl, SelectorSpec next) => _Spec(
    _map({
      selectorKeyExploreInterpretAs: _map({
        selectorKeyAs: adl,
        selectorKeyNext: next.node(),
      }),
    }),
  );
  SelectorSpec exploreRecursive(RecursionLimit limit, SelectorSpec sequence) =>
      _Spec(
        _map({
          selectorKeyExploreRecursive: _map({
            selectorKeyLimit: _map({
              limit.mode == RecursionLimitMode.depth
                  ? selectorKeyLimitDepth
                  : selectorKeyLimitNone: limit.mode == RecursionLimitMode.depth
                  ? limit.depth
                  : _map({}),
            }),
            selectorKeySequence: sequence.node(),
          }),
        }),
      );

  Node _map(Map<String, Object> values) {
    final b = prototype.newBuilder();
    final a = b.beginMap(values.length);
    values.forEach((key, value) => _assign(a.assembleEntry(key), value));
    a.finish();
    return b.build();
  }

  Node _list(List<Object> values) {
    final b = prototype.newBuilder();
    final a = b.beginList(values.length);
    for (final value in values) {
      _assign(a.assembleValue(), value);
    }
    a.finish();
    return b.build();
  }

  void _assign(NodeAssembler assembler, Object value) {
    if (value is Node)
      assembler.assignNode(value);
    else if (value is int)
      assembler.assignInt(value);
    else if (value is String)
      assembler.assignString(value);
    else {
      throw ArgumentError.value(value);
    }
  }
}

final class ExploreFieldsSpecBuilder {
  ExploreFieldsSpecBuilder._(this._fields);
  final Map<String, Node> _fields;
  void insert(String key, SelectorSpec value) => _fields[key] = value.node();
}

final class _Spec implements SelectorSpec {
  const _Spec(this._node);
  final Node _node;
  @override
  Node node() => _node;
  @override
  Selector selector() => compileSelector(_node);
}

