// ignore_for_file: library_prefixes
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:golib_dart/builtin.dart' hide Addr;
import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:golib_dart/net.dart' as net;
import 'package:golib_dart/net/netip.dart' as netip;
import 'package:golib_dart/os.dart' as os;
import 'package:test/test.dart';

Golang.String gs(String s) => Golang.String.fromDart(s);

Golang.Int gi(int n) => Golang.Int(n);

String hx(Slice<Golang.Uint8> b) => b.isNil
    ? 'nil'
    : [for (final x in b.items) x.toInt().toRadixString(16).padLeft(2, '0')]
          .join();

String txt(Slice<Golang.Uint8> b) => Golang.String.fromBytes(
  Uint8List.fromList([for (final x in b.items) x.toInt()]),
).toString();

String es(GoError? e) => e == null ? '<nil>' : e.error().toString();

String bit(bool b) => b ? '1' : '0';

String ipFlags(net.IP ip) => [
  ip.isUnspecified(),
  ip.isLoopback(),
  ip.isPrivate(),
  ip.isMulticast(),
  ip.isInterfaceLocalMulticast(),
  ip.isLinkLocalMulticast(),
  ip.isLinkLocalUnicast(),
  ip.isGlobalUnicast(),
].map(bit).join();

String addrFlags(netip.Addr a) => [
  a.isValid(),
  a.is4(),
  a.is6(),
  a.is4In6(),
  a.isUnspecified(),
  a.isLoopback(),
  a.isPrivate(),
  a.isMulticast(),
  a.isInterfaceLocalMulticast(),
  a.isLinkLocalMulticast(),
  a.isLinkLocalUnicast(),
  a.isGlobalUnicast(),
].map(bit).join();

List<String> run(Golang.String s, netip.Addr prev) {
  final out = <String>[];
  void add(String k, List<Object> parts) => out.add(
    '$k ${parts.map((p) => p is Golang.String ? p.toString() : '$p').join('|')}',
  );

  final ip = net.parseIP(s);
  final (mt, merr) = ip.marshalText();
  add('ip', [
    hx(ip),
    ip.string(),
    hx(ip.to4()),
    hx(ip.to16()),
    ipFlags(ip),
    ip.defaultMask().string(),
    txt(mt),
    es(merr),
  ]);
  if (!ip.isNil) {
    add('ipmask', [
      ip.mask(net.cidrMask(gi(12), gi(32))).string(),
      ip.mask(net.cidrMask(gi(70), gi(128))).string(),
      ip.mask(net.cidrMask(gi(108), gi(128))).string(),
      bit(ip.equal(ip.to4())),
      bit(ip.equal(net.parseIP(gs('10.1.2.3')))),
    ]);
  }
  final (cip, cnet, cerr) = net.parseCIDR(s);
  var cs = 'nil';
  if (cnet != null) {
    cs =
        '${cnet.string()} ${cnet.network()} ${bit(cnet.contains(cip))} '
        '${bit(cnet.contains(net.parseIP(gs('10.200.0.1'))))}';
  }
  add('cidr', [hx(cip), cs, es(cerr)]);
  final (h, p, herr) = net.splitHostPort(s);
  add('hostport', [h, p, es(herr), net.joinHostPort(h, p)]);
  final (hw, mErr) = net.parseMAC(s);
  add('mac', [hw.string(), hx(hw), es(mErr)]);

  final (a, aerr) = netip.parseAddr(s);
  final (bin, _) = a.marshalBinary();
  final (atx, _) = a.marshalText();
  add('addr', [
    a.string(),
    es(aerr),
    a.stringExpanded(),
    addrFlags(a),
    a.bitLen().toInt(),
    a.zone(),
    a.next().string(),
    a.prev().string(),
    a.unmap().string(),
    hx(a.asSlice()),
    hx(bin),
    txt(atx),
    a.compare(prev).toInt(),
    bit(a.less(prev)),
    bit(a == prev),
  ]);
  for (final n in [0, 1, 17, 31, 32, 64, 120, 128, 129, -1]) {
    final (pf, err) = a.prefix(gi(n));
    add('addrprefix', [pf.string(), es(err)]);
  }
  final u = netip.Addr();
  final uerr = u.unmarshalBinary(bin);
  add('addrunbin', [u.string(), es(uerr), bit(u == a)]);

  final (pf, perr) = netip.parsePrefix(s);
  final (pbin, _) = pf.marshalBinary();
  final (ptxt, _) = pf.marshalText();
  add('prefix', [
    pf.string(),
    es(perr),
    pf.masked().string(),
    pf.bits().toInt(),
    bit(pf.isValid()),
    bit(pf.isSingleIP()),
    pf.addr$().string(),
    hx(pbin),
    txt(ptxt),
    bit(pf.contains(prev)),
    bit(pf.contains(pf.addr$().next())),
    bit(pf.overlaps(netip.mustParsePrefix(gs('10.0.0.0/16')))),
    bit(pf.overlaps(netip.mustParsePrefix(gs('2001:db8::/48')))),
    pf.compare(netip.mustParsePrefix(gs('10.1.0.0/16'))).toInt(),
  ]);

  final (ap, aperr) = netip.parseAddrPort(s);
  final (abin, _) = ap.marshalBinary();
  final (aptx, _) = ap.marshalText();
  add('addrport', [
    ap.string(),
    es(aperr),
    ap.port().toInt(),
    ap.addr$().string(),
    hx(abin),
    txt(aptx),
    bit(ap.isValid()),
    net.tcpAddrFromAddrPort(ap).string(),
    net.udpAddrFromAddrPort(ap).string(),
  ]);
  return out;
}

