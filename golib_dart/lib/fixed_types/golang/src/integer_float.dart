// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Rounds an integer directly to IEEE significand precision, ties to even.
/// Internal callers provide 64-bit integers and precision 24 or 53, so the
/// rounded value is exactly representable as binary64 before binary32 storage.
double integerToFloat(BigInt value, int precision) {
  final magnitude = value.abs();
  final shift = magnitude.bitLength - precision;
  if (shift <= 0) return value.toDouble();
  var significant = magnitude >> shift;
  final discarded = magnitude - (significant << shift);
  final half = BigInt.one << (shift - 1);
  if (discarded > half || (discarded == half && significant.isOdd)) {
    significant += BigInt.one;
  }
  final rounded = significant << shift;
  return (value.isNegative ? -rounded : rounded).toDouble();
}
