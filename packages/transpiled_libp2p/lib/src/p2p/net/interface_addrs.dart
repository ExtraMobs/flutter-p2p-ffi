// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:io';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

/// Transpilação 1:1 de `InterfaceMultiaddrs()` de `go-multiaddr/net/net.go:389-403`.
/// Retorna os multiaddrs correspondentes às interfaces de rede da máquina local.
Future<List<Multiaddr>> interfaceMultiaddrs() async {
  final interfaces = await NetworkInterface.list(
    includeLoopback: true,
    type: InternetAddressType.any,
  );
  final maddrs = <Multiaddr>[];
  for (final iface in interfaces) {
    for (final addr in iface.addresses) {
      final proto = addr.type == InternetAddressType.IPv6 ? 'ip6' : 'ip4';
      maddrs.add(Multiaddr.parse('/$proto/${addr.address}'));
    }
  }
  return maddrs;
}

/// Transpilação 1:1 de `interfaceAddresses()` de `go-multiaddr/net/resolve.go:74-88`.
/// Retorna os multiaddrs das interfaces excluindo endereços link-local IPv6 (fe80::/10).
Future<List<Multiaddr>> interfaceAddresses() async {
  final maddrs = await interfaceMultiaddrs();
  return maddrs.where((a) => !isIp6LinkLocal(a)).toList();
}

/// Transpilação 1:1 de `interfaceAddrsCache` de `go-libp2p/p2p/host/basic/addrs_manager.go:794-835`.
/// Mantém em cache os endereços das interfaces com TTL de 1 minuto (`interfaceAddrsCacheTTL`).
class InterfaceAddrsCache {
  static const Duration interfaceAddrsCacheTtl = Duration(minutes: 1);

  List<Multiaddr> _all = const [];
  DateTime _lastUpdated = DateTime.fromMillisecondsSinceEpoch(0);

  /// Retorna todos os endereços de interface em cache, atualizando de forma assíncrona se expirado.
  Future<List<Multiaddr>> all() async {
    if (DateTime.now().difference(_lastUpdated) > interfaceAddrsCacheTtl) {
      await update();
    }
    return _all;
  }

  /// Retorna os endereços já em cache sincronicamente, ou fallback para loopback se vazio.
  List<Multiaddr> allSync() {
    if (_all.isEmpty) {
      return [ip4Loopback, ip6Loopback];
    }
    return _all;
  }

  /// Atualiza o cache consultando as interfaces do SO.
  Future<List<Multiaddr>> update() async {
    try {
      final addrs = await interfaceAddresses();
      _all = addrs;
      _lastUpdated = DateTime.now();
    } catch (_) {
      _all = [ip4Loopback, ip6Loopback];
    }
    return _all;
  }
}
