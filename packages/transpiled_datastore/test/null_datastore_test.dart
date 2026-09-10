// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-datastore's null_ds_test.go: TestNullDatastore -- the only
// subtest that makes sense for a datastore that stores nothing.
import 'package:test/test.dart';
import 'package:transpiled_datastore/transpiled_datastore.dart';

import 'dstest/basic_tests.dart';

void main() {
  test('NullDatastore: nothing should ever be found', () async {
    await subtestNotFounds(NullDatastore());
  });
}
