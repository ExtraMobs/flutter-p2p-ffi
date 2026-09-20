/// Port of `stun.go` (pion/stun v3.1.1).
///
/// `readFullOrPanic`/`writeOrPanic` (stun.go:23-39) are private helpers that
/// wrap `io.ReadFull`/`io.Writer.Write` and `panic` on error purely because
/// Go's blocking-random-source APIs return `(int, error)` even though they
/// realistically never fail. Dart's `Random.secure()` (used directly in
/// message.dart for [Message.newTransactionId]/`randomTransactionId`) has no
/// error channel to wrap in the first place, so there is nothing for these
/// two helpers to port.
library;

import 'helpers.dart';
import 'message.dart';

/// Port of `DefaultPort` (stun.go:44): the IANA-assigned port for the
/// "stun" protocol.
const int defaultPort = 3478;

/// Port of `DefaultTLSPort` (stun.go:45): the IANA-assigned port for the
/// "stuns" protocol.
const int defaultTlsPort = 5349;

/// Port of `transactionIDSetter` (stun.go:49): private in Go, so private
/// here too (AGENTS.md, "Princípio do Menor Privilégio").
final class _TransactionIdSetter implements Setter {
  const _TransactionIdSetter();

  @override
  void addTo(Message m) => m.newTransactionId();
}

/// Port of the package-level `TransactionID` value (stun.go:56): sets
/// `m.transactionId` to a fresh random value.
const Setter transactionId = _TransactionIdSetter();
