// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
//
// Transpilação 1:1 de `go-libp2p/p2p/host/basic/addrs_manager.go`.
// Gerencia a resolução de endereços locais, agregação de mapeamentos NAT,
// inclusão de endereços observados via Identify, remoção de endereços não especificados (0.0.0.0 e ::)
// e aplicação da AddrsFactory do usuário.

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../../core/host/host.dart';
import '../../net/interface_addrs.dart';
import 'nat_manager.dart';

const int maxObservedAddrsPerListenAddr = 3;

final Multiaddr p2pCircuitAddr = Multiaddr.parse('/p2p-circuit');

/// Transpilação 1:1 de `ObservedAddrsManager` (addrs_manager.go:38-41).
abstract interface class ObservedAddrsManager {
  List<Multiaddr> addrs(int minObservers);
  List<Multiaddr> addrsFor(Multiaddr local);
}

/// Transpilação 1:1 de `hostAddrs` (addrs_manager.go:43-50).
class HostAddrs {
  const HostAddrs({
    this.addrs = const [],
    this.localAddrs = const [],
    this.reachableAddrs = const [],
    this.unreachableAddrs = const [],
    this.unknownAddrs = const [],
    this.relayAddrs = const [],
  });

  final List<Multiaddr> addrs;
  final List<Multiaddr> localAddrs;
  final List<Multiaddr> reachableAddrs;
  final List<Multiaddr> unreachableAddrs;
  final List<Multiaddr> unknownAddrs;
  final List<Multiaddr> relayAddrs;
}

/// Transpilação 1:1 de `addrsManager` (addrs_manager.go:52-83).
class AddrsManager {
  AddrsManager({
    required List<Multiaddr> Function() listenAddrs,
    AddrsFactory? addrsFactory,
    List<Multiaddr> Function(List<Multiaddr>)? addCertHashes,
    this.observedAddrsManager,
    this.natManager,
    List<Multiaddr> Function()? relayAddrs,
    InterfaceAddrsCache? interfaceAddrs,
  }) : _listenAddrs = listenAddrs,
       _addrsFactory = addrsFactory ?? ((addrs) => addrs),
       _addCertHashes = addCertHashes ?? ((addrs) => addrs),
       _relayAddrs = relayAddrs ?? (() => const []),
       _interfaceAddrs = interfaceAddrs ?? InterfaceAddrsCache();

  final List<Multiaddr> Function() _listenAddrs;
  final AddrsFactory _addrsFactory;
  final List<Multiaddr> Function(List<Multiaddr>) _addCertHashes;
  final List<Multiaddr> Function() _relayAddrs;
  final ObservedAddrsManager? observedAddrsManager;
  final NatManager? natManager;
  final InterfaceAddrsCache _interfaceAddrs;

  /// Retorna os endereços dialáveis do nó aplicando a AddrsFactory.
  /// Espelha `addrsManager.Addrs()` (addrs_manager.go:448-454).
  List<Multiaddr> addrs() {
    final local = getLocalAddrs();
    final relay = _relayAddrs();
    final dialable = getDialableAddrs(local, relay);
    return applyAddrsFactory(dialable);
  }

  /// Retorna todos os endereços locais ouvidos pelo nó, exceto circuit addrs.
  /// Espelha `addrsManager.DirectAddrs()` (addrs_manager.go:502-506).
  List<Multiaddr> directAddrs() {
    return List<Multiaddr>.from(getLocalAddrs());
  }

  /// Resolve endereços de interface, NAT, observed e remove incondicionalmente
  /// endereços não especificados (0.0.0.0 e ::).
  /// Espelha `addrsManager.getLocalAddrs()` (addrs_manager.go:528-562).
  List<Multiaddr> getLocalAddrs() {
    final listenAddrs = _listenAddrs();
    if (listenAddrs.isEmpty) return const [];

    var finalAddrs = <Multiaddr>[];
    finalAddrs = appendInterfaceAddrs(finalAddrs, listenAddrs);

    if (natManager != null) {
      finalAddrs = appendNatAddrs(finalAddrs, listenAddrs);
    }

    if (observedAddrsManager != null) {
      finalAddrs = appendObservedAddrs(
        finalAddrs,
        listenAddrs,
        _interfaceAddrs.allSync(),
      );
    }

    // Remove "/p2p-circuit" addresses (addrs_manager.go:547-549)
    finalAddrs.removeWhere((a) => a == p2pCircuitAddr);

    // Remove any unspecified address from the list (addrs_manager.go:552-554)
    finalAddrs.removeWhere(isIpUnspecified);

    // Add certhashes (addrs_manager.go:558)
    finalAddrs = _addCertHashes(finalAddrs);

    // Deduplicate (addrs_manager.go:559)
    final seen = <String>{};
    final uniqueAddrs = <Multiaddr>[];
    for (final a in finalAddrs) {
      if (seen.add(a.toString())) {
        uniqueAddrs.add(a);
      }
    }

    // Sort by string representation
    uniqueAddrs.sort((a, b) => a.toString().compareTo(b.toString()));
    return uniqueAddrs;
  }

