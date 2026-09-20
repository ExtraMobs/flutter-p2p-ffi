// ignore_for_file: public_member_api_docs
/// Port of github.com/pion/logging revision fixed in
/// doc/transpilation/UPSTREAM_LOCK.md (v0.2.4).
///
/// Ported: `scoped.go` ([LogLevel], [LeveledLogger], [LoggerFactory]) and
/// `logger.go` ([DefaultLeveledLogger], [DefaultLoggerFactory]).
///
/// Deliberately not ported, each documented at its own would-be call site:
/// `LogLevel.Set`/`.Get`'s `sync/atomic` usage (scoped.dart), the
/// `sync.RWMutex` inside `loggerWriter` and the `WithTraceLogger`/
/// `WithDebugLogger`/`WithInfoLogger`/`WithWarnLogger`/`WithErrorLogger`
/// chainable `*log.Logger` injectors, which have no Dart equivalent and no
/// consumer in this codebase (logger.dart). The `log.Lshortfile` caller
/// file:line on trace/debug output is a known, documented gap (logger.dart).
library;

export 'src/logger.dart' show DefaultLeveledLogger, DefaultLoggerFactory;
export 'src/scoped.dart' show LeveledLogger, LogLevel, LoggerFactory;
