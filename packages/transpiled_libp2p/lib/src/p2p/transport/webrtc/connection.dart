// SPDX-FileCopyrightText: 2023 The Go-Libp2p Authors
// SPDX-License-Identifier: MIT

// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:typed_data';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';
import 'package:transpiled_pion_datachannel/transpiled_pion_datachannel.dart'
    as pion_datachannel;
import 'package:transpiled_pion_sctp/transpiled_pion_sctp.dart' as pion_sctp;

import '../../../core/crypto/key_types.dart';
import '../../../core/network/network.dart';
import '../../../core/peer/peer_id.dart';
import '../../../core/transport/transport.dart';
import 'stream.dart';

/// ErrConnectionTimeout represents a timeout during WebRTC connection setup.
class ErrConnectionTimeout implements Exception {
  const ErrConnectionTimeout();

  String error() => 'connection timeout';
  Golang.Int64 timeout() => Golang.Int64(1);
  bool temporary() => false;

  @override
  String toString() => error();
}

/// Connection represents a WebRTC Direct CapableConn.
class Connection implements CapableConn {
  Connection({
    required this.direction,
    required this.association,
    required this.localPeerId,
    required this.localMaddr,
    required this.remotePeerId,
    required this.remotePubKey,
    required this.remoteMaddr,
    required this.transportInstance,
    this.connScope = const NullConnScope(),
  });

  final Direction direction;
  final pion_sctp.Association association;
  final PeerId localPeerId;
  final Multiaddr localMaddr;
  final PeerId remotePeerId;
  final PubKey remotePubKey;
  final Multiaddr remoteMaddr;
  final Transport transportInstance;
  final ConnScope connScope;

  bool _closed = false;
  int _nextStreamId = 1;
  final Map<int, Stream> _streams = {};
  final List<Stream> _incomingStreams = [];
  Completer<Stream>? _acceptWaiter;

  @override
  ConnState connState() => ConnState();

  @override
  bool isClosed() => _closed;

  @override
  PeerId localPeer() => localPeerId;

  @override
  PeerId remotePeer() => remotePeerId;

  @override
  PubKey remotePublicKey() => remotePubKey;

  @override
  Multiaddr localMultiaddr() => localMaddr;

  @override
  Multiaddr remoteMultiaddr() => remoteMaddr;

  @override
  ConnScope scope() => connScope;

  @override
  Transport transport() => transportInstance;

  dynamic as(Type targetType) {
    if (targetType == Connection) return this;
    return null;
  }

  Future<void> closeWithError(int err) async {
    await close();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final s in _streams.values) {
      await s.close();
    }
    _streams.clear();
    await association.close();
    final waiter = _acceptWaiter;
    _acceptWaiter = null;
    if (waiter != null && !waiter.isCompleted) {
      waiter.completeError(StateError('connection closed'));
    }
  }

  @override
  Future<MuxedStream> openStream() async {
    if (_closed) throw StateError('connection closed');
    final streamId = _nextStreamId;
    _nextStreamId += 2;

    final config = pion_datachannel.Config(
      label: 'stream-$streamId',
      negotiated: true,
    );
    final dc = await pion_datachannel.dial(association, streamId, config);
    final s = Stream(channel: dc, onDone: () => _streams.remove(streamId));
    _streams[streamId] = s;
    return s;
  }

  @override
  Future<MuxedStream> acceptStream() async {
    if (_closed) throw StateError('connection closed');
    if (_incomingStreams.isNotEmpty) {
      return _incomingStreams.removeAt(0);
    }
    _acceptWaiter = Completer<Stream>();
    return _acceptWaiter!.future;
  }

  void pushIncomingStream(Stream s) {
    if (_closed) return;
    final waiter = _acceptWaiter;
    _acceptWaiter = null;
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete(s);
    } else {
      _incomingStreams.add(s);
    }
  }
}
