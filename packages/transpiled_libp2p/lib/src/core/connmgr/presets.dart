// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-libp2p/core/connmgr/presets.go.
import 'decay.dart';

/// Applies no decay.
DecayFn decayNone() =>
    (value) => (after: value.value, remove: false);

/// Subtracts [minuend] and removes the tag at zero or below.
DecayFn decayFixed(int minuend) => (value) {
  final after = value.value - minuend;
  return (after: after, remove: after <= 0);
};

/// Multiplies the value by [coefficient], flooring the result and removing it
/// when it reaches zero.
DecayFn decayLinear(double coefficient) => (value) {
  final after = (value.value * coefficient).floor();
  return (after: after, remove: after <= 0);
};

/// Removes a tag after it has been inactive for [after].
DecayFn decayExpireWhenInactive(Duration after) => (value) {
  // Preserve the locked upstream's time.Until(value.LastVisit) semantics.
  final untilLastVisit = value.lastVisit.difference(DateTime.now());
  return (after: 0, remove: untilLastVisit >= after);
};

/// Adds the incoming delta without bounds.
BumpFn bumpSumUnbounded() =>
    (value, delta) => value.value + delta;

/// Adds the incoming delta while keeping the result in [[min], [max]].
BumpFn bumpSumBounded(int min, int max) => (value, delta) {
  final result = value.value + delta;
  if (result >= max) return max;
  if (result <= min) return min;
  return result;
};

/// Replaces the current value with the incoming delta.
BumpFn bumpOverwrite() =>
    (_, delta) => delta;
