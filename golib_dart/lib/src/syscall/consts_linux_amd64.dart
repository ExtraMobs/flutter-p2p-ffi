part of '../../syscall.dart';

// Gerado de `syscall/zerrors_linux_amd64.go` do Go 1.26.5 (go/types e
// `Errno.Error()`); não editar à mão.
//
// Nomes como o g2d os gera (`top_member_name`: `AF_INET` → `af_INET`).
// O código gerado não os cita (o g2d dobra toda constante de outro
// pacote no literal); servem aos shims escritos à mão.

// ------------------------------------------------------------ errno

/// `syscall.E2BIG`.
const e2BIG = Errno._(0, 7);

/// `syscall.EACCES`.
const eacces = Errno._(0, 13);

/// `syscall.EADDRINUSE`.
const eaddrinuse = Errno._(0, 98);

/// `syscall.EADDRNOTAVAIL`.
const eaddrnotavail = Errno._(0, 99);

/// `syscall.EADV`.
const eadv = Errno._(0, 68);

/// `syscall.EAFNOSUPPORT`.
const eafnosupport = Errno._(0, 97);

/// `syscall.EAGAIN`.
const eagain = Errno._(0, 11);

/// `syscall.EALREADY`.
const ealready = Errno._(0, 114);

/// `syscall.EBADE`.
const ebade = Errno._(0, 52);

/// `syscall.EBADF`.
const ebadf = Errno._(0, 9);

/// `syscall.EBADFD`.
const ebadfd = Errno._(0, 77);

/// `syscall.EBADMSG`.
const ebadmsg = Errno._(0, 74);

/// `syscall.EBADR`.
const ebadr = Errno._(0, 53);

/// `syscall.EBADRQC`.
const ebadrqc = Errno._(0, 56);

/// `syscall.EBADSLT`.
const ebadslt = Errno._(0, 57);

/// `syscall.EBFONT`.
const ebfont = Errno._(0, 59);

/// `syscall.EBUSY`.
const ebusy = Errno._(0, 16);

/// `syscall.ECANCELED`.
const ecanceled = Errno._(0, 125);

/// `syscall.ECHILD`.
const echild = Errno._(0, 10);

/// `syscall.ECHRNG`.
const echrng = Errno._(0, 44);

/// `syscall.ECOMM`.
const ecomm = Errno._(0, 70);

/// `syscall.ECONNABORTED`.
const econnaborted = Errno._(0, 103);

/// `syscall.ECONNREFUSED`.
const econnrefused = Errno._(0, 111);

/// `syscall.ECONNRESET`.
const econnreset = Errno._(0, 104);

/// `syscall.EDEADLK`.
const edeadlk = Errno._(0, 35);

/// `syscall.EDEADLOCK`.
const edeadlock = Errno._(0, 35);

/// `syscall.EDESTADDRREQ`.
const edestaddrreq = Errno._(0, 89);

/// `syscall.EDOM`.
const edom = Errno._(0, 33);

/// `syscall.EDOTDOT`.
const edotdot = Errno._(0, 73);

/// `syscall.EDQUOT`.
const edquot = Errno._(0, 122);

/// `syscall.EEXIST`.
const eexist = Errno._(0, 17);

/// `syscall.EFAULT`.
const efault = Errno._(0, 14);

/// `syscall.EFBIG`.
const efbig = Errno._(0, 27);

/// `syscall.EHOSTDOWN`.
const ehostdown = Errno._(0, 112);

/// `syscall.EHOSTUNREACH`.
const ehostunreach = Errno._(0, 113);

/// `syscall.EIDRM`.
const eidrm = Errno._(0, 43);

/// `syscall.EILSEQ`.
const eilseq = Errno._(0, 84);

/// `syscall.EINPROGRESS`.
const einprogress = Errno._(0, 115);

/// `syscall.EINTR`.
const eintr = Errno._(0, 4);

/// `syscall.EINVAL`.
const einval = Errno._(0, 22);

/// `syscall.EIO`.
const eio = Errno._(0, 5);

/// `syscall.EISCONN`.
const eisconn = Errno._(0, 106);

/// `syscall.EISDIR`.
const eisdir = Errno._(0, 21);

/// `syscall.EISNAM`.
const eisnam = Errno._(0, 120);

/// `syscall.EKEYEXPIRED`.
const ekeyexpired = Errno._(0, 127);

/// `syscall.EKEYREJECTED`.
const ekeyrejected = Errno._(0, 129);

/// `syscall.EKEYREVOKED`.
const ekeyrevoked = Errno._(0, 128);

/// `syscall.EL2HLT`.
const el2HLT = Errno._(0, 51);

/// `syscall.EL2NSYNC`.
const el2NSYNC = Errno._(0, 45);

