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
  });

  /// Addresses on which the libp2p host listens.
  final List<String> listenAddresses;

  /// Public addresses to announce to peers and the DHT.
  final List<String> announceAddresses;

  /// Peers used to enter the public DHT.
  final List<String> bootstrapPeers;
}

/// Reusable configuration for an embedded IPFS node.
final class IpfsConfig {
  /// Creates node settings.
  const IpfsConfig({
    this.offline = true,
    this.network = const NetworkConfig(),
    this.bitswap = const BitswapConfig(),
  });

  /// Whether networking is disabled.
  final bool offline;

  /// libp2p network settings.
  final NetworkConfig network;

  /// Bitswap client settings.
  final BitswapConfig bitswap;

  /// Returns a copy with selected values replaced.
  IpfsConfig copyWith({
    bool? offline,
    NetworkConfig? network,
    BitswapConfig? bitswap,
  }) => IpfsConfig(
    offline: offline ?? this.offline,
    network: network ?? this.network,
    bitswap: bitswap ?? this.bitswap,
  );
}
