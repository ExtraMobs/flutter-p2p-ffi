// Constantes do linux/amd64 (as do `zerrors_linux_amd64.go` do Go e dos
// headers da glibc) usadas pelo `sysffi` e por quem chama a libc por ele.
//
// ⚠️ Só linux (decisão F3). O macOS (etapa E8) muda boa parte delas
// (`SOCK_NONBLOCK` não existe, `SOL_SOCKET` é 0xffff, os `SO_*` e errno são
// outros): entra num `consts_darwin.dart` com os mesmos nomes, escolhido pelo
// `sysFfiSupported`/`Abi` em `sysffi.dart`.
// ignore_for_file: constant_identifier_names

// Famílias.
const AF_UNSPEC = 0;
const AF_UNIX = 1;
const AF_INET = 2;
const AF_INET6 = 10;
const AF_NETLINK = 16;
const AF_PACKET = 17;

// Tipos de socket (+ flags do `socket`/`accept4`).
const SOCK_STREAM = 1;
const SOCK_DGRAM = 2;
const SOCK_RAW = 3;
const SOCK_SEQPACKET = 5;
const SOCK_NONBLOCK = 0x800;
const SOCK_CLOEXEC = 0x80000;

// Níveis e opções.
const SOL_SOCKET = 1;
const SO_REUSEADDR = 2;
const SO_TYPE = 3;
const SO_ERROR = 4;
const SO_BROADCAST = 6;
const SO_SNDBUF = 7;
const SO_RCVBUF = 8;
const SO_KEEPALIVE = 9;
const SO_LINGER = 13;
const SO_REUSEPORT = 15;
const SO_PASSCRED = 16;
const SO_PEERCRED = 17;
const SO_ACCEPTCONN = 30;
const SO_DOMAIN = 39;

const SCM_RIGHTS = 1;
const SCM_CREDENTIALS = 2;

const IPPROTO_IP = 0;
const IPPROTO_ICMP = 1;
const IPPROTO_TCP = 6;
const IPPROTO_UDP = 17;
const IPPROTO_IPV6 = 41;
const IPPROTO_ICMPV6 = 58;

const IP_TOS = 1;
const IP_TTL = 2;
const IP_PKTINFO = 8;
const IP_MTU_DISCOVER = 10;
const IP_RECVTOS = 13;
const IPV6_V6ONLY = 26;
const IPV6_RECVPKTINFO = 49;
const IPV6_RECVTCLASS = 66;
const IPV6_TCLASS = 67;

const TCP_NODELAY = 1;
const TCP_KEEPIDLE = 4;
const TCP_KEEPINTVL = 5;
const TCP_KEEPCNT = 6;

// Flags de `send*`/`recv*`.
const MSG_OOB = 0x1;
const MSG_PEEK = 0x2;
const MSG_CTRUNC = 0x8;
const MSG_TRUNC = 0x20;
const MSG_DONTWAIT = 0x40;
const MSG_WAITALL = 0x100;
const MSG_NOSIGNAL = 0x4000;
const MSG_CMSG_CLOEXEC = 0x40000000;

// `shutdown`.
const SHUT_RD = 0;
const SHUT_WR = 1;
const SHUT_RDWR = 2;

// `fcntl`.
const F_GETFD = 1;
const F_SETFD = 2;
const F_GETFL = 3;
const F_SETFL = 4;
const FD_CLOEXEC = 1;
const O_NONBLOCK = 0x800;

// `poll`.
const POLLIN = 0x1;
const POLLPRI = 0x2;
const POLLOUT = 0x4;
const POLLERR = 0x8;
const POLLHUP = 0x10;
const POLLNVAL = 0x20;
const POLLRDHUP = 0x2000;

// `eventfd`.
const EFD_SEMAPHORE = 0x1;
const EFD_NONBLOCK = 0x800;
const EFD_CLOEXEC = 0x80000;

// errno (numeração do linux; o texto do Go fica no shim `syscall`).
const EPERM = 1;
const ENOENT = 2;
const EINTR = 4;
const EIO = 5;
const EBADF = 9;
const EAGAIN = 11;
const EWOULDBLOCK = EAGAIN;
const ENOMEM = 12;
const EACCES = 13;
const EFAULT = 14;
const EEXIST = 17;
const EINVAL = 22;
const EMFILE = 24;
const EPIPE = 32;
const ENOTSOCK = 88;
const EDESTADDRREQ = 89;
const EMSGSIZE = 90;
const EPROTOTYPE = 91;
const ENOPROTOOPT = 92;
const EPROTONOSUPPORT = 93;
const EOPNOTSUPP = 95;
const EAFNOSUPPORT = 97;
const EADDRINUSE = 98;
const EADDRNOTAVAIL = 99;
const ENETDOWN = 100;
const ENETUNREACH = 101;
const ECONNABORTED = 103;
const ECONNRESET = 104;
const ENOBUFS = 105;
const EISCONN = 106;
const ENOTCONN = 107;
const ETIMEDOUT = 110;
const ECONNREFUSED = 111;
const EHOSTUNREACH = 113;
const EALREADY = 114;
const EINPROGRESS = 115;
