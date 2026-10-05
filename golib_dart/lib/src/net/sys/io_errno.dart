part of 'sys_io.dart';

// errno numérico do SO → nome; o texto vem de `errnoText` (o do Go no
// linux), em qualquer SO.

const _linuxErrno = <int, String>{
  2: 'ENOENT', 20: 'ENOTDIR', 21: 'EISDIR', 30: 'EROFS', //
  36: 'ENAMETOOLONG', 40: 'ELOOP', 88: 'ENOTSOCK',
  1: 'EPERM', 4: 'EINTR', 9: 'EBADF', 11: 'EAGAIN', 12: 'ENOMEM', //
  13: 'EACCES', 22: 'EINVAL', 23: 'ENFILE', 24: 'EMFILE', 32: 'EPIPE',
  90: 'EMSGSIZE', 93: 'EPROTONOSUPPORT', 95: 'EOPNOTSUPP',
  97: 'EAFNOSUPPORT', 98: 'EADDRINUSE', 99: 'EADDRNOTAVAIL',
  100: 'ENETDOWN', 101: 'ENETUNREACH', 103: 'ECONNABORTED',
  104: 'ECONNRESET', 105: 'ENOBUFS', 106: 'EISCONN', 107: 'ENOTCONN',
  110: 'ETIMEDOUT', 111: 'ECONNREFUSED', 112: 'EHOSTDOWN',
  113: 'EHOSTUNREACH', 114: 'EALREADY', 115: 'EINPROGRESS',
};

const _darwinErrno = <int, String>{
  2: 'ENOENT', 20: 'ENOTDIR', 21: 'EISDIR', 30: 'EROFS', //
  63: 'ENAMETOOLONG', 62: 'ELOOP', 38: 'ENOTSOCK',
  1: 'EPERM', 4: 'EINTR', 9: 'EBADF', 35: 'EAGAIN', 12: 'ENOMEM', //
  13: 'EACCES', 22: 'EINVAL', 23: 'ENFILE', 24: 'EMFILE', 32: 'EPIPE',
  40: 'EMSGSIZE', 43: 'EPROTONOSUPPORT', 45: 'EOPNOTSUPP',
  102: 'EOPNOTSUPP', 47: 'EAFNOSUPPORT', 48: 'EADDRINUSE',
  49: 'EADDRNOTAVAIL', 50: 'ENETDOWN', 51: 'ENETUNREACH',
  53: 'ECONNABORTED', 54: 'ECONNRESET', 55: 'ENOBUFS', 56: 'EISCONN',
  57: 'ENOTCONN', 60: 'ETIMEDOUT', 61: 'ECONNREFUSED', 64: 'EHOSTDOWN',
  65: 'EHOSTUNREACH', 37: 'EALREADY', 36: 'EINPROGRESS',
};

const _windowsErrno = <int, String>{
  2: 'ENOENT', 10038: 'ENOTSOCK', 10063: 'ENAMETOOLONG', //
  10013: 'EACCES', 10022: 'EINVAL', 10024: 'EMFILE', 10035: 'EAGAIN', //
  10036: 'EINPROGRESS', 10037: 'EALREADY', 10040: 'EMSGSIZE',
  10043: 'EPROTONOSUPPORT', 10045: 'EOPNOTSUPP', 10047: 'EAFNOSUPPORT',
  10048: 'EADDRINUSE', 10049: 'EADDRNOTAVAIL', 10050: 'ENETDOWN',
  10051: 'ENETUNREACH', 10053: 'ECONNABORTED', 10054: 'ECONNRESET',
  10055: 'ENOBUFS', 10056: 'EISCONN', 10057: 'ENOTCONN',
  10060: 'ETIMEDOUT', 10061: 'ECONNREFUSED', 10064: 'EHOSTDOWN',
  10065: 'EHOSTUNREACH',
};

final Map<int, String> _errnoNames = Platform.isWindows
    ? _windowsErrno
    : (Platform.isMacOS || Platform.isIOS)
    ? _darwinErrno
    : _linuxErrno;

/// Qualquer falha de uma operação de I/O → exceção do motor. [written]: o
/// que um `write` já tinha entregue.
SysException _mapIo(Object e, String syscall, {int written = 0}) {
  switch (e) {
    case SysException():
      return e;
    case NetClosingException():
      return SysClosed(written);
    case DeadlineExceededException():
      return SysTimeout(written);
    case SocketException(:final osError, :final message):
      final errno = osError?.errorCode ?? 0;
      final code = _errnoNames[errno];
      if (code != null) {
        return SysError.errno(syscall, code, written: written);
      }
      // O `dart:io` recusa sozinho um segundo bind no mesmo (ip, porta) do
      // mesmo processo, sem errno: é o EADDRINUSE do Go.
      if (message.contains('shared flag') ||
          (osError?.message.contains('shared flag') ?? false)) {
        return SysError.errno('bind', 'EADDRINUSE', written: written);
      }
      final text = osError?.message ?? message;
      return SysError(syscall, 'EOTHER', text.toLowerCase(), written: written);
    default:
      return SysError(syscall, 'EOTHER', '$e', written: written);
  }
}

/// Erro de `listen`/`bind` com a syscall que o Go mostraria.
SysException _mapBind(Object e, String otherwise) {
  final m = _mapIo(e, otherwise);
  if (m is SysError &&
      const {'EADDRINUSE', 'EADDRNOTAVAIL', 'EACCES'}.contains(m.code)) {
    return SysError('bind', m.code, m.message);
  }
  return m;
}
