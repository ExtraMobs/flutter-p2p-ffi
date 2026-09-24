import 'dart:math';
import 'dart:typed_data';

typedef CidGenerator = Uint8List Function();
typedef NullableCidGenerator = Uint8List? Function();

/// RandomCIDGenerator is a random Connection ID generator where CID is the specified size.
CidGenerator randomCidGenerator(int size) {
  final rng = Random.secure();
  return () {
    final cid = Uint8List(size);
    for (var i = 0; i < size; i++) {
      cid[i] = rng.nextInt(256);
    }
    return cid;
  };
}

/// OnlySendCIDGenerator enables sending Connection IDs negotiated with a peer.
NullableCidGenerator onlySendCidGenerator() {
  return () => null;
}
