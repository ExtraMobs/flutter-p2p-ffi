// Shim `time` contra o oráculo Go (`test/go_time_vectors.go`, embutido em
// `time_vectors.dart` para rodar também no JS/Wasm, sem `dart:io`;
// `time_oracle_test.dart` confere na VM que o embutido é a saída atual do Go).
// ignore_for_file: library_prefixes
import 'dart:convert';
import 'dart:typed_data';

import 'package:golib_dart/builtin.dart';
import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:golib_dart/time.dart' as time;
import 'package:test/test.dart';

import 'time_vectors.dart';

List<String> _describe(time.Time t) {
  final (y, m, d) = t.date();
  final (h, mi, s) = t.clock();
  final (iy, iw) = t.isoWeek();
  final (zn, zo) = t.zone();
  return [
    '${t.string()}',
    '${t.unix()} ${t.unixNano()} ${t.unixMilli()} ${t.unixMicro()}',
    '$y ${m.toInt()} $d ${m.string()} ${t.year()} ${t.month().toInt()} '
        '${t.day()}',
    '$h $mi $s ${t.hour()} ${t.minute()} ${t.second()} ${t.nanosecond()}',
    '${t.weekday().string()} ${t.yearDay()} $iy $iw',
    '$zn $zo ${t.location().string()} ${t.isZero()}',
  ];
}

Golang.Int64 _i64(Object? s) => Golang.Int64.fromBigInt(BigInt.parse('$s'));

time.Duration _dur(Object? s) => time.Duration.fromBigInt(BigInt.parse('$s'));

Golang.String _gs(String s) => Golang.String.fromDart(s);

