// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';

typedef SubscriptionOpt = void Function(Object);
typedef EmitterOpt = void Function(Object);
typedef CancelFunc = void Function();

final Object wildcardSubscription = Object();

abstract interface class Emitter {
  Future<void> emit(Object event);
  Future<void> close();
}

abstract interface class Subscription {
  Stream<Object> out();
  String name();
  Future<void> close();
}

abstract interface class Bus {
  Subscription subscribe(Object eventType, {List<SubscriptionOpt> opts = const []});
  Future<Emitter> emitter(Object eventType, {List<EmitterOpt> opts = const []});
  List<Type> getAllEventTypes();
}
