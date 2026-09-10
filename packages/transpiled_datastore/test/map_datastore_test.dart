// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-datastore's basic_ds_test.go: TestMapDatastore, running the
// full dstest conformance suite (basic + batching subtests) against
// MapDatastore.
//
// dstest.subtestCombinations is ported in dstest/basic_tests.dart (its
// logic is real and tested transitively via every other subtestQuery
// call) but deliberately not invoked here: its exhaustive product is
// 4*4*2*4*3*3 = 1152 sub-queries, each re-seeding a fresh fixture --
// upstream Go itself only runs it "when not under the race detector"
// for the same cost reason; running it here would make this suite far
// slower without adding coverage the other subtests don't already give.
import 'package:test/test.dart';
import 'package:transpiled_datastore/transpiled_datastore.dart';

import 'dstest/basic_tests.dart';
import 'dstest/test_util.dart';

void main() {
  test('MapDatastore passes the full dstest conformance suite', () async {
    final ds = MapDatastore();
    await subtestAll(ds);
    for (final subtest in batchSubtests) {
      await subtest(ds);
    }
  });
}
