// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-datastore's features_test.go: TestFeatureByName,
// TestFeaturesForDatastore.
import 'package:test/test.dart';
import 'package:transpiled_datastore/transpiled_datastore.dart';

void main() {
  test('TestFeatureByName', () {
    final feat = featureByName(featureNameBatching);
    expect(feat, isNotNull);
    expect(feat!.name, equals(featureNameBatching));

    expect(featureByName('UnknownFeature'), isNull);
  });

  test('TestFeaturesForDatastore', () {
    List<Feature> byNames(List<String> names) => [for (final n in names) featureByName(n)!];

    final cases = <(String, Datastore?, List<String>)>[
      ('MapDatastore', MapDatastore(), const ['Batching']),
      (
        'NullDatastore',
        NullDatastore(),
        const ['Batching', 'Checked', 'GC', 'Persistent', 'Scrubbed', 'Transaction'],
      ),
      (
        'LogDatastore',
        LogDatastore(MapDatastore()),
        const ['Batching', 'Checked', 'GC', 'Persistent', 'Scrubbed'],
      ),
      ('nil datastore', null, const <String>[]),
    ];

    for (final (name, ds, expectedNames) in cases) {
      final feats = featuresForDatastore(ds);
      expect(feats, hasLength(expectedNames.length), reason: name);
      expect(feats, equals(byNames(expectedNames)), reason: name);
    }
  });
}
