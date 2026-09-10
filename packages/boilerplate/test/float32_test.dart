// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: library_prefixes
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';

void main() {
  test('float32 rounds, preserves signed zero and IEEE comparisons', () {
    expect(Golang.Float32(16777217).toDouble(), 16777216);
    final zero = Golang.Float32(), negativeZero = Golang.Float32(-0.0);
    expect(zero == negativeZero, true);
    expect(zero.hashCode, negativeZero.hashCode);
    expect(negativeZero.toLittleEndianBytes(), [0, 0, 0, 128]);
    expect(
      (Golang.Float32(1) / negativeZero).toDouble(),
      double.negativeInfinity,
    );
    final nan = zero / zero;
    expect(nan.toDouble().isNaN, true);
    expect(nan == nan, false);
    expect(nan <= zero, false);
    expect(nan >= zero, false);
    expect((Golang.Float32(16777216) + Golang.Float32(1)).toDouble(), 16777216);
  });
}
