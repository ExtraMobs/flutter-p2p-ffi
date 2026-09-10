// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of compconfig.go, compparallel.go, and compsequential.go.
import 'dart:async';
import 'dart:typed_data';

import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multihash/transpiled_multihash.dart';

import 'multi_error.dart';

/// Per-router controls for [ComposableParallel].
class ParallelRouter {
  /// Creates a router configuration. Zero [timeout] disables the timeout.
  const ParallelRouter({
    required this.router,
    this.timeout = Duration.zero,
    this.executeAfter = Duration.zero,
    this.doNotWaitForSearchValue = false,
    this.ignoreError = false,
  });

  /// Maximum execution time after [executeAfter].
  final Duration timeout;

  /// Router to invoke.
  final Routing router;

  /// Delay before invoking [router].
  final Duration executeAfter;

  /// Lets a successful search finish without waiting for this router.
  final bool doNotWaitForSearchValue;

  /// Whether failures from this router are ignored.
  final bool ignoreError;
}

/// Per-router controls for [ComposableSequential].
class SequentialRouter {
  /// Creates a router configuration. Zero [timeout] disables the timeout.
  const SequentialRouter({
    required this.router,
    this.timeout = Duration.zero,
    this.ignoreError = false,
  });

  /// Maximum execution time for each operation.
  final Duration timeout;

  /// Whether failures from this router are ignored.
  final bool ignoreError;

  /// Router to invoke.
  final Routing router;
}

/// Optional batched provider-announcement capability.
abstract class ProvideManyRouter {
  /// Announces raw CIDs built from [keys].
  Future<void> provideMany(List<DecodedMultihash> keys);
}

/// Optional readiness hook from compconfig.go.
abstract class ReadyAbleRouter {
  /// Whether this router is ready to serve requests.
  bool ready();
}

/// Exposes the routers nested by a composable router.
abstract class ComposableRouter {
  /// Returns the directly nested routers.
  List<Routing> routers();
}

Future<T> _run<T>(
  Future<T> Function() action,
  Duration delay,
  Duration timeout,
) async {
  if (delay != Duration.zero) await Future<void>.delayed(delay);
  final future = action();
  return timeout == Duration.zero ? future : future.timeout(timeout);
}

Future<void> _provideMany(Routing router, List<DecodedMultihash> keys) async {
  if (router case final ProvideManyRouter provider) {
    return provider.provideMany(keys);
  }
  for (final key in keys) {
    await router.provide(Cid.v1('raw', key), true);
  }
}

