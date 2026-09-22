// test/atomic/nivel_2/libp2p_connmgr_atomic_tests.dart
//
// Testes atômicos 1 para 1 para o porte de go-libp2p/p2p/net/connmgr:
// BasicConnMgr, CmInfo, DecayerCfg e as options.
//
// Nível 2: tudo em memória, com o relógio do transpiled_clock dirigindo grace
// period, silence period e o tique de decaimento, para que nenhuma asserção
// dependa de tempo de parede.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_clock/transpiled_clock.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

/// Epoch do `Mock`, que nasce em `time.Unix(0, 0)`.
final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

/// Peers distintos e baratos. O último byte decide o shard em `_Segments.get`,
/// então variá-lo garante que os 256 buckets sejam de fato exercitados.
PeerId _peer(int i) => PeerId(value: Uint8List.fromList([0x12, 0x20, i]));

/// Conexão de teste que registra como foi fechada.
class _TestConn implements Conn {
  _TestConn(
    this._remote, {
    this.direction = Direction.outbound,
    this.numStreams = 0,
    int port = 4001,
  }) : _addr = Multiaddr.parse('/ip4/127.0.0.1/tcp/$port');

  final PeerId _remote;
  final Multiaddr _addr;
  final Direction direction;
  final int numStreams;

  bool closed = false;
  ConnErrorCode? closedWith;

  @override
  PeerId remotePeer() => _remote;

  @override
  Multiaddr remoteMultiaddr() => _addr;

  @override
  ConnStats stat() =>
      ConnStats(direction: direction, opened: _epoch, numStreams: numStreams);

  @override
  bool get isClosed => closed;

  @override
  Future<void> close() async {
    closed = true;
  }