/// `syscall.EL3HLT`.
const el3HLT = Errno._(0, 46);

/// `syscall.EL3RST`.
const el3RST = Errno._(0, 47);

/// `syscall.ELIBACC`.
const elibacc = Errno._(0, 79);

/// `syscall.ELIBBAD`.
const elibbad = Errno._(0, 80);

/// `syscall.ELIBEXEC`.
const elibexec = Errno._(0, 83);

/// `syscall.ELIBMAX`.
const elibmax = Errno._(0, 82);

/// `syscall.ELIBSCN`.
const elibscn = Errno._(0, 81);

/// `syscall.ELNRNG`.
const elnrng = Errno._(0, 48);

/// `syscall.ELOOP`.
const eloop = Errno._(0, 40);

/// `syscall.EMEDIUMTYPE`.
const emediumtype = Errno._(0, 124);

/// `syscall.EMFILE`.
const emfile = Errno._(0, 24);

/// `syscall.EMLINK`.
const emlink = Errno._(0, 31);

/// `syscall.EMSGSIZE`.
const emsgsize = Errno._(0, 90);

/// `syscall.EMULTIHOP`.
const emultihop = Errno._(0, 72);

/// `syscall.ENAMETOOLONG`.
const enametoolong = Errno._(0, 36);

/// `syscall.ENAVAIL`.
const enavail = Errno._(0, 119);

/// `syscall.ENETDOWN`.
const enetdown = Errno._(0, 100);

/// `syscall.ENETRESET`.
const enetreset = Errno._(0, 102);

/// `syscall.ENETUNREACH`.
const enetunreach = Errno._(0, 101);

/// `syscall.ENFILE`.
const enfile = Errno._(0, 23);

/// `syscall.ENOANO`.
const enoano = Errno._(0, 55);

/// `syscall.ENOBUFS`.
const enobufs = Errno._(0, 105);

/// `syscall.ENOCSI`.
const enocsi = Errno._(0, 50);

/// `syscall.ENODATA`.
const enodata = Errno._(0, 61);

/// `syscall.ENODEV`.
const enodev = Errno._(0, 19);

/// `syscall.ENOENT`.
const enoent = Errno._(0, 2);

/// `syscall.ENOEXEC`.
const enoexec = Errno._(0, 8);

/// `syscall.ENOKEY`.
const enokey = Errno._(0, 126);

/// `syscall.ENOLCK`.
const enolck = Errno._(0, 37);

/// `syscall.ENOLINK`.
const enolink = Errno._(0, 67);

/// `syscall.ENOMEDIUM`.
const enomedium = Errno._(0, 123);

/// `syscall.ENOMEM`.
const enomem = Errno._(0, 12);

/// `syscall.ENOMSG`.
const enomsg = Errno._(0, 42);

/// `syscall.ENONET`.
const enonet = Errno._(0, 64);

/// `syscall.ENOPKG`.
const enopkg = Errno._(0, 65);

/// `syscall.ENOPROTOOPT`.
const enoprotoopt = Errno._(0, 92);

/// `syscall.ENOSPC`.
const enospc = Errno._(0, 28);

/// `syscall.ENOSR`.
const enosr = Errno._(0, 63);

/// `syscall.ENOSTR`.
const enostr = Errno._(0, 60);

/// `syscall.ENOSYS`.
const enosys = Errno._(0, 38);

/// `syscall.ENOTBLK`.
const enotblk = Errno._(0, 15);

/// `syscall.ENOTCONN`.
const enotconn = Errno._(0, 107);

/// `syscall.ENOTDIR`.
const enotdir = Errno._(0, 20);

/// `syscall.ENOTEMPTY`.
const enotempty = Errno._(0, 39);

/// `syscall.ENOTNAM`.
const enotnam = Errno._(0, 118);

/// `syscall.ENOTRECOVERABLE`.
const enotrecoverable = Errno._(0, 131);

/// `syscall.ENOTSOCK`.
const enotsock = Errno._(0, 88);

/// `syscall.ENOTSUP`.
const enotsup = Errno._(0, 95);

/// `syscall.ENOTTY`.
const enotty = Errno._(0, 25);

/// `syscall.ENOTUNIQ`.
const enotuniq = Errno._(0, 76);

/// `syscall.ENXIO`.
const enxio = Errno._(0, 6);

/// `syscall.EOPNOTSUPP`.
const eopnotsupp = Errno._(0, 95);

/// `syscall.EOVERFLOW`.
const eoverflow = Errno._(0, 75);

/// `syscall.EOWNERDEAD`.
const eownerdead = Errno._(0, 130);

/// `syscall.EPERM`.
const eperm = Errno._(0, 1);

/// `syscall.EPFNOSUPPORT`.
const epfnosupport = Errno._(0, 96);

