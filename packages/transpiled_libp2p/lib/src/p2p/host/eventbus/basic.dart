// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';

import '../../../core/event/bus.dart';

class _BasicEmitter implements Emitter {
  _BasicEmitter(this._bus, this._eventType);
  final BasicBus _bus;
  final Object _eventType;
  bool _closed = false;

  @override
  Future<void> emit(Object event) async {
    if (_closed) throw StateError('Emitter is closed');
    if (_eventType is Type && event.runtimeType != _eventType) {
      throw ArgumentError('Event type ${event.runtimeType} does not match emitter type $_eventType');
    }
    _bus._emit(event);
  }

  @override
  Future<void> close() async {
    _closed = true;
  }
}

class _BasicSubscription implements Subscription {
  _BasicSubscription(this._controller, this._name, this._onClose);
  final StreamController<Object> _controller;
  final String _name;
  final void Function() _onClose;
  bool _closed = false;

  @override
  Stream<Object> out() => _controller.stream;

  @override
  String name() => _name;

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _onClose();
    await _controller.close();
  }
}

/// BasicBus is a type-based event delivery system implementing libp2p's Bus.
class BasicBus implements Bus {
  BasicBus();

  final Map<String, StreamController<Object>> _topics = {};
  final StreamController<Object> _wildcard = StreamController<Object>.broadcast();
  final Set<Type> _knownTypes = {};

  void _emit(Object event) {
    _knownTypes.add(event.runtimeType);
    final key = event.runtimeType.toString();
    final topic = _topics[key];
    if (topic != null && !topic.isClosed) {
      topic.add(event);
    }
    if (!_wildcard.isClosed) {
      _wildcard.add(event);
    }
  }

  @override
  Subscription subscribe(Object eventType, {List<SubscriptionOpt> opts = const []}) {
    if (identical(eventType, wildcardSubscription)) {
      final controller = StreamController<Object>.broadcast();
      final sub = _wildcard.stream.listen((event) {
        if (!controller.isClosed) controller.add(event);
      });
      return _BasicSubscription(controller, 'wildcard', () => sub.cancel());
    }

    final key = eventType is Type ? eventType.toString() : eventType.toString();
    if (eventType is Type) {
      _knownTypes.add(eventType);
    }

    final topic = _topics.putIfAbsent(key, () => StreamController<Object>.broadcast());
    final controller = StreamController<Object>.broadcast();
    final sub = topic.stream.listen((event) {
      if (!controller.isClosed) controller.add(event);
    });
    return _BasicSubscription(controller, key, () => sub.cancel());
  }

  @override
  Future<Emitter> emitter(Object eventType, {List<EmitterOpt> opts = const []}) async {
    if (identical(eventType, wildcardSubscription)) {
      throw ArgumentError('Cannot create emitter for wildcard subscription');
    }
    if (eventType is Type) {
      _knownTypes.add(eventType);
    }
    return _BasicEmitter(this, eventType);
  }

  @override
  List<Type> getAllEventTypes() => _knownTypes.toList();
}
