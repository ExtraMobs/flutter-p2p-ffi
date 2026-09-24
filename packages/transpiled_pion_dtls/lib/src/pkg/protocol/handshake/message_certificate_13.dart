part of 'handshake.dart';

// Port of pkg/protocol/handshake/message_certificate_13.go.

const int _maxUint24 = 0xffffff;
const int _cert13ContextMaxLength = 255;
const int _cert13CertLengthFieldSize = 3;
const int _cert13ExtLengthFieldSize = 2;

/// CertificateEntry13 represents a single certificate entry in the DTLS 1.3
/// Certificate message. Each entry contains certificate data and optional
/// per-certificate extensions.
/// https://datatracker.ietf.org/doc/html/rfc8446#section-4.4.2
///
/// Port of `CertificateEntry13` (message_certificate_13.go:16-24).
final class CertificateEntry13 {
  /// CertificateData contains the DER-encoded X.509 certificate. Can be
  /// empty for certain contexts (e.g., RawPublicKey mode).
  Uint8List certificateData;

  /// Extensions contains per-certificate extensions. Examples: OCSP status,
  /// SignedCertificateTimestamp, etc.
  List<extension.Extension> extensions;

  CertificateEntry13({
    Uint8List? certificateData,
    List<extension.Extension>? extensions,
  }) : certificateData = certificateData ?? Uint8List(0),
       extensions = extensions ?? [];
}

/// MessageCertificate13 represents the Certificate handshake message for
/// DTLS 1.3. This message is used to transport the certificate chain and
/// associated extensions.
/// https://datatracker.ietf.org/doc/html/rfc8446#section-4.4.2
///
/// Port of `MessageCertificate13` (message_certificate_13.go:29-39) and its
/// methods `Type`/`Marshal`/`Unmarshal` (message_certificate_13.go:46-198).
final class MessageCertificate13 implements Message {
  /// CertificateRequestContext is an opaque value that binds this
  /// certificate to a specific CertificateRequest (for client certificates)
  /// or is empty for server certificates.
  Uint8List certificateRequestContext;

  /// CertificateList contains the certificate chain with each entry having
  /// optional per-certificate extensions.
  List<CertificateEntry13> certificateList;

  MessageCertificate13({
    Uint8List? certificateRequestContext,
    List<CertificateEntry13>? certificateList,
  }) : certificateRequestContext = certificateRequestContext ?? Uint8List(0),
       certificateList = certificateList ?? [];

  @override
  HandshakeType get type => HandshakeType.certificate;

  /// Marshal encodes the MessageCertificate13 into its wire format.
  ///
  /// Wire format:
  /// ```
  /// [1 byte]  certificate_request_context length
  /// [0-255]   certificate_request_context data
  /// [3 bytes] certificate_list length
  /// For each certificate:
  ///   [3 bytes]  cert_data length
  ///   [variable] cert_data (DER certificate)
  ///   [2 bytes]  extensions length (from extension.Marshal)
  ///   [variable] extensions data
  /// ```
  @override
  Uint8List marshal() {
    if (certificateRequestContext.length > _cert13ContextMaxLength) {
      throw _errCertificateRequestContextTooLong;
    }

    final out = BytesBuilder();
    out.addByte(certificateRequestContext.length);
    out.add(certificateRequestContext);

    final certificateListBytes = BytesBuilder();
    for (final entry in certificateList) {
      final certDataLen = entry.certificateData.length;
      if (certDataLen == 0 || certDataLen > _maxUint24) {
        throw _errInvalidCertificateEntry;
      }
      final certDataLenBytes = Uint8List(_cert13CertLengthFieldSize);
      util.putBigEndianUint24(certDataLenBytes, certDataLen);
      certificateListBytes.add(certDataLenBytes);
      certificateListBytes.add(entry.certificateData);

      certificateListBytes.add(extension.marshalExtensions(entry.extensions));

      if (certificateListBytes.length > _maxUint24) {
        throw _errCertificateListTooLong;
      }
    }
    final certificateListRaw = certificateListBytes.toBytes();

    final certificateListLenBytes = Uint8List(_cert13CertLengthFieldSize);
    util.putBigEndianUint24(certificateListLenBytes, certificateListRaw.length);
    out.add(certificateListLenBytes);
    out.add(certificateListRaw);

    return out.toBytes();
  }

  /// Unmarshal decodes the MessageCertificate13 from its wire format.
  @override
  void unmarshal(Uint8List data) {
    if (data.length < 1 + _cert13CertLengthFieldSize) throw _errBufferTooSmall;

    final str = _CryptobyteReader(data);

    final contextData = str.readUint8LengthPrefixed();
    certificateRequestContext = Uint8List.fromList(contextData);

    final certificateListData = str.readUint24LengthPrefixed();

    if (!str.isEmpty) throw _errLengthMismatch;

    certificateList = [];
    final entriesReader = _CryptobyteReader(certificateListData);
    while (!entriesReader.isEmpty) {
      certificateList.add(_parseCertificate13Entry(entriesReader));
    }
  }
}

/// parseCertificate13Entry parses a single certificate entry from the
/// cryptobyte string.
///
/// Port of `parseCertificate13Entry` (message_certificate_13.go:115-153).
CertificateEntry13 _parseCertificate13Entry(_CryptobyteReader str) {
  final certData = str.readUint24LengthPrefixed();
  if (certData.isEmpty) throw _errInvalidCertificateEntry;
  final certDataBytes = Uint8List.fromList(certData);

  if (str.remainingLength < _cert13ExtLengthFieldSize) {
    throw _errInvalidCertificateEntry;
  }

  // Peek the extensions length to validate we have enough data, then
  // extract and unmarshal exactly that many bytes -- matching Go's manual
  // slice arithmetic (message_certificate_13.go:139-149) rather than the
  // reader's own length-prefixed helper, since `extension.unmarshalExtensions`
  // itself re-parses the 2-byte length prefix.
  final peek = str.clone();
  final extensionsLen = (peek.readUint8() << 8) | peek.readUint8();
  if (str.remainingLength < _cert13ExtLengthFieldSize + extensionsLen) {
    throw _errInvalidCertificateEntry;
  }
  final extensionsData = str.readBytes(
    _cert13ExtLengthFieldSize + extensionsLen,
  );

  return CertificateEntry13(
    certificateData: certDataBytes,
    extensions: extension.unmarshalExtensions(extensionsData),
  );
}
