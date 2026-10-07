/// Tabelas de errno do linux (amd64), comuns ao shim `syscall` e à
/// camada `sys` do `net`: a numeração e os textos do Go valem em toda
/// plataforma (o build é `GOOS=linux`).
// Gerado de `syscall/zerrors_linux_amd64.go` do Go 1.26.5 (go/types e
// `Errno.Error()`); não editar à mão.
library;

/// `errors` do Go: texto de cada errno (`''` onde a tabela não tem).
const errnoTexts = <String>[
  '', // 0
  'operation not permitted', // 1
  'no such file or directory', // 2
  'no such process', // 3
  'interrupted system call', // 4
  'input/output error', // 5
  'no such device or address', // 6
  'argument list too long', // 7
  'exec format error', // 8
  'bad file descriptor', // 9
  'no child processes', // 10
  'resource temporarily unavailable', // 11
  'cannot allocate memory', // 12
  'permission denied', // 13
  'bad address', // 14
  'block device required', // 15
  'device or resource busy', // 16
  'file exists', // 17
  'invalid cross-device link', // 18
  'no such device', // 19
  'not a directory', // 20
  'is a directory', // 21
  'invalid argument', // 22
  'too many open files in system', // 23
  'too many open files', // 24
  'inappropriate ioctl for device', // 25
  'text file busy', // 26
  'file too large', // 27
  'no space left on device', // 28
  'illegal seek', // 29
  'read-only file system', // 30
  'too many links', // 31
  'broken pipe', // 32
  'numerical argument out of domain', // 33
  'numerical result out of range', // 34
  'resource deadlock avoided', // 35
  'file name too long', // 36
  'no locks available', // 37
  'function not implemented', // 38
  'directory not empty', // 39
  'too many levels of symbolic links', // 40
  '', // 41
  'no message of desired type', // 42
  'identifier removed', // 43
  'channel number out of range', // 44
  'level 2 not synchronized', // 45
  'level 3 halted', // 46
  'level 3 reset', // 47
  'link number out of range', // 48
  'protocol driver not attached', // 49
  'no CSI structure available', // 50
  'level 2 halted', // 51
  'invalid exchange', // 52
  'invalid request descriptor', // 53
  'exchange full', // 54
  'no anode', // 55
  'invalid request code', // 56
  'invalid slot', // 57
  '', // 58
  'bad font file format', // 59
  'device not a stream', // 60
  'no data available', // 61
  'timer expired', // 62
  'out of streams resources', // 63
  'machine is not on the network', // 64
  'package not installed', // 65
  'object is remote', // 66
  'link has been severed', // 67
  'advertise error', // 68
  'srmount error', // 69
  'communication error on send', // 70
  'protocol error', // 71
  'multihop attempted', // 72
  'RFS specific error', // 73
  'bad message', // 74
  'value too large for defined data type', // 75
  'name not unique on network', // 76
  'file descriptor in bad state', // 77
  'remote address changed', // 78
  'can not access a needed shared library', // 79
  'accessing a corrupted shared library', // 80
  '.lib section in a.out corrupted', // 81
  'attempting to link in too many shared libraries', // 82
  'cannot exec a shared library directly', // 83
  'invalid or incomplete multibyte or wide character', // 84
  'interrupted system call should be restarted', // 85
  'streams pipe error', // 86
  'too many users', // 87
  'socket operation on non-socket', // 88
  'destination address required', // 89
  'message too long', // 90
  'protocol wrong type for socket', // 91
  'protocol not available', // 92
  'protocol not supported', // 93
  'socket type not supported', // 94
  'operation not supported', // 95
  'protocol family not supported', // 96
  'address family not supported by protocol', // 97
  'address already in use', // 98
  'cannot assign requested address', // 99
  'network is down', // 100
  'network is unreachable', // 101
  'network dropped connection on reset', // 102
  'software caused connection abort', // 103
  'connection reset by peer', // 104
  'no buffer space available', // 105
  'transport endpoint is already connected', // 106
  'transport endpoint is not connected', // 107
  'cannot send after transport endpoint shutdown', // 108
  'too many references: cannot splice', // 109
  'connection timed out', // 110
  'connection refused', // 111
  'host is down', // 112
  'no route to host', // 113
  'operation already in progress', // 114
  'operation now in progress', // 115
  'stale file handle', // 116
  'structure needs cleaning', // 117
  'not a XENIX named type file', // 118
  'no XENIX semaphores available', // 119
  'is a named type file', // 120
  'remote I/O error', // 121
  'disk quota exceeded', // 122
  'no medium found', // 123
  'wrong medium type', // 124
  'operation canceled', // 125
  'required key not available', // 126
  'key has expired', // 127
  'key has been revoked', // 128
  'key was rejected by service', // 129
  'owner died', // 130
  'state not recoverable', // 131
  'operation not possible due to RF-kill', // 132
];

