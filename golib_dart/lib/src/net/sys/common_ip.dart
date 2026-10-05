part of 'common.dart';

// IP em texto e conversões entre as formas de 4 e 16 bytes.

/// IP de 4 ou 16 bytes em texto, como o `net.IP.String` do Go (IPv4 mapeado
/// sai como `a.b.c.d`; IPv6 com a maior sequência de zeros comprimida).
String ipToString(Uint8List ip) {
  if (ip.length == 4) return ip.join('.');
  if (ip.length != 16) return '?';
  if (isV4Mapped(ip)) return ip.sublist(12).join('.');
  final words = [for (var i = 0; i < 16; i += 2) (ip[i] << 8) | ip[i + 1]];
  var bestStart = -1, bestLen = 0;
  for (var i = 0; i < 8;) {
    if (words[i] != 0) {
      i++;
      continue;
    }
    var j = i;
    while (j < 8 && words[j] == 0) {
      j++;
    }
    if (j - i > bestLen && j - i >= 2) {
      bestStart = i;
      bestLen = j - i;
    }
    i = j;
  }
  final out = StringBuffer();
  for (var i = 0; i < 8; i++) {
    if (i == bestStart) {
      out.write('::');
      i += bestLen - 1;
      continue;
    }
    if (i > 0 && i != bestStart + bestLen) out.write(':');
    out.write(words[i].toRadixString(16));
  }
  return out.toString();
}

/// IP em texto do jeito que o sistema aceita (`::ffff:a.b.c.d` para mapeado,
/// para não virar IPv4 puro num socket IPv6).
String ipToSystemString(Uint8List ip) => ip.length == 16 && isV4Mapped(ip)
    ? '::ffff:${ip.sublist(12).join('.')}'
    : ipToString(ip);

/// Texto (IPv4, IPv6, com ou sem `%zona`) → bytes e zona; `null` se não é IP.
(Uint8List, String)? parseIpZone(String s) {
  var zone = '';
  final pct = s.indexOf('%');
  if (pct >= 0) {
    zone = s.substring(pct + 1);
    s = s.substring(0, pct);
  }
  final ip = parseIp(s);
  return ip == null ? null : (ip, zone);
}

/// IPv4 → 4 bytes; IPv6 → 16 bytes; `null` se não é IP.
Uint8List? parseIp(String s) {
  if (!s.contains(':')) return _parseV4(s);
  final out = Uint8List(16);
  var tail = s;
  // Sufixo IPv4 (`::ffff:1.2.3.4`).
  Uint8List? v4;
  final lastColon = tail.lastIndexOf(':');
  if (tail.substring(lastColon + 1).contains('.')) {
    v4 = _parseV4(tail.substring(lastColon + 1));
    if (v4 == null) return null;
    tail = '${tail.substring(0, lastColon + 1)}0:0';
  }
  final halves = tail.split('::');
  if (halves.length > 2) return null;
  List<int>? words(String part) {
    if (part.isEmpty) return [];
    final r = <int>[];
    for (final w in part.split(':')) {
      if (w.isEmpty || w.length > 4) return null;
      final v = int.tryParse(w, radix: 16);
      if (v == null) return null;
      r.add(v);
    }
    return r;
  }

  final head = words(halves[0]);
  final rest = halves.length == 2 ? words(halves[1]) : <int>[];
  if (head == null || rest == null) return null;
  final total = head.length + rest.length;
  if (halves.length == 1 ? total != 8 : total > 7) return null;
  final all = [...head, ...List.filled(8 - total, 0), ...rest];
  for (var i = 0; i < 8; i++) {
    out[2 * i] = all[i] >> 8;
    out[2 * i + 1] = all[i] & 0xff;
  }
  if (v4 != null) out.setRange(12, 16, v4);
  return out;
}

Uint8List? _parseV4(String s) {
  final parts = s.split('.');
  if (parts.length != 4) return null;
  final out = Uint8List(4);
  for (var i = 0; i < 4; i++) {
    final p = parts[i];
    if (p.isEmpty || p.length > 3 || (p.length > 1 && p[0] == '0')) {
      return null;
    }
    final v = int.tryParse(p);
    if (v == null || v > 255) return null;
    out[i] = v;
  }
  return out;
}

/// `::ffff:a.b.c.d`.
bool isV4Mapped(Uint8List ip) {
  if (ip.length != 16) return false;
  for (var i = 0; i < 10; i++) {
    if (ip[i] != 0) return false;
  }
  return ip[10] == 0xff && ip[11] == 0xff;
}

/// IPv4 (4 bytes ou mapeado) → 4 bytes; o resto, `null`.
Uint8List? ipTo4(Uint8List ip) {
  if (ip.length == 4) return ip;
  if (isV4Mapped(ip)) return Uint8List.sublistView(ip, 12);
  return null;
}

/// IPv4 de 4 bytes → mapeado em IPv6 (16 bytes); IPv6 fica como está.
Uint8List ipTo16(Uint8List ip) {
  if (ip.length != 4) return ip;
  return Uint8List(16)
    ..[10] = 0xff
    ..[11] = 0xff
    ..setRange(12, 16, ip);
}

/// 127/8 ou `::1` (também mapeado).
bool isLoopbackIp(Uint8List ip) {
  final v4 = ipTo4(ip);
  if (v4 != null) return v4[0] == 127;
  if (ip.length != 16) return false;
  for (var i = 0; i < 15; i++) {
    if (ip[i] != 0) return false;
  }
  return ip[15] == 1;
}
