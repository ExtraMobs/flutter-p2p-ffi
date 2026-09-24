part of 'extension.dart';

// Port of pkg/protocol/extension/cookie.go.

const int _maxCookieSize = 0xffff - 2;

/// CookieExt implements the cookie extension in DTLS 1.3. See RFC 8446
/// section 4.2.2. Cookie.
///
/// Port of `CookieExt` (cookie.go:12-14) and its methods
/// `TypeValue`/`Marshal`/`Unmarshal` (cookie.go:17-60).
final class CookieExt implements Extension {
  Uint8List cookie;

  CookieExt([Uint8List? cookie]) : cookie = cookie ?? Uint8List(0);

  @override
  TypeValue get typeValue => TypeValue.cookie;

  @override
  Uint8List marshal() {
    final cookieLength = cookie.length;
    if (cookieLength == 0 || cookieLength > _maxCookieSize) {
      throw _errCookieExtFormat;
    }
    final b = _CryptobyteBuilder();
    b.addUint16(typeValue.value);
    b.addUint16LengthPrefixed((b) {
      b.addUint16LengthPrefixed((b) {
        b.addBytes(cookie);
      });
    });
    return b.toBytes();
  }

  @override
  void unmarshal(Uint8List data) {
    final val = _CryptobyteReader(data);
    final extension = val.readUint16();
    if (extension != typeValue.value) throw _errInvalidExtensionType;

    final extData = val.readUint16LengthPrefixedReader();

    final cookieBytes = extData.readUint16LengthPrefixed();
    if (cookieBytes.isEmpty || cookieBytes.length > _maxCookieSize) {
      throw _errCookieExtFormat;
    }
    cookie = Uint8List.fromList(cookieBytes);
  }
}
