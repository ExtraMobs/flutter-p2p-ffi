// test/atomic/nivel_1/boilerplate_atomic_tests.dart
// Testes atomicos 1 para 1 para o modulo boilerplate (fixed_types/golang)

import 'dart:typed_data';
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:boilerplate/fixed_types/golang/src/integer_float.dart';
import 'package:boilerplate/internal_poll/golang.dart';
import 'package:test/test.dart';

void main() {
  group('Bool [Atomic Audit]', () {
    test('toBool() - converte para bool nativo Dart', () {
      expect(Golang.Bool().toBool(), isFalse);
      expect(Golang.Bool(false).toBool(), isFalse);
      expect(Golang.Bool(true).toBool(), isTrue);
    });

    test('not() - executa negacao logica', () {
      expect(Golang.Bool(true).not().toBool(), isFalse);
      expect(Golang.Bool(false).not().toBool(), isTrue);
    });

    test('and() - operacao AND com curto-circuito', () {
      var evaluated = false;
      final f = Golang.Bool(false);
      final resF = f.and(() {
        evaluated = true;
        return Golang.Bool(true);
      });
      expect(resF.toBool(), isFalse);
      expect(evaluated, isFalse);

      final t = Golang.Bool(true);
      final resT = t.and(() {
        evaluated = true;
        return Golang.Bool(true);
      });
      expect(resT.toBool(), isTrue);
      expect(evaluated, isTrue);
    });

    test('or() - operacao OR com curto-circuito', () {
      var evaluated = false;
      final t = Golang.Bool(true);
      final resT = t.or(() {
        evaluated = true;
        return Golang.Bool(false);
      });
      expect(resT.toBool(), isTrue);
      expect(evaluated, isFalse);

      final f = Golang.Bool(false);
      final resF = f.or(() {
        evaluated = true;
        return Golang.Bool(true);
      });
      expect(resF.toBool(), isTrue);
      expect(evaluated, isTrue);
    });

    test('operator == - compara igualdade de valores Bool', () {
      expect(Golang.Bool(true) == Golang.Bool(true), isTrue);
      expect(Golang.Bool(false) == Golang.Bool(false), isTrue);
      expect(Golang.Bool(true) == Golang.Bool(false), isFalse);
    });

    test('hashCode - retorna hash code do booleano', () {
      expect(Golang.Bool(true).hashCode, equals(true.hashCode));
      expect(Golang.Bool(false).hashCode, equals(false.hashCode));
    });

    test('toString() - converte para representacao em string', () {
      expect(Golang.Bool(true).toString(), equals('true'));
      expect(Golang.Bool(false).toString(), equals('false'));
    });
  });

  group('Complex128 [Atomic Audit]', () {
    test('operator + - soma numeros complexos', () {
      final a = Golang.Complex128.fromDoubles(1.0, 2.0);
      final b = Golang.Complex128.fromDoubles(3.0, 4.0);
      final sum = a + b;
      expect(sum.real.toDouble(), equals(4.0));
      expect(sum.imag.toDouble(), equals(6.0));
    });

    test('operator * - multiplica numeros complexos', () {
      final a = Golang.Complex128.fromDoubles(1.0, 2.0);
      final b = Golang.Complex128.fromDoubles(3.0, 4.0);
      final prod = a * b;
      expect(prod.real.toDouble(), equals(-5.0));
      expect(prod.imag.toDouble(), equals(10.0));
    });

    test('operator / - divide numeros complexos', () {
      final a = Golang.Complex128.fromDoubles(1.0, 2.0);
      final b = Golang.Complex128.fromDoubles(1.0, 2.0);
      final div = a / b;
      expect(div.real.toDouble(), closeTo(1.0, 1e-9));
      expect(div.imag.toDouble(), closeTo(0.0, 1e-9));
    });

    test('operator == - compara igualdade de Complex128', () {
      final a = Golang.Complex128.fromDoubles(2.5, 3.5);
      final b = Golang.Complex128.fromDoubles(2.5, 3.5);
      final c = Golang.Complex128.fromDoubles(2.5, 3.6);
      expect(a == b, isTrue);
      expect(a == c, isFalse);
    });

    test('hashCode - retorna hash code combinando real e imag', () {
      final a = Golang.Complex128.fromDoubles(1.0, 2.0);
      final b = Golang.Complex128.fromDoubles(1.0, 2.0);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString() - formata complexo para string', () {
      final a = Golang.Complex128.fromDoubles(1.5, 2.5);
      expect(a.toString(), equals("(Instance of 'Float64'+Instance of 'Float64' i)"));
    });
  });

  group('Complex64 [Atomic Audit]', () {
    test('operator + - soma numeros complexos em precisao 32-bit', () {
      final a = Golang.Complex64.fromDoubles(1.0, 2.0);
      final b = Golang.Complex64.fromDoubles(3.0, 4.0);
      final sum = a + b;
      expect(sum.real.toDouble(), closeTo(4.0, 1e-5));
      expect(sum.imag.toDouble(), closeTo(6.0, 1e-5));
    });

    test('operator * - multiplica numeros complexos em precisao 32-bit', () {
      final a = Golang.Complex64.fromDoubles(1.0, 2.0);
      final b = Golang.Complex64.fromDoubles(3.0, 4.0);
      final prod = a * b;
      expect(prod.real.toDouble(), closeTo(-5.0, 1e-5));
      expect(prod.imag.toDouble(), closeTo(10.0, 1e-5));
    });

    test('operator / - divide numeros complexos usando algoritmo Smith', () {
      final a = Golang.Complex64.fromDoubles(1.0, 2.0);
      final b = Golang.Complex64.fromDoubles(1.0, 2.0);
      final div = a / b;
      expect(div.real.toDouble(), closeTo(1.0, 1e-5));
      expect(div.imag.toDouble(), closeTo(0.0, 1e-5));
    });

    test('operator == - compara igualdade de Complex64', () {
      final a = Golang.Complex64.fromDoubles(1.5, -2.5);
      final b = Golang.Complex64.fromDoubles(1.5, -2.5);
      final c = Golang.Complex64.fromDoubles(1.5, 2.5);
      expect(a == b, isTrue);
      expect(a == c, isFalse);
    });

    test('hashCode - retorna hash code do Complex64', () {
      final a = Golang.Complex64.fromDoubles(1.0, 2.0);
      final b = Golang.Complex64.fromDoubles(1.0, 2.0);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString() - formata complex64 para string', () {
      final a = Golang.Complex64.fromDoubles(2.0, 3.0);
      expect(a.toString(), equals("(Instance of 'Float32'+Instance of 'Float32' i)"));
    });
  });

  group('Float32 [Atomic Audit]', () {
    test('toDouble() - converte float32 para double nativo Dart', () {
      final f = Golang.Float32(3.140000104904175);
      expect(f.toDouble(), closeTo(3.14, 1e-2));
    });

    test('toLittleEndianBytes() - exporta bytes little-endian de 4 bytes', () {
      final f = Golang.Float32(1.0);
      final bytes = f.toLittleEndianBytes();
      expect(bytes.length, equals(4));
    });

    test('operator + - adicao com arredondamento binary32', () {
      final a = Golang.Float32(1.5);
      final b = Golang.Float32(2.25);
      expect((a + b).toDouble(), closeTo(3.75, 1e-5));
    });

    test('operator * - multiplicacao com arredondamento binary32', () {
      final a = Golang.Float32(2.0);
      final b = Golang.Float32(3.5);
      expect((a * b).toDouble(), closeTo(7.0, 1e-5));
    });

    test('operator / - divisao de float32', () {
      final a = Golang.Float32(7.0);
      final b = Golang.Float32(2.0);
      expect((a / b).toDouble(), closeTo(3.5, 1e-5));
    });

    test('operator < - comparacao estritamente menor', () {
      expect(Golang.Float32(1.0) < Golang.Float32(2.0), isTrue);
      expect(Golang.Float32(2.0) < Golang.Float32(1.0), isFalse);
    });

    test('operator <= - comparacao menor ou igual', () {
      expect(Golang.Float32(1.0) <= Golang.Float32(1.0), isTrue);
      expect(Golang.Float32(1.0) <= Golang.Float32(2.0), isTrue);
      expect(Golang.Float32(2.0) <= Golang.Float32(1.0), isFalse);
    });

    test('operator > - comparacao estritamente maior', () {
      expect(Golang.Float32(2.0) > Golang.Float32(1.0), isTrue);
      expect(Golang.Float32(1.0) > Golang.Float32(2.0), isFalse);
    });

    test('operator >= - comparacao maior ou igual', () {
      expect(Golang.Float32(2.0) >= Golang.Float32(2.0), isTrue);
      expect(Golang.Float32(2.0) >= Golang.Float32(1.0), isTrue);
      expect(Golang.Float32(1.0) >= Golang.Float32(2.0), isFalse);
    });

    test('operator == - igualdade de float32', () {
      expect(Golang.Float32(4.5) == Golang.Float32(4.5), isTrue);
      expect(Golang.Float32(4.5) == Golang.Float32(4.6), isFalse);
    });

    test('hashCode - hash code baseado no double', () {
      expect(Golang.Float32(1.0).hashCode, equals(Golang.Float32(1.0).hashCode));
    });
  });

  group('Float64 [Atomic Audit]', () {
    test('toDouble() - retorna double nativo exato', () {
      final f = Golang.Float64(3.141592653589793);
      expect(f.toDouble(), equals(3.141592653589793));
    });

    test('toLittleEndianBytes() - exporta bytes little-endian de 8 bytes', () {
      final f = Golang.Float64(1.0);
      final bytes = f.toLittleEndianBytes();
      expect(bytes.length, equals(8));
    });

    test('operator + - adicao float64', () {
      final a = Golang.Float64(1.25);
      final b = Golang.Float64(2.75);
      expect((a + b).toDouble(), equals(4.0));
    });

    test('operator * - multiplicacao float64', () {
      final a = Golang.Float64(2.5);
      final b = Golang.Float64(4.0);
      expect((a * b).toDouble(), equals(10.0));
    });

    test('operator / - divisao float64', () {
      final a = Golang.Float64(10.0);
      final b = Golang.Float64(4.0);
      expect((a / b).toDouble(), equals(2.5));
    });

    test('operator < - comparacao menor que', () {
      expect(Golang.Float64(1.5) < Golang.Float64(2.5), isTrue);
      expect(Golang.Float64(2.5) < Golang.Float64(1.5), isFalse);
    });

    test('operator <= - comparacao menor ou igual', () {
      expect(Golang.Float64(1.5) <= Golang.Float64(1.5), isTrue);
      expect(Golang.Float64(1.5) <= Golang.Float64(2.5), isTrue);
      expect(Golang.Float64(2.5) <= Golang.Float64(1.5), isFalse);
    });

    test('operator > - comparacao maior que', () {
      expect(Golang.Float64(3.0) > Golang.Float64(2.0), isTrue);
      expect(Golang.Float64(2.0) > Golang.Float64(3.0), isFalse);
    });

    test('operator >= - comparacao maior ou igual', () {
      expect(Golang.Float64(3.0) >= Golang.Float64(3.0), isTrue);
      expect(Golang.Float64(3.0) >= Golang.Float64(2.0), isTrue);
      expect(Golang.Float64(2.0) >= Golang.Float64(3.0), isFalse);
    });

    test('operator == - igualdade de Float64', () {
      expect(Golang.Float64(5.0) == Golang.Float64(5.0), isTrue);
      expect(Golang.Float64(5.0) == Golang.Float64(5.1), isFalse);
    });

    test('hashCode - hash code do Float64', () {
      expect(Golang.Float64(2.5).hashCode, equals(Golang.Float64(2.5).hashCode));
    });
  });

  group('Int8 [Atomic Audit]', () {
    test('toBigInt() - retorna valor com sinal em 8 bits', () {
      expect(Golang.Int8(0).toBigInt(), equals(BigInt.zero));
      expect(Golang.Int8(127).toBigInt(), equals(BigInt.from(127)));
      expect(Golang.Int8(-128).toBigInt(), equals(BigInt.from(-128)));
      expect(Golang.Int8(255).toBigInt(), equals(BigInt.from(-1)));
    });

    test('toUint8() - converte para Uint8 preservando bits', () {
      final u = Golang.Int8(-1).toUint8();
      expect(u.toBigInt(), equals(BigInt.from(255)));
    });

    test('toLittleEndianBytes() - exporta byte unico', () {
      final bytes = Golang.Int8(42).toLittleEndianBytes();
      expect(bytes.length, equals(1));
      expect(bytes[0], equals(42));
    });

    test('operator + - adicao com overflow signed', () {
      final a = Golang.Int8(127);
      final b = Golang.Int8(1);
      expect((a + b).toBigInt(), equals(BigInt.from(-128)));
    });

    test('operator * - multiplicacao com overflow signed', () {
      final a = Golang.Int8(20);
      final b = Golang.Int8(10);
      expect((a * b).toBigInt(), equals(BigInt.from(-56)));
    });

    test('operator ~/ - divisao inteira em direcao ao zero', () {
      final a = Golang.Int8(-7);
      final b = Golang.Int8(2);
      expect((a ~/ b).toBigInt(), equals(BigInt.from(-3)));
    });

    test('operator % - resto com sinal do dividendo', () {
      final a = Golang.Int8(-7);
      final b = Golang.Int8(2);
      expect((a % b).toBigInt(), equals(BigInt.from(-1)));
    });

    test('operator & - bitwise AND', () {
      final a = Golang.Int8(12);
      final b = Golang.Int8(10);
      expect((a & b).toBigInt(), equals(BigInt.from(8)));
    });

    test('operator | - bitwise OR', () {
      final a = Golang.Int8(12);
      final b = Golang.Int8(10);
      expect((a | b).toBigInt(), equals(BigInt.from(14)));
    });

    test('operator ^ - bitwise XOR', () {
      final a = Golang.Int8(12);
      final b = Golang.Int8(10);
      expect((a ^ b).toBigInt(), equals(BigInt.from(6)));
    });

    test('operator ~ - complemento bit a bit', () {
      final a = Golang.Int8(0);
      expect((~a).toBigInt(), equals(BigInt.from(-1)));
    });

    test('andNot() - operacao bitwise clear Go', () {
      final a = Golang.Int8(15);
      final b = Golang.Int8(3);
      expect(a.andNot(b).toBigInt(), equals(BigInt.from(12)));
    });

    test('operator << - shift left com truncamento 8-bit', () {
      final a = Golang.Int8(1);
      expect((a << 2).toBigInt(), equals(BigInt.from(4)));
      expect((a << 8).toBigInt(), equals(BigInt.zero));
    });

    test('operator >> - shift right aritmetico', () {
      final a = Golang.Int8(-8);
      expect((a >> 1).toBigInt(), equals(BigInt.from(-4)));
      expect((a >> 8).toBigInt(), equals(BigInt.from(-1)));
      expect(() => a >> -1, throwsA(isA<ArgumentError>()));
    });

    test('compareTo() - comparacao ordinal com sinal', () {
      expect(Golang.Int8(-5).compareTo(Golang.Int8(5)), lessThan(0));
      expect(Golang.Int8(5).compareTo(Golang.Int8(5)), equals(0));
      expect(Golang.Int8(5).compareTo(Golang.Int8(-5)), greaterThan(0));
    });

    test('operator < - operador menor que com sinal', () {
      expect(Golang.Int8(-10) < Golang.Int8(5), isTrue);
      expect(Golang.Int8(5) < Golang.Int8(-10), isFalse);
    });

    test('operator <= - operador menor ou igual com sinal', () {
      expect(Golang.Int8(-10) <= Golang.Int8(-10), isTrue);
      expect(Golang.Int8(-10) <= Golang.Int8(5), isTrue);
      expect(Golang.Int8(5) <= Golang.Int8(-10), isFalse);
    });

    test('operator > - operador maior que com sinal', () {
      expect(Golang.Int8(10) > Golang.Int8(-5), isTrue);
      expect(Golang.Int8(-5) > Golang.Int8(10), isFalse);
    });

    test('operator >= - operador maior ou igual com sinal', () {
      expect(Golang.Int8(10) >= Golang.Int8(10), isTrue);
      expect(Golang.Int8(10) >= Golang.Int8(5), isTrue);
      expect(Golang.Int8(-5) >= Golang.Int8(10), isFalse);
    });

    test('operator == - igualdade de bits de Int8', () {
      expect(Golang.Int8(42) == Golang.Int8(42), isTrue);
      expect(Golang.Int8(42) == Golang.Int8(-42), isFalse);
    });

    test('hashCode - hash code consistente', () {
      expect(Golang.Int8(42).hashCode, equals(BigInt.from(42).hashCode));
    });

    test('toString() - representacao em string do valor signed', () {
      expect(Golang.Int8(-128).toString(), equals('-128'));
      expect(Golang.Int8(127).toString(), equals('127'));
    });
  });

  group('Int16 [Atomic Audit]', () {
    test('toBigInt() - retorna valor assinado em 16 bits', () {
      expect(Golang.Int16(-32768).toBigInt(), equals(BigInt.from(-32768)));
      expect(Golang.Int16(32767).toBigInt(), equals(BigInt.from(32767)));
    });

    test('toUint16() - converte para Uint16 preservando bits', () {
      final u = Golang.Int16(-1).toUint16();
      expect(u.toBigInt(), equals(BigInt.from(65535)));
    });

    test('toLittleEndianBytes() - exporta 2 bytes little-endian', () {
      final bytes = Golang.Int16(0x1234).toLittleEndianBytes();
      expect(bytes.length, equals(2));
      expect(bytes[0], equals(0x34));
      expect(bytes[1], equals(0x12));
    });

    test('operator + - adicao com overflow signed 16-bit', () {
      final a = Golang.Int16(32767);
      final b = Golang.Int16(1);
      expect((a + b).toBigInt(), equals(BigInt.from(-32768)));
    });

    test('operator * - multiplicacao com overflow signed 16-bit', () {
      final a = Golang.Int16(1000);
      final b = Golang.Int16(100);
      expect((a * b).toBigInt(), equals(BigInt.from(-31072)));
    });

    test('operator ~/ - divisao inteira truncada para zero', () {
      final a = Golang.Int16(-15);
      final b = Golang.Int16(4);
      expect((a ~/ b).toBigInt(), equals(BigInt.from(-3)));
    });

    test('operator % - resto com sinal do dividendo', () {
      final a = Golang.Int16(-15);
      final b = Golang.Int16(4);
      expect((a % b).toBigInt(), equals(BigInt.from(-3)));
    });

    test('operator & - bitwise AND em 16 bits', () {
      final a = Golang.Int16(0x00FF);
      final b = Golang.Int16(0x0F0F);
      expect((a & b).toBigInt(), equals(BigInt.from(0x000F)));
    });

    test('operator | - bitwise OR em 16 bits', () {
      final a = Golang.Int16(0x00F0);
      final b = Golang.Int16(0x0F00);
      expect((a | b).toBigInt(), equals(BigInt.from(0x0FF0)));
    });

    test('operator ^ - bitwise XOR em 16 bits', () {
      final a = Golang.Int16(0x00FF);
      final b = Golang.Int16(0x0FFF);
      expect((a ^ b).toBigInt(), equals(BigInt.from(0x0F00)));
    });

    test('operator ~ - complemento bit a bit 16-bit', () {
      final a = Golang.Int16(0);
      expect((~a).toBigInt(), equals(BigInt.from(-1)));
    });

    test('andNot() - operacao bitwise clear Go 16-bit', () {
      final a = Golang.Int16(0x00FF);
      final b = Golang.Int16(0x000F);
      expect(a.andNot(b).toBigInt(), equals(BigInt.from(0x00F0)));
    });

    test('operator << - shift left com truncamento 16-bit', () {
      final a = Golang.Int16(1);
      expect((a << 15).toBigInt(), equals(BigInt.from(-32768)));
      expect((a << 16).toBigInt(), equals(BigInt.zero));
    });

    test('operator >> - shift right aritmetico 16-bit', () {
      final a = Golang.Int16(-16);
      expect((a >> 2).toBigInt(), equals(BigInt.from(-4)));
      expect((a >> 16).toBigInt(), equals(BigInt.from(-1)));
      expect(() => a >> -1, throwsA(isA<ArgumentError>()));
    });

    test('compareTo() - comparacao ordinal signed 16-bit', () {
      expect(Golang.Int16(-100).compareTo(Golang.Int16(100)), lessThan(0));
      expect(Golang.Int16(100).compareTo(Golang.Int16(100)), equals(0));
      expect(Golang.Int16(100).compareTo(Golang.Int16(-100)), greaterThan(0));
    });

    test('operator < - operador menor que signed 16-bit', () {
      expect(Golang.Int16(-50) < Golang.Int16(50), isTrue);
      expect(Golang.Int16(50) < Golang.Int16(-50), isFalse);
    });

    test('operator <= - operador menor ou igual signed 16-bit', () {
      expect(Golang.Int16(50) <= Golang.Int16(50), isTrue);
      expect(Golang.Int16(-50) <= Golang.Int16(50), isTrue);
      expect(Golang.Int16(50) <= Golang.Int16(-50), isFalse);
    });

    test('operator > - operador maior que signed 16-bit', () {
      expect(Golang.Int16(50) > Golang.Int16(-50), isTrue);
      expect(Golang.Int16(-50) > Golang.Int16(50), isFalse);
    });

    test('operator >= - operador maior ou igual signed 16-bit', () {
      expect(Golang.Int16(50) >= Golang.Int16(50), isTrue);
      expect(Golang.Int16(50) >= Golang.Int16(-50), isTrue);
      expect(Golang.Int16(-50) >= Golang.Int16(50), isFalse);
    });

    test('operator == - igualdade de Int16', () {
      expect(Golang.Int16(1234) == Golang.Int16(1234), isTrue);
      expect(Golang.Int16(1234) == Golang.Int16(4321), isFalse);
    });

    test('hashCode - hash code do Int16', () {
      expect(Golang.Int16(1234).hashCode, equals(BigInt.from(1234).hashCode));
    });

    test('toString() - representacao textual de Int16', () {
      expect(Golang.Int16(-32768).toString(), equals('-32768'));
      expect(Golang.Int16(32767).toString(), equals('32767'));
    });
  });

  group('Int32 [Atomic Audit]', () {
    test('toBigInt() - retorna valor assinado em 32 bits', () {
      expect(Golang.Int32(-2147483648).toBigInt(), equals(BigInt.from(-2147483648)));
      expect(Golang.Int32(2147483647).toBigInt(), equals(BigInt.from(2147483647)));
    });

    test('toUint32() - converte para Uint32 preservando bits', () {
      final u = Golang.Int32(-1).toUint32();
      expect(u.toBigInt(), equals(BigInt.from(4294967295)));
    });

    test('toLittleEndianBytes() - exporta 4 bytes little-endian', () {
      final bytes = Golang.Int32(0x12345678).toLittleEndianBytes();
      expect(bytes.length, equals(4));
      expect(bytes[0], equals(0x78));
      expect(bytes[1], equals(0x56));
      expect(bytes[2], equals(0x34));
      expect(bytes[3], equals(0x12));
    });

    test('operator + - adicao com overflow signed 32-bit', () {
      final a = Golang.Int32(2147483647);
      final b = Golang.Int32(1);
      expect((a + b).toBigInt(), equals(BigInt.from(-2147483648)));
    });

    test('operator * - multiplicacao com overflow signed 32-bit', () {
      final a = Golang.Int32(100000);
      final b = Golang.Int32(100000);
      expect((a * b).toBigInt(), equals(BigInt.from(1410065408)));
    });

    test('operator ~/ - divisao inteira truncada para zero', () {
      final a = Golang.Int32(-100);
      final b = Golang.Int32(9);
      expect((a ~/ b).toBigInt(), equals(BigInt.from(-11)));
    });

    test('operator % - resto com sinal do dividendo', () {
      final a = Golang.Int32(-100);
      final b = Golang.Int32(9);
      expect((a % b).toBigInt(), equals(BigInt.from(-1)));
    });

    test('operator & - bitwise AND em 32 bits', () {
      final a = Golang.Int32(0x0000FFFF);
      final b = Golang.Int32(0x00FF00FF);
      expect((a & b).toBigInt(), equals(BigInt.from(0x000000FF)));
    });

    test('operator | - bitwise OR em 32 bits', () {
      final a = Golang.Int32(0x0000FF00);
      final b = Golang.Int32(0x00FF0000);
      expect((a | b).toBigInt(), equals(BigInt.from(0x00FFFF00)));
    });

    test('operator ^ - bitwise XOR em 32 bits', () {
      final a = Golang.Int32(0x0000FFFF);
      final b = Golang.Int32(0x000FFFFF);
      expect((a ^ b).toBigInt(), equals(BigInt.from(0x000F0000)));
    });

    test('operator ~ - complemento bit a bit 32-bit', () {
      final a = Golang.Int32(0);
      expect((~a).toBigInt(), equals(BigInt.from(-1)));
    });

    test('andNot() - operacao bitwise clear Go 32-bit', () {
      final a = Golang.Int32(0x0000FFFF);
      final b = Golang.Int32(0x000000FF);
      expect(a.andNot(b).toBigInt(), equals(BigInt.from(0x0000FF00)));
    });

    test('operator << - shift left com truncamento 32-bit', () {
      final a = Golang.Int32(1);
      expect((a << 31).toBigInt(), equals(BigInt.from(-2147483648)));
      expect((a << 32).toBigInt(), equals(BigInt.zero));
    });

    test('operator >> - shift right aritmetico 32-bit', () {
      final a = Golang.Int32(-32);
      expect((a >> 3).toBigInt(), equals(BigInt.from(-4)));
      expect((a >> 32).toBigInt(), equals(BigInt.from(-1)));
      expect(() => a >> -1, throwsA(isA<ArgumentError>()));
    });

    test('compareTo() - comparacao ordinal signed 32-bit', () {
      expect(Golang.Int32(-1000).compareTo(Golang.Int32(1000)), lessThan(0));
      expect(Golang.Int32(1000).compareTo(Golang.Int32(1000)), equals(0));
      expect(Golang.Int32(1000).compareTo(Golang.Int32(-1000)), greaterThan(0));
    });

    test('operator < - operador menor que signed 32-bit', () {
      expect(Golang.Int32(-500) < Golang.Int32(500), isTrue);
      expect(Golang.Int32(500) < Golang.Int32(-500), isFalse);
    });

    test('operator <= - operador menor ou igual signed 32-bit', () {
      expect(Golang.Int32(500) <= Golang.Int32(500), isTrue);
      expect(Golang.Int32(-500) <= Golang.Int32(500), isTrue);
      expect(Golang.Int32(500) <= Golang.Int32(-500), isFalse);
    });

    test('operator > - operador maior que signed 32-bit', () {
      expect(Golang.Int32(500) > Golang.Int32(-500), isTrue);
      expect(Golang.Int32(-500) > Golang.Int32(500), isFalse);
    });

    test('operator >= - operador maior ou igual signed 32-bit', () {
      expect(Golang.Int32(500) >= Golang.Int32(500), isTrue);
      expect(Golang.Int32(500) >= Golang.Int32(-500), isTrue);
      expect(Golang.Int32(-500) >= Golang.Int32(500), isFalse);
    });

    test('operator == - igualdade de Int32', () {
      expect(Golang.Int32(100000) == Golang.Int32(100000), isTrue);
      expect(Golang.Int32(100000) == Golang.Int32(200000), isFalse);
    });

    test('hashCode - hash code do Int32', () {
      expect(Golang.Int32(100000).hashCode, equals(BigInt.from(100000).hashCode));
    });

    test('toString() - representacao textual de Int32', () {
      expect(Golang.Int32(-2147483648).toString(), equals('-2147483648'));
      expect(Golang.Int32(2147483647).toString(), equals('2147483647'));
    });
  });

  group('Int64 [Atomic Audit]', () {
    test('toBigInt() - retorna valor exato em 64 bits assinado', () {
      final minVal = BigInt.parse('-9223372036854775808');
      final maxVal = BigInt.parse('9223372036854775807');
      expect(Golang.Int64.fromBigInt(minVal).toBigInt(), equals(minVal));
      expect(Golang.Int64.fromBigInt(maxVal).toBigInt(), equals(maxVal));
    });

    test('toIntExact() - retorna int nativo ou lanca UnsupportedError', () {
      expect(Golang.Int64(12345).toIntExact(), equals(12345));
    });

    test('toUint64() - converte para Uint64 preservando padrao de bits', () {
      final u = Golang.Int64(-1).toUint64();
      expect(u.toBigInt(), equals(BigInt.parse('18446744073709551615')));
    });

    test('toLittleEndianBytes() - exporta 8 bytes little-endian', () {
      final bytes = Golang.Int64(0x0102030405060708).toLittleEndianBytes();
      expect(bytes.length, equals(8));
      expect(bytes[0], equals(0x08));
      expect(bytes[7], equals(0x01));
    });

    test('operator + - adicao com overflow signed 64-bit', () {
      final maxVal = BigInt.parse('9223372036854775807');
      final minVal = BigInt.parse('-9223372036854775808');
      final a = Golang.Int64.fromBigInt(maxVal);
      final b = Golang.Int64(1);
      expect((a + b).toBigInt(), equals(minVal));
    });

    test('operator * - multiplicacao com overflow signed 64-bit', () {
      final a = Golang.Int64.fromBigInt(BigInt.parse('4000000000'));
      final b = Golang.Int64.fromBigInt(BigInt.parse('3000000000'));
      final prod = a * b;
      expect(prod.toBigInt(), equals(BigInt.parse('-6446744073709551616')));
    });

    test('operator ~/ - divisao inteira Go 64-bit', () {
      final a = Golang.Int64(-100);
      final b = Golang.Int64(7);
      expect((a ~/ b).toBigInt(), equals(BigInt.from(-14)));
    });

    test('operator % - resto Go com sinal do dividendo', () {
      final a = Golang.Int64(-100);
      final b = Golang.Int64(7);
      expect((a % b).toBigInt(), equals(BigInt.from(-2)));
    });

    test('operator & - bitwise AND 64-bit', () {
      final a = Golang.Int64(0x0000FFFF0000FFFF);
      final b = Golang.Int64(0x00FF00FF00FF00FF);
      expect((a & b).toBigInt(), equals(BigInt.from(0x000000FF000000FF)));
    });

    test('operator | - bitwise OR 64-bit', () {
      final a = Golang.Int64(0x0000FF000000FF00);
      final b = Golang.Int64(0x00FF000000FF0000);
      expect((a | b).toBigInt(), equals(BigInt.from(0x00FFFF0000FFFF00)));
    });

    test('operator ^ - bitwise XOR 64-bit', () {
      final a = Golang.Int64(0x0000FFFF0000FFFF);
      final b = Golang.Int64(0x000FFFFF000FFFFF);
      expect((a ^ b).toBigInt(), equals(BigInt.from(0x000F0000000F0000)));
    });

    test('operator ~ - complemento bit a bit 64-bit', () {
      final a = Golang.Int64(0);
      expect((~a).toBigInt(), equals(BigInt.from(-1)));
    });

    test('andNot() - operacao bitwise clear Go 64-bit', () {
      final a = Golang.Int64(0x0000FFFF);
      final b = Golang.Int64(0x000000FF);
      expect(a.andNot(b).toBigInt(), equals(BigInt.from(0x0000FF00)));
    });

    test('operator << - shift left com truncamento 64-bit', () {
      final a = Golang.Int64(1);
      expect((a << 63).toBigInt(), equals(BigInt.parse('-9223372036854775808')));
      expect((a << 64).toBigInt(), equals(BigInt.zero));
    });

    test('operator >> - shift right aritmetico 64-bit', () {
      final a = Golang.Int64(-64);
      expect((a >> 3).toBigInt(), equals(BigInt.from(-8)));
      expect((a >> 64).toBigInt(), equals(BigInt.from(-1)));
      expect(() => a >> -1, throwsA(isA<ArgumentError>()));
    });

    test('compareTo() - comparacao ordinal signed 64-bit', () {
      expect(Golang.Int64(-5000).compareTo(Golang.Int64(5000)), lessThan(0));
      expect(Golang.Int64(5000).compareTo(Golang.Int64(5000)), equals(0));
      expect(Golang.Int64(5000).compareTo(Golang.Int64(-5000)), greaterThan(0));
    });

    test('operator < - operador menor que signed 64-bit', () {
      expect(Golang.Int64(-1000) < Golang.Int64(1000), isTrue);
      expect(Golang.Int64(1000) < Golang.Int64(-1000), isFalse);
    });

    test('operator <= - operador menor ou igual signed 64-bit', () {
      expect(Golang.Int64(1000) <= Golang.Int64(1000), isTrue);
      expect(Golang.Int64(-1000) <= Golang.Int64(1000), isTrue);
      expect(Golang.Int64(1000) <= Golang.Int64(-1000), isFalse);
    });

    test('operator > - operador maior que signed 64-bit', () {
      expect(Golang.Int64(1000) > Golang.Int64(-1000), isTrue);
      expect(Golang.Int64(-1000) > Golang.Int64(1000), isFalse);
    });

    test('operator >= - operador maior ou igual signed 64-bit', () {
      expect(Golang.Int64(1000) >= Golang.Int64(1000), isTrue);
      expect(Golang.Int64(1000) >= Golang.Int64(-1000), isTrue);
      expect(Golang.Int64(-1000) >= Golang.Int64(1000), isFalse);
    });

    test('operator == - igualdade de Int64', () {
      expect(Golang.Int64(987654321) == Golang.Int64(987654321), isTrue);
      expect(Golang.Int64(987654321) == Golang.Int64(-987654321), isFalse);
    });

    test('hashCode - hash code do Int64', () {
      expect(Golang.Int64(987654321).hashCode, equals(BigInt.from(987654321).hashCode));
    });

    test('toString() - representacao textual de Int64', () {
      final minStr = '-9223372036854775808';
      expect(Golang.Int64.fromBigInt(BigInt.parse(minStr)).toString(), equals(minStr));
    });
  });

  group('String [Atomic Audit]', () {
    test('length - retorna tamanho em bytes e nao caracteres', () {
      final s = Golang.String.fromDart('Ola');
      expect(s.length, equals(3));
      final sUtf8 = Golang.String.fromDart('Olá');
      expect(sUtf8.length, equals(4));
    });

    test('operator [] - acesso indexado ao byte', () {
      final s = Golang.String.fromDart('Go');
      expect(s[0], equals(71));
      expect(s[1], equals(111));
      expect(() => s[2], throwsA(isA<RangeError>()));
    });

    test('toBytes() - retorna Uint8List independente e mutavel', () {
      final s = Golang.String.fromDart('P2P');
      final bytes = s.toBytes();
      expect(bytes, equals(Uint8List.fromList([80, 50, 80])));
      bytes[0] = 0;
      expect(s[0], equals(80));
    });

    test('toDart() - decodifica UTF-8 estrito', () {
      final s = Golang.String.fromDart('Dart IPFS');
      expect(s.toDart(), equals('Dart IPFS'));
    });

    test('slice() - recorta substring em limites de bytes', () {
      final s = Golang.String.fromDart('abcdef');
      final sub = s.slice(1, 4);
      expect(sub.toDart(), equals('bcd'));
      expect(() => s.slice(4, 2), throwsA(isA<RangeError>()));
    });

    test('operator + - concatenacao preservando bytes', () {
      final a = Golang.String.fromDart('Hello, ');
      final b = Golang.String.fromDart('World!');
      final combined = a + b;
      expect(combined.toDart(), equals('Hello, World!'));
    });

    test('compareTo() - comparacao lexicografica por bytes', () {
      final a = Golang.String.fromDart('abc');
      final b = Golang.String.fromDart('abd');
      expect(a.compareTo(b), lessThan(0));
      expect(b.compareTo(a), greaterThan(0));
      expect(a.compareTo(a), equals(0));
    });

    test('operator < - comparacao lexicografica menor que', () {
      final a = Golang.String.fromDart('apple');
      final b = Golang.String.fromDart('banana');
      expect(a < b, isTrue);
      expect(b < a, isFalse);
    });

    test('operator <= - comparacao lexicografica menor ou igual', () {
      final a = Golang.String.fromDart('apple');
      final b = Golang.String.fromDart('apple');
      final c = Golang.String.fromDart('banana');
      expect(a <= b, isTrue);
      expect(a <= c, isTrue);
      expect(c <= a, isFalse);
    });

    test('operator > - comparacao lexicografica maior que', () {
      final a = Golang.String.fromDart('zebra');
      final b = Golang.String.fromDart('apple');
      expect(a > b, isTrue);
      expect(b > a, isFalse);
    });

    test('operator >= - comparacao lexicografica maior ou igual', () {
      final a = Golang.String.fromDart('zebra');
      final b = Golang.String.fromDart('zebra');
      final c = Golang.String.fromDart('apple');
      expect(a >= b, isTrue);
      expect(a >= c, isTrue);
      expect(c >= a, isFalse);
    });

    test('operator == - igualdade de strings Go por bytes', () {
      final a = Golang.String.fromDart('test');
      final b = Golang.String.fromDart('test');
      final c = Golang.String.fromDart('other');
      expect(a == b, isTrue);
      expect(a == c, isFalse);
    });

    test('hashCode - hash code baseado em bytes', () {
      final a = Golang.String.fromDart('test');
      final b = Golang.String.fromDart('test');
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('Uint8 [Atomic Audit]', () {
    test('toBigInt() - retorna unsigned exato', () {
      expect(Golang.Uint8(0).toBigInt(), equals(BigInt.zero));
      expect(Golang.Uint8(255).toBigInt(), equals(BigInt.from(255)));
      expect(Golang.Uint8(256).toBigInt(), equals(BigInt.zero));
    });

    test('toLittleEndianBytes() - exporta byte unico', () {
      final bytes = Golang.Uint8(200).toLittleEndianBytes();
      expect(bytes.length, equals(1));
      expect(bytes[0], equals(200));
    });

    test('operator + - adicao modulo 2^8', () {
      final a = Golang.Uint8(250);
      final b = Golang.Uint8(10);
      expect((a + b).toBigInt(), equals(BigInt.from(4)));
    });

    test('operator * - multiplicacao modulo 2^8', () {
      final a = Golang.Uint8(16);
      final b = Golang.Uint8(16);
      expect((a * b).toBigInt(), equals(BigInt.zero));
    });

    test('operator ~/ - divisao unsigned', () {
      final a = Golang.Uint8(100);
      final b = Golang.Uint8(7);
      expect((a ~/ b).toBigInt(), equals(BigInt.from(14)));
    });

    test('operator % - resto unsigned', () {
      final a = Golang.Uint8(100);
      final b = Golang.Uint8(7);
      expect((a % b).toBigInt(), equals(BigInt.from(2)));
    });

    test('operator & - bitwise AND unsigned', () {
      final a = Golang.Uint8(0xF0);
      final b = Golang.Uint8(0x3C);
      expect((a & b).toBigInt(), equals(BigInt.from(0x30)));
    });

    test('operator | - bitwise OR unsigned', () {
      final a = Golang.Uint8(0xF0);
      final b = Golang.Uint8(0x0F);
      expect((a | b).toBigInt(), equals(BigInt.from(0xFF)));
    });

    test('operator ^ - bitwise XOR unsigned', () {
      final a = Golang.Uint8(0xFF);
      final b = Golang.Uint8(0x0F);
      expect((a ^ b).toBigInt(), equals(BigInt.from(0xF0)));
    });

    test('operator ~ - complemento bit a bit unsigned 8-bit', () {
      final a = Golang.Uint8(0);
      expect((~a).toBigInt(), equals(BigInt.from(255)));
    });

    test('andNot() - operacao bitwise clear Go unsigned 8-bit', () {
      final a = Golang.Uint8(0xFF);
      final b = Golang.Uint8(0x0F);
      expect(a.andNot(b).toBigInt(), equals(BigInt.from(0xF0)));
    });

    test('operator << - shift left logico unsigned', () {
      final a = Golang.Uint8(1);
      expect((a << 7).toBigInt(), equals(BigInt.from(128)));
      expect((a << 8).toBigInt(), equals(BigInt.zero));
      expect(() => a << -1, throwsA(isA<ArgumentError>()));
    });

    test('operator >> - shift right logico unsigned', () {
      final a = Golang.Uint8(128);
      expect((a >> 7).toBigInt(), equals(BigInt.one));
      expect((a >> 8).toBigInt(), equals(BigInt.zero));
      expect(() => a >> -1, throwsA(isA<ArgumentError>()));
    });

    test('compareTo() - comparacao ordinal unsigned 8-bit', () {
      expect(Golang.Uint8(10).compareTo(Golang.Uint8(20)), lessThan(0));
      expect(Golang.Uint8(20).compareTo(Golang.Uint8(20)), equals(0));
      expect(Golang.Uint8(20).compareTo(Golang.Uint8(10)), greaterThan(0));
    });

    test('operator < - menor que unsigned 8-bit', () {
      expect(Golang.Uint8(10) < Golang.Uint8(20), isTrue);
      expect(Golang.Uint8(20) < Golang.Uint8(10), isFalse);
    });

    test('operator <= - menor ou igual unsigned 8-bit', () {
      expect(Golang.Uint8(20) <= Golang.Uint8(20), isTrue);
      expect(Golang.Uint8(10) <= Golang.Uint8(20), isTrue);
      expect(Golang.Uint8(20) <= Golang.Uint8(10), isFalse);
    });

    test('operator > - maior que unsigned 8-bit', () {
      expect(Golang.Uint8(30) > Golang.Uint8(20), isTrue);
      expect(Golang.Uint8(20) > Golang.Uint8(30), isFalse);
    });

    test('operator >= - maior ou igual unsigned 8-bit', () {
      expect(Golang.Uint8(30) >= Golang.Uint8(30), isTrue);
      expect(Golang.Uint8(30) >= Golang.Uint8(20), isTrue);
      expect(Golang.Uint8(20) >= Golang.Uint8(30), isFalse);
    });

    test('operator == - igualdade de Uint8', () {
      expect(Golang.Uint8(123) == Golang.Uint8(123), isTrue);
      expect(Golang.Uint8(123) == Golang.Uint8(124), isFalse);
    });

    test('hashCode - hash code de Uint8', () {
      expect(Golang.Uint8(123).hashCode, equals(BigInt.from(123).hashCode));
    });

    test('toString() - representacao textual de Uint8', () {
      expect(Golang.Uint8(255).toString(), equals('255'));
    });
  });

  group('Uint16 [Atomic Audit]', () {
    test('toBigInt() - retorna unsigned exato em 16 bits', () {
      expect(Golang.Uint16(0).toBigInt(), equals(BigInt.zero));
      expect(Golang.Uint16(65535).toBigInt(), equals(BigInt.from(65535)));
      expect(Golang.Uint16(65536).toBigInt(), equals(BigInt.zero));
    });

    test('toLittleEndianBytes() - exporta 2 bytes little-endian', () {
      final bytes = Golang.Uint16(0xAABB).toLittleEndianBytes();
      expect(bytes.length, equals(2));
      expect(bytes[0], equals(0xBB));
      expect(bytes[1], equals(0xAA));
    });

    test('operator + - adicao modulo 2^16', () {
      final a = Golang.Uint16(65530);
      final b = Golang.Uint16(10);
      expect((a + b).toBigInt(), equals(BigInt.from(4)));
    });

    test('operator * - multiplicacao modulo 2^16', () {
      final a = Golang.Uint16(256);
      final b = Golang.Uint16(256);
      expect((a * b).toBigInt(), equals(BigInt.zero));
    });

    test('operator ~/ - divisao unsigned 16-bit', () {
      final a = Golang.Uint16(1000);
      final b = Golang.Uint16(30);
      expect((a ~/ b).toBigInt(), equals(BigInt.from(33)));
    });

    test('operator % - resto unsigned 16-bit', () {
      final a = Golang.Uint16(1000);
      final b = Golang.Uint16(30);
      expect((a % b).toBigInt(), equals(BigInt.from(10)));
    });

    test('operator & - bitwise AND unsigned 16-bit', () {
      final a = Golang.Uint16(0xFF00);
      final b = Golang.Uint16(0x0FF0);
      expect((a & b).toBigInt(), equals(BigInt.from(0x0F00)));
    });

    test('operator | - bitwise OR unsigned 16-bit', () {
      final a = Golang.Uint16(0xF000);
      final b = Golang.Uint16(0x0F00);
      expect((a | b).toBigInt(), equals(BigInt.from(0xFF00)));
    });

    test('operator ^ - bitwise XOR unsigned 16-bit', () {
      final a = Golang.Uint16(0xFFFF);
      final b = Golang.Uint16(0x00FF);
      expect((a ^ b).toBigInt(), equals(BigInt.from(0xFF00)));
    });

    test('operator ~ - complemento bit a bit unsigned 16-bit', () {
      final a = Golang.Uint16(0);
      expect((~a).toBigInt(), equals(BigInt.from(65535)));
    });

    test('andNot() - operacao bitwise clear Go unsigned 16-bit', () {
      final a = Golang.Uint16(0xFFFF);
      final b = Golang.Uint16(0x00FF);
      expect(a.andNot(b).toBigInt(), equals(BigInt.from(0xFF00)));
    });

    test('operator << - shift left logico unsigned 16-bit', () {
      final a = Golang.Uint16(1);
      expect((a << 15).toBigInt(), equals(BigInt.from(32768)));
      expect((a << 16).toBigInt(), equals(BigInt.zero));
      expect(() => a << -1, throwsA(isA<ArgumentError>()));
    });

    test('operator >> - shift right logico unsigned 16-bit', () {
      final a = Golang.Uint16(32768);
      expect((a >> 15).toBigInt(), equals(BigInt.one));
      expect((a >> 16).toBigInt(), equals(BigInt.zero));
      expect(() => a >> -1, throwsA(isA<ArgumentError>()));
    });

    test('compareTo() - comparacao ordinal unsigned 16-bit', () {
      expect(Golang.Uint16(100).compareTo(Golang.Uint16(200)), lessThan(0));
      expect(Golang.Uint16(200).compareTo(Golang.Uint16(200)), equals(0));
      expect(Golang.Uint16(200).compareTo(Golang.Uint16(100)), greaterThan(0));
    });

    test('operator < - menor que unsigned 16-bit', () {
      expect(Golang.Uint16(100) < Golang.Uint16(200), isTrue);
      expect(Golang.Uint16(200) < Golang.Uint16(100), isFalse);
    });

    test('operator <= - menor ou igual unsigned 16-bit', () {
      expect(Golang.Uint16(200) <= Golang.Uint16(200), isTrue);
      expect(Golang.Uint16(100) <= Golang.Uint16(200), isTrue);
      expect(Golang.Uint16(200) <= Golang.Uint16(100), isFalse);
    });

    test('operator > - maior que unsigned 16-bit', () {
      expect(Golang.Uint16(300) > Golang.Uint16(200), isTrue);
      expect(Golang.Uint16(200) > Golang.Uint16(300), isFalse);
    });

    test('operator >= - maior ou igual unsigned 16-bit', () {
      expect(Golang.Uint16(300) >= Golang.Uint16(300), isTrue);
      expect(Golang.Uint16(300) >= Golang.Uint16(200), isTrue);
      expect(Golang.Uint16(200) >= Golang.Uint16(300), isFalse);
    });

    test('operator == - igualdade de Uint16', () {
      expect(Golang.Uint16(4321) == Golang.Uint16(4321), isTrue);
      expect(Golang.Uint16(4321) == Golang.Uint16(1234), isFalse);
    });

    test('hashCode - hash code de Uint16', () {
      expect(Golang.Uint16(4321).hashCode, equals(BigInt.from(4321).hashCode));
    });

    test('toString() - representacao textual de Uint16', () {
      expect(Golang.Uint16(65535).toString(), equals('65535'));
    });
  });

  group('Uint32 [Atomic Audit]', () {
    test('toBigInt() - retorna unsigned exato em 32 bits', () {
      expect(Golang.Uint32(0).toBigInt(), equals(BigInt.zero));
      expect(Golang.Uint32.fromBigInt(BigInt.parse('4294967295')).toBigInt(), equals(BigInt.parse('4294967295')));
    });

    test('toLittleEndianBytes() - exporta 4 bytes little-endian', () {
      final bytes = Golang.Uint32(0x11223344).toLittleEndianBytes();
      expect(bytes.length, equals(4));
      expect(bytes[0], equals(0x44));
      expect(bytes[1], equals(0x33));
      expect(bytes[2], equals(0x22));
      expect(bytes[3], equals(0x11));
    });

    test('operator + - adicao modulo 2^32', () {
      final maxVal = BigInt.parse('4294967295');
      final a = Golang.Uint32.fromBigInt(maxVal);
      final b = Golang.Uint32(1);
      expect((a + b).toBigInt(), equals(BigInt.zero));
    });

    test('operator * - multiplicacao modulo 2^32', () {
      final a = Golang.Uint32(65536);
      final b = Golang.Uint32(65536);
      expect((a * b).toBigInt(), equals(BigInt.zero));
    });

    test('operator ~/ - divisao unsigned 32-bit', () {
      final a = Golang.Uint32(100000);
      final b = Golang.Uint32(300);
      expect((a ~/ b).toBigInt(), equals(BigInt.from(333)));
    });

    test('operator % - resto unsigned 32-bit', () {
      final a = Golang.Uint32(100000);
      final b = Golang.Uint32(300);
      expect((a % b).toBigInt(), equals(BigInt.from(100)));
    });

    test('operator & - bitwise AND unsigned 32-bit', () {
      final a = Golang.Uint32(0xFFFF0000);
      final b = Golang.Uint32(0x00FFFF00);
      expect((a & b).toBigInt(), equals(BigInt.from(0x00FF0000)));
    });

    test('operator | - bitwise OR unsigned 32-bit', () {
      final a = Golang.Uint32(0xFF000000);
      final b = Golang.Uint32(0x00FF0000);
      expect((a | b).toBigInt(), equals(BigInt.from(0xFFFF0000)));
    });

    test('operator ^ - bitwise XOR unsigned 32-bit', () {
      final a = Golang.Uint32(0xFFFFFFFF);
      final b = Golang.Uint32(0x0000FFFF);
      expect((a ^ b).toBigInt(), equals(BigInt.from(0xFFFF0000)));
    });

    test('operator ~ - complemento bit a bit unsigned 32-bit', () {
      final a = Golang.Uint32(0);
      expect((~a).toBigInt(), equals(BigInt.parse('4294967295')));
    });

    test('andNot() - operacao bitwise clear Go unsigned 32-bit', () {
      final a = Golang.Uint32(0xFFFFFFFF);
      final b = Golang.Uint32(0x0000FFFF);
      expect(a.andNot(b).toBigInt(), equals(BigInt.from(0xFFFF0000)));
    });

    test('operator << - shift left logico unsigned 32-bit', () {
      final a = Golang.Uint32(1);
      expect((a << 31).toBigInt(), equals(BigInt.from(2147483648)));
      expect((a << 32).toBigInt(), equals(BigInt.zero));
      expect(() => a << -1, throwsA(isA<ArgumentError>()));
    });

    test('operator >> - shift right logico unsigned 32-bit', () {
      final a = Golang.Uint32.fromBigInt(BigInt.from(2147483648));
      expect((a >> 31).toBigInt(), equals(BigInt.one));
      expect((a >> 32).toBigInt(), equals(BigInt.zero));
      expect(() => a >> -1, throwsA(isA<ArgumentError>()));
    });

    test('compareTo() - comparacao ordinal unsigned 32-bit', () {
      expect(Golang.Uint32(1000).compareTo(Golang.Uint32(2000)), lessThan(0));
      expect(Golang.Uint32(2000).compareTo(Golang.Uint32(2000)), equals(0));
      expect(Golang.Uint32(2000).compareTo(Golang.Uint32(1000)), greaterThan(0));
    });

    test('operator < - menor que unsigned 32-bit', () {
      expect(Golang.Uint32(1000) < Golang.Uint32(2000), isTrue);
      expect(Golang.Uint32(2000) < Golang.Uint32(1000), isFalse);
    });

    test('operator <= - menor ou igual unsigned 32-bit', () {
      expect(Golang.Uint32(2000) <= Golang.Uint32(2000), isTrue);
      expect(Golang.Uint32(1000) <= Golang.Uint32(2000), isTrue);
      expect(Golang.Uint32(2000) <= Golang.Uint32(1000), isFalse);
    });

    test('operator > - maior que unsigned 32-bit', () {
      expect(Golang.Uint32(3000) > Golang.Uint32(2000), isTrue);
      expect(Golang.Uint32(2000) > Golang.Uint32(3000), isFalse);
    });

    test('operator >= - maior ou igual unsigned 32-bit', () {
      expect(Golang.Uint32(3000) >= Golang.Uint32(3000), isTrue);
      expect(Golang.Uint32(3000) >= Golang.Uint32(2000), isTrue);
      expect(Golang.Uint32(2000) >= Golang.Uint32(3000), isFalse);
    });

    test('operator == - igualdade de Uint32', () {
      expect(Golang.Uint32(55555) == Golang.Uint32(55555), isTrue);
      expect(Golang.Uint32(55555) == Golang.Uint32(66666), isFalse);
    });

    test('hashCode - hash code de Uint32', () {
      expect(Golang.Uint32(55555).hashCode, equals(BigInt.from(55555).hashCode));
    });

    test('toString() - representacao textual de Uint32', () {
      expect(Golang.Uint32(4294967295).toString(), equals('4294967295'));
    });
  });

  group('Uint64 [Atomic Audit]', () {
    test('toBigInt() - retorna unsigned exato em 64 bits', () {
      final maxU64 = BigInt.parse('18446744073709551615');
      expect(Golang.Uint64.fromBigInt(maxU64).toBigInt(), equals(maxU64));
    });

    test('toLittleEndianBytes() - exporta 8 bytes little-endian', () {
      final bytes = Golang.Uint64(0x0102030405060708).toLittleEndianBytes();
      expect(bytes.length, equals(8));
      expect(bytes[0], equals(0x08));
      expect(bytes[7], equals(0x01));
    });

    test('operator + - adicao modulo 2^64', () {
      final maxVal = BigInt.parse('18446744073709551615');
      final a = Golang.Uint64.fromBigInt(maxVal);
      final b = Golang.Uint64(1);
      expect((a + b).toBigInt(), equals(BigInt.zero));
    });

    test('operator * - multiplicacao modulo 2^64', () {
      final a = Golang.Uint64.fromBigInt(BigInt.parse('4294967296'));
      final b = Golang.Uint64.fromBigInt(BigInt.parse('4294967296'));
      expect((a * b).toBigInt(), equals(BigInt.zero));
    });

    test('operator ~/ - divisao unsigned 64-bit', () {
      final a = Golang.Uint64(1000000);
      final b = Golang.Uint64(700);
      expect((a ~/ b).toBigInt(), equals(BigInt.from(1428)));
    });

    test('operator % - resto unsigned 64-bit', () {
      final a = Golang.Uint64(1000000);
      final b = Golang.Uint64(700);
      expect((a % b).toBigInt(), equals(BigInt.from(400)));
    });

    test('operator & - bitwise AND unsigned 64-bit', () {
      final a = Golang.Uint64(0xFFFFFFFF00000000);
      final b = Golang.Uint64(0x0000FFFFFFFF0000);
      expect((a & b).toBigInt(), equals(BigInt.from(0x0000FFFF00000000)));
    });

    test('operator | - bitwise OR unsigned 64-bit', () {
      final a = Golang.Uint64.fromBigInt(BigInt.parse('18374686479671623680'));
      final b = Golang.Uint64.fromBigInt(BigInt.parse('71776119061217280'));
      expect((a | b).toBigInt(), equals(BigInt.parse('18446462598732840960')));
    });

    test('operator ^ - bitwise XOR unsigned 64-bit', () {
      final a = Golang.Uint64(0x00000000FFFFFFFF);
      final b = Golang.Uint64(0x000000000000FFFF);
      expect((a ^ b).toBigInt(), equals(BigInt.from(0x00000000FFFF0000)));
    });

    test('operator ~ - complemento bit a bit unsigned 64-bit', () {
      final a = Golang.Uint64(0);
      expect((~a).toBigInt(), equals(BigInt.parse('18446744073709551615')));
    });

    test('andNot() - operacao bitwise clear Go unsigned 64-bit', () {
      final a = Golang.Uint64(0xFFFFFFFF);
      final b = Golang.Uint64(0x0000FFFF);
      expect(a.andNot(b).toBigInt(), equals(BigInt.from(0xFFFF0000)));
    });

    test('operator << - shift left logico unsigned 64-bit', () {
      final a = Golang.Uint64(1);
      expect((a << 63).toBigInt(), equals(BigInt.parse('9223372036854775808')));
      expect((a << 64).toBigInt(), equals(BigInt.zero));
      expect(() => a << -1, throwsA(isA<ArgumentError>()));
    });

    test('operator >> - shift right logico unsigned 64-bit', () {
      final a = Golang.Uint64.fromBigInt(BigInt.parse('9223372036854775808'));
      expect((a >> 63).toBigInt(), equals(BigInt.one));
      expect((a >> 64).toBigInt(), equals(BigInt.zero));
      expect(() => a >> -1, throwsA(isA<ArgumentError>()));
    });

    test('compareTo() - comparacao ordinal unsigned 64-bit', () {
      expect(Golang.Uint64(10000).compareTo(Golang.Uint64(20000)), lessThan(0));
      expect(Golang.Uint64(20000).compareTo(Golang.Uint64(20000)), equals(0));
      expect(Golang.Uint64(20000).compareTo(Golang.Uint64(10000)), greaterThan(0));
    });

    test('operator < - menor que unsigned 64-bit', () {
      expect(Golang.Uint64(10000) < Golang.Uint64(20000), isTrue);
      expect(Golang.Uint64(20000) < Golang.Uint64(10000), isFalse);
    });

    test('operator <= - menor ou igual unsigned 64-bit', () {
      expect(Golang.Uint64(20000) <= Golang.Uint64(20000), isTrue);
      expect(Golang.Uint64(10000) <= Golang.Uint64(20000), isTrue);
      expect(Golang.Uint64(20000) <= Golang.Uint64(10000), isFalse);
    });

    test('operator > - maior que unsigned 64-bit', () {
      expect(Golang.Uint64(30000) > Golang.Uint64(20000), isTrue);
      expect(Golang.Uint64(20000) > Golang.Uint64(30000), isFalse);
    });

    test('operator >= - maior ou igual unsigned 64-bit', () {
      expect(Golang.Uint64(30000) >= Golang.Uint64(30000), isTrue);
      expect(Golang.Uint64(30000) >= Golang.Uint64(20000), isTrue);
      expect(Golang.Uint64(20000) >= Golang.Uint64(30000), isFalse);
    });

    test('operator == - igualdade de Uint64', () {
      expect(Golang.Uint64(999999999) == Golang.Uint64(999999999), isTrue);
      expect(Golang.Uint64(999999999) == Golang.Uint64(888888888), isFalse);
    });

    test('hashCode - hash code de Uint64', () {
      expect(Golang.Uint64(999999999).hashCode, equals(BigInt.from(999999999).hashCode));
    });

    test('toString() - representacao textual de Uint64', () {
      final maxStr = '18446744073709551615';
      expect(Golang.Uint64.fromBigInt(BigInt.parse(maxStr)).toString(), equals(maxStr));
    });
  });

  group('FdMutex [Atomic Audit]', () {
    test('close() - fecha e so tem efeito na primeira vez', () {
      final mu = FdMutex();
      expect(mu.close(), isTrue);
      expect(mu.close(), isFalse);
    });

    test('rwlock() - adquire trava e recusa quando fechado', () async {
      final mu = FdMutex();
      expect(await mu.rwlock(true), isTrue);
      expect(await mu.rwlock(false), isTrue);
      mu.close();
      expect(await mu.rwlock(true), isFalse);
    });

    test('rwunlock() - libera a trava e desperta um esperador', () async {
      final mu = FdMutex();
      await mu.rwlock(false);
      var despertou = false;
      // ignore: unawaited_futures
      mu.rwlock(false).then((_) => despertou = true);
      await Future<void>.delayed(Duration.zero);
      expect(despertou, isFalse);
      mu.rwunlock(false);
      await Future<void>.delayed(Duration.zero);
      expect(despertou, isTrue);
    });

    test('isClosed - reflete o fechamento do descritor', () {
      final mu = FdMutex();
      expect(mu.isClosed, isFalse);
      mu.close();
      expect(mu.isClosed, isTrue);
    });

    test('readWaiters - conta esperas pendentes pela trava de leitura',
        () async {
      final mu = FdMutex();
      await mu.rwlock(true);
      expect(mu.readWaiters, 0);
      // ignore: unawaited_futures
      mu.rwlock(true).then((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(mu.readWaiters, 1);
    });

    test('writeWaiters - conta esperas pendentes pela trava de escrita',
        () async {
      final mu = FdMutex();
      await mu.rwlock(false);
      expect(mu.writeWaiters, 0);
      // ignore: unawaited_futures
      mu.rwlock(false).then((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(mu.writeWaiters, 1);
    });
  });

  group('NetClosingException [Atomic Audit]', () {
    test('toString() - preserva o texto exigido pelo upstream', () {
      expect(
        const NetClosingException().toString(),
        'use of closed network connection',
      );
    });
  });

  group('FileClosingException [Atomic Audit]', () {
    test('toString() - preserva o texto do upstream', () {
      expect(const FileClosingException().toString(), 'use of closed file');
    });
  });

  group('DeadlineExceededException [Atomic Audit]', () {
    test('toString() - preserva o texto do upstream', () {
      expect(const DeadlineExceededException().toString(), 'i/o timeout');
    });
  });

  group('Top-Level Functions [Atomic Audit]', () {
    test('errClosing() - escolhe o sentinela conforme arquivo ou rede', () {
      expect(errClosing(isFile: false), isA<NetClosingException>());
      expect(errClosing(isFile: true), isA<FileClosingException>());
    });

    test('integerToFloat() - arredonda BigInt para precisao float com desempate par', () {
      // Valor pequeno que cabe na precisao
      expect(integerToFloat(BigInt.from(100), 24), equals(100.0));
      expect(integerToFloat(BigInt.from(-100), 24), equals(-100.0));

      // Valor com mais de 24 bits
      final bigVal = (BigInt.one << 30) + (BigInt.one << 29);
      final rounded = integerToFloat(bigVal, 24);
      expect(rounded, equals(bigVal.toDouble()));
    });
  });
}
