// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of parallel.go. Dart Futures cannot be forcibly cancelled; cancelling a
// returned stream does cancel its child subscriptions.
import 'dart:async';
import 'dart:typed_data';

import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart'
    as core
    show getPublicKey;
import 'package:transpiled_libp2p_record/transpiled_libp2p_record.dart';

import 'bootstrap.dart';
import 'compose.dart';
import 'limited_value_store.dart';
import 'multi_error.dart';
import 'null_router.dart';
import 'tiered.dart';

/// Executes the legacy routing API against all applicable routers at once.
class Parallel implements Routing, PubKeyFetcher, Bootstrap {
  /// Creates a router that queries [routers] concurrently.
  const Parallel({this.routers = const [], this.validator});

  /// Routers queried by this instance.
  final List<Routing> routers;

  /// Chooses the freshest value returned by [searchValue].
  final Validator? validator;

  List<Routing> _filter(bool Function(Routing router) test) => [
    for (final router in routers)
      if (test(router)) router,
  ];

  Future<void> _put(
    Future<void> Function(Routing router) call,
    List<Routing> selected,
  ) async {
    if (selected.isEmpty) throw const RoutingNotSupportedException();
    final results = await Future.wait(
      selected.map((router) async {
        try {
          await call(router);
          return null;
        } catch (error) {
          return error;
        }
      }),
    );
    final errors = <Object>[];
    var success = false;
    for (final result in results) {
      if (result == null) {
        success = true;
      } else if (result is! RoutingNotSupportedException) {
        errors.add(result);
      }
    }
    final combined = combineErrors(errors);
    if (combined != null) throw combined;
    if (!success) throw const RoutingNotSupportedException();
  }

  Future<T> _get<T>(
    Future<T> Function(Routing router) call,
    List<Routing> selected,
  ) async {
    if (selected.isEmpty) throw const RoutingNotFoundException();
    final result = Completer<T>();
    var remaining = selected.length;
    final errors = <Object>[];
    for (final router in selected) {
      unawaited(
        call(router).then(
          (value) {
            if (!result.isCompleted) result.complete(value);
          },
          onError: (Object error, StackTrace trace) {
            if (error is! RoutingNotFoundException &&
                error is! RoutingNotSupportedException) {
              errors.add(error);
            }
            if (--remaining == 0 && !result.isCompleted) {
              final combined = combineErrors(errors);
              result.completeError(
                combined ?? const RoutingNotFoundException(),
              );
            }
          },
        ),
      );
    }
    return result.future;
  }

  @override
  Future<void> putValue(
    String key,
    Uint8List value, {
    List<RoutingOption> options = const [],
  }) => _withQueryEvents(
    () => _put(
      (router) => router.putValue(key, value, options: options),
      _filter((router) => _supportsKey(router, key)),
    ),
  );

  @override
  Future<Uint8List> getValue(
    String key, {
    List<RoutingOption> options = const [],
  }) => _withQueryEvents(
    () => _get(
      (router) => router.getValue(key, options: options),
      _filter((router) => _supportsKey(router, key)),
    ),
  );

  @override
  Stream<Uint8List> searchValue(
    String key, {
    List<RoutingOption> options = const [],
  }) {
    final selected = _filter((router) => _supportsKey(router, key));
    if (selected.isEmpty) return const Stream.empty();
    return _withQueryEventStream(
      () => _merge(
        selected.map((router) => router.searchValue(key, options: options)),
        onValue: (value, best) {
          if (best == null) return true;
          final selector = validator;
          if (selector == null) {
            throw StateError('Parallel.searchValue requires a validator');
          }
          try {
            return selector.select(key, [best, value]) == 1;
          } catch (_) {
            return false;
          }
        },
        distinct: true,
        finishWhenProductiveStreamCloses: true,
      ),
    );
  }

  @override
  Future<PubKey> getPublicKey(PeerId id) => _get(
    (router) => core.getPublicKey(router, id),
    _filter((router) => _supportsKey(router, keyForPublicKey(id))),
  );

  @override
  Future<AddrInfo> findPeer(PeerId id) => _withQueryEvents(
    () => _get((router) => router.findPeer(id), _filter(_supportsPeer)),
  );

  @override
  Future<void> provide(Cid cid, bool local) =>
      _put((router) => router.provide(cid, local), _filter(_supportsContent));

  @override
  Stream<AddrInfo> findProvidersAsync(Cid cid, int count) {
    final selected = _filter(_supportsContent);
    if (selected.isEmpty) return const Stream.empty();
    if (selected.length == 1) {
      return selected.single.findProvidersAsync(cid, count);
    }
    final seen = <PeerId>{};
    var left = count;
    return _withQueryEventStream(
      () => _merge(
        selected.map((router) => router.findProvidersAsync(cid, count)),
        onValue: (info, _) {
          if (!seen.add(info.id)) return false;
          return count <= 0 || left-- > 0;
        },
        stopWhen: () => count > 0 && left == 0,
      ),
    );
  }

  @override
  Future<void> bootstrap() async {
    final errors = <Object>[];
    for (final router in routers) {
      try {
        await router.bootstrap();
      } catch (error) {
        errors.add(error);
      }
    }
    final combined = combineErrors(errors);
    if (combined != null) throw combined;
  }

