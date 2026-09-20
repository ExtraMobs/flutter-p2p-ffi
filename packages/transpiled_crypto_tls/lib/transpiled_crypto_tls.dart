// ignore_for_file: public_member_api_docs
/// Port of Go's standard library crypto/tls (TLS 1.3 path).
///
/// Scope of this pass: the TLS 1.3 key schedule (`key_schedule.dart`, RFC
/// 8446 Section 7), the TLS 1.3 cipher suite table plus AEAD wrapping
/// (`cipher_suites.dart`), the TLS 1.3 handshake message codec
/// (`handshake_messages.dart`), TLS alerts (`alert.dart`, ported in full),
/// and the TLS 1.3 record layer -- per-record AEAD protection, framing,
/// fragmentation and the referenced size/version/record-type constants
/// (`record_layer.dart`). The handshake state machine
/// (`handshake_client_tls13.go`/`handshake_server_tls13.go`, not yet ported)
/// and `Conn`'s `net.Conn`/`*Config`-bound orchestration (`Read`, `Write`,
/// `Handshake`, the stream-reassembly retry loop) are out of scope for this
/// pass; see each file's header for its exact Go symbol traceability and
/// named gaps.
library;

export 'src/alert.dart'
    show
        AlertException,
        alertAccessDenied,
        alertBadCertificate,
        alertBadCertificateHashValue,
        alertBadCertificateStatusResponse,
        alertBadRecordMac,
        alertCertificateExpired,
        alertCertificateRequired,
        alertCertificateRevoked,
        alertCertificateUnknown,
        alertCertificateUnobtainable,
        alertCloseNotify,
        alertDecodeError,
        alertDecompressionFailure,
        alertDecryptError,
        alertDecryptionFailed,
        alertEchRequired,
        alertExportRestriction,
        alertHandshakeFailure,
        alertIllegalParameter,
        alertInappropriateFallback,
        alertInsufficientSecurity,
        alertInternalError,
        alertLevelError,
        alertLevelWarning,
        alertMissingExtension,
        alertNoApplicationProtocol,
        alertNoRenegotiation,
        alertProtocolVersion,
        alertRecordOverflow,
        alertUnexpectedMessage,
        alertUnknownCa,
        alertUnknownPskIdentity,
        alertUnrecognizedName,
        alertUnsupportedCertificate,
        alertUnsupportedExtension,
        alertUserCanceled;
export 'src/cipher_suites.dart'
    show
        AeadAuthenticationException,
        aeadAesGcmTls13,
        aeadChaCha20Poly1305,
        aeadNonceLength,
        cipherSuiteTls13ById,
        cipherSuitesTls13,
        mutualCipherSuiteTls13,
        tlsAes128GcmSha256,
        tlsAes256GcmSha384,
        tlsChacha20Poly1305Sha256;
export 'src/handshake_messages.dart'
    show
        CertificateMsgTls13,
        CertificateRequestMsgTls13,
        CertificateVerifyMsg,
        ClientHelloMsg,
        EncryptedExtensionsMsg,
        EndOfEarlyDataMsg,
        FinishedMsg,
        HandshakeMessageFormatException,
        KeyShare,
        KeyUpdateMsg,
        NewSessionTicketMsgTls13,
        PskIdentity,
        ServerHelloMsg;
export 'src/key_schedule.dart'
    show
        CipherSuiteTls13,
        CipherSuiteTls13Aead,
        EarlySecret,
        ExporterMasterSecret,
        HandshakeSecret,
        HandshakeTranscript,
        MasterSecret,
        expandLabel;
export 'src/record_layer.dart'
    show
        HalfConn,
        RecordHeaderException,
        maxCiphertextTls13,
        maxPlaintext,
        maxUselessRecords,
        readTls13Record,
        recordHeaderLen,
        recordTypeAlert,
        recordTypeApplicationData,
        recordTypeChangeCipherSpec,
        recordTypeHandshake,
        versionTls10,
        versionTls12,
        versionTls13,
        writeTls13Records;
