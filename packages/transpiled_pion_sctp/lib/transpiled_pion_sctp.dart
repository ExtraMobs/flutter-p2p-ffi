// ignore_for_file: public_member_api_docs
/// Port of github.com/pion/sctp revision fixed in
/// doc/transpilation/UPSTREAM_LOCK.md (v1.8.39).
///
/// **Ported so far**: the full pure codec layer -- `util.go` (4-byte chunk
/// padding, RFC 1982 Serial Number Arithmetic for TSN/SSN wraparound
/// comparison), `chunktype.go`, `chunkheader.go`, `chunk.go`, every
/// `param_*.go` parameter type (`paramtype.go`, `paramheader.go`,
/// `param.go` and its 11 concrete types), every `error_cause_*.go` type,
/// all 16 concrete `chunk_*.go` types (`chunk_init_common.go`'s shared
/// INIT/INIT-ACK body included), and `packet.go` (marshal/unmarshal with
/// the CRC32C/Castagnoli checksum, and its `TryMarshalUnmarshal` fuzz
/// entrypoint). Every one of these Go types is unexported (package-private)
/// and stays public only within `lib/src` -- see util.dart's file-level doc
/// comment -- so none of them is re-exported below.
/// [PayloadProtocolIdentifier] (chunk_payload_data.go) is the sole
/// exception: it *is* exported upstream, so it alone is re-exported here to
/// preserve the same visibility parity.
///
/// **Known gap, declared not silent**: the `association` state machine
/// (INIT/INIT-ACK/COOKIE-ECHO/COOKIE-ACK, SHUTDOWN, congestion control, RTO
/// timers), `stream.go`, and the payload/pending/receive/control queues and
/// reassembly queue are not ported yet. `chunkPayloadData`'s
/// retransmission/partial-reliability bookkeeping fields and methods (only
/// reachable from that subsystem) are declared as a named gap in
/// chunk_payload_data.dart's file-level doc comment rather than ported
/// unused. No symbol below pretends to be more complete than it is.
library;

export 'src/chunk.dart' show Chunk;
export 'src/chunk_payload_data.dart' show PayloadProtocolIdentifier;
export 'src/chunkheader.dart'
    show
        ChunkHeader,
        ChunkHeaderNotEnoughSpaceException,
        ChunkHeaderPaddingNonZeroException,
        ChunkHeaderTooSmallException;
export 'src/chunktype.dart' show ChunkType;
