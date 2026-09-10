// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';

import '../../../core/event/bus.dart';
import '../../../core/event/reachability.dart';
import '../../../core/host/host.dart';
import '../../../core/network/network.dart';
import '../../../core/protocol/protocol.dart';

const ProtocolId autoNatProto = '/libp2p/autonat/1.0.0';

/// AutoNat contract for reachability detection.
abstract interface class AutoNat {
  Reachability status();
  Future<void> close();
}

/// A simple AutoNat implementation when a fixed reachability status is desired.
class StaticAutoNat implements AutoNat {
  StaticAutoNat({required this.reachability});

  final Reachability reachability;

  @override
  Reachability status() => reachability;

  @override
  Future<void> close() async {}
}

/// AmbientAutoNat determines NAT reachability based on inbound connections and observed addresses.
class AmbientAutoNat implements AutoNat {
  AmbientAutoNat({
    required this.host,
    Reachability initialReachability = Reachability.unknown,
  }) : _status = initialReachability;

  final Host host;
  Reachability _status;
  bool _closed = false;
  Emitter? _emitter;

  Future<Emitter> _getEmitter() async {
    return _emitter ??= await host.eventBus.emitter(EvtLocalReachabilityChanged);
  }

  @override
  Reachability status() => _status;

  /// Updates reachability and emits EvtLocalReachabilityChanged if changed.
  Future<void> setReachability(Reachability newStatus) async {
    if (_closed || _status == newStatus) return;
    _status = newStatus;
    try {
      final em = await _getEmitter();
      em.emit(EvtLocalReachabilityChanged(reachability: newStatus));
    } catch (_) {}
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _emitter?.close();
    _emitter = null;
  }
}