net.IPMask mask(List<int> b) => net.IPMask(
  Slice.of([
    for (final x in b) Golang.Uint8(x),
  ], const Elem<Golang.Uint8>(1, Golang.Uint8.new, ofInt: Golang.Uint8.from)),
);

void main() {
  test('net e net/netip iguais ao Go: parse, formatação, máscaras, '
      'prefixos e erros', () async {
    final r = await Process.run(
      'go',
      ['run', 'test/go_net_vectors.go'],
      environment: {...Platform.environment, 'GOTOOLCHAIN': 'go1.26.5'},
      stdoutEncoding: utf8,
    );
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final go = jsonDecode(r.stdout as String) as Map<String, dynamic>;
    final inputs = [for (final s in go['inputs'] as List) s as String];
    final res = go['res'] as List;
    var prev = netip.mustParseAddr(gs('10.1.2.3'));
    final bad = <String>[];
    for (var i = 0; i < inputs.length; i++) {
      final s = gs(inputs[i]);
      final got = run(s, prev);
      final want = [for (final l in res[i] as List) l as String];
      for (var k = 0; k < want.length || k < got.length; k++) {
        final w = k < want.length ? want[k] : '(nada)';
        final g = k < got.length ? got[k] : '(nada)';
        if (w != g)
          bad.add('in=${jsonEncode(inputs[i])}\n  go : $w\n  dart: $g');
      }
      final (a, err) = netip.parseAddr(s);
      if (err == null) prev = a;
    }
    expect(
      bad.length,
      0,
      reason: '${bad.length} divergências:\n${bad.take(25).join('\n')}',
    );

    final masks = <String>[];
    for (final bits in [0, 32, 64, 128]) {
      for (final ones in [
        -1,
        0,
        1,
        7,
        8,
        9,
        24,
        31,
        32,
        33,
        64,
        127,
        128,
        129,
      ]) {
        final m = net.cidrMask(gi(ones), gi(bits));
        final (o, b) = m.size();
        masks.add('$ones/$bits ${m.string()} ${o.toInt()} ${b.toInt()}');
      }
    }
    for (final b in [
      [0xff, 0, 0xff, 0],
      [0xff, 0xf0, 0, 0],
      <int>[],
      [0xff],
      [0x80, 0, 0, 1],
    ]) {
      final m = mask(b);
      final (o, s) = m.size();
      final n = net.IPNet(
        ip: net.iPv4(
          Golang.Uint8(10),
          Golang.Uint8(1),
          Golang.Uint8(2),
          Golang.Uint8(3),
        ),
        mask: m,
      );
      masks.add('${m.string()} ${o.toInt()} ${s.toInt()} ${n.string()}');
    }
    expect(masks, go['masks']);
  });

  test('erros e endereços do net com o texto do Go', () {
    final tcp = net.TCPAddr(ip: net.parseIP(gs('127.0.0.1')), port: gi(4001));
    final udp = net.UDPAddr(
      ip: net.parseIP(gs('::1')),
      port: gi(53),
      zone: gs('lo'),
    );
    final op = net.OpError(
      op: gs('dial'),
      net: gs('tcp'),
      source: tcp,
      addr: udp,
      err: net.errClosed,
    );
    expect(
      op.error().toString(),
      'dial tcp 127.0.0.1:4001->[::1%lo]:53: use of closed network connection',
    );
    expect(op.unwrap(), same(net.errClosed));
    expect(op.timeout(), isFalse);
    // Go: os.IsTimeout(&net.OpError{Err: os.ErrDeadlineExceeded}) == true.
    expect(os.isTimeout(op), isFalse);
    final dl = net.OpError(
      op: gs('read'),
      net: gs('tcp'),
      err: os.errDeadlineExceeded,
    );
    expect(dl.timeout(), isTrue);
    expect(os.isTimeout(dl), isTrue);
    expect(dl.error().toString(), 'read tcp: i/o timeout');
    expect(net.OpError.$nil.error().toString(), '<nil>');
    expect(net.TCPAddr.$nil.string().toString(), '<nil>');
    expect(
      net.DNSError(
        err: gs('no such host'),
        name: gs('x.invalid'),
        isNotFound: true,
      ).error().toString(),
      'lookup x.invalid: no such host',
    );
    expect(
      net.AddrError(err: gs('bad'), addr: gs('1.2')).error().toString(),
      'address 1.2: bad',
    );
    expect(
      net.UnknownNetworkError(gs('foo')).error().toString(),
      'unknown network foo',
    );
    expect(net.iPv4zero.string().toString(), '0.0.0.0');
    expect(net.iPv6linklocalallrouters.string().toString(), 'ff02::2');
    final ptr = net.IP$Ptr(Box<net.IP>(net.parseIP(gs('1.2.3.4'))));
    expect(ptr.unmarshalText(net.parseIP(gs('::1')).to16()), isNotNull);
    expect(
      es(
        ptr.unmarshalText(
          Slice.nil(const Elem<Golang.Uint8>(1, Golang.Uint8.new)),
        ),
      ),
      '<nil>',
    );
    expect(ptr.value.isNil, isTrue);
  });
}
