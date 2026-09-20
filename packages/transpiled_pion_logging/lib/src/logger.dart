// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `logger.go` (github.com/pion/logging): [DefaultLeveledLogger],
/// [DefaultLoggerFactory] and `NewDefaultLeveledLoggerForScope`.
///
/// Regra 16 forbids `print()` in library code; the default output is
/// `stderr.write`, matching Go's `os.Stderr` default (logger.go:166).
///
/// **Deliberately not ported**:
/// - `loggerWriter`'s `sync.RWMutex` (logger.go:19): guards concurrent
///   `Write`/`SetOutput` calls from multiple goroutines. A Dart isolate has
///   no shared-memory threads, so the private `_LoggerWriter` below carries
///   no lock.
/// - `WithTraceLogger`/`WithDebugLogger`/`WithInfoLogger`/`WithWarnLogger`/
///   `WithErrorLogger` (logger.go:50-94): these inject a Go `*log.Logger`
///   per level, a type with no Dart equivalent. No consumer in this
///   codebase calls them (pion/sctp only uses [LeveledLogger],
///   [LoggerFactory] and `DefaultLoggerFactory()`); the five per-level
///   `log.Logger`s they configure are collapsed into one internal
///   formatter ([_log]) that reproduces the same line prefixes
///   (`"{scope} TRACE: "`, `"{scope} DEBUG: "`, etc.).
/// - `log.Lshortfile` (the caller's file:line) on the trace/debug loggers:
///   Dart has no cheap way to capture the caller's source location without
///   walking a [StackTrace] on every call. This is a known, documented
///   simplification, not a silent one -- trace/debug lines still carry a
///   microsecond timestamp (matching `log.Lmicroseconds`), just not the
///   file:line suffix.
library;

import 'dart:io';

import 'scoped.dart';

/// Wraps the destination [StringSink] so it can be swapped at runtime via
/// [DefaultLeveledLogger.withOutput]. Port of `loggerWriter` (logger.go:18),
/// minus the mutex -- see the file-level doc comment.
class _LoggerWriter {
  _LoggerWriter(this._output);

  StringSink _output;

  void setOutput(StringSink output) => _output = output;

  void write(String data) => _output.write(data);
}

/// Formats a Go `fmt.Sprintf`-style `format` string against `args`,
/// supporting the verb subset pion's own call sites emit: `%v` (default
/// representation), `%s`, `%d`, `%x` (hex), `%t`, `%q` (quoted) and the
/// literal `%%`. An unmatched verb (more verbs than args) renders as Go does
/// for a missing argument: `%!<verb>(MISSING)`.
///
/// No Go symbol corresponds to this helper (Go gets `fmt.Sprintf` from the
/// standard library), so it is private per the project's auxiliary-symbol
/// convention.
String _formatLogMessage(String format, List<Object?> args) {
  if (args.isEmpty) return format;
  var argIndex = 0;
  final buffer = StringBuffer();
  var i = 0;
  while (i < format.length) {
    final char = format[i];
    if (char == '%' && i + 1 < format.length) {
      final verb = format[i + 1];
      if (verb == '%') {
        buffer.write('%');
        i += 2;
        continue;
      }
      if ('vsdxtq'.contains(verb)) {
        if (argIndex < args.length) {
          buffer.write(_formatVerb(verb, args[argIndex++]));
        } else {
          buffer.write('%!$verb(MISSING)');
        }
        i += 2;
        continue;
      }
    }
    buffer.write(char);
    i++;
  }
  return buffer.toString();
}

String _formatVerb(String verb, Object? arg) {
  switch (verb) {
    case 'd':
      return arg is int ? arg.toString() : '$arg';
    case 'x':
      return arg is int ? arg.toRadixString(16) : '$arg';
    case 'q':
      return '"$arg"';
    default:
      return '$arg';
  }
}

String _twoDigits(int n) => n.toString().padLeft(2, '0');

/// Port of the `log.LstdFlags` prefix (`"2009/01/23 01:23:23 "`) used for
/// the info/warn/error loggers (logger.go:176-178).
String _stdTimestamp(DateTime now) =>
    '${now.year}/${_twoDigits(now.month)}/${_twoDigits(now.day)} '
    '${_twoDigits(now.hour)}:${_twoDigits(now.minute)}:${_twoDigits(now.second)} ';

/// Port of the `log.Lmicroseconds` prefix used for the trace/debug loggers
/// (logger.go:174-175); the `log.Lshortfile` suffix is dropped, see the
/// file-level doc comment.
String _microTimestamp(DateTime now) =>
    '${_twoDigits(now.hour)}:${_twoDigits(now.minute)}:${_twoDigits(now.second)}.'
    '${(now.microsecond + now.millisecond * 1000).toString().padLeft(6, '0')} ';

/// Port of `DefaultLeveledLogger` (logger.go:38): logging at user-defined
/// levels.
final class DefaultLeveledLogger implements LeveledLogger {
  DefaultLeveledLogger._(this._scope, this._level, StringSink writer)
      : _writer = _LoggerWriter(writer);

  /// Port of `NewDefaultLeveledLoggerForScope` (logger.go:164-179).
  factory DefaultLeveledLogger.forScope(
    String scope,
    LogLevel level, [
    StringSink? writer,
  ]) => DefaultLeveledLogger._(scope, level, writer ?? stderr);

