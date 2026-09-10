import 'dart:async';
import 'dart:typed_data';

import 'package:synchronized/synchronized.dart';
import 'package:transpiled_block_format/transpiled_block_format.dart' as blocks;
import 'package:transpiled_boxo/bitswap/message.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';

import '../../blockstore/blockstore.dart';
import '../../network/libp2p_host.dart';
import 'bitswap_message.dart';
import 'interface_bitswap_handler.dart';

/// Bitswap protocol supported by the current Boxo client.
const String bitswapProtocol = '/ipfs/bitswap/1.2.0';

/// Minimal Boxo `BlockGetter` client for connected providers.
final class BitswapClient implements BlockGetter {
  /// Creates a client over [router] and [blockstore].
  BitswapClient({
    required this.router,
    required this.blockstore,
    required this.timeout,
  });

  /// Router used to connect to Bitswap providers.
  final Libp2pRouter router;

  /// Blockstore used to satisfy and persist block requests.
  final Blockstore blockstore;

  /// Maximum time allowed for each provider request.
  final Duration timeout;
  final List<AddrInfo> _providers = [];
  final Map<Cid, Completer<blocks.Block>> _pending = {};
  final Map<String, NetworkStream> _outbound = {};
  final Map<String, Lock> _senderLocks = {};

  /// Registers the inbound Bitswap stream handler.
  void start() {
    for (final proto in [
      bitswapProtocol,
      '/ipfs/bitswap/1.1.0',
      '/ipfs/bitswap/1.0.0',
      '/ipfs/bitswap',
    ]) {
      router.host.setStreamHandler(
        proto,
        (stream) => _handleIncoming(stream),
      );
    }
  }

  /// Connects and registers a provider for subsequent block requests.
  Future<void> connect(AddrInfo provider) async {
    await router.connect(provider);
    if (!_providers.contains(provider)) _providers.add(provider);
  }

  @override
  Future<blocks.Block> getBlock(Cid cid) async {
    if (await blockstore.has(cid)) return blockstore.get(cid);
    final existing = _pending[cid];
    if (existing != null) return existing.future;
    final completer = Completer<blocks.Block>();
    _pending[cid] = completer;
    Object? lastError;
    try {
      for (final provider in _providers) {
        try {
          await _sendWant(provider, cid);
          final block = await completer.future.timeout(timeout);
          await blockstore.put(block);
          return block;
        } catch (error) {
          lastError = error;
        }
      }
      throw StateError('Bitswap could not retrieve $cid: $lastError');
    } finally {
      _pending.remove(cid);
    }
  }

  Future<void> _sendWant(AddrInfo provider, Cid cid) async {
    final key = provider.id.toString();
    await (_senderLocks[key] ??= Lock()).synchronized(() async {
      Object? lastError;
      for (var attempt = 0; attempt < 3; attempt++) {
        var stream = _outbound[key];
        try {
          if (stream == null || stream.isClosed) {
            await router.connect(provider);
            stream = await router.host.newStream(
              provider.id,
              const [bitswapProtocol],
            );
            _outbound[key] = stream;
          }
          await stream.setWriteDeadline(DateTime.now().add(timeout));
          try {
            await stream.write(encodeWantBlock(cid));
          } finally {
            await stream.setDeadline(null);
          }
          return;
        } catch (error) {
          lastError = error;
          _outbound.remove(key);
          await stream?.reset();
          if (attempt < 2) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
        }
      }
      throw StateError('Bitswap sender failed after 3 attempts: $lastError');
    });
  }

  /// Closes persistent provider senders.
  Future<void> close() async {
    for (final entry in _senderLocks.entries) {
      await entry.value.synchronized(() async {
        await _outbound.remove(entry.key)?.reset();
      });
    }
    _senderLocks.clear();
  }

  Future<void> _handleIncoming(NetworkStream stream) async {
    try {
      while (!stream.isClosed) {
        final message = await readBitswapMessage(stream);
        var completed = false;
        for (final entry in _pending.entries.toList()) {
          try {
            final block = blockFromMessage(message, entry.key);
            if (block != null && !entry.value.isCompleted) {
              entry.value.complete(block);
              completed = true;
            }
          } catch (error, stackTrace) {
            if (!entry.value.isCompleted) {
              entry.value.completeError(error, stackTrace);
            }
          }
        }
        // Respond to remote peer wantlists (Bitswap Server / Seeding)
        final wants = message.wantlist();
        if (wants.isNotEmpty) {
          final response = BitSwapMessage(false);
          var hasResponse = false;
          for (final want in wants) {
            if (want.cancel) continue;
            if (await blockstore.has(want.cid)) {
              final block = await blockstore.get(want.cid);
              if (want.wantType == WantType.have) {
                response.addBlockPresence(want.cid, BlockPresenceType.have);
                hasResponse = true;
              } else {
                response.addBlock(block);
                hasResponse = true;
              }
            } else if (want.sendDontHave) {
              response.addBlockPresence(want.cid, BlockPresenceType.dontHave);
              hasResponse = true;
            }
          }
          if (hasResponse) {
            final responseBytes = encodeBitswapMessage(response);
            try {
              await stream.write(responseBytes);
            } catch (_) {}
            try {
              final conn = stream.conn();
              if (conn case final ConnSecurity sec) {
                final remotePeer = sec.remotePeer();
                await _sendResponseToPeer(remotePeer, responseBytes);
              }
            } catch (_) {}
          }
        }
        if (completed) return;
      }
    } catch (_) {
      // EOF, reset, or session shutdown cleanly ends inbound message loop.
    } finally {
      try {
        await stream.close();
      } catch (_) {}
    }
  }

  Future<void> _sendResponseToPeer(PeerId peer, Uint8List bytes) async {
    final key = peer.toString();
    await (_senderLocks[key] ??= Lock()).synchronized(() async {
      var stream = _outbound[key];
      if (stream == null || stream.isClosed) {
        stream = await router.host.newStream(
          peer,
          const [bitswapProtocol],
        );
        _outbound[key] = stream;
      }
      await stream.setWriteDeadline(DateTime.now().add(timeout));
      try {
        await stream.write(bytes);
      } finally {
        await stream.setDeadline(null);
      }
    });
  }
}
