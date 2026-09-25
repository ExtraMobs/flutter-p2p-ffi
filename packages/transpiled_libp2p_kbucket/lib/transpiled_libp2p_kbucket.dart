// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Port of `go-libp2p-kbucket`. The `peerdiversity` subpackage
/// (`peerdiversity/filter.go`) is not re-exported here: Go code that wants
/// `peerdiversity.Filter` imports `go-libp2p-kbucket/peerdiversity`
/// directly, as its own package path, separately from `go-libp2p-kbucket`
/// itself -- this port keeps that same separation. Import it with
/// `package:transpiled_libp2p_kbucket/src/peerdiversity/filter.dart`,
/// prefixed `peerdiversity` per AGENTS.md's Regra 25.
library;

export 'src/bucket.dart' show Bucket, PeerInfo;
export 'src/keyspace.dart' show KeySpace, KeyspaceKey, sortByDistance;
export 'src/peer_metrics.dart' show PeerMetrics;
export 'src/sorting.dart' show PeerDistanceSorter, sortClosestPeers;
export 'src/table.dart'
    show
        PeerRejectedHighLatencyException,
        PeerRejectedNoCapacityException,
        RoutingTable;
export 'src/table_refresh.dart' show RoutingTableRefresh, maxCplForRefresh;
export 'src/util.dart'
    show
        DhtId,
        LookupFailureException,
        closer,
        commonPrefixLen,
        convertKey,
        convertPeerId,
        genRandPeerIdWithCpl,
        peerIdPreimageMaxCpl,
        randUint16,
        xor;
export 'src/xor_keyspace.dart' show XorKeySpace, xorBytes, zeroPrefixLen;
