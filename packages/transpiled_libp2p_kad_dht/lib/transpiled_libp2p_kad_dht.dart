// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Port of `go-libp2p-kad-dht` (partial).
///
/// Covers the Amino DHT client (`lookup.go`, `routing.go`), the server
/// handlers (`handlers.go` and the response half of `dht_net.go`) and the
/// wire format of `pb/dht.proto`. The module boundary follows the upstream
/// `go.mod`; see `doc/transpilation/PROGRESS.md` for what is still missing.
library;

export 'src/dht_message.dart'
    show
        DhtRequest,
        DhtResponse,
        boundPeerRecordAddrs,
        dhtMessageSizeMax,
        dhtPeerSizeMax,
        encodeAddProvider,
        encodeDhtResponse,
        encodeFindNode,
        encodeGetProviders,
        encodePeerRecord,
        frameDhtMessage,
        maxPeerRecordSize,
        readDhtFrame;
export 'src/dht_provider_finder.dart'
    show DhtClient, dhtProtocol, lanDhtProtocol;
export 'src/dht_provider_manager.dart' show ProviderManager, dhtProvideValidity;
export 'src/dht_server.dart' show DhtServer, ModeOpt, dhtStreamIdleTimeout;
export 'src/query_peerset.dart' show PeerState, QueryPeerset;
