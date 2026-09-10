import 'dart:async';

import 'package:transpiled_block_format/transpiled_block_format.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';

/// PubSub is a simple interface for publishing blocks and being able to subscribe
/// for cids. It's used internally by bitswap to decouple receiving blocks
/// and actually providing them back to the GetBlocks caller.
abstract class PubSub {
  void publish(PeerId from, List<Block> blocks);
  Stream<Block> subscribe(List<Cid> keys);
  void shutdown();
}

/// NotificationsPubSub implements PubSub.
class NotificationsPubSub implements PubSub {
  NotificationsPubSub({bool traceBlock = false}) {
    // traceBlock is kept for API compatibility, but traceability is omitted as per scope.
  }

  bool _closed = false;
  
  final Map<String, List<StreamController<Block>>> _listeners = {};

  @override
  void publish(PeerId from, List<Block> blocks) {
    if (_closed) return;
    
    for (final block in blocks) {
      final key = block.cid().encode();
      final subs = _listeners[key];
      if (subs != null) {
        // Iterate over a copy to allow safe removal during iteration
        for (final sub in subs.toList()) {
          if (!sub.isClosed) {
            sub.add(block);
          }
        }
      }
    }
  }

  @override
  Stream<Block> subscribe(List<Cid> keys) {
    if (keys.isEmpty) {
      return const Stream.empty();
    }
    
    if (_closed) {
      return const Stream.empty();
    }

    final controller = StreamController<Block>();
    final remaining = keys.map((k) => k.encode()).toSet();
    
    void cleanup() {
      for (final key in keys) {
        final keyStr = key.encode();
        final subs = _listeners[keyStr];
        if (subs != null) {
          subs.remove(controller);
          if (subs.isEmpty) {
            _listeners.remove(keyStr);
          }
        }
      }
    }

    controller.onCancel = cleanup;
    
    for (final key in keys) {
      final keyStr = key.encode();
      _listeners.putIfAbsent(keyStr, () => []).add(controller);
    }
    
    final actualController = StreamController<Block>();
    actualController.onCancel = cleanup;
    
    StreamSubscription<Block>? sub;
    sub = controller.stream.listen((block) {
      final keyStr = block.cid().encode();
      if (remaining.contains(keyStr)) {
        remaining.remove(keyStr);
        
        final subs = _listeners[keyStr];
        if (subs != null) {
          subs.remove(controller);
          if (subs.isEmpty) {
            _listeners.remove(keyStr);
          }
        }
        
        actualController.add(block);
        
        if (remaining.isEmpty) {
          sub?.cancel();
          if (!controller.isClosed) controller.close();
          if (!actualController.isClosed) actualController.close();
        }
      }
    }, onDone: () {
      if (!actualController.isClosed) actualController.close();
    });

    return actualController.stream;
  }

  @override
  void shutdown() {
    if (_closed) return;
    _closed = true;
    for (final subs in _listeners.values) {
      for (final sub in subs) {
        if (!sub.isClosed) {
          sub.close();
        }
      }
    }
    _listeners.clear();
  }
}
