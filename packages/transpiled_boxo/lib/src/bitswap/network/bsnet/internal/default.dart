import 'package:transpiled_libp2p/transpiled_libp2p.dart';

/// ProtocolBitswapNoVers is equivalent to the legacy bitswap protocol
const ProtocolId protocolBitswapNoVers = '/ipfs/bitswap';

/// ProtocolBitswapOneZero is the prefix for the legacy bitswap protocol
const ProtocolId protocolBitswapOneZero = '/ipfs/bitswap/1.0.0';

/// ProtocolBitswapOneOne is the prefix for version 1.1.0
const ProtocolId protocolBitswapOneOne = '/ipfs/bitswap/1.1.0';

/// ProtocolBitswap is the current version of the bitswap protocol: 1.2.0
const ProtocolId protocolBitswap = '/ipfs/bitswap/1.2.0';

const List<ProtocolId> defaultProtocols = [
  protocolBitswap,
  protocolBitswapOneOne,
  protocolBitswapOneZero,
  protocolBitswapNoVers,
];