/// `syscall.EPIPE`.
const epipe = Errno._(0, 32);

/// `syscall.EPROTO`.
const eproto = Errno._(0, 71);

/// `syscall.EPROTONOSUPPORT`.
const eprotonosupport = Errno._(0, 93);

/// `syscall.EPROTOTYPE`.
const eprototype = Errno._(0, 91);

/// `syscall.ERANGE`.
const erange = Errno._(0, 34);

/// `syscall.EREMCHG`.
const eremchg = Errno._(0, 78);

/// `syscall.EREMOTE`.
const eremote = Errno._(0, 66);

/// `syscall.EREMOTEIO`.
const eremoteio = Errno._(0, 121);

/// `syscall.ERESTART`.
const erestart = Errno._(0, 85);

/// `syscall.ERFKILL`.
const erfkill = Errno._(0, 132);

/// `syscall.EROFS`.
const erofs = Errno._(0, 30);

/// `syscall.ESHUTDOWN`.
const eshutdown = Errno._(0, 108);

/// `syscall.ESOCKTNOSUPPORT`.
const esocktnosupport = Errno._(0, 94);

/// `syscall.ESPIPE`.
const espipe = Errno._(0, 29);

/// `syscall.ESRCH`.
const esrch = Errno._(0, 3);

/// `syscall.ESRMNT`.
const esrmnt = Errno._(0, 69);

/// `syscall.ESTALE`.
const estale = Errno._(0, 116);

/// `syscall.ESTRPIPE`.
const estrpipe = Errno._(0, 86);

/// `syscall.ETIME`.
const etime = Errno._(0, 62);

/// `syscall.ETIMEDOUT`.
const etimedout = Errno._(0, 110);

/// `syscall.ETOOMANYREFS`.
const etoomanyrefs = Errno._(0, 109);

/// `syscall.ETXTBSY`.
const etxtbsy = Errno._(0, 26);

/// `syscall.EUCLEAN`.
const euclean = Errno._(0, 117);

/// `syscall.EUNATCH`.
const eunatch = Errno._(0, 49);

/// `syscall.EUSERS`.
const eusers = Errno._(0, 87);

/// `syscall.EWOULDBLOCK`.
const ewouldblock = Errno._(0, 11);

/// `syscall.EXDEV`.
const exdev = Errno._(0, 18);

/// `syscall.EXFULL`.
const exfull = Errno._(0, 54);

// ------------------------------------------------------------ rede

/// `syscall.AF_ALG`.
const af_ALG = 0x26;

/// `syscall.AF_APPLETALK`.
const af_APPLETALK = 5;

/// `syscall.AF_ASH`.
const af_ASH = 0x12;

/// `syscall.AF_ATMPVC`.
const af_ATMPVC = 8;

/// `syscall.AF_ATMSVC`.
const af_ATMSVC = 0x14;

/// `syscall.AF_AX25`.
const af_AX25 = 3;

/// `syscall.AF_BLUETOOTH`.
const af_BLUETOOTH = 0x1f;

/// `syscall.AF_BRIDGE`.
const af_BRIDGE = 7;

/// `syscall.AF_CAIF`.
const af_CAIF = 0x25;

/// `syscall.AF_CAN`.
const af_CAN = 0x1d;

/// `syscall.AF_DECnet`.
const af_DECnet = 0xc;

/// `syscall.AF_ECONET`.
const af_ECONET = 0x13;

/// `syscall.AF_FILE`.
const af_FILE = 1;

/// `syscall.AF_IEEE802154`.
const af_IEEE802154 = 0x24;

/// `syscall.AF_INET`.
const af_INET = 2;

/// `syscall.AF_INET6`.
const af_INET6 = 0xa;

/// `syscall.AF_IPX`.
const af_IPX = 4;

/// `syscall.AF_IRDA`.
const af_IRDA = 0x17;

/// `syscall.AF_ISDN`.
const af_ISDN = 0x22;

/// `syscall.AF_IUCV`.
const af_IUCV = 0x20;

/// `syscall.AF_KEY`.
const af_KEY = 0xf;

/// `syscall.AF_LLC`.
const af_LLC = 0x1a;

/// `syscall.AF_LOCAL`.
const af_LOCAL = 1;

/// `syscall.AF_MAX`.
const af_MAX = 0x27;

/// `syscall.AF_NETBEUI`.
const af_NETBEUI = 0xd;

/// `syscall.AF_NETLINK`.
const af_NETLINK = 0x10;

/// `syscall.AF_NETROM`.
const af_NETROM = 6;

/// `syscall.AF_PACKET`.
const af_PACKET = 0x11;

/// `syscall.AF_PHONET`.
const af_PHONET = 0x23;

/// `syscall.AF_PPPOX`.
const af_PPPOX = 0x18;

