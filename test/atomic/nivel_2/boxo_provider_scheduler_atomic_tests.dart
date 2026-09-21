import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';
import 'package:transpiled_boxo/src/provider/provider.dart';
import 'package:transpiled_boxo/src/provider/reprovider.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_datastore/transpiled_datastore.dart';

class _SlowFirstProvide implements Provider {
  final first = Completer<void>();
  int calls = 0;
  @override
  Future<void> provide(Cid cid, bool announce) async {
    if (++calls == 1) await first.future;
  }
}

void main() {
  group('System [Atomic Audit]', () {
    test(
      'close() - cancels the 22-hour timer instead of keeping the isolate alive',
      () {
        fakeAsync((time) {
          final system = reproviderSystem(MapDatastore());
          time.flushMicrotasks();
          time.elapse(const Duration(minutes: 1));
          time.flushMicrotasks();
          expect(time.pendingTimers, isNotEmpty);
          var closed = false;
          system.close().then((_) => closed = true);
          time.flushMicrotasks();
          expect(closed, isTrue);
          expect(time.pendingTimers, isEmpty);
        });
      },
    );
    test(
      'reprovide() - consumes a pending periodic tick after a slow run',
      () async {
        final cid = await Cid.fromContent(Uint8List.fromList([1]));
        fakeAsync((time) {
          final provider = _SlowFirstProvide();
          final system = reproviderSystem(
            MapDatastore(),
            options: [
              online(provider),
              reproviderInterval(const Duration(seconds: 10)),
              keyProvider(() => Stream.value(cid)),
            ],
          );
          time.flushMicrotasks();
          time.elapse(Duration.zero);
          time.flushMicrotasks();
          expect(provider.calls, 1);
          time.elapse(const Duration(seconds: 15));
          provider.first.complete();
          time.flushMicrotasks();
          expect(provider.calls, 2);
          system.close();
          time.flushMicrotasks();
          expect(time.pendingTimers, isEmpty);
        });
      },
    );
  });
}
