// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: library_prefixes
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';

void main() {
  test('float64 signed zero, NaN and 53-bit precision boundary', () {
    final zero = Golang.Float64(), neg = Golang.Float64(-0.0);
    expect(zero == neg, true);
    expect(zero.hashCode, neg.hashCode);
    expect(neg.toLittleEndianBytes(), [0, 0, 0, 0, 0, 0, 0, 128]);
    expect((Golang.Float64(1) / neg).toDouble(), double.negativeInfinity);
    final nan = zero / zero;
    expect(nan == nan, false);
    expect(nan < zero, false);
    expect(nan >= zero, false);
    expect(
      (Golang.Float64(9007199254740992.0) + Golang.Float64(1)).toDouble(),
      9007199254740992.0,
    );
    neg.toLittleEndianBytes()[7] = 0;
    expect(neg.toDouble().isNegative, true);
  });
}
