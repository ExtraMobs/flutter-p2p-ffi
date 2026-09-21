// Port of `github.com/quic-go/webtransport-go`'s `protocol.go` and the wire
// identifiers its `server.go` declares (v0.11.1, revision
// d03fbc34952e05e833ab2a3810ab55aeefe2bf30, fixed in
// `doc/transpilation/UPSTREAM_LOCK.md`).
//
// These identifiers belong to the webtransport-go module rather than to
// quic-go: HTTP/3 knows nothing about WebTransport beyond the SETTINGS it
// relays, so the WebTransport SETTINGS codepoints and the stream-header
// signals live here, on their own `go.mod` boundary.

/// SETTINGS_ENABLE_WEBTRANSPORT as used up to draft-ietf-webtrans-http3-06.
///
/// Go: `settingsEnableWebtransportDraft06`.
const int settingsEnableWebtransportDraft06 = 0x2b603742;

/// SETTINGS_WT_ENABLED. Go: `settingsWebTransportEnabled`.
const int settingsWebTransportEnabled = 0x2c7cf000;

/// SETTINGS_WT_MAX_SESSIONS. Go: `settingsWebTransportMaxSessions`.
const int settingsWebTransportMaxSessions = 0x14e9cd29;

/// SETTINGS_WT_INITIAL_MAX_STREAMS_UNI.
/// Go: `settingsWebTransportInitialMaxStreamsUni`.
const int settingsWebTransportInitialMaxStreamsUni = 0x2b64;

/// SETTINGS_WT_INITIAL_MAX_STREAMS_BIDI.
/// Go: `settingsWebTransportInitialMaxStreamsBidi`.
const int settingsWebTransportInitialMaxStreamsBidi = 0x2b65;

/// SETTINGS_WT_INITIAL_MAX_DATA. Go: `settingsWebTransportInitialMaxData`.
const int settingsWebTransportInitialMaxData = 0x2b61;

/// The Extended-CONNECT `:protocol` value, per draft-ietf-webtrans-http3-15
/// sections 3.2 and 9.1. Go: `protocolHeader`.
const String protocolHeader = 'webtransport-h3';

/// The pre-draft-15 `:protocol` value. A server still accepts it; a client
/// does not send it. Go: `protocolHeaderLegacy`.
const String protocolHeaderLegacy = 'webtransport';

/// The frame type that prefixes a WebTransport bidirectional stream, followed
/// by the session ID. Go: `webTransportFrameType` (`server.go`).
const int webTransportFrameType = 0x41;

/// The stream type that prefixes a WebTransport unidirectional stream,
/// followed by the session ID. Go: `webTransportUniStreamType` (`server.go`).
const int webTransportUniStreamType = 0x54;

/// The HTTP header carrying the application protocols a client can speak.
/// Go: `wtAvailableProtocolsHeader`.
const String wtAvailableProtocolsHeader = 'wt-available-protocols';

/// The HTTP header carrying the application protocol a server selected.
/// Go: `wtProtocolHeader`.
const String wtProtocolHeader = 'wt-protocol';

/// Whether [value] is a `:protocol` value that names WebTransport.
///
/// Go: `isWebTransportProtocol`.
bool isWebTransportProtocol(String value) =>
    value == protocolHeader || value == protocolHeaderLegacy;

/// Whether [id] can be a WebTransport session ID.
///
/// Session IDs are the stream IDs of the CONNECT requests that establish
/// them, and those requests travel on client-initiated bidirectional streams,
/// whose QUIC stream IDs are divisible by four. Go: `isValidSessionID`.
bool isValidSessionId(int id) => id % 4 == 0;