/// Número de cada nome de errno (`EWOULDBLOCK` = `EAGAIN`...).
const errnoNumbers = <String, int>{
  'E2BIG': 7,
  'EACCES': 13,
  'EADDRINUSE': 98,
  'EADDRNOTAVAIL': 99,
  'EADV': 68,
  'EAFNOSUPPORT': 97,
  'EAGAIN': 11,
  'EALREADY': 114,
  'EBADE': 52,
  'EBADF': 9,
  'EBADFD': 77,
  'EBADMSG': 74,
  'EBADR': 53,
  'EBADRQC': 56,
  'EBADSLT': 57,
  'EBFONT': 59,
  'EBUSY': 16,
  'ECANCELED': 125,
  'ECHILD': 10,
  'ECHRNG': 44,
  'ECOMM': 70,
  'ECONNABORTED': 103,
  'ECONNREFUSED': 111,
  'ECONNRESET': 104,
  'EDEADLK': 35,
  'EDEADLOCK': 35,
  'EDESTADDRREQ': 89,
  'EDOM': 33,
  'EDOTDOT': 73,
  'EDQUOT': 122,
  'EEXIST': 17,
  'EFAULT': 14,
  'EFBIG': 27,
  'EHOSTDOWN': 112,
  'EHOSTUNREACH': 113,
  'EIDRM': 43,
  'EILSEQ': 84,
  'EINPROGRESS': 115,
  'EINTR': 4,
  'EINVAL': 22,
  'EIO': 5,
  'EISCONN': 106,
  'EISDIR': 21,
  'EISNAM': 120,
  'EKEYEXPIRED': 127,
  'EKEYREJECTED': 129,
  'EKEYREVOKED': 128,
  'EL2HLT': 51,
  'EL2NSYNC': 45,
  'EL3HLT': 46,
  'EL3RST': 47,
  'ELIBACC': 79,
  'ELIBBAD': 80,
  'ELIBEXEC': 83,
  'ELIBMAX': 82,
  'ELIBSCN': 81,
  'ELNRNG': 48,
  'ELOOP': 40,
  'EMEDIUMTYPE': 124,
  'EMFILE': 24,
  'EMLINK': 31,
  'EMSGSIZE': 90,
  'EMULTIHOP': 72,
  'ENAMETOOLONG': 36,
  'ENAVAIL': 119,
  'ENETDOWN': 100,
  'ENETRESET': 102,
  'ENETUNREACH': 101,
  'ENFILE': 23,
  'ENOANO': 55,
  'ENOBUFS': 105,
  'ENOCSI': 50,
  'ENODATA': 61,
  'ENODEV': 19,
  'ENOENT': 2,
  'ENOEXEC': 8,
  'ENOKEY': 126,
  'ENOLCK': 37,
  'ENOLINK': 67,
  'ENOMEDIUM': 123,
  'ENOMEM': 12,
  'ENOMSG': 42,
  'ENONET': 64,
  'ENOPKG': 65,
  'ENOPROTOOPT': 92,
  'ENOSPC': 28,
  'ENOSR': 63,
  'ENOSTR': 60,
  'ENOSYS': 38,
  'ENOTBLK': 15,
  'ENOTCONN': 107,
  'ENOTDIR': 20,
  'ENOTEMPTY': 39,
  'ENOTNAM': 118,
  'ENOTRECOVERABLE': 131,
  'ENOTSOCK': 88,
  'ENOTSUP': 95,
  'ENOTTY': 25,
  'ENOTUNIQ': 76,
  'ENXIO': 6,
  'EOPNOTSUPP': 95,
  'EOVERFLOW': 75,
  'EOWNERDEAD': 130,
  'EPERM': 1,
  'EPFNOSUPPORT': 96,
  'EPIPE': 32,
  'EPROTO': 71,
  'EPROTONOSUPPORT': 93,
  'EPROTOTYPE': 91,
  'ERANGE': 34,
  'EREMCHG': 78,
  'EREMOTE': 66,
  'EREMOTEIO': 121,
  'ERESTART': 85,
  'ERFKILL': 132,
  'EROFS': 30,
  'ESHUTDOWN': 108,
  'ESOCKTNOSUPPORT': 94,
  'ESPIPE': 29,
  'ESRCH': 3,
  'ESRMNT': 69,
  'ESTALE': 116,
  'ESTRPIPE': 86,
  'ETIME': 62,
  'ETIMEDOUT': 110,
  'ETOOMANYREFS': 109,
  'ETXTBSY': 26,
  'EUCLEAN': 117,
  'EUNATCH': 49,
  'EUSERS': 87,
  'EWOULDBLOCK': 11,
  'EXDEV': 18,
  'EXFULL': 54,
};

