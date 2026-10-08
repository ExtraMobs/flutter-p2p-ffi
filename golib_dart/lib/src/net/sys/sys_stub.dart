/// Plataforma sem `dart:io` nem `dart:js_interop`: nenhuma rede; toda
/// operação lança `SysError(..., 'EOPNOTSUPP', 'operation not supported')`.
/// (O navegador cai no mesmo comportamento por `sys_js.dart`.)
library;

import 'dart:async';
import 'dart:typed_data';

import 'common.dart';

/// Rede disponível: nunca, aqui.
bool get sysNetSupported => false;

/// Fecha o listener Unix (não há arquivo a preservar).
void sysCloseKeepingUnixFile(String path, void Function() close) => close();

Future<SysTcpConn> sysDialTcp(
  SysAddr remote, {
  SysAddr? local,
  DateTime? deadline,
  Future<void>? cancel,
}) async => throw SysError.unsupported('socket');

Future<SysTcpListener> sysListenTcp(
  SysAddr local, {
  int backlog = 128,
  bool v6Only = false,
}) async => throw SysError.unsupported('socket');

Future<SysUdpConn> sysListenUdp(SysAddr local, {bool v6Only = false}) async =>
    throw SysError.unsupported('socket');

Future<SysTcpConn> sysDialUnix(
  String path, {
  DateTime? deadline,
  Future<void>? cancel,
}) async => throw SysError.unsupported('socket');

Future<SysTcpListener> sysListenUnix(String path, {int backlog = 128}) async =>
    throw SysError.unsupported('socket');

void sysUnlinkUnix(String path) {}

Future<List<Uint8List>> sysLookupIp(
  String host, {
  String network = 'ip',
}) async => throw SysError.unsupported('lookup');

Future<List<String>> sysLookupTxt(String name, {SysAddr? server}) async =>
    throw SysError.unsupported('lookup');

Future<List<SysInterface>> sysInterfaces() async =>
    throw SysError.unsupported('netlink');

/// Sem sistema de arquivos: `null`.
String? sysReadFile(String path) => null;

/// Sem nome de host.
String sysHostname() => '';

/// Socket cru da rede FFI (`Control`, `SyscallConn` com fd real): não
/// existe aqui; falha como o Go em js/wasm (F4: `socket: operation not
/// supported`).
SysSocket sysSocket(int family, int sotype, int proto) =>
    throw SysError.unsupported('socket');

/// Sem rede FFI, não há `close` adiado a esperar.
Future<void> sysClosesSettled() async {}

/// Sem rede FFI, a família não é escolhida por aqui.
SysIpStack sysIpStack() =>
    const SysIpStack(ipv4: true, ipv6: false, ipv4MappedIPv6: false);
