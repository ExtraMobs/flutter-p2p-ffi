part of '../../os.dart';

/// `os.ErrInvalid` (`fs.ErrInvalid`).
final GoError errInvalid = fs.errInvalid;

/// `os.ErrPermission`.
final GoError errPermission = fs.errPermission;

/// `os.ErrExist`.
final GoError errExist = fs.errExist;

/// `os.ErrNotExist`.
final GoError errNotExist = fs.errNotExist;

/// `os.ErrClosed`.
final GoError errClosed = fs.errClosed;

/// `os.ErrNoDeadline`.
final GoError errNoDeadline = ErrorString(
  Golang.String.fromDart('file type does not support deadline'),
);

/// `*poll.DeadlineExceededError`.
final class _DeadlineExceeded
    implements GoError, fs.TimeoutError, Golang.GoTyped {
  @override
  Golang.String error() => Golang.String.fromDart('i/o timeout');

  @override
  bool timeout() => true;

  bool temporary() => true;

  @override
  String get $goType => '*poll.DeadlineExceededError';

  @override
  List<String> get $methods => const ['Error', 'Temporary', 'Timeout'];
}

/// `os.ErrDeadlineExceeded`.
final GoError errDeadlineExceeded = _DeadlineExceeded();

GoError? _underlying(GoError? err) => err is fs.PathError ? err.err : err;

bool _underlyingIs(GoError? err, GoError target) =>
    identical(_underlying(err), target);

/// `os.IsExist(err)`.
bool isExist(GoError? err) => _underlyingIs(err, errExist);

/// `os.IsNotExist(err)`.
bool isNotExist(GoError? err) => _underlyingIs(err, errNotExist);

/// `os.IsPermission(err)`.
bool isPermission(GoError? err) => _underlyingIs(err, errPermission);

/// `os.IsTimeout(err)`.
bool isTimeout(GoError? err) => switch (_underlying(err)) {
  final fs.TimeoutError t => t.timeout(),
  _ => false,
};