  final String _scope;
  LogLevel _level;
  final _LoggerWriter _writer;

  /// Port of `DefaultLeveledLogger.WithOutput` (logger.go:90-94), minus the
  /// Go chainable-`With*` naming (see the file-level doc comment): sets the
  /// destination and returns `this` for chaining.
  DefaultLeveledLogger withOutput(StringSink output) {
    _writer.setOutput(output);
    return this;
  }

  /// Port of `DefaultLeveledLogger.SetLevel` (logger.go:109-111).
  void setLevel(LogLevel newLevel) => _level = newLevel;

  void _log(String label, LogLevel level, bool micro, String format, List<Object?> args) {
    if (_level.value < level.value) return;
    final msg = _formatLogMessage(format, args);
    final timestamp = micro ? _microTimestamp(DateTime.now()) : _stdTimestamp(DateTime.now());
    _writer.write('$_scope $label: $timestamp$msg\n');
  }

  /// Port of `DefaultLeveledLogger.Trace` (logger.go:114-116).
  @override
  void trace(String msg) => _log('TRACE', LogLevel.trace, true, msg, const []);

  /// Port of `DefaultLeveledLogger.Tracef` (logger.go:119-121).
  @override
  void tracef(String format, [List<Object?> args = const []]) =>
      _log('TRACE', LogLevel.trace, true, format, args);

  /// Port of `DefaultLeveledLogger.Debug` (logger.go:124-126).
  @override
  void debug(String msg) => _log('DEBUG', LogLevel.debug, true, msg, const []);

  /// Port of `DefaultLeveledLogger.Debugf` (logger.go:129-131).
  @override
  void debugf(String format, [List<Object?> args = const []]) =>
      _log('DEBUG', LogLevel.debug, true, format, args);

  /// Port of `DefaultLeveledLogger.Info` (logger.go:134-136).
  @override
  void info(String msg) => _log('INFO', LogLevel.info, false, msg, const []);

  /// Port of `DefaultLeveledLogger.Infof` (logger.go:139-141).
  @override
  void infof(String format, [List<Object?> args = const []]) =>
      _log('INFO', LogLevel.info, false, format, args);

  /// Port of `DefaultLeveledLogger.Warn` (logger.go:144-146).
  @override
  void warn(String msg) => _log('WARNING', LogLevel.warn, false, msg, const []);

  /// Port of `DefaultLeveledLogger.Warnf` (logger.go:149-151).
  @override
  void warnf(String format, [List<Object?> args = const []]) =>
      _log('WARNING', LogLevel.warn, false, format, args);

  /// Port of `DefaultLeveledLogger.Error` (logger.go:154-156).
  @override
  void error(String msg) => _log('ERROR', LogLevel.error, false, msg, const []);

  /// Port of `DefaultLeveledLogger.Errorf` (logger.go:159-161).
  @override
  void errorf(String format, [List<Object?> args = const []]) =>
      _log('ERROR', LogLevel.error, false, format, args);
}

/// Port of `DefaultLoggerFactory` (logger.go:182): defines levels by scope
/// and creates [DefaultLeveledLogger]s.
final class DefaultLoggerFactory implements LoggerFactory {
  /// Port of `NewDefaultLoggerFactory` (logger.go:189-230): reads
  /// `PION_LOG_<LEVEL>`/`PIONS_LOG_<LEVEL>` environment variables (`ALL` or
  /// a comma-separated scope list) to seed [defaultLogLevel] and
  /// [scopeLevels].
  DefaultLoggerFactory() : writer = stderr, defaultLogLevel = LogLevel.error, scopeLevels = {} {
    const logLevels = <String, LogLevel>{
      'DISABLE': LogLevel.disabled,
      'ERROR': LogLevel.error,
      'WARN': LogLevel.warn,
      'INFO': LogLevel.info,
      'DEBUG': LogLevel.debug,
      'TRACE': LogLevel.trace,
    };

    for (final entry in logLevels.entries) {
      var env = Platform.environment['PION_LOG_${entry.key}'];
      if (env == null || env.isEmpty) {
        env = Platform.environment['PIONS_LOG_${entry.key}'];
      }
      if (env == null || env.isEmpty) continue;

      if (env.toLowerCase() == 'all') {
        if (defaultLogLevel < entry.value) {
          defaultLogLevel = entry.value;
        }
        continue;
      }

      for (final scope in env.toLowerCase().split(',')) {
        scopeLevels[scope] = entry.value;
      }
    }
  }

  /// Port of `DefaultLoggerFactory.Writer` (logger.go:183).
  StringSink writer;

  /// Port of `DefaultLoggerFactory.DefaultLogLevel` (logger.go:184).
  LogLevel defaultLogLevel;

  /// Port of `DefaultLoggerFactory.ScopeLevels` (logger.go:185).
  final Map<String, LogLevel> scopeLevels;

  /// Port of `DefaultLoggerFactory.NewLogger` (logger.go:233-244).
  @override
  LeveledLogger newLogger(String scope) {
    final logLevel = scopeLevels[scope] ?? defaultLogLevel;
    return DefaultLeveledLogger.forScope(scope, logLevel, writer);
  }
}