String _hex(Iterable<int> b) =>
    [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();

Golang.String _unhex(String h) => Golang.String.fromBytes(
  Uint8List.fromList([
    for (var i = 0; i < h.length; i += 2)
      int.parse(h.substring(i, i + 2), radix: 16),
  ]),
);

/// Compara linha a linha, falhando na primeira diferença (a lista inteira
/// no `expect` seria ilegível).
void _check(String what, List<String> got, List<Object?> want) {
  for (var i = 0; i < got.length && i < want.length; i++) {
    if (got[i] != want[i]) {
      fail('$what[$i]: Dart "${got[i]}" != Go "${want[i]}"');
    }
  }
  expect(got.length, want.length, reason: '$what: número de linhas');
}

void main() {
  final go = jsonDecode(timeVectorsJson) as Map<String, dynamic>;
  final fz = time.fixedZone(_gs('BRT'), Golang.Int(-3 * 3600));

  test('Unix, UTC, In, componentes e String() iguais ao Go', () {
    final out = <String>[];
    for (final s in go['secs'] as List) {
      for (final n in go['nsecs'] as List) {
        final t = time.unix(_i64(s), _i64(n));
        out
          ..addAll(_describe(t))
          ..addAll(_describe(t.utc()))
          ..addAll(_describe(t.in$(fz)))
          ..add(
            '${t == t.utc()} ${t.utc() == t.utc()} '
            '${t.location() == time.local} ${t.utc().location() == time.utc} '
            '${t.equal(t.in$(fz))}',
          );
      }
    }
    _check('unix', out, go['unix'] as List);
    final milli = <String>[];
    for (final ms in go['milli'] as List) {
      milli
        ..add('${time.unixMilli(_i64(ms)).utc().string()}')
        ..add('${time.unixMicro(_i64(ms)).utc().string()}');
    }
    _check('milli', milli, go['milliOut'] as List);
  });

  test('Date normaliza e aplica a zona como o Go', () {
    final out = <String>[];
    for (final a in go['dates'] as List) {
      final v = [for (final x in a as List) int.parse(x as String)];
      for (final z in go['zones'] as List) {
        final loc = z == null
            ? time.utc
            : time.fixedZone(
                _gs(z['name'] as String),
                Golang.Int(z['offset'] as int),
              );
        final t = time.date(
          Golang.Int(v[0]),
          time.Month(v[1]),
          Golang.Int(v[2]),
          Golang.Int(v[3]),
          Golang.Int(v[4]),
          Golang.Int(v[5]),
          Golang.Int(v[6]),
          loc,
        );
        out.addAll(_describe(t));
      }
    }
    _check('date', out, go['date'] as List);
  });

  test('Add, Sub, comparações, AddDate, Truncate e Round iguais ao Go', () {
    final bases = [
      for (final b in go['bases'] as List)
        () {
          final t = time.unix(_i64(b[0]), _i64(b[1]));
          return switch (b[2]) {
            'Local' => t,
            'UTC' => t.utc(),
            _ => t.in$(
              time.fixedZone(
                _gs(b[3] as String),
                Golang.Int(int.parse(b[4] as String)),
              ),
            ),
          };
        }(),
    ];
    expect(bases.last == time.Time(), isTrue, reason: 'zero reconstruído');
    final durs = [for (final d in go['durs'] as List) _dur(d)];
    final out = <String>[];
    for (final b in bases) {
      for (final d in durs) {
        final a = b.add(d);
        out.addAll([
          '${a.string()}',
          '${b.truncate(d).string()}',
          '${b.round(d).string()}',
        ]);
        final sub = a.sub(b);
        out.add(
          '${sub.nanoseconds()} ${sub.string()} ${b.sub(a).string()} '
          '${a.before(b)} ${a.after(b)} ${a.equal(b)} ${a.compare(b)} '
          '${b.compare(a)} ${a == b}',
        );
      }
      for (final u in bases) {
        out.add(
          '${b.sub(u).nanoseconds()} ${b.before(u)} ${b.after(u)} '
          '${b.equal(u)} ${b.compare(u)} ${b == u}',
        );
      }
      for (final (y, m, d) in const [
        (0, 0, 0),
        (1, 0, 0),
        (0, 1, 0),
        (0, 0, 1),
        (-1, -13, 400),
        (0, 1, 30),
        (1000, 0, -1),
      ]) {
        out.add(
          '${b.addDate(Golang.Int(y), Golang.Int(m), Golang.Int(d)).string()}',
        );
      }
    }
    _check('arith', out, go['arith'] as List);
  });

  test('Month/Weekday String() iguais ao Go', () {
    final out = <String>[];
    for (var i = -1; i <= 14; i++) {
      out
        ..add('${time.Month(i).string()}')
        ..add('${time.Weekday(i).string()}');
    }
    out
      ..add(
        '${time.Month(1099511627777 /* 1<<40 + 1; `<<` de int é 32 bits no JS */).string()}',
      )
      ..add('${time.Weekday(-1099511627776).string()}');
    _check('monthWeekday', out, go['monthWeekday'] as List);
  });

  test('ParseDuration igual ao Go (bytes, erros, estouro)', () {
    final out = <String>[];
    for (final h in go['pdIn'] as List) {
      final (d, err) = time.parseDuration(_unhex(h as String));
      final e = err == null ? utf8.encode('<nil>') : err.error().toBytes();
      out.add('${d.nanoseconds()} ${d.string()} ${_hex(e)}');
    }
    _check('pd', out, go['pdOut'] as List);
  });

  test('Now/Since/Until: leitura monotônica com a forma do Go', () {
    final n = time.now();
    expect(n.string().toString(), contains(' m=+'));
    expect(n.location() == time.local, isTrue);
    expect(time.since(n) >= time.Duration(), isTrue);
    expect(time.until(n) <= time.Duration(), isTrue);
    // Round(0)/UTC() removem a leitura monotônica, como no Go.
    expect(
      n.round(time.Duration()).string().toString(),
      isNot(contains(' m=')),
    );
    expect(n.utc().string().toString(), isNot(contains(' m=')));
    final later = n.add(time.Duration(1500));
    expect(later.sub(n).nanoseconds().toInt(), 1500);
    expect(later.after(n) && n.before(later), isTrue);
    expect(later.string().toString(), contains(' m=+'));
    expect(
      () => n.in$(null),
      throwsA(isA<Panic>()),
      reason: 'In(nil) entra em pânico',
    );
  });
}
