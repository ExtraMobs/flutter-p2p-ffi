part of '../../net.dart';

// `addrselect.go`: a ordem RFC 6724 dos endereços de um nome. A origem de
// cada destino é a do kernel, como no Go: o `LocalAddr` de um `DialUDP`
// (`connect`) para a porta 9; sem rota, o destino fica sem origem.

/// `sortByRFC6724(addrs)`.
Future<void> _sortByRFC6724(List<_IPZ> addrs) async {
  if (addrs.length < 2) return;
  final infos = [for (final a in addrs) _RFC6724Info(a, await _srcAddr(a))];
  _sortStable(infos, _compareByRFC6724);
  for (var i = 0; i < infos.length; i++) {
    addrs[i] = infos[i].addr;
  }
}

/// `srcAddrs` (um destino): a origem de [dst], ou `null` sem rota.
Future<Uint8List?> _srcAddr(_IPZ dst) async {
  final (c, err) = await dialUDP(
    _gs('udp'),
    null,
    UDPAddr(ip: _ipOf(dst.$1), port: Golang.Int(9), zone: _gs(dst.$2)),
  );
  if (err != null || c == null) return null;
  final la = c.localAddr();
  c.close();
  return la is UDPAddr ? _as16(_ipBytes(la.ip)) : null;
}

/// IP em 16 bytes (IPv4 mapeado).
Uint8List _as16(Uint8List ip) {
  if (ip.length == 16) return ip;
  return Uint8List(16)
    ..[10] = 0xff
    ..[11] = 0xff
    ..setRange(12, 16, ip);
}

bool _isV4(Uint8List ip) => ip.length == 4 || _isV4Mapped(ip);

bool _isLoopbackIP(Uint8List ip) {
  final b = _as16(ip);
  if (_isV4Mapped(b)) return b[12] == 127;
  for (var i = 0; i < 15; i++) {
    if (b[i] != 0) return false;
  }
  return b[15] == 1;
}

bool _isLinkLocalIP(Uint8List ip) {
  final b = _as16(ip);
  if (_isV4Mapped(b)) return b[12] == 169 && b[13] == 254;
  return b[0] == 0xfe && b[1] & 0xc0 == 0x80;
}

final class _RFC6724Info {
  _RFC6724Info(this.addr, this.src)
    : addrAttr = _ipAttrOf(addr.$1),
      srcAttr = src == null ? const _IPAttr(0, 0, 0) : _ipAttrOf(src);
  final _IPZ addr;
  final Uint8List? src;
  final _IPAttr addrAttr;
  final _IPAttr srcAttr;
}

final class _IPAttr {
  const _IPAttr(this.scope, this.precedence, this.label);
  final int scope;
  final int precedence;
  final int label;
}

_IPAttr _ipAttrOf(Uint8List ip) {
  final (prec, label) = _classify(_as16(ip));
  return _IPAttr(_classifyScope(ip), prec, label);
}

/// `rfc6724policyTable`: (prefixo em 16 bytes, bits, precedência, rótulo),
/// do mais longo para o mais curto.
final _policyTable = <(List<int>, int, int, int)>[
  ([...List.filled(15, 0), 1], 128, 50, 0),
  ([...List.filled(10, 0), 0xff, 0xff], 96, 35, 4),
  ([], 96, 1, 3),
  ([0x20, 0x01], 32, 5, 5),
  ([0x20, 0x02], 16, 30, 2),
  ([0x3f, 0xfe], 16, 1, 12),
  ([0xfe, 0xc0], 10, 1, 11),
  ([0xfc], 7, 3, 13),
  ([], 0, 40, 1),
];

(int, int) _classify(Uint8List ip) {
  for (final (prefix, bits, prec, label) in _policyTable) {
    var ok = true;
    for (var i = 0; i < bits && ok; i++) {
      final want = i ~/ 8 < prefix.length
          ? (prefix[i ~/ 8] >> (7 - i % 8)) & 1
          : 0;
      ok = ((ip[i ~/ 8] >> (7 - i % 8)) & 1) == want;
    }
    if (ok) return (prec, label);
  }
  return (0, 0);
}

/// `classifyScope`.
int _classifyScope(Uint8List ip) {
  if (_isLoopbackIP(ip) || _isLinkLocalIP(ip)) return 0x2;
  final b = _as16(ip);
  final v6 = !_isV4Mapped(b);
  if (v6 && b[0] == 0xff) return b[1] & 0xf;
  if (v6 && b[0] == 0xfe && b[1] & 0xc0 == 0xc0) return 0x5;
  return 0xe;
}

/// `commonPrefixLen(a, b)`: só os 64 bits do prefixo, no IPv6.
int _commonPrefixLen(Uint8List a, Uint8List b) {
  final av = _isV4Mapped(_as16(a)) ? _as16(a).sublist(12) : _as16(a);
  final bv = _isV4Mapped(_as16(b)) ? _as16(b).sublist(12) : _as16(b);
  if (av.length != bv.length) return 0;
  final n = av.length > 8 ? 8 : av.length;
  var cpl = 0;
  for (var i = 0; i < n; i++) {
    if (av[i] == bv[i]) {
      cpl += 8;
      continue;
    }
    var bits = 8, x = av[i], y = bv[i];
    while (true) {
      x >>= 1;
      y >>= 1;
      bits--;
      if (x == y) return cpl + bits;
    }
  }
  return cpl;
}

/// `compareByRFC6724`: -1 prefere a, 1 prefere b.
int _compareByRFC6724(_RFC6724Info a, _RFC6724Info b) {
  final da = a.addr.$1, db = b.addr.$1;
  final sa = a.src, sb = b.src;
  final ada = a.addrAttr, adb = b.addrAttr;
  final asa = a.srcAttr, asb = b.srcAttr;
  // Regra 1: destino sem origem por último.
  if (sa == null && sb == null) return 0;
  if (sb == null) return -1;
  if (sa == null) return 1;
  // Regra 2: escopo igual ao da origem.
  if (ada.scope == asa.scope && adb.scope != asb.scope) return -1;
  if (ada.scope != asa.scope && adb.scope == asb.scope) return 1;
  // Regra 5: rótulo igual ao da origem.
  if (asa.label == ada.label && asb.label != adb.label) return -1;
  if (asa.label != ada.label && asb.label == adb.label) return 1;
  // Regra 6: precedência maior.
  if (ada.precedence > adb.precedence) return -1;
  if (ada.precedence < adb.precedence) return 1;
  // Regra 8: escopo menor.
  if (ada.scope < adb.scope) return -1;
  if (ada.scope > adb.scope) return 1;
  // Regra 9: prefixo comum mais longo (só IPv6).
  if (!_isV4(da) && !_isV4(db)) {
    final ca = _commonPrefixLen(sa, da), cb = _commonPrefixLen(sb, db);
    if (ca > cb) return -1;
    if (ca < cb) return 1;
  }
  return 0;
}
