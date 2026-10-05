/// Plataforma sem `dart:io` nem `dart:js_interop`: nenhuma rede; toda
/// operação lança `SysError(..., 'EOPNOTSUPP', 'operation not supported')`.
/// (O navegador cai no mesmo comportamento por `sys_js.dart`.)
library;

import 'dart:async';
import 'dart:typed_data';

import 'common.dart';

/// Rede disponível: nunca, aqui.
bool get sysNetSupported => false;

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

Future<List<Uint8List>> sysLookupIp(
  String host, {
  String network = 'ip',
}) async => throw SysError.unsupported('lookup');

Future<List<String>> sysLookupTxt(String name, {SysAddr? server}) async =>
    throw SysError.unsupported('lookup');

Future<List<SysInterface>> sysInterfaces() async =>
    throw SysError.unsupported('netlink');