/// `syscall.AF_RDS`.
const af_RDS = 0x15;

/// `syscall.AF_ROSE`.
const af_ROSE = 0xb;

/// `syscall.AF_ROUTE`.
const af_ROUTE = 0x10;

/// `syscall.AF_RXRPC`.
const af_RXRPC = 0x21;

/// `syscall.AF_SECURITY`.
const af_SECURITY = 0xe;

/// `syscall.AF_SNA`.
const af_SNA = 0x16;

/// `syscall.AF_TIPC`.
const af_TIPC = 0x1e;

/// `syscall.AF_UNIX`.
const af_UNIX = 1;

/// `syscall.AF_UNSPEC`.
const af_UNSPEC = 0;

/// `syscall.AF_WANPIPE`.
const af_WANPIPE = 0x19;

/// `syscall.AF_X25`.
const af_X25 = 9;

/// `syscall.IPPROTO_AH`.
const ipproto_AH = 0x33;

/// `syscall.IPPROTO_COMP`.
const ipproto_COMP = 0x6c;

/// `syscall.IPPROTO_DCCP`.
const ipproto_DCCP = 0x21;

/// `syscall.IPPROTO_DSTOPTS`.
const ipproto_DSTOPTS = 0x3c;

/// `syscall.IPPROTO_EGP`.
const ipproto_EGP = 8;

/// `syscall.IPPROTO_ENCAP`.
const ipproto_ENCAP = 0x62;

/// `syscall.IPPROTO_ESP`.
const ipproto_ESP = 0x32;

/// `syscall.IPPROTO_FRAGMENT`.
const ipproto_FRAGMENT = 0x2c;

/// `syscall.IPPROTO_GRE`.
const ipproto_GRE = 0x2f;

/// `syscall.IPPROTO_HOPOPTS`.
const ipproto_HOPOPTS = 0;

/// `syscall.IPPROTO_ICMP`.
const ipproto_ICMP = 1;

/// `syscall.IPPROTO_ICMPV6`.
const ipproto_ICMPV6 = 0x3a;

/// `syscall.IPPROTO_IDP`.
const ipproto_IDP = 0x16;

/// `syscall.IPPROTO_IGMP`.
const ipproto_IGMP = 2;

/// `syscall.IPPROTO_IP`.
const ipproto_IP = 0;

/// `syscall.IPPROTO_IPIP`.
const ipproto_IPIP = 4;

/// `syscall.IPPROTO_IPV6`.
const ipproto_IPV6 = 0x29;

/// `syscall.IPPROTO_MTP`.
const ipproto_MTP = 0x5c;

/// `syscall.IPPROTO_NONE`.
const ipproto_NONE = 0x3b;

/// `syscall.IPPROTO_PIM`.
const ipproto_PIM = 0x67;

/// `syscall.IPPROTO_PUP`.
const ipproto_PUP = 0xc;

/// `syscall.IPPROTO_RAW`.
const ipproto_RAW = 0xff;

/// `syscall.IPPROTO_ROUTING`.
const ipproto_ROUTING = 0x2b;

/// `syscall.IPPROTO_RSVP`.
const ipproto_RSVP = 0x2e;

/// `syscall.IPPROTO_SCTP`.
const ipproto_SCTP = 0x84;

/// `syscall.IPPROTO_TCP`.
const ipproto_TCP = 6;

/// `syscall.IPPROTO_TP`.
const ipproto_TP = 0x1d;

/// `syscall.IPPROTO_UDP`.
const ipproto_UDP = 0x11;

/// `syscall.IPPROTO_UDPLITE`.
const ipproto_UDPLITE = 0x88;

/// `syscall.IPV6_2292DSTOPTS`.
const ipv6_2292DSTOPTS = 4;

/// `syscall.IPV6_2292HOPLIMIT`.
const ipv6_2292HOPLIMIT = 8;

/// `syscall.IPV6_2292HOPOPTS`.
const ipv6_2292HOPOPTS = 3;

/// `syscall.IPV6_2292PKTINFO`.
const ipv6_2292PKTINFO = 2;

/// `syscall.IPV6_2292PKTOPTIONS`.
const ipv6_2292PKTOPTIONS = 6;

/// `syscall.IPV6_2292RTHDR`.
const ipv6_2292RTHDR = 5;

/// `syscall.IPV6_ADDRFORM`.
const ipv6_ADDRFORM = 1;

/// `syscall.IPV6_ADD_MEMBERSHIP`.
const ipv6_ADD_MEMBERSHIP = 0x14;

/// `syscall.IPV6_AUTHHDR`.
const ipv6_AUTHHDR = 0xa;

/// `syscall.IPV6_CHECKSUM`.
const ipv6_CHECKSUM = 7;