/// Configurable fan-out router. This is distinct from legacy [Parallel].
class ComposableParallel
    implements Routing, ComposableRouter, ProvideManyRouter, ReadyAbleRouter {
  /// Creates a router from per-router [_entries].
  const ComposableParallel(this._entries);

  final List<ParallelRouter> _entries;

  @override
  List<Routing> routers() =>
      _entries.map((entry) => entry.router).toList(growable: false);

  @override
  bool ready() => _entries.every(
    (entry) =>
        entry.router is! ReadyAbleRouter ||
        (entry.router as ReadyAbleRouter).ready(),
  );

  Future<void> _execute(Future<void> Function(Routing router) call) async {
    final results = await Future.wait(
      _entries.map((entry) async {
        try {
          await _run(
            () => call(entry.router),
            entry.executeAfter,
            entry.timeout,
          );
          return null;
        } catch (error) {
          return entry.ignoreError ? null : error;
        }
      }),
    );
    final error = combineErrors(results.whereType<Object>().toList());
    if (error != null) throw error;
  }

  Future<T> _first<T>(
    Future<T> Function(Routing router) call,
    bool Function(T value) isEmpty,
  ) async {
    if (_entries.isEmpty) throw const RoutingNotFoundException();
    final answer = Completer<T>();
    var remaining = _entries.length;
    void miss() {
      remaining--;
      if (remaining == 0 && !answer.isCompleted) {
        answer.completeError(const RoutingNotFoundException());
      }
    }

    for (final entry in _entries) {
      unawaited(
        _run(() => call(entry.router), entry.executeAfter, entry.timeout).then(
          (value) {
            if (isEmpty(value)) {
              miss();
            } else if (!answer.isCompleted) {
              answer.complete(value);
            }
          },
          onError: (Object error, StackTrace trace) {
            if (!entry.ignoreError && error is! RoutingNotFoundException) {
              if (!answer.isCompleted) answer.completeError(error, trace);
            } else {
              miss();
            }
          },
        ),
      );
    }
    return answer.future;
  }

  @override
  Future<void> provide(Cid cid, bool local) =>
      _execute((router) => router.provide(cid, local));

  @override
  Future<void> provideMany(List<DecodedMultihash> keys) =>
      _execute((router) => _provideMany(router, keys));

  @override
  Future<void> putValue(
    String key,
    Uint8List value, {
    List<RoutingOption> options = const [],
  }) => _execute((router) => router.putValue(key, value, options: options));

  @override
  Future<Uint8List> getValue(
    String key, {
    List<RoutingOption> options = const [],
  }) => _first(
    (router) => router.getValue(key, options: options),
    (value) => value.isEmpty,
  );

  @override
  Future<AddrInfo> findPeer(PeerId id) =>
      _first((router) => router.findPeer(id), (info) => info.id.value.isEmpty);

  @override
  Future<void> bootstrap() => _execute((router) => router.bootstrap());

  @override
  Stream<Uint8List> searchValue(
    String key, {
    List<RoutingOption> options = const [],
  }) => _parallelStreams(
    _entries,
    (router) => router.searchValue(key, options: options),
    isSearchValue: true,
  );

  @override
  Stream<AddrInfo> findProvidersAsync(Cid cid, int count) {
    var remaining = count;
    return _parallelStreams(
      _entries,
      (router) => router.findProvidersAsync(cid, count),
      accept: (_) => count <= 0 || remaining-- > 0,
      stop: () => count > 0 && remaining == 0,
    );
  }
}

/// Configurable ordered router.
class ComposableSequential
    implements Routing, ComposableRouter, ProvideManyRouter, ReadyAbleRouter {
  /// Creates an ordered router from per-router [_entries].
  const ComposableSequential(this._entries);

  final List<SequentialRouter> _entries;

  @override
  List<Routing> routers() =>
      _entries.map((entry) => entry.router).toList(growable: false);

  @override
  bool ready() => _entries.every(
    (entry) =>
        entry.router is! ReadyAbleRouter ||
        (entry.router as ReadyAbleRouter).ready(),
  );

  Future<T> _first<T>(
    Future<T> Function(Routing router) call,
    bool Function(T value) isEmpty,
  ) async {
    for (final entry in _entries) {
      try {
        final value = await _run(
          () => call(entry.router),
          Duration.zero,
          entry.timeout,
        );
        if (!isEmpty(value)) return value;
      } catch (error) {
        if (!entry.ignoreError && error is! RoutingNotFoundException) rethrow;
      }
    }
    throw const RoutingNotFoundException();
  }

  Future<void> _execute(Future<void> Function(Routing router) call) async {
    for (final entry in _entries) {
      try {
        await _run(() => call(entry.router), Duration.zero, entry.timeout);
      } catch (error) {
        if (!entry.ignoreError && error is! RoutingNotFoundException) rethrow;
      }
    }
  }

  @override
  Future<void> provide(Cid cid, bool local) =>
      _execute((router) => router.provide(cid, local));

  @override
  Future<void> provideMany(List<DecodedMultihash> keys) =>
      _execute((router) => _provideMany(router, keys));

  @override
  Future<void> putValue(
    String key,
    Uint8List value, {
    List<RoutingOption> options = const [],
  }) => _execute((router) => router.putValue(key, value, options: options));

  @override
  Future<Uint8List> getValue(
    String key, {
    List<RoutingOption> options = const [],
  }) => _first(
    (router) => router.getValue(key, options: options),
    (value) => value.isEmpty,
  );

  @override
  Future<AddrInfo> findPeer(PeerId id) =>
      _first((router) => router.findPeer(id), (info) => info.id.value.isEmpty);

  @override
  Future<void> bootstrap() => _execute((router) => router.bootstrap());

  @override
  Stream<Uint8List> searchValue(
    String key, {
    List<RoutingOption> options = const [],
  }) => _sequentialStreams(
    _entries,
    (router) => router.searchValue(key, options: options),
  );

  @override
  Stream<AddrInfo> findProvidersAsync(Cid cid, int count) => _sequentialStreams(
    _entries,
    (router) => router.findProvidersAsync(cid, count),
    count: count,
  );
}