  @override
  Future<void> closeWithError(ConnErrorCode errorCode) async {
    closed = true;
    closedWith = errorCode;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Limiter implements GetConnLimiter {
  _Limiter(this._limit);
  final int _limit;

  @override
  int getConnLimit() => _limit;
}

/// Um manager com relógio de mock nos dois lugares que o upstream mantém
/// independentes, e silence period longo o bastante para que o laço de fundo
/// não dispare no meio de um teste que avança o relógio.
({BasicConnMgr cm, Mock clock}) _managerWith({
  int low = 2,
  int hi = 4,
  Duration gracePeriod = const Duration(minutes: 1),
  Duration silencePeriod = const Duration(hours: 1),
  Duration resolution = const Duration(minutes: 1),
}) {
  final clock = Mock();
  final cm = BasicConnMgr(low, hi, [
    withClock(clock),
    withGracePeriod(gracePeriod),
    withSilencePeriod(silencePeriod),
    decayerConfig(DecayerCfg(resolution: resolution, clock: clock)),
  ]);
  return (cm: cm, clock: clock);
}

/// Registra [conns] no manager pelo notifee, como a rede faria.
void _connectAll(BasicConnMgr cm, List<_TestConn> conns) {
  final n = cm.notifiee();
  for (final c in conns) {
    n.connected(_nullNetwork, c);
  }
}

/// O notifee do connmgr ignora o `Network` que recebe (`connmgr.go:665`), então
/// nenhum objeto de rede precisa existir para exercitá-lo.
final Network _nullNetwork = _UnusedNetwork();

class _UnusedNetwork implements Network {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('BasicConnMgr [Atomic Audit]', () {
    test('tagPeer() - soma o valor da tag no total do peer', () {
      final (:cm, :clock) = _managerWith();
      final p = _peer(1);

      cm.tagPeer(p, 'useful', 10);
      expect(cm.getTagInfo(p)!.value, equals(10));
      expect(cm.getTagInfo(p)!.tags['useful'], equals(10));

      cm.close();
    });

    test('tagPeer() - substitui o valor anterior em vez de acumular', () {
      final (:cm, :clock) = _managerWith();
      final p = _peer(2);

      cm.tagPeer(p, 'useful', 10);
      cm.tagPeer(p, 'useful', 3);
      expect(cm.getTagInfo(p)!.value, equals(3));

      cm.close();
    });

    test('untagPeer() - desconta a tag do total e a remove', () {
      final (:cm, :clock) = _managerWith();
      final p = _peer(3);

      cm.tagPeer(p, 'a', 5);
      cm.tagPeer(p, 'b', 7);
      cm.untagPeer(p, 'a');

      final info = cm.getTagInfo(p)!;
      expect(info.value, equals(7));
      expect(info.tags.containsKey('a'), isFalse);

      cm.close();
    });

    test('untagPeer() - peer desconhecido é ignorado sem lançar', () {
      final (:cm, :clock) = _managerWith();
      expect(() => cm.untagPeer(_peer(4), 'a'), returnsNormally);
      expect(cm.getTagInfo(_peer(4)), isNull);
      cm.close();
    });

    test('upsertTag() - recebe o valor atual e grava o retornado', () {
      final (:cm, :clock) = _managerWith();
      final p = _peer(5);

      cm.upsertTag(p, 'score', (v) => v + 1);
      expect(cm.getTagInfo(p)!.value, equals(1));
      cm.upsertTag(p, 'score', (v) => v + 4);
      expect(cm.getTagInfo(p)!.value, equals(5));

      cm.close();
    });

    test('getTagInfo() - devolve null para peer desconhecido', () {
      final (:cm, :clock) = _managerWith();
      expect(cm.getTagInfo(_peer(6)), isNull);
      cm.close();
    });

    test('getTagInfo() - chaveia as conexões pelo multiaddr remoto', () {
      final (:cm, :clock) = _managerWith();
      final p = _peer(7);
      final conn = _TestConn(p, port: 4321);
      _connectAll(cm, [conn]);

      final info = cm.getTagInfo(p)!;
      expect(info.conns.keys, equals(['/ip4/127.0.0.1/tcp/4321']));
      expect(info.firstSeen, equals(_epoch));

      cm.close();
    });

    test('protect() - impede a poda do peer protegido', () async {
      final (:cm, :clock) = _managerWith(low: 2, hi: 4);
      final conns = [for (var i = 10; i < 15; i++) _TestConn(_peer(i))];
      _connectAll(cm, conns);
      cm.protect(_peer(10), 'peering');

      await clock.add(const Duration(minutes: 2));
      await cm.trimOpenConns();

      expect(conns.first.closed, isFalse);
      expect(conns.where((c) => c.closed), isNotEmpty);

      cm.close();
    });

    test('protect() - não é refcontado: duas marcações, um unprotect', () {
      final (:cm, :clock) = _managerWith();
      final p = _peer(16);
      cm.protect(p, 'x');
      cm.protect(p, 'x');
      expect(cm.unprotect(p, 'x'), isFalse);
      expect(cm.isProtected(p, 'x'), isFalse);
      cm.close();
    });

    test('unprotect() - devolve true enquanto outra tag ainda protege', () {
      final (:cm, :clock) = _managerWith();
      final p = _peer(17);
      cm.protect(p, 'a');
      cm.protect(p, 'b');
      expect(cm.unprotect(p, 'a'), isTrue);
      expect(cm.isProtected(p, 'b'), isTrue);
      cm.close();
    });

    test('unprotect() - devolve false para peer nunca protegido', () {
      final (:cm, :clock) = _managerWith();
      expect(cm.unprotect(_peer(18), 'a'), isFalse);
      cm.close();
    });

    test('isProtected() - tag vazia pergunta por qualquer proteção', () {
      final (:cm, :clock) = _managerWith();
      final p = _peer(19);
      expect(cm.isProtected(p, ''), isFalse);
      cm.protect(p, 'qualquer');
      expect(cm.isProtected(p, ''), isTrue);
      expect(cm.isProtected(p, 'outra'), isFalse);
      cm.close();
    });

    test('checkLimit() - aceita um limite de sistema acima do high water', () {
      final (:cm, :clock) = _managerWith(low: 2, hi: 4);
      expect(() => cm.checkLimit(_Limiter(100)), returnsNormally);
      cm.close();
    });

    test('checkLimit() - lança quando o high water excede o limite', () {
      final (:cm, :clock) = _managerWith(low: 2, hi: 400);
      expect(
        () => cm.checkLimit(_Limiter(100)),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('conn manager high watermark limit: 400'),
          ),
        ),
      );
      cm.close();
    });

    test('trimOpenConns() - poda até o low water e fecha com '
        'connGarbageCollected', () async {
      final (:cm, :clock) = _managerWith(low: 2, hi: 4);
      final conns = [for (var i = 20; i < 25; i++) _TestConn(_peer(i))];
      _connectAll(cm, conns);
      expect(cm.getInfo().connCount, equals(5));

      await clock.add(const Duration(minutes: 2));
      await cm.trimOpenConns();

      final closed = conns.where((c) => c.closed).toList();
      expect(closed, hasLength(3));
      expect(closed.first.closedWith, equals(connGarbageCollected));

      cm.close();
    });

    test('trimOpenConns() - não poda nada enquanto todos estão no grace '
        'period', () async {
      final (:cm, :clock) = _managerWith(low: 2, hi: 4);
      final conns = [for (var i = 30; i < 35; i++) _TestConn(_peer(i))];
      _connectAll(cm, conns);

      await cm.trimOpenConns();

      expect(conns.every((c) => !c.closed), isTrue);
      cm.close();
    });

    test('trimOpenConns() - aborta quando ha candidatos de menos fora do '
        'grace period', () async {
      final (:cm, :clock) = _managerWith(low: 3, hi: 4);
      final conns = [for (var i = 40; i < 45; i++) _TestConn(_peer(i))];
      _connectAll(cm, conns);
      // Tres dos cinco protegidos deixam so dois candidatos, abaixo do low
      // water: podar agora mataria conexoes potencialmente uteis.
      for (var i = 40; i < 43; i++) {
        cm.protect(_peer(i), 'peering');
      }

      await clock.add(const Duration(minutes: 2));
      await cm.trimOpenConns();

      expect(conns.every((c) => !c.closed), isTrue);
      cm.close();
    });

    test(
      'trimOpenConns() - desabilitado quando low ou high water e zero',
      () async {
        final clock = Mock();
        final cm = BasicConnMgr(0, 0, [
          withClock(clock),
          decayerConfig(
            DecayerCfg(resolution: const Duration(minutes: 1), clock: clock),
          ),
        ]);
        final conns = [for (var i = 50; i < 55; i++) _TestConn(_peer(i))];
        _connectAll(cm, conns);

        await clock.add(const Duration(minutes: 5));
        await cm.trimOpenConns();

        expect(conns.every((c) => !c.closed), isTrue);
        cm.close();
      },
    );

    test(
      'trimOpenConns() - chamadas concorrentes coalescem em um unico trim',
      () async {
        final (:cm, :clock) = _managerWith(low: 2, hi: 4);
        _connectAll(cm, [for (var i = 60; i < 65; i++) _TestConn(_peer(i))]);
        await clock.add(const Duration(minutes: 2));

        final first = cm.trimOpenConns();
        final second = cm.trimOpenConns();
        expect(identical(first, second), isTrue);
        await first;

        cm.close();
      },
    );

    test('forceTrim() - ignora o grace period', () async {
      final (:cm, :clock) = _managerWith(low: 2, hi: 4);
      final conns = [for (var i = 70; i < 75; i++) _TestConn(_peer(i))];
      _connectAll(cm, conns);

      // Nenhum avanço de relógio: todos ainda dentro do grace period.
      await cm.forceTrim();

      expect(conns.where((c) => c.closed), isNotEmpty);
      cm.close();
    });

    test(
      'forceTrim() - nao faz nada com menos conexoes que o low water',
      () async {
        final (:cm, :clock) = _managerWith(low: 5, hi: 8);
        final conns = [for (var i = 80; i < 82; i++) _TestConn(_peer(i))];
        _connectAll(cm, conns);

        await cm.forceTrim();

        expect(conns.every((c) => !c.closed), isTrue);
        cm.close();
      },
    );

    test('getInfo() - reporta os watermarks, o grace period e a contagem', () {
      final (:cm, :clock) = _managerWith(low: 2, hi: 4);
      _connectAll(cm, [_TestConn(_peer(90)), _TestConn(_peer(91))]);

      final info = cm.getInfo();
      expect(info.lowWater, equals(2));
      expect(info.highWater, equals(4));
      expect(info.gracePeriod, equals(const Duration(minutes: 1)));
      expect(info.connCount, equals(2));
      expect(info.lastTrim, equals(_epoch));

      cm.close();
    });

    test('notifiee() - connected passa a rastrear a conexao', () {
      final (:cm, :clock) = _managerWith();
      final conn = _TestConn(_peer(100));
      cm.notifiee().connected(_nullNetwork, conn);

      expect(cm.getInfo().connCount, equals(1));
      expect(cm.getTagInfo(_peer(100)), isNotNull);

      cm.close();
    });

    test('notifiee() - connected reinicia o grace period de uma entrada '
        'temporaria criada por tag precoce', () async {
      final (:cm, :clock) = _managerWith();
      final p = _peer(101);

      cm.tagPeer(p, 'early', 1);
      expect(cm.getTagInfo(p)!.firstSeen, equals(_epoch));

      await clock.add(const Duration(minutes: 5));
      cm.notifiee().connected(_nullNetwork, _TestConn(p));

      expect(
        cm.getTagInfo(p)!.firstSeen,
        equals(_epoch.add(const Duration(minutes: 5))),
      );

      cm.close();
    });

    test(
      'notifiee() - uma segunda notificacao da mesma conexao e ignorada',
      () {
        final (:cm, :clock) = _managerWith();
        final conn = _TestConn(_peer(102));
        cm.notifiee()
          ..connected(_nullNetwork, conn)
          ..connected(_nullNetwork, conn);

        expect(cm.getInfo().connCount, equals(1));
        cm.close();
      },
    );

    test('notifiee() - disconnected apaga o peer na ultima conexao, perdendo '
        'as tags', () {
      final (:cm, :clock) = _managerWith();
      final p = _peer(103);
      final conn = _TestConn(p);
      final n = cm.notifiee()..connected(_nullNetwork, conn);
      cm.tagPeer(p, 'useful', 9);

      n.disconnected(_nullNetwork, conn);

      expect(cm.getInfo().connCount, equals(0));
      expect(cm.getTagInfo(p), isNull);

      cm.close();
    });

    test('notifiee() - disconnected de conexao nao rastreada nao altera a '
        'contagem', () {
      final (:cm, :clock) = _managerWith();
      final tracked = _TestConn(_peer(104));
      final n = cm.notifiee()..connected(_nullNetwork, tracked);

      n.disconnected(_nullNetwork, _TestConn(_peer(105)));

      expect(cm.getInfo().connCount, equals(1));
      cm.close();
    });

    test('notifiee() - listen e listenClose sao no-op', () {
      final (:cm, :clock) = _managerWith();
      final n = cm.notifiee();
      final addr = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');
      expect(() => n.listen(_nullNetwork, addr), returnsNormally);
      expect(() => n.listenClose(_nullNetwork, addr), returnsNormally);
      expect(cm.getInfo().connCount, equals(0));
      cm.close();
    });

    test('registerDecayingTag() - a tag decai no tique e o total do peer '
        'acompanha', () async {
      final (:cm, :clock) = _managerWith(
        resolution: const Duration(minutes: 1),
      );
      final p = _peer(110);

      final tag = cm.registerDecayingTag(
        'score',
        const Duration(minutes: 1),
        (value) => (after: value.value - 1, remove: false),
        (value, delta) => value.value + delta,
      );
      tag.bump(p, 3);
      expect(cm.getTagInfo(p)!.value, equals(3));

      await clock.add(const Duration(minutes: 1));
      expect(cm.getTagInfo(p)!.value, equals(2));

      cm.close();
    });

    test('registerDecayingTag() - remove a tag quando decayFn pede', () async {
      final (:cm, :clock) = _managerWith();
      final p = _peer(111);

      final tag = cm.registerDecayingTag(
        'ephemeral',
        const Duration(minutes: 1),
        (value) => (after: 0, remove: true),
        (value, delta) => value.value + delta,
      );
      tag.bump(p, 5);
      expect(cm.getTagInfo(p)!.value, equals(5));

      await clock.add(const Duration(minutes: 1));
      expect(cm.getTagInfo(p)!.value, equals(0));
      expect(cm.getTagInfo(p)!.tags.containsKey('ephemeral'), isFalse);

      cm.close();
    });

    test('registerDecayingTag() - lanca quando o nome ja existe', () {
      final (:cm, :clock) = _managerWith();
      cm.registerDecayingTag(
        'dup',
        const Duration(minutes: 1),
        (v) => (after: v.value, remove: false),
        (v, d) => v.value + d,
      );
      expect(
        () => cm.registerDecayingTag(
          'dup',
          const Duration(minutes: 1),
          (v) => (after: v.value, remove: false),
          (v, d) => v.value + d,
        ),
        throwsA(isA<ArgumentError>()),
      );
      cm.close();
    });

    test('registerDecayingTag() - intervalo menor que a resolucao e elevado '
        'a ela', () {
      final (:cm, :clock) = _managerWith(
        resolution: const Duration(minutes: 1),
      );
      final tag = cm.registerDecayingTag(
        'clamped',
        const Duration(seconds: 5),
        (v) => (after: v.value, remove: false),
        (v, d) => v.value + d,
      );
      expect(tag.interval(), equals(const Duration(minutes: 1)));
      cm.close();
    });

    test('close() - e idempotente e para o laco de fundo', () async {
      final (:cm, :clock) = _managerWith(
        low: 2,
        hi: 4,
        silencePeriod: const Duration(seconds: 10),
      );
      final conns = [for (var i = 120; i < 125; i++) _TestConn(_peer(i))];
      _connectAll(cm, conns);

      cm.close();
      cm.close();

      // Com o laco parado, avancar o relogio nao poda nada.
      await clock.add(const Duration(minutes: 10));
      expect(conns.every((c) => !c.closed), isTrue);
    });
  });

