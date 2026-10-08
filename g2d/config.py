"""Constantes do motor: prefixos, URIs, shims da stdlib e interfaces dos shims."""


# Prefixo do shim do universo Go (builtin.dart). `go` é palavra-chave em Go,
# então nenhum pacote ou identificador Go colide com ele.
BUILTIN_PREFIX = "go"

BUILTIN_URI = "package:golib_dart/builtin.dart"

# Tipos fixos do Go (golib_dart/fixed_types, origem: boilerplate do dart IPFS).
# O sentinela não é um import path Go válido (`$`), então não colide.
GOLANG = "$golang"

GOLANG_PREFIX = "Golang"

GOLANG_URI = "package:golib_dart/fixed_types/golang.dart"

# Library de um pacote do grafo (não-stdlib): o mono-repo que o WriteStage
# escreve (`name: out` no pubspec gerado, `lib/<import path>.dart`).
GRAPH_URI = "package:out/{path}.dart"

# Interfaces da stdlib que existem nos shims (podem ir em `implements`).
SHIM_INTERFACES = {("fmt", "Stringer"), ("fmt", "GoStringer"), ("fmt", "Formatter"), ("fmt", "State"), ("sort", "Interface"), ("io", "Reader"), ("io", "Writer"),
                   ("io", "ByteReader"), ("io", "ByteWriter"), ("io", "StringWriter"), ("io", "Closer"),
                   ("io", "Seeker"), ("io", "ReaderAt"), ("io", "WriterAt"), ("io", "ReadCloser"), ("io", "WriteCloser"),
                   ("io", "ReadWriter"), ("io", "ReadWriteCloser"), ("io", "ReadSeeker"), ("io", "WriteSeeker"),
                   ("io", "ReadWriteSeeker"), ("io", "ReadSeekCloser"), ("io", "ReaderFrom"), ("io", "WriterTo"),
                   ("io", "ByteScanner"), ("io", "RuneReader"), ("io", "RuneScanner"), ("sync", "Locker"),
                   ("context", "Context"), ("encoding", "TextMarshaler"), ("encoding", "TextUnmarshaler"),
                   ("encoding", "BinaryMarshaler"), ("encoding", "BinaryUnmarshaler"),
                   ("encoding/json", "Marshaler"), ("encoding/json", "Unmarshaler"),
                   ("net", "Addr"), ("net", "Error"), ("net", "Conn"), ("net", "Listener"), ("net", "PacketConn"),
                   ("syscall", "RawConn"), ("syscall", "Conn")}

# Tipos não exportados da stdlib que o código do grafo recebe por inferência
# (`var NBO = binary.BigEndian`): a classe pública do shim que os representa.
SHIM_TYPES = {("encoding/binary", "bigEndian"): "BigEndian", ("encoding/binary", "littleEndian"): "LittleEndian",
              ("encoding/binary", "nativeEndian"): "NativeEndian"}

# Pacotes da stdlib com shim em golib_dart/.
STDLIB_SHIMS = {
    "bytes": "package:golib_dart/bytes.dart",
    "context": "package:golib_dart/context.dart",
    "crypto/subtle": "package:golib_dart/crypto/subtle.dart",
    "encoding": "package:golib_dart/encoding.dart",
    "encoding/binary": "package:golib_dart/encoding/binary.dart",
    "encoding/json": "package:golib_dart/encoding/json.dart",
    "errors": "package:golib_dart/errors.dart",
    "fmt": "package:golib_dart/fmt.dart",
    "io": "package:golib_dart/io.dart",
    "io/fs": "package:golib_dart/io/fs.dart",
    "os": "package:golib_dart/os.dart",
    "reflect": "package:golib_dart/reflect.dart",
    "math": "package:golib_dart/math.dart",
    "math/bits": "package:golib_dart/math/bits.dart",
    "net": "package:golib_dart/net.dart",
    "net/netip": "package:golib_dart/net/netip.dart",
    "net/textproto": "package:golib_dart/net/textproto.dart",
    "regexp": "package:golib_dart/regexp.dart",
    "sort": "package:golib_dart/sort.dart",
    "strconv": "package:golib_dart/strconv.dart",
    "strings": "package:golib_dart/strings.dart",
    "sync": "package:golib_dart/sync.dart",
    "sync/atomic": "package:golib_dart/sync/atomic.dart",
    "syscall": "package:golib_dart/syscall.dart",
    "time": "package:golib_dart/time.dart",
    "unicode": "package:golib_dart/unicode.dart",
    "unicode/utf8": "package:golib_dart/unicode/utf8.dart",
}

# Tipos nomeados de shim sobre slice/map/func/array/bool que o shim escreve
# na forma que o g2d gera para um pacote transpilado (`final class IP extends
# go.Slice<Golang.Uint8>` com `super.alias`, e `IP$Ptr extends go.PtrView`
# quando tem métodos): conversões `net.IP(b)`/`[]byte(ip)`, zero value,
# descritores e `*N` seguem as regras dos tipos gerados. Os outros compostos
# nomeados de shim são typedef do subjacente (`json.RawMessage`).
SHIM_NAMED_CLASSES = frozenset({("net", "IP"), ("net", "IPMask"), ("net", "HardwareAddr"), ("net", "Buffers"),
                                ("net/textproto", "MIMEHeader")})

# Pacotes cuja presença no grafo liga os descritores de reflexão (M5):
# `reflect` e os shims construídos sobre ele.
REFLECT_PKGS = frozenset({"reflect", "encoding/json"})

# Tipos nomeados de shim com descritor de reflexão próprio (`static final $rt`
# na classe do shim); os outros viram `go.rtOpaque`.
SHIM_RTYPES = frozenset({("encoding/json", "Number"), ("encoding/json", "Delim"), ("time", "Time"),
                         ("time", "Duration"), ("time", "Month"), ("time", "Weekday"), ("syscall", "Errno")})
