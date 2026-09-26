"""Configuração do motor: prefixos, shims da stdlib e interfaces dos shims.

Constantes de módulo são os padrões; `EngineConfig` permite injetar outros
(ex.: um plugin que adiciona shims) sem editar o núcleo.
"""

from dataclasses import dataclass, field


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
SHIM_INTERFACES = {("fmt", "Stringer"), ("fmt", "Formatter"), ("fmt", "State"), ("sort", "Interface"), ("io", "Reader"), ("io", "Writer"),
                   ("io", "ByteReader"), ("io", "ByteWriter"), ("io", "StringWriter"), ("io", "Closer"),
                   ("io", "Seeker"), ("io", "ReaderAt"), ("io", "WriterAt"), ("io", "ReadCloser"), ("io", "WriteCloser"),
                   ("io", "ReadWriter"), ("io", "ReadWriteCloser"), ("io", "ReadSeeker"), ("io", "WriteSeeker"),
                   ("io", "ReadWriteSeeker"), ("sync", "Locker")}

# Tipos não exportados da stdlib que o código do grafo recebe por inferência
# (`var NBO = binary.BigEndian`): a classe pública do shim que os representa.
SHIM_TYPES = {("encoding/binary", "bigEndian"): "BigEndian", ("encoding/binary", "littleEndian"): "LittleEndian",
              ("encoding/binary", "nativeEndian"): "NativeEndian"}

# Pacotes da stdlib com shim em golib_dart/.
STDLIB_SHIMS = {
    "bytes": "package:golib_dart/bytes.dart",
    "crypto/subtle": "package:golib_dart/crypto/subtle.dart",
    "encoding/binary": "package:golib_dart/encoding/binary.dart",
    "errors": "package:golib_dart/errors.dart",
    "fmt": "package:golib_dart/fmt.dart",
    "io": "package:golib_dart/io.dart",
    "math": "package:golib_dart/math.dart",
    "math/bits": "package:golib_dart/math/bits.dart",
    "sort": "package:golib_dart/sort.dart",
    "strconv": "package:golib_dart/strconv.dart",
    "strings": "package:golib_dart/strings.dart",
    "sync": "package:golib_dart/sync.dart",
    "sync/atomic": "package:golib_dart/sync/atomic.dart",
    "time": "package:golib_dart/time.dart",
    "unicode/utf8": "package:golib_dart/unicode/utf8.dart",
}


@dataclass
class EngineConfig:
    """Tabelas consultadas pelos serviços; plugins podem estendê-las."""

    stdlib_shims: dict = field(default_factory=lambda: dict(STDLIB_SHIMS))
    shim_interfaces: set = field(default_factory=lambda: set(SHIM_INTERFACES))
