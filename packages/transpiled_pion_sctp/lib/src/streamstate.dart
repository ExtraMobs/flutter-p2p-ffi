// ignore_for_file: public_member_api_docs

/// StreamState is an enum for SCTP Stream state field.
enum StreamState {
  open,
  closing,
  closed;

  String string() {
    switch (this) {
      case StreamState.open:
        return 'open';
      case StreamState.closing:
        return 'closing';
      case StreamState.closed:
        return 'closed';
    }
  }

  @override
  String toString() => string();
}