Stream<T> _parallelStreams<T>(
  List<ParallelRouter> entries,
  Stream<T> Function(Routing) create, {
  bool Function(T value)? accept,
  bool Function()? stop,
  bool isSearchValue = false,
}) {
  late StreamController<T> controller;
  final subscriptions = <StreamSubscription<T>>{};
  final timers = <Timer>{};
  final errors = <Object>[];
  var active = entries.length;
  var blocking = entries
      .where((entry) => !isSearchValue || !entry.doNotWaitForSearchValue)
      .length;
  var sent = false;
  var closed = false;

  Future<void> finish({bool reportErrors = false}) async {
    if (closed) return;
    closed = true;
    for (final timer in timers) {
      timer.cancel();
    }
    await Future.wait(
      subscriptions.map((subscription) => subscription.cancel()),
    );
    if (reportErrors && !sent && isSearchValue) {
      final error = combineErrors(errors);
      if (error != null) controller.addError(error);
    }
    if (!controller.isClosed) await controller.close();
  }

  void start(ParallelRouter entry) {
    unawaited(() async {
      if (entry.executeAfter != Duration.zero) {
        await Future<void>.delayed(entry.executeAfter);
      }
      if (closed) return;

      StreamSubscription<T>? subscription;
      Timer? timer;
      var done = false;
      void complete([Object? error]) {
        if (done || closed) return;
        done = true;
        if (error != null && !entry.ignoreError) errors.add(error);
        timer?.cancel();
        if (subscription != null) subscriptions.remove(subscription);
        active--;
        if (!isSearchValue || !entry.doNotWaitForSearchValue) blocking--;
        if (active == 0) {
          unawaited(finish(reportErrors: true));
        } else if (sent && blocking == 0) {
          unawaited(finish());
        }
      }

      try {
        subscription = create(entry.router).listen(
          (value) {
            if (closed || !(accept?.call(value) ?? true)) return;
            sent = true;
            controller.add(value);
            if (stop?.call() ?? false) unawaited(finish());
          },
          onError: (Object error, StackTrace trace) {
            complete(error);
          },
          onDone: complete,
          cancelOnError: true,
        );
        final activeSubscription = subscription;
        if (done) {
          unawaited(activeSubscription.cancel());
        } else {
          subscriptions.add(activeSubscription);
          if (entry.timeout != Duration.zero) {
            timer = Timer(entry.timeout, () {
              unawaited(activeSubscription.cancel());
              complete();
            });
            timers.add(timer);
          }
        }
      } catch (error) {
        complete(error);
      }
    }());
  }

  controller = StreamController<T>(
    onListen: () {
      for (final entry in entries) {
        start(entry);
      }
      if (entries.isEmpty) unawaited(finish());
    },
    onCancel: finish,
  );
  return controller.stream;
}

Stream<T> _sequentialStreams<T>(
  List<SequentialRouter> entries,
  Stream<T> Function(Routing) create, {
  int count = 0,
}) async* {
  var remaining = count;
  for (final entry in entries) {
    StreamIterator<T>? iterator;
    final stopwatch = Stopwatch()..start();
    try {
      iterator = StreamIterator<T>(create(entry.router));
      while (true) {
        final timeLeft = entry.timeout - stopwatch.elapsed;
        if (entry.timeout != Duration.zero && timeLeft <= Duration.zero) break;
        final hasNext = entry.timeout == Duration.zero
            ? await iterator.moveNext()
            : await iterator.moveNext().timeout(
                timeLeft,
                onTimeout: () => false,
              );
        if (!hasNext) break;
        yield iterator.current;
        if (count > 0 && --remaining == 0) return;
      }
    } catch (error) {
      if (!entry.ignoreError && error is! RoutingNotFoundException) return;
    } finally {
      await iterator?.cancel();
    }
  }
}