  /// Expande listen addrs não especificados nas interfaces locais do SO.
  /// Espelha `addrsManager.appendInterfaceAddrs` (addrs_manager.go:566-573).
  List<Multiaddr> appendInterfaceAddrs(
    List<Multiaddr> dst,
    List<Multiaddr> listenAddrs,
  ) {
    try {
      final resolved = resolveUnspecifiedAddresses(
        listenAddrs,
        _interfaceAddrs.allSync(),
      );
      dst.addAll(resolved);
    } catch (_) {
      dst.addAll(listenAddrs);
    }
    return dst;
  }

  /// Adiciona mapeamentos de porta externos do NAT (UPnP / NAT-PMP).
  /// Espelha `addrsManager.appendNATAddrs` (addrs_manager.go:578-586).
  List<Multiaddr> appendNatAddrs(
    List<Multiaddr> dst,
    List<Multiaddr> listenAddrs,
  ) {
    final nat = natManager;
    if (nat == null) return dst;
    for (final la in listenAddrs) {
      final mapped = nat.getMapping(la);
      if (mapped != null) {
        dst.add(mapped);
      }
    }
    return dst;
  }

  /// Adiciona endereços observados externamente reportados pelo protocolo Identify.
  /// Espelha `addrsManager.appendObservedAddrs` (addrs_manager.go:588-614).
  List<Multiaddr> appendObservedAddrs(
    List<Multiaddr> dst,
    List<Multiaddr> listenAddrs,
    List<Multiaddr> ifaceAddrs,
  ) {
    final obsMgr = observedAddrsManager;
    if (obsMgr == null) return dst;

    for (final la in listenAddrs) {
      var obsAddrs = obsMgr.addrsFor(la);
      if (obsAddrs.length > maxObservedAddrsPerListenAddr) {
        obsAddrs = obsAddrs.sublist(0, maxObservedAddrsPerListenAddr);
      }
      dst.addAll(obsAddrs);
    }

    try {
      final resolved = resolveUnspecifiedAddresses(listenAddrs, ifaceAddrs);
      for (final addr in resolved) {
        var obsAddrs = obsMgr.addrsFor(addr);
        if (obsAddrs.length > maxObservedAddrsPerListenAddr) {
          obsAddrs = obsAddrs.sublist(0, maxObservedAddrsPerListenAddr);
        }
        dst.addAll(obsAddrs);
      }
    } catch (_) {}

    return dst;
  }

  /// Retorna todos os endereços públicos diretos do nó, alcançáveis ou não,
  /// adequados para hole punching. Ao contrário de [addrs], inclui endereços
  /// observados com apenas 1 observador (via `observedAddrsManager.addrs(1)`)
  /// -- diferente do corte de [maxObservedAddrsPerListenAddr] usado em
  /// [appendObservedAddrs], que serve a [addrs]/[getLocalAddrs].
  /// Espelha `addrsManager.HolePunchAddrs` (addrs_manager.go:486-499).
  List<Multiaddr> holePunchAddrs() {
    var addrs = List<Multiaddr>.of(_addrsFactory(directAddrs()));
    final obsMgr = observedAddrsManager;
    if (obsMgr != null) {
      addrs = [...addrs, ...obsMgr.addrs(1)];
    }
    final seen = <String>{};
    final unique = <Multiaddr>[
      for (final a in addrs)
        if (seen.add(a.toString())) a,
    ];
    return unique.where(isPublicAddr).toList();
  }

  /// Retorna os endereços dialáveis combinando locais e relay addrs.
  /// Espelha `addrsManager.getDialableAddrs` (addrs_manager.go:457-474).
  List<Multiaddr> getDialableAddrs(
    List<Multiaddr> localAddrs,
    List<Multiaddr> relayAddrs,
  ) {
    return [...localAddrs, ...relayAddrs];
  }

  /// Aplica a fábrica de endereços (AddrsFactory) e certhashes.
  /// Espelha `addrsManager.applyAddrsFactory` (addrs_manager.go:476-484).
  List<Multiaddr> applyAddrsFactory(List<Multiaddr> addrs) {
    final configured = _addrsFactory(addrs);
    final withCerts = _addCertHashes(configured);

    final seen = <String>{};
    final unique = <Multiaddr>[];
    for (final a in withCerts) {
      if (seen.add(a.toString())) {
        unique.add(a);
      }
    }
    unique.sort((a, b) => a.toString().compareTo(b.toString()));
    return unique;
  }
}
