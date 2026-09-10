// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: library_prefixes
import 'dart:math' as math;
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';

void main() {
  test(
    'float narrowing rounds ties to even and widening preserves results',
    () {
      final half = math.pow(2, -24).toDouble();
      final a = Golang.Float32.fromFloat64(Golang.Float64(1 + half));
      final b = Golang.Float32.fromFloat64(Golang.Float64(1 + 3 * half));
      expect(a.toDouble(), 1);
      expect(b.toDouble(), 1 + math.pow(2, -22));
      expect(Golang.Float64.fromFloat32(b).toDouble(), b.toDouble());
      final negativeZero = Golang.Float32.fromFloat64(Golang.Float64(-0.0));
      expect(
        Golang.Float64.fromFloat32(negativeZero).toDouble().isNegative,
        true,
      );
      expect(
        Golang.Float32.fromFloat64(Golang.Float64(1e300)).toDouble(),
        double.infinity,
      );
    },
  );
}
