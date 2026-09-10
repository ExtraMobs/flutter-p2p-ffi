// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// The RFC3339Nano-compatible timestamp format used by IPFS.
const String timeFormatIpfs = 'RFC3339Nano';

/// Parses an RFC3339 timestamp and normalizes it to UTC.
DateTime parseRfc3339(String value) => DateTime.parse(value).toUtc();

/// Formats [value] as UTC RFC3339Nano, omitting insignificant zeroes.
String formatRfc3339(DateTime value) {
  final text = value.toUtc().toIso8601String();
  if (!text.contains('.')) return text;
  final z = text.endsWith('Z') ? 'Z' : '';
  final body = z.isEmpty ? text : text.substring(0, text.length - 1);
  final dot = body.indexOf('.');
  final fraction = body.substring(dot + 1).replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty
      ? body.substring(0, dot) + z
      : '${body.substring(0, dot)}.$fraction$z';
}
