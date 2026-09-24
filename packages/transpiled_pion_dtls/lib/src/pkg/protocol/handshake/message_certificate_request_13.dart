part of 'handshake.dart';

// Port of pkg/protocol/handshake/message_certificate_request_13.go.

const int _maxUint16 = 0xffff;
const int _certReq13ContextMaxLength = 255;
const int _certReq13MinLength = 3;

/// MessageCertificateRequest13 represents the CertificateRequest handshake
/// message for DTLS 1.3. This message is used by the server to request a
/// certificate from the client.
/// https://datatracker.ietf.org/doc/html/rfc8446#section-4.3.2
///
/// Port of `MessageCertificateRequest13` (message_certificate_request_13.go:15-23)
/// and its methods `Type`/`Marshal`/`Unmarshal`
/// (message_certificate_request_13.go:30-134).
final class MessageCertificateRequest13 implements Message {
  /// CertificateRequestContext is an opaque value that the server creates
  /// to bind the client's certificate to the handshake context.
  Uint8List certificateRequestContext;

  /// Extensions contains the list of extensions. The signature_algorithms
  /// extension is REQUIRED per RFC 8446.
  List<extension.Extension> extensions;

  MessageCertificateRequest13({
    Uint8List? certificateRequestContext,
    List<extension.Extension>? extensions,
  }) : certificateRequestContext = certificateRequestContext ?? Uint8List(0),
       extensions = extensions ?? [];

  @override
  HandshakeType get type => HandshakeType.certificateRequest;

  /// Marshal encodes the MessageCertificateRequest13 into its wire format.
  ///
  /// Wire format:
  /// ```
  /// [1 byte]  certificate_request_context length
  /// [0-255]   certificate_request_context data
  /// [2 bytes] extensions length (from extension.Marshal)
  /// [variable] extensions data
  /// ```
  @override
  Uint8List marshal() {
    if (certificateRequestContext.length > _certReq13ContextMaxLength) {
      throw _errCertificateRequestContextTooLong;
    }

    final hasSignatureAlgorithms = extensions.any(
      (ext) =>
          ext.typeValue == extension.TypeValue.supportedSignatureAlgorithms,
    );
    if (!hasSignatureAlgorithms) {
      throw _errMissingSignatureAlgorithmsExtension;
    }

    final builder = _CryptobyteBuilder();
    builder.addUint8LengthPrefixed((b) {
      b.addBytes(certificateRequestContext);
    });

    final extensionsData = extension.marshalExtensions(extensions);
    if (extensionsData.length < 2 || extensionsData.length > _maxUint16) {
      throw _errInvalidExtensionsLength;
    }
    builder.addBytes(extensionsData);

    return builder.toBytes();
  }

  /// Unmarshal decodes the MessageCertificateRequest13 from its wire format.
  @override
  void unmarshal(Uint8List data) {
    if (data.length < _certReq13MinLength) throw _errBufferTooSmall;

    final str = _CryptobyteReader(data);

    final contextData = str.readUint8LengthPrefixed();
    certificateRequestContext = Uint8List.fromList(contextData);

    if (str.remainingLength < 2) throw _errInvalidExtensionsLength;
    final peek = str.clone();
    final extensionsLen = (peek.readUint8() << 8) | peek.readUint8();

    if (str.remainingLength - 2 != extensionsLen) throw _errLengthMismatch;

    extensions = extension.unmarshalExtensions(
      str.readBytes(str.remainingLength),
    );

    final hasSignatureAlgorithms = extensions.any(
      (ext) =>
          ext.typeValue == extension.TypeValue.supportedSignatureAlgorithms,
    );
    if (!hasSignatureAlgorithms) {
      throw _errMissingSignatureAlgorithmsExtension;
    }
  }
}