  group('CmInfo [Atomic Audit]', () {
    test('CmInfo() - carrega a configuracao e o estado informados', () {
      final info = CmInfo(
        lowWater: 32,
        highWater: 96,
        lastTrim: _epoch,
        gracePeriod: const Duration(seconds: 20),
        connCount: 41,
      );
      expect(info.lowWater, equals(32));
      expect(info.highWater, equals(96));
      expect(info.lastTrim, equals(_epoch));
      expect(info.gracePeriod, equals(const Duration(seconds: 20)));
      expect(info.connCount, equals(41));
    });
  });

  group('DecayerCfg [Atomic Audit]', () {
    test('withDefaults() - grava a resolucao padrao e devolve a si mesma', () {
      final cfg = DecayerCfg();
      final returned = cfg.withDefaults();
      expect(identical(returned, cfg), isTrue);
      expect(cfg.resolution, equals(defaultResolution));
      expect(defaultResolution, equals(const Duration(minutes: 1)));
    });
  });

  group('Top-Level Functions [Atomic Audit]', () {
    test(
      'withGracePeriod() - configura o grace period reportado por getInfo',
      () {
        final clock = Mock();
        final cm = BasicConnMgr(2, 4, [
          withClock(clock),
          withGracePeriod(const Duration(seconds: 20)),
          decayerConfig(
            DecayerCfg(resolution: const Duration(minutes: 1), clock: clock),
          ),
        ]);
        expect(cm.getInfo().gracePeriod, equals(const Duration(seconds: 20)));
        cm.close();
      },
    );

    test('withGracePeriod() - lanca para periodo negativo', () {
      expect(
        () =>
            BasicConnMgr(2, 4, [withGracePeriod(const Duration(seconds: -1))]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('withSilencePeriod() - lanca para periodo nao positivo', () {
      expect(
        () => BasicConnMgr(2, 4, [withSilencePeriod(Duration.zero)]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('withClock() - o relogio injetado passa a datar os peers', () {
      final clock = Mock();
      final cm = BasicConnMgr(2, 4, [
        withClock(clock),
        decayerConfig(
          DecayerCfg(resolution: const Duration(minutes: 1), clock: clock),
        ),
      ]);
      cm.notifiee().connected(_nullNetwork, _TestConn(_peer(130)));
      expect(cm.getTagInfo(_peer(130))!.firstSeen, equals(_epoch));
      cm.close();
    });

    test('decayerConfig() - a resolucao configurada governa o clamp do '
        'intervalo', () {
      final clock = Mock();
      final cm = BasicConnMgr(2, 4, [
        withClock(clock),
        decayerConfig(
          DecayerCfg(resolution: const Duration(minutes: 5), clock: clock),
        ),
      ]);
      final tag = cm.registerDecayingTag(
        'x',
        const Duration(minutes: 1),
        (v) => (after: v.value, remove: false),
        (v, d) => v.value + d,
      );
      expect(tag.interval(), equals(const Duration(minutes: 5)));
      cm.close();
    });

    test('decayerConfig() - resolucao nao positiva lanca em vez de girar um '
        'Timer.periodic quente', () {
      expect(
        () => BasicConnMgr(2, 4, [decayerConfig(DecayerCfg())]),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
