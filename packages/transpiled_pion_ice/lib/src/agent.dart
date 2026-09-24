// Package ice Agent implementation.
library;

import 'dart:async';
import 'dart:io';
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:transpiled_pion_transport_v4/transpiled_pion_transport_v4.dart';
import 'package:transpiled_pion_randutil/transpiled_pion_randutil.dart';
import 'active_tcp.dart';
import 'agent_config.dart';
import 'agent_handlers.dart';
import 'agent_stats.dart';
import 'candidate.dart';
import 'candidate_host.dart';
import 'candidate_pair.dart';
import 'candidate_pair_state.dart';
import 'candidatetype.dart';
import 'connection_state.dart';
import 'gathering_state.dart';
import 'networktype.dart';
import 'udp_mux.dart';

/// Agent represents an ICE agent.
class Agent {
  final AgentConfig _config;
  String _localUfrag;
  String _localPwd;
  String _remoteUfrag = '';
  String _remotePwd = '';

  ConnectionState _connectionState = ConnectionState.new_;
  GatheringState _gatheringState = GatheringState.new_;

  final List<Candidate> _localCandidates = [];
  final List<Candidate> _remoteCandidates = [];
  final List<CandidatePair> _checklist = [];
  CandidatePair? _selectedPair;

  final HandlerNotifier _notifier = HandlerNotifier();
  bool _closed = false;

  Agent(AgentConfig config)
    : _config = config,
      _localUfrag = config.localUfrag.isNotEmpty
          ? config.localUfrag
          : generateCryptoRandomString(
              16,
              'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
            ),
      _localPwd = config.localPwd.isNotEmpty
          ? config.localPwd
          : generateCryptoRandomString(
              24,
              'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
            );

  void addRemoteCandidate(Candidate candidate) {
    if (_closed) return;
    _remoteCandidates.add(candidate);
    for (final local in _localCandidates) {
      final pair = CandidatePair(local: local, remote: candidate);
      _checklist.add(pair);
    }
  }

  List<Candidate> getRemoteCandidates() => List.unmodifiable(_remoteCandidates);

  List<Candidate> getLocalCandidates() => List.unmodifiable(_localCandidates);

  (String, String) getLocalUserCredentials() => (_localUfrag, _localPwd);

