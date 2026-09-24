// Package ice Candidate and candidateBase implementation.
library;

import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'candidatetype.dart';
import 'networktype.dart';
import 'tcptype.dart';
import 'candidaterelatedaddress.dart';

/// CandidateExtension represents an ICE candidate extension attribute.
class CandidateExtension {
  final String key;
  final String value;

  const CandidateExtension({required this.key, required this.value});
}

/// Candidate represents an ICE candidate.
abstract class Candidate {
  String foundation();
  String id();
  int component();
  void setComponent(int c);
  DateTime lastReceived();
  DateTime lastSent();
  NetworkType networkType();
  String address();
  Golang.Uint16 port();
  int priority();
  CandidateRelatedAddress? relatedAddress();
  List<CandidateExtension> extensions();
  CandidateExtension? getExtension(String key);
  void addExtension(CandidateExtension ext);
  bool removeExtension(String key);
  String string();
  CandidateType type();
  TcpType tcpType();
  bool equal(Candidate other);
  bool deepEqual(Candidate other);
  String marshal();
}

/// CandidateBase provides default implementation for Candidate.
class CandidateBase implements Candidate {
  String _id;
  String _address;
  Golang.Uint16 _port;
  CandidateType _candidateType;
  NetworkType _networkType;
  int _component;
  TcpType _tcpType;
  String _foundationOverride;
  int _priorityOverride;
  CandidateRelatedAddress? _relatedAddress;
  DateTime _lastReceived;
  DateTime _lastSent;
  final List<CandidateExtension> _extensions = [];

  CandidateBase({
    String id = '',
    String address = '',
    Golang.Uint16? port,
    CandidateType candidateType = CandidateType.host,
    NetworkType networkType = NetworkType.udp4,
    int component = 1,
    TcpType tcpType = TcpType.unspecified,
    String foundationOverride = '',
    int priorityOverride = 0,
    CandidateRelatedAddress? relatedAddress,
    DateTime? lastReceived,
    DateTime? lastSent,
  }) : _id = id,
       _address = address,
       _port = port ?? Golang.Uint16(0),
       _candidateType = candidateType,
       _networkType = networkType,
       _component = component,
       _tcpType = tcpType,
       _foundationOverride = foundationOverride,
       _priorityOverride = priorityOverride,
       _relatedAddress = relatedAddress,
       _lastReceived = lastReceived ?? DateTime.fromMillisecondsSinceEpoch(0),
       _lastSent = lastSent ?? DateTime.fromMillisecondsSinceEpoch(0);

  // Context-like methods from Go's candidateBase
  bool done() => false;
  Exception? err() => null;
  DateTime? deadline() => null;
  dynamic value(dynamic key) => null;

  @override
  String id() => _id;

  @override
  String foundation() {
    if (_foundationOverride.isNotEmpty) return _foundationOverride;
    return '${_candidateType.string()}_${_address}_${_networkType.string()}'
        .hashCode
        .abs()
        .toString();
  }

  @override
  String address() => _address;

  @override
  Golang.Uint16 port() => _port;

  @override
  CandidateType type() => _candidateType;

  @override
  NetworkType networkType() => _networkType;

  @override
  int component() => _component;

  @override
  void setComponent(int c) {
    _component = c;
  }

  int localPreference() => 65535;

  @override
  CandidateRelatedAddress? relatedAddress() => _relatedAddress;

  @override
  TcpType tcpType() => _tcpType;

  int typePreference() => _candidateType.preference();

  @override
  int priority() {
    if (_priorityOverride > 0) return _priorityOverride;
    // RFC 5245 Section 4.1.2.1: priority = (2^24)*(type preference) + (2^8)*(local preference) + (256 - component)
    return (typePreference() << 24) |
        (localPreference() << 8) |
        (256 - _component);
  }

  @override
  bool equal(Candidate other) {
    return _address == other.address() &&
        _port == other.port() &&
        _candidateType == other.type() &&
        _networkType == other.networkType() &&
        _component == other.component();
  }

