// Package ice TcpType implementation.
library;

/// TCPType is the type of ICE TCP candidate.
enum TcpType {
  unspecified,
  active,
  passive,
  simultaneousOpen;

  static TcpType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return TcpType.active;
      case 'passive':
        return TcpType.passive;
      case 'so':
        return TcpType.simultaneousOpen;
      default:
        return TcpType.unspecified;
    }
  }

  String string() {
    switch (this) {
      case TcpType.unspecified:
        return '';
      case TcpType.active:
        return 'active';
      case TcpType.passive:
        return 'passive';
      case TcpType.simultaneousOpen:
        return 'so';
    }
  }

  @override
  String toString() => string();
}
