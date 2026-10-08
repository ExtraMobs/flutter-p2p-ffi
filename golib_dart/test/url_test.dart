// ignore_for_file: library_prefixes
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:golib_dart/builtin.dart';
import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:golib_dart/fmt.dart' as fmt;
import 'package:golib_dart/net/url.dart' as url;
import 'package:test/test.dart';

Golang.String _unhex(String h) => Golang.String.fromBytes(
  Uint8List.fromList([
    for (var i = 0; i < h.length; i += 2)
      int.parse(h.substring(i, i + 2), radix: 16),
  ]),
);

String _hex(Golang.String s) =>
    [for (final x in s.toBytes()) x.toRadixString(16).padLeft(2, '0')].join();

Golang.String _gs(String s) => Golang.String.fromDart(s);

const _any = Elem<Object?>(16, zeroNull, pointers: true);
const _strElem = Elem<Golang.String>(16, Golang.String.new, pointers: true);

String _t(Object? v) => fmt.sprintf(_gs('%T'), Slice.of([v], _any)).toString();

String _errText(GoError? err) {
  if (err == null) return '<nil>';
  var s = '${err.error()}|${_t(err)}';
  if (err is url.Error) {
    s +=
        '|${err.op}|${err.url}|${_t(err.unwrap())}|${err.timeout()}|${err.temporary()}';
  }
  return s;
}

List<String> _urlFields(url.URL u) {
  var (user, name, pass) = ('nil', '', '');
  final ui = u.user;
  if (ui != null) {
    final (p, set) = ui.password();
    (user, name, pass) = ('$set', ui.username().toString(), p.toString());
  }
  return [
    '${u.scheme}',
    '${u.opaque}',
    user,
    name,
    pass,
    '${u.host}',
    '${u.path}',
    '${u.fragment}',
    '${u.rawQuery}',
    '${u.rawPath}',
    '${u.rawFragment}',
    '${u.forceQuery}',
    '${u.omitHost}',
  ];
}

// Os campos vêm em hex e voltam como Golang.String sem perder bytes.
url.URL _fromFields(List<Golang.String> f) {
  final set = f[2].toString();
  return url.URL(
    scheme: f[0],
    opaque: f[1],
    user: set == 'nil'
        ? null
        : set == 'true'
        ? url.userPassword(f[3], f[4])
        : url.user(f[3]),
    host: f[5],
    path: f[6],
    fragment: f[7],
    rawQuery: f[8],
    rawPath: f[9],
    rawFragment: f[10],
    forceQuery: f[11].toString() == 'true',
    omitHost: f[12].toString() == 'true',
  );
}

List<Golang.String> _dumpURL(url.URL u) {
  final (bin, _) = u.marshalBinary();
  final f = [for (final s in _urlFields(u)) _gs(s)];
  // Os campos de string vão como bytes (podem não ser UTF-8).
  f[0] = u.scheme;
  f[1] = u.opaque;
  if (u.user != null) {
    f[3] = u.user!.username();
    f[4] = u.user!.password().$1;
  }
  f[5] = u.host;
  f[6] = u.path;
  f[7] = u.fragment;
  f[8] = u.rawQuery;
  f[9] = u.rawPath;
  f[10] = u.rawFragment;
  return [
    ...f,
    u.user == null ? _gs('nil') : u.user!.string(),
    u.string(),
    u.escapedPath(),
    u.escapedFragment(),
    u.hostname(),
    u.port(),
    u.requestURI(),
    u.redacted(),
    _gs('${u.isAbs()}'),
    u.query().encode(),
    fmt.sprint(Slice.of([u], _any)),
    Golang.String.fromBytes(
      Uint8List.fromList([for (final b in bin.items) b.toInt()]),
    ),
  ];
}

List<Golang.String> _dumpParse((url.URL?, GoError?) r) {
  final (u, err) = r;
  if (err != null) return [_gs('E'), _gs(_errText(err))];
  return _dumpURL(u!);
}