/// `syscall.IPV6_DROP_MEMBERSHIP`.
const ipv6_DROP_MEMBERSHIP = 0x15;

/// `syscall.IPV6_DSTOPTS`.
const ipv6_DSTOPTS = 0x3b;

/// `syscall.IPV6_HOPLIMIT`.
const ipv6_HOPLIMIT = 0x34;

/// `syscall.IPV6_HOPOPTS`.
const ipv6_HOPOPTS = 0x36;

/// `syscall.IPV6_IPSEC_POLICY`.
const ipv6_IPSEC_POLICY = 0x22;

/// `syscall.IPV6_JOIN_ANYCAST`.
const ipv6_JOIN_ANYCAST = 0x1b;

/// `syscall.IPV6_JOIN_GROUP`.
const ipv6_JOIN_GROUP = 0x14;

/// `syscall.IPV6_LEAVE_ANYCAST`.
const ipv6_LEAVE_ANYCAST = 0x1c;

/// `syscall.IPV6_LEAVE_GROUP`.
const ipv6_LEAVE_GROUP = 0x15;

/// `syscall.IPV6_MTU`.
const ipv6_MTU = 0x18;

/// `syscall.IPV6_MTU_DISCOVER`.
const ipv6_MTU_DISCOVER = 0x17;

/// `syscall.IPV6_MULTICAST_HOPS`.
const ipv6_MULTICAST_HOPS = 0x12;

/// `syscall.IPV6_MULTICAST_IF`.
const ipv6_MULTICAST_IF = 0x11;

/// `syscall.IPV6_MULTICAST_LOOP`.
const ipv6_MULTICAST_LOOP = 0x13;

/// `syscall.IPV6_NEXTHOP`.
const ipv6_NEXTHOP = 9;

/// `syscall.IPV6_PKTINFO`.
const ipv6_PKTINFO = 0x32;

/// `syscall.IPV6_PMTUDISC_DO`.
const ipv6_PMTUDISC_DO = 2;

/// `syscall.IPV6_PMTUDISC_DONT`.
const ipv6_PMTUDISC_DONT = 0;

/// `syscall.IPV6_PMTUDISC_PROBE`.
const ipv6_PMTUDISC_PROBE = 3;

/// `syscall.IPV6_PMTUDISC_WANT`.
const ipv6_PMTUDISC_WANT = 1;

/// `syscall.IPV6_RECVDSTOPTS`.
const ipv6_RECVDSTOPTS = 0x3a;

/// `syscall.IPV6_RECVERR`.
const ipv6_RECVERR = 0x19;

/// `syscall.IPV6_RECVHOPLIMIT`.
const ipv6_RECVHOPLIMIT = 0x33;

/// `syscall.IPV6_RECVHOPOPTS`.
const ipv6_RECVHOPOPTS = 0x35;

/// `syscall.IPV6_RECVPKTINFO`.
const ipv6_RECVPKTINFO = 0x31;

/// `syscall.IPV6_RECVRTHDR`.
const ipv6_RECVRTHDR = 0x38;

/// `syscall.IPV6_RECVTCLASS`.
const ipv6_RECVTCLASS = 0x42;

/// `syscall.IPV6_ROUTER_ALERT`.
const ipv6_ROUTER_ALERT = 0x16;

/// `syscall.IPV6_RTHDR`.
const ipv6_RTHDR = 0x39;

/// `syscall.IPV6_RTHDRDSTOPTS`.
const ipv6_RTHDRDSTOPTS = 0x37;

/// `syscall.IPV6_RTHDR_LOOSE`.
const ipv6_RTHDR_LOOSE = 0;

/// `syscall.IPV6_RTHDR_STRICT`.
const ipv6_RTHDR_STRICT = 1;

/// `syscall.IPV6_RTHDR_TYPE_0`.
const ipv6_RTHDR_TYPE_0 = 0;

/// `syscall.IPV6_RXDSTOPTS`.
const ipv6_RXDSTOPTS = 0x3b;

/// `syscall.IPV6_RXHOPOPTS`.
const ipv6_RXHOPOPTS = 0x36;

/// `syscall.IPV6_TCLASS`.
const ipv6_TCLASS = 0x43;

/// `syscall.IPV6_UNICAST_HOPS`.
const ipv6_UNICAST_HOPS = 0x10;

/// `syscall.IPV6_V6ONLY`.
const ipv6_V6ONLY = 0x1a;

/// `syscall.IPV6_XFRM_POLICY`.
const ipv6_XFRM_POLICY = 0x23;

/// `syscall.IP_ADD_MEMBERSHIP`.
const ip_ADD_MEMBERSHIP = 0x23;

/// `syscall.IP_ADD_SOURCE_MEMBERSHIP`.
const ip_ADD_SOURCE_MEMBERSHIP = 0x27;

