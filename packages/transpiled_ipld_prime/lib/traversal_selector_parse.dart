// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Port of go-ipld-prime/traversal/selector/parse.
// ignore_for_file: duplicate_ignore, public_member_api_docs
library;

import 'dart:convert';
import 'src/basicnode/prototypes.dart';
import 'src/codec/json/codec.dart' as json;
import 'src/datamodel/node.dart';
import 'src/traversal/selector/selector.dart';

Node parseJsonSelector(String source) {
  final builder = prototype.any.newBuilder();
  json.decode(builder, utf8.encode(source));
  final node = builder.build();
  compileSelector(node);
  return node;
}

Selector parseAndCompileJsonSelector(String source) =>
    compileSelector(parseJsonSelector(source));

final Node commonSelectorMatchPoint = parseJsonSelector('{".":{}}');
final Node commonSelectorMatchChildren = parseJsonSelector(
  '{"a":{">":{".":{}}}}',
);
final Node commonSelectorExploreAllRecursively = parseJsonSelector(
  '{"R":{"l":{"none":{}},":>":{"a":{">":{"@":{}}}}}}',
);
final Node commonSelectorMatchAllRecursively = parseJsonSelector(
  '{"R":{"l":{"none":{}},":>":{"|":[{".":{}},{"a":{">":{"@":{}}}}]}}}',
);