List<Golang.String> _dumpValues(url.Values v, GoError? err) {
  final keys = v.keysSnapshot()..sort((a, b) => a.compareTo(b));
  final out = [v.encode(), _gs(_errText(err))];
  for (final k in keys) {
    out
      ..add(k)
      ..add(_gs('${v[k].length}'))
      ..addAll(v[k].items)
      ..add(v.get(k))
      ..add(_gs('${v.has(k)}'));
  }
  return out;
}

void main() {
  test('net/url igual ao Go (tabelas do url_test.go)', () async {
    final r = await Process.run(
      'go',
      ['run', 'test/go_url_vectors.go'],
      environment: {...Platform.environment, 'GOTOOLCHAIN': 'go1.26.5'},
      stdoutEncoding: utf8,
    );
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final ops = jsonDecode(r.stdout as String) as List;
    expect(ops.length, greaterThan(3000));
    var failures = 0;
    for (final o in ops) {
      final op = o['op'] as String;
      final a = [for (final h in o['in'] as List? ?? []) _unhex(h as String)];
      final List<Golang.String> got;
      switch (op) {
        case 'Parse':
          got = _dumpParse(url.parse(a[0]));
        case 'ParseRequestURI':
          got = _dumpParse(url.parseRequestURI(a[0]));
        case 'QueryUnescape':
          final (s, e) = url.queryUnescape(a[0]);
          got = [s, _gs(_errText(e))];
        case 'PathUnescape':
          final (s, e) = url.pathUnescape(a[0]);
          got = [s, _gs(_errText(e))];
        case 'QueryEscape':
          got = [url.queryEscape(a[0])];
        case 'PathEscape':
          got = [url.pathEscape(a[0])];
        case 'ParseQuery':
          final (v, e) = url.parseQuery(a[0]);
          got = _dumpValues(v, e);
        case 'HostPort':
          final h = url.URL(host: a[0]);
          got = [h.hostname(), h.port()];
        case 'Resolve':
          final base = url.parse(a[0]).$1!, ref = url.parse(a[1]).$1!;
          got = [
            ..._dumpURL(base.resolveReference(ref)),
            ..._dumpParse(base.parse(a[1])),
          ];
        case 'JoinPath':
          final elem = Slice.of(a.sublist(1), _strElem);
          final (s, e) = url.joinPath(a[0], elem);
          got = [s, _gs(_errText(e))];
          final (u, err) = url.parse(a[0]);
          if (err == null) got.addAll(_dumpURL(u!.joinPath(elem)));
        case 'URL':
          final f = [for (final h in o['url'] as List) _unhex(h as String)];
          got = _dumpURL(_fromFields(f));
        case 'Values':
          final v = url.Values(GoMap(const Elem(24, _nilStrings)));
          for (var i = 0; i < a.length; i += 2) {
            v.add(a[i], a[i + 1]);
          }
          got = _dumpValues(v, null);
        default:
          throw StateError(op);
      }
      final want = [for (final h in o['out'] as List) h as String];
      final gotHex = [for (final s in got) _hex(s)];
      if (gotHex.join(',') != want.join(',')) {
        if (failures++ < 15) {
          printOnFailure(
            '$op ${a.map((s) => '"$s"').join(' ')}\n'
            '  got  ${[for (final s in got) '$s']}\n'
            '  want ${[for (final h in want) '${_unhex(h)}']}',
          );
        }
      }
    }
    expect(failures, 0);
  });

  test('url.Error: Timeout/Temporary do erro embrulhado; nil deref', () {
    final e = url.Error(op: _gs('Get'), url: _gs('u'), err: _Timeout());
    expect(e.timeout(), isTrue);
    expect(e.temporary(), isFalse);
    expect(e.error().toString(), 'Get "u": t');
    expect(() => url.URL.$nil.string(), throwsA(isA<Panic>()));
    expect(url.URL.$nil.redacted().toString(), '');
    expect(url.Userinfo.$nil.username().toString(), '');
  });
}

Slice<Golang.String> _nilStrings() => Slice.nil(_strElem);

final class _Timeout implements GoError, Timeouter, Golang.GoTyped {
  @override
  String get $goType => '*main.timeoutError';
  @override
  List<String> get $methods => const ['Error', 'Timeout'];
  @override
  Golang.String error() => _gs('t');
  @override
  bool timeout() => true;
}
