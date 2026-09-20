import 'identity.dart';

/// Bitswap client settings used by the embedded node.
final class BitswapConfig {
  /// Creates Bitswap settings.
  const BitswapConfig({this.p2pTimeout = const Duration(seconds: 30)});

  /// Maximum time allowed for a block request.
  final Duration p2pTimeout;
}

/// Network settings needed by the current TCP/Noise runtime.
final class NetworkConfig {
  /// Creates network settings.
  const NetworkConfig({
    this.listenAddresses = const ['/ip4/127.0.0.1/tcp/0'],
    this.announceAddresses = const [],
    this.bootstrapPeers = const [],
    this.mdnsEnabled = true,
  });

  /// Addresses on which the libp2p host listens.
  final List<String> listenAddresses;

  /// Public addresses to announce to peers and the DHT.
  final List<String> announceAddresses;

  /// Peers used to enter the public DHT.
  final List<String> bootstrapPeers;

  /// Enables LAN discovery (Kubo Discovery.MDNS.Enabled).
  final bool mdnsEnabled;
}

/// Reusable configuration for an embedded IPFS node.
final class IpfsConfig {
  /// Creates node settings.
  const IpfsConfig({
    this.identity,
    this.offline = true,
    this.network = const NetworkConfig(),
    this.bitswap = const BitswapConfig(),
  });

  /// Whether networking is disabled.
  final bool offline;

  /// Stored local identity; omitted for an ephemeral node.
  final Identity? identity;

  /// libp2p network settings.
  final NetworkConfig network;

  /// Bitswap client settings.
  final BitswapConfig bitswap;

  /// Returns a copy with selected values replaced.
  IpfsConfig copyWith({
    Identity? identity,
    bool? offline,
    NetworkConfig? network,
    BitswapConfig? bitswap,
  }) => IpfsConfig(
    identity: identity ?? this.identity,
    offline: offline ?? this.offline,
    network: network ?? this.network,
    bitswap: bitswap ?? this.bitswap,
  );
}
