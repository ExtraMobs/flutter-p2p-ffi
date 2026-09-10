// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/features.dart
//
// Port of go-datastore's features.go. Go's `FeaturesForDatastore` uses
// `reflect.TypeOf(...).Implements(...)` to test a datastore against each
// feature interface generically; Dart has no equivalent runtime interface
// inspection, so this is ported as a fixed `is`-check per feature instead
// (there are only 7 features, a closed set -- this isn't a scalability
// concern the way it would be in Go's fully-open reflection approach).
import 'datastore.dart';

/// Batching support. Equivalent to go-datastore's `FeatureNameBatching`.
const String featureNameBatching = 'Batching';

/// On-disk integrity checking. Equivalent to go-datastore's
/// `FeatureNameChecked`.
const String featureNameChecked = 'Checked';

/// Garbage collection. Equivalent to go-datastore's `FeatureNameGC`.
const String featureNameGc = 'GC';

/// Disk-usage reporting. Equivalent to go-datastore's
/// `FeatureNamePersistent`.
const String featureNamePersistent = 'Persistent';

/// Scrubbing/error-correction. Equivalent to go-datastore's
/// `FeatureNameScrubbed`.
const String featureNameScrubbed = 'Scrubbed';

/// Time-to-live entries. Equivalent to go-datastore's `FeatureNameTTL`.
const String featureNameTtl = 'TTL';

/// Transactions. Equivalent to go-datastore's `FeatureNameTransaction`.
const String featureNameTransaction = 'Transaction';

/// Metadata about a datastore feature. Equivalent to go-datastore's
/// `Feature`.
class Feature {
  /// Creates feature metadata.
  const Feature(this.name, this.matches);

  /// The feature's canonical name.
  final String name;

  /// Whether [d] implements this feature.
  final bool Function(Datastore d) matches;

  @override
  bool operator ==(Object other) => other is Feature && name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}

/// All known datastore features, in their canonical order. Equivalent to
/// go-datastore's `Features` (only appended to, for backwards
/// compatibility, matching Go's own comment on that function).
List<Feature> features() => const [
  Feature(featureNameBatching, _isBatching),
  Feature(featureNameChecked, _isChecked),
  Feature(featureNameGc, _isGc),
  Feature(featureNamePersistent, _isPersistent),
  Feature(featureNameScrubbed, _isScrubbed),
  Feature(featureNameTtl, _isTtl),
  Feature(featureNameTransaction, _isTransaction),
];

bool _isBatching(Datastore d) => d is Batching;
bool _isChecked(Datastore d) => d is CheckedDatastore;
bool _isGc(Datastore d) => d is GcDatastore;
bool _isPersistent(Datastore d) => d is PersistentDatastore;
bool _isScrubbed(Datastore d) => d is ScrubbedDatastore;
bool _isTtl(Datastore d) => d is TtlDatastore;
bool _isTransaction(Datastore d) => d is TxnDatastore;

final Map<String, Feature> _featuresByName = {for (final f in features()) f.name: f};

/// The feature named [name], if known. Equivalent to go-datastore's
/// `FeatureByName`.
Feature? featureByName(String name) => _featuresByName[name];

/// The features [d] supports. Equivalent to go-datastore's
/// `FeaturesForDatastore`.
List<Feature> featuresForDatastore(Datastore? d) {
  if (d == null) return const [];
  return [for (final f in features()) if (f.matches(d)) f];
}