  @override
  bool deepEqual(Candidate other) {
    if (!equal(other)) return false;
    final otherExts = other.extensions();
    if (_extensions.length != otherExts.length) return false;
    for (var i = 0; i < _extensions.length; i++) {
      if (_extensions[i].key != otherExts[i].key ||
          _extensions[i].value != otherExts[i].value) {
        return false;
      }
    }
    return true;
  }

  @override
  String string() {
    final rel = _relatedAddress != null ? _relatedAddress!.string() : '';
    final tcp = _tcpType != TcpType.unspecified
        ? ' tcptype ${_tcpType.string()}'
        : '';
    return '${foundation()} ${_component} ${_networkType.string().toUpperCase()} ${priority()} ${_address} ${_port.toBigInt().toInt()} typ ${_candidateType.string()}$rel$tcp';
  }

  @override
  DateTime lastReceived() => _lastReceived;

  @override
  DateTime lastSent() => _lastSent;

  void setLastReceived(DateTime t) {
    _lastReceived = t;
  }

  void setLastSent(DateTime t) {
    _lastSent = t;
  }

  @override
  String marshal() => 'candidate:${string()}';

  @override
  List<CandidateExtension> extensions() => List.unmodifiable(_extensions);

  @override
  CandidateExtension? getExtension(String key) {
    for (final ext in _extensions) {
      if (ext.key == key) return ext;
    }
    return null;
  }

  @override
  void addExtension(CandidateExtension ext) {
    removeExtension(ext.key);
    _extensions.add(ext);
  }

  @override
  bool removeExtension(String key) {
    final idx = _extensions.indexWhere((e) => e.key == key);
    if (idx != -1) {
      _extensions.removeAt(idx);
      return true;
    }
    return false;
  }

  @override
  String toString() => string();
}

/// unmarshalCandidate parses an ICE candidate string.
Candidate unmarshalCandidate(String raw) {
  var s = raw.trim();
  if (s.startsWith('candidate:')) {
    s = s.substring('candidate:'.length);
  }
  final parts = s.split(RegExp(r'\s+'));
  if (parts.length < 8) {
    throw FormatException('Invalid candidate line: $raw');
  }

  final foundation = parts[0];
  final component = int.parse(parts[1]);
  final transportStr = parts[2].toLowerCase();
  final priority = int.parse(parts[3]);
  final address = parts[4];
  final port = int.parse(parts[5]);
  // parts[6] should be 'typ'
  final typStr = parts[7].toLowerCase();

  CandidateType ctype;
  switch (typStr) {
    case 'host':
      ctype = CandidateType.host;
      break;
    case 'srflx':
      ctype = CandidateType.serverReflexive;
      break;
    case 'prflx':
      ctype = CandidateType.peerReflexive;
      break;
    case 'relay':
      ctype = CandidateType.relay;
      break;
    default:
      ctype = CandidateType.unspecified;
  }

  NetworkType ntype;
  if (transportStr.contains('tcp')) {
    ntype = address.contains(':') ? NetworkType.tcp6 : NetworkType.tcp4;
  } else {
    ntype = address.contains(':') ? NetworkType.udp6 : NetworkType.udp4;
  }

  CandidateRelatedAddress? relAddr;
  TcpType tcpType = TcpType.unspecified;

  var idx = 8;
  while (idx < parts.length) {
    if (parts[idx] == 'raddr' && idx + 1 < parts.length) {
      final raddress = parts[idx + 1];
      var rport = 0;
      if (idx + 3 < parts.length && parts[idx + 2] == 'rport') {
        rport = int.parse(parts[idx + 3]);
        idx += 4;
      } else {
        idx += 2;
      }
      relAddr = CandidateRelatedAddress(address: raddress, port: rport);
    } else if (parts[idx] == 'tcptype' && idx + 1 < parts.length) {
      tcpType = TcpType.fromString(parts[idx + 1]);
      idx += 2;
    } else {
      idx++;
    }
  }

  return CandidateBase(
    id: foundation,
    address: address,
    port: Golang.Uint16(port),
    candidateType: ctype,
    networkType: ntype,
    component: component,
    tcpType: tcpType,
    foundationOverride: foundation,
    priorityOverride: priority,
    relatedAddress: relAddr,
  );
}
