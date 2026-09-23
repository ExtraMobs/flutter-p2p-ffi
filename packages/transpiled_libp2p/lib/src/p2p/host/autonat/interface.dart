// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:convert';
import 'dart:typed_data';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';
import '../../../core/crypto/proto_varint.dart';
import '../../../core/host/host.dart';
import '../../../core/network/network.dart';
import '../../../core/peer/addr_info.dart';
import '../../../core/peer/peer_id.dart';

part 'client.dart';
part 'proto.dart';

/// AutoNAT is the interface for NAT autodiscovery
abstract interface class AutoNat {
  /// Status returns the current NAT status
  Reachability status();

  /// Closes the AutoNAT subsystem
  Future<void> close();
}

/// Client is a stateless client interface to AutoNAT peers
abstract class Client {
  factory Client({required Host host, AddrFunc? addrFunc}) = _Client;

  /// DialBack requests from a peer providing AutoNAT services to test dial back
  Future<void> dialBack(PeerId p);
}

/// AddrFunc is a function returning the candidate addresses for the local host.
typedef AddrFunc = List<Multiaddr> Function();