/// Nome canônico de cada número (o que a camada `sys` usa).
const errnoNames = <int, String>{
  1: 'EPERM',
  2: 'ENOENT',
  3: 'ESRCH',
  4: 'EINTR',
  5: 'EIO',
  6: 'ENXIO',
  7: 'E2BIG',
  8: 'ENOEXEC',
  9: 'EBADF',
  10: 'ECHILD',
  11: 'EAGAIN',
  12: 'ENOMEM',
  13: 'EACCES',
  14: 'EFAULT',
  15: 'ENOTBLK',
  16: 'EBUSY',
  17: 'EEXIST',
  18: 'EXDEV',
  19: 'ENODEV',
  20: 'ENOTDIR',
  21: 'EISDIR',
  22: 'EINVAL',
  23: 'ENFILE',
  24: 'EMFILE',
  25: 'ENOTTY',
  26: 'ETXTBSY',
  27: 'EFBIG',
  28: 'ENOSPC',
  29: 'ESPIPE',
  30: 'EROFS',
  31: 'EMLINK',
  32: 'EPIPE',
  33: 'EDOM',
  34: 'ERANGE',
  35: 'EDEADLK',
  36: 'ENAMETOOLONG',
  37: 'ENOLCK',
  38: 'ENOSYS',
  39: 'ENOTEMPTY',
  40: 'ELOOP',
  42: 'ENOMSG',
  43: 'EIDRM',
  44: 'ECHRNG',
  45: 'EL2NSYNC',
  46: 'EL3HLT',
  47: 'EL3RST',
  48: 'ELNRNG',
  49: 'EUNATCH',
  50: 'ENOCSI',
  51: 'EL2HLT',
  52: 'EBADE',
  53: 'EBADR',
  54: 'EXFULL',
  55: 'ENOANO',
  56: 'EBADRQC',
  57: 'EBADSLT',
  59: 'EBFONT',
  60: 'ENOSTR',
  61: 'ENODATA',
  62: 'ETIME',
  63: 'ENOSR',
  64: 'ENONET',
  65: 'ENOPKG',
  66: 'EREMOTE',
  67: 'ENOLINK',
  68: 'EADV',
  69: 'ESRMNT',
  70: 'ECOMM',
  71: 'EPROTO',
  72: 'EMULTIHOP',
  73: 'EDOTDOT',
  74: 'EBADMSG',
  75: 'EOVERFLOW',
  76: 'ENOTUNIQ',
  77: 'EBADFD',
  78: 'EREMCHG',
  79: 'ELIBACC',
  80: 'ELIBBAD',
  81: 'ELIBSCN',
  82: 'ELIBMAX',
  83: 'ELIBEXEC',
  84: 'EILSEQ',
  85: 'ERESTART',
  86: 'ESTRPIPE',
  87: 'EUSERS',
  88: 'ENOTSOCK',
  89: 'EDESTADDRREQ',
  90: 'EMSGSIZE',
  91: 'EPROTOTYPE',
  92: 'ENOPROTOOPT',
  93: 'EPROTONOSUPPORT',
  94: 'ESOCKTNOSUPPORT',
  95: 'EOPNOTSUPP',
  96: 'EPFNOSUPPORT',
  97: 'EAFNOSUPPORT',
  98: 'EADDRINUSE',
  99: 'EADDRNOTAVAIL',
  100: 'ENETDOWN',
  101: 'ENETUNREACH',
  102: 'ENETRESET',
  103: 'ECONNABORTED',
  104: 'ECONNRESET',
  105: 'ENOBUFS',
  106: 'EISCONN',
  107: 'ENOTCONN',
  108: 'ESHUTDOWN',
  109: 'ETOOMANYREFS',
  110: 'ETIMEDOUT',
  111: 'ECONNREFUSED',
  112: 'EHOSTDOWN',
  113: 'EHOSTUNREACH',
  114: 'EALREADY',
  115: 'EINPROGRESS',
  116: 'ESTALE',
  117: 'EUCLEAN',
  118: 'ENOTNAM',
  119: 'ENAVAIL',
  120: 'EISNAM',
  121: 'EREMOTEIO',
  122: 'EDQUOT',
  123: 'ENOMEDIUM',
  124: 'EMEDIUMTYPE',
  125: 'ECANCELED',
  126: 'ENOKEY',
  127: 'EKEYEXPIRED',
  128: 'EKEYREVOKED',
  129: 'EKEYREJECTED',
  130: 'EOWNERDEAD',
  131: 'ENOTRECOVERABLE',
  132: 'ERFKILL',
};
