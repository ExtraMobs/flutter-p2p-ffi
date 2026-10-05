/// Motor de rede da VM/AOT sobre `dart:io`: TCP pelo `Fd` do
/// `internal/poll` (sobre `RawSocket`), UDP por `RawDatagramSocket` com o
/// mesmo `PollDesc`/`FdMutex`, DNS de IP pelo `getaddrinfo` do sistema
/// (`InternetAddress.lookup`) e TXT pelo cliente próprio (`dns_client.dart`)
/// lendo `/etc/resolv.conf`.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import '../../internal/poll/errors.dart';
import '../../internal/poll/fd.dart';
import '../../internal/poll/fd_mutex.dart';
import '../../internal/poll/poll_desc.dart';
import 'common.dart';
import 'dns_client.dart';
import 'linux_iface.dart';
import 'resolv_conf.dart';

part 'io_errno.dart';
part 'io_iface.dart';
part 'io_listen.dart';
part 'io_tcp.dart';
part 'io_udp.dart';
part 'io_unix.dart';

/// Rede disponível (sempre, na VM).
bool get sysNetSupported => true;

/// Conecta em [remote]; [local] fixa a origem; [deadline] vence com
/// [SysTimeout]; [cancel] completando aborta com [SysCanceled].
Future<SysTcpConn> sysDialTcp(
  SysAddr remote, {
  SysAddr? local,
  DateTime? deadline,
  Future<void>? cancel,
}) => heldIo(() => _dialTcp(remote, local, deadline, cancel));

/// Escuta TCP em [local]; IP vazio = todas as interfaces, dual-stack (`::`
/// com `IPV6_V6ONLY` desligado) quando há IPv6, senão `0.0.0.0`, como o Go no
/// linux. [v6Only] (desvio do contrato) é o `tcp6` do Go.
Future<SysTcpListener> sysListenTcp(
  SysAddr local, {
  int backlog = 128,
  bool v6Only = false,
}) => _listenTcp(local, backlog, v6Only);

/// Conecta no socket Unix de fluxo em [path]; [deadline] vence com
/// [SysTimeout]; [cancel] completando aborta com [SysCanceled].
Future<SysTcpConn> sysDialUnix(
  String path, {
  DateTime? deadline,
  Future<void>? cancel,
}) => heldIo(() => _dialUnix(path, deadline, cancel));

/// Escuta no socket Unix de fluxo em [path].
Future<SysTcpListener> sysListenUnix(String path, {int backlog = 128}) =>
    _listenUnix(path, backlog);

/// Apaga o arquivo do socket Unix [path] (o `unlink` do `Close`).
void sysUnlinkUnix(String path) => _unlinkUnix(path);

/// Socket UDP em [local] (IP vazio: dual-stack quando há IPv6). [v6Only] é
/// ignorado na VM (⚠️ o `dart:io` não expõe `IPV6_V6ONLY` para UDP).
Future<SysUdpConn> sysListenUdp(SysAddr local, {bool v6Only = false}) =>
    _listenUdp(local);

/// IPs de [host] pelo resolvedor do sistema (`getaddrinfo`: `/etc/hosts`,
/// DNS...). [network]: `ip`, `ip4` ou `ip6`.
Future<List<Uint8List>> sysLookupIp(String host, {String network = 'ip'}) =>
    heldIo(() async {
      final type = switch (network) {
        'ip4' => InternetAddressType.IPv4,
        'ip6' => InternetAddressType.IPv6,
        _ => InternetAddressType.any,
      };
      final List<InternetAddress> addrs;
      try {
        addrs = await InternetAddress.lookup(host, type: type);
      } on SocketException catch (e) {
        throw _dnsError(host, e);
      }
      final out = <Uint8List>[];
      for (final a in addrs) {
        final raw = a.rawAddress;
        if (!out.any((o) => _eq(o, raw))) out.add(raw);
      }
      if (out.isEmpty) throw SysDnsError.notFound(host);
      return out;
    });

/// Registros TXT de [name] (character-strings de cada registro
/// concatenadas). [server] troca o `/etc/resolv.conf` por um servidor só.
Future<List<String>> sysLookupTxt(String name, {SysAddr? server}) =>
    heldIo(() async {
      String? text;
      try {
        text = await File('/etc/resolv.conf').readAsString();
      } on FileSystemException {
        text = null;
      }
      final conf = ResolvConf.parse(text, parseIp: parseIp);
      return dnsLookupTxt(name, conf, (
        listenUdp: sysListenUdp,
        dialTcp: (remote, deadline) => sysDialTcp(remote, deadline: deadline),
      ), server: server);
    });

/// Interfaces de rede (ver `io_iface.dart` para o que vem de onde).
Future<List<SysInterface>> sysInterfaces() => _interfaces();

/// `getsockopt` cru de uma conexão TCP desta plataforma (só na VM; não faz
/// parte do contrato de [SysTcpConn]): os testes conferem com ele o que
/// `setLinger`/`setKeepAlive*` gravaram no socket. `null` se [c] não é uma
/// conexão desta plataforma.
Uint8List? sysGetRawOption(SysTcpConn c, int level, int option, int length) =>
    c is _IoTcpConn
    ? c._socket.getRawOption(RawSocketOption(level, option, Uint8List(length)))
    : null;

SysDnsError _dnsError(String host, SocketException e) {
  final code = e.osError?.errorCode ?? 0;
  // EAI_NONAME (-2) e EAI_NODATA (-5) no glibc; 8/7 no macOS; 11001/11004
  // (WSAHOST_NOT_FOUND/WSANO_DATA) no Windows.
  const notFound = {-2, -5, 8, 7, 11001, 11004};
  // EAI_AGAIN (-3) no glibc, 2 no macOS, WSATRY_AGAIN no Windows.
  const again = {-3, 2, 11002};
  if (notFound.contains(code)) return SysDnsError.notFound(host);
  if (again.contains(code)) {
    return SysDnsError(host, 'server misbehaving', isTemporary: true);
  }
  final msg = e.osError?.message ?? e.message;
  return SysDnsError(host, msg.isEmpty ? 'no such host' : msg.toLowerCase());
}

bool _eq(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// [ip] (+ zona) como endereço do `dart:io`.
InternetAddress _inet(Uint8List ip, [String zone = '']) {
  if (zone.isNotEmpty) {
    final parsed = InternetAddress.tryParse('${ipToString(ip)}%$zone');
    if (parsed != null) return parsed;
  }
  return InternetAddress.fromRawAddress(ip);
}

SysAddr _addrOf(InternetAddress a, int port) {
  final s = a.address;
  final pct = s.indexOf('%');
  return SysAddr(a.rawAddress, port, pct < 0 ? '' : s.substring(pct + 1));
}
