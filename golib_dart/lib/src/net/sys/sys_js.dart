/// Motor de rede do JS (dart2js) e do Wasm (dart2wasm): sob Node, os módulos
/// `node:net`, `node:dgram`, `node:dns`, `node:os` e `node:fs` por
/// `dart:js_interop`, carregados com `process.getBuiltinModule` (Node ≥
/// 22.3; funciona em script e em ESM). Sem Node (navegador), toda operação
/// lança `SysError(..., 'EOPNOTSUPP', 'operation not supported')` — nada de
/// TCP emulado sobre WebSocket (decisão D4).
library;

import 'dart:async';
import 'dart:collection';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import '../../internal/poll/fd_mutex.dart';
import '../../runtime/output.dart' show ensureAsyncScheduling;
import 'common.dart';
import 'linux_iface.dart';

part 'js_dns.dart';
part 'js_listen.dart';
part 'js_node.dart';
part 'js_tcp.dart';
part 'js_udp.dart';
part 'js_unix.dart';

/// Rede disponível: só sob Node (com `process.getBuiltinModule`).
bool get sysNetSupported => _node != null;

/// Conecta em [remote]; [local] fixa a origem; [deadline] vence com
/// [SysTimeout]; [cancel] completando aborta com [SysCanceled].
Future<SysTcpConn> sysDialTcp(
  SysAddr remote, {
  SysAddr? local,
  DateTime? deadline,
  Future<void>? cancel,
}) async {
  _require('socket');
  return heldIo(() => _dialTcp(remote, local, deadline, cancel));
}

/// Escuta TCP em [local]; IP vazio = dual-stack quando há IPv6 (o padrão do
/// `server.listen` do Node sem `host`), senão `0.0.0.0`. [v6Only]: `tcp6`.
Future<SysTcpListener> sysListenTcp(
  SysAddr local, {
  int backlog = 128,
  bool v6Only = false,
}) async {
  _require('socket');
  return _listenTcp(local, backlog, v6Only);
}

/// Conecta no socket Unix de fluxo em [path]; [deadline] vence com
/// [SysTimeout]; [cancel] completando aborta com [SysCanceled].
Future<SysTcpConn> sysDialUnix(
  String path, {
  DateTime? deadline,
  Future<void>? cancel,
}) async {
  _require('socket');
  return heldIo(() => _dialUnix(path, deadline, cancel));
}

/// Escuta no socket Unix de fluxo em [path].
Future<SysTcpListener> sysListenUnix(String path, {int backlog = 128}) async {
  _require('socket');
  return _listenUnix(path, backlog);
}

/// Apaga o arquivo do socket Unix [path] (o `unlink` do `Close`).
void sysUnlinkUnix(String path) {
  if (_node == null) return;
  _unlinkUnix(path);
}

/// Socket UDP em [local] (IP vazio: `udp6` dual-stack, ou `udp4` sem IPv6).
Future<SysUdpConn> sysListenUdp(SysAddr local, {bool v6Only = false}) async {
  _require('socket');
  return _listenUdp(local, v6Only);
}

/// IPs de [host] pelo `dns.lookup` do Node (o `getaddrinfo` do sistema).
Future<List<Uint8List>> sysLookupIp(
  String host, {
  String network = 'ip',
}) async {
  _require('lookup');
  return heldIo(() => _lookupIp(host, network));
}

/// Registros TXT pelo `dns.resolveTxt` do Node; [server]: um
/// `dns.Resolver` só com ele.
Future<List<String>> sysLookupTxt(String name, {SysAddr? server}) async {
  _require('lookup');
  return heldIo(() => _lookupTxt(name, server));
}

/// Interfaces: `os.networkInterfaces()` (+ `/sys/class/net` no linux).
Future<List<SysInterface>> sysInterfaces() async {
  _require('netlink');
  return _interfaces();
}

/// Conteúdo do arquivo de texto [path], ou `null` (sem Node, ou não dá
/// para ler). Síncrono (`fs.readFileSync`).
String? sysReadFile(String path) {
  if (_node == null) return null;
  try {
    return _str(
      _fs.callMethod<JSAny?>('readFileSync'.toJS, path.toJS, 'latin1'.toJS),
    );
  } catch (_) {
    return null;
  }
}

/// O nome do host (`os.hostname()`); vazio sem Node.
String sysHostname() {
  if (_node == null) return '';
  return _str(_os.callMethod<JSAny?>('hostname'.toJS)) ?? '';
}

/// Sem Node: `operation not supported`. Com Node: garante o agendamento
/// do dart2js (`self`) antes do primeiro temporizador.
void _require(String syscall) {
  if (_node == null) throw SysError.unsupported(syscall);
  ensureAsyncScheduling();
}

/// Socket cru da rede FFI (`Control`, `SyscallConn` com fd real): não
/// existe aqui; falha como o Go em js/wasm (F4: `socket: operation not
/// supported`).
SysSocket sysSocket(int family, int sotype, int proto) =>
    throw SysError.unsupported('socket');

/// Sem rede FFI, a família não é escolhida por aqui.
SysIpStack sysIpStack() =>
    const SysIpStack(ipv4: true, ipv6: false, ipv4MappedIPv6: false);
