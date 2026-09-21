// ignore_for_file: public_member_api_docs
//
// Ported from `quic-go/http3/server.go` (module `github.com/quic-go/
// quic-go`, upstream commit fixed in `doc/transpilation/UPSTREAM_LOCK.md`).
//
// The SETTINGS-identifier constants used to build/parse a SETTINGS frame
// itself (SETTINGS_MAX_FIELD_SECTION_SIZE, SETTINGS_ENABLE_CONNECT_PROTOCOL,
// SETTINGS_H3_DATAGRAM) live next to `Http3SettingsFrame` in `frames.dart`,
// mirroring their co-location (and Go-unexported visibility) in
// `frames.go` itself. This file holds the identifiers Go declares elsewhere
// in the same module: the ALPN token and the unidirectional stream type
// registry from `server.go`.
//
// Deliberately NOT ported here: the WebTransport-specific SETTINGS ids
// (`settingsEnableWebtransportDraft06`, `settingsWebTransportEnabled`,
// `settingsWebTransportMaxSessions`, `settingsWebTransportInitialMax*`) and
// the WebTransport frame/stream type ids (`webTransportFrameType = 0x41`,
// `webTransportUniStreamType = 0x54`) read from
// `go-ipfs-reference/webtransport-go/{protocol,server}.go` for value
// verification. Those belong to the separate Go module
// `github.com/quic-go/webtransport-go` (its own `go.mod`), and porting them
// into `transpiled_quic_go` would cross the module boundary AGENTS.md
// requires each port to respect (RULE_MODULE_BOUNDARY_LEAK). Nothing in this
// port's `Http3SettingsFrame.other` map depends on knowing those specific
// ids — unrecognized settings round-trip generically — so this is a scope
// decision, not a functional gap. They should be ported into a future
// `packages/transpiled_webtransport_go/` alongside Objective 6 Marco G.4/G.5.

/// ALPN protocol negotiated during the TLS/QUIC handshake, for QUIC v1 and
/// v2. Mirrors Go's exported `http3.NextProtoH3` (`quic-go/http3/server.go`).
const nextProtoH3 = 'h3';

// Go's exported named type `http3.StreamType` (based on `uint64`,
// `quic-go/http3/server.go`) is the stream type of a unidirectional HTTP/3
// stream; upstream declares no exported value constants for it. It is
// represented here as a plain `int` rather than a Dart typedef: the
// project's typedef-shim audit (RULE_NO_TYPEDEF_SHIMS) rejects any
// `typedef X = Y;` outside `packages/boilerplate/` regardless of whether the
// alias is itself declared upstream, so a bare `int` is what the tooling
// actually enforces here.

/// Control stream (RFC 9114 §6.2.1).
/// Go: unexported `streamTypeControlStream` (`quic-go/http3/server.go`).
const http3StreamTypeControl = 0x00;

/// Push stream (RFC 9114 §6.2.2 — deprecated, kept only for wire-format
/// recognition of legacy peers).
/// Go: unexported `streamTypePushStream` (`quic-go/http3/server.go`).
const http3StreamTypePush = 0x01;

/// QPACK encoder stream (RFC 9204 §4.2).
/// Go: unexported `streamTypeQPACKEncoderStream` (`quic-go/http3/server.go`).
const http3StreamTypeQpackEncoder = 0x02;

/// QPACK decoder stream (RFC 9204 §4.2).
/// Go: unexported `streamTypeQPACKDecoderStream` (`quic-go/http3/server.go`).
const http3StreamTypeQpackDecoder = 0x03;
