// Package ice CandidateRelatedAddress implementation.
library;

/// CandidateRelatedAddress conveys transport addresses related to the candidate.
class CandidateRelatedAddress {
  final String address;
  final int port;

  const CandidateRelatedAddress({required this.address, required this.port});

  String string() => ' related $address:$port';

  bool equal(CandidateRelatedAddress? other) {
    if (other == null) return false;
    return address == other.address && port == other.port;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CandidateRelatedAddress && equal(other));

  @override
  int get hashCode => Object.hash(address, port);

  @override
  String toString() => string();
}