/// `syscall.IP_BLOCK_SOURCE`.
const ip_BLOCK_SOURCE = 0x26;

/// `syscall.IP_DEFAULT_MULTICAST_LOOP`.
const ip_DEFAULT_MULTICAST_LOOP = 1;

/// `syscall.IP_DEFAULT_MULTICAST_TTL`.
const ip_DEFAULT_MULTICAST_TTL = 1;

/// `syscall.IP_DF`.
const ip_DF = 0x4000;

/// `syscall.IP_DROP_MEMBERSHIP`.
const ip_DROP_MEMBERSHIP = 0x24;

/// `syscall.IP_DROP_SOURCE_MEMBERSHIP`.
const ip_DROP_SOURCE_MEMBERSHIP = 0x28;

/// `syscall.IP_FREEBIND`.
const ip_FREEBIND = 0xf;

/// `syscall.IP_HDRINCL`.
const ip_HDRINCL = 3;

/// `syscall.IP_IPSEC_POLICY`.
const ip_IPSEC_POLICY = 0x10;

/// `syscall.IP_MAXPACKET`.
const ip_MAXPACKET = 0xffff;

/// `syscall.IP_MAX_MEMBERSHIPS`.
const ip_MAX_MEMBERSHIPS = 0x14;

/// `syscall.IP_MF`.
const ip_MF = 0x2000;

/// `syscall.IP_MINTTL`.
const ip_MINTTL = 0x15;

/// `syscall.IP_MSFILTER`.
const ip_MSFILTER = 0x29;

/// `syscall.IP_MSS`.
const ip_MSS = 0x240;

/// `syscall.IP_MTU`.
const ip_MTU = 0xe;

/// `syscall.IP_MTU_DISCOVER`.
const ip_MTU_DISCOVER = 0xa;

/// `syscall.IP_MULTICAST_IF`.
const ip_MULTICAST_IF = 0x20;

/// `syscall.IP_MULTICAST_LOOP`.
const ip_MULTICAST_LOOP = 0x22;

/// `syscall.IP_MULTICAST_TTL`.
const ip_MULTICAST_TTL = 0x21;

/// `syscall.IP_OFFMASK`.
const ip_OFFMASK = 0x1fff;

/// `syscall.IP_OPTIONS`.
const ip_OPTIONS = 4;

/// `syscall.IP_ORIGDSTADDR`.
const ip_ORIGDSTADDR = 0x14;

/// `syscall.IP_PASSSEC`.
const ip_PASSSEC = 0x12;

/// `syscall.IP_PKTINFO`.
const ip_PKTINFO = 8;

/// `syscall.IP_PKTOPTIONS`.
const ip_PKTOPTIONS = 9;

/// `syscall.IP_PMTUDISC`.
const ip_PMTUDISC = 0xa;

/// `syscall.IP_PMTUDISC_DO`.
const ip_PMTUDISC_DO = 2;

/// `syscall.IP_PMTUDISC_DONT`.
const ip_PMTUDISC_DONT = 0;

/// `syscall.IP_PMTUDISC_PROBE`.
const ip_PMTUDISC_PROBE = 3;

/// `syscall.IP_PMTUDISC_WANT`.
const ip_PMTUDISC_WANT = 1;

/// `syscall.IP_RECVERR`.
const ip_RECVERR = 0xb;

/// `syscall.IP_RECVOPTS`.
const ip_RECVOPTS = 6;

/// `syscall.IP_RECVORIGDSTADDR`.
const ip_RECVORIGDSTADDR = 0x14;

/// `syscall.IP_RECVRETOPTS`.
const ip_RECVRETOPTS = 7;

/// `syscall.IP_RECVTOS`.
const ip_RECVTOS = 0xd;

/// `syscall.IP_RECVTTL`.
const ip_RECVTTL = 0xc;

/// `syscall.IP_RETOPTS`.
const ip_RETOPTS = 7;

/// `syscall.IP_RF`.
const ip_RF = 0x8000;

/// `syscall.IP_ROUTER_ALERT`.
const ip_ROUTER_ALERT = 5;

/// `syscall.IP_TOS`.
const ip_TOS = 1;

/// `syscall.IP_TRANSPARENT`.
const ip_TRANSPARENT = 0x13;

/// `syscall.IP_TTL`.
const ip_TTL = 2;

/// `syscall.IP_UNBLOCK_SOURCE`.
const ip_UNBLOCK_SOURCE = 0x25;

/// `syscall.IP_XFRM_POLICY`.
const ip_XFRM_POLICY = 0x11;

/// `syscall.MSG_CMSG_CLOEXEC`.
const msg_CMSG_CLOEXEC = 0x40000000;

/// `syscall.MSG_CONFIRM`.
const msg_CONFIRM = 0x800;

