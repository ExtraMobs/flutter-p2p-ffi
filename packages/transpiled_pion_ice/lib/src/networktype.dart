// Package ice NetworkType implementation.
library;

/// NetworkType represents the type of network.
enum NetworkType {
  udp4,
  udp6,
  tcp4,
  tcp6;

  String string() {
    switch (this) {
      case NetworkType.udp4:
        return 'udp4';
      case NetworkType.udp6:
        return 'udp6';
      case NetworkType.tcp4:
        return 'tcp4';
      case NetworkType.tcp6:
        return 'tcp6';
    }
  }

  bool isUdp() => this == NetworkType.udp4 || this == NetworkType.udp6;
  bool isTcp() => this == NetworkType.tcp4 || this == NetworkType.tcp6;

  @override
  String toString() => string();
}
