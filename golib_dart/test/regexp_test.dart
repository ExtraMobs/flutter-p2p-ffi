// ignore_for_file: library_prefixes
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:golib_dart/builtin.dart';
import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:golib_dart/regexp.dart' as regexp;
import 'package:test/test.dart';

Uint8List unhex(String h) => Uint8List.fromList([
  for (var i = 0; i < h.length; i += 2)
    int.parse(h.substring(i, i + 2), radix: 16),
]);

Golang.String gs(String h) => Golang.String.fromBytes(unhex(h));

String hx(Golang.String s) =>
    [for (final b in s.toBytes()) b.toRadixString(16).padLeft(2, '0')].join();

Slice<Golang.Uint8> bytesOf(Golang.String s) => Slice.of([
  for (final b in s.toBytes()) Golang.Uint8(b),
], const Elem<Golang.Uint8>(1, Golang.Uint8.new, ofInt: Golang.Uint8.from));

String hxb(Slice<Golang.Uint8> b) => b.isNil
    ? 'nil'
    : [for (final x in b.items) x.toInt().toRadixString(16).padLeft(2, '0')]
          .join();

String hxs(Slice<Golang.String> a) =>
    a.isNil ? 'nil' : '[${[for (final s in a.items) hx(s)].join(',')}]';

String hxss(Slice<Slice<Golang.String>> a) =>
    a.isNil ? 'nil' : '[${[for (final s in a.items) hxs(s)].join(',')}]';

String hxbs(Slice<Slice<Golang.Uint8>> a) =>
    a.isNil ? 'nil' : '[${[for (final s in a.items) hxb(s)].join(',')}]';

String ints(Slice<Golang.Int> a) =>
    a.isNil ? 'nil' : '[${[for (final x in a.items) x.toInt()].join(' ')}]';

String intss(Slice<Slice<Golang.Int>> a) =>
    a.isNil ? 'nil' : '[${[for (final s in a.items) ints(s)].join(' ')}]';

List<String> run(Golang.String pat, Golang.String inp) {
  final (re0, err) = regexp.compile(pat);
  if (err != null) {
    String msg;
    try {
      regexp.mustCompile(pat);
      msg = 'NO PANIC';
    } on Panic catch (p) {
      msg = hx(p.value as Golang.String);
    }
    return ['ERR ${hx(err.error())} | $msg'];
  }
  final re = re0!;
  final b = bytesOf(inp);
  final tpl = Golang.String.fromDart('<\$0|\${1}|\$x|\$\$|\$1x|\${first}|\$>');
  final n3 = Golang.Int(3), nAll = Golang.Int(-1), n2 = Golang.Int(2);
  final names = re.subexpNames();
  final sm = re.findStringSubmatchIndex(inp);
  return [
    'ns=${re.numSubexp()} names=${hxs(names)} str=${hx(re.string())}',
    '${re.matchString(inp)} ${re.match(b)}',
    '${ints(re.findStringIndex(inp))} ${ints(re.findIndex(b))}',
    '${ints(sm)} ${ints(re.findSubmatchIndex(b))}',
    intss(re.findAllStringSubmatchIndex(inp, nAll)),
    '${intss(re.findAllStringIndex(inp, n3))} ${intss(re.findAllIndex(b, nAll))}',
    '${hx(re.findString(inp))} ${hxb(re.find(b))}',
    '${hxs(re.findStringSubmatch(inp))} ${hxbs(re.findSubmatch(b))}',
    '${hxs(re.findAllString(inp, nAll))} ${hxss(re.findAllStringSubmatch(inp, n2))}',
    '${hx(re.replaceAllString(inp, tpl))} ${hxb(re.replaceAll(b, bytesOf(tpl)))}',
    '${hx(re.replaceAllLiteralString(inp, Golang.String.fromDart(r'$1')))} '
        '${hxb(re.replaceAllLiteral(b, bytesOf(Golang.String.fromDart(r'$1'))))}',
    hx(
      re.replaceAllStringFunc(
        inp,
        (m) => Golang.String.fromDart('[') + m + Golang.String.fromDart(']'),
      ),
    ),
    '${hxs(re.split(inp, nAll))} ${hxs(re.split(inp, n2))} ${hxs(re.split(inp, Golang.Int(0)))}',
    hxb(re.expandString(bytesOf(Golang.String.fromDart('pre:')), tpl, inp, sm)),
    '${re.subexpIndex(Golang.String.fromDart('first'))} '
        '${re.subexpIndex(Golang.String.fromDart('x'))} '
        '${re.subexpIndex(Golang.String())}',
  ];
}

void main() {
  test('regexp igual ao Go: sintaxe, erros, casamentos, índices em bytes e '
      'substituição', () async {
    final r = await Process.run('go', [
      'run',
      'test/go_regexp_vectors.go',
    ], stdoutEncoding: utf8);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final go = jsonDecode(r.stdout as String) as Map<String, dynamic>;
    final pats = [for (final h in go['pats'] as List) gs(h as String)];
    final inputs = [for (final h in go['inputs'] as List) gs(h as String)];
    final want = <String, String>{};
    for (final l in go['res'] as List) {
      final s = l as String;
      final sp = s.indexOf(' ');
      want[s.substring(0, sp)] = s.substring(sp + 1);
    }
    final got = <String, String>{};
    for (var pi = 0; pi < pats.length; pi++) {
      for (var ii = 0; ii < inputs.length; ii++) {
        if (want['$pi/$ii/0'] == null) continue;
        final lines = run(pats[pi], inputs[ii]);
        for (var k = 0; k < lines.length; k++) {
          got['$pi/$ii/$k'] = lines[k];
        }
      }
    }
    final bad = <String>[];
    want.forEach((k, v) {
      if (got[k] != v) {
        final pi = int.parse(k.split('/')[0]), ii = int.parse(k.split('/')[1]);
        bad.add(
          'pat=${jsonEncode(pats[pi].toString())} in=${jsonEncode(inputs[ii].toString())} op=${k.split('/')[2]}\n  go : $v\n  dart: ${got[k]}',
        );
      }
    });
    expect(got.length, want.length);
    expect(
      bad.length,
      0,
      reason: '${bad.length} divergências:\n${bad.take(25).join('\n')}',
    );
    // Funções do pacote.
    final pkg = [
      for (final h in [
        '',
        '612e62',
        '5c2e2b2a3f28297c5b5d7b7d5e24',
        'e697a5e69cac',
        '61ff62',
        '2d5f2061',
      ])
        hx(regexp.quoteMeta(gs(h))),
    ];
    final (ok1, e1) = regexp.matchString(
      Golang.String.fromDart('^a+b\$'),
      Golang.String.fromDart('aaab'),
    );
    final (ok2, e2) = regexp.match(
      Golang.String.fromDart('('),
      bytesOf(Golang.String.fromDart('x')),
    );
    pkg
      ..add('$ok1 ${e1 == null ? '<nil>' : e1.error()}')
      ..add('$ok2 ${hx(e2!.error())}');
    expect(pkg, go['pkg']);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
