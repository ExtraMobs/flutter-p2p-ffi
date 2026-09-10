// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';

import '../../core/network/network.dart';
import '../../core/protocol/protocol.dart';

class _HandlerEntry {
  _HandlerEntry({
    required this.protocol,
    required this.handler,
    this.match,
  });

  final ProtocolId protocol;
  final HandlerFunc handler;
  final bool Function(ProtocolId)? match;

  bool matches(ProtocolId p) {
    if (match != null) return match!(p);
    return protocol == p;
  }
}

/// Standard implementation of [ProtocolSwitch].
class MultistreamMuxer implements ProtocolSwitch {
  MultistreamMuxer();

  final List<_HandlerEntry> _handlers = [];

  @override
  void addHandler(ProtocolId id, HandlerFunc handler) {
    removeHandler(id);
    _handlers.add(_HandlerEntry(protocol: id, handler: handler));
  }

  @override
  void addHandlerWithFunc(
    ProtocolId id,
    bool Function(ProtocolId) match,
    HandlerFunc handler,
  ) {
    removeHandler(id);
    _handlers.add(_HandlerEntry(protocol: id, handler: handler, match: match));
  }

  @override
  void removeHandler(ProtocolId id) {
    _handlers.removeWhere((entry) => entry.protocol == id);
  }

  @override
  List<ProtocolId> protocols() => [for (final h in _handlers) h.protocol];

  @override
  Future<(ProtocolId, HandlerFunc)> negotiate(Object stream) async {
    // If the stream already has a protocol selected (e.g. NetworkStream), use it.
    if (stream is NetworkStream) {
      final pid = stream.protocol();
      if (pid.isNotEmpty) {
        for (final entry in _handlers) {
          if (entry.matches(pid)) {
            return (pid, entry.handler);
          }
        }
      }
    }
    // Default fallback to first handler if available
    if (_handlers.isNotEmpty) {
      final first = _handlers.first;
      return (first.protocol, first.handler);
    }
    throw StateError('Protocol negotiation failed: no matching handlers');
  }

  @override
  Future<void> handle(Object stream) async {
    final (pid, handler) = await negotiate(stream);
    await handler(pid, stream);
  }
}
