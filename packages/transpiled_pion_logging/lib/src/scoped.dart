// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `scoped.go` (github.com/pion/logging, revision fixed in
/// doc/transpilation/UPSTREAM_LOCK.md): [LogLevel], [LeveledLogger] and
/// [LoggerFactory].
///
/// **Deliberately not ported**: `LogLevel.Set`/`LogLevel.Get`
/// (scoped.go:14-21) exist in Go only so that an addressable `LogLevel`
/// struct field (e.g. `DefaultLeveledLogger.level`) can be mutated safely
/// from concurrent goroutines via `sync/atomic`. A Dart isolate has no
/// shared-memory threads, so a plain field read/write is already safe;
/// [LogLevel] is therefore ported as the immutable value type it
/// conceptually is (mirroring how `MessageType`/`MessageClass` are ported in
/// `transpiled_pion_stun`), and the mutation this enabled is exposed instead
/// as `DefaultLeveledLogger.setLevel` (logger.dart), which is the only
/// place upstream ever calls `.Set`. Ordering, the six levels and
/// `String()`/[toString] all keep full behavioral parity.
library;

/// Port of `LogLevel` (scoped.go:11): the level at which a [LeveledLogger]
/// emits messages.
final class LogLevel implements Comparable<LogLevel> {
  const LogLevel._(this.value);

  /// The underlying ordinal, matching the Go `iota` values.
  final int value;

  /// Port of `LogLevelDisabled` (scoped.go:44): completely disables logging.
  static const LogLevel disabled = LogLevel._(0);

  /// Port of `LogLevelError` (scoped.go:47): fatal errors that should be
  /// handled by user code, but are logged to ensure they are seen.
  static const LogLevel error = LogLevel._(1);

  /// Port of `LogLevelWarn` (scoped.go:49): abnormal, non-fatal operation.
  static const LogLevel warn = LogLevel._(2);

  /// Port of `LogLevelInfo` (scoped.go:51): normal operation (state
  /// transitions, etc.).
  static const LogLevel info = LogLevel._(3);

  /// Port of `LogLevelDebug` (scoped.go:53): low-level library information.
  static const LogLevel debug = LogLevel._(4);

  /// Port of `LogLevelTrace` (scoped.go:55): very low-level information
  /// (e.g. network traces).
  static const LogLevel trace = LogLevel._(5);

  @override
  int compareTo(LogLevel other) => value.compareTo(other.value);

  bool operator <(LogLevel other) => value < other.value;

  bool operator <=(LogLevel other) => value <= other.value;

  bool operator >(LogLevel other) => value > other.value;

  bool operator >=(LogLevel other) => value >= other.value;

  @override
  bool operator ==(Object other) => other is LogLevel && other.value == value;

  @override
  int get hashCode => value.hashCode;

  /// Port of `LogLevel.String` (scoped.go:23-40).
  @override
  String toString() {
    switch (value) {
      case 0:
        return 'Disabled';
      case 1:
        return 'Error';
      case 2:
        return 'Warn';
      case 3:
        return 'Info';
      case 4:
        return 'Debug';
      case 5:
        return 'Trace';
      default:
        return 'UNKNOWN';
    }
  }
}

/// Port of `LeveledLogger` (scoped.go:59): the basic pion Logger interface.
///
/// `format string, args ...any` (Go's `fmt.Sprintf` verbs) becomes
/// `String format, [List<Object?> args]`; see `logger.dart`'s `_sprintf` for
/// the verb subset supported.
abstract interface class LeveledLogger {
  void trace(String msg);

  void tracef(String format, [List<Object?> args = const []]);

  void debug(String msg);

  void debugf(String format, [List<Object?> args = const []]);

  void info(String msg);

  void infof(String format, [List<Object?> args = const []]);

  void warn(String msg);

  void warnf(String format, [List<Object?> args = const []]);

  void error(String msg);

  void errorf(String format, [List<Object?> args = const []]);
}

/// Port of `LoggerFactory` (scoped.go:73): the basic pion LoggerFactory
/// interface.
abstract interface class LoggerFactory {
  LeveledLogger newLogger(String scope);
}
