// ignore_for_file: public_member_api_docs
/// Port of github.com/pion/stun v3.1.1 (revision fixed in
/// doc/transpilation/UPSTREAM_LOCK.md).
///
/// Ported: the message codec (`message.go`), the attribute registry and
/// TLV codec (`attributes.go`), `addr.go`, `xoraddr.go`, `integrity.go`,
/// `fingerprint.go`, `errorcode.go`, `errors.go`, `checks.go`,
/// `textattrs.go`, `uattrs.go`, `helpers.go`, `stun.go`, `uri.go`,
/// `agent.go` and `client.go`.
///
/// Deliberately not ported, each documented at its own would-be call site:
/// `internal/hmac`'s `sync.Pool` (integrity.dart uses `package:crypto`'s
/// `Hmac` directly -- see integrity.dart), `client.go`'s
/// `sync.Pool`/`runtime.SetFinalizer` usage (client.dart), Go's
/// `encoding/gob` support (`GobEncode`/`GobDecode`, message.dart), and the
/// `debug`-build-tag-only diagnostic error types in `attributes_debug.go`/
/// `checks_debug.go`/`fingerprint_debug.go`/`integrity_debug.go` (checks.go
/// doc comment) -- none change observable behavior for a Dart port that
/// ships one build.
///
/// **Known gap**, not silently degraded: `client.go`'s STUN-over-DTLS
/// dialing (`stuns:`/secure `turns:` URIs resolving to UDP) throws
/// [DtlsNotSupportedException] because `pion/dtls` is not ported into this
/// codebase yet, and its TLS dialing (`stuns:`/secure `turns:` over TCP)
/// throws [TlsNotSupportedException] because `transpiled_pion_transport_v4`'s
/// `Net.dial` has no upgrade-to-TLS primitive to build it on. See
/// client.dart's file-level doc comment for the full reasoning. Plain
/// `stun:`/`turn:` dialing, and the full message/attribute codec that
/// `pion/ice` actually consumes, are complete.
library;

export 'src/addr.dart'
    show
        AlternateServer,
        BadIpLengthException,
        MappedAddress,
        OtherAddress,
        ResponseOrigin,
        ipToString,
        isIpv4,
        isZeros;
export 'src/agent.dart'
    show
        Agent,
        AgentClosedException,
        Event,
        Handler,
        TransactionExistsException,
        TransactionNotExistsException,
        TransactionStoppedException,
        TransactionTimeOutException,
        noopHandler;
export 'src/attributes.dart'
    show
        AttrType,
        AttributeNotFoundException,
        AttributesX,
        MessageGetX,
        RawAttribute,
        compatAttrType,
        nearestPaddedValueLength,
        padding;
export 'src/checks.dart'
    show
        checkFingerprint,
        checkHmac,
        checkOverflow,
        checkSize,
        isAttrSizeInvalid,
        isAttrSizeOverflow;
export 'src/client.dart'
    show
        Client,
        ClientAgent,
        ClientClosedException,
        ClientOption,
        Clock,
        CloseException,
        Collector,
        DtlsNotSupportedException,
        NoConnectionException,
        StopException,
        TlsNotSupportedException,
        UnsupportedUriException,
        withAgent,
        withClock,
        withCollector,
        withHandler,
        withNoConnClose,
        withNoRetransmit,
        withRto,
        withTimeoutRate;
export 'src/errorcode.dart'
    show ErrorCode, ErrorCodeAttribute, NoDefaultReasonException, TurnException;
export 'src/errors.dart'
    show
        AttributeSizeInvalidException,
        AttributeSizeOverflowException,
        DecodeErrPlace,
        DecodeException,
        UnexpectedEofException;
export 'src/fingerprint.dart'
    show
        FingerprintAttr,
        FingerprintMismatchException,
        fingerprint,
        fingerprintValue;
export 'src/helpers.dart'
    show Checker, Getter, MessageBuildX, Setter, build, mustBuild;
export 'src/integrity.dart'
    show
        FingerprintBeforeIntegrityException,
        IntegrityMismatchException,
        MessageIntegrity;
export 'src/message.dart'
    show
        DecodeToNilException,
        Message,
        MessageClass,
        MessageType,
        Method,
        UnexpectedHeaderEofException,
        attributeHeaderSize,
        bindingError,
        bindingRequest,
        bindingSuccess,
        decode,
        isMessage,
        magicCookie,
        messageHeaderSize,
        randomTransactionId,
        transactionIdSetter,
        transactionIdSize;
export 'src/stun.dart' show defaultPort, defaultTlsPort, transactionId;
export 'src/textattrs.dart'
    show Nonce, Realm, Software, TextAttribute, Username;
export 'src/uattrs.dart' show BadUnknownAttrsSizeException, UnknownAttributes;
export 'src/uri.dart'
    show
        HostException,
        InvalidQueryException,
        PortException,
        ProtoType,
        ProtoTypeException,
        SchemeType,
        SchemeTypeException,
        StunQueryException,
        StunUri,
        UnknownTypeException;
export 'src/xoraddr.dart' show XorMappedAddress;
