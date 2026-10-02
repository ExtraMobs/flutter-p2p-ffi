// ignore_for_file: library_prefixes
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:golib_dart/builtin.dart';
import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:golib_dart/strconv.dart' as strconv;
import 'package:test/test.dart';

String _err(GoError? e) => e == null ? '<nil>' : '${e.error()}';

Golang.String _unhex(String h) => Golang.String.fromBytes(
  Uint8List.fromList([
    for (var i = 0; i < h.length; i += 2)
      int.parse(h.substring(i, i + 2), radix: 16),
  ]),
);

String _hex(Iterable<int> b) =>
    [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();

const _elem = Elem<Golang.Uint8>(1, Golang.Uint8.new, ofInt: Golang.Uint8.from);

Slice<Golang.Uint8> _dst(String s) =>
    Slice.of([for (final c in s.codeUnits) Golang.Uint8(c)], _elem);

String _sl(Slice<Golang.Uint8> s) => _hex(s.items.map((b) => b.toInt()));

String _fbits(double f) {
  if (f.isNaN) return 'NaN';
  final b = ByteData(8)..setFloat64(0, f);
  return b.getUint32(0).toRadixString(16).padLeft(8, '0') +
      b.getUint32(4).toRadixString(16).padLeft(8, '0');
}

double _frombits(String h) {
  final b = ByteData(8)
    ..setUint32(0, int.parse(h.substring(0, 8), radix: 16))
    ..setUint32(4, int.parse(h.substring(8), radix: 16));
  return b.getFloat64(0);
}

void main() {
  test('strconv (bool, quote, unquote, append, float) igual ao Go', () async {
    final r = await Process.run('go', [
      'run',
      'test/go_strconv_misc_vectors.go',
    ], stdoutEncoding: utf8);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final go = jsonDecode(r.stdout as String) as Map<String, dynamic>;
    final strs = [for (final h in go['strs'] as List) _unhex(h as String)];
    final fl = [for (final h in go['fl'] as List) _unhex(h as String)];
    final runes = (go['runes'] as List).cast<int>();
    final floats = [
      for (final h in go['floats'] as List) _frombits(h as String),
    ];
    final out = <String>[];
    String q(Golang.String s) => _hex(s.toBytes());
    for (final s in strs) {
      final (b, be) = strconv.parseBool(s);
      out.add('pb $b ${_err(be)}');
      out.add(
        'q ${strconv.quote(s)}|${strconv.quoteToASCII(s)}|'
        '${strconv.canBackquote(s)}',
      );
      final (u, ue) = strconv.unquote(s);
      out.add('uq ${q(u)} ${_err(ue)}');
      for (final qc in [0, 0x27, 0x22]) {
        final (v, mb, tail, err) = strconv.unquoteChar(s, Golang.Uint8(qc));
        out.add('uc $qc $v $mb ${q(tail)} ${_err(err)}');
      }
      out.add(
        'ab ${_sl(strconv.appendBool(_dst('x'), s.length % 2 == 0))}'
        ' ${_sl(strconv.appendQuote(_dst('<'), s))}'
        ' ${_sl(strconv.appendQuoteToASCII(Slice.nil(_elem), s))}',
      );
    }
    for (final r in runes) {
      final gr = Golang.Rune(r);
      out.add(
        'r $r ${strconv.quoteRune(gr)} ${strconv.quoteRuneToASCII(gr)} '
        '${strconv.isPrint(gr)} '
        '${utf8.decode(strconv.appendQuoteRune(_dst('['), gr).items.map((b) => b.toInt()).toList())} '
        '${utf8.decode(strconv.appendQuoteRuneToASCII(Slice.nil(_elem), gr).items.map((b) => b.toInt()).toList())}',
      );
    }
    String txt(Slice<Golang.Uint8> s) =>
        String.fromCharCodes(s.items.map((b) => b.toInt()));
    for (final v in [
      BigInt.zero,
      BigInt.one,
      -BigInt.one,
      BigInt.from(35),
      BigInt.from(-36),
      BigInt.from(255),
      BigInt.parse('9223372036854775807'),
      -BigInt.parse('9223372036854775808'),
    ]) {
      final i = Golang.Int64.fromBigInt(v);
      for (final b in [2, 8, 10, 16, 36]) {
        out.add(
          '${txt(strconv.appendInt(_dst('i:'), i, Golang.Int(b)))} '
          '${txt(strconv.appendUint(_dst('u:'), Golang.Uint64.from(i), Golang.Int(b)))}',
        );
      }
    }
    for (final f in floats) {
      for (final fm in 'eEfFgGz'.codeUnits) {
        for (final prec in [-1, 0, 1, 3, 6, 17, 30]) {
          for (final bits in [32, 64]) {
            final a = strconv.formatFloat(
              Golang.Float64(f),
              Golang.Uint8(fm),
              Golang.Int(prec),
              Golang.Int(bits),
            );
            final b = txt(
              strconv.appendFloat(
                _dst('<'),
                Golang.Float64(f),
                Golang.Uint8(fm),
                Golang.Int(prec),
                Golang.Int(bits),
              ),
            );
            out.add('$a $b');
          }
        }
      }
    }
    for (final s in fl) {
      for (final bits in [32, 64, 0]) {
        final (f, err) = strconv.parseFloat(s, Golang.Int(bits));
        out.add('pf ${_fbits(f.toDouble())} ${_err(err)}');
      }
    }
    final want = (go['out'] as List).cast<String>();
    expect(out.length, want.length);
    for (var k = 0; k < out.length; k++) {
      expect(out[k], want[k], reason: 'linha $k');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
