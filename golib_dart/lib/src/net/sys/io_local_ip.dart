part of 'sys_io.dart';

// O IP local de uma conexão TCP do `dart:io` (o `RawSocket` não o dá).

/// IP local de uma conexão. Com IP fixado (bind explícito), é ele; no linux,
/// a linha da conexão em `/proc/net/tcp{,6}` (exato); senão, ⚠️ o loopback
/// da família quando o par é loopback, e "não especificado" no resto.
Future<Uint8List> _localIp(Uint8List? bound, SysAddr remote, int port) async {
  if (bound != null && bound.isNotEmpty && !bound.every((b) => b == 0)) {
    return bound;
  }
  if (Platform.isLinux || Platform.isAndroid) {
    final ip = await _procLocalIp(remote, port);
    if (ip != null) {
      return remote.ip.length == 16 ? ipTo16(ip) : (ipTo4(ip) ?? ip);
    }
  }
  final v4 = ipTo4(remote.ip);
  if (isLoopbackIp(remote.ip)) {
    if (v4 == null) return Uint8List(16)..[15] = 1;
    final lo = Uint8List.fromList([127, 0, 0, 1]);
    return remote.ip.length == 16 ? ipTo16(lo) : lo;
  }
  return Uint8List(remote.ip.length);
}

/// Procura `local:port ↔ remote` em `/proc/net/tcp` e `tcp6`.
Future<Uint8List?> _procLocalIp(SysAddr remote, int port) async {
  final want = ipTo16(remote.ip);
  for (final f in const ['/proc/net/tcp', '/proc/net/tcp6']) {
    final String text;
    try {
      text = await File(f).readAsString();
    } on FileSystemException {
      continue;
    }
    for (final line in text.split('\n').skip(1)) {
      final cols = line.trim().split(RegExp(r'\s+'));
      if (cols.length < 3) continue;
      final l = _procAddr(cols[1]), r = _procAddr(cols[2]);
      if (l == null || r == null) continue;
      if (l.$2 != port || r.$2 != remote.port) continue;
      if (!_eq(ipTo16(r.$1), want)) continue;
      return l.$1;
    }
  }
  return null;
}

/// `0100007F:1F90` → (127.0.0.1, 8080): palavras de 32 bits na ordem do host.
(Uint8List, int)? _procAddr(String s) {
  final c = s.indexOf(':');
  if (c < 0) return null;
  final hex = s.substring(0, c);
  final port = int.tryParse(s.substring(c + 1), radix: 16);
  if (port == null || (hex.length != 8 && hex.length != 32)) return null;
  final out = Uint8List(hex.length ~/ 2);
  for (var w = 0; w < hex.length ~/ 8; w++) {
    final v = int.tryParse(hex.substring(w * 8, w * 8 + 8), radix: 16);
    if (v == null) return null;
    for (var b = 0; b < 4; b++) {
      final shift = Endian.host == Endian.little ? 8 * b : 8 * (3 - b);
      out[w * 4 + b] = (v >> shift) & 0xff;
    }
  }
  return (out, port);
}