  /// Closes every nested router that implements [Closable].
  Future<void> close() async {
    final errors = <Object>[];
    for (final router in routers) {
      final Object candidate = router;
      if (candidate is Closable) {
        try {
          await candidate.close();
        } catch (error) {
          errors.add(error);
        }
      }
    }
    final combined = combineErrors(errors);
    if (combined != null) throw combined;
  }
}

/// Dart equivalent of Go's optional `io.Closer` assertion.
abstract class Closable {
  /// Releases resources held by the router.
  Future<void> close();
}

bool _supportsKey(ValueStore store, String key) {
  if (store is NullRouter) return false;
  if (store is Compose) {
    return store.valueStore != null && _supportsKey(store.valueStore!, key);
  }
  if (store is Parallel) {
    return store.routers.any((router) => _supportsKey(router, key));
  }
  if (store is Tiered) {
    return store.routers.any((router) => _supportsKey(router, key));
  }
  return store is! LimitedValueStore ||
      (store.keySupported(key) && _supportsKey(store.valueStore, key));
}

bool _supportsPeer(PeerRouting routing) =>
    routing is! NullRouter &&
    (routing is! Compose ||
        (routing.peerRouting != null && _supportsPeer(routing.peerRouting!))) &&
    (routing is! Parallel || routing.routers.any(_supportsPeer)) &&
    (routing is! Tiered || routing.routers.any(_supportsPeer));
bool _supportsContent(ContentRouting routing) =>
    routing is! NullRouter &&
    (routing is! Compose ||
        (routing.contentRouting != null &&
            _supportsContent(routing.contentRouting!))) &&
    (routing is! Parallel || routing.routers.any(_supportsContent)) &&
    (routing is! Tiered || routing.routers.any(_supportsContent));

Stream<T> _merge<T>(
  Iterable<Stream<T>> streams, {
  required bool Function(T value, T? best) onValue,
  bool distinct = false,
  bool Function()? stopWhen,
  bool finishWhenProductiveStreamCloses = false,
}) {
  late StreamController<T> controller;
  final subscriptions = <StreamSubscription<T>>[];
  T? best;
  var open = 0;
  var stopped = false;
  Future<void> finish() async {
    if (stopped) return;
    stopped = true;
    await Future.wait(
      subscriptions.map((subscription) => subscription.cancel()),
    );
    if (!controller.isClosed) await controller.close();
  }

  controller = StreamController<T>(
    onListen: () {
      for (final stream in streams) {
        open++;
        var produced = false;
        subscriptions.add(
          stream.listen(
            (value) {
              produced = true;
              if (stopped || !onValue(value, best)) return;
              if (distinct &&
                  best != null &&
                  value is Uint8List &&
                  value.isNotEmpty &&
                  _equalBytes(best!, value)) {
                return;
              }
              best = value;
              controller.add(value);
              if (stopWhen?.call() ?? false) unawaited(finish());
            },
            onError: controller.addError,
            onDone: () {
              open--;
              if ((finishWhenProductiveStreamCloses && produced) || open == 0) {
                unawaited(finish());
              }
            },
          ),
        );
      }
      if (open == 0) unawaited(finish());
    },
    onCancel: finish,
  );
  return controller.stream;
}

bool _equalBytes(Object? left, Object? right) =>
    left is Uint8List &&
    right is Uint8List &&
    left.length == right.length &&
    List.generate(
      left.length,
      (i) => left[i] == right[i],
    ).every((same) => same);

Future<T> _withQueryEvents<T>(Future<T> Function() body) async {
  if (!subscribesToQueryEvents()) return body();
  final outerZone = Zone.current;
  final registration = registerForQueryEvents();
  QueryEvent? lastError;
  var succeeded = false;
  final subscription = registration.events.listen((event) {
    if (event.type == queryError) {
      lastError = event;
    } else {
      succeeded = true;
      outerZone.run(() => publishQueryEvent(event));
    }
  });
  try {
    return await registration.run(body);
  } finally {
    await registration.close();
    await subscription.cancel();
    if (!succeeded && lastError != null) {
      outerZone.run(() => publishQueryEvent(lastError!));
    }
  }
}

Stream<T> _withQueryEventStream<T>(Stream<T> Function() body) {
  if (!subscribesToQueryEvents()) return body();

  final outerZone = Zone.current;
  final registration = registerForQueryEvents();
  QueryEvent? lastError;
  var succeeded = false;
  final eventsDone = Completer<void>();
  registration.events.listen((event) {
    if (event.type == queryError) {
      lastError = event;
    } else {
      succeeded = true;
      outerZone.run(() => publishQueryEvent(event));
    }
  }, onDone: eventsDone.complete);

  late StreamController<T> controller;
  StreamSubscription<T>? source;
  var closed = false;
  Future<void> finish() async {
    if (closed) return;
    closed = true;
    await source?.cancel();
    await registration.close();
    await eventsDone.future;
    if (!succeeded && lastError != null) {
      outerZone.run(() => publishQueryEvent(lastError!));
    }
    if (!controller.isClosed) await controller.close();
  }

  controller = StreamController<T>(
    onListen: () {
      source = registration.run(
        () => body().listen(
          controller.add,
          onError: controller.addError,
          onDone: () => unawaited(finish()),
        ),
      );
    },
    onCancel: finish,
  );
  return controller.stream;
}