/// `syscall.MSG_CTRUNC`.
const msg_CTRUNC = 8;

/// `syscall.MSG_DONTROUTE`.
const msg_DONTROUTE = 4;

/// `syscall.MSG_DONTWAIT`.
const msg_DONTWAIT = 0x40;

/// `syscall.MSG_EOR`.
const msg_EOR = 0x80;

/// `syscall.MSG_ERRQUEUE`.
const msg_ERRQUEUE = 0x2000;

/// `syscall.MSG_FASTOPEN`.
const msg_FASTOPEN = 0x20000000;

/// `syscall.MSG_FIN`.
const msg_FIN = 0x200;

/// `syscall.MSG_MORE`.
const msg_MORE = 0x8000;

/// `syscall.MSG_NOSIGNAL`.
const msg_NOSIGNAL = 0x4000;

/// `syscall.MSG_OOB`.
const msg_OOB = 1;

/// `syscall.MSG_PEEK`.
const msg_PEEK = 2;

/// `syscall.MSG_PROXY`.
const msg_PROXY = 0x10;

/// `syscall.MSG_RST`.
const msg_RST = 0x1000;

/// `syscall.MSG_SYN`.
const msg_SYN = 0x400;

/// `syscall.MSG_TRUNC`.
const msg_TRUNC = 0x20;

/// `syscall.MSG_TRYHARD`.
const msg_TRYHARD = 4;

/// `syscall.MSG_WAITALL`.
const msg_WAITALL = 0x100;

/// `syscall.MSG_WAITFORONE`.
const msg_WAITFORONE = 0x10000;

/// `syscall.SCM_CREDENTIALS`.
const scm_CREDENTIALS = 2;

/// `syscall.SCM_RIGHTS`.
const scm_RIGHTS = 1;

/// `syscall.SCM_TIMESTAMP`.
const scm_TIMESTAMP = 0x1d;

/// `syscall.SCM_TIMESTAMPING`.
const scm_TIMESTAMPING = 0x25;

/// `syscall.SCM_TIMESTAMPNS`.
const scm_TIMESTAMPNS = 0x23;

/// `syscall.SOCK_CLOEXEC`.
const sock_CLOEXEC = 0x80000;

/// `syscall.SOCK_DCCP`.
const sock_DCCP = 6;

/// `syscall.SOCK_DGRAM`.
const sock_DGRAM = 2;

/// `syscall.SOCK_NONBLOCK`.
const sock_NONBLOCK = 0x800;

/// `syscall.SOCK_PACKET`.
const sock_PACKET = 0xa;

/// `syscall.SOCK_RAW`.
const sock_RAW = 3;

/// `syscall.SOCK_RDM`.
const sock_RDM = 4;

/// `syscall.SOCK_SEQPACKET`.
const sock_SEQPACKET = 5;

/// `syscall.SOCK_STREAM`.
const sock_STREAM = 1;

/// `syscall.SOL_AAL`.
const sol_AAL = 0x109;

/// `syscall.SOL_ATM`.
const sol_ATM = 0x108;

/// `syscall.SOL_DECNET`.
const sol_DECNET = 0x105;

/// `syscall.SOL_ICMPV6`.
const sol_ICMPV6 = 0x3a;

/// `syscall.SOL_IP`.
const sol_IP = 0;

/// `syscall.SOL_IPV6`.
const sol_IPV6 = 0x29;

/// `syscall.SOL_IRDA`.
const sol_IRDA = 0x10a;

/// `syscall.SOL_PACKET`.
const sol_PACKET = 0x107;

/// `syscall.SOL_RAW`.
const sol_RAW = 0xff;

/// `syscall.SOL_SOCKET`.
const sol_SOCKET = 1;

/// `syscall.SOL_TCP`.
const sol_TCP = 6;

/// `syscall.SOL_X25`.
const sol_X25 = 0x106;

/// `syscall.SOMAXCONN`.
const somaxconn = 0x80;

/// `syscall.SO_ACCEPTCONN`.
const so_ACCEPTCONN = 0x1e;

/// `syscall.SO_ATTACH_FILTER`.
const so_ATTACH_FILTER = 0x1a;

/// `syscall.SO_BINDTODEVICE`.
const so_BINDTODEVICE = 0x19;

/// `syscall.SO_BROADCAST`.
const so_BROADCAST = 6;

/// `syscall.SO_BSDCOMPAT`.
const so_BSDCOMPAT = 0xe;

/// `syscall.SO_DEBUG`.
const so_DEBUG = 1;

/// `syscall.SO_DETACH_FILTER`.
const so_DETACH_FILTER = 0x1b;

/// `syscall.SO_DOMAIN`.
const so_DOMAIN = 0x27;

/// `syscall.SO_DONTROUTE`.
const so_DONTROUTE = 5;

