// Package ice ConnectionState implementation.
library;

/// ConnectionState indicates the ICE agent's connection state.
enum ConnectionState {
  new_,
  checking,
  connected,
  completed,
  failed,
  disconnected,
  closed;

  String string() {
    switch (this) {
      case ConnectionState.new_:
        return 'New';
      case ConnectionState.checking:
        return 'Checking';
      case ConnectionState.connected:
        return 'Connected';
      case ConnectionState.completed:
        return 'Completed';
      case ConnectionState.failed:
        return 'Failed';
      case ConnectionState.disconnected:
        return 'Disconnected';
      case ConnectionState.closed:
        return 'Closed';
    }
  }

  @override
  String toString() => string();
}
