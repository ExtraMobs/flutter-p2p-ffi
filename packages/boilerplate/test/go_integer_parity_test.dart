// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: library_prefixes
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';

void main() {
  test(
    'integer and byte-string results match the installed Go toolchain',
    () async {
      final result = await Process.run('go', [
        'run',
        'test/go_integer_vectors.go',
      ]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      final u = Golang.Uint64.fromBigInt((BigInt.one << 64) - BigInt.one);
      final min = Golang.Int64.fromBigInt(-(BigInt.one << 63));
      final max = Golang.Int64.fromBigInt((BigInt.one << 63) - BigInt.one);
      final neg = Golang.Int64(-5), divisor = Golang.Int64(-1);
      final s = Golang.String.fromBytes(Uint8List.fromList([255, 0, 195, 169]));
      String hex(Uint8List bytes) =>
          bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final actual = [
        u,
        u + Golang.Uint64(1),
        u * Golang.Uint64(2),
        u >> 63,
        u << 64,
        u.andNot(Golang.Uint64(15)),
        max + Golang.Int64(1),
        min - Golang.Int64(1),
        min ~/ divisor,
        min % divisor,
        neg ~/ Golang.Int64(2),
        neg % Golang.Int64(2),
        neg >> 64,
        divisor.toUint64(),
        s.length,
        s[0],
        hex(s.slice(2, 3).toBytes()),
        hex((s + Golang.String.fromDart('a')).toBytes()),
        Golang.String.fromDart('\uE000') < Golang.String.fromDart('\u{10000}'),
      ].map((value) => value.toString()).toList();
      for (final code in [
        -1,
        0,
        127,
        128,
        0xd7ff,
        0xd800,
        0xdfff,
        0xe000,
        0x1f30d,
        0x10ffff,
        0x110000,
      ]) {
        actual.add(
          hex(Golang.String.fromCodePoint(BigInt.from(code)).toBytes()),
        );
      }
      actual.add(hex(Golang.String.fromCodePoint(u.toBigInt()).toBytes()));
      final wideRune = BigInt.parse('4294967361');
      actual.add(
        hex(Golang.String.fromRune(Golang.Rune.fromBigInt(wideRune)).toBytes()),
      );
      actual.add(hex(Golang.String.fromCodePoint(wideRune).toBytes()));
      for (final a in [false, true]) {
        for (final b in [false, true]) {
          var calls = 0;
          Golang.Bool rhs() {
            calls++;
            return Golang.Bool(b);
          }

          final left = Golang.Bool(a);
          actual.add(left.and(rhs).toString());
          actual.add('$calls');
          calls = 0;
          actual.add(left.or(rhs).toString());
          actual.add('$calls');
          actual.add(left.not().toString());
        }
      }
      final conversion = Golang.Uint16(0x10f0);
      final narrowed = Golang.Int8.fromBigInt(conversion.toBigInt());
      actual.add(Golang.Uint32.fromBigInt(narrowed.toBigInt()).toString());
      for (final n in [-32768, -129, -128, -1, 0, 127, 128, 255, 32767]) {
        final v = Golang.Int16(n).toBigInt();
        actual.add(Golang.Int8.fromBigInt(v).toString());
        actual.add(Golang.Uint8.fromBigInt(v).toString());
        actual.add(Golang.Uint64.fromBigInt(v).toString());
      }
      expect(actual, jsonDecode(result.stdout as String));
    },
  );
}
