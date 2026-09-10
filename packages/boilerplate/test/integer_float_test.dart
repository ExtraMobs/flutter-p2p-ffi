// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: library_prefixes
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';

void main() {
  test('direct int64 to float32 avoids double rounding', () {
    final n = (BigInt.one << 62) + (BigInt.one << 38) + BigInt.one;
    final signed = Golang.Int64.fromBigInt(n);
    final exact = Golang.Float32.fromInt64(signed);
    final doubleRounded = Golang.Float32(n.toDouble());
    expect(exact.toDouble(), greaterThan(doubleRounded.toDouble()));
    expect(Golang.Float32.fromInt64(-signed).toDouble(), -exact.toDouble());
    expect(
      Golang.Float32.fromUint64(signed.toUint64()).toDouble(),
      exact.toDouble(),
    );
    expect(Golang.Float64.fromInt64(Golang.Int64(-1)).toDouble(), -1);
  });
}
