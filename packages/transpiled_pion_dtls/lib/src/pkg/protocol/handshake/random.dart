part of 'handshake.dart';

// Port of pkg/protocol/handshake/random.go.

/// Port of `RandomBytesLength`/`RandomLength` (random.go:11-14).
const int randomBytesLength = 28;
const int randomLength = randomBytesLength + 4;

/// Random value that is used in ClientHello and ServerHello.
/// https://tools.ietf.org/html/rfc4346#section-7.4.1.2
///
/// Port of `Random` (random.go:17-20) and its methods
/// `MarshalFixed`/`UnmarshalFixed`/`Populate` (random.go:23-51). Go's
/// `GMTUnixTime time.Time` becomes a Dart `DateTime`.
final class Random {
  DateTime gmtUnixTime;
  Uint8List randomBytes;

  Random({DateTime? gmtUnixTime, Uint8List? randomBytes})
    : gmtUnixTime = gmtUnixTime ?? DateTime.fromMillisecondsSinceEpoch(0),
      randomBytes = randomBytes ?? Uint8List(randomBytesLength);

  /// MarshalFixed encodes the Handshake.
  Uint8List marshalFixed() {
    final out = Uint8List(randomLength);
    final unixSeconds = gmtUnixTime.millisecondsSinceEpoch ~/ 1000;
    out[0] = (unixSeconds >> 24) & 0xff;
    out[1] = (unixSeconds >> 16) & 0xff;
    out[2] = (unixSeconds >> 8) & 0xff;
    out[3] = unixSeconds & 0xff;
    out.setRange(4, randomLength, randomBytes);
    return out;
  }

  /// UnmarshalFixed populates the message from encoded data.
  void unmarshalFixed(Uint8List data) {
    final unixSeconds =
        (data[0] << 24) | (data[1] << 16) | (data[2] << 8) | data[3];
    gmtUnixTime = DateTime.fromMillisecondsSinceEpoch(
      unixSeconds * 1000,
      isUtc: true,
    );
    randomBytes = Uint8List.fromList(data.sublist(4, randomLength));
  }

  /// Populate fills the handshakeRandom with random values. May be called
  /// multiple times.
  void populate() {
    gmtUnixTime = DateTime.now();
    final rng = math.Random.secure();
    for (var i = 0; i < randomBytesLength; i++) {
      randomBytes[i] = rng.nextInt(256);
    }
  }
}