/// `syscall.SO_ERROR`.
const so_ERROR = 4;

/// `syscall.SO_KEEPALIVE`.
const so_KEEPALIVE = 9;

/// `syscall.SO_LINGER`.
const so_LINGER = 0xd;

/// `syscall.SO_MARK`.
const so_MARK = 0x24;

/// `syscall.SO_NO_CHECK`.
const so_NO_CHECK = 0xb;

/// `syscall.SO_OOBINLINE`.
const so_OOBINLINE = 0xa;

/// `syscall.SO_PASSCRED`.
const so_PASSCRED = 0x10;

/// `syscall.SO_PASSSEC`.
const so_PASSSEC = 0x22;

/// `syscall.SO_PEERCRED`.
const so_PEERCRED = 0x11;

/// `syscall.SO_PEERNAME`.
const so_PEERNAME = 0x1c;

/// `syscall.SO_PEERSEC`.
const so_PEERSEC = 0x1f;

/// `syscall.SO_PRIORITY`.
const so_PRIORITY = 0xc;

/// `syscall.SO_PROTOCOL`.
const so_PROTOCOL = 0x26;

/// `syscall.SO_RCVBUF`.
const so_RCVBUF = 8;

/// `syscall.SO_RCVBUFFORCE`.
const so_RCVBUFFORCE = 0x21;

/// `syscall.SO_RCVLOWAT`.
const so_RCVLOWAT = 0x12;

/// `syscall.SO_RCVTIMEO`.
const so_RCVTIMEO = 0x14;

/// `syscall.SO_REUSEADDR`.
const so_REUSEADDR = 2;

/// `syscall.SO_RXQ_OVFL`.
const so_RXQ_OVFL = 0x28;

/// `syscall.SO_SECURITY_AUTHENTICATION`.
const so_SECURITY_AUTHENTICATION = 0x16;

/// `syscall.SO_SECURITY_ENCRYPTION_NETWORK`.
const so_SECURITY_ENCRYPTION_NETWORK = 0x18;

/// `syscall.SO_SECURITY_ENCRYPTION_TRANSPORT`.
const so_SECURITY_ENCRYPTION_TRANSPORT = 0x17;

/// `syscall.SO_SNDBUF`.
const so_SNDBUF = 7;

/// `syscall.SO_SNDBUFFORCE`.
const so_SNDBUFFORCE = 0x20;

/// `syscall.SO_SNDLOWAT`.
const so_SNDLOWAT = 0x13;

/// `syscall.SO_SNDTIMEO`.
const so_SNDTIMEO = 0x15;

/// `syscall.SO_TIMESTAMP`.
const so_TIMESTAMP = 0x1d;

/// `syscall.SO_TIMESTAMPING`.
const so_TIMESTAMPING = 0x25;

/// `syscall.SO_TIMESTAMPNS`.
const so_TIMESTAMPNS = 0x23;

/// `syscall.SO_TYPE`.
const so_TYPE = 3;

/// `syscall.TCP_CONGESTION`.
const tcp_CONGESTION = 0xd;

/// `syscall.TCP_CORK`.
const tcp_CORK = 3;

/// `syscall.TCP_DEFER_ACCEPT`.
const tcp_DEFER_ACCEPT = 9;

/// `syscall.TCP_INFO`.
const tcp_INFO = 0xb;

/// `syscall.TCP_KEEPCNT`.
const tcp_KEEPCNT = 6;

/// `syscall.TCP_KEEPIDLE`.
const tcp_KEEPIDLE = 4;

/// `syscall.TCP_KEEPINTVL`.
const tcp_KEEPINTVL = 5;

/// `syscall.TCP_LINGER2`.
const tcp_LINGER2 = 8;

/// `syscall.TCP_MAXSEG`.
const tcp_MAXSEG = 2;

/// `syscall.TCP_MAXWIN`.
const tcp_MAXWIN = 0xffff;

/// `syscall.TCP_MAX_WINSHIFT`.
const tcp_MAX_WINSHIFT = 0xe;

/// `syscall.TCP_MD5SIG`.
const tcp_MD5SIG = 0xe;

/// `syscall.TCP_MD5SIG_MAXKEYLEN`.
const tcp_MD5SIG_MAXKEYLEN = 0x50;

/// `syscall.TCP_MSS`.
const tcp_MSS = 0x200;

/// `syscall.TCP_NODELAY`.
const tcp_NODELAY = 1;

/// `syscall.TCP_QUICKACK`.
const tcp_QUICKACK = 0xc;

/// `syscall.TCP_SYNCNT`.
const tcp_SYNCNT = 7;

/// `syscall.TCP_WINDOW_CLAMP`.
const tcp_WINDOW_CLAMP = 0xa;
