// src/protocols/dht/dht_routing_table_interface.dart
//
// Re-export shim: moved to ../../core/interfaces/routing_table.dart (it only
// depends on transpiled_libp2p's peer_id.dart, and transport/ needs it without
// depending on a DHT-specific path). Kept here until Phase 4 confirms
// nothing imports this path directly anymore.
export '../../core/interfaces/routing_table.dart';