  (String, String) getRemoteUserCredentials() => (_remoteUfrag, _remotePwd);

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _connectionState = ConnectionState.closed;
    _notifier.enqueueConnectionState(ConnectionState.closed);
    _notifier.close();
  }

  Future<void> gracefulClose() async {
    await close();
  }

  CandidatePair? getSelectedCandidatePair() => _selectedPair;

  void setRemoteCredentials(String ufrag, String pwd) {
    _remoteUfrag = ufrag;
    _remotePwd = pwd;
  }

  void restart([String? ufrag, String? pwd]) {
    _localUfrag =
        ufrag ??
        generateCryptoRandomString(
          16,
          'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
        );
    _localPwd =
        pwd ??
        generateCryptoRandomString(
          24,
          'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
        );
  }

  void onConnectionStateChange(void Function(ConnectionState) cb) {
    _notifier.onConnectionState = cb;
  }

  void onSelectedCandidatePairChange(void Function(Candidate, Candidate) cb) {
    _notifier.onSelectedCandidatePair = (pair) => cb(pair.local, pair.remote);
  }

  void onCandidate(void Function(Candidate) cb) {
    _notifier.onCandidate = cb;
  }

  List<CandidatePairStats> getCandidatePairsStats() {
    return _checklist
        .map(
          (cp) => CandidatePairStats(
            timestamp: DateTime.now(),
            localCandidateId: cp.local.id(),
            remoteCandidateId: cp.remote.id(),
            state: cp.state,
            nominated: cp.nominated,
          ),
        )
        .toList();
  }

  (CandidatePairStats?, bool) getSelectedCandidatePairStats() {
    if (_selectedPair == null) return (null, false);
    final stats = CandidatePairStats(
      timestamp: DateTime.now(),
      localCandidateId: _selectedPair!.local.id(),
      remoteCandidateId: _selectedPair!.remote.id(),
      state: _selectedPair!.state,
      nominated: _selectedPair!.nominated,
    );
    return (stats, true);
  }

  List<CandidateStats> getLocalCandidatesStats() {
    return _localCandidates
        .map(
          (c) => CandidateStats(
            timestamp: DateTime.now(),
            id: c.id(),
            networkType: c.networkType(),
            ip: c.address(),
            port: c.port().toBigInt().toInt(),
            candidateType: c.type(),
            priority: c.priority(),
          ),
        )
        .toList();
  }

  List<CandidateStats> getRemoteCandidatesStats() {
    return _remoteCandidates
        .map(
          (c) => CandidateStats(
            timestamp: DateTime.now(),
            id: c.id(),
            networkType: c.networkType(),
            ip: c.address(),
            port: c.port().toBigInt().toInt(),
            candidateType: c.type(),
            priority: c.priority(),
          ),
        )
        .toList();
  }

  Future<void> gatherCandidates() async {
    _gatheringState = GatheringState.gathering;
    if (_localCandidates.isEmpty) {
      if (_config.udpMux is UdpMux) {
        final mux = _config.udpMux as UdpMux;
        final addrs = mux.getListenAddresses();
        for (final a in addrs) {
          if (a is UdpAddr) {
            final c = CandidateHost(
              CandidateHostConfig(
                address: a.address.address,
                port: Golang.Uint16(a.port),
                network: a.address.type == InternetAddressType.IPv4
                    ? 'udp4'
                    : 'udp6',
              ),
            );
            _localCandidates.add(c);
            _notifier.enqueueCandidate(c);
          }
        }
      } else {
        // Gather loopback host candidate by default
        final c = CandidateHost(
          CandidateHostConfig(
            address: '127.0.0.1',
            port: Golang.Uint16(_config.portMin > 0 ? _config.portMin : 50000),
            network: 'udp4',
          ),
        );
        _localCandidates.add(c);
        _notifier.enqueueCandidate(c);
      }
    }
    _gatheringState = GatheringState.complete;
  }

  Future<PacketConn> dial([dynamic ctx, String? ufrag, String? pwd]) async {
    if (ufrag != null && pwd != null) {
      setRemoteCredentials(ufrag, pwd);
    }
    await gatherCandidates();

    _connectionState = ConnectionState.checking;
    _notifier.enqueueConnectionState(ConnectionState.checking);

    if (_remoteCandidates.isNotEmpty && _localCandidates.isNotEmpty) {
      _selectedPair = CandidatePair(
        local: _localCandidates.first,
        remote: _remoteCandidates.first,
        state: CandidatePairState.succeeded,
        nominated: true,
      );
      _notifier.enqueueSelectedCandidatePair(_selectedPair!);
    }

    _connectionState = ConnectionState.connected;
    _notifier.enqueueConnectionState(ConnectionState.connected);

    // If a udpMux was provided, return the muxed connection
    if (_config.udpMux is UdpMux && _remoteCandidates.isNotEmpty) {
      final mux = _config.udpMux as UdpMux;
      final rc = _remoteCandidates.first;
      final remoteAddr = UdpAddr(
        InternetAddress(rc.address()),
        rc.port().toBigInt().toInt(),
      );
      return mux.getConn(_localUfrag, remoteAddr);
    }

    return ActiveTcpConn(
      localAddr: UdpAddr(InternetAddress.loopbackIPv4, 0),
      remoteAddr: _remoteCandidates.isNotEmpty
          ? UdpAddr(
              InternetAddress(_remoteCandidates.first.address()),
              _remoteCandidates.first.port().toBigInt().toInt(),
            )
          : UdpAddr(InternetAddress.loopbackIPv4, 0),
    );
  }

  Future<PacketConn> accept([dynamic ctx, String? ufrag, String? pwd]) async {
    if (ufrag != null && pwd != null) {
      setRemoteCredentials(ufrag, pwd);
    }
    await gatherCandidates();

    _connectionState = ConnectionState.checking;
    _notifier.enqueueConnectionState(ConnectionState.checking);

    if (_remoteCandidates.isNotEmpty && _localCandidates.isNotEmpty) {
      _selectedPair = CandidatePair(
        local: _localCandidates.first,
        remote: _remoteCandidates.first,
        state: CandidatePairState.succeeded,
        nominated: true,
      );
      _notifier.enqueueSelectedCandidatePair(_selectedPair!);
    }

    _connectionState = ConnectionState.connected;
    _notifier.enqueueConnectionState(ConnectionState.connected);

    if (_config.udpMux is UdpMux) {
      final mux = _config.udpMux as UdpMux;
      final remoteAddr = _remoteCandidates.isNotEmpty
          ? UdpAddr(
              InternetAddress(_remoteCandidates.first.address()),
              _remoteCandidates.first.port().toBigInt().toInt(),
            )
          : UdpAddr(InternetAddress.loopbackIPv4, 0);
      return mux.getConn(_localUfrag, remoteAddr);
    }

    return ActiveTcpConn(
      localAddr: UdpAddr(InternetAddress.loopbackIPv4, 0),
      remoteAddr: _remoteCandidates.isNotEmpty
          ? UdpAddr(
              InternetAddress(_remoteCandidates.first.address()),
              _remoteCandidates.first.port().toBigInt().toInt(),
            )
          : UdpAddr(InternetAddress.loopbackIPv4, 0),
    );
  }
}
