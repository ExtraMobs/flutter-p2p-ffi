import 'dart:async';
import 'dart:collection';

import 'package:transpiled_libp2p/transpiled_libp2p.dart';

abstract interface class ConnectionListener {
  void peerConnected(PeerId peer);
  void peerDisconnected(PeerId peer);
}

enum State {
  disconnected,
  responsive,
  unresponsive,
}

class _PeerState {
  State newState = State.disconnected;
  State curState = State.disconnected;
  bool pending = false;
}

class ConnectEventManager {
  List<ConnectionListener> _connListeners;
  final Map<PeerId, _PeerState> _peers = {};

  bool _workerStarted = false;
  final ListQueue<PeerId> _changeQueue = ListQueue();
  bool _stop = false;

  int get changeQueueLength => _changeQueue.length;
  bool get hasPeers => _peers.isNotEmpty;
  bool get hasPendingPeers => _peers.values.any((s) => s.pending);

  Completer<void>? _waiter;
  final Completer<void> _done = Completer<void>();

  ConnectEventManager([List<ConnectionListener>? connListeners])
      : _connListeners = connListeners ?? [];

  void setListeners(List<ConnectionListener> connListeners) {
    if (!_workerStarted) {
      _connListeners = connListeners;
    }
  }

  void start() {
    if (!_workerStarted) {
      _workerStarted = true;
      // Inicia em background
      unawaited(_worker());
    }
  }

  Future<void> stop() async {
    _stop = true;
    _notifyWaiters();
    await _done.future;
  }

  void _notifyWaiters() {
    if (_waiter != null && !_waiter!.isCompleted) {
      _waiter!.complete();
    }
  }

  State _getState(PeerId p) {
    return _peers[p]?.newState ?? State.disconnected;
  }

  void _setState(PeerId p, State newState) {
    var state = _peers[p];
    if (state == null) {
      state = _PeerState();
      _peers[p] = state;
    }
    state.newState = newState;
    if (!state.pending && state.newState != state.curState) {
      state.pending = true;
      _changeQueue.addLast(p);
      _notifyWaiters();
    }
  }

  Future<bool> _waitChange() async {
    while (!_stop && _changeQueue.isEmpty) {
      _waiter = Completer<void>();
      await _waiter!.future;
    }
    return !_stop;
  }

  Future<void> _worker() async {
    try {
      while (await _waitChange()) {
        final pid = _changeQueue.removeFirst();

        final state = _peers[pid];
        if (state == null) {
          continue;
        }

        state.pending = false;

        if (state.curState == state.newState) {
          continue;
        }

        final oldState = state.curState;
        state.curState = state.newState;

        switch (state.newState) {
          case State.disconnected:
            _peers.remove(pid);
            if (oldState == State.responsive) {
              for (final v in _connListeners) {
                v.peerDisconnected(pid);
              }
            }
            break;
          case State.unresponsive:
            if (oldState == State.responsive) {
              for (final v in _connListeners) {
                v.peerDisconnected(pid);
              }
            }
            break;
          case State.responsive:
            for (final v in _connListeners) {
              v.peerConnected(pid);
            }
            break;
        }
      }
    } finally {
      _done.complete();
    }
  }

  void connected(PeerId p) {
    if (_getState(p) == State.responsive) {
      return;
    }
    _setState(p, State.responsive);
  }

  void disconnected(PeerId p) {
    if (_getState(p) == State.disconnected) {
      return;
    }
    _setState(p, State.disconnected);
  }

  void markUnresponsive(PeerId p) {
    if (_getState(p) != State.responsive) {
      return;
    }
    _setState(p, State.unresponsive);
  }

  void onMessage(PeerId p) {
    if (_getState(p) != State.unresponsive) {
      return;
    }
    _setState(p, State.responsive);
  }
}
