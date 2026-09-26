# Auditoria do grafo real

Gerado por `python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo`. **Não edite**: rode o comando de novo.

- Alvo: `github.com/ipfs/kubo/cmd/ipfs` (`github.com/ipfs/kubo` v0.43.1), 1112 pacotes fora da stdlib.
- Contexto: go1.26.5, `CGO_ENABLED=0 GOARCH=amd64 GOFLAGS=-tags=purego,noasm GOOS=linux`.
- Ocorrência = declaração de nível de pacote que falha (o primeiro problema dela);
  do `dart analyze`, cada diagnóstico. Pacote bloqueado não conta no ranking.

## Resumo

| status | pacotes | % |
|---|---:|---:|
| verde | 63 | 5.7 |
| dart-invalido | 1 | 0.1 |
| bloqueado | 88 | 7.9 |
| unsupported | 953 | 85.7 |
| substituicao | 7 | 0.6 |

**Verde: 63 de 1112 (5.7%).**

## Ranking de códigos

Ordem: pacotes da fronteira afetados, pacotes afetados, ocorrências.

| código | ocorrências | pacotes | na fronteira | exemplo |
|---|---:|---:|---:|---|
| `shim-ausente:io` | 966 | 232 | 43 | `github.com/ipld/go-car/v2/internal/io` converter.go:18:1: pacote sem shim/transpilação: io |
| `shim-ausente:time` | 1456 | 279 | 42 | `github.com/cenkalti/backoff/v4` backoff.go:16:1: pacote sem shim/transpilação: time |
| `shim-ausente:sync` | 692 | 305 | 37 | `github.com/cockroachdb/pebble/v2/internal/intern` intern.go:9:1: pacote sem shim/transpilação: sync |
| `shim-ausente:os` | 268 | 114 | 29 | `github.com/cockroachdb/redact/internal/rfmt` print.go:220:6: pacote sem shim/transpilação: os |
| `shim-ausente:context` | 1557 | 311 | 26 | `github.com/cenkalti/backoff/v4` context.go:10:1: pacote sem shim/transpilação: context |
| `shim-ausente:net` | 624 | 111 | 17 | `github.com/google/gopacket/routing` common.go:16:1: pacote sem shim/transpilação: net |
| `shim-simbolo:bytes.Buffer` | 97 | 59 | 16 | `github.com/cockroachdb/pebble/v2/internal/treeprinter` tree_printer.go:23:1: símbolo sem shim: bytes.Buffer |
| `shim-ausente:reflect` | 660 | 112 | 14 | `github.com/cockroachdb/redact/internal/rfmt/fmtsort` sort.go:23:1: pacote sem shim/transpilação: reflect |
| `shim-ausente:regexp` | 169 | 35 | 12 | `github.com/cockroachdb/redact/internal/markers` constants.go:33:1: pacote sem shim/transpilação: regexp |
| `shim-simbolo:strings.Builder` | 82 | 33 | 12 | `github.com/ucarion/urlpath` urlpath.go:14:1: símbolo sem shim: strings.Builder |
| `tipo:chan` | 200 | 92 | 11 | `github.com/cskr/pubsub` pubsub.go:28:1: tipo chan |
| `shim-ausente:sync/atomic` | 146 | 65 | 10 | `github.com/cockroachdb/crlib/crsync` typed_atomic.go:21:1: pacote sem shim/transpilação: sync/atomic |
| `shim-ausente:net/http` | 786 | 58 | 10 | `github.com/caddyserver/zerossl` client.go:16:1: pacote sem shim/transpilação: net/http |
| `generico-nao-struct` | 44 | 23 | 9 | `github.com/ipfs/go-libdht/kad` kad.go:16:6: tipo genérico não-struct |
| `shim-ausente:hash` | 65 | 22 | 9 | `github.com/spaolacci/murmur3` murmur128.go:23:1: pacote sem shim/transpilação: hash |
| `tipo-basico:Pointer` | 357 | 68 | 8 | `github.com/cockroachdb/pebble/v2/internal/rawalloc` rawalloc.go:21:6: tipo básico Pointer |
| `shim-ausente:encoding/json` | 103 | 39 | 8 | `github.com/blang/semver/v4` semver.go:24:1: pacote sem shim/transpilação: encoding/json |
| `shim-simbolo:strings.trimSpace` | 43 | 29 | 8 | `github.com/blang/semver/v4` semver.go:240:6: símbolo sem shim: strings.trimSpace |
| `tipo-nomeado:array` | 35 | 27 | 8 | `google.golang.org/protobuf/internal/pragma` pragma.go:22:6: tipo nomeado sobre array |
| `make:chan` | 81 | 57 | 7 | `github.com/cskr/pubsub` pubsub.go:43:16: make de chan |
| `shim-ausente:unicode/utf8` | 72 | 30 | 7 | `github.com/rivo/uniseg` grapheme.go:215:6: pacote sem shim/transpilação: unicode/utf8 |
| `append-string` | 39 | 21 | 7 | `golang.org/x/net/dns/dnsmessage` message.go:1889:8: append([]byte, string...) |
| `shim-ausente:math/big` | 80 | 17 | 7 | `github.com/dustin/go-humanize` big.go:8:6: pacote sem shim/transpilação: math/big |
| `shim-simbolo:strings.equalFold` | 20 | 14 | 7 | `github.com/pion/webrtc/v4/internal/fmtp` fmtp.go:92:6: símbolo sem shim: strings.equalFold |
| `shim-ausente:unicode` | 19 | 14 | 7 | `github.com/anmitsu/go-shlex` shlex.go:28:1: pacote sem shim/transpilação: unicode |
| `copy-string` | 23 | 11 | 7 | `golang.org/x/net/dns/dnsmessage` message.go:1935:2: copy([]byte, string) |
| `conversao:nao-basico` | 323 | 54 | 6 | `google.golang.org/protobuf/internal/set` ints.go:20:3: conversão de tipo não-básico |
| `shim-simbolo:fmt.State` | 55 | 26 | 6 | `github.com/cockroachdb/redact/interfaces` interfaces.go:41:1: símbolo sem shim: fmt.State |
| `shim-simbolo:bytes.Reader` | 50 | 23 | 6 | `github.com/quic-go/quic-go/quicvarint` io.go:14:5: símbolo sem shim: bytes.Reader |
| `shim-ausente:log` | 36 | 22 | 6 | `github.com/AndreasBriese/bbloom` bbloom.go:64:6: pacote sem shim/transpilação: log |
| `shim-ausente:encoding/base64` | 36 | 21 | 6 | `github.com/dunglas/httpsfv` binary.go:31:6: pacote sem shim/transpilação: encoding/base64 |
| `branch:goto` | 60 | 19 | 6 | `gonum.org/v1/gonum/mathext/internal/cephes` incbi.go:39:3: goto |
| `shim-ausente:encoding/hex` | 26 | 14 | 6 | `github.com/pion/webrtc/v4/internal/fmtp` h264.go:10:6: pacote sem shim/transpilação: encoding/hex |
| `shim-simbolo:strconv.parseFloat` | 14 | 11 | 6 | `github.com/munnerz/goautoneg` autoneg.go:93:6: símbolo sem shim: strconv.parseFloat |
| `shim-ausente:slices` | 88 | 51 | 5 | `github.com/ipfs/go-libdht/kad/trie` trie.go:17:1: pacote sem shim/transpilação: slices |
| `shim-ausente:net/url` | 135 | 45 | 5 | `github.com/cockroachdb/pebble/v2/internal/lsmview` url.go:17:6: pacote sem shim/transpilação: net/url |
| `builtin:None` | 39 | 30 | 5 | `filippo.io/bigmod` nat_noasm.go:12:19: builtin None |
| `shim-ausente:runtime` | 38 | 25 | 5 | `github.com/cockroachdb/pebble/v2/internal/invariants` invariants.go:40:6: pacote sem shim/transpilação: runtime |
| `shim-simbolo:encoding/binary.putUvarint` | 26 | 13 | 5 | `github.com/golang/snappy` encode.go:20:6: símbolo sem shim: encoding/binary.putUvarint |
| `shim-ausente:hash/crc32` | 29 | 11 | 5 | `github.com/cockroachdb/pebble/v2/internal/crc` crc.go:21:1: pacote sem shim/transpilação: hash/crc32 |
| `shim-ausente:io/fs` | 81 | 29 | 4 | `github.com/caddyserver/certmagic/internal/atomicfile` file.go:65:6: pacote sem shim/transpilação: io/fs |
| `shim-ausente:crypto/rand` | 34 | 26 | 4 | `github.com/flynn/noise` state.go:317:6: pacote sem shim/transpilação: crypto/rand |
| `shim-ausente:bufio` | 36 | 18 | 4 | `github.com/anmitsu/go-shlex` shlex.go:52:1: pacote sem shim/transpilação: bufio |
| `import:_` | 16 | 16 | 4 | `google.golang.org/protobuf/internal/editiondefaults` defaults.go:9:8: import _ embed |
| `shim-ausente:log/slog` | 109 | 47 | 3 | `github.com/go-logr/logr` sloghandler.go:26:1: pacote sem shim/transpilação: log/slog |
| `shim-simbolo:strings.toLower` | 40 | 32 | 3 | `github.com/gabriel-vasile/mimetype/internal/charset` charset.go:163:6: símbolo sem shim: strings.toLower |
| `shim-ausente:syscall` | 76 | 25 | 3 | `github.com/pbnjay/memory` memory_linux.go:7:6: pacote sem shim/transpilação: syscall |
| `shim-simbolo:errors.as` | 21 | 17 | 3 | `github.com/jbenet/go-temp-err-catcher` temp_err_catcher.go:26:6: símbolo sem shim: errors.as |
| `shim-simbolo:errors.is$` | 22 | 15 | 3 | `github.com/pkg/errors` go113.go:16:6: símbolo sem shim: errors.is$ |
| `shim-ausente:path` | 27 | 13 | 3 | `github.com/ipfs/go-datastore/query` query_impl.go:111:6: pacote sem shim/transpilação: path |
| `shim-ausente:crypto/sha256` | 15 | 13 | 3 | `github.com/multiformats/go-multihash/register/sha256` sha256.go:19:6: pacote sem shim/transpilação: crypto/sha256 |
| `constraint` | 55 | 12 | 3 | `github.com/rivo/uniseg` properties.go:137:6: constraint de tipo não mapeada |
| `shim-ausente:iter` | 16 | 10 | 3 | `github.com/cockroachdb/pebble/v2/sstable/block/blockkind` kind.go:46:6: pacote sem shim/transpilação: iter |
| `shim-simbolo:encoding/binary.uvarint` | 13 | 10 | 3 | `github.com/golang/snappy` decode.go:32:6: símbolo sem shim: encoding/binary.uvarint |
| `shim-ausente:runtime/debug` | 11 | 10 | 3 | `github.com/ipfs/boxo/util` util.go:34:6: pacote sem shim/transpilação: runtime/debug |
| `shim-simbolo:math.log` | 22 | 7 | 3 | `gonum.org/v1/gonum/mathext/internal/cephes` igam.go:98:6: símbolo sem shim: math.log |
| `shim-ausente:container/list` | 10 | 5 | 3 | `github.com/golang/groupcache/lru` lru.go:23:1: pacote sem shim/transpilação: container/list |
| `shim-ausente:crypto/md5` | 5 | 5 | 3 | `github.com/multiformats/go-multihash/core` registry.go:112:6: pacote sem shim/transpilação: crypto/md5 |
| `tipo-nomeado:pointer` | 3 | 3 | 3 | `github.com/klauspost/cpuid/v2` cpuid.go:553:6: tipo nomeado sobre pointer |
| `shim-ausente:crypto/x509` | 45 | 15 | 2 | `github.com/libp2p/go-libp2p/core/crypto` ecdsa.go:76:6: pacote sem shim/transpilação: crypto/x509 |
| `shim-ausente:maps` | 16 | 14 | 2 | `github.com/ipfs/kubo/repo/common` common.go:67:6: pacote sem shim/transpilação: maps |
| `tipo-nomeado:bool` | 21 | 13 | 2 | `github.com/ipld/go-ipld-prime/fluent/qp` qp.go:120:1: tipo nomeado sobre bool |
| `shim-simbolo:strings.trim` | 14 | 12 | 2 | `github.com/klauspost/cpuid/v2` cpuid.go:991:6: símbolo sem shim: strings.trim |
| `shim-ausente:cmp` | 13 | 10 | 2 | `go.opentelemetry.io/auto/sdk/internal/telemetry` value.go:290:6: pacote sem shim/transpilação: cmp |
| `shim-ausente:crypto` | 21 | 9 | 2 | `golang.org/x/crypto/blake2s` blake2s.go:59:6: pacote sem shim/transpilação: crypto |
| `literal-composto:pointer` | 12 | 9 | 2 | `golang.org/x/text/unicode/norm` forminfo.go:64:29: literal composto de pointer |
| `fmt-verbo:%#v` | 67 | 8 | 2 | `github.com/cockroachdb/swiss` map.go:1006:21: fmt: %#v não portado no shim |
| `shim-simbolo:math.pow` | 12 | 7 | 2 | `github.com/klauspost/compress` compressible.go:10:6: símbolo sem shim: math.pow |
| `shim-ausente:crypto/cipher` | 14 | 6 | 2 | `github.com/davidlazar/go-crypto/salsa20` salsa20.go:20:6: pacote sem shim/transpilação: crypto/cipher |
| `shim-simbolo:strconv.formatFloat` | 10 | 6 | 2 | `go.opentelemetry.io/otel/attribute` value.go:745:6: símbolo sem shim: strconv.formatFloat |
| `func-sem-corpo` | 6 | 4 | 2 | `github.com/cockroachdb/pebble/v2/internal/rawalloc` rawalloc_go1.9.go:27:6: função sem corpo (assembly ou go:linkname): substituição |
| `shim-simbolo:math.lgamma` | 5 | 4 | 2 | `gonum.org/v1/gonum/mathext/internal/gonum` beta.go:40:6: símbolo sem shim: math.lgamma |
| `shim-ausente:crypto/sha1` | 4 | 4 | 2 | `github.com/pion/stun/v3/internal/hmac` pool.go:40:5: pacote sem shim/transpilação: crypto/sha1 |
| `shim-simbolo:fmt.sscanf` | 5 | 3 | 2 | `github.com/syndtr/goleveldb/leveldb/storage` file_storage.go:649:6: símbolo sem shim: fmt.sscanf |
| `shim-ausente:crypto/ecdh` | 4 | 3 | 2 | `golang.org/x/crypto/curve25519` curve25519.go:38:6: pacote sem shim/transpilação: crypto/ecdh |
| `shim-simbolo:errors.unwrap` | 4 | 3 | 2 | `github.com/pkg/errors` go113.go:36:6: símbolo sem shim: errors.unwrap |
| `shim-ausente:encoding/xml` | 3 | 3 | 2 | `github.com/huin/goupnp/scpd` scpd.go:20:1: pacote sem shim/transpilação: encoding/xml |
| `shim-ausente:flag` | 3 | 3 | 2 | `github.com/grpc-ecosystem/grpc-gateway/v2/utilities` string_array_flag.go:9:1: pacote sem shim/transpilação: flag |
| `shim-simbolo:strings.fieldsFunc` | 3 | 2 | 2 | `github.com/ipld/go-ipld-prime/datamodel` path.go:113:6: símbolo sem shim: strings.fieldsFunc |
| `shim-simbolo:strings.map` | 2 | 2 | 2 | `github.com/prometheus/otlptranslator` unit_namer.go:123:6: símbolo sem shim: strings.map |
| `shim-ausente:crypto/tls` | 82 | 28 | 1 | `github.com/coreos/go-systemd/v22/activation` listeners.go:58:6: pacote sem shim/transpilação: crypto/tls |
| `shim-ausente:path/filepath` | 38 | 24 | 1 | `github.com/fsnotify/fsnotify` fsnotify.go:507:6: pacote sem shim/transpilação: path/filepath |
| `shim-ausente:math/rand/v2` | 14 | 13 | 1 | `google.golang.org/grpc/balancer/pickfirst/internal` internal.go:28:2: pacote sem shim/transpilação: math/rand/v2 |
| `shim-ausente:math/rand` | 20 | 11 | 1 | `github.com/pion/randutil` math.go:27:1: pacote sem shim/transpilação: math/rand |
| `shim-simbolo:strings.replace` | 10 | 9 | 1 | `github.com/blang/semver/v4` range.go:205:6: símbolo sem shim: strings.replace |
| `fmt-verbo:%p` | 11 | 7 | 1 | `google.golang.org/grpc/attributes` attributes.go:145:21: fmt: %p não portado no shim |
| `shim-simbolo:strings.replaceAll` | 9 | 7 | 1 | `github.com/pion/rtcp` compound_packet.go:23:1: símbolo sem shim: strings.replaceAll |
| `conversao:bool-bool` | 12 | 6 | 1 | `github.com/ipld/go-ipld-prime/fluent/qp` qp.go:129:9: conversão bool → bool |
| `shim-simbolo:strconv.appendInt` | 8 | 6 | 1 | `github.com/hashicorp/go-version` version.go:70:1: símbolo sem shim: strconv.appendInt |
| `shim-simbolo:strings.toUpper` | 7 | 6 | 1 | `github.com/klauspost/cpuid/v2` cpuid.go:957:6: símbolo sem shim: strings.toUpper |
| `shim-ausente:os/exec` | 10 | 5 | 1 | `golang.org/x/sys/execabs` execabs.go:54:6: pacote sem shim/transpilação: os/exec |
| `shim-ausente:container/heap` | 6 | 5 | 1 | `github.com/ipfs/go-ipfs-pq` pq.go:35:6: pacote sem shim/transpilação: container/heap |
| `range:pointer` | 5 | 5 | 1 | `golang.org/x/crypto/curve25519` curve25519.go:27:3: range sobre pointer |
| `shim-ausente:encoding/asn1` | 10 | 4 | 1 | `golang.org/x/crypto/cryptobyte` asn1.go:163:6: pacote sem shim/transpilação: encoding/asn1 |
| `shim-simbolo:strings.compare` | 9 | 4 | 1 | `github.com/ipfs/go-datastore/query` order.go:50:1: símbolo sem shim: strings.compare |
| `shim-ausente:crypto/ecdsa` | 8 | 4 | 1 | `github.com/decred/dcrd/dcrec/secp256k1/v4` privkey.go:16:1: pacote sem shim/transpilação: crypto/ecdsa |
| `shim-simbolo:strings.Reader` | 5 | 4 | 1 | `github.com/anmitsu/go-shlex` shlex.go:74:6: símbolo sem shim: strings.Reader |
| `shim-ausente:io/ioutil` | 4 | 4 | 1 | `github.com/minio/sha256-simd` cpuid_other.go:31:6: pacote sem shim/transpilação: io/ioutil |
| `shim-simbolo:strconv.quote` | 4 | 4 | 1 | `go.opencensus.io/resource` resource.go:43:6: símbolo sem shim: strconv.quote |
| `shim-ausente:crypto/elliptic` | 8 | 3 | 1 | `filippo.io/keygen` ecdsa.go:32:6: pacote sem shim/transpilação: crypto/elliptic |
| `shim-ausente:crypto/rsa` | 5 | 3 | 1 | `filippo.io/keygen` rsa.go:30:6: pacote sem shim/transpilação: crypto/rsa |
| `shim-simbolo:bytes.trimSuffix` | 5 | 3 | 1 | `github.com/klauspost/compress/s2` index.go:547:6: símbolo sem shim: bytes.trimSuffix |
| `shim-simbolo:bytes.trimSpace` | 3 | 3 | 1 | `github.com/kr/text` wrap.go:23:6: símbolo sem shim: bytes.trimSpace |
| `shim-simbolo:fmt.sprintln` | 3 | 3 | 1 | `github.com/fatih/color` color.go:683:6: símbolo sem shim: fmt.sprintln |
| `shim-simbolo:math.exp` | 3 | 3 | 1 | `gonum.org/v1/gonum/mathext/internal/gonum` beta.go:24:6: símbolo sem shim: math.exp |
| `shim-simbolo:math.log2` | 3 | 3 | 1 | `github.com/klauspost/compress` compressible.go:68:6: símbolo sem shim: math.log2 |
| `builtin:real` | 4 | 2 | 1 | `gonum.org/v1/gonum/mathext/internal/amos` amos.go:1377:19: builtin real |
| `shim-simbolo:bytes.join` | 4 | 2 | 1 | `golang.org/x/text/internal/language` parse.go:351:6: símbolo sem shim: bytes.join |
| `shim-ausente:os/user` | 3 | 2 | 1 | `github.com/hanwen/go-fuse/v2/internal` access.go:14:6: pacote sem shim/transpilação: os/user |
| `shim-simbolo:math.modf` | 3 | 2 | 1 | `gonum.org/v1/gonum/mathext` digamma.go:14:6: símbolo sem shim: math.modf |
| `shim-simbolo:strings.indexRune` | 3 | 2 | 1 | `github.com/blang/semver/v4` semver.go:271:6: símbolo sem shim: strings.indexRune |
| `range:chan` | 2 | 2 | 1 | `github.com/ipfs/go-datastore/query` query_impl.go:84:2: range sobre chan |
| `shim-ausente:encoding` | 2 | 2 | 1 | `github.com/go-logfmt/logfmt` encode.go:304:6: pacote sem shim/transpilação: encoding |
| `shim-simbolo:strings.indexAny` | 2 | 2 | 1 | `github.com/grpc-ecosystem/grpc-gateway/v2/internal/httprule` parse.go:39:6: símbolo sem shim: strings.indexAny |
| `shim-simbolo:strings.indexFunc` | 2 | 2 | 1 | `github.com/blang/semver/v4` semver.go:443:6: símbolo sem shim: strings.indexFunc |
| `dart:undefined_class` | 8 | 1 | 1 | `golang.org/x/crypto/internal/poly1305` 14:7: error: Undefined class '_macGeneric'. |
| `builtin:complex` | 6 | 1 | 1 | `gonum.org/v1/gonum/mathext/internal/amos` amos.go:206:17: builtin complex |
| `dart:implicit_this_reference_in_initializer` | 3 | 1 | 1 | `golang.org/x/crypto/internal/poly1305` 14:63: error: The instance member '_macGeneric' can't be accessed in an initializer. |
| `shim-ausente:math/cmplx` | 2 | 1 | 1 | `gonum.org/v1/gonum/mathext/internal/amos` amos.go:1940:6: pacote sem shim/transpilação: math/cmplx |
| `shim-simbolo:bytes.errTooLarge` | 2 | 1 | 1 | `github.com/syndtr/goleveldb/leveldb/util` buffer.go:21:1: símbolo sem shim: bytes.errTooLarge |
| `shim-simbolo:bytes.repeat` | 2 | 1 | 1 | `github.com/decred/dcrd/dcrec/secp256k1/v4` nonce.go:31:2: símbolo sem shim: bytes.repeat |
| `shim-simbolo:bytes.runes` | 2 | 1 | 1 | `golang.org/x/text/unicode/bidi` bidi.go:76:1: símbolo sem shim: bytes.runes |
| `builtin:println` | 1 | 1 | 1 | `golang.org/x/exp/mmap` mmap_unix.go:51:3: builtin println |
| `shim-ausente:database/sql/driver` | 1 | 1 | 1 | `github.com/google/uuid` null.go:29:1: pacote sem shim/transpilação: database/sql/driver |
| `shim-simbolo:bytes.equalFold` | 1 | 1 | 1 | `github.com/google/uuid` uuid.go:120:6: símbolo sem shim: bytes.equalFold |
| `shim-simbolo:bytes.indexAny` | 1 | 1 | 1 | `github.com/gorilla/mux` regexp.go:242:6: símbolo sem shim: bytes.indexAny |
| `shim-simbolo:bytes.lastIndex` | 1 | 1 | 1 | `github.com/klauspost/compress/s2` dict.go:83:6: símbolo sem shim: bytes.lastIndex |
| `shim-ausente:net/netip` | 42 | 14 | 0 | `github.com/pion/mdns/v2` conn.go:48:1: pacote sem shim/transpilação: net/netip |
| `shim-simbolo:errors.join` | 16 | 11 | 0 | `go.opentelemetry.io/otel/baggage` baggage.go:436:6: símbolo sem shim: errors.join |
| `shim-simbolo:strings.cut` | 14 | 10 | 0 | `go.opentelemetry.io/otel/trace` tracestate.go:124:6: símbolo sem shim: strings.cut |
| `indice:func` | 15 | 9 | 0 | `go.opentelemetry.io/otel/attribute` value.go:241:9: índice sobre func |
| `range:func` | 13 | 8 | 0 | `github.com/prometheus/procfs` mountinfo.go:150:2: range sobre func |
| `stmt:GoStmt` | 9 | 8 | 0 | `go.opencensus.io/stats/view` worker.go:34:2: statement GoStmt |
| `shim-simbolo:strings.lastIndexByte` | 7 | 7 | 0 | `go.uber.org/zap/zapcore` entry.go:70:1: símbolo sem shim: strings.lastIndexByte |
| `expr:IndexListExpr` | 9 | 6 | 0 | `github.com/hashicorp/golang-lru/v2/simplelru` lru.go:31:14: expressão IndexListExpr |
| `shim-simbolo:bytes.newBuffer` | 9 | 6 | 0 | `lukechampine.com/blake3/bao` bao.go:213:6: símbolo sem shim: bytes.newBuffer |
| `shim-simbolo:strings.repeat` | 9 | 6 | 0 | `github.com/mattn/go-runewidth` runewidth.go:98:1: símbolo sem shim: strings.repeat |
| `zero-value:chan` | 7 | 6 | 0 | `github.com/pion/turn/v4/internal/client` transaction.go:48:6: zero value de chan |
| `shim-simbolo:strings.trimRight` | 7 | 5 | 0 | `github.com/multiformats/go-multiaddr` codec.go:11:6: símbolo sem shim: strings.trimRight |
| `shim-simbolo:bytes.newReader` | 5 | 5 | 0 | `github.com/ipfs/go-cid` cid.go:607:6: símbolo sem shim: bytes.newReader |
| `shim-simbolo:fmt.Formatter` | 5 | 5 | 0 | `github.com/kr/pretty` formatter.go:29:6: símbolo sem shim: fmt.Formatter |
| `stmt:SelectStmt` | 8 | 4 | 0 | `github.com/syndtr/goleveldb/leveldb` db_compaction.go:382:4: statement SelectStmt |
| `andnot-nao-ident` | 7 | 4 | 0 | `golang.org/x/term` term_unix.go:32:2: &^= sobre expressão não-identificador |
| `shim-ausente:net/textproto` | 7 | 4 | 0 | `golang.org/x/net/http/httpguts` guts.go:20:6: pacote sem shim/transpilação: net/textproto |
| `shim-simbolo:fmt.fprintf` | 5 | 4 | 0 | `github.com/fatih/color` color.go:193:6: símbolo sem shim: fmt.fprintf |
| `shim-simbolo:strings.containsAny` | 4 | 4 | 0 | `github.com/prometheus/procfs` mdstat.go:231:6: símbolo sem shim: strings.containsAny |
| `shim-ausente:net/http/httptrace` | 21 | 3 | 0 | `github.com/quic-go/quic-go/http3` stream.go:54:6: pacote sem shim/transpilação: net/http/httptrace |
| `shim-ausente:encoding/base32` | 12 | 3 | 0 | `github.com/multiformats/go-multiaddr` transcoders.go:193:6: pacote sem shim/transpilação: encoding/base32 |
| `shim-simbolo:strings.fields` | 11 | 3 | 0 | `github.com/prometheus/procfs` arp.go:64:6: símbolo sem shim: strings.fields |
| `shim-ausente:text/template` | 10 | 3 | 0 | `github.com/cheggaaa/pb/v3` template.go:30:1: pacote sem shim/transpilação: text/template |
| `shim-ausente:crypto/aes` | 7 | 3 | 0 | `github.com/flynn/noise` cipher_suite.go:140:6: pacote sem shim/transpilação: crypto/aes |
| `shim-simbolo:errors.asType` | 4 | 3 | 0 | `github.com/quic-go/quic-go` sys_conn_helper_linux.go:98:6: símbolo sem shim: errors.asType |
| `shim-simbolo:strings.trimLeft` | 3 | 3 | 0 | `github.com/multiformats/go-multiaddr/net` convert.go:158:6: símbolo sem shim: strings.trimLeft |
| `tipo-nomeado:chan` | 3 | 3 | 0 | `github.com/libp2p/go-libp2p-kad-dht/internal` ctx_mutex.go:7:6: tipo nomeado sobre chan |
| `shim-ausente:html/template` | 8 | 2 | 0 | `github.com/ipfs/boxo/gateway/assets` : pacote sem shim/transpilação: html/template |
| `shim-ausente:mime/multipart` | 6 | 2 | 0 | `github.com/ipfs/boxo/files` multipartfile.go:68:1: pacote sem shim/transpilação: mime/multipart |
| `shim-ausente:compress/gzip` | 4 | 2 | 0 | `google.golang.org/grpc/encoding/gzip` gzip.go:48:1: pacote sem shim/transpilação: compress/gzip |
| `shim-simbolo:math.round` | 4 | 2 | 0 | `gonum.org/v1/gonum/mathext/internal/cephes` hyp2f1.go:78:6: símbolo sem shim: math.round |
| `operador-unario:<-` | 3 | 2 | 0 | `github.com/pion/srtp/v3` session_srtcp.go:98:16: operador unário <- |
| `shim-simbolo:fmt.fprintln` | 3 | 2 | 0 | `github.com/klauspost/compress/zstd` dict.go:192:6: símbolo sem shim: fmt.fprintln |
| `shim-simbolo:strconv.appendFloat` | 3 | 2 | 0 | `github.com/prometheus/common/expfmt` openmetrics_create.go:655:6: símbolo sem shim: strconv.appendFloat |
| `shim-simbolo:strconv.appendUint` | 3 | 2 | 0 | `github.com/pion/sdp/v3` session_description.go:186:1: símbolo sem shim: strconv.appendUint |
| `shim-simbolo:strings.cutPrefix` | 3 | 2 | 0 | `github.com/ipfs/kubo/fuse/mount` stat.go:55:6: símbolo sem shim: strings.cutPrefix |
| `shim-simbolo:strings.newReplacer` | 3 | 2 | 0 | `github.com/prometheus/common/expfmt` text_create.go:462:2: símbolo sem shim: strings.newReplacer |
| `shim-ausente:archive/zip` | 2 | 2 | 0 | `github.com/ipfs/kubo/profile` profile.go:126:1: pacote sem shim/transpilação: archive/zip |
| `shim-ausente:crypto/x509/pkix` | 2 | 2 | 0 | `github.com/caddyserver/certmagic` config.go:1385:2: pacote sem shim/transpilação: crypto/x509/pkix |
| `shim-ausente:go/build` | 2 | 2 | 0 | `github.com/getsentry/sentry-go` stacktrace.go:333:5: pacote sem shim/transpilação: go/build |
| `shim-simbolo:bytes.clone` | 2 | 2 | 0 | `filippo.io/keygen` ecdsa.go:112:6: símbolo sem shim: bytes.clone |
| `shim-simbolo:bytes.newBufferString` | 2 | 2 | 0 | `github.com/mgutz/ansi` ansi.go:228:6: símbolo sem shim: bytes.newBufferString |
| `shim-simbolo:bytes.trimPrefix` | 2 | 2 | 0 | `github.com/go-kit/log` stdlib.go:28:1: símbolo sem shim: bytes.trimPrefix |
| `shim-simbolo:encoding/binary._bigEndian` | 2 | 2 | 0 | `github.com/libp2p/go-msgio` num.go:9:1: símbolo sem shim: encoding/binary._bigEndian |
| `shim-simbolo:math.log10` | 2 | 2 | 0 | `github.com/cockroachdb/pebble/v2/internal/binfmt` binfmt.go:22:6: símbolo sem shim: math.log10 |
| `shim-simbolo:strconv.isPrint` | 2 | 2 | 0 | `github.com/go-logr/logr/funcr` funcr.go:702:6: símbolo sem shim: strconv.isPrint |
| `shim-ausente:crypto/sha3` | 9 | 1 | 0 | `golang.org/x/crypto/sha3` hashes.go:66:6: pacote sem shim/transpilação: crypto/sha3 |
| `shim-simbolo:bytes.contains` | 7 | 1 | 0 | `github.com/gabriel-vasile/mimetype/internal/magic` archive.go:132:6: símbolo sem shim: bytes.contains |
| `shim-ausente:testing` | 6 | 1 | 0 | `github.com/ipfs/kubo/repo/fsrepo/migrations/common` testing_helpers.go:28:6: pacote sem shim/transpilação: testing |
| `shim-ausente:go/token` | 5 | 1 | 0 | `github.com/cockroachdb/pebble/v2/internal/dsl` dsl.go:40:1: pacote sem shim/transpilação: go/token |
| `shim-simbolo:encoding/binary.nativeEndian` | 4 | 1 | 0 | `golang.org/x/net/ipv6` control_rfc3542_unix.go:20:6: símbolo sem shim: encoding/binary.nativeEndian |
| `erro-interno:KeyError` | 3 | 1 | 0 | `github.com/ipfs/kubo/core/commands` update.go:103:5: services/types.py:105: 'results' |
| `shim-ausente:mime` | 3 | 1 | 0 | `github.com/gabriel-vasile/mimetype` mime.go:14:1: pacote sem shim/transpilação: mime |
| `shim-ausente:compress/flate` | 2 | 1 | 0 | `github.com/gorilla/websocket` compression.go:96:1: pacote sem shim/transpilação: compress/flate |
| `shim-ausente:crypto/ed25519` | 2 | 1 | 0 | `github.com/libp2p/go-libp2p/core/crypto` ed25519.go:16:1: pacote sem shim/transpilação: crypto/ed25519 |
| `shim-ausente:expvar` | 2 | 1 | 0 | `github.com/dgraph-io/badger/y` metrics.go:21:1: pacote sem shim/transpilação: expvar |
| `shim-ausente:runtime/pprof` | 2 | 1 | 0 | `github.com/cockroachdb/pebble/v2/record` log_writer.go:23:1: pacote sem shim/transpilação: runtime/pprof |
| `shim-ausente:weak` | 2 | 1 | 0 | `github.com/klauspost/compress/zstd` simple_go124.go:16:1: pacote sem shim/transpilação: weak |
| `shim-simbolo:math.sincos` | 2 | 1 | 0 | `gonum.org/v1/gonum/mathext` ell_carlson.go:149:6: símbolo sem shim: math.sincos |
| `shim-simbolo:strconv.parseBool` | 2 | 1 | 0 | `github.com/grpc-ecosystem/grpc-gateway/v2/runtime` convert.go:28:6: símbolo sem shim: strconv.parseBool |
| `shim-simbolo:strings.Replacer` | 2 | 1 | 0 | `github.com/prometheus/common/expfmt` text_create.go:461:1: símbolo sem shim: strings.Replacer |
| `construtor-ambiguo` | 1 | 1 | 0 | `github.com/syndtr/goleveldb/leveldb` db_state.go:23:1: parâmetro de construtor ambíguo para campo DB |
| `defer-builtin` | 1 | 1 | 0 | `golang.org/x/net/http2` transport.go:1781:2: defer de builtin |
| `for-multi-atribuicao` | 1 | 1 | 0 | `go.uber.org/zap/internal/stacktrace` stack.go:164:41: cláusula de for com múltiplas atribuições |
| `layout:typeparam` | 1 | 1 | 0 | `github.com/RaduBerinde/axisds/regiontree` region_tree.go:49:1: layout de typeparam |
| `len:chan` | 1 | 1 | 0 | `github.com/libp2p/go-libp2p/p2p/host/eventbus` basic.go:477:50: len de chan |
| `min:typeparam` | 1 | 1 | 0 | `github.com/cockroachdb/pebble/v2/sstable/colblk` uints.go:472:13: min de typeparam |
| `shim-ausente:` | 1 | 1 | 0 | `github.com/cockroachdb/pebble/v2/internal/genericcache` cache.go:25:1: pacote sem shim/transpilação:  |
| `shim-ausente:archive/tar` | 1 | 1 | 0 | `github.com/ipfs/boxo/files` tarwriter.go:15:1: pacote sem shim/transpilação: archive/tar |
| `shim-ausente:crypto/fips140` | 1 | 1 | 0 | `golang.org/x/crypto/chacha20poly1305` fips140only_go1.26.go:11:6: pacote sem shim/transpilação: crypto/fips140 |
| `shim-ausente:crypto/hmac` | 1 | 1 | 0 | `github.com/pion/dtls/v3/pkg/crypto/prf` prf.go:159:6: pacote sem shim/transpilação: crypto/hmac |
| `shim-ausente:crypto/sha512` | 1 | 1 | 0 | `github.com/flynn/noise` cipher_suite.go:202:5: pacote sem shim/transpilação: crypto/sha512 |
| `shim-ausente:embed` | 1 | 1 | 0 | `github.com/ipfs/kubo/assets` assets.go:16:1: pacote sem shim/transpilação: embed |
| `shim-ausente:go/scanner` | 1 | 1 | 0 | `github.com/cockroachdb/pebble/v2/internal/dsl` dsl.go:111:1: pacote sem shim/transpilação: go/scanner |
| `shim-ausente:hash/fnv` | 1 | 1 | 0 | `github.com/caddyserver/certmagic` crypto.go:137:6: pacote sem shim/transpilação: hash/fnv |
| `shim-ausente:hash/maphash` | 1 | 1 | 0 | `github.com/ipfs/boxo/bitswap/server/internal/decision` scheduler.go:43:6: pacote sem shim/transpilação: hash/maphash |
| `shim-ausente:os/signal` | 1 | 1 | 0 | `go.uber.org/fx` signal.go:47:6: pacote sem shim/transpilação: os/signal |
| `shim-ausente:runtime/metrics` | 1 | 1 | 0 | `github.com/prometheus/client_golang/prometheus/internal` go_runtime_metrics.go:39:6: pacote sem shim/transpilação: runtime/metrics |
| `shim-simbolo:bytes.containsFunc` | 1 | 1 | 0 | `github.com/cockroachdb/pebble/v2/sstable/colblk` raw_bytes.go:78:6: símbolo sem shim: bytes.containsFunc |
| `shim-simbolo:bytes.cut` | 1 | 1 | 0 | `github.com/libp2p/go-libp2p/p2p/http/auth/internal/handshake` handshake.go:34:1: símbolo sem shim: bytes.cut |
| `shim-simbolo:bytes.cutPrefix` | 1 | 1 | 0 | `github.com/quic-go/quic-go/http3` settings_0rtt.go:17:6: símbolo sem shim: bytes.cutPrefix |
| `shim-simbolo:bytes.splitN` | 1 | 1 | 0 | `github.com/golang/protobuf/proto` text_encode.go:117:1: símbolo sem shim: bytes.splitN |
| `shim-simbolo:bytes.toLower` | 1 | 1 | 0 | `go.uber.org/zap/zapcore` level.go:32:1: símbolo sem shim: bytes.toLower |
| `shim-simbolo:bytes.trim` | 1 | 1 | 0 | `github.com/gabriel-vasile/mimetype/internal/magic` archive.go:174:6: símbolo sem shim: bytes.trim |
| `shim-simbolo:encoding/binary.appendUvarint` | 1 | 1 | 0 | `github.com/libp2p/go-libp2p/core/record` envelope.go:268:6: símbolo sem shim: encoding/binary.appendUvarint |
| `shim-simbolo:fmt.append$` | 1 | 1 | 0 | `github.com/ipfs/boxo/ipns` record.go:619:6: símbolo sem shim: fmt.append$ |
| `shim-simbolo:fmt.fprint` | 1 | 1 | 0 | `github.com/fatih/color` color.go:44:1: símbolo sem shim: fmt.fprint |
| `shim-simbolo:math.cos` | 1 | 1 | 0 | `gonum.org/v1/gonum/mathext/internal/cephes` unity.go:141:6: símbolo sem shim: math.cos |
| `shim-simbolo:math.erfc` | 1 | 1 | 0 | `gonum.org/v1/gonum/mathext/internal/cephes` igam.go:266:6: símbolo sem shim: math.erfc |
| `shim-simbolo:math.expm1` | 1 | 1 | 0 | `github.com/cockroachdb/pebble/v2/internal/ewma` ewma_bytes.go:27:1: símbolo sem shim: math.expm1 |
| `shim-simbolo:math.gamma` | 1 | 1 | 0 | `gonum.org/v1/gonum/mathext` hypergeo.go:24:6: símbolo sem shim: math.gamma |
| `shim-simbolo:math.ldexp` | 1 | 1 | 0 | `go.opentelemetry.io/otel/sdk/metric/internal/aggregate` exponential_histogram.go:130:5: símbolo sem shim: math.ldexp |
| `shim-simbolo:math.tan` | 1 | 1 | 0 | `gonum.org/v1/gonum/mathext/internal/cephes` psi.go:78:6: símbolo sem shim: math.tan |
| `shim-simbolo:strconv.quoteToASCII` | 1 | 1 | 0 | `github.com/pion/sdp/v3` base_lexer.go:16:1: símbolo sem shim: strconv.quoteToASCII |
| `shim-simbolo:strings.lastIndexFunc` | 1 | 1 | 0 | `github.com/multiformats/go-multiaddr-dns` resolve.go:16:6: símbolo sem shim: strings.lastIndexFunc |
| `shim-simbolo:strings.splitAfter` | 1 | 1 | 0 | `github.com/prometheus/client_golang/prometheus/internal` difflib.go:651:6: símbolo sem shim: strings.splitAfter |
| `shim-simbolo:strings.title` | 1 | 1 | 0 | `github.com/ipld/go-ipld-prime/node/bindnode` infer.go:387:6: símbolo sem shim: strings.title |

## Ranking por área

| área | ocorrências | pacotes |
|---|---:|---:|
| `shim-ausente` | 8974 | 873 |
| `shim-simbolo` | 818 | 284 |
| `tipo` | 200 | 92 |
| `tipo-basico` | 357 | 68 |
| `conversao` | 335 | 58 |
| `make` | 81 | 57 |
| `tipo-nomeado` | 62 | 40 |
| `builtin` | 50 | 33 |
| `generico-nao-struct` | 44 | 23 |
| `append-string` | 39 | 21 |
| `branch` | 60 | 19 |
| `import` | 16 | 16 |
| `fmt-verbo` | 78 | 15 |
| `range` | 20 | 15 |
| `constraint` | 55 | 12 |
| `copy-string` | 23 | 11 |
| `stmt` | 17 | 11 |
| `indice` | 15 | 9 |
| `literal-composto` | 12 | 9 |
| `expr` | 9 | 6 |
| `zero-value` | 7 | 6 |
| `andnot-nao-ident` | 7 | 4 |
| `func-sem-corpo` | 6 | 4 |
| `operador-unario` | 3 | 2 |
| `dart` | 11 | 1 |
| `erro-interno` | 3 | 1 |
| `construtor-ambiguo` | 1 | 1 |
| `defer-builtin` | 1 | 1 |
| `for-multi-atribuicao` | 1 | 1 |
| `layout` | 1 | 1 |
| `len` | 1 | 1 |
| `min` | 1 | 1 |

## Fronteira (237 pacotes)

Não verdes com todas as dependências do grafo verdes: o próximo trabalho.

| pacote | status | problemas |
|---|---|---|
| `github.com/cskr/pubsub` | unsupported | `tipo:chan`×3, `make:chan` |
| `github.com/golang/groupcache/lru` | unsupported | `shim-ausente:container/list`×2 |
| `github.com/ipfs/go-libdht/kad` | unsupported | `generico-nao-struct`×3 |
| `github.com/probe-lab/go-libdht/kad` | unsupported | `generico-nao-struct`×3 |
| `github.com/quic-go/quic-go/internal/utils/minheap` | unsupported | `generico-nao-struct` |
| `github.com/rivo/uniseg` | unsupported | `shim-ausente:unicode/utf8`×15, `constraint` |
| `github.com/cockroachdb/pebble/v2/internal/rawalloc` | unsupported | `func-sem-corpo`, `tipo-basico:Pointer` |
| `google.golang.org/protobuf/internal/set` | unsupported | `conversao:nao-basico` |
| `github.com/klauspost/compress` | unsupported | `shim-simbolo:math.log2`, `shim-simbolo:math.pow` |
| `gonum.org/v1/gonum/mathext/internal/gonum` | unsupported | `shim-simbolo:math.exp`, `shim-simbolo:math.lgamma` |
| `gonum.org/v1/gonum/mathext/internal/amos` | unsupported | `builtin:complex`×6, `shim-ausente:math/cmplx`×2, `builtin:real`, `shim-simbolo:math.lgamma` |
| `github.com/cockroachdb/pebble/v2/internal/invariants` | unsupported | `shim-ausente:runtime` |
| `github.com/hashicorp/golang-lru/simplelru` | unsupported | `shim-ausente:container/list`×2 |
| `github.com/cockroachdb/pebble/v2/sstable/block/blockkind` | unsupported | `shim-ausente:iter` |
| `golang.org/x/exp/slices` | unsupported | `constraint`×29 |
| `golang.org/x/net/dns/dnsmessage` | unsupported | `append-string`×2, `copy-string` |
| `github.com/beorn7/perks/quantile` | unsupported | `branch:goto` |
| `github.com/ipfs/go-ipfs-pq` | unsupported | `shim-ausente:container/heap`×2 |
| `github.com/cockroachdb/crlib/crsync` | unsupported | `shim-ausente:sync/atomic` |
| `github.com/pion/ice/v4/internal/atomic` | unsupported | `shim-ausente:sync/atomic` |
| `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc/internal/counter` | unsupported | `shim-ausente:sync/atomic` |
| `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp/internal/counter` | unsupported | `shim-ausente:sync/atomic` |
| `go.opentelemetry.io/otel/exporters/prometheus/internal/counter` | unsupported | `shim-ausente:sync/atomic` |
| `go.opentelemetry.io/otel/exporters/stdout/stdouttrace/internal/counter` | unsupported | `shim-ausente:sync/atomic` |
| `github.com/Jorropo/jsync` | unsupported | `shim-ausente:sync/atomic` |
| `github.com/cockroachdb/pebble/v2/internal/intern` | unsupported | `shim-ausente:sync`×2 |
| `github.com/guillaumemichel/reservedpool` | unsupported | `shim-ausente:sync`×2 |
| `github.com/quic-go/quic-go/internal/utils/linkedlist` | unsupported | `shim-ausente:sync`×3 |
| `go.uber.org/zap/internal/pool` | unsupported | `shim-ausente:sync`×2 |
| `google.golang.org/grpc/internal/buffer` | unsupported | `make:chan`, `tipo:chan` |
| `google.golang.org/protobuf/internal/pragma` | unsupported | `tipo-nomeado:array`×2 |
| `github.com/gabriel-vasile/mimetype/internal/json` | unsupported | `shim-ausente:sync`×2, `branch:goto` |
| `github.com/gabriel-vasile/mimetype/internal/mp3` | unsupported | `tipo-nomeado:array` |
| `github.com/ipld/go-car/v2/internal/io` | unsupported | `shim-ausente:io`×10 |
| `github.com/kr/text` | unsupported | `shim-ausente:io`×2, `shim-simbolo:bytes.trimSpace` |
| `github.com/multiformats/go-base32` | unsupported | `shim-ausente:io`×5 |
| `github.com/prometheus/client_golang/prometheus/promhttp/internal` | unsupported | `shim-ausente:io` |
| `golang.org/x/text/transform` | unsupported | `shim-ausente:io`×4, `copy-string`, `shim-ausente:unicode/utf8` |
| `github.com/spaolacci/murmur3` | unsupported | `shim-ausente:hash`×5, `tipo-basico:Pointer`×3, `conversao:nao-basico` |
| `github.com/cockroachdb/pebble/v2/internal/crc` | unsupported | `shim-ausente:hash/crc32`×3 |
| `filippo.io/bigmod` | unsupported | `builtin:None`×3 |
| `github.com/cespare/xxhash` | unsupported | `shim-ausente:hash`, `tipo-basico:Pointer` |
| `github.com/cespare/xxhash/v2` | unsupported | `append-string`, `tipo-basico:Pointer` |
| `github.com/cockroachdb/redact/internal/rfmt/fmtsort` | unsupported | `shim-ausente:reflect`×4 |
| `github.com/gabriel-vasile/mimetype/internal/scan` | unsupported | `branch:goto` |
| `github.com/golang/snappy` | unsupported | `shim-ausente:io`×5, `shim-ausente:hash/crc32`×3, `branch:goto`, `shim-simbolo:encoding/binary.putUvarint`, `shim-simbolo:encoding/binary.uvarint` |
| `github.com/klauspost/compress/internal/snapref` | unsupported | `shim-ausente:io`×5, `shim-ausente:hash/crc32`×3, `branch:goto`, `shim-simbolo:encoding/binary.putUvarint`, `shim-simbolo:encoding/binary.uvarint` |
| `github.com/klauspost/compress/zstd/internal/xxhash` | unsupported | `append-string` |
| `github.com/multiformats/go-varint` | unsupported | `shim-simbolo:encoding/binary.putUvarint`×2, `shim-ausente:io` |
| `github.com/rogpeppe/go-internal/fmtsort` | unsupported | `shim-ausente:reflect`×5 |
| `github.com/zeebo/blake3/internal/utils` | unsupported | `tipo-basico:Pointer`×2 |
| `go.opentelemetry.io/otel/attribute/internal` | unsupported | `constraint`×4 |
| `golang.org/x/crypto/blake2b` | unsupported | `shim-ausente:hash`×5, `shim-ausente:io`×2, `append-string` |
| `golang.org/x/crypto/blake2s` | unsupported | `shim-ausente:hash`×2, `shim-ausente:io`×2, `append-string`, `shim-ausente:crypto` |
| `golang.org/x/crypto/internal/alias` | unsupported | `shim-ausente:reflect` |
| `golang.org/x/crypto/internal/poly1305` | dart-invalido | `dart:undefined_class`×8, `dart:implicit_this_reference_in_initializer`×3 |
| `github.com/anmitsu/go-shlex` | unsupported | `shim-ausente:bufio`, `shim-ausente:io`, `shim-ausente:unicode`, `shim-simbolo:strings.Reader` |
| `github.com/libp2p/go-buffer-pool` | unsupported | `copy-string`×2, `shim-ausente:sync`×2, `shim-ausente:bufio`, `shim-ausente:io` |
| `github.com/munnerz/goautoneg` | unsupported | `shim-simbolo:strconv.parseFloat` |
| `github.com/ucarion/urlpath` | unsupported | `shim-simbolo:strings.Builder` |
| `github.com/pbnjay/memory` | unsupported | `shim-ausente:syscall`×2 |
| `github.com/cenkalti/backoff/v4` | unsupported | `shim-ausente:time`×20, `shim-ausente:context`×4, `tipo:chan`×2, `generico-nao-struct`, `make:chan` |
| `github.com/cockroachdb/tokenbucket` | unsupported | `shim-ausente:time` |
| `github.com/hashicorp/golang-lru/v2/internal` | unsupported | `shim-ausente:time`×2 |
| `github.com/ipfs/boxo/routing/http/internal` | unsupported | `shim-ausente:context` |
| `github.com/ipfs/go-metrics-interface` | unsupported | `shim-ausente:context`×4, `shim-ausente:time` |
| `github.com/ipfs/kubo/internal/fusemount` | unsupported | `shim-ausente:context`×2 |
| `github.com/jbenet/go-temp-err-catcher` | unsupported | `shim-ausente:time`×3, `shim-simbolo:errors.as` |
| `github.com/libp2p/go-libp2p-pubsub/timecache` | unsupported | `shim-ausente:time`×7, `shim-ausente:sync`×3, `shim-ausente:context` |
| `github.com/pion/dtls/v3/internal/closer` | unsupported | `shim-ausente:context`×3 |
| `github.com/pion/interceptor/internal/ntp` | unsupported | `shim-ausente:time`×4 |
| `github.com/pion/transport/v3/deadline` | unsupported | `shim-ausente:time`×2, `make:chan`, `shim-ausente:sync` |
| `github.com/pion/transport/v4/deadline` | unsupported | `shim-ausente:time`×2, `make:chan`, `shim-ausente:sync` |
| `github.com/quic-go/quic-go/internal/monotime` | unsupported | `shim-ausente:time`×7 |
| `github.com/slok/go-http-metrics/metrics` | unsupported | `shim-ausente:context`×2 |
| `go.opentelemetry.io/otel/internal/baggage` | unsupported | `shim-ausente:context`×6 |
| `go.uber.org/dig/internal/digclock` | unsupported | `shim-ausente:time`×4 |
| `go.uber.org/fx/internal/fxclock` | unsupported | `shim-ausente:time`×4, `shim-ausente:context`, `shim-ausente:sync` |
| `golang.org/x/net/internal/httpsfv` | unsupported | `shim-ausente:slices`×5, `shim-ausente:time`, `shim-ausente:unicode/utf8`, `shim-simbolo:strconv.parseFloat`, `shim-simbolo:strings.Builder` |
| `google.golang.org/grpc/backoff` | unsupported | `shim-ausente:time`×2 |
| `google.golang.org/grpc/balancer/pickfirst/internal` | unsupported | `shim-ausente:math/rand/v2`×2, `shim-ausente:time`×2 |
| `google.golang.org/grpc/internal/idle` | unsupported | `shim-ausente:time`×4 |
| `google.golang.org/grpc/keepalive` | unsupported | `shim-ausente:time`×3 |
| `google.golang.org/protobuf/internal/editiondefaults` | unsupported | `import:_` |
| `github.com/RaduBerinde/btreemap` | unsupported | `generico-nao-struct`×2, `shim-ausente:io`, `shim-ausente:iter`, `shim-ausente:sync` |
| `github.com/benbjohnson/clock` | unsupported | `shim-ausente:time`×5, `tipo:chan`×4, `shim-ausente:sync`×2, `shim-ausente:context` |
| `github.com/blang/semver/v4` | unsupported | `shim-simbolo:strings.replace`×2, `shim-ausente:encoding/json`, `shim-ausente:unicode`, `shim-simbolo:strings.indexFunc`, `shim-simbolo:strings.indexRune` (+1) |
| `github.com/cenkalti/backoff/v5` | unsupported | `shim-ausente:time`×17, `tipo:chan`×2, `generico-nao-struct`, `make:chan`, `shim-ausente:context` |
| `github.com/cockroachdb/crlib/crstrings` | unsupported | `shim-ausente:slices` |
| `github.com/cockroachdb/crlib/fifo` | unsupported | `shim-ausente:sync` |
| `github.com/cockroachdb/logtags` | unsupported | `shim-ausente:context`×5, `shim-simbolo:strings.Builder` |
| `github.com/cockroachdb/pebble/v2/internal/treeprinter` | unsupported | `shim-simbolo:bytes.Buffer` |
| `github.com/cockroachdb/redact/interfaces` | unsupported | `shim-simbolo:fmt.State` |
| `github.com/cockroachdb/redact/internal/fmtforward` | unsupported | `shim-ausente:io`, `shim-simbolo:fmt.State` |
| `github.com/cockroachdb/swiss` | unsupported | `tipo-basico:Pointer`×10, `builtin:None`×2, `generico-nao-struct`×2, `conversao:nao-basico`, `fmt-verbo:%#v` (+2) |
| `github.com/crackcomm/go-gitignore` | unsupported | `shim-ausente:os`×2, `shim-ausente:regexp`×2 |
| `github.com/davidlazar/go-crypto/salsa20` | unsupported | `shim-ausente:crypto/cipher` |
| `github.com/dunglas/httpsfv` | unsupported | `shim-simbolo:strings.Builder`×15, `shim-ausente:io`×6, `shim-ausente:time`×2, `shim-ausente:unicode`×2, `shim-ausente:encoding/base64` (+1) |
| `github.com/filecoin-project/go-clock` | unsupported | `shim-ausente:time`×5, `tipo:chan`×4, `shim-ausente:sync`×2, `shim-ausente:context` |
| `github.com/gammazero/deque` | unsupported | `shim-ausente:iter` |
| `github.com/go-jose/go-jose/v4/json` | unsupported | `shim-ausente:sync` |
| `github.com/go-logfmt/logfmt` | unsupported | `shim-ausente:io`×12, `shim-simbolo:bytes.Buffer`×4, `shim-ausente:reflect`×3, `shim-ausente:bufio`, `shim-ausente:encoding` (+2) |
| `github.com/grpc-ecosystem/grpc-gateway/v2/utilities` | unsupported | `shim-ausente:flag`, `shim-ausente:io` |
| `github.com/hashicorp/go-version` | unsupported | `shim-ausente:regexp`×7, `shim-simbolo:strconv.appendInt` |
| `github.com/huin/goupnp/scpd` | unsupported | `shim-ausente:encoding/xml`, `shim-simbolo:strings.trimSpace` |
| `github.com/ipfs/boxo/routing/http/internal/drjson` | unsupported | `shim-simbolo:bytes.Buffer`×2 |
| `github.com/ipfs/boxo/routing/http/types/iter` | unsupported | `generico-nao-struct`×2, `shim-ausente:encoding/json`, `shim-ausente:io` |
| `github.com/ipfs/go-datastore/query` | unsupported | `shim-simbolo:strings.compare`×3, `tipo:chan`×3, `range:chan`, `shim-ausente:context`, `shim-ausente:path` (+3) |
| `github.com/ipfs/kubo/repo/common` | unsupported | `shim-ausente:maps` |
| `github.com/ipld/go-ipld-prime/datamodel` | unsupported | `shim-ausente:io`, `shim-simbolo:strings.Builder`, `shim-simbolo:strings.fieldsFunc` |
| `github.com/ipld/go-ipld-prime/storage` | unsupported | `shim-ausente:context`×14, `shim-ausente:io` |
| `github.com/klauspost/compress/fse` | unsupported | `shim-ausente:io` |
| `github.com/klauspost/cpuid/v2` | unsupported | `shim-ausente:flag`, `shim-ausente:os`, `shim-ausente:slices`, `shim-simbolo:strings.toLower`, `shim-simbolo:strings.toUpper` (+3) |
| `github.com/libp2p/go-libp2p-kad-dht/provider/internal/connectivity` | unsupported | `shim-ausente:time`×5, `make:chan`, `tipo:chan` |
| `github.com/libp2p/go-libp2p/core/pnet` | unsupported | `shim-ausente:bufio`×2, `shim-ausente:io`, `shim-ausente:os` |
| `github.com/mikioh/tcpopt` | unsupported | `tipo-basico:Pointer`×7, `shim-ausente:time`×6, `conversao:bool-bool`×4, `tipo-nomeado:bool`×4, `shim-ausente:sync` |
| `github.com/multiformats/go-multihash/core` | unsupported | `shim-ausente:hash`×7, `shim-ausente:crypto/md5`, `shim-simbolo:bytes.Buffer` |
| `github.com/opentracing/opentracing-go/log` | unsupported | `shim-ausente:reflect` |
| `github.com/pion/dtls/v3/pkg/crypto/ccm` | unsupported | `shim-ausente:crypto/cipher`×3 |
| `github.com/pion/dtls/v3/pkg/crypto/hash` | unsupported | `shim-ausente:crypto/md5` |
| `github.com/pion/rtcp` | unsupported | `shim-ausente:reflect`×4, `copy-string`, `shim-simbolo:strings.replaceAll` |
| `github.com/pion/stun/v3/internal/hmac` | unsupported | `shim-ausente:hash`×6, `shim-ausente:sync`×2, `shim-ausente:crypto/sha1`, `shim-ausente:crypto/sha256` |
| `github.com/pion/transport/v4/replaydetector` | unsupported | `shim-simbolo:strings.Builder` |
| `github.com/pion/webrtc/v4/internal/fmtp` | unsupported | `shim-simbolo:strings.equalFold`×3, `shim-simbolo:strings.toLower`×2, `shim-ausente:encoding/hex`, `shim-simbolo:strings.trimSpace` |
| `github.com/pkg/errors` | unsupported | `shim-simbolo:fmt.State`×5, `shim-ausente:runtime`×2, `shim-simbolo:errors.as`, `shim-simbolo:errors.is$`, `shim-simbolo:errors.unwrap` |
| `github.com/polydawn/refmt/obj/atlas` | unsupported | `shim-ausente:reflect`×18, `shim-ausente:unicode`×2 |
| `github.com/polydawn/refmt/pretty` | unsupported | `shim-ausente:io`×2 |
| `github.com/polydawn/refmt/shared` | unsupported | `shim-ausente:io`×5, `shim-simbolo:bytes.Buffer` |
| `github.com/prometheus/otlptranslator` | unsupported | `shim-simbolo:strings.Builder`×2, `shim-simbolo:strings.fieldsFunc`×2, `shim-ausente:slices`, `shim-ausente:unicode`, `shim-simbolo:strings.map` (+1) |
| `github.com/prometheus/procfs/internal/util` | unsupported | `shim-ausente:os`×5, `shim-simbolo:strings.trimSpace`×2 |
| `github.com/quic-go/quic-go/qlogwriter/jsontext` | unsupported | `shim-ausente:io`×2, `builtin:None` |
| `github.com/quic-go/quic-go/quicvarint` | unsupported | `shim-ausente:io`×8, `shim-simbolo:bytes.Buffer`, `shim-simbolo:bytes.Reader` |
| `github.com/syndtr/goleveldb/leveldb/util` | unsupported | `shim-ausente:hash/crc32`×3, `shim-ausente:sync`×2, `shim-simbolo:bytes.errTooLarge`×2 |
| `github.com/texttheater/golang-levenshtein/levenshtein` | unsupported | `shim-ausente:io`, `shim-ausente:os` |
| `go.opencensus.io/internal` | unsupported | `shim-ausente:time`×2, `shim-ausente:unicode`, `shim-simbolo:strings.map` |
| `go.opencensus.io/resource` | unsupported | `shim-ausente:context`×4, `shim-ausente:regexp`×2, `shim-simbolo:strconv.quote`, `shim-simbolo:strings.trimSpace` |
| `go.opencensus.io/trace/tracestate` | unsupported | `shim-ausente:regexp`×5 |
| `go.opentelemetry.io/auto/sdk/internal/telemetry` | unsupported | `shim-simbolo:bytes.Reader`×6, `conversao:nao-basico`×4, `shim-ausente:time`×4, `shim-ausente:encoding/hex`×2, `shim-ausente:encoding/json`×2 (+4) |
| `go.opentelemetry.io/otel/codes` | unsupported | `shim-ausente:encoding/json` |
| `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc/internal/x` | unsupported | `shim-ausente:os`, `shim-simbolo:strings.equalFold` |
| `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp/internal/x` | unsupported | `shim-ausente:os`, `shim-simbolo:strings.equalFold` |
| `go.opentelemetry.io/otel/exporters/prometheus/internal/x` | unsupported | `shim-ausente:os`, `shim-simbolo:strings.equalFold` |
| `go.opentelemetry.io/otel/exporters/stdout/stdouttrace/internal/x` | unsupported | `shim-ausente:os`, `shim-simbolo:strings.equalFold` |
| `go.opentelemetry.io/otel/sdk/internal/x` | unsupported | `shim-simbolo:strings.equalFold`×3, `shim-ausente:os` |
| `go.opentelemetry.io/otel/sdk/metric/internal/x` | unsupported | `shim-ausente:os` |
| `go.opentelemetry.io/otel/trace/internal/telemetry` | unsupported | `shim-simbolo:bytes.Reader`×6, `conversao:nao-basico`×4, `shim-ausente:time`×4, `shim-ausente:encoding/hex`×2, `shim-ausente:encoding/json`×2 (+4) |
| `go.uber.org/dig/internal/dot` | unsupported | `shim-ausente:reflect`×4 |
| `go.uber.org/multierr` | unsupported | `shim-ausente:io`×2, `shim-ausente:sync`, `shim-ausente:sync/atomic`, `shim-simbolo:bytes.Buffer`, `shim-simbolo:errors.is$` |
| `go.uber.org/zap/internal/exit` | unsupported | `shim-ausente:os` |
| `golang.org/x/crypto/curve25519` | unsupported | `shim-ausente:crypto/ecdh`×2, `range:pointer` |
| `golang.org/x/crypto/hkdf` | unsupported | `shim-ausente:hash`×4 |
| `golang.org/x/exp/mmap` | unsupported | `builtin:println`, `shim-ausente:os` |
| `golang.org/x/net/bpf` | unsupported | `fmt-verbo:%#v`×9 |
| `golang.org/x/net/http2/hpack` | unsupported | `shim-simbolo:bytes.Buffer`×4, `shim-ausente:io`×3, `shim-ausente:sync`×2, `append-string`, `tipo-nomeado:array` |
| `golang.org/x/sync/errgroup` | unsupported | `shim-ausente:context`, `shim-ausente:sync` |
| `golang.org/x/text/internal/language` | unsupported | `copy-string`×8, `shim-simbolo:bytes.join`×3, `append-string`, `shim-simbolo:bytes.Buffer`, `shim-simbolo:strings.toLower` |
| `golang.org/x/text/unicode/bidi` | unsupported | `shim-ausente:container/list`×2, `shim-simbolo:bytes.runes`×2, `shim-ausente:unicode/utf8` |
| `golang.org/x/time/rate` | unsupported | `shim-ausente:time`×5, `shim-ausente:sync` |
| `golang.org/x/xerrors` | unsupported | `shim-simbolo:fmt.State`×6, `shim-ausente:runtime`×2, `shim-ausente:unicode/utf8`, `shim-simbolo:errors.as`, `shim-simbolo:errors.is$` (+1) |
| `google.golang.org/grpc/attributes` | unsupported | `fmt-verbo:%p`, `shim-ausente:maps` |
| `google.golang.org/grpc/internal/envconfig` | unsupported | `shim-ausente:os`×8 |
| `google.golang.org/protobuf/internal/detrand` | unsupported | `shim-ausente:os` |
| `gopkg.in/yaml.v2` | unsupported | `shim-ausente:reflect`×18, `shim-ausente:io`×11, `shim-ausente:regexp`×5, `shim-ausente:time`×4, `shim-ausente:encoding/base64` (+2) |
| `gopkg.in/yaml.v3` | unsupported | `shim-ausente:reflect`×22, `shim-ausente:io`×11, `shim-ausente:regexp`×5, `shim-ausente:time`×4, `shim-ausente:encoding/base64` (+2) |
| `github.com/AndreasBriese/bbloom` | unsupported | `shim-ausente:encoding/json`, `shim-ausente:log`, `shim-ausente:sync`, `shim-simbolo:math.log`, `tipo-basico:Pointer` |
| `github.com/gogo/protobuf/proto` | unsupported | `shim-ausente:sync` |
| `github.com/ipfs/bbloom` | unsupported | `shim-ausente:encoding/json`, `shim-ausente:sync`, `shim-simbolo:math.log` |
| `github.com/koron/go-ssdp/internal/ssdplog` | unsupported | `shim-ausente:log`×2 |
| `github.com/pion/logging` | unsupported | `shim-ausente:io`×2, `conversao:nao-basico`, `shim-ausente:log`, `shim-ausente:os`, `shim-ausente:sync` |
| `go.opentelemetry.io/otel/internal/errorhandler` | unsupported | `shim-ausente:sync/atomic`×4, `shim-ausente:log` |
| `golang.org/x/net/internal/timeseries` | unsupported | `shim-ausente:time`×11 |
| `google.golang.org/grpc/grpclog/internal` | unsupported | `shim-ausente:io`×2, `shim-ausente:log`, `shim-ausente:os`, `shim-simbolo:fmt.sprintln` |
| `github.com/go-logr/logr` | unsupported | `shim-ausente:log/slog`×7, `shim-ausente:context`×6 |
| `github.com/libp2p/go-libp2p-pubsub/internal/gologshim` | unsupported | `shim-ausente:log/slog`×5, `shim-ausente:os` |
| `github.com/libp2p/go-libp2p/gologshim` | unsupported | `shim-ausente:log/slog`×7, `shim-ausente:os`, `shim-ausente:sync` |
| `github.com/dustin/go-humanize` | unsupported | `shim-ausente:math/big`×38, `shim-ausente:time`×6, `shim-ausente:regexp`×3, `shim-simbolo:math.pow`×3, `shim-simbolo:strconv.formatFloat`×2 (+4) |
| `github.com/klauspost/compress/s2` | unsupported | `branch:goto`×14, `shim-ausente:sync`×10, `shim-ausente:io`×8, `shim-simbolo:encoding/binary.putUvarint`×8, `shim-ausente:hash/crc32`×3 (+4) |
| `github.com/mr-tron/base58` | unsupported | `shim-ausente:math/big`×5, `copy-string` |
| `github.com/mr-tron/base58/base58` | unsupported | `shim-ausente:math/big`×5, `copy-string` |
| `github.com/pion/dtls/v3/pkg/crypto/elliptic` | unsupported | `shim-ausente:crypto/ecdh`, `shim-ausente:crypto/rand` |
| `github.com/pion/randutil` | unsupported | `shim-ausente:crypto/rand`×2, `shim-ausente:math/rand`, `shim-ausente:time` |
| `github.com/whyrusleeping/cbor/go` | unsupported | `shim-ausente:reflect`×11, `shim-ausente:io`×9, `shim-ausente:math/big`×2, `shim-simbolo:bytes.Buffer`, `shim-simbolo:bytes.Reader` |
| `github.com/whyrusleeping/chunker` | unsupported | `shim-ausente:sync` |
| `github.com/whyrusleeping/go-keyspace` | unsupported | `shim-ausente:math/big`×3, `shim-ausente:crypto/sha256` |
| `golang.org/x/crypto/cryptobyte` | unsupported | `shim-ausente:math/big`×3, `shim-ausente:encoding/asn1`, `shim-ausente:reflect` |
| `github.com/cheggaaa/pb/v3/termutil` | unsupported | `shim-ausente:os`×6, `tipo:chan`×2, `shim-ausente:sync` |
| `github.com/hanwen/go-fuse/v2/internal` | unsupported | `shim-ausente:os/user` |
| `github.com/caddyserver/certmagic/internal/atomicfile` | unsupported | `shim-ausente:io/fs`×2, `shim-ausente:io`, `shim-ausente:os` |
| `github.com/facebookgo/atomicfile` | unsupported | `shim-ausente:io/fs`, `shim-ausente:os` |
| `github.com/ipfs/kubo/misc/fsutil` | unsupported | `shim-ausente:os`×3 |
| `github.com/ipfs/kubo/repo/fsrepo/migrations/atomicfile` | unsupported | `shim-ausente:io/fs`, `shim-ausente:os` |
| `github.com/prometheus/procfs/internal/fs` | unsupported | `shim-ausente:os`, `shim-ausente:path/filepath` |
| `github.com/syndtr/goleveldb/leveldb/storage` | unsupported | `shim-ausente:os`×7, `shim-ausente:io`×3, `shim-ausente:io/fs`×2, `shim-ausente:sync`×2, `shim-simbolo:bytes.Buffer` (+2) |
| `golang.org/x/sys/execabs` | unsupported | `shim-ausente:os/exec`×6, `shim-ausente:context` |
| `github.com/RaduBerinde/axisds` | unsupported | `generico-nao-struct`×4, `shim-ausente:regexp`, `shim-simbolo:fmt.sscanf` |
| `github.com/ipfs/kubo/core/commands/e` | unsupported | `shim-ausente:runtime/debug` |
| `github.com/libp2p/go-libp2p/core/internal/catch` | unsupported | `shim-ausente:io`, `shim-ausente:os`, `shim-ausente:runtime/debug` |
| `github.com/libp2p/go-libp2p/p2p/protocol/identify/internal/user-agent` | unsupported | `shim-ausente:runtime/debug` |
| `go.opencensus.io/tag` | unsupported | `shim-ausente:context`×5, `shim-simbolo:bytes.Buffer`, `shim-simbolo:encoding/binary.putUvarint` |
| `github.com/decred/dcrd/dcrec/secp256k1/v4` | unsupported | `shim-ausente:math/big`×6, `shim-ausente:encoding/hex`×4, `shim-ausente:crypto/elliptic`×2, `shim-ausente:io`×2, `shim-simbolo:bytes.repeat`×2 (+6) |
| `github.com/libdns/libdns` | unsupported | `shim-ausente:time`×9, `shim-ausente:context`×5, `shim-simbolo:strings.Builder`, `shim-simbolo:strings.trim`, `shim-simbolo:strings.trimSpace` |
| `github.com/google/gopacket/routing` | unsupported | `shim-ausente:net`×4, `shim-ausente:syscall` |
| `github.com/google/uuid` | unsupported | `shim-ausente:io`×6, `shim-ausente:net`×2, `shim-ausente:os`×2, `shim-ausente:sync`×2, `shim-ausente:time`×2 (+9) |
| `github.com/jackpal/go-nat-pmp` | unsupported | `shim-ausente:time`×4, `shim-ausente:net`×3 |
| `github.com/libp2p/go-cidranger/net` | unsupported | `shim-ausente:net`×6 |
| `github.com/libp2p/go-libp2p-asn-util` | unsupported | `import:_` |
| `github.com/libp2p/go-netroute` | unsupported | `shim-ausente:net`×7, `shim-ausente:syscall`×2, `shim-simbolo:bytes.Buffer`×2 |
| `github.com/pion/dtls/v3/pkg/net` | unsupported | `shim-ausente:net`×5 |
| `github.com/pion/dtls/v3/pkg/protocol` | unsupported | `literal-composto:pointer`, `shim-ausente:net` |
| `github.com/pion/ice/v4/internal/fakenet` | unsupported | `shim-ausente:net`×2 |
| `github.com/pion/transport/v3` | unsupported | `shim-ausente:net`×7 |
| `github.com/pion/transport/v4` | unsupported | `shim-ausente:net`×7, `shim-ausente:context` |
| `github.com/pion/transport/v4/netctx` | unsupported | `shim-ausente:context`×5, `shim-ausente:net`×5, `shim-ausente:io`×2, `shim-ausente:time`×2 |
| `github.com/pion/turn/v4/internal/ipnet` | unsupported | `shim-ausente:net`×3 |
| `github.com/whyrusleeping/multiaddr-filter` | unsupported | `shim-ausente:net`×2 |
| `github.com/wlynxg/anet` | unsupported | `shim-ausente:net`×3 |
| `golang.org/x/net/internal/socks` | unsupported | `shim-ausente:net`×4, `shim-ausente:time`×3, `shim-ausente:context` |
| `google.golang.org/grpc/internal/resolver/dns/internal` | unsupported | `shim-ausente:context`, `tipo:chan` |
| `github.com/cockroachdb/pebble/v2/internal/lsmview` | unsupported | `shim-ausente:net/url` |
| `github.com/coreos/go-systemd/v22/activation` | unsupported | `shim-ausente:net`×3, `shim-ausente:crypto/tls`×2, `shim-ausente:os`×2 |
| `github.com/getsentry/sentry-go/internal/otel/baggage` | unsupported | `shim-ausente:regexp`×9, `shim-simbolo:strings.Builder`, `shim-simbolo:strings.trimSpace` |
| `github.com/pion/dtls/v3/pkg/crypto/fingerprint` | unsupported | `shim-ausente:crypto`×3, `shim-ausente:crypto/x509` |
| `go.uber.org/dig/internal/digreflect` | unsupported | `shim-ausente:net/url`, `shim-ausente:reflect`, `shim-ausente:runtime`, `shim-simbolo:fmt.State` |
| `go.uber.org/fx/internal/fxreflect` | unsupported | `shim-ausente:regexp`×2, `shim-ausente:net/url`, `shim-ausente:reflect`, `shim-ausente:runtime`, `shim-simbolo:fmt.State` (+1) |
| `golang.org/x/crypto/ocsp` | unsupported | `import:_` |
| `github.com/caddyserver/zerossl` | unsupported | `shim-ausente:net/http`×2, `shim-ausente:crypto/x509`, `shim-ausente:encoding/base64`, `shim-ausente:time`, `tipo-nomeado:bool` |
| `github.com/felixge/httpsnoop` | unsupported | `shim-ausente:net/http`×520, `shim-ausente:time`×4, `shim-ausente:io`, `shim-ausente:net`, `tipo:chan` |
| `github.com/gorilla/mux` | unsupported | `shim-ausente:net/http`×22, `shim-ausente:regexp`×5, `shim-ausente:path`, `shim-simbolo:bytes.indexAny` |
| `github.com/huin/goupnp/soap` | unsupported | `shim-ausente:regexp`×15, `shim-ausente:time`×11, `shim-ausente:net/url`×4, `shim-simbolo:strconv.formatFloat`×3, `shim-simbolo:strconv.parseFloat`×3 (+6) |
| `github.com/ipfs/kubo/client/rpc/auth` | unsupported | `shim-ausente:net/http`×2 |
| `github.com/mholt/acmez/v3/acme` | unsupported | `import:_` |
| `github.com/prometheus/client_golang/internal/github.com/golang/gddo/httputil/header` | unsupported | `shim-ausente:net/http` |
| `github.com/rs/cors` | unsupported | `shim-ausente:net/http`×2, `shim-ausente:log` |
| `go.opencensus.io/zpages/internal` | unsupported | `shim-ausente:net/http`×4, `literal-composto:pointer`, `shim-ausente:io/ioutil`, `shim-ausente:path`, `shim-ausente:sync` (+1) |
| `go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp/internal/request` | unsupported | `shim-ausente:io`×2, `shim-ausente:net/http`×2 |
| `golang.org/x/oauth2/internal` | unsupported | `shim-ausente:context`×3, `shim-ausente:net/url`×2, `shim-ausente:time`×2, `shim-ausente:crypto/rsa`, `shim-ausente:encoding/json` (+3) |
| `github.com/getsentry/sentry-go/internal/debug` | unsupported | `shim-ausente:net/http` |

## Pacotes (ordem de inicialização do Go)

| # | pacote | status | problemas |
|---:|---|---|---|
| 1 | `github.com/VividCortex/ewma` | verde |  |
| 2 | `github.com/cockroachdb/crlib/internal/invariants` | verde |  |
| 3 | `github.com/cockroachdb/errors/stdstrings` | verde |  |
| 4 | `github.com/cockroachdb/pebble/v2/internal/bitflip` | verde |  |
| 5 | `github.com/cockroachdb/pebble/v2/internal/buildtags` | verde |  |
| 6 | `github.com/cockroachdb/pebble/v2/internal/constants` | verde |  |
| 7 | `github.com/cskr/pubsub` | unsupported | `tipo:chan`×3, `make:chan` |
| 8 | `github.com/dgraph-io/badger/options` | verde |  |
| 9 | `github.com/dgraph-io/badger/trie` | verde |  |
| 10 | `github.com/getsentry/sentry-go/internal/otel/baggage/internal/baggage` | verde |  |
| 11 | `github.com/golang/groupcache/lru` | unsupported | `shim-ausente:container/list`×2 |
| 12 | `github.com/hanwen/go-fuse/v2/internal/ioctl` | verde |  |
| 13 | `github.com/ipfs/boxo/ipld/unixfs/internal` | verde |  |
| 14 | `github.com/ipfs/go-libdht/kad` | unsupported | `generico-nao-struct`×3 |
| 15 | `github.com/klauspost/compress/internal/race` | verde |  |
| 16 | `github.com/libp2p/go-libp2p/core/control` | verde |  |
| 17 | `github.com/pion/dtls/v3/internal/ciphersuite/types` | verde |  |
| 18 | `github.com/pion/dtls/v3/pkg/crypto/clientcertificate` | verde |  |
| 19 | `github.com/pion/interceptor/internal/sequencenumber` | verde |  |
| 20 | `github.com/probe-lab/go-libdht/kad` | unsupported | `generico-nao-struct`×3 |
| 21 | `github.com/quic-go/quic-go/internal/utils/minheap` | unsupported | `generico-nao-struct` |
| 22 | `github.com/quic-go/quic-go/internal/utils/ringbuffer` | verde |  |
| 23 | `github.com/zeebo/blake3/internal/alg/compress/compress_sse41` | substituicao | assembly: impl_amd64.s |
| 24 | `github.com/zeebo/blake3/internal/alg/hash/hash_avx2` | substituicao | assembly: impl_amd64.s |
| 25 | `github.com/zeebo/blake3/internal/consts` | verde |  |
| 26 | `go.opencensus.io` | verde |  |
| 27 | `go.opencensus.io/internal/tagencoding` | verde |  |
| 28 | `go.opencensus.io/trace/internal` | verde |  |
| 29 | `go.opentelemetry.io/otel/exporters/prometheus/internal` | verde |  |
| 30 | `go.opentelemetry.io/otel/exporters/stdout/stdouttrace/internal` | verde |  |
| 31 | `go.opentelemetry.io/otel/metric/embedded` | verde |  |
| 32 | `go.opentelemetry.io/otel/sdk` | verde |  |
| 33 | `go.opentelemetry.io/otel/sdk/metric/internal` | verde |  |
| 34 | `go.opentelemetry.io/otel/sdk/metric/internal/reservoir` | verde |  |
| 35 | `go.opentelemetry.io/otel/trace/embedded` | verde |  |
| 36 | `go.uber.org/dig/internal/graph` | verde |  |
| 37 | `golang.org/x/crypto/cryptobyte/asn1` | verde |  |
| 38 | `golang.org/x/exp/constraints` | verde |  |
| 39 | `golang.org/x/net/internal/iana` | verde |  |
| 40 | `golang.org/x/xerrors/internal` | verde |  |
| 41 | `google.golang.org/grpc/encoding/internal` | verde |  |
| 42 | `google.golang.org/grpc/internal/transport/internal` | verde |  |
| 43 | `google.golang.org/grpc/serviceconfig` | verde |  |
| 44 | `google.golang.org/protobuf/internal/flags` | verde |  |
| 45 | `github.com/rivo/uniseg` | unsupported | `shim-ausente:unicode/utf8`×15, `constraint` |
| 46 | `github.com/cockroachdb/pebble/v2/internal/rawalloc` | unsupported | `func-sem-corpo`, `tipo-basico:Pointer` |
| 47 | `github.com/cockroachdb/pebble/v2/internal/bytealloc` | bloqueado | `dart:uri_does_not_exist` |
| 48 | `github.com/zeebo/blake3/internal/alg/compress/compress_pure` | verde |  |
| 49 | `github.com/zeebo/blake3/internal/alg/compress` | bloqueado | `dart:uri_does_not_exist` |
| 50 | `golang.org/x/crypto/salsa20/salsa` | verde |  |
| 51 | `google.golang.org/protobuf/internal/set` | unsupported | `conversao:nao-basico` |
| 52 | `github.com/klauspost/compress` | unsupported | `shim-simbolo:math.log2`, `shim-simbolo:math.pow` |
| 53 | `github.com/petar/GoLLRB/llrb` | verde |  |
| 54 | `gonum.org/v1/gonum/mathext/internal/gonum` | unsupported | `shim-simbolo:math.exp`, `shim-simbolo:math.lgamma` |
| 55 | `gonum.org/v1/gonum/mathext/internal/cephes` | unsupported | `shim-simbolo:math.log`×9, `shim-simbolo:math.pow`×3, `shim-simbolo:math.lgamma`×2, `branch:goto`, `shim-simbolo:math.cos` (+4) |
| 56 | `gonum.org/v1/gonum/mathext/internal/amos` | unsupported | `builtin:complex`×6, `shim-ausente:math/cmplx`×2, `builtin:real`, `shim-simbolo:math.lgamma` |
| 57 | `gonum.org/v1/gonum/mathext` | unsupported | `shim-simbolo:math.log`×8, `builtin:real`×3, `shim-simbolo:math.round`×3, `shim-simbolo:math.modf`×2, `shim-simbolo:math.pow`×2 (+3) |
| 58 | `github.com/cockroachdb/pebble/v2/internal/invariants` | unsupported | `shim-ausente:runtime` |
| 59 | `github.com/cockroachdb/pebble/v2/internal/ewma` | unsupported | `shim-simbolo:math.expm1` |
| 60 | `github.com/pion/transport/v3/utils/xor` | verde |  |
| 61 | `github.com/pion/transport/v4/utils/xor` | verde |  |
| 62 | `github.com/hashicorp/golang-lru/simplelru` | unsupported | `shim-ausente:container/list`×2 |
| 63 | `github.com/pion/rtp/codecs/vp9` | verde |  |
| 64 | `github.com/cockroachdb/pebble/v2/sstable/block/blockkind` | unsupported | `shim-ausente:iter` |
| 65 | `golang.org/x/exp/slices` | unsupported | `constraint`×29 |
| 66 | `golang.org/x/net/dns/dnsmessage` | unsupported | `append-string`×2, `copy-string` |
| 67 | `github.com/beorn7/perks/quantile` | unsupported | `branch:goto` |
| 68 | `github.com/gogo/protobuf/sortkeys` | verde |  |
| 69 | `github.com/ipfs/go-ipfs-pq` | unsupported | `shim-ausente:container/heap`×2 |
| 70 | `golang.org/x/text/internal/tag` | verde |  |
| 71 | `github.com/cockroachdb/crlib/crsync` | unsupported | `shim-ausente:sync/atomic` |
| 72 | `github.com/pion/ice/v4/internal/atomic` | unsupported | `shim-ausente:sync/atomic` |
| 73 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc/internal/counter` | unsupported | `shim-ausente:sync/atomic` |
| 74 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp/internal/counter` | unsupported | `shim-ausente:sync/atomic` |
| 75 | `go.opentelemetry.io/otel/exporters/prometheus/internal/counter` | unsupported | `shim-ausente:sync/atomic` |
| 76 | `go.opentelemetry.io/otel/exporters/stdout/stdouttrace/internal/counter` | unsupported | `shim-ausente:sync/atomic` |
| 77 | `github.com/Jorropo/jsync` | unsupported | `shim-ausente:sync/atomic` |
| 78 | `github.com/cockroachdb/pebble/v2/internal/intern` | unsupported | `shim-ausente:sync`×2 |
| 79 | `github.com/guillaumemichel/reservedpool` | unsupported | `shim-ausente:sync`×2 |
| 80 | `github.com/quic-go/quic-go/internal/utils/linkedlist` | unsupported | `shim-ausente:sync`×3 |
| 81 | `go.uber.org/zap/internal/pool` | unsupported | `shim-ausente:sync`×2 |
| 82 | `google.golang.org/grpc/internal/buffer` | unsupported | `make:chan`, `tipo:chan` |
| 83 | `google.golang.org/protobuf/internal/pragma` | unsupported | `tipo-nomeado:array`×2 |
| 84 | `github.com/gabriel-vasile/mimetype/internal/json` | unsupported | `shim-ausente:sync`×2, `branch:goto` |
| 85 | `github.com/gabriel-vasile/mimetype/internal/mp3` | unsupported | `tipo-nomeado:array` |
| 86 | `github.com/getsentry/sentry-go/internal/traceparser` | verde |  |
| 87 | `github.com/ipld/go-car/v2/internal/io` | unsupported | `shim-ausente:io`×10 |
| 88 | `github.com/kr/text` | unsupported | `shim-ausente:io`×2, `shim-simbolo:bytes.trimSpace` |
| 89 | `github.com/multiformats/go-base32` | unsupported | `shim-ausente:io`×5 |
| 90 | `github.com/prometheus/client_golang/prometheus/promhttp/internal` | unsupported | `shim-ausente:io` |
| 91 | `github.com/syndtr/goleveldb/leveldb/comparer` | verde |  |
| 92 | `golang.org/x/text/transform` | unsupported | `shim-ausente:io`×4, `copy-string`, `shim-ausente:unicode/utf8` |
| 93 | `github.com/spaolacci/murmur3` | unsupported | `shim-ausente:hash`×5, `tipo-basico:Pointer`×3, `conversao:nao-basico` |
| 94 | `github.com/cockroachdb/pebble/v2/internal/crc` | unsupported | `shim-ausente:hash/crc32`×3 |
| 95 | `filippo.io/bigmod` | unsupported | `builtin:None`×3 |
| 96 | `github.com/cespare/xxhash` | unsupported | `shim-ausente:hash`, `tipo-basico:Pointer` |
| 97 | `github.com/cespare/xxhash/v2` | unsupported | `append-string`, `tipo-basico:Pointer` |
| 98 | `github.com/cockroachdb/redact/internal/rfmt/fmtsort` | unsupported | `shim-ausente:reflect`×4 |
| 99 | `github.com/gabriel-vasile/mimetype/internal/scan` | unsupported | `branch:goto` |
| 100 | `github.com/gabriel-vasile/mimetype/internal/cdf` | bloqueado | `dart:uri_does_not_exist` |
| 101 | `github.com/gabriel-vasile/mimetype/internal/csv` | bloqueado | `dart:uri_does_not_exist` |
| 102 | `github.com/gabriel-vasile/mimetype/internal/markup` | bloqueado | `dart:uri_does_not_exist` |
| 103 | `github.com/golang/snappy` | unsupported | `shim-ausente:io`×5, `shim-ausente:hash/crc32`×3, `branch:goto`, `shim-simbolo:encoding/binary.putUvarint`, `shim-simbolo:encoding/binary.uvarint` |
| 104 | `github.com/klauspost/compress/internal/le` | verde |  |
| 105 | `github.com/klauspost/compress/internal/snapref` | unsupported | `shim-ausente:io`×5, `shim-ausente:hash/crc32`×3, `branch:goto`, `shim-simbolo:encoding/binary.putUvarint`, `shim-simbolo:encoding/binary.uvarint` |
| 106 | `github.com/klauspost/compress/zstd/internal/xxhash` | unsupported | `append-string` |
| 107 | `github.com/multiformats/go-varint` | unsupported | `shim-simbolo:encoding/binary.putUvarint`×2, `shim-ausente:io` |
| 108 | `github.com/pion/dtls/v3/internal/util` | verde |  |
| 109 | `github.com/rogpeppe/go-internal/fmtsort` | unsupported | `shim-ausente:reflect`×5 |
| 110 | `github.com/zeebo/blake3/internal/utils` | unsupported | `tipo-basico:Pointer`×2 |
| 111 | `github.com/zeebo/blake3/internal/alg/hash/hash_pure` | unsupported | `tipo-basico:Pointer` |
| 112 | `github.com/zeebo/blake3/internal/alg/hash` | bloqueado | `dart:uri_does_not_exist`×2 |
| 113 | `github.com/zeebo/blake3/internal/alg` | bloqueado | `dart:prefix_collides_with_top_level_member`, `dart:undefined_method`, `dart:unused_import` |
| 114 | `go.opentelemetry.io/otel/attribute/internal` | unsupported | `constraint`×4 |
| 115 | `go.opentelemetry.io/otel/attribute/internal/xxhash` | bloqueado | `dart:uri_does_not_exist` |
| 116 | `golang.org/x/crypto/blake2b` | unsupported | `shim-ausente:hash`×5, `shim-ausente:io`×2, `append-string` |
| 117 | `golang.org/x/crypto/blake2s` | unsupported | `shim-ausente:hash`×2, `shim-ausente:io`×2, `append-string`, `shim-ausente:crypto` |
| 118 | `golang.org/x/crypto/internal/alias` | unsupported | `shim-ausente:reflect` |
| 119 | `golang.org/x/crypto/internal/poly1305` | dart-invalido | `dart:undefined_class`×8, `dart:implicit_this_reference_in_initializer`×3 |
| 120 | `golang.org/x/crypto/salsa20` | bloqueado | `dart:uri_does_not_exist` |
| 121 | `github.com/anmitsu/go-shlex` | unsupported | `shim-ausente:bufio`, `shim-ausente:io`, `shim-ausente:unicode`, `shim-simbolo:strings.Reader` |
| 122 | `github.com/gabriel-vasile/mimetype/internal/charset` | unsupported | `shim-ausente:unicode/utf8`, `shim-simbolo:bytes.trimSpace`, `shim-simbolo:strings.toLower` |
| 123 | `github.com/ipfs/go-libdht/kad/key` | unsupported | `conversao:nao-basico`×3, `generico-nao-struct` |
| 124 | `github.com/ipfs/go-libdht/kad/key/bitstr` | bloqueado |  |
| 125 | `github.com/ipfs/go-libdht/kad/trie` | unsupported | `shim-ausente:slices` |
| 126 | `github.com/libp2p/go-buffer-pool` | unsupported | `copy-string`×2, `shim-ausente:sync`×2, `shim-ausente:bufio`, `shim-ausente:io` |
| 127 | `github.com/libp2p/go-msgio` | unsupported | `shim-ausente:io`×26, `shim-simbolo:encoding/binary._bigEndian` |
| 128 | `github.com/munnerz/goautoneg` | unsupported | `shim-simbolo:strconv.parseFloat` |
| 129 | `github.com/probe-lab/go-libdht/kad/key` | unsupported | `conversao:nao-basico`×3, `generico-nao-struct` |
| 130 | `github.com/rs/cors/internal` | verde |  |
| 131 | `github.com/ucarion/urlpath` | unsupported | `shim-simbolo:strings.Builder` |
| 132 | `github.com/pbnjay/memory` | unsupported | `shim-ausente:syscall`×2 |
| 133 | `github.com/cenkalti/backoff/v4` | unsupported | `shim-ausente:time`×20, `shim-ausente:context`×4, `tipo:chan`×2, `generico-nao-struct`, `make:chan` |
| 134 | `github.com/cockroachdb/crlib/crtime` | unsupported | `shim-ausente:time`×5 |
| 135 | `github.com/cockroachdb/pebble/v2/internal/genericcache` | unsupported | `constraint`×5, `generico-nao-struct`×2, `shim-ausente:`, `tipo:chan` |
| 136 | `github.com/cockroachdb/tokenbucket` | unsupported | `shim-ausente:time` |
| 137 | `github.com/hashicorp/golang-lru/v2/internal` | unsupported | `shim-ausente:time`×2 |
| 138 | `github.com/hashicorp/golang-lru/v2/simplelru` | unsupported | `generico-nao-struct`×2, `expr:IndexListExpr` |
| 139 | `github.com/hashicorp/golang-lru/v2` | unsupported | `shim-ausente:sync`×2, `expr:IndexListExpr` |
| 140 | `github.com/ipfs/boxo/routing/http/internal` | unsupported | `shim-ausente:context` |
| 141 | `github.com/ipfs/go-metrics-interface` | unsupported | `shim-ausente:context`×4, `shim-ausente:time` |
| 142 | `github.com/ipfs/boxo/bitswap/metrics` | unsupported | `shim-ausente:context`×11 |
| 143 | `github.com/ipfs/kubo/internal/fusemount` | unsupported | `shim-ausente:context`×2 |
| 144 | `github.com/jbenet/go-temp-err-catcher` | unsupported | `shim-ausente:time`×3, `shim-simbolo:errors.as` |
| 145 | `github.com/libp2p/go-libp2p-kad-dht/provider/stats` | unsupported | `shim-ausente:time`×4 |
| 146 | `github.com/libp2p/go-libp2p-pubsub/timecache` | unsupported | `shim-ausente:time`×7, `shim-ausente:sync`×3, `shim-ausente:context` |
| 147 | `github.com/pion/dtls/v3/internal/closer` | unsupported | `shim-ausente:context`×3 |
| 148 | `github.com/pion/ice/v4/internal/taskloop` | unsupported | `make:chan`, `shim-ausente:context`, `tipo:chan` |
| 149 | `github.com/pion/interceptor/internal/ntp` | unsupported | `shim-ausente:time`×4 |
| 150 | `github.com/pion/transport/v3/deadline` | unsupported | `shim-ausente:time`×2, `make:chan`, `shim-ausente:sync` |
| 151 | `github.com/pion/transport/v3/packetio` | unsupported | `make:chan`, `shim-ausente:sync` |
| 152 | `github.com/pion/transport/v4/deadline` | unsupported | `shim-ausente:time`×2, `make:chan`, `shim-ausente:sync` |
| 153 | `github.com/quic-go/quic-go/internal/monotime` | unsupported | `shim-ausente:time`×7 |
| 154 | `github.com/slok/go-http-metrics/metrics` | unsupported | `shim-ausente:context`×2 |
| 155 | `go.opentelemetry.io/otel/internal/baggage` | unsupported | `shim-ausente:context`×6 |
| 156 | `go.uber.org/dig/internal/digclock` | unsupported | `shim-ausente:time`×4 |
| 157 | `go.uber.org/fx/internal/fxclock` | unsupported | `shim-ausente:time`×4, `shim-ausente:context`, `shim-ausente:sync` |
| 158 | `go.uber.org/zap/buffer` | unsupported | `append-string` |
| 159 | `go.uber.org/zap/internal/bufferpool` | bloqueado | `dart:uri_does_not_exist` |
| 160 | `go.uber.org/zap/internal/stacktrace` | unsupported | `shim-ausente:runtime`×2, `for-multi-atribuicao` |
| 161 | `golang.org/x/net/internal/httpsfv` | unsupported | `shim-ausente:slices`×5, `shim-ausente:time`, `shim-ausente:unicode/utf8`, `shim-simbolo:strconv.parseFloat`, `shim-simbolo:strings.Builder` |
| 162 | `golang.org/x/sys/unix` | substituicao | assembly: asm_linux_amd64.s |
| 163 | `github.com/hanwen/go-fuse/v2/internal/fallocate` | bloqueado | `dart:uri_does_not_exist` |
| 164 | `github.com/hanwen/go-fuse/v2/internal/openat` | unsupported | `shim-ausente:syscall`×2 |
| 165 | `github.com/hanwen/go-fuse/v2/internal/renameat` | bloqueado | `dart:uri_does_not_exist` |
| 166 | `github.com/hanwen/go-fuse/v2/internal/xattr` | unsupported | `shim-ausente:syscall` |
| 167 | `github.com/ipfs/kubo/core/node/libp2p/fd` | bloqueado | `dart:uri_does_not_exist` |
| 168 | `github.com/mattn/go-isatty` | bloqueado | `dart:uri_does_not_exist` |
| 169 | `google.golang.org/grpc/backoff` | unsupported | `shim-ausente:time`×2 |
| 170 | `google.golang.org/grpc/balancer/pickfirst/internal` | unsupported | `shim-ausente:math/rand/v2`×2, `shim-ausente:time`×2 |
| 171 | `google.golang.org/grpc/internal/backoff` | unsupported | `shim-ausente:time`×2, `shim-ausente:context` |
| 172 | `google.golang.org/grpc/internal/grpcsync` | unsupported | `shim-ausente:context`×2, `make:chan`, `shim-ausente:sync`, `shim-ausente:sync/atomic`, `tipo:chan` |
| 173 | `google.golang.org/grpc/internal/idle` | unsupported | `shim-ausente:time`×4 |
| 174 | `google.golang.org/grpc/keepalive` | unsupported | `shim-ausente:time`×3 |
| 175 | `google.golang.org/protobuf/internal/editiondefaults` | unsupported | `import:_` |
| 176 | `github.com/RaduBerinde/btreemap` | unsupported | `generico-nao-struct`×2, `shim-ausente:io`, `shim-ausente:iter`, `shim-ausente:sync` |
| 177 | `github.com/benbjohnson/clock` | unsupported | `shim-ausente:time`×5, `tipo:chan`×4, `shim-ausente:sync`×2, `shim-ausente:context` |
| 178 | `github.com/blang/semver/v4` | unsupported | `shim-simbolo:strings.replace`×2, `shim-ausente:encoding/json`, `shim-ausente:unicode`, `shim-simbolo:strings.indexFunc`, `shim-simbolo:strings.indexRune` (+1) |
| 179 | `github.com/cenkalti/backoff/v5` | unsupported | `shim-ausente:time`×17, `tipo:chan`×2, `generico-nao-struct`, `make:chan`, `shim-ausente:context` |
| 180 | `github.com/cockroachdb/crlib/crbytes` | substituicao | assembly: common_prefix_amd64.s |
| 181 | `github.com/cockroachdb/crlib/crstrings` | unsupported | `shim-ausente:slices` |
| 182 | `github.com/cockroachdb/crlib/fifo` | unsupported | `shim-ausente:sync` |
| 183 | `github.com/cockroachdb/logtags` | unsupported | `shim-ausente:context`×5, `shim-simbolo:strings.Builder` |
| 184 | `github.com/cockroachdb/pebble/v2/internal/manual` | unsupported | `shim-ausente:sync/atomic` |
| 185 | `github.com/cockroachdb/pebble/v2/internal/treeprinter` | unsupported | `shim-simbolo:bytes.Buffer` |
| 186 | `github.com/cockroachdb/pebble/v2/internal/binfmt` | unsupported | `shim-simbolo:bytes.Buffer`×3, `shim-ausente:io`, `shim-simbolo:math.log10` |
| 187 | `github.com/cockroachdb/redact/interfaces` | unsupported | `shim-simbolo:fmt.State` |
| 188 | `github.com/cockroachdb/redact/internal/fmtforward` | unsupported | `shim-ausente:io`, `shim-simbolo:fmt.State` |
| 189 | `github.com/cockroachdb/redact/internal/markers` | unsupported | `shim-ausente:regexp`×6 |
| 190 | `github.com/cockroachdb/redact/internal/escape` | unsupported | `shim-ausente:unicode/utf8` |
| 191 | `github.com/cockroachdb/redact/internal/buffer` | unsupported | `tipo-basico:Pointer` |
| 192 | `github.com/cockroachdb/redact/internal/redact` | unsupported | `shim-simbolo:fmt.State`×2 |
| 193 | `github.com/cockroachdb/redact/internal/rfmt` | unsupported | `shim-ausente:reflect`×12, `shim-ausente:io`×3, `shim-ausente:os`×3, `shim-ausente:sync`×2, `append-string` (+2) |
| 194 | `github.com/cockroachdb/redact/builder` | bloqueado | `dart:uri_does_not_exist`×4 |
| 195 | `github.com/cockroachdb/redact` | unsupported | `shim-ausente:io`×2, `shim-ausente:reflect`×2, `shim-simbolo:fmt.State` |
| 196 | `github.com/cockroachdb/pebble/v2/internal/humanize` | unsupported | `shim-simbolo:math.log`, `shim-simbolo:math.pow` |
| 197 | `github.com/cockroachdb/swiss` | unsupported | `tipo-basico:Pointer`×10, `builtin:None`×2, `generico-nao-struct`×2, `conversao:nao-basico`, `fmt-verbo:%#v` (+2) |
| 198 | `github.com/crackcomm/go-gitignore` | unsupported | `shim-ausente:os`×2, `shim-ausente:regexp`×2 |
| 199 | `github.com/davidlazar/go-crypto/salsa20` | unsupported | `shim-ausente:crypto/cipher` |
| 200 | `github.com/dunglas/httpsfv` | unsupported | `shim-simbolo:strings.Builder`×15, `shim-ausente:io`×6, `shim-ausente:time`×2, `shim-ausente:unicode`×2, `shim-ausente:encoding/base64` (+1) |
| 201 | `github.com/filecoin-project/go-clock` | unsupported | `shim-ausente:time`×5, `tipo:chan`×4, `shim-ausente:sync`×2, `shim-ausente:context` |
| 202 | `github.com/fsnotify/fsnotify/internal` | unsupported | `shim-ausente:syscall`×4, `shim-ausente:os` |
| 203 | `github.com/gabriel-vasile/mimetype/internal/magic` | unsupported | `shim-simbolo:bytes.contains`×7, `shim-ausente:slices`×5, `shim-ausente:time`, `shim-simbolo:bytes.trim` |
| 204 | `github.com/gammazero/deque` | unsupported | `shim-ausente:iter` |
| 205 | `github.com/gammazero/chanqueue` | unsupported | `tipo:chan`×4, `make:chan`×2, `generico-nao-struct` |
| 206 | `github.com/go-jose/go-jose/v4/json` | unsupported | `shim-ausente:sync` |
| 207 | `github.com/go-logfmt/logfmt` | unsupported | `shim-ausente:io`×12, `shim-simbolo:bytes.Buffer`×4, `shim-ausente:reflect`×3, `shim-ausente:bufio`, `shim-ausente:encoding` (+2) |
| 208 | `github.com/grpc-ecosystem/grpc-gateway/v2/utilities` | unsupported | `shim-ausente:flag`, `shim-ausente:io` |
| 209 | `github.com/grpc-ecosystem/grpc-gateway/v2/internal/httprule` | unsupported | `shim-simbolo:strings.indexAny` |
| 210 | `github.com/hashicorp/go-version` | unsupported | `shim-ausente:regexp`×7, `shim-simbolo:strconv.appendInt` |
| 211 | `github.com/huin/goupnp/scpd` | unsupported | `shim-ausente:encoding/xml`, `shim-simbolo:strings.trimSpace` |
| 212 | `github.com/ipfs/boxo/routing/http/internal/drjson` | unsupported | `shim-simbolo:bytes.Buffer`×2 |
| 213 | `github.com/ipfs/boxo/routing/http/types/iter` | unsupported | `generico-nao-struct`×2, `shim-ausente:encoding/json`, `shim-ausente:io` |
| 214 | `github.com/ipfs/go-bitfield` | verde |  |
| 215 | `github.com/ipfs/go-datastore/query` | unsupported | `shim-simbolo:strings.compare`×3, `tipo:chan`×3, `range:chan`, `shim-ausente:context`, `shim-ausente:path` (+3) |
| 216 | `github.com/ipfs/go-libdht/kad/key/bit256` | unsupported | `shim-simbolo:math.log2` |
| 217 | `github.com/ipfs/kubo/repo/common` | unsupported | `shim-ausente:maps` |
| 218 | `github.com/ipld/go-ipld-prime/datamodel` | unsupported | `shim-ausente:io`, `shim-simbolo:strings.Builder`, `shim-simbolo:strings.fieldsFunc` |
| 219 | `github.com/ipld/go-ipld-prime/adl` | bloqueado | `dart:uri_does_not_exist` |
| 220 | `github.com/ipld/go-ipld-prime/codec` | unsupported | `shim-ausente:io` |
| 221 | `github.com/ipld/go-ipld-prime/fluent` | unsupported | `shim-ausente:reflect`×2 |
| 222 | `github.com/ipld/go-ipld-prime/fluent/qp` | unsupported | `conversao:bool-bool`, `tipo-nomeado:bool` |
| 223 | `github.com/ipld/go-ipld-prime/linking/preload` | unsupported | `shim-ausente:context` |
| 224 | `github.com/ipld/go-ipld-prime/multicodec` | bloqueado | `dart:uri_does_not_exist` |
| 225 | `github.com/ipld/go-ipld-prime/codec/raw` | unsupported | `shim-ausente:io`×2 |
| 226 | `github.com/ipld/go-ipld-prime/node/mixins` | bloqueado | `dart:uri_does_not_exist` |
| 227 | `github.com/ipld/go-ipld-prime/schema` | unsupported | `tipo-nomeado:bool` |
| 228 | `github.com/ipld/go-ipld-prime/storage` | unsupported | `shim-ausente:context`×14, `shim-ausente:io` |
| 229 | `github.com/ipld/go-ipld-prime/linking` | unsupported | `shim-ausente:context`, `shim-ausente:hash`, `shim-ausente:io` |
| 230 | `github.com/ipld/go-ipld-prime/node/basicnode` | unsupported | `conversao:bool-bool`×4, `shim-ausente:io`×3, `conversao:nao-basico`, `tipo-nomeado:bool` |
| 231 | `github.com/ipld/go-ipld-prime/node/basic` | bloqueado | `dart:uri_does_not_exist`×3 |
| 232 | `github.com/klauspost/compress/fse` | unsupported | `shim-ausente:io` |
| 233 | `github.com/klauspost/compress/huff0` | unsupported | `shim-ausente:io`×2, `shim-ausente:sync`×2, `shim-ausente:runtime` |
| 234 | `github.com/klauspost/cpuid/v2` | unsupported | `shim-ausente:flag`, `shim-ausente:os`, `shim-ausente:slices`, `shim-simbolo:strings.toLower`, `shim-simbolo:strings.toUpper` (+3) |
| 235 | `github.com/libp2p/go-flow-metrics` | unsupported | `shim-ausente:time`×3, `shim-ausente:sync`×2, `shim-ausente:sync/atomic`, `shim-simbolo:math.exp` |
| 236 | `github.com/libp2p/go-libp2p-kad-dht/provider/internal/connectivity` | unsupported | `shim-ausente:time`×5, `make:chan`, `tipo:chan` |
| 237 | `github.com/libp2p/go-libp2p/core/pnet` | unsupported | `shim-ausente:bufio`×2, `shim-ausente:io`, `shim-ausente:os` |
| 238 | `github.com/mattn/go-colorable` | unsupported | `import:_` |
| 239 | `github.com/fatih/color` | unsupported | `shim-ausente:os`×2, `shim-ausente:io`, `shim-simbolo:fmt.fprint`, `shim-simbolo:fmt.fprintf`, `shim-simbolo:fmt.sprintln` |
| 240 | `github.com/mattn/go-runewidth` | unsupported | `shim-ausente:os`×2, `shim-ausente:regexp`×2, `shim-simbolo:strings.repeat`, `shim-simbolo:strings.toLower` |
| 241 | `github.com/mgutz/ansi` | unsupported | `shim-simbolo:bytes.Buffer`×3, `shim-ausente:io`, `shim-simbolo:bytes.newBufferString` |
| 242 | `github.com/elgris/jsondiff` | unsupported | `shim-ausente:io`×2, `shim-ausente:encoding/json`, `shim-ausente:reflect`, `shim-simbolo:bytes.Buffer` |
| 243 | `github.com/mikioh/tcpopt` | unsupported | `tipo-basico:Pointer`×7, `shim-ausente:time`×6, `conversao:bool-bool`×4, `tipo-nomeado:bool`×4, `shim-ausente:sync` |
| 244 | `github.com/mikioh/tcpinfo` | unsupported | `shim-ausente:time`×4, `tipo-basico:Pointer`×4, `tipo-nomeado:bool`×2, `tipo-nomeado:array` |
| 245 | `github.com/multiformats/go-base36` | verde |  |
| 246 | `github.com/multiformats/go-multiaddr/x/meg` | verde |  |
| 247 | `github.com/multiformats/go-multicodec` | verde |  |
| 248 | `github.com/multiformats/go-multihash/core` | unsupported | `shim-ausente:hash`×7, `shim-ausente:crypto/md5`, `shim-simbolo:bytes.Buffer` |
| 249 | `github.com/multiformats/go-multihash/register/blake2` | bloqueado | `dart:uri_does_not_exist`×3 |
| 250 | `github.com/multiformats/go-multihash/register/murmur3` | unsupported | `shim-ausente:hash` |
| 251 | `github.com/multiformats/go-multihash/register/sha256` | unsupported | `shim-ausente:crypto/sha256` |
| 252 | `github.com/multiformats/go-multihash/register/miniosha256` | unsupported | `import:_` |
| 253 | `github.com/opentracing/opentracing-go/log` | unsupported | `shim-ausente:reflect` |
| 254 | `github.com/pion/dtls/v3/pkg/crypto/ccm` | unsupported | `shim-ausente:crypto/cipher`×3 |
| 255 | `github.com/pion/dtls/v3/pkg/crypto/hash` | unsupported | `shim-ausente:crypto/md5` |
| 256 | `github.com/pion/dtls/v3/pkg/crypto/signature` | bloqueado | `dart:uri_does_not_exist` |
| 257 | `github.com/pion/rtcp` | unsupported | `shim-ausente:reflect`×4, `copy-string`, `shim-simbolo:strings.replaceAll` |
| 258 | `github.com/pion/rtp/codecs/av1/obu` | verde |  |
| 259 | `github.com/pion/stun/v3/internal/hmac` | unsupported | `shim-ausente:hash`×6, `shim-ausente:sync`×2, `shim-ausente:crypto/sha1`, `shim-ausente:crypto/sha256` |
| 260 | `github.com/pion/transport/v3/replaydetector` | verde |  |
| 261 | `github.com/pion/transport/v4/replaydetector` | unsupported | `shim-simbolo:strings.Builder` |
| 262 | `github.com/pion/webrtc/v4/internal/fmtp` | unsupported | `shim-simbolo:strings.equalFold`×3, `shim-simbolo:strings.toLower`×2, `shim-ausente:encoding/hex`, `shim-simbolo:strings.trimSpace` |
| 263 | `github.com/pion/webrtc/v4/pkg/rtcerr` | verde |  |
| 264 | `github.com/pkg/errors` | unsupported | `shim-simbolo:fmt.State`×5, `shim-ausente:runtime`×2, `shim-simbolo:errors.as`, `shim-simbolo:errors.is$`, `shim-simbolo:errors.unwrap` |
| 265 | `github.com/polydawn/refmt/obj/atlas` | unsupported | `shim-ausente:reflect`×18, `shim-ausente:unicode`×2 |
| 266 | `github.com/polydawn/refmt/tok` | verde |  |
| 267 | `github.com/polydawn/refmt/obj` | unsupported | `shim-ausente:reflect`×54 |
| 268 | `github.com/polydawn/refmt/pretty` | unsupported | `shim-ausente:io`×2 |
| 269 | `github.com/polydawn/refmt/shared` | unsupported | `shim-ausente:io`×5, `shim-simbolo:bytes.Buffer` |
| 270 | `github.com/polydawn/refmt/cbor` | unsupported | `shim-ausente:io`×8, `shim-simbolo:bytes.Buffer`×4, `branch:goto` |
| 271 | `github.com/polydawn/refmt/json` | unsupported | `shim-ausente:io`×8, `shim-simbolo:bytes.Buffer`×4, `shim-ausente:unicode/utf8` |
| 272 | `github.com/polydawn/refmt` | unsupported | `shim-ausente:io`×4 |
| 273 | `github.com/ipfs/go-ipld-cbor/encoding` | unsupported | `shim-ausente:io`×6, `shim-ausente:sync`×6 |
| 274 | `github.com/prometheus/otlptranslator` | unsupported | `shim-simbolo:strings.Builder`×2, `shim-simbolo:strings.fieldsFunc`×2, `shim-ausente:slices`, `shim-ausente:unicode`, `shim-simbolo:strings.map` (+1) |
| 275 | `github.com/prometheus/procfs/internal/util` | unsupported | `shim-ausente:os`×5, `shim-simbolo:strings.trimSpace`×2 |
| 276 | `github.com/quic-go/quic-go/qlogwriter/jsontext` | unsupported | `shim-ausente:io`×2, `builtin:None` |
| 277 | `github.com/quic-go/quic-go/quicvarint` | unsupported | `shim-ausente:io`×8, `shim-simbolo:bytes.Buffer`, `shim-simbolo:bytes.Reader` |
| 278 | `github.com/slok/go-http-metrics/middleware` | unsupported | `shim-ausente:context`×2 |
| 279 | `github.com/syndtr/goleveldb/leveldb/util` | unsupported | `shim-ausente:hash/crc32`×3, `shim-ausente:sync`×2, `shim-simbolo:bytes.errTooLarge`×2 |
| 280 | `github.com/syndtr/goleveldb/leveldb/cache` | unsupported | `shim-ausente:sync`×4, `tipo-basico:Pointer`×3 |
| 281 | `github.com/syndtr/goleveldb/leveldb/filter` | bloqueado | `dart:uri_does_not_exist` |
| 282 | `github.com/syndtr/goleveldb/leveldb/opt` | unsupported | `shim-simbolo:math.pow` |
| 283 | `github.com/texttheater/golang-levenshtein/levenshtein` | unsupported | `shim-ausente:io`, `shim-ausente:os` |
| 284 | `github.com/zeebo/blake3` | unsupported | `tipo-basico:Pointer`×6 |
| 285 | `go.opencensus.io/internal` | unsupported | `shim-ausente:time`×2, `shim-ausente:unicode`, `shim-simbolo:strings.map` |
| 286 | `go.opencensus.io/resource` | unsupported | `shim-ausente:context`×4, `shim-ausente:regexp`×2, `shim-simbolo:strconv.quote`, `shim-simbolo:strings.trimSpace` |
| 287 | `go.opencensus.io/metric/metricdata` | unsupported | `shim-ausente:time`×7 |
| 288 | `go.opencensus.io/metric/metricproducer` | unsupported | `shim-ausente:sync`×2 |
| 289 | `go.opencensus.io/trace/tracestate` | unsupported | `shim-ausente:regexp`×5 |
| 290 | `go.opentelemetry.io/auto/sdk/internal/telemetry` | unsupported | `shim-simbolo:bytes.Reader`×6, `conversao:nao-basico`×4, `shim-ausente:time`×4, `shim-ausente:encoding/hex`×2, `shim-ausente:encoding/json`×2 (+4) |
| 291 | `go.opentelemetry.io/otel/attribute` | unsupported | `shim-simbolo:strings.Builder`×34, `shim-ausente:reflect`×9, `shim-ausente:cmp`×2, `shim-simbolo:bytes.Buffer`×2, `conversao:nao-basico` (+4) |
| 292 | `go.opentelemetry.io/otel/codes` | unsupported | `shim-ausente:encoding/json` |
| 293 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc/internal` | verde |  |
| 294 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc/internal/retry` | unsupported | `shim-ausente:context`×3, `shim-ausente:time`×3 |
| 295 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc/internal/x` | unsupported | `shim-ausente:os`, `shim-simbolo:strings.equalFold` |
| 296 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp/internal` | verde |  |
| 297 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp/internal/retry` | unsupported | `shim-ausente:context`×3, `shim-ausente:time`×3 |
| 298 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp/internal/x` | unsupported | `shim-ausente:os`, `shim-simbolo:strings.equalFold` |
| 299 | `go.opentelemetry.io/otel/exporters/prometheus/internal/x` | unsupported | `shim-ausente:os`, `shim-simbolo:strings.equalFold` |
| 300 | `go.opentelemetry.io/otel/exporters/stdout/stdouttrace/internal/x` | unsupported | `shim-ausente:os`, `shim-simbolo:strings.equalFold` |
| 301 | `go.opentelemetry.io/otel/metric` | unsupported | `shim-ausente:context`×11, `shim-ausente:slices` |
| 302 | `go.opentelemetry.io/otel/metric/noop` | unsupported | `shim-ausente:context`×8 |
| 303 | `go.opentelemetry.io/otel/sdk/instrumentation` | bloqueado | `dart:uri_does_not_exist` |
| 304 | `go.opentelemetry.io/otel/sdk/internal/attrnorm` | unsupported | `shim-ausente:reflect`×5, `shim-ausente:slices`×3, `shim-ausente:unicode/utf8`, `shim-simbolo:strings.Builder`, `tipo-basico:Pointer` |
| 305 | `go.opentelemetry.io/otel/sdk/internal/x` | unsupported | `shim-simbolo:strings.equalFold`×3, `shim-ausente:os` |
| 306 | `go.opentelemetry.io/otel/sdk/metric/internal/attrnorm` | unsupported | `shim-ausente:reflect`×5, `tipo-basico:Pointer` |
| 307 | `go.opentelemetry.io/otel/sdk/metric/internal/x` | unsupported | `shim-ausente:os` |
| 308 | `go.opentelemetry.io/otel/semconv/internal/metricpool` | unsupported | `shim-ausente:sync`×3 |
| 309 | `go.opentelemetry.io/otel/semconv/v1.37.0` | unsupported | `shim-ausente:reflect` |
| 310 | `go.opentelemetry.io/otel/semconv/v1.41.0` | unsupported | `shim-ausente:reflect`×3, `shim-simbolo:errors.as` |
| 311 | `go.opentelemetry.io/otel/semconv/v1.41.0/otelconv` | unsupported | `shim-ausente:context`×13 |
| 312 | `go.opentelemetry.io/otel/semconv/v1.43.0` | unsupported | `shim-ausente:reflect`×3, `shim-simbolo:errors.as` |
| 313 | `go.opentelemetry.io/otel/semconv/v1.43.0/httpconv` | unsupported | `shim-ausente:context`×10 |
| 314 | `go.opentelemetry.io/otel/semconv/v1.43.0/otelconv` | unsupported | `shim-ausente:context`×13 |
| 315 | `go.opentelemetry.io/otel/trace/internal/telemetry` | unsupported | `shim-simbolo:bytes.Reader`×6, `conversao:nao-basico`×4, `shim-ausente:time`×4, `shim-ausente:encoding/hex`×2, `shim-ausente:encoding/json`×2 (+4) |
| 316 | `go.opentelemetry.io/otel/trace` | unsupported | `shim-ausente:context`×11, `shim-ausente:time`×5, `shim-simbolo:strings.cut`×3, `shim-ausente:encoding/json`×2, `tipo-nomeado:array`×2 (+8) |
| 317 | `go.opentelemetry.io/otel/sdk/metric/exemplar` | unsupported | `shim-ausente:context`×6, `shim-ausente:sync`×2, `shim-ausente:time`×2, `conversao:nao-basico`, `shim-ausente:math/rand/v2` (+2) |
| 318 | `go.opentelemetry.io/otel/trace/noop` | unsupported | `shim-ausente:context` |
| 319 | `go.uber.org/dig/internal/digerror` | verde |  |
| 320 | `go.uber.org/dig/internal/dot` | unsupported | `shim-ausente:reflect`×4 |
| 321 | `go.uber.org/multierr` | unsupported | `shim-ausente:io`×2, `shim-ausente:sync`, `shim-ausente:sync/atomic`, `shim-simbolo:bytes.Buffer`, `shim-simbolo:errors.is$` |
| 322 | `go.uber.org/zap/internal/color` | verde |  |
| 323 | `go.uber.org/zap/internal/exit` | unsupported | `shim-ausente:os` |
| 324 | `go.uber.org/zap/zapcore` | unsupported | `shim-ausente:time`×30, `shim-ausente:io`×5, `shim-ausente:reflect`×2, `shim-ausente:sync`×2, `constraint` (+7) |
| 325 | `go.uber.org/zap/internal` | bloqueado | `dart:uri_does_not_exist` |
| 326 | `golang.org/x/crypto/chacha20` | bloqueado | `dart:uri_does_not_exist` |
| 327 | `golang.org/x/crypto/chacha20poly1305` | unsupported | `shim-ausente:crypto/cipher`×2, `shim-ausente:crypto/fips140` |
| 328 | `golang.org/x/crypto/curve25519` | unsupported | `shim-ausente:crypto/ecdh`×2, `range:pointer` |
| 329 | `golang.org/x/crypto/hkdf` | unsupported | `shim-ausente:hash`×4 |
| 330 | `golang.org/x/exp/mmap` | unsupported | `builtin:println`, `shim-ausente:os` |
| 331 | `golang.org/x/net/bpf` | unsupported | `fmt-verbo:%#v`×9 |
| 332 | `golang.org/x/net/http2/hpack` | unsupported | `shim-simbolo:bytes.Buffer`×4, `shim-ausente:io`×3, `shim-ausente:sync`×2, `append-string`, `tipo-nomeado:array` |
| 333 | `github.com/quic-go/qpack` | unsupported | `shim-ausente:io`×4 |
| 334 | `golang.org/x/sync/errgroup` | unsupported | `shim-ausente:context`, `shim-ausente:sync` |
| 335 | `golang.org/x/sys/cpu` | substituicao | assembly: cpu_gc_x86.s |
| 336 | `golang.org/x/crypto/sha3` | unsupported | `shim-ausente:crypto/sha3`×9, `shim-ausente:hash`×7, `range:pointer` |
| 337 | `github.com/multiformats/go-multihash/register/sha3` | bloqueado | `dart:uri_does_not_exist`×2 |
| 338 | `golang.org/x/term` | unsupported | `shim-ausente:io`×3, `andnot-nao-ident`×2, `shim-ausente:sync`, `shim-ausente:unicode/utf8` |
| 339 | `golang.org/x/text/internal/language` | unsupported | `copy-string`×8, `shim-simbolo:bytes.join`×3, `append-string`, `shim-simbolo:bytes.Buffer`, `shim-simbolo:strings.toLower` |
| 340 | `golang.org/x/text/internal/language/compact` | unsupported | `shim-simbolo:strings.toLower` |
| 341 | `golang.org/x/text/language` | unsupported | `conversao:nao-basico`×83, `shim-simbolo:strings.trimSpace`×2, `shim-simbolo:strconv.parseFloat`, `shim-simbolo:strings.toLower` |
| 342 | `golang.org/x/text/internal` | bloqueado | `dart:uri_does_not_exist` |
| 343 | `golang.org/x/text/unicode/bidi` | unsupported | `shim-ausente:container/list`×2, `shim-simbolo:bytes.runes`×2, `shim-ausente:unicode/utf8` |
| 344 | `golang.org/x/text/secure/bidirule` | bloqueado | `dart:undefined_getter`×4, `dart:uri_does_not_exist`×2, `dart:invalid_constant` |
| 345 | `golang.org/x/text/unicode/norm` | unsupported | `shim-ausente:unicode/utf8`×6, `branch:goto`×3, `copy-string`×3, `shim-ausente:io`×2, `literal-composto:pointer` (+1) |
| 346 | `golang.org/x/net/idna` | unsupported | `append-string`×2, `copy-string`, `shim-ausente:unicode/utf8` |
| 347 | `golang.org/x/text/cases` | unsupported | `shim-ausente:unicode/utf8`×2 |
| 348 | `golang.org/x/time/rate` | unsupported | `shim-ausente:time`×5, `shim-ausente:sync` |
| 349 | `golang.org/x/xerrors` | unsupported | `shim-simbolo:fmt.State`×6, `shim-ausente:runtime`×2, `shim-ausente:unicode/utf8`, `shim-simbolo:errors.as`, `shim-simbolo:errors.is$` (+1) |
| 350 | `google.golang.org/grpc/attributes` | unsupported | `fmt-verbo:%p`, `shim-ausente:maps` |
| 351 | `google.golang.org/grpc/internal/envconfig` | unsupported | `shim-ausente:os`×8 |
| 352 | `google.golang.org/protobuf/internal/detrand` | unsupported | `shim-ausente:os` |
| 353 | `google.golang.org/protobuf/internal/errors` | bloqueado | `dart:undefined_getter`×2, `dart:uri_does_not_exist` |
| 354 | `google.golang.org/protobuf/encoding/protowire` | unsupported | `append-string`, `shim-ausente:io` |
| 355 | `google.golang.org/protobuf/internal/version` | verde |  |
| 356 | `google.golang.org/protobuf/reflect/protoreflect` | unsupported | `tipo-basico:Pointer`×10, `shim-ausente:reflect`, `shim-simbolo:strconv.appendInt`, `shim-simbolo:strings.lastIndexByte` |
| 357 | `google.golang.org/protobuf/internal/descfmt` | unsupported | `shim-ausente:reflect`×3, `shim-simbolo:fmt.State`×2, `shim-simbolo:strings.repeat` |
| 358 | `google.golang.org/protobuf/internal/descopts` | bloqueado | `dart:uri_does_not_exist` |
| 359 | `google.golang.org/protobuf/internal/encoding/messageset` | bloqueado | `dart:uri_does_not_exist`×2 |
| 360 | `google.golang.org/protobuf/internal/genid` | bloqueado | `dart:uri_does_not_exist`×2 |
| 361 | `google.golang.org/protobuf/internal/order` | unsupported | `shim-ausente:sync`×4 |
| 362 | `google.golang.org/protobuf/internal/strs` | unsupported | `shim-ausente:unicode`×4, `builtin:None`×2, `append-string` |
| 363 | `google.golang.org/protobuf/internal/encoding/json` | unsupported | `append-string`×3, `shim-ausente:regexp`×3, `shim-ausente:io`, `shim-simbolo:strconv.parseFloat`, `shim-simbolo:strings.trim` |
| 364 | `google.golang.org/protobuf/internal/encoding/text` | unsupported | `append-string`×4, `shim-ausente:io`, `shim-ausente:unicode/utf8`, `shim-simbolo:strings.toLower`, `shim-simbolo:strings.trim` |
| 365 | `google.golang.org/protobuf/internal/encoding/defval` | unsupported | `append-string`, `shim-simbolo:strconv.formatFloat`, `shim-simbolo:strconv.parseFloat` |
| 366 | `google.golang.org/protobuf/reflect/protoregistry` | unsupported | `shim-ausente:os`, `shim-ausente:sync`, `shim-simbolo:strings.lastIndexByte`, `shim-simbolo:strings.replace` |
| 367 | `google.golang.org/protobuf/runtime/protoiface` | bloqueado |  |
| 368 | `google.golang.org/protobuf/internal/protolazy` | unsupported | `tipo-basico:Pointer`×2, `branch:goto`, `shim-ausente:io` |
| 369 | `google.golang.org/protobuf/proto` | unsupported | `append-string`, `constraint`, `shim-ausente:reflect`, `shim-ausente:unicode/utf8`, `shim-simbolo:errors.as` |
| 370 | `google.golang.org/protobuf/encoding/protodelim` | unsupported | `shim-ausente:io`×4 |
| 371 | `google.golang.org/protobuf/encoding/prototext` | unsupported | `shim-ausente:unicode/utf8`×2 |
| 372 | `google.golang.org/protobuf/internal/filedesc` | unsupported | `shim-ausente:sync`×19, `shim-simbolo:fmt.State`×5, `tipo-nomeado:array`×2, `shim-simbolo:strings.toLower` |
| 373 | `google.golang.org/protobuf/encoding/protojson` | unsupported | `shim-simbolo:strings.trimSpace`×3, `shim-ausente:encoding/base64`×2, `shim-ausente:time` |
| 374 | `google.golang.org/protobuf/internal/encoding/tag` | unsupported | `shim-ausente:reflect`×3 |
| 375 | `google.golang.org/protobuf/internal/impl` | unsupported | `shim-ausente:reflect`×121, `shim-ausente:unicode/utf8`×15, `shim-ausente:sync`×12, `tipo-basico:Pointer`×12, `shim-ausente:sync/atomic`×4 (+3) |
| 376 | `google.golang.org/protobuf/internal/filetype` | unsupported | `shim-ausente:reflect`×3 |
| 377 | `google.golang.org/protobuf/runtime/protoimpl` | bloqueado | `dart:uri_does_not_exist` |
| 378 | `github.com/ipfs/boxo/bitswap/message/pb` | unsupported | `tipo-basico:Pointer`×5, `shim-ausente:reflect`, `shim-ausente:sync` |
| 379 | `github.com/ipfs/boxo/filestore/pb` | unsupported | `shim-ausente:reflect`, `shim-ausente:sync`, `tipo-basico:Pointer` |
| 380 | `github.com/ipfs/boxo/ipld/merkledag/pb` | unsupported | `tipo-basico:Pointer`×2, `shim-ausente:reflect`, `shim-ausente:sync` |
| 381 | `github.com/ipfs/boxo/ipld/unixfs/pb` | unsupported | `tipo-basico:Pointer`×3, `shim-ausente:reflect`, `shim-ausente:sync` |
| 382 | `github.com/ipfs/boxo/ipns/pb` | unsupported | `shim-ausente:reflect`, `shim-ausente:sync`, `tipo-basico:Pointer` |
| 383 | `github.com/libp2p/go-libp2p-record/pb` | unsupported | `shim-ausente:reflect`, `shim-ausente:sync`, `tipo-basico:Pointer` |
| 384 | `github.com/libp2p/go-libp2p/core/crypto/pb` | unsupported | `tipo-basico:Pointer`×2, `builtin:None`, `shim-ausente:reflect`, `shim-ausente:sync` |
| 385 | `github.com/libp2p/go-libp2p/core/peer/pb` | unsupported | `tipo-basico:Pointer`×2, `builtin:None`, `shim-ausente:reflect`, `shim-ausente:sync` |
| 386 | `github.com/libp2p/go-libp2p/core/record/pb` | unsupported | `builtin:None`, `shim-ausente:reflect`, `shim-ausente:sync`, `tipo-basico:Pointer` |
| 387 | `github.com/libp2p/go-libp2p/p2p/host/autonat/pb` | unsupported | `tipo-basico:Pointer`×4, `builtin:None`, `shim-ausente:reflect`, `shim-ausente:sync` |
| 388 | `github.com/libp2p/go-libp2p/p2p/protocol/autonatv2/pb` | unsupported | `tipo-basico:Pointer`×7, `builtin:None`, `shim-ausente:reflect`, `shim-ausente:sync` |
| 389 | `github.com/libp2p/go-libp2p/p2p/protocol/circuitv2/pb` | unsupported | `tipo-basico:Pointer`×6, `builtin:None`×2, `shim-ausente:reflect`×2, `shim-ausente:sync`×2 |
| 390 | `github.com/libp2p/go-libp2p/p2p/protocol/holepunch/pb` | unsupported | `builtin:None`, `shim-ausente:reflect`, `shim-ausente:sync`, `tipo-basico:Pointer` |
| 391 | `github.com/libp2p/go-libp2p/p2p/protocol/identify/pb` | unsupported | `builtin:None`, `shim-ausente:reflect`, `shim-ausente:sync`, `tipo-basico:Pointer` |
| 392 | `github.com/libp2p/go-libp2p/p2p/security/insecure/pb` | unsupported | `builtin:None`, `shim-ausente:reflect`, `shim-ausente:sync`, `tipo-basico:Pointer` |
| 393 | `github.com/libp2p/go-libp2p/p2p/security/noise/pb` | unsupported | `tipo-basico:Pointer`×2, `builtin:None`, `shim-ausente:reflect`, `shim-ausente:sync` |
| 394 | `github.com/libp2p/go-libp2p/p2p/transport/webrtc/pb` | unsupported | `builtin:None`, `shim-ausente:reflect`, `shim-ausente:sync`, `tipo-basico:Pointer` |
| 395 | `go.opentelemetry.io/proto/otlp/common/v1` | unsupported | `tipo-basico:Pointer`×6, `shim-ausente:reflect`, `shim-ausente:sync` |
| 396 | `go.opentelemetry.io/proto/otlp/resource/v1` | unsupported | `shim-ausente:reflect`, `shim-ausente:sync`, `tipo-basico:Pointer` |
| 397 | `go.opentelemetry.io/proto/otlp/trace/v1` | unsupported | `tipo-basico:Pointer`×7, `shim-ausente:reflect`, `shim-ausente:sync` |
| 398 | `google.golang.org/protobuf/protoadapt` | bloqueado | `dart:uri_does_not_exist` |
| 399 | `google.golang.org/grpc/internal/pretty` | unsupported | `shim-ausente:encoding/json`, `shim-simbolo:bytes.Buffer` |
| 400 | `google.golang.org/protobuf/types/descriptorpb` | unsupported | `tipo-basico:Pointer`×34, `builtin:None`, `shim-ausente:reflect`, `shim-ausente:sync` |
| 401 | `google.golang.org/protobuf/internal/editionssupport` | bloqueado | `dart:uri_does_not_exist` |
| 402 | `google.golang.org/protobuf/types/gofeaturespb` | unsupported | `builtin:None`, `shim-ausente:reflect`, `shim-ausente:sync`, `tipo-basico:Pointer` |
| 403 | `google.golang.org/protobuf/reflect/protodesc` | unsupported | `shim-ausente:os`×2, `shim-ausente:sync`, `shim-ausente:unicode`, `shim-simbolo:strings.toLower` |
| 404 | `google.golang.org/protobuf/types/known/anypb` | unsupported | `builtin:None`, `shim-ausente:reflect`, `shim-ausente:sync`, `shim-simbolo:strings.lastIndexByte` |
| 405 | `google.golang.org/genproto/googleapis/api/httpbody` | unsupported | `shim-ausente:reflect`, `shim-ausente:sync`, `tipo-basico:Pointer` |
| 406 | `google.golang.org/genproto/googleapis/rpc/status` | unsupported | `shim-ausente:reflect`, `shim-ausente:sync`, `tipo-basico:Pointer` |
| 407 | `google.golang.org/protobuf/types/known/durationpb` | unsupported | `shim-ausente:time`×2, `builtin:None`, `shim-ausente:reflect`, `shim-ausente:sync` |
| 408 | `google.golang.org/genproto/googleapis/rpc/errdetails` | unsupported | `tipo-basico:Pointer`×14, `shim-ausente:reflect`, `shim-ausente:sync` |
| 409 | `google.golang.org/protobuf/types/known/fieldmaskpb` | unsupported | `builtin:None`, `shim-ausente:reflect`, `shim-ausente:sync`, `shim-simbolo:strings.toLower`, `tipo-basico:Pointer` |
| 410 | `google.golang.org/protobuf/types/known/structpb` | unsupported | `tipo-basico:Pointer`×3, `builtin:None`, `shim-ausente:encoding/json`, `shim-ausente:reflect`, `shim-ausente:sync` (+1) |
| 411 | `google.golang.org/protobuf/types/known/timestamppb` | unsupported | `shim-ausente:time`×3, `builtin:None`, `shim-ausente:reflect`, `shim-ausente:sync` |
| 412 | `github.com/prometheus/client_model/go` | unsupported | `tipo-basico:Pointer`×12, `shim-ausente:reflect`, `shim-ausente:sync` |
| 413 | `github.com/prometheus/common/model` | unsupported | `shim-ausente:encoding/json`×10, `shim-ausente:time`×7, `shim-ausente:regexp`×4, `shim-ausente:maps`×2, `shim-simbolo:strconv.formatFloat`×2 (+5) |
| 414 | `github.com/prometheus/client_golang/prometheus/internal` | unsupported | `shim-ausente:regexp`×3, `shim-ausente:io`, `shim-ausente:runtime/metrics`, `shim-simbolo:bytes.Buffer`, `shim-simbolo:strings.splitAfter` |
| 415 | `google.golang.org/grpc/binarylog/grpc_binarylog_v1` | unsupported | `tipo-basico:Pointer`×8, `builtin:None`, `shim-ausente:reflect`, `shim-ausente:sync` |
| 416 | `google.golang.org/protobuf/types/known/wrapperspb` | unsupported | `tipo-basico:Pointer`×9, `builtin:None`, `shim-ausente:reflect`, `shim-ausente:sync` |
| 417 | `gopkg.in/yaml.v2` | unsupported | `shim-ausente:reflect`×18, `shim-ausente:io`×11, `shim-ausente:regexp`×5, `shim-ausente:time`×4, `shim-ausente:encoding/base64` (+2) |
| 418 | `gopkg.in/yaml.v3` | unsupported | `shim-ausente:reflect`×22, `shim-ausente:io`×11, `shim-ausente:regexp`×5, `shim-ausente:time`×4, `shim-ausente:encoding/base64` (+2) |
| 419 | `github.com/golang/protobuf/proto` | unsupported | `shim-ausente:reflect`×12, `shim-ausente:sync`×6, `shim-ausente:io`×3, `shim-ausente:unicode/utf8`×2, `shim-ausente:encoding` (+6) |
| 420 | `github.com/dgraph-io/badger/pb` | unsupported | `shim-ausente:io`×5 |
| 421 | `github.com/minio/sha256-simd` | unsupported | `append-string`, `shim-ausente:hash`, `shim-ausente:io/ioutil` |
| 422 | `github.com/AndreasBriese/bbloom` | unsupported | `shim-ausente:encoding/json`, `shim-ausente:log`, `shim-ausente:sync`, `shim-simbolo:math.log`, `tipo-basico:Pointer` |
| 423 | `github.com/dgraph-io/ristretto/z` | substituicao | assembly: rtutil.s |
| 424 | `github.com/go-kit/log` | unsupported | `shim-ausente:io`×7, `shim-ausente:time`×5, `shim-ausente:sync`×4, `shim-ausente:regexp`×3, `shim-ausente:reflect`×2 (+6) |
| 425 | `github.com/go-kit/log/level` | unsupported | `shim-simbolo:strings.toLower` |
| 426 | `github.com/gogo/protobuf/proto` | unsupported | `shim-ausente:sync` |
| 427 | `github.com/gogo/protobuf/protoc-gen-gogo/descriptor` | unsupported | `fmt-verbo:%#v`×18, `shim-ausente:sync`×9, `shim-ausente:reflect`, `shim-simbolo:bytes.Reader` |
| 428 | `github.com/gogo/protobuf/gogoproto` | bloqueado | `dart:uri_does_not_exist`×2 |
| 429 | `github.com/gogo/protobuf/types` | unsupported | `fmt-verbo:%#v`×34, `shim-ausente:reflect`×19, `shim-ausente:time`×16, `shim-ausente:io`×10 |
| 430 | `github.com/cockroachdb/errors/errorspb` | unsupported | `import:_` |
| 431 | `github.com/hanwen/go-fuse/v2/splice` | unsupported | `shim-ausente:syscall`×5, `shim-ausente:os`×4, `shim-ausente:sync`×2 |
| 432 | `github.com/ipfs/bbloom` | unsupported | `shim-ausente:encoding/json`, `shim-ausente:sync`, `shim-simbolo:math.log` |
| 433 | `github.com/koron/go-ssdp/internal/ssdplog` | unsupported | `shim-ausente:log`×2 |
| 434 | `github.com/libp2p/go-libp2p-pubsub-router/pb` | unsupported | `shim-ausente:io`×2, `copy-string` |
| 435 | `github.com/pion/logging` | unsupported | `shim-ausente:io`×2, `conversao:nao-basico`, `shim-ausente:log`, `shim-ausente:os`, `shim-ausente:sync` |
| 436 | `github.com/prometheus/statsd_exporter/pkg/level` | bloqueado | `dart:uri_does_not_exist`×2 |
| 437 | `github.com/prometheus/statsd_exporter/pkg/mapper/fsm` | unsupported | `shim-ausente:regexp`×4, `shim-ausente:io` |
| 438 | `go.opentelemetry.io/otel/internal/errorhandler` | unsupported | `shim-ausente:sync/atomic`×4, `shim-ausente:log` |
| 439 | `golang.org/x/net/internal/timeseries` | unsupported | `shim-ausente:time`×11 |
| 440 | `google.golang.org/grpc/grpclog/internal` | unsupported | `shim-ausente:io`×2, `shim-ausente:log`, `shim-ausente:os`, `shim-simbolo:fmt.sprintln` |
| 441 | `google.golang.org/grpc/grpclog` | unsupported | `shim-ausente:os`×4, `shim-ausente:io`×3 |
| 442 | `google.golang.org/grpc/connectivity` | bloqueado | `dart:uri_does_not_exist` |
| 443 | `google.golang.org/grpc/internal/grpclog` | bloqueado | `dart:uri_does_not_exist` |
| 444 | `github.com/go-logr/logr` | unsupported | `shim-ausente:log/slog`×7, `shim-ausente:context`×6 |
| 445 | `github.com/libp2p/go-libp2p-pubsub/internal/gologshim` | unsupported | `shim-ausente:log/slog`×5, `shim-ausente:os` |
| 446 | `github.com/libp2p/go-libp2p-pubsub/pb` | unsupported | `tipo-basico:Pointer`×37, `builtin:None`×2, `shim-ausente:reflect`×2, `shim-ausente:sync`×2 |
| 447 | `github.com/libp2p/go-libp2p/gologshim` | unsupported | `shim-ausente:log/slog`×7, `shim-ausente:os`, `shim-ausente:sync` |
| 448 | `go.opentelemetry.io/auto/sdk` | unsupported | `shim-ausente:context`×3, `conversao:nao-basico`, `shim-ausente:os`, `shim-ausente:reflect`, `shim-ausente:sync/atomic` (+1) |
| 449 | `lukechampine.com/blake3/guts` | substituicao | assembly: compress_amd64.s |
| 450 | `lukechampine.com/blake3/bao` | unsupported | `shim-ausente:io`×4, `shim-simbolo:bytes.newBuffer`×3, `range:pointer`, `shim-simbolo:bytes.Reader` |
| 451 | `lukechampine.com/blake3` | unsupported | `shim-ausente:io`×3, `shim-simbolo:bytes.newBuffer` |
| 452 | `github.com/multiformats/go-multihash/register/blake3` | bloqueado | `dart:uri_does_not_exist`×2 |
| 453 | `github.com/multiformats/go-multihash/register/all` | unsupported | `import:_` |
| 454 | `github.com/dustin/go-humanize` | unsupported | `shim-ausente:math/big`×38, `shim-ausente:time`×6, `shim-ausente:regexp`×3, `shim-simbolo:math.pow`×3, `shim-simbolo:strconv.formatFloat`×2 (+4) |
| 455 | `github.com/flynn/noise` | unsupported | `shim-ausente:hash`×6, `shim-ausente:io`×6, `shim-ausente:crypto/aes`, `shim-ausente:crypto/cipher`, `shim-ausente:crypto/rand` (+2) |
| 456 | `github.com/klauspost/compress/s2` | unsupported | `branch:goto`×14, `shim-ausente:sync`×10, `shim-ausente:io`×8, `shim-simbolo:encoding/binary.putUvarint`×8, `shim-ausente:hash/crc32`×3 (+4) |
| 457 | `github.com/libp2p/go-libp2p-kbucket/keyspace` | unsupported | `shim-ausente:math/big`×5 |
| 458 | `github.com/minio/minlz` | unsupported | `shim-ausente:io`×10, `branch:goto`×6, `shim-ausente:sync`×6, `shim-ausente:hash/crc32`×3, `shim-simbolo:encoding/binary.putUvarint`×2 (+4) |
| 459 | `github.com/mr-tron/base58` | unsupported | `shim-ausente:math/big`×5, `copy-string` |
| 460 | `github.com/mr-tron/base58/base58` | unsupported | `shim-ausente:math/big`×5, `copy-string` |
| 461 | `github.com/multiformats/go-multibase` | unsupported | `shim-ausente:unicode/utf8`×4, `shim-ausente:encoding/hex`, `shim-simbolo:strings.repeat` |
| 462 | `github.com/multiformats/go-multihash` | unsupported | `import:_` |
| 463 | `github.com/ipfs/go-cid` | unsupported | `shim-ausente:io`×4, `shim-simbolo:bytes.newReader`, `shim-simbolo:strings.Builder` |
| 464 | `github.com/ipfs/boxo/bitswap/client/wantlist` | unsupported | `shim-ausente:cmp` |
| 465 | `github.com/ipfs/boxo/ipld/unixfs/private/linksize` | bloqueado | `dart:uri_does_not_exist` |
| 466 | `github.com/ipfs/boxo/path` | unsupported | `shim-ausente:path` |
| 467 | `github.com/ipfs/boxo/verifcid` | bloqueado | `dart:uri_does_not_exist`×2 |
| 468 | `github.com/ipfs/boxo/bitswap/internal/defaults` | unsupported | `shim-ausente:time` |
| 469 | `github.com/ipfs/go-cidutil` | unsupported | `make:chan`, `shim-simbolo:bytes.Buffer`, `shim-simbolo:strings.compare`, `tipo:chan` |
| 470 | `github.com/ipfs/go-cidutil/cidenc` | bloqueado | `dart:uri_does_not_exist`×2 |
| 471 | `github.com/ipld/go-car/v2/internal/carv1/util` | unsupported | `shim-ausente:io`×6 |
| 472 | `github.com/ipld/go-ipld-prime/linking/cid` | unsupported | `shim-ausente:io`×2 |
| 473 | `github.com/ipld/go-ipld-prime/codec/dagcbor` | unsupported | `shim-ausente:io`×7 |
| 474 | `github.com/ipld/go-ipld-prime/codec/cbor` | unsupported | `shim-ausente:io`×2 |
| 475 | `github.com/ipld/go-ipld-prime/codec/dagjson` | unsupported | `shim-ausente:io`×5, `shim-ausente:encoding/base64`×2 |
| 476 | `github.com/ceramicnetwork/go-dag-jose/dagjose` | unsupported | `conversao:nao-basico`×44, `branch:goto`×14, `shim-ausente:io`×5, `shim-ausente:encoding/base64`×2, `shim-ausente:reflect` (+2) |
| 477 | `github.com/ipld/go-ipld-prime/codec/json` | unsupported | `shim-ausente:io`×2 |
| 478 | `github.com/ipld/go-ipld-prime/traversal/selector` | unsupported | `shim-ausente:io`×2 |
| 479 | `github.com/ipld/go-ipld-prime/traversal` | unsupported | `shim-ausente:context`, `shim-simbolo:errors.is$` |
| 480 | `github.com/ipld/go-ipld-prime/traversal/selector/builder` | bloqueado | `dart:uri_does_not_exist`×3, `dart:prefix_shadowed_by_local_declaration`×2, `dart:undefined_method` |
| 481 | `github.com/ipld/go-ipld-prime/traversal/selector/parse` | unsupported | `shim-simbolo:strings.Reader`×2 |
| 482 | `github.com/libp2p/go-libp2p-kad-dht/provider/internal` | bloqueado | `dart:uri_does_not_exist` |
| 483 | `github.com/pion/dtls/v3/pkg/crypto/elliptic` | unsupported | `shim-ausente:crypto/ecdh`, `shim-ausente:crypto/rand` |
| 484 | `github.com/pion/randutil` | unsupported | `shim-ausente:crypto/rand`×2, `shim-ausente:math/rand`, `shim-ausente:time` |
| 485 | `github.com/pion/rtp` | unsupported | `shim-ausente:time`×10, `shim-ausente:io`×5, `shim-ausente:sync` |
| 486 | `github.com/pion/interceptor` | unsupported | `shim-ausente:io`, `shim-simbolo:errors.is$` |
| 487 | `github.com/pion/interceptor/internal/rtpbuffer` | unsupported | `shim-ausente:sync`×3 |
| 488 | `github.com/pion/interceptor/pkg/flexfec/util` | bloqueado | `dart:invalid_constant`, `dart:undefined_getter`, `dart:uri_does_not_exist` |
| 489 | `github.com/pion/interceptor/pkg/flexfec` | unsupported | `shim-ausente:sync`×2 |
| 490 | `github.com/pion/interceptor/pkg/nack` | unsupported | `shim-ausente:sync`×3, `shim-ausente:time`×3 |
| 491 | `github.com/pion/interceptor/pkg/report` | unsupported | `shim-ausente:time`×10, `shim-ausente:sync`×2, `tipo:chan`×2, `shim-ausente:math/rand` |
| 492 | `github.com/pion/interceptor/pkg/rfc8888` | unsupported | `shim-ausente:time`×9, `shim-ausente:sync`×2, `tipo:chan` |
| 493 | `github.com/pion/interceptor/pkg/twcc` | unsupported | `make:chan`, `shim-ausente:sync`, `shim-ausente:sync/atomic`, `shim-ausente:time` |
| 494 | `github.com/pion/rtp/codecs` | bloqueado | `dart:undefined_class`×18, `dart:implicit_this_reference_in_initializer`×6, `dart:constructor_with_return_type`, `dart:undefined_method`, `dart:uri_does_not_exist` |
| 495 | `github.com/pion/webrtc/v4/internal/util` | unsupported | `shim-simbolo:errors.is$` |
| 496 | `github.com/pion/webrtc/v4/pkg/media` | unsupported | `shim-ausente:time` |
| 497 | `github.com/whyrusleeping/cbor/go` | unsupported | `shim-ausente:reflect`×11, `shim-ausente:io`×9, `shim-ausente:math/big`×2, `shim-simbolo:bytes.Buffer`, `shim-simbolo:bytes.Reader` |
| 498 | `github.com/ipld/go-car/v2/index` | unsupported | `shim-ausente:io`×8 |
| 499 | `github.com/whyrusleeping/chunker` | unsupported | `shim-ausente:sync` |
| 500 | `github.com/whyrusleeping/go-keyspace` | unsupported | `shim-ausente:math/big`×3, `shim-ausente:crypto/sha256` |
| 501 | `github.com/whyrusleeping/go-sysinfo` | unsupported | `shim-ausente:io/ioutil`, `shim-ausente:syscall` |
| 502 | `golang.org/x/crypto/cryptobyte` | unsupported | `shim-ausente:math/big`×3, `shim-ausente:encoding/asn1`, `shim-ausente:reflect` |
| 503 | `github.com/gabriel-vasile/mimetype` | unsupported | `shim-ausente:mime`×3, `shim-ausente:sync`×2, `shim-ausente:sync/atomic`×2, `shim-ausente:io`, `shim-ausente:os` |
| 504 | `github.com/cheggaaa/pb/v3/termutil` | unsupported | `shim-ausente:os`×6, `tipo:chan`×2, `shim-ausente:sync` |
| 505 | `github.com/hanwen/go-fuse/v2/internal` | unsupported | `shim-ausente:os/user` |
| 506 | `github.com/caddyserver/certmagic/internal/atomicfile` | unsupported | `shim-ausente:io/fs`×2, `shim-ausente:io`, `shim-ausente:os` |
| 507 | `github.com/facebookgo/atomicfile` | unsupported | `shim-ausente:io/fs`, `shim-ausente:os` |
| 508 | `github.com/fsnotify/fsnotify` | unsupported | `tipo:chan`×5, `make:chan`×2, `shim-ausente:os`, `shim-ausente:path/filepath`, `shim-simbolo:strings.Builder` (+1) |
| 509 | `github.com/go-logr/logr/funcr` | unsupported | `shim-ausente:log/slog`, `shim-ausente:reflect`, `shim-simbolo:bytes.Buffer`, `shim-simbolo:bytes.newBuffer`, `shim-simbolo:strconv.isPrint` (+1) |
| 510 | `github.com/go-logr/stdr` | unsupported | `shim-ausente:log`, `shim-simbolo:bytes.Buffer` |
| 511 | `github.com/ipfs/kubo/misc/fsutil` | unsupported | `shim-ausente:os`×3 |
| 512 | `github.com/ipfs/kubo/repo/fsrepo/migrations/atomicfile` | unsupported | `shim-ausente:io/fs`, `shim-ausente:os` |
| 513 | `github.com/prometheus/procfs/internal/fs` | unsupported | `shim-ausente:os`, `shim-ausente:path/filepath` |
| 514 | `github.com/syndtr/goleveldb/leveldb/storage` | unsupported | `shim-ausente:os`×7, `shim-ausente:io`×3, `shim-ausente:io/fs`×2, `shim-ausente:sync`×2, `shim-simbolo:bytes.Buffer` (+2) |
| 515 | `github.com/syndtr/goleveldb/leveldb/errors` | bloqueado | `dart:uri_does_not_exist`×2, `dart:invalid_constant`, `dart:undefined_getter` |
| 516 | `github.com/syndtr/goleveldb/leveldb/iterator` | unsupported | `shim-ausente:container/heap` |
| 517 | `github.com/syndtr/goleveldb/leveldb/journal` | unsupported | `shim-ausente:io`×5 |
| 518 | `github.com/syndtr/goleveldb/leveldb/memdb` | unsupported | `shim-ausente:math/rand`×2, `branch:goto` |
| 519 | `github.com/syndtr/goleveldb/leveldb/table` | unsupported | `shim-ausente:io`×3, `shim-simbolo:encoding/binary.putUvarint`×2, `shim-simbolo:encoding/binary.uvarint`×2, `shim-ausente:sync` |
| 520 | `github.com/syndtr/goleveldb/leveldb` | unsupported | `shim-ausente:time`×6, `shim-ausente:sync`×5, `shim-ausente:sync/atomic`×5, `shim-ausente:io`×3, `tipo:chan`×3 (+8) |
| 521 | `go4.org/lock` | unsupported | `shim-ausente:io`×4, `shim-ausente:os`×3, `shim-ausente:sync`, `shim-ausente:syscall` |
| 522 | `golang.org/x/sys/execabs` | unsupported | `shim-ausente:os/exec`×6, `shim-ausente:context` |
| 523 | `github.com/RaduBerinde/axisds` | unsupported | `generico-nao-struct`×4, `shim-ausente:regexp`, `shim-simbolo:fmt.sscanf` |
| 524 | `github.com/RaduBerinde/axisds/regiontree` | unsupported | `conversao:nao-basico`, `generico-nao-struct`, `layout:typeparam` |
| 525 | `github.com/ipfs/boxo/util` | unsupported | `shim-ausente:os`×2, `shim-ausente:time`×2, `shim-ausente:path/filepath`, `shim-ausente:runtime/debug` |
| 526 | `github.com/ipfs/go-block-format` | bloqueado | `dart:prefix_shadowed_by_local_declaration`×4, `dart:uri_does_not_exist`×3 |
| 527 | `github.com/ipfs/boxo/bitswap/client/internal/sessioninterestmanager` | unsupported | `shim-ausente:sync` |
| 528 | `github.com/ipfs/boxo/exchange` | unsupported | `shim-ausente:context`×2, `shim-ausente:io` |
| 529 | `github.com/ipfs/go-ipld-format` | unsupported | `shim-ausente:context`×18, `shim-ausente:runtime`, `shim-simbolo:errors.is$`, `tipo:chan` |
| 530 | `github.com/ipfs/boxo/filestore/posinfo` | unsupported | `shim-ausente:io/fs` |
| 531 | `github.com/ipfs/boxo/ipld/merkledag/traverse` | unsupported | `shim-ausente:context` |
| 532 | `github.com/ipfs/boxo/pinning/pinner` | unsupported | `shim-ausente:context` |
| 533 | `github.com/ipfs/kubo/core/commands/e` | unsupported | `shim-ausente:runtime/debug` |
| 534 | `github.com/libp2p/go-libp2p/core/internal/catch` | unsupported | `shim-ausente:io`, `shim-ausente:os`, `shim-ausente:runtime/debug` |
| 535 | `github.com/libp2p/go-libp2p/p2p/protocol/identify/internal/user-agent` | unsupported | `shim-ausente:runtime/debug` |
| 536 | `github.com/libp2p/go-msgio/pbio` | unsupported | `shim-ausente:io`×5, `shim-ausente:bufio` |
| 537 | `github.com/libp2p/go-msgio/protoio` | unsupported | `shim-ausente:io`×5, `shim-ausente:bufio` |
| 538 | `github.com/multiformats/go-multistream` | unsupported | `shim-ausente:io`×19, `shim-ausente:bufio`×2, `shim-ausente:sync`×2, `generico-nao-struct`, `make:chan` (+1) |
| 539 | `github.com/libp2p/go-libp2p/core/protocol` | unsupported | `shim-ausente:io`×2 |
| 540 | `github.com/ipfs/boxo/bitswap/network/bsnet/internal` | bloqueado | `dart:invalid_constant`, `dart:undefined_getter`, `dart:uri_does_not_exist` |
| 541 | `github.com/libp2p/go-libp2p-kad-dht/amino` | unsupported | `shim-ausente:time` |
| 542 | `go.opencensus.io/trace` | unsupported | `shim-ausente:time`×11, `shim-ausente:context`×7, `shim-ausente:sync`×6, `conversao:nao-basico`, `shim-ausente:sync/atomic` (+1) |
| 543 | `go.opencensus.io/metric/metricexport` | unsupported | `shim-ausente:time`×3, `shim-ausente:context`×2 |
| 544 | `github.com/ipfs/kubo/repo/fsrepo/migrations/common` | unsupported | `shim-ausente:testing`×6, `shim-ausente:io`×4, `shim-ausente:maps`×2, `shim-ausente:path/filepath`×2, `shim-ausente:os` (+1) |
| 545 | `github.com/ipfs/kubo/repo/fsrepo/migrations/fs-repo-17-to-18/migration` | unsupported | `shim-ausente:io` |
| 546 | `github.com/kr/pretty` | unsupported | `shim-ausente:reflect`×12, `shim-ausente:io`×5, `shim-ausente:log`×3, `conversao:nao-basico`, `shim-simbolo:fmt.Formatter` |
| 547 | `github.com/cockroachdb/errors/errbase` | unsupported | `shim-ausente:context`×41, `shim-simbolo:fmt.State`×9, `shim-ausente:reflect`×2, `shim-ausente:io/fs`, `shim-ausente:os` (+2) |
| 548 | `github.com/cockroachdb/errors/barriers` | unsupported | `shim-ausente:context`×3, `shim-simbolo:fmt.State` |
| 549 | `github.com/cockroachdb/errors/contexttags` | unsupported | `shim-ausente:context`×3, `shim-simbolo:fmt.State` |
| 550 | `github.com/cockroachdb/errors/domains` | unsupported | `shim-ausente:context`, `shim-ausente:runtime`, `shim-simbolo:fmt.State` |
| 551 | `github.com/cockroachdb/errors/hintdetail` | unsupported | `shim-ausente:context`×4, `shim-simbolo:bytes.Buffer`×2, `shim-simbolo:fmt.State`×2 |
| 552 | `github.com/cockroachdb/errors/join` | unsupported | `shim-ausente:context`, `shim-simbolo:fmt.State` |
| 553 | `github.com/cockroachdb/errors/markers` | unsupported | `shim-ausente:reflect`×5, `shim-ausente:context`×2, `fmt-verbo:%p`, `shim-simbolo:fmt.State` |
| 554 | `github.com/cockroachdb/errors/assert` | unsupported | `shim-ausente:context`, `shim-simbolo:fmt.State` |
| 555 | `github.com/cockroachdb/errors/issuelink` | unsupported | `shim-simbolo:bytes.Buffer`×3, `shim-ausente:context`×2 |
| 556 | `github.com/cockroachdb/errors/safedetails` | unsupported | `shim-ausente:reflect`×2, `shim-ausente:context`, `shim-simbolo:fmt.State` |
| 557 | `github.com/cockroachdb/errors/secondary` | unsupported | `shim-ausente:context`×2, `shim-simbolo:fmt.State` |
| 558 | `github.com/cockroachdb/errors/telemetrykeys` | unsupported | `shim-ausente:context`, `shim-simbolo:fmt.State` |
| 559 | `github.com/ipld/go-ipld-prime/node/bindnode` | unsupported | `shim-ausente:reflect`×65, `conversao:nao-basico`, `shim-ausente:io`, `shim-ausente:runtime`, `shim-simbolo:strings.Builder` (+1) |
| 560 | `github.com/ipld/go-ipld-prime/schema/dmt` | unsupported | `conversao:bool-bool`, `fmt-verbo:%#v` |
| 561 | `github.com/ipld/go-ipld-prime/schema/dsl` | unsupported | `shim-ausente:bufio`, `shim-ausente:io`, `shim-ausente:os`, `shim-ausente:reflect`, `shim-simbolo:bytes.Reader` |
| 562 | `github.com/ipld/go-ipld-prime` | unsupported | `shim-ausente:io`×6, `shim-simbolo:bytes.Reader`×3, `shim-ausente:os`, `shim-simbolo:bytes.Buffer` |
| 563 | `github.com/ipfs/boxo/fetcher` | unsupported | `shim-ausente:context`×2 |
| 564 | `github.com/ipfs/boxo/fetcher/helpers` | unsupported | `shim-ausente:context`×3 |
| 565 | `github.com/ipfs/go-ipld-git` | unsupported | `conversao:nao-basico`×24, `shim-ausente:bufio`×9, `shim-ausente:io`×9, `branch:goto`, `shim-simbolo:bytes.Reader` (+1) |
| 566 | `github.com/ipfs/go-ipld-legacy` | unsupported | `shim-ausente:context`, `shim-simbolo:bytes.Buffer` |
| 567 | `github.com/ipfs/go-unixfsnode/data` | unsupported | `conversao:nao-basico`×12, `branch:goto`×6 |
| 568 | `github.com/ipld/go-car/v2/internal/loader` | unsupported | `shim-ausente:io`×4, `shim-simbolo:bytes.newBuffer` |
| 569 | `github.com/ipld/go-codec-dagpb` | unsupported | `conversao:nao-basico`×9, `shim-ausente:io`×6, `branch:goto`×4 |
| 570 | `github.com/ipfs/go-unixfsnode/file` | unsupported | `shim-ausente:io`×6, `shim-ausente:context`×5 |
| 571 | `github.com/ipfs/go-unixfsnode/iter` | bloqueado | `dart:uri_does_not_exist`×3 |
| 572 | `github.com/ipfs/go-unixfsnode/hamt` | unsupported | `shim-ausente:context`×4, `shim-ausente:hash` |
| 573 | `github.com/ipfs/go-unixfsnode/utils` | bloqueado | `dart:uri_does_not_exist` |
| 574 | `github.com/ipfs/go-unixfsnode/directory` | unsupported | `shim-ausente:context` |
| 575 | `github.com/ipfs/go-unixfsnode` | unsupported | `shim-ausente:context`×5, `shim-ausente:io` |
| 576 | `go.opencensus.io/tag` | unsupported | `shim-ausente:context`×5, `shim-simbolo:bytes.Buffer`, `shim-simbolo:encoding/binary.putUvarint` |
| 577 | `go.opencensus.io/stats/internal` | bloqueado | `dart:uri_does_not_exist` |
| 578 | `go.opencensus.io/stats` | unsupported | `shim-ausente:context`×3, `shim-ausente:sync`, `shim-ausente:sync/atomic` |
| 579 | `go.opencensus.io/stats/view` | unsupported | `shim-ausente:time`×26, `tipo:chan`×3, `shim-ausente:reflect`, `shim-ausente:sync/atomic`, `shim-simbolo:bytes.Buffer` (+1) |
| 580 | `filippo.io/keygen` | unsupported | `shim-ausente:crypto/elliptic`×3, `shim-ausente:crypto/rsa`×2, `shim-ausente:crypto/rand`, `shim-ausente:crypto/sha256`, `shim-simbolo:bytes.clone` |
| 581 | `github.com/decred/dcrd/dcrec/secp256k1/v4` | unsupported | `shim-ausente:math/big`×6, `shim-ausente:encoding/hex`×4, `shim-ausente:crypto/elliptic`×2, `shim-ausente:io`×2, `shim-simbolo:bytes.repeat`×2 (+6) |
| 582 | `github.com/decred/dcrd/dcrec/secp256k1/v4/ecdsa` | unsupported | `shim-ausente:math/big` |
| 583 | `github.com/klauspost/compress/zstd` | unsupported | `shim-ausente:io`×18, `shim-ausente:sync`×9, `shim-ausente:runtime`×6, `tipo:chan`×5, `conversao:nao-basico`×4 (+10) |
| 584 | `github.com/libdns/libdns` | unsupported | `shim-ausente:time`×9, `shim-ausente:context`×5, `shim-simbolo:strings.Builder`, `shim-simbolo:strings.trim`, `shim-simbolo:strings.trimSpace` |
| 585 | `github.com/coreos/go-systemd/v22/daemon` | unsupported | `shim-ausente:os`, `shim-ausente:time` |
| 586 | `github.com/google/gopacket/routing` | unsupported | `shim-ausente:net`×4, `shim-ausente:syscall` |
| 587 | `github.com/google/uuid` | unsupported | `shim-ausente:io`×6, `shim-ausente:net`×2, `shim-ausente:os`×2, `shim-ausente:sync`×2, `shim-ausente:time`×2 (+9) |
| 588 | `github.com/hanwen/go-fuse/v2/fuse` | unsupported | `tipo-basico:Pointer`×46, `shim-ausente:os`×10, `shim-ausente:syscall`×10, `shim-ausente:time`×9, `tipo:chan`×6 (+13) |
| 589 | `github.com/hanwen/go-fuse/v2/fs` | unsupported | `shim-ausente:context`×58, `conversao:nao-basico`×51, `shim-ausente:syscall`×15, `shim-ausente:sync`×6, `shim-ausente:time`×2 (+2) |
| 590 | `github.com/ipfs/go-datastore` | unsupported | `shim-ausente:context`×29, `shim-ausente:io`, `shim-ausente:path`, `shim-ausente:reflect`, `shim-simbolo:strings.replace` |
| 591 | `github.com/ipfs/boxo/datastore/dshelp` | bloqueado | `dart:uri_does_not_exist`×4 |
| 592 | `github.com/ipfs/go-datastore/keytransform` | unsupported | `shim-ausente:context`×3 |
| 593 | `github.com/ipfs/go-datastore/mount` | unsupported | `shim-ausente:container/heap`, `shim-ausente:context`, `shim-ausente:slices`, `shim-ausente:sync` |
| 594 | `github.com/ipfs/go-datastore/namespace` | bloqueado | `dart:uri_does_not_exist`×2 |
| 595 | `github.com/ipfs/boxo/pinning/pinner/dsindex` | unsupported | `shim-ausente:context`×3 |
| 596 | `github.com/ipfs/go-datastore/sync` | unsupported | `shim-ausente:context`, `shim-ausente:sync` |
| 597 | `github.com/ipfs/go-ds-leveldb` | unsupported | `shim-ausente:context`×2, `shim-ausente:sync`×2, `conversao:nao-basico` |
| 598 | `github.com/ipfs/go-ds-measure` | unsupported | `shim-ausente:context`×2, `shim-ausente:time` |
| 599 | `github.com/ipfs/go-ipfs-ds-help` | bloqueado | `dart:uri_does_not_exist`×4 |
| 600 | `github.com/jackpal/go-nat-pmp` | unsupported | `shim-ausente:time`×4, `shim-ausente:net`×3 |
| 601 | `github.com/libp2p/go-cidranger/net` | unsupported | `shim-ausente:net`×6 |
| 602 | `github.com/libp2p/go-cidranger` | unsupported | `shim-ausente:net`×13 |
| 603 | `github.com/libp2p/go-libp2p-asn-util` | unsupported | `import:_` |
| 604 | `github.com/libp2p/go-libp2p/p2p/net/pnet` | unsupported | `shim-ausente:net`×3 |
| 605 | `github.com/libp2p/go-netroute` | unsupported | `shim-ausente:net`×7, `shim-ausente:syscall`×2, `shim-simbolo:bytes.Buffer`×2 |
| 606 | `github.com/libp2p/go-reuseport` | unsupported | `shim-ausente:net`×6, `shim-ausente:syscall`, `shim-ausente:time` |
| 607 | `github.com/libp2p/go-yamux/v5` | unsupported | `shim-ausente:time`×6, `shim-ausente:net`×4, `tipo:chan`×4, `make:chan`×2, `shim-ausente:sync`×2 (+2) |
| 608 | `github.com/marten-seemann/tcp` | unsupported | `tipo-basico:Pointer`×4, `shim-ausente:net`×2, `shim-ausente:sync`, `shim-ausente:syscall` |
| 609 | `github.com/pion/dtls/v3/internal/net` | unsupported | `shim-ausente:net`, `shim-ausente:sync` |
| 610 | `github.com/pion/dtls/v3/pkg/net` | unsupported | `shim-ausente:net`×5 |
| 611 | `github.com/pion/dtls/v3/internal/net/udp` | unsupported | `shim-ausente:net`×4 |
| 612 | `github.com/pion/dtls/v3/pkg/protocol` | unsupported | `literal-composto:pointer`, `shim-ausente:net` |
| 613 | `github.com/pion/dtls/v3/pkg/crypto/prf` | unsupported | `shim-ausente:hash`×2, `fmt-verbo:%#v`, `shim-ausente:crypto/ecdh`, `shim-ausente:crypto/hmac` |
| 614 | `github.com/pion/dtls/v3/pkg/protocol/alert` | bloqueado | `dart:uri_does_not_exist` |
| 615 | `github.com/pion/ice/v4/internal/fakenet` | unsupported | `shim-ausente:net`×2 |
| 616 | `github.com/pion/sctp` | unsupported | `shim-ausente:time`×6, `shim-ausente:hash/crc32`×3, `shim-ausente:sync`×3, `shim-ausente:context`×2, `shim-ausente:sync/atomic`×2 (+6) |
| 617 | `github.com/pion/datachannel` | unsupported | `shim-ausente:time`×3, `shim-ausente:io`, `shim-ausente:sync` |
| 618 | `github.com/pion/srtp/v3` | unsupported | `shim-ausente:sync`×7, `shim-ausente:crypto/aes`×3, `fmt-verbo:%#v`×2, `operador-unario:<-`×2, `shim-ausente:crypto/cipher`×2 (+5) |
| 619 | `github.com/pion/transport/v3` | unsupported | `shim-ausente:net`×7 |
| 620 | `github.com/pion/transport/v3/vnet` | unsupported | `shim-ausente:net`×21, `shim-ausente:time`×11, `shim-ausente:sync`×4, `shim-ausente:sync/atomic`×2, `make:chan` (+1) |
| 621 | `github.com/pion/transport/v4` | unsupported | `shim-ausente:net`×7, `shim-ausente:context` |
| 622 | `github.com/pion/transport/v4/netctx` | unsupported | `shim-ausente:context`×5, `shim-ausente:net`×5, `shim-ausente:io`×2, `shim-ausente:time`×2 |
| 623 | `github.com/pion/turn/v4/internal/ipnet` | unsupported | `shim-ausente:net`×3 |
| 624 | `github.com/prometheus/procfs` | unsupported | `shim-ausente:regexp`×36, `shim-ausente:io`×21, `shim-simbolo:bytes.Reader`×15, `shim-ausente:os`×11, `shim-simbolo:strings.fields`×9 (+11) |
| 625 | `github.com/whyrusleeping/multiaddr-filter` | unsupported | `shim-ausente:net`×2 |
| 626 | `github.com/wlynxg/anet` | unsupported | `shim-ausente:net`×3 |
| 627 | `github.com/pion/transport/v3/stdnet` | unsupported | `shim-ausente:net`×3 |
| 628 | `github.com/pion/transport/v4/stdnet` | unsupported | `shim-ausente:net`×4 |
| 629 | `golang.org/x/net/internal/socket` | unsupported | `shim-ausente:net`×13, `shim-ausente:syscall`×8, `tipo-basico:Pointer`×7, `shim-ausente:sync`×3, `func-sem-corpo`×2 (+1) |
| 630 | `golang.org/x/net/internal/socks` | unsupported | `shim-ausente:net`×4, `shim-ausente:time`×3, `shim-ausente:context` |
| 631 | `golang.org/x/net/ipv4` | unsupported | `shim-ausente:net`×15, `tipo-basico:Pointer`×3, `andnot-nao-ident`, `literal-composto:pointer`, `shim-ausente:sync` |
| 632 | `github.com/koron/go-ssdp/internal/multicast` | unsupported | `shim-ausente:net`×14, `shim-ausente:sync` |
| 633 | `golang.org/x/net/ipv6` | unsupported | `shim-ausente:net`×13, `shim-simbolo:encoding/binary.nativeEndian`×4, `tipo-basico:Pointer`×4, `andnot-nao-ident`, `literal-composto:pointer` (+1) |
| 634 | `github.com/pion/mdns/v2` | unsupported | `shim-ausente:net/netip`×9, `shim-ausente:net`×5, `shim-ausente:time`×3, `shim-ausente:sync`, `tipo:chan` |
| 635 | `google.golang.org/grpc/internal` | unsupported | `shim-ausente:time`×4, `shim-ausente:context`, `shim-ausente:net` |
| 636 | `google.golang.org/grpc/codes` | bloqueado | `dart:prefix_collides_with_top_level_member`, `dart:undefined_getter`, `dart:uri_does_not_exist` |
| 637 | `google.golang.org/grpc/internal/mem` | unsupported | `shim-ausente:sync`×2, `shim-ausente:slices` |
| 638 | `google.golang.org/grpc/internal/resolver/dns/internal` | unsupported | `shim-ausente:context`, `tipo:chan` |
| 639 | `google.golang.org/grpc/internal/status` | bloqueado | `dart:uri_does_not_exist`×3, `dart:undefined_method` |
| 640 | `google.golang.org/grpc/internal/syscall` | unsupported | `shim-ausente:net`×2, `shim-ausente:syscall`×2 |
| 641 | `google.golang.org/grpc/mem` | unsupported | `shim-ausente:io`×3, `shim-ausente:sync`×2, `shim-ausente:sync/atomic` |
| 642 | `google.golang.org/grpc/internal/transport/readyreader` | unsupported | `shim-ausente:io`×4, `shim-ausente:syscall`×3 |
| 643 | `google.golang.org/grpc/metadata` | unsupported | `shim-ausente:context`×7, `shim-simbolo:strings.toLower`×3 |
| 644 | `google.golang.org/grpc/internal/balancerload` | bloqueado | `dart:uri_does_not_exist` |
| 645 | `google.golang.org/grpc/internal/grpcutil` | unsupported | `shim-ausente:context`×2, `shim-ausente:time`×2 |
| 646 | `google.golang.org/grpc/encoding` | unsupported | `shim-simbolo:strings.toLower`×2, `shim-ausente:io`, `shim-ausente:slices` |
| 647 | `google.golang.org/grpc/encoding/gzip` | unsupported | `shim-ausente:compress/gzip`×2, `shim-ausente:io`×2, `shim-ausente:sync` |
| 648 | `google.golang.org/grpc/encoding/proto` | bloqueado | `dart:uri_does_not_exist`×4, `dart:return_of_invalid_type`, `dart:unnecessary_cast` |
| 649 | `google.golang.org/grpc/stats` | unsupported | `shim-ausente:context`×5, `shim-ausente:time`×4, `shim-ausente:net`×3, `shim-ausente:maps` |
| 650 | `google.golang.org/grpc/experimental/stats` | unsupported | `conversao:nao-basico`×14, `shim-ausente:context`×2, `shim-ausente:maps` |
| 651 | `google.golang.org/grpc/internal/stats` | unsupported | `shim-ausente:context`×4 |
| 652 | `google.golang.org/grpc/status` | unsupported | `shim-ausente:context`, `shim-simbolo:errors.as` |
| 653 | `google.golang.org/grpc/internal/binarylog` | unsupported | `shim-ausente:regexp`×7, `shim-ausente:net`×4, `shim-ausente:io`×3, `shim-ausente:context`×2, `shim-ausente:time`×2 (+3) |
| 654 | `google.golang.org/grpc/tap` | unsupported | `shim-ausente:context` |
| 655 | `golang.org/x/net/http/httpguts` | unsupported | `shim-ausente:net`, `shim-ausente:net/textproto` |
| 656 | `github.com/cockroachdb/pebble/v2/internal/lsmview` | unsupported | `shim-ausente:net/url` |
| 657 | `github.com/coreos/go-systemd/v22/activation` | unsupported | `shim-ausente:net`×3, `shim-ausente:crypto/tls`×2, `shim-ausente:os`×2 |
| 658 | `github.com/getsentry/sentry-go/internal/otel/baggage` | unsupported | `shim-ausente:regexp`×9, `shim-simbolo:strings.Builder`, `shim-simbolo:strings.trimSpace` |
| 659 | `github.com/ipfs/go-ipfs-redirects-file` | unsupported | `shim-ausente:net/url`×3, `shim-simbolo:strings.replaceAll`×2, `shim-ausente:io`, `shim-simbolo:strings.Reader` |
| 660 | `github.com/libp2p/go-libp2p/core/crypto` | unsupported | `conversao:nao-basico`×6, `shim-ausente:crypto/ecdsa`×5, `shim-ausente:crypto/x509`×5, `shim-ausente:io`×5, `shim-ausente:crypto`×3 (+7) |
| 661 | `github.com/libp2p/go-libp2p/core/record` | unsupported | `shim-ausente:reflect`×4, `shim-ausente:sync`, `shim-simbolo:encoding/binary.appendUvarint` |
| 662 | `github.com/miekg/dns` | unsupported | `import:_` |
| 663 | `github.com/libp2p/zeroconf/v2` | unsupported | `shim-ausente:net`×19, `shim-ausente:time`×5, `shim-ausente:context`×2, `tipo:chan`×2, `make:chan` (+1) |
| 664 | `github.com/multiformats/go-multiaddr` | unsupported | `shim-ausente:encoding/base32`×6, `shim-ausente:encoding/base64`×4, `shim-ausente:net`×3, `conversao:nao-basico`×2, `shim-ausente:log`×2 (+9) |
| 665 | `github.com/libp2p/go-libp2p/core/peer` | unsupported | `shim-ausente:encoding/json`×2, `shim-ausente:sync`, `shim-ausente:time` |
| 666 | `github.com/ipfs/boxo/bitswap/client/internal/blockpresencemanager` | unsupported | `shim-ausente:sync` |
| 667 | `github.com/ipfs/boxo/bitswap/client/traceability` | unsupported | `shim-ausente:time` |
| 668 | `github.com/ipfs/boxo/bitswap/client/internal/notifications` | unsupported | `make:chan`, `shim-ausente:context`, `shim-ausente:sync` |
| 669 | `github.com/ipfs/boxo/retrieval` | unsupported | `shim-ausente:context`×3, `make:chan`, `shim-ausente:sync/atomic` |
| 670 | `github.com/ipfs/boxo/routing/http/types` | unsupported | `shim-ausente:encoding/json`×6, `shim-ausente:time`×2, `shim-ausente:io` |
| 671 | `github.com/ipfs/boxo/routing/http/types/json` | unsupported | `shim-ausente:encoding/json` |
| 672 | `github.com/ipfs/boxo/routing/http/types/ndjson` | unsupported | `shim-ausente:io`×2 |
| 673 | `github.com/ipfs/go-peertaskqueue/peertask` | unsupported | `shim-ausente:time`×2 |
| 674 | `github.com/ipfs/go-peertaskqueue/peertracker` | unsupported | `shim-ausente:sync` |
| 675 | `github.com/ipfs/go-peertaskqueue` | unsupported | `shim-ausente:sync` |
| 676 | `github.com/libp2p/go-libp2p-kad-dht/qpeerset` | unsupported | `shim-ausente:math/big`×3 |
| 677 | `github.com/libp2p/go-libp2p-pubsub/partialmessages` | unsupported | `generico-nao-struct`, `shim-ausente:iter`, `shim-ausente:log/slog` |
| 678 | `github.com/libp2p/go-libp2p-record` | bloqueado | `dart:uri_does_not_exist`×4 |
| 679 | `github.com/libp2p/go-libp2p/core/discovery` | unsupported | `shim-ausente:context`×3, `shim-ausente:time`×2 |
| 680 | `github.com/libp2p/go-libp2p/core/metrics` | unsupported | `shim-ausente:time`×2 |
| 681 | `github.com/libp2p/go-libp2p/core/peerstore` | unsupported | `shim-ausente:time`×8, `shim-ausente:io` |
| 682 | `github.com/libp2p/go-libp2p/core/network` | unsupported | `shim-ausente:context`×16, `shim-ausente:time`×5, `shim-ausente:io`×4, `shim-ausente:net`×4 |
| 683 | `github.com/ipfs/boxo/bitswap/message` | unsupported | `shim-ausente:io`×4, `shim-ausente:maps` |
| 684 | `github.com/ipfs/boxo/bitswap/tracer` | bloqueado | `dart:uri_does_not_exist`×2 |
| 685 | `github.com/libp2p/go-libp2p/core/connmgr` | unsupported | `shim-ausente:time`×4, `shim-ausente:context`×2, `shim-ausente:io` |
| 686 | `github.com/libp2p/go-libp2p/core/event` | unsupported | `shim-ausente:io`×2, `shim-ausente:reflect` |
| 687 | `github.com/libp2p/go-libp2p/core/host` | unsupported | `shim-ausente:context` |
| 688 | `github.com/libp2p/go-libp2p-gostream` | unsupported | `shim-ausente:context`×2, `shim-ausente:net`×2, `shim-ausente:time` |
| 689 | `github.com/libp2p/go-libp2p/core/routing` | unsupported | `shim-ausente:context`×11, `shim-ausente:encoding/json`, `shim-ausente:maps`, `shim-ausente:slices`, `shim-ausente:sync` |
| 690 | `github.com/libp2p/go-libp2p/core/sec` | unsupported | `shim-ausente:context`, `shim-ausente:net` |
| 691 | `github.com/libp2p/go-libp2p/p2p/discovery/backoff` | unsupported | `shim-ausente:time`×20, `shim-ausente:sync`×3, `shim-ausente:context`×2, `shim-ausente:log/slog` |
| 692 | `github.com/libp2p/go-libp2p/p2p/discovery/mdns` | unsupported | `shim-ausente:math/rand`×2, `shim-ausente:context`, `shim-ausente:io`, `shim-ausente:log/slog`, `shim-simbolo:strings.toLower` |
| 693 | `github.com/libp2p/go-libp2p/p2p/discovery/routing` | unsupported | `shim-ausente:context`×2 |
| 694 | `github.com/libp2p/go-libp2p/p2p/host/peerstore` | unsupported | `shim-ausente:sync`, `shim-ausente:time` |
| 695 | `github.com/libp2p/go-libp2p/p2p/host/routed` | unsupported | `shim-ausente:context`×2, `shim-ausente:log/slog`, `shim-ausente:time` |
| 696 | `github.com/libp2p/go-libp2p/p2p/muxer/yamux` | unsupported | `shim-ausente:time`×2, `conversao:nao-basico`, `shim-ausente:io`, `shim-ausente:log`, `shim-simbolo:errors.as` |
| 697 | `github.com/libp2p/go-libp2p/p2p/net/connmgr` | unsupported | `shim-ausente:time`×11, `shim-ausente:sync`×5, `make:chan`, `shim-ausente:log/slog` |
| 698 | `github.com/libp2p/go-libp2p/p2p/net/gostream` | unsupported | `shim-ausente:context`×2, `shim-ausente:net`×2, `shim-ausente:time` |
| 699 | `github.com/libp2p/go-libp2p/p2p/protocol/circuitv2/proto` | unsupported | `shim-ausente:time` |
| 700 | `github.com/libp2p/go-libp2p/p2p/protocol/circuitv2/util` | unsupported | `shim-ausente:io`×3 |
| 701 | `github.com/libp2p/go-libp2p/p2p/protocol/ping` | unsupported | `shim-ausente:log/slog`×2, `shim-ausente:time`×2, `shim-ausente:context`, `shim-ausente:io`, `tipo:chan` |
| 702 | `github.com/libp2p/go-libp2p/p2p/security/insecure` | unsupported | `shim-ausente:context`, `shim-ausente:io`, `shim-ausente:net` |
| 703 | `github.com/multiformats/go-multiaddr-dns` | unsupported | `shim-ausente:context`×4, `shim-ausente:net`×3, `shim-simbolo:strings.lastIndexFunc` |
| 704 | `github.com/multiformats/go-multiaddr-fmt` | bloqueado | `dart:invalid_constant`, `dart:undefined_getter`, `dart:uri_does_not_exist` |
| 705 | `github.com/multiformats/go-multiaddr/net` | unsupported | `shim-ausente:net`×36, `conversao:nao-basico`×5, `shim-ausente:sync`, `shim-simbolo:strings.trimLeft` |
| 706 | `github.com/libp2p/go-libp2p/core/transport` | unsupported | `shim-ausente:context`×7, `shim-ausente:net`×2 |
| 707 | `github.com/libp2p/go-libp2p/p2p/canonicallog` | unsupported | `shim-ausente:context`×2, `shim-ausente:log/slog`×2, `shim-ausente:math/rand`, `shim-ausente:net` |
| 708 | `github.com/libp2p/go-libp2p/p2p/host/peerstore/pstoremem` | unsupported | `shim-ausente:time`×6, `shim-ausente:sync`×5, `shim-ausente:container/heap`, `shim-ausente:context`, `shim-ausente:log/slog` (+2) |
| 709 | `github.com/libp2p/go-libp2p-pubsub` | unsupported | `shim-ausente:time`×49, `shim-ausente:context`×15, `shim-ausente:log/slog`×14, `shim-ausente:sync`×13, `tipo:chan`×12 (+9) |
| 710 | `github.com/libp2p/go-libp2p/p2p/net/reuseport` | unsupported | `shim-ausente:net`×6, `shim-ausente:context`×2, `shim-ausente:log/slog`, `shim-ausente:sync` |
| 711 | `github.com/libp2p/go-libp2p/p2p/net/upgrader` | unsupported | `shim-ausente:time`×4, `shim-ausente:sync`×2, `shim-ausente:context`, `shim-ausente:log/slog`, `shim-ausente:net` (+1) |
| 712 | `github.com/libp2p/go-libp2p/p2p/protocol/circuitv2/client` | unsupported | `shim-ausente:time`×11, `shim-ausente:context`×5, `make:chan`, `shim-ausente:log/slog`, `tipo:chan` |
| 713 | `github.com/libp2p/go-libp2p/p2p/security/noise` | unsupported | `shim-ausente:context`×5, `shim-ausente:slices`, `shim-ausente:sync` |
| 714 | `github.com/libp2p/go-libp2p/p2p/security/tls` | unsupported | `shim-ausente:crypto/x509`×5, `shim-ausente:crypto/tls`×3, `shim-ausente:context`, `shim-ausente:crypto`, `shim-ausente:io` (+1) |
| 715 | `github.com/libp2p/go-libp2p/p2p/transport/tcpreuse/internal/sampledconn` | unsupported | `shim-ausente:net`×3, `shim-ausente:io` |
| 716 | `github.com/libp2p/go-libp2p/p2p/transport/tcpreuse` | unsupported | `shim-ausente:time`×4, `shim-ausente:sync`×2, `shim-ausente:log/slog`, `shim-ausente:net`, `shim-ausente:os` (+1) |
| 717 | `github.com/libp2p/go-libp2p/x/rate` | unsupported | `shim-ausente:net/netip`×3, `shim-ausente:time`×2, `shim-ausente:sync` |
| 718 | `github.com/pion/dtls/v3/pkg/crypto/fingerprint` | unsupported | `shim-ausente:crypto`×3, `shim-ausente:crypto/x509` |
| 719 | `github.com/pion/dtls/v3/pkg/crypto/signaturehash` | unsupported | `shim-ausente:crypto`×4, `shim-ausente:crypto/tls`, `shim-ausente:crypto/x509` |
| 720 | `github.com/pion/dtls/v3/pkg/protocol/extension` | unsupported | `shim-ausente:crypto/tls`, `shim-ausente:slices` |
| 721 | `github.com/pion/dtls/v3/pkg/protocol/handshake` | unsupported | `shim-ausente:crypto/tls`×3, `shim-ausente:time` |
| 722 | `github.com/pion/dtls/v3/pkg/protocol/recordlayer` | bloqueado | `dart:uri_does_not_exist`×3 |
| 723 | `github.com/pion/dtls/v3/pkg/crypto/ciphersuite` | unsupported | `shim-ausente:crypto/cipher`×5, `shim-ausente:crypto/aes`×3, `shim-ausente:crypto/rand` |
| 724 | `github.com/pion/dtls/v3/internal/ciphersuite` | unsupported | `shim-ausente:hash`×9, `shim-ausente:sync/atomic`×6 |
| 725 | `github.com/pion/dtls/v3` | unsupported | `shim-ausente:net`×18, `shim-ausente:context`×14, `shim-ausente:crypto/tls`×14, `shim-ausente:crypto/x509`×11, `literal-composto:pointer`×4 (+13) |
| 726 | `github.com/pion/sdp/v3` | unsupported | `append-string`×12, `shim-ausente:net/url`×4, `shim-simbolo:strconv.appendInt`×3, `shim-ausente:io`×2, `shim-ausente:slices`×2 (+8) |
| 727 | `github.com/pion/stun/v3` | unsupported | `shim-ausente:net`×10, `shim-ausente:time`×10, `shim-ausente:sync`×9, `conversao:nao-basico`×5, `shim-ausente:io`×4 (+12) |
| 728 | `github.com/pion/ice/v4/internal/stun` | unsupported | `shim-ausente:net` |
| 729 | `github.com/pion/turn/v4/internal/proto` | unsupported | `shim-ausente:net`×3, `shim-ausente:time`×2, `conversao:nao-basico`, `shim-ausente:io` |
| 730 | `github.com/pion/turn/v4/internal/allocation` | unsupported | `shim-ausente:net`×9, `shim-ausente:sync`, `shim-ausente:time` |
| 731 | `github.com/pion/turn/v4/internal/client` | unsupported | `shim-ausente:net`×12, `shim-ausente:time`×5, `shim-ausente:sync`×3, `make:chan`×2, `tipo:chan`×2 (+2) |
| 732 | `github.com/pion/turn/v4/internal/server` | unsupported | `shim-ausente:net`×6, `shim-ausente:time`×6, `shim-ausente:crypto/rand` |
| 733 | `github.com/pion/turn/v4` | unsupported | `shim-ausente:net`×15, `shim-ausente:time`×8, `shim-ausente:crypto/md5`, `shim-ausente:crypto/sha1` |
| 734 | `github.com/quic-go/quic-go/internal/protocol` | unsupported | `shim-ausente:time`×11, `shim-ausente:crypto/rand`×3, `shim-ausente:crypto/tls`×2, `shim-ausente:encoding/hex`×2, `shim-ausente:slices`×2 (+3) |
| 735 | `github.com/quic-go/quic-go/internal/qerr` | unsupported | `shim-ausente:net`×6, `shim-ausente:crypto/tls` |
| 736 | `github.com/quic-go/quic-go/internal/utils` | unsupported | `shim-ausente:bufio`×2, `shim-ausente:sync/atomic`×2, `shim-ausente:time`×2, `shim-ausente:crypto/rand`, `shim-ausente:log` (+1) |
| 737 | `github.com/quic-go/quic-go/internal/wire` | unsupported | `shim-ausente:io`×17, `shim-ausente:time`×6, `shim-ausente:crypto/rand`, `shim-ausente:net/netip`, `shim-ausente:sync` (+1) |
| 738 | `github.com/quic-go/quic-go/qlogwriter` | unsupported | `shim-ausente:io`×5, `shim-ausente:time`×4, `shim-ausente:runtime/debug` |
| 739 | `github.com/quic-go/quic-go/qlog` | unsupported | `shim-ausente:time`×26, `shim-ausente:encoding/hex`×4, `shim-ausente:context`×2, `shim-ausente:net/netip`×2, `conversao:nao-basico` (+2) |
| 740 | `github.com/quic-go/quic-go/internal/congestion` | unsupported | `shim-ausente:time`×5 |
| 741 | `github.com/quic-go/quic-go/internal/ackhandler` | unsupported | `shim-ausente:time`×4, `shim-ausente:slices`×3, `range:func`×2, `shim-ausente:sync`×2 |
| 742 | `github.com/quic-go/quic-go/internal/handshake` | unsupported | `import:_` |
| 743 | `github.com/quic-go/quic-go` | unsupported | `shim-ausente:net`×30, `shim-ausente:sync`×20, `shim-ausente:context`×16, `shim-ausente:time`×10, `shim-ausente:syscall`×8 (+16) |
| 744 | `github.com/quic-go/quic-go/http3/qlog` | unsupported | `shim-ausente:time`×4, `shim-ausente:context` |
| 745 | `go.opentelemetry.io/otel/baggage` | unsupported | `shim-ausente:context`×3, `shim-ausente:net/url`×3, `shim-ausente:unicode/utf8`×3, `range:func`, `shim-simbolo:errors.join` (+1) |
| 746 | `go.uber.org/dig/internal/digreflect` | unsupported | `shim-ausente:net/url`, `shim-ausente:reflect`, `shim-ausente:runtime`, `shim-simbolo:fmt.State` |
| 747 | `go.uber.org/dig` | unsupported | `shim-ausente:reflect`×54, `shim-ausente:io`×14, `fmt-verbo:%p`×3, `shim-ausente:math/rand`×3, `shim-simbolo:fmt.State`×3 (+8) |
| 748 | `go.uber.org/fx/internal/fxreflect` | unsupported | `shim-ausente:regexp`×2, `shim-ausente:net/url`, `shim-ausente:reflect`, `shim-ausente:runtime`, `shim-simbolo:fmt.State` (+1) |
| 749 | `golang.org/x/crypto/ocsp` | unsupported | `import:_` |
| 750 | `golang.org/x/net/proxy` | unsupported | `shim-ausente:context`×4, `shim-ausente:net/url`×4, `shim-ausente:net`×3, `shim-ausente:sync` |
| 751 | `github.com/pion/ice/v4` | unsupported | `shim-ausente:net`×45, `shim-ausente:time`×11, `shim-ausente:net/netip`×10, `shim-ausente:sync`×5, `shim-ausente:sync/atomic`×4 (+7) |
| 752 | `github.com/libp2p/go-libp2p/p2p/transport/webrtc/udpmux` | unsupported | `shim-ausente:net`×4, `shim-ausente:context`×2, `shim-ausente:log/slog`, `shim-simbolo:strings.cut` |
| 753 | `github.com/pion/webrtc/v4/internal/mux` | unsupported | `shim-ausente:net`×3, `make:chan` |
| 754 | `github.com/pion/webrtc/v4` | unsupported | `shim-ausente:time` |
| 755 | `google.golang.org/grpc/internal/credentials` | unsupported | `shim-ausente:context`×2, `shim-ausente:crypto/tls`×2, `shim-ausente:net`×2, `shim-ausente:crypto/x509` |
| 756 | `google.golang.org/grpc/credentials` | unsupported | `shim-ausente:crypto/tls`×7, `shim-ausente:context`×5, `shim-ausente:crypto/x509`, `shim-ausente:os` |
| 757 | `google.golang.org/grpc/credentials/insecure` | unsupported | `shim-ausente:context` |
| 758 | `google.golang.org/grpc/internal/channelz` | unsupported | `shim-ausente:sync/atomic`×12, `shim-ausente:time`×4, `shim-ausente:net`, `shim-ausente:sync`, `shim-ausente:syscall` |
| 759 | `google.golang.org/grpc/channelz` | bloqueado |  |
| 760 | `google.golang.org/grpc/peer` | unsupported | `shim-ausente:context`×2, `shim-ausente:net` |
| 761 | `google.golang.org/grpc/resolver` | unsupported | `shim-ausente:iter`×2, `generico-nao-struct`, `shim-ausente:encoding/base64`, `shim-ausente:net`, `shim-ausente:net/url` (+1) |
| 762 | `google.golang.org/grpc/balancer` | unsupported | `shim-simbolo:strings.toLower`×2, `shim-ausente:context`, `shim-ausente:encoding/json`, `shim-ausente:net` |
| 763 | `google.golang.org/grpc/balancer/base` | unsupported | `indice:func`×2 |
| 764 | `google.golang.org/grpc/balancer/endpointsharding` | unsupported | `indice:func`, `shim-ausente:math/rand/v2`, `shim-ausente:sync`, `shim-ausente:sync/atomic`, `stmt:GoStmt` |
| 765 | `google.golang.org/grpc/balancer/grpclb/state` | bloqueado | `dart:uri_does_not_exist`×2, `dart:invalid_constant`, `dart:undefined_getter` |
| 766 | `google.golang.org/grpc/experimental/balancer/weight` | bloqueado | `dart:uri_does_not_exist`×2 |
| 767 | `google.golang.org/grpc/balancer/pickfirst` | unsupported | `indice:func`×2, `shim-ausente:net`, `shim-ausente:sync`, `shim-ausente:time` |
| 768 | `google.golang.org/grpc/balancer/roundrobin` | unsupported | `fmt-verbo:%p` |
| 769 | `google.golang.org/grpc/internal/balancer/gracefulswitch` | unsupported | `fmt-verbo:%p`, `shim-ausente:encoding/json`, `shim-ausente:sync` |
| 770 | `google.golang.org/grpc/internal/metadata` | bloqueado | `dart:uri_does_not_exist`×3 |
| 771 | `google.golang.org/grpc/internal/proxyattributes` | unsupported | `shim-ausente:net/url` |
| 772 | `google.golang.org/grpc/internal/resolver/dns` | unsupported | `shim-ausente:time`×4, `shim-ausente:context`×3, `shim-ausente:net`×3, `shim-ausente:encoding/json`×2, `shim-ausente:net/netip`×2 (+1) |
| 773 | `google.golang.org/grpc/internal/resolver/passthrough` | bloqueado | `dart:invalid_constant`, `dart:undefined_getter`, `dart:uri_does_not_exist` |
| 774 | `google.golang.org/grpc/internal/serviceconfig` | unsupported | `shim-ausente:time`×3, `shim-ausente:encoding/json`×2 |
| 775 | `google.golang.org/grpc/internal/resolver` | unsupported | `shim-ausente:context`×3, `shim-ausente:sync` |
| 776 | `google.golang.org/grpc/internal/transport/networktype` | bloqueado | `dart:uri_does_not_exist`×2 |
| 777 | `google.golang.org/grpc/internal/resolver/unix` | bloqueado | `dart:invalid_constant`, `dart:undefined_getter`, `dart:uri_does_not_exist` |
| 778 | `google.golang.org/grpc/resolver/dns` | unsupported | `shim-ausente:time`×2 |
| 779 | `golang.org/x/net/internal/httpcommon` | unsupported | `shim-ausente:net/textproto`×3, `shim-ausente:net/url`×2, `shim-ausente:context`, `shim-ausente:sync`, `shim-simbolo:strings.toLower` |
| 780 | `github.com/cheggaaa/pb/v3` | unsupported | `shim-ausente:time`×7, `shim-ausente:text/template`×5, `shim-ausente:io`×3, `shim-ausente:regexp`×3, `shim-ausente:sync`×3 (+4) |
| 781 | `github.com/whyrusleeping/cbor-gen` | unsupported | `shim-ausente:io`×36, `shim-ausente:reflect`×10, `shim-ausente:sync`×4, `shim-ausente:math/big`, `shim-ausente:time` (+5) |
| 782 | `github.com/ipfs/go-ipld-cbor` | unsupported | `shim-ausente:context`×4, `shim-ausente:io`×3, `shim-ausente:math/big`, `shim-simbolo:bytes.newReader`, `shim-simbolo:strings.trimLeft` |
| 783 | `github.com/ipld/go-car/v2/internal/carv1` | unsupported | `shim-ausente:io`×8, `shim-ausente:context`×5 |
| 784 | `github.com/ipld/go-car/v2` | unsupported | `shim-ausente:io`×13, `shim-ausente:context`×5, `shim-ausente:os`×3, `shim-ausente:io/fs`×2 |
| 785 | `github.com/ipld/go-car/v2/internal/store` | unsupported | `shim-ausente:io`×5 |
| 786 | `github.com/ipld/go-car/v2/storage` | unsupported | `shim-ausente:io`×7, `shim-ausente:context`×2 |
| 787 | `github.com/ipfs/boxo/gateway/assets` | unsupported | `shim-ausente:html/template` |
| 788 | `github.com/caddyserver/zerossl` | unsupported | `shim-ausente:net/http`×2, `shim-ausente:crypto/x509`, `shim-ausente:encoding/base64`, `shim-ausente:time`, `tipo-nomeado:bool` |
| 789 | `github.com/felixge/httpsnoop` | unsupported | `shim-ausente:net/http`×520, `shim-ausente:time`×4, `shim-ausente:io`, `shim-ausente:net`, `tipo:chan` |
| 790 | `github.com/getsentry/sentry-go/internal/ratelimit` | unsupported | `shim-ausente:time`×6, `shim-ausente:net/http`×2, `shim-simbolo:strings.fields` |
| 791 | `github.com/gorilla/mux` | unsupported | `shim-ausente:net/http`×22, `shim-ausente:regexp`×5, `shim-ausente:path`, `shim-simbolo:bytes.indexAny` |
| 792 | `github.com/gorilla/websocket` | unsupported | `shim-ausente:io`×10, `shim-ausente:net/http`×7, `shim-ausente:net`×5, `copy-string`×3, `shim-ausente:net/url`×3 (+13) |
| 793 | `github.com/huin/goupnp/httpu` | unsupported | `shim-ausente:net/http`×6, `shim-ausente:net`×4, `shim-ausente:regexp`×2, `shim-ausente:sync` |
| 794 | `github.com/huin/goupnp/soap` | unsupported | `shim-ausente:regexp`×15, `shim-ausente:time`×11, `shim-ausente:net/url`×4, `shim-simbolo:strconv.formatFloat`×3, `shim-simbolo:strconv.parseFloat`×3 (+6) |
| 795 | `github.com/huin/goupnp/ssdp` | unsupported | `shim-ausente:net/http`×6, `shim-ausente:context`×3, `shim-ausente:regexp`×2, `shim-ausente:net/url`, `shim-ausente:sync` (+2) |
| 796 | `github.com/huin/goupnp` | unsupported | `shim-ausente:net/url`×10, `shim-ausente:context`×7, `shim-ausente:io`×2, `shim-ausente:net/http`×2, `shim-ausente:encoding/xml` (+1) |
| 797 | `github.com/huin/goupnp/dcps/internetgateway1` | unsupported | `shim-ausente:context`×27, `shim-ausente:net/url`×18, `shim-ausente:net`×9 |
| 798 | `github.com/huin/goupnp/dcps/internetgateway2` | unsupported | `shim-ausente:context`×36, `shim-ausente:net/url`×24, `shim-ausente:net`×12 |
| 799 | `github.com/ipfs/boxo/files` | unsupported | `shim-ausente:io/fs`×19, `shim-ausente:io`×9, `shim-ausente:time`×7, `shim-ausente:mime/multipart`×5, `shim-ausente:os`×2 (+9) |
| 800 | `github.com/ipfs/boxo/tar` | unsupported | `shim-ausente:io`×2, `shim-ausente:time` |
| 801 | `github.com/ipfs/kubo/client/rpc/auth` | unsupported | `shim-ausente:net/http`×2 |
| 802 | `github.com/koron/go-ssdp` | unsupported | `shim-ausente:net`×15, `shim-ausente:regexp`×3, `shim-ausente:sync`×2, `shim-ausente:log`, `shim-ausente:net/http` (+3) |
| 803 | `github.com/libp2p/go-libp2p-http` | unsupported | `shim-ausente:io`, `shim-ausente:net/http` |
| 804 | `github.com/libp2p/go-libp2p/p2p/http/auth/internal/handshake` | unsupported | `shim-ausente:time`×5, `shim-ausente:bufio`, `shim-ausente:crypto/rand`, `shim-ausente:io`, `shim-ausente:net/http` (+3) |
| 805 | `github.com/libp2p/go-libp2p/p2p/http/auth` | unsupported | `shim-ausente:net/http`×3, `shim-ausente:time`×3, `shim-ausente:sync`×2, `shim-ausente:crypto/sha256`, `shim-ausente:io` (+1) |
| 806 | `github.com/libp2p/go-libp2p/p2p/http` | unsupported | `shim-ausente:net/http`×6, `shim-ausente:time`×4, `shim-ausente:net`×2, `shim-ausente:net/url`×2, `shim-ausente:sync`×2 (+5) |
| 807 | `github.com/libp2p/go-libp2p/p2p/net/nat/internal/nat` | unsupported | `shim-ausente:context`×11, `shim-ausente:net`×3, `shim-ausente:math/rand`×2, `shim-ausente:log/slog`, `shim-ausente:time` |
| 808 | `github.com/libp2p/go-libp2p/p2p/net/nat` | unsupported | `shim-ausente:time`×4, `shim-ausente:context`×2, `shim-ausente:log/slog`, `shim-ausente:net/netip`, `shim-ausente:sync` |
| 809 | `github.com/libp2p/go-libp2p/p2p/transport/websocket` | unsupported | `shim-ausente:time`×8, `shim-ausente:crypto/tls`×5, `shim-ausente:net`×4, `shim-ausente:net/http`×3, `shim-ausente:net/url`×3 (+3) |
| 810 | `github.com/mholt/acmez/v3/acme` | unsupported | `import:_` |
| 811 | `github.com/mholt/acmez/v3` | unsupported | `shim-ausente:context`×5, `shim-ausente:crypto/x509`×5, `shim-ausente:encoding/asn1`×4, `shim-ausente:time`×2, `shim-ausente:crypto` (+3) |
| 812 | `github.com/opentracing/opentracing-go` | unsupported | `shim-ausente:context`×5, `shim-ausente:time`×5, `shim-ausente:net/http` |
| 813 | `github.com/prometheus/client_golang/internal/github.com/golang/gddo/httputil/header` | unsupported | `shim-ausente:net/http` |
| 814 | `github.com/prometheus/client_golang/internal/github.com/golang/gddo/httputil` | unsupported | `shim-ausente:net/http` |
| 815 | `github.com/prometheus/common/expfmt` | unsupported | `shim-ausente:io`×7, `shim-ausente:net/http`×3, `shim-ausente:bufio`×2, `shim-ausente:sync`×2, `shim-simbolo:strconv.appendFloat`×2 (+8) |
| 816 | `github.com/prometheus/client_golang/prometheus` | unsupported | `shim-ausente:runtime` |
| 817 | `github.com/libp2p/go-libp2p/p2p/metricshelper` | unsupported | `shim-ausente:sync`×2, `shim-simbolo:errors.as` |
| 818 | `github.com/libp2p/go-libp2p/p2p/host/eventbus` | unsupported | `shim-ausente:reflect`×7, `shim-ausente:log/slog`×3, `shim-ausente:sync`×3, `tipo:chan`×3, `len:chan` (+3) |
| 819 | `github.com/libp2p/go-libp2p/p2p/host/autonat` | unsupported | `shim-ausente:time`×10, `shim-ausente:context`×4, `shim-ausente:io`, `shim-ausente:log/slog`, `shim-ausente:net` (+1) |
| 820 | `github.com/libp2p/go-libp2p/p2p/host/blank` | unsupported | `shim-ausente:log/slog`×2, `indice:func` |
| 821 | `github.com/libp2p/go-libp2p/p2p/host/pstoremanager` | unsupported | `shim-ausente:time`×3, `shim-ausente:context`, `shim-ausente:log/slog` |
| 822 | `github.com/libp2p/go-libp2p/p2p/host/resource-manager` | unsupported | `shim-ausente:net/netip`×6, `shim-ausente:encoding/json`×3, `shim-ausente:io`×3, `shim-ausente:log/slog`×3, `shim-ausente:net`×3 (+9) |
| 823 | `github.com/libp2p/go-libp2p/p2p/net/swarm` | unsupported | `shim-ausente:time`×22, `shim-ausente:context`×10, `shim-ausente:sync`×6, `tipo:chan`×5, `shim-ausente:net/netip`×2 (+4) |
| 824 | `github.com/libp2p/go-libp2p/p2p/protocol/autonatv2` | unsupported | `shim-ausente:time`×7, `shim-ausente:context`×2, `shim-ausente:io`×2, `shim-ausente:sync`×2, `shim-ausente:iter` (+4) |
| 825 | `github.com/libp2p/go-libp2p/p2p/protocol/circuitv2/relay` | unsupported | `shim-ausente:time`×9, `shim-ausente:context`×2, `shim-ausente:log/slog`, `shim-ausente:sync` |
| 826 | `github.com/libp2p/go-libp2p/p2p/host/relaysvc` | unsupported | `shim-ausente:context`, `shim-ausente:sync` |
| 827 | `github.com/libp2p/go-libp2p/p2p/protocol/identify` | unsupported | `shim-ausente:time`×4, `shim-ausente:slices`×3, `tipo:chan`×3, `shim-ausente:io`×2, `shim-ausente:context` (+2) |
| 828 | `github.com/libp2p/go-libp2p/p2p/host/autorelay` | unsupported | `shim-ausente:time`×14, `shim-ausente:context`×2, `tipo:chan`×2, `shim-ausente:log/slog`, `shim-ausente:sync` (+1) |
| 829 | `github.com/libp2p/go-libp2p/p2p/protocol/holepunch` | unsupported | `shim-ausente:time`×10, `shim-ausente:context`×5, `shim-ausente:log/slog`, `shim-ausente:slices`, `shim-ausente:sync` |
| 830 | `github.com/libp2p/go-libp2p/p2p/host/basic` | unsupported | `shim-ausente:time`×16, `shim-ausente:context`×9, `shim-ausente:io`×4, `shim-ausente:sync`×4, `shim-ausente:slices`×3 (+4) |
| 831 | `github.com/libp2p/go-libp2p/p2p/host/observedaddrs` | unsupported | `shim-ausente:log/slog`×2, `shim-ausente:time`×2, `make:chan`, `shim-ausente:net`, `shim-ausente:sync` (+1) |
| 832 | `github.com/libp2p/go-libp2p/p2p/transport/quicreuse` | unsupported | `shim-ausente:net`×11, `shim-ausente:context`×7, `shim-ausente:time`×4, `shim-ausente:io`×2, `shim-ausente:sync`×2 (+4) |
| 833 | `github.com/libp2p/go-libp2p/p2p/transport/quic` | unsupported | `shim-ausente:context`×3, `tipo:chan`×3, `shim-ausente:log/slog`×2, `shim-ausente:time`×2, `shim-ausente:sync` (+1) |
| 834 | `github.com/libp2p/go-libp2p/p2p/transport/tcp` | unsupported | `shim-ausente:time`×9, `shim-ausente:net`×5, `shim-ausente:sync`×2, `shim-ausente:context`, `shim-ausente:log/slog` |
| 835 | `github.com/libp2p/go-libp2p/p2p/transport/webrtc` | unsupported | `shim-ausente:time`×8, `shim-ausente:net`×6, `shim-ausente:log/slog`×4, `tipo:chan`×3, `make:chan`×2 (+9) |
| 836 | `github.com/prometheus/client_golang/prometheus/promauto` | bloqueado | `dart:uri_does_not_exist` |
| 837 | `github.com/prometheus/client_golang/prometheus/promhttp` | unsupported | `shim-ausente:net/http` |
| 838 | `github.com/prometheus/statsd_exporter/pkg/mapper` | unsupported | `shim-ausente:regexp`×6, `shim-ausente:time`×3, `shim-ausente:sync`, `shim-simbolo:strings.Builder` |
| 839 | `contrib.go.opencensus.io/exporter/prometheus` | unsupported | `tipo:chan`×2, `shim-ausente:log`, `shim-ausente:net/http`, `shim-ausente:sync` |
| 840 | `github.com/quic-go/quic-go/http3` | unsupported | `shim-ausente:io`×17, `shim-ausente:net/http/httptrace`×14, `shim-ausente:net/http`×11, `shim-ausente:context`×5, `shim-ausente:net`×5 (+15) |
| 841 | `github.com/quic-go/webtransport-go` | unsupported | `shim-ausente:context`×8, `shim-ausente:io`×5, `shim-ausente:sync`×5, `shim-ausente:time`×5, `make:chan`×4 (+8) |
| 842 | `github.com/libp2p/go-libp2p/p2p/transport/webtransport` | unsupported | `shim-ausente:time`×9, `shim-ausente:context`×8, `shim-ausente:crypto/tls`×2, `shim-ausente:log/slog`×2, `shim-ausente:net`×2 (+5) |
| 843 | `github.com/rs/cors` | unsupported | `shim-ausente:net/http`×2, `shim-ausente:log` |
| 844 | `github.com/slok/go-http-metrics/metrics/prometheus` | unsupported | `shim-ausente:context` |
| 845 | `github.com/slok/go-http-metrics/middleware/std` | unsupported | `shim-ausente:net/http`×4 |
| 846 | `go.opencensus.io/trace/propagation` | unsupported | `shim-ausente:net/http` |
| 847 | `go.opencensus.io/plugin/ocgrpc` | unsupported | `shim-ausente:context`×9, `shim-ausente:time`, `shim-simbolo:strings.trimLeft` |
| 848 | `go.opencensus.io/zpages/internal` | unsupported | `shim-ausente:net/http`×4, `literal-composto:pointer`, `shim-ausente:io/ioutil`, `shim-ausente:path`, `shim-ausente:sync` (+1) |
| 849 | `go.opencensus.io/zpages` | unsupported | `shim-ausente:time` |
| 850 | `go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp/internal/request` | unsupported | `shim-ausente:io`×2, `shim-ausente:net/http`×2 |
| 851 | `go.opentelemetry.io/otel/propagation` | unsupported | `shim-ausente:context`×6, `shim-ausente:sync`, `shim-simbolo:strings.cut` |
| 852 | `go.opentelemetry.io/contrib/propagators/b3` | unsupported | `shim-ausente:context`×7 |
| 853 | `go.opentelemetry.io/contrib/propagators/jaeger` | unsupported | `shim-ausente:context`×4 |
| 854 | `go.opentelemetry.io/contrib/propagators/ot` | unsupported | `shim-simbolo:strings.toLower`×2, `shim-ausente:context` |
| 855 | `go.opentelemetry.io/otel/internal/global` | unsupported | `shim-ausente:sync/atomic`×26, `shim-ausente:sync`×5, `shim-ausente:context`, `shim-ausente:log`, `shim-ausente:reflect` |
| 856 | `go.opentelemetry.io/otel` | bloqueado | `dart:uri_does_not_exist`×5 |
| 857 | `github.com/ipfs/boxo/bitswap/client/internal` | unsupported | `shim-ausente:context`×2 |
| 858 | `github.com/ipfs/boxo/bitswap/internal` | unsupported | `shim-ausente:context`×2 |
| 859 | `github.com/ipfs/boxo/blockservice/internal` | unsupported | `shim-ausente:context`×2 |
| 860 | `github.com/libp2p/go-libp2p-kad-dht/internal` | unsupported | `shim-ausente:time`×2, `make:chan`, `shim-ausente:context`, `shim-ausente:unicode/utf8`, `tipo-nomeado:chan` |
| 861 | `github.com/libp2p/go-libp2p-routing-helpers/tracing` | unsupported | `shim-ausente:context` |
| 862 | `go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp/internal/semconv` | unsupported | `shim-ausente:net/http`×3, `shim-ausente:sync`×2, `shim-ausente:time`×2, `shim-simbolo:strings.cut`, `shim-simbolo:strings.lastIndexByte` (+1) |
| 863 | `go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp` | unsupported | `shim-ausente:net/http`×12, `shim-ausente:context`×4, `shim-ausente:io`, `shim-ausente:net/http/httptrace`, `shim-ausente:sync` (+1) |
| 864 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc/internal/envconfig` | unsupported | `shim-ausente:crypto/x509`×2, `shim-ausente:crypto/tls`, `shim-ausente:net/url`, `shim-ausente:time`, `shim-ausente:unicode` (+3) |
| 865 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc/internal/observ` | unsupported | `shim-ausente:sync`×9, `shim-ausente:context`×2, `shim-ausente:net`, `shim-ausente:net/netip`, `shim-simbolo:errors.join` (+1) |
| 866 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp/internal/envconfig` | unsupported | `shim-ausente:crypto/x509`×2, `shim-ausente:crypto/tls`, `shim-ausente:net/url`, `shim-ausente:time`, `shim-ausente:unicode` (+3) |
| 867 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp/internal/observ` | unsupported | `shim-ausente:sync`×9, `shim-ausente:context`×2, `shim-ausente:net`, `shim-ausente:net/netip`, `shim-simbolo:errors.join` |
| 868 | `go.opentelemetry.io/otel/exporters/prometheus/internal/observ` | unsupported | `shim-ausente:sync`×6, `shim-ausente:context`×3, `shim-simbolo:errors.join` |
| 869 | `go.opentelemetry.io/otel/exporters/stdout/stdouttrace/internal/observ` | unsupported | `shim-ausente:sync`×6, `shim-ausente:context`×2, `shim-simbolo:errors.join` |
| 870 | `go.opentelemetry.io/otel/sdk/metric/internal/observ` | unsupported | `shim-ausente:sync`×5, `shim-ausente:context`×2 |
| 871 | `go.opentelemetry.io/otel/sdk/resource` | unsupported | `shim-ausente:context`×15, `shim-ausente:os`×10, `shim-ausente:regexp`×3, `shim-simbolo:strings.trimSpace`×3, `shim-ausente:io`×2 (+8) |
| 872 | `go.opentelemetry.io/otel/sdk/metric/metricdata` | unsupported | `shim-ausente:time`×5, `shim-ausente:encoding/json` |
| 873 | `go.opentelemetry.io/otel/sdk/metric/internal/aggregate` | unsupported | `shim-ausente:time`×12, `shim-ausente:sync/atomic`×7, `shim-ausente:context`×5, `shim-ausente:sync`×5, `generico-nao-struct`×3 (+3) |
| 874 | `go.opentelemetry.io/otel/sdk/metric` | unsupported | `shim-ausente:context`×16, `shim-ausente:time`×8, `shim-ausente:sync/atomic`×5, `shim-simbolo:errors.join`×4, `conversao:nao-basico`×2 (+9) |
| 875 | `go.opentelemetry.io/otel/exporters/prometheus` | unsupported | `tipo:chan`×5, `shim-ausente:sync`×3, `shim-ausente:slices`×2, `shim-ausente:context`, `shim-ausente:encoding/hex` |
| 876 | `go.opentelemetry.io/otel/sdk/trace/internal/env` | unsupported | `shim-ausente:os`×2 |
| 877 | `go.opentelemetry.io/otel/sdk/trace/internal/observ` | unsupported | `shim-ausente:context`×3, `shim-simbolo:errors.join`×2 |
| 878 | `go.opentelemetry.io/otel/sdk/trace` | unsupported | `shim-ausente:time`×9, `shim-ausente:context`×7, `shim-ausente:sync`×5, `shim-ausente:sync/atomic`×2, `tipo:chan`×2 (+4) |
| 879 | `go.opentelemetry.io/contrib/propagators/aws/xray` | unsupported | `shim-ausente:context`, `shim-ausente:crypto/rand`, `shim-ausente:sync`, `shim-ausente:time`, `shim-simbolo:strings.trimSpace` |
| 880 | `go.opentelemetry.io/contrib/propagators/autoprop` | unsupported | `shim-ausente:os`, `shim-ausente:sync` |
| 881 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/internal/tracetransform` | bloqueado | `dart:uri_does_not_exist`×8, `dart:undefined_getter`×3, `dart:prefix_shadowed_by_local_declaration`×2, `dart:prefix_collides_with_top_level_member` |
| 882 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace` | unsupported | `shim-ausente:context`×2, `shim-ausente:sync` |
| 883 | `go.opentelemetry.io/otel/sdk/trace/tracetest` | unsupported | `shim-ausente:sync`×2, `shim-ausente:time`×2, `shim-ausente:context` |
| 884 | `go.opentelemetry.io/otel/exporters/stdout/stdouttrace` | unsupported | `shim-ausente:io`×3, `shim-ausente:os`×3, `shim-ausente:encoding/json`×2, `tipo-nomeado:bool`×2, `shim-ausente:time` |
| 885 | `go.opentelemetry.io/otel/semconv/internal` | unsupported | `shim-ausente:net`, `shim-ausente:net/http` |
| 886 | `go.opentelemetry.io/otel/semconv/v1.4.0` | unsupported | `shim-ausente:net/http`×5 |
| 887 | `go.uber.org/zap` | unsupported | `shim-ausente:time`×13, `generico-nao-struct`×5, `shim-ausente:io`×5, `conversao:nao-basico`×3, `shim-ausente:log`×3 (+11) |
| 888 | `github.com/ipfs/go-log/v2` | unsupported | `shim-ausente:log/slog`×8, `shim-ausente:os`×3, `shim-ausente:context`×2, `shim-ausente:io`×2, `shim-ausente:sync`×2 (+4) |
| 889 | `github.com/ipfs-shipyard/nopfs` | unsupported | `shim-ausente:io`×3, `shim-ausente:os`×2, `shim-ausente:time`×2, `shim-ausente:io/fs`, `shim-ausente:net/url` (+3) |
| 890 | `github.com/ipfs/boxo/autoconf` | unsupported | `shim-ausente:time`×8, `shim-ausente:slices`×4, `shim-ausente:net/http`×3, `shim-simbolo:strings.trimRight`×2, `shim-ausente:context` (+4) |
| 891 | `github.com/ipfs/boxo/bitswap/client/internal/getter` | unsupported | `shim-ausente:context`×4, `tipo:chan` |
| 892 | `github.com/ipfs/boxo/bitswap/client/internal/sessionpeermanager` | unsupported | `shim-ausente:sync` |
| 893 | `github.com/ipfs/boxo/bitswap/network` | unsupported | `shim-ausente:context`×5, `shim-ausente:time`×2, `make:chan`, `shim-ausente:net`, `shim-ausente:net/url` (+1) |
| 894 | `github.com/ipfs/boxo/bitswap/client/internal/messagequeue` | unsupported | `shim-ausente:time`×12, `shim-ausente:context`×6, `shim-ausente:sync/atomic` |
| 895 | `github.com/ipfs/boxo/bitswap/network/bsnet` | unsupported | `shim-ausente:context`×9, `shim-ausente:time`×7, `conversao:nao-basico`, `shim-ausente:sync/atomic` |
| 896 | `github.com/ipfs/boxo/bitswap/network/httpnet` | unsupported | `shim-ausente:context`×14, `shim-ausente:time`×13, `shim-ausente:sync`×4, `shim-simbolo:strings.trimSpace`×2, `make:chan` (+4) |
| 897 | `github.com/ipfs/boxo/bootstrap` | unsupported | `shim-ausente:context`×6, `shim-ausente:time`×2, `shim-ausente:io`, `shim-ausente:math/rand/v2` |
| 898 | `github.com/ipfs/boxo/chunker` | unsupported | `shim-ausente:io`×16, `shim-ausente:sync`, `tipo:chan` |
| 899 | `github.com/ipfs/boxo/ipns` | unsupported | `shim-ausente:time`×6, `shim-simbolo:bytes.Buffer`×2, `shim-simbolo:errors.is$`×2, `shim-ausente:iter`, `shim-simbolo:bytes.Reader` (+3) |
| 900 | `github.com/ipfs/boxo/keystore` | unsupported | `shim-ausente:encoding/base32`×3, `shim-ausente:io/fs`, `shim-ausente:path/filepath`, `shim-simbolo:strings.toUpper` |
| 901 | `github.com/ipfs/boxo/path/resolver` | unsupported | `shim-ausente:context`×5, `range:func` |
| 902 | `github.com/ipfs/boxo/peering` | unsupported | `shim-ausente:sync`×2, `shim-ausente:context`, `shim-ausente:time` |
| 903 | `github.com/ipfs/boxo/bitswap/client/internal/peermanager` | unsupported | `shim-ausente:context`×2, `shim-ausente:sync`×2 |
| 904 | `github.com/ipfs/boxo/bitswap/client/internal/session` | unsupported | `shim-ausente:context`×4, `shim-ausente:time`×3, `shim-ausente:math/rand/v2` |
| 905 | `github.com/ipfs/boxo/bitswap/client/internal/sessionmanager` | unsupported | `shim-ausente:context`×2, `shim-ausente:sync` |
| 906 | `github.com/ipfs/boxo/routing/http/filters` | unsupported | `shim-ausente:net/url`, `shim-ausente:reflect`, `shim-ausente:slices`, `shim-simbolo:strings.equalFold`, `shim-simbolo:strings.toLower` |
| 907 | `github.com/ipfs/boxo/routing/http/server` | unsupported | `shim-ausente:time`×10, `shim-ausente:net/http`×8, `shim-ausente:context`, `shim-ausente:sync/atomic`, `shim-simbolo:errors.join` |
| 908 | `github.com/ipfs/boxo/routing/providerquerymanager` | unsupported | `shim-ausente:context`×8, `shim-ausente:time`×2, `make:chan`, `shim-ausente:sync`, `tipo:chan` |
| 909 | `github.com/ipfs/go-ds-flatfs` | unsupported | `shim-ausente:os`×10, `shim-ausente:time`×6, `shim-ausente:path/filepath`×4, `shim-ausente:io/fs`×3, `shim-ausente:sync`×3 (+7) |
| 910 | `github.com/ipfs/go-dsqueue` | unsupported | `shim-ausente:time`×5, `shim-ausente:context`×2, `shim-ausente:encoding/base64`×2, `tipo:chan` |
| 911 | `github.com/ipfs/boxo/provider` | unsupported | `shim-ausente:context`×13, `shim-ausente:time`×6, `tipo:chan` |
| 912 | `github.com/ipfs/boxo/blockstore` | unsupported | `shim-ausente:context`×16, `shim-ausente:sync`×3, `shim-ausente:sync/atomic`, `tipo-nomeado:bool` |
| 913 | `github.com/ipfs/boxo/bitswap/client` | unsupported | `shim-ausente:time`×3, `shim-ausente:context`×2 |
| 914 | `github.com/ipfs/boxo/bitswap/server/internal/decision` | unsupported | `shim-ausente:time`×5, `tipo:chan`×3, `make:chan`×2, `shim-ausente:context`, `shim-ausente:hash/maphash` (+1) |
| 915 | `github.com/ipfs/boxo/bitswap/server` | unsupported | `shim-ausente:context`, `shim-ausente:sync` |
| 916 | `github.com/ipfs/boxo/bitswap` | unsupported | `shim-ausente:context`×3, `shim-ausente:time`×2 |
| 917 | `github.com/ipfs/boxo/blockservice` | unsupported | `shim-ausente:context`×10, `shim-ausente:io`, `shim-ausente:sync` |
| 918 | `github.com/ipfs/boxo/exchange/offline` | unsupported | `shim-ausente:context` |
| 919 | `github.com/ipfs/boxo/fetcher/impl/blockservice` | unsupported | `shim-ausente:context`×3 |
| 920 | `github.com/ipfs/boxo/filestore` | unsupported | `shim-ausente:context`×10, `shim-ausente:os`×2, `shim-ausente:io` |
| 921 | `github.com/ipfs/boxo/ipld/merkledag` | unsupported | `import:_` |
| 922 | `github.com/ipfs/boxo/ipld/merkledag/dagutils` | unsupported | `shim-ausente:context`×6 |
| 923 | `github.com/ipfs/boxo/ipld/merkledag/test` | unsupported | `shim-ausente:context` |
| 924 | `github.com/ipfs/boxo/ipld/unixfs` | unsupported | `shim-ausente:io/fs`×7 |
| 925 | `github.com/ipfs/boxo/dag/walker` | unsupported | `shim-ausente:context`×9, `shim-ausente:crypto/rand`, `shim-simbolo:bytes.Reader`, `shim-simbolo:math.log2` |
| 926 | `github.com/ipfs/boxo/ipld/unixfs/hamt` | unsupported | `shim-ausente:context`×2, `shim-ausente:hash`, `shim-ausente:io/fs`, `shim-ausente:slices` |
| 927 | `github.com/ipfs/boxo/ipld/unixfs/importer/helpers` | unsupported | `shim-ausente:io/fs`×3 |
| 928 | `github.com/ipfs/boxo/ipld/unixfs/importer/balanced` | bloqueado | `dart:uri_does_not_exist`×3 |
| 929 | `github.com/ipfs/boxo/ipld/unixfs/importer/trickle` | unsupported | `shim-ausente:context`×4 |
| 930 | `github.com/ipfs/boxo/ipld/unixfs/io` | unsupported | `shim-ausente:context`×5, `shim-ausente:io/fs`×5, `shim-ausente:io`, `shim-simbolo:bytes.Reader` |
| 931 | `github.com/ipfs/boxo/ipld/unixfs/file` | unsupported | `shim-ausente:context`×5 |
| 932 | `github.com/ipfs/boxo/ipld/unixfs/mod` | unsupported | `shim-ausente:context`×3 |
| 933 | `github.com/ipfs/boxo/mfs` | unsupported | `shim-ausente:time`×10, `shim-ausente:context`×8, `shim-ausente:io/fs`×4, `shim-ausente:sync`×3, `shim-ausente:path`×2 (+4) |
| 934 | `github.com/ipfs/boxo/pinning/pinner/dspinner` | unsupported | `shim-ausente:context`×8, `shim-ausente:path`×3, `shim-ausente:sync`, `tipo:chan` |
| 935 | `github.com/ipfs/go-fs-lock` | unsupported | `shim-ausente:context`, `shim-ausente:io`, `shim-ausente:os`, `shim-ausente:path/filepath`, `shim-ausente:syscall` |
| 936 | `github.com/ipfs/go-ipfs-cmds` | unsupported | `shim-ausente:io`×16, `shim-ausente:reflect`×16, `tipo:chan`×4, `shim-ausente:context`×3, `make:chan`×2 (+6) |
| 937 | `github.com/ipfs/go-ipfs-cmds/cli` | unsupported | `shim-ausente:io`×8, `shim-ausente:os`×4, `shim-ausente:reflect`×4, `shim-ausente:text/template`×3, `shim-ausente:context`×2 (+8) |
| 938 | `github.com/ipfs/go-ipfs-cmds/http` | unsupported | `shim-ausente:net/http`×20, `shim-ausente:io`×2, `shim-ausente:net/url`, `shim-ausente:sync`, `tipo:chan` |
| 939 | `github.com/ipfs/go-metrics-prometheus` | unsupported | `shim-simbolo:strings.replace`, `tipo:chan` |
| 940 | `github.com/ipfs/kubo/blocks/blockstoreutil` | unsupported | `shim-ausente:context`×2 |
| 941 | `github.com/ipfs/kubo/cmd/ipfs/util` | unsupported | `make:chan`, `shim-ausente:context`, `shim-ausente:os`, `shim-ausente:syscall`, `tipo:chan` |
| 942 | `github.com/ipfs/kubo/core/commands/keyencode` | bloqueado | `dart:uri_does_not_exist`×3 |
| 943 | `github.com/ipfs/kubo/core/shutdown` | unsupported | `shim-ausente:time`×2, `shim-ausente:context`, `shim-ausente:sync/atomic` |
| 944 | `github.com/ipfs/kubo/fuse/mount` | unsupported | `shim-ausente:io/fs`×4, `shim-ausente:sync`×2, `shim-ausente:time`×2, `make:chan`, `operador-unario:<-` (+5) |
| 945 | `github.com/ipfs/kubo/fuse/writable` | unsupported | `shim-ausente:sync`×3, `shim-ausente:sync/atomic`×3, `shim-ausente:context` |
| 946 | `github.com/ipfs/kubo/gc` | unsupported | `shim-ausente:context`×3 |
| 947 | `github.com/ipfs/kubo/p2p` | unsupported | `shim-ausente:context`×2, `shim-ausente:sync`×2, `stmt:GoStmt`×2, `tipo:chan`×2 |
| 948 | `github.com/ipfs/kubo/thirdparty/verifbs` | unsupported | `shim-ausente:context`×2 |
| 949 | `github.com/libp2p/go-doh-resolver` | unsupported | `shim-ausente:time`×5, `shim-ausente:context`×4, `shim-ausente:net`×2, `shim-ausente:sync` |
| 950 | `github.com/libp2p/go-libp2p-kad-dht/pb` | unsupported | `shim-ausente:context`×3, `tipo-basico:Pointer`×2, `shim-ausente:reflect`, `shim-ausente:sync` |
| 951 | `github.com/libp2p/go-libp2p-kad-dht/internal/metrics` | unsupported | `shim-ausente:context`×11 |
| 952 | `github.com/libp2p/go-libp2p-kad-dht/internal/net` | unsupported | `shim-ausente:bufio`×2, `shim-ausente:sync`×2, `shim-ausente:time`×2, `shim-ausente:io`, `zero-value:chan` |
| 953 | `github.com/libp2p/go-libp2p-kad-dht/records` | unsupported | `shim-ausente:time`×13, `shim-ausente:context`, `shim-ausente:io`, `shim-ausente:maps`, `shim-ausente:sync` |
| 954 | `github.com/ipfs/boxo/routing/offline` | unsupported | `shim-ausente:time`×2 |
| 955 | `github.com/libp2p/go-libp2p-kbucket/peerdiversity` | unsupported | `shim-ausente:net`×2, `shim-ausente:sync` |
| 956 | `github.com/libp2p/go-libp2p-kad-dht/internal/config` | unsupported | `shim-ausente:time`×2 |
| 957 | `github.com/libp2p/go-libp2p-kbucket` | unsupported | `shim-ausente:container/list`×3, `shim-ausente:time`×2, `shim-ausente:context`, `shim-ausente:crypto/rand` |
| 958 | `github.com/libp2p/go-libp2p-kad-dht/crawler` | unsupported | `shim-ausente:time`×6, `shim-ausente:context`×2, `shim-ausente:sync`×2, `shim-ausente:slices` |
| 959 | `github.com/libp2p/go-libp2p-kad-dht/netsize` | unsupported | `shim-ausente:time`×3, `shim-ausente:math/big`×2, `shim-ausente:sync`, `shim-simbolo:strings.repeat` |
| 960 | `github.com/libp2p/go-libp2p-kad-dht/provider/internal/keyspace` | unsupported | `range:func`×4, `shim-ausente:iter`×4, `expr:IndexListExpr`×3, `shim-ausente:crypto/sha256`×2, `shim-ausente:cmp` (+1) |
| 961 | `github.com/libp2p/go-libp2p-kad-dht/provider/internal/queue` | unsupported | `expr:IndexListExpr`×2, `shim-ausente:sync`×2, `shim-ausente:slices` |
| 962 | `github.com/libp2p/go-libp2p-kad-dht/provider/internal/timeseries` | unsupported | `shim-ausente:time`×8, `shim-ausente:sync` |
| 963 | `github.com/libp2p/go-libp2p-kad-dht/provider/keystore` | unsupported | `shim-ausente:context`×5, `make:chan`, `shim-ausente:sync/atomic`, `shim-ausente:time`, `shim-simbolo:strings.Builder` (+1) |
| 964 | `github.com/libp2p/go-libp2p-kad-dht/provider` | unsupported | `shim-ausente:time`×13, `shim-ausente:context`×4, `shim-ausente:sync/atomic`×2, `shim-simbolo:errors.join`, `tipo:chan` |
| 965 | `github.com/libp2p/go-libp2p-kad-dht/provider/buffered` | unsupported | `shim-ausente:time`×4, `make:chan`, `shim-ausente:sync` |
| 966 | `github.com/libp2p/go-libp2p-kad-dht/rtrefresh` | unsupported | `shim-ausente:context`×2, `shim-ausente:time`, `tipo:chan` |
| 967 | `github.com/libp2p/go-libp2p-kad-dht` | unsupported | `shim-ausente:sync` |
| 968 | `github.com/ipfs/boxo/namesys` | unsupported | `shim-ausente:context`×19, `shim-ausente:time`×16, `expr:IndexListExpr`, `shim-ausente:os`, `shim-ausente:sync` |
| 969 | `github.com/ipfs-shipyard/nopfs/ipfs` | unsupported | `shim-ausente:context`×3 |
| 970 | `github.com/ipfs/boxo/namesys/republisher` | unsupported | `shim-ausente:time`×3, `shim-ausente:context` |
| 971 | `github.com/ipfs/kubo/core/coreiface/options` | unsupported | `shim-ausente:time`×4, `tipo:chan`×2, `zero-value:chan` |
| 972 | `github.com/ipfs/kubo/core/coreiface` | unsupported | `shim-ausente:context`×13, `shim-ausente:io`×2, `shim-ausente:io/fs`×2, `shim-ausente:time` |
| 973 | `github.com/ipfs/kubo/core/commands/cmdutils` | unsupported | `shim-ausente:slices`, `shim-ausente:unicode` |
| 974 | `github.com/ipfs/kubo` | unsupported | `shim-ausente:runtime`, `shim-ausente:runtime/debug`, `shim-simbolo:strings.trim` |
| 975 | `github.com/ipfs/kubo/profile` | unsupported | `shim-ausente:context`×13, `shim-ausente:time`×2, `shim-ausente:archive/zip`, `shim-ausente:io`, `shim-simbolo:bytes.Buffer` |
| 976 | `github.com/libp2p/go-libp2p-pubsub-router` | unsupported | `shim-ausente:context`×8, `shim-ausente:time`×2, `shim-ausente:encoding/base64`, `tipo:chan` |
| 977 | `github.com/libp2p/go-libp2p-routing-helpers` | unsupported | `shim-ausente:context`×17, `shim-ausente:time`×2, `shim-ausente:sync` |
| 978 | `github.com/ipfs/boxo/gateway` | unsupported | `import:_` |
| 979 | `github.com/ipfs/boxo/routing/http/contentrouter` | unsupported | `shim-ausente:context`×4, `shim-ausente:time` |
| 980 | `github.com/ipfs/boxo/routing/http/client` | unsupported | `shim-ausente:net/http`×5, `shim-ausente:context`×2, `shim-ausente:io`×2, `shim-ausente:slices`×2, `shim-ausente:reflect` (+4) |
| 981 | `github.com/libp2p/go-libp2p-kad-dht/dual` | unsupported | `shim-simbolo:errors.join`×2, `shim-ausente:context` |
| 982 | `github.com/libp2p/go-libp2p-kad-dht/provider/dual` | unsupported | `shim-ausente:time`×26, `make:chan`, `shim-ausente:context` |
| 983 | `github.com/libp2p/go-libp2p-xor/key` | unsupported | `shim-ausente:math/big`×2 |
| 984 | `github.com/libp2p/go-libp2p-xor/trie` | unsupported | `shim-ausente:encoding/json` |
| 985 | `github.com/libp2p/go-libp2p-xor/kademlia` | unsupported | `shim-ausente:encoding/json`×2 |
| 986 | `github.com/libp2p/go-libp2p-kad-dht/fullrt` | unsupported | `shim-ausente:time`×5, `shim-ausente:context`, `tipo:chan` |
| 987 | `github.com/libp2p/go-socket-activation` | unsupported | `shim-ausente:os`×3, `shim-ausente:sync` |
| 988 | `go.uber.org/fx/fxevent` | unsupported | `shim-ausente:log/slog`×5, `shim-ausente:time`×3, `shim-ausente:io`, `shim-ausente:os`, `shim-simbolo:strings.toUpper` |
| 989 | `go.uber.org/fx/internal/fxlog` | unsupported | `shim-ausente:io`, `shim-ausente:reflect`, `shim-ausente:sync` |
| 990 | `go.uber.org/fx/internal/lifecycle` | unsupported | `shim-ausente:reflect`×5, `shim-ausente:context`×2, `constraint`, `shim-ausente:sync`, `shim-simbolo:strings.Builder` |
| 991 | `go.uber.org/fx` | unsupported | `shim-ausente:reflect`×37, `shim-ausente:time`×7, `shim-ausente:context`×5, `constraint`×3, `shim-ausente:io`×2 (+7) |
| 992 | `github.com/ipfs/kubo/core/node/helpers` | unsupported | `shim-ausente:context`, `shim-ausente:time` |
| 993 | `github.com/libp2p/go-libp2p/config` | unsupported | `shim-ausente:crypto/sha256`×2, `shim-ausente:time`×2, `tipo:chan`×2, `shim-ausente:log/slog` |
| 994 | `github.com/libp2p/go-libp2p` | unsupported | `shim-ausente:crypto/rand`×2, `shim-ausente:time`×2, `shim-ausente:reflect`, `shim-ausente:sync` |
| 995 | `go.uber.org/zap/exp/zapslog` | unsupported | `shim-ausente:log/slog`×6 |
| 996 | `github.com/caddyserver/certmagic` | unsupported | `shim-ausente:context`×38, `shim-ausente:time`×31, `shim-ausente:sync`×10, `shim-ausente:crypto/tls`×9, `shim-ausente:net`×9 (+21) |
| 997 | `golang.org/x/net/http2` | unsupported | `shim-ausente:net/http`×36, `shim-ausente:sync`×20, `shim-ausente:io`×15, `shim-ausente:net`×12, `shim-ausente:time`×8 (+23) |
| 998 | `golang.org/x/net/trace` | unsupported | `shim-ausente:time`×10, `shim-ausente:sync`×9, `shim-ausente:html/template`×7, `shim-ausente:net/http`×7, `stmt:SelectStmt`×4 (+6) |
| 999 | `github.com/dgraph-io/badger/y` | unsupported | `shim-ausente:os`×7, `make:chan`×3, `shim-ausente:log`×3, `tipo:chan`×3, `shim-ausente:expvar`×2 (+4) |
| 1000 | `github.com/dgraph-io/badger/skl` | unsupported | `shim-ausente:sync/atomic`×3 |
| 1001 | `github.com/dgraph-io/badger/table` | unsupported | `shim-ausente:io`×2, `shim-simbolo:bytes.Buffer`×2, `shim-ausente:os`, `shim-ausente:path`, `shim-ausente:path/filepath` (+1) |
| 1002 | `github.com/dgraph-io/badger` | unsupported | `shim-ausente:sync`×17, `shim-ausente:os`×9, `shim-ausente:time`×4, `tipo:chan`×3, `shim-ausente:bufio`×2 (+10) |
| 1003 | `github.com/ipfs/go-ds-badger` | unsupported | `shim-ausente:time`×4, `shim-ausente:context`×2, `shim-ausente:sync` |
| 1004 | `golang.org/x/oauth2/internal` | unsupported | `shim-ausente:context`×3, `shim-ausente:net/url`×2, `shim-ausente:time`×2, `shim-ausente:crypto/rsa`, `shim-ausente:encoding/json` (+3) |
| 1005 | `golang.org/x/oauth2` | unsupported | `shim-ausente:time`×8, `shim-ausente:context`×7, `shim-ausente:net/url`×3, `shim-ausente:net/http`×2, `shim-ausente:sync`×2 (+2) |
| 1006 | `github.com/ipshipyard/p2p-forge/client` | unsupported | `shim-ausente:context`×10, `shim-ausente:net/http`×5, `shim-ausente:time`×5, `shim-ausente:crypto/x509`×2, `shim-ausente:net`×2 (+3) |
| 1007 | `github.com/getsentry/sentry-go/internal/debug` | unsupported | `shim-ausente:net/http` |
| 1008 | `github.com/getsentry/sentry-go` | unsupported | `shim-ausente:time`×26, `shim-ausente:context`×10, `shim-ausente:sync`×10, `shim-ausente:encoding/json`×7, `shim-ausente:net/http`×6 (+17) |
| 1009 | `github.com/cockroachdb/errors/withstack` | unsupported | `shim-simbolo:strings.trimSpace`×3, `shim-simbolo:fmt.State`×2, `shim-ausente:go/build`, `shim-ausente:runtime`, `shim-simbolo:strings.replace` |
| 1010 | `github.com/cockroachdb/errors/errutil` | unsupported | `shim-ausente:context`×7, `shim-ausente:reflect`×3, `shim-simbolo:fmt.State`×3, `conversao:nao-basico` |
| 1011 | `github.com/cockroachdb/errors/report` | unsupported | `shim-simbolo:bytes.Buffer`, `shim-simbolo:strings.Builder`, `shim-simbolo:strings.lastIndexByte` |
| 1012 | `github.com/cockroachdb/errors` | unsupported | `shim-ausente:context`×9, `shim-simbolo:fmt.Formatter`, `shim-simbolo:fmt.State` |
| 1013 | `github.com/cockroachdb/errors/oserror` | unsupported | `shim-ausente:os`×9 |
| 1014 | `github.com/cockroachdb/pebble/v2/internal/dsl` | unsupported | `shim-ausente:go/token`×5, `generico-nao-struct`×3, `conversao:nao-basico`×2, `indice:func`, `shim-ausente:go/scanner` (+1) |
| 1015 | `github.com/cockroachdb/pebble/v2/vfs` | unsupported | `shim-ausente:sync` |
| 1016 | `github.com/cockroachdb/pebble/v2/internal/base` | unsupported | `shim-ausente:sync` |
| 1017 | `github.com/cockroachdb/pebble/v2/batchrepr` | unsupported | `tipo-basico:Pointer` |
| 1018 | `github.com/cockroachdb/pebble/v2/bloom` | unsupported | `shim-ausente:sync`×2, `tipo-nomeado:array` |
| 1019 | `github.com/cockroachdb/pebble/v2/internal/arenaskl` | unsupported | `shim-ausente:sync/atomic`×3, `shim-ausente:context`×2, `shim-ausente:sync`×2, `tipo-basico:Pointer` |
| 1020 | `github.com/cockroachdb/pebble/v2/internal/batchskl` | unsupported | `shim-ausente:math/rand/v2` |
| 1021 | `github.com/cockroachdb/pebble/v2/internal/cache` | unsupported | `shim-ausente:sync` |
| 1022 | `github.com/cockroachdb/pebble/v2/internal/compression` | unsupported | `shim-ausente:sync`×4, `shim-ausente:math/rand/v2`, `shim-simbolo:encoding/binary.putUvarint`, `shim-simbolo:encoding/binary.uvarint` |
| 1023 | `github.com/cockroachdb/pebble/v2/internal/invalidating` | unsupported | `shim-ausente:slices` |
| 1024 | `github.com/cockroachdb/pebble/v2/internal/keyspan` | unsupported | `shim-ausente:context`×12, `shim-ausente:io`×5, `shim-ausente:slices`×4, `shim-ausente:cmp`×2, `fmt-verbo:%p` (+6) |
| 1025 | `github.com/cockroachdb/pebble/v2/internal/private` | bloqueado | `dart:uri_does_not_exist`×2 |
| 1026 | `github.com/cockroachdb/pebble/v2/internal/problemspans` | unsupported | `shim-ausente:sync/atomic`, `shim-ausente:time` |
| 1027 | `github.com/cockroachdb/pebble/v2/internal/rangedel` | bloqueado | `dart:uri_does_not_exist`×2 |
| 1028 | `github.com/cockroachdb/pebble/v2/internal/rangekey` | unsupported | `shim-simbolo:encoding/binary.putUvarint`×4, `shim-simbolo:encoding/binary.uvarint`×2, `shim-ausente:slices` |
| 1029 | `github.com/cockroachdb/pebble/v2/internal/sstableinternal` | bloqueado | `dart:uri_does_not_exist`×2 |
| 1030 | `github.com/cockroachdb/pebble/v2/internal/strparse` | unsupported | `shim-ausente:regexp`, `shim-simbolo:strings.fields` |
| 1031 | `github.com/cockroachdb/pebble/v2/internal/testkeys` | unsupported | `shim-ausente:regexp`×3, `shim-simbolo:bytes.trimSuffix`×3, `branch:goto`, `shim-ausente:math/rand/v2`, `shim-simbolo:strconv.appendInt` |
| 1032 | `github.com/cockroachdb/pebble/v2/objstorage/remote` | unsupported | `shim-ausente:sync` |
| 1033 | `github.com/cockroachdb/pebble/v2/objstorage/objstorageprovider/sharedcache` | unsupported | `shim-ausente:sync` |
| 1034 | `github.com/cockroachdb/pebble/v2/objstorage` | unsupported | `shim-ausente:context`×5, `shim-simbolo:bytes.Buffer`×2 |
| 1035 | `github.com/cockroachdb/pebble/v2/objstorage/objstorageprovider/objiotracing` | unsupported | `shim-ausente:context`×4 |
| 1036 | `github.com/cockroachdb/pebble/v2/record` | unsupported | `shim-ausente:io`×7, `shim-ausente:sync`×5, `shim-ausente:sync/atomic`×3, `shim-ausente:runtime/pprof`×2, `shim-ausente:time`×2 (+1) |
| 1037 | `github.com/cockroachdb/pebble/v2/sstable/virtual` | bloqueado | `dart:uri_does_not_exist` |
| 1038 | `github.com/cockroachdb/pebble/v2/vfs/atomicfs` | bloqueado | `dart:uri_does_not_exist`×3 |
| 1039 | `github.com/cockroachdb/pebble/v2/objstorage/objstorageprovider/remoteobjcat` | unsupported | `shim-ausente:sync` |
| 1040 | `github.com/cockroachdb/pebble/v2/objstorage/objstorageprovider` | unsupported | `shim-ausente:sync` |
| 1041 | `github.com/cockroachdb/pebble/v2/sstable/block` | unsupported | `shim-ausente:sync` |
| 1042 | `github.com/cockroachdb/pebble/v2/sstable/colblk` | unsupported | `tipo-basico:Pointer`×25, `shim-ausente:io`×7, `builtin:None`×4, `constraint`×3, `indice:func`×3 (+13) |
| 1043 | `github.com/cockroachdb/pebble/v2/sstable/blob` | unsupported | `shim-ausente:sync` |
| 1044 | `github.com/cockroachdb/pebble/v2/internal/blobtest` | unsupported | `shim-ausente:context`, `shim-ausente:math/rand/v2` |
| 1045 | `github.com/cockroachdb/pebble/v2/sstable/rowblk` | unsupported | `tipo-basico:Pointer`×3, `shim-ausente:sync`×2, `builtin:None`, `shim-ausente:context`, `shim-ausente:io` (+1) |
| 1046 | `github.com/cockroachdb/pebble/v2/sstable/valblk` | unsupported | `shim-ausente:context`×3, `tipo-basico:Pointer`×3, `shim-ausente:sync`×2, `shim-simbolo:encoding/binary.putUvarint` |
| 1047 | `github.com/cockroachdb/pebble/v2/sstable` | unsupported | `shim-ausente:sync` |
| 1048 | `github.com/cockroachdb/pebble/v2/internal/manifest` | unsupported | `shim-ausente:container/heap` |
| 1049 | `github.com/cockroachdb/pebble/v2/internal/compact` | unsupported | `shim-ausente:io`×2, `shim-ausente:slices`×2, `shim-ausente:time`×2, `shim-simbolo:bytes.Buffer`, `shim-simbolo:strings.Builder` (+1) |
| 1050 | `github.com/cockroachdb/pebble/v2/internal/keyspan/keyspanimpl` | unsupported | `shim-ausente:context`×4, `shim-simbolo:bytes.Buffer` |
| 1051 | `github.com/cockroachdb/pebble/v2/internal/overlap` | unsupported | `shim-ausente:context`×2, `tipo-nomeado:array` |
| 1052 | `github.com/cockroachdb/pebble/v2/internal/rangekeystack` | bloqueado | `dart:uri_does_not_exist`×4, `dart:invalid_constant`×2, `dart:undefined_getter`×2 |
| 1053 | `github.com/cockroachdb/pebble/v2/rangekey` | bloqueado | `dart:uri_does_not_exist`×3 |
| 1054 | `github.com/cockroachdb/pebble/v2/wal` | unsupported | `shim-ausente:sync` |
| 1055 | `github.com/cockroachdb/pebble/v2` | unsupported | `shim-ausente:sync` |
| 1056 | `github.com/ipfs/boxo/pinning/remote/client/openapi` | unsupported | `shim-ausente:encoding/json`×18, `shim-ausente:context`×10, `shim-ausente:net/http`×7, `shim-ausente:time`×5, `shim-ausente:regexp`×3 (+5) |
| 1057 | `github.com/ipfs/boxo/pinning/remote/client` | unsupported | `shim-ausente:encoding/json`×3, `shim-ausente:time`×3, `shim-ausente:context`, `shim-ausente:net/http`, `shim-ausente:slices` |
| 1058 | `github.com/ipfs/go-ds-pebble` | unsupported | `make:chan`, `shim-ausente:context`, `tipo:chan` |
| 1059 | `github.com/ipfs/kubo/config` | unsupported | `shim-ausente:time`×13, `shim-ausente:encoding/json`×9, `tipo-nomeado:bool`×4, `shim-ausente:path/filepath`×3, `shim-ausente:encoding/base64`×2 (+14) |
| 1060 | `github.com/ipfs/kubo/config/serialize` | unsupported | `shim-ausente:io`, `shim-ausente:os`, `shim-ausente:path/filepath` |
| 1061 | `github.com/ipfs/kubo/repo` | unsupported | `shim-ausente:context`×3, `shim-ausente:io`, `shim-ausente:sync` |
| 1062 | `github.com/ipfs/kubo/repo/fsrepo/migrations/fs-repo-16-to-17/migration` | unsupported | `shim-ausente:io`, `shim-ausente:slices` |
| 1063 | `github.com/ipfs/kubo/repo/fsrepo/migrations` | unsupported | `shim-ausente:context`×14, `shim-ausente:os`×4, `shim-ausente:io`×3, `shim-ausente:net/http`×2, `shim-ausente:path/filepath`×2 (+6) |
| 1064 | `github.com/ipfs/kubo/repo/fsrepo` | unsupported | `shim-ausente:path/filepath`×3, `shim-ausente:os`×2, `shim-ausente:encoding/json`, `shim-ausente:io`, `shim-ausente:io/fs` (+2) |
| 1065 | `github.com/ipfs/kubo/routing` | unsupported | `shim-ausente:context`×3, `shim-ausente:encoding/base64`, `shim-ausente:net/http`, `shim-ausente:time` |
| 1066 | `github.com/ipfs/kubo/core/node/libp2p` | unsupported | `shim-ausente:context`×9, `shim-ausente:time`×8, `shim-ausente:net`×6, `shim-ausente:os`×6, `conversao:nao-basico`×2 (+10) |
| 1067 | `github.com/ipfs/kubo/core/node` | unsupported | `shim-ausente:context`×29, `shim-ausente:time`×13, `shim-ausente:encoding/base32`×3, `shim-ausente:crypto/rand`, `shim-ausente:io` (+2) |
| 1068 | `github.com/ipfs/kubo/core` | unsupported | `shim-ausente:context`×2, `shim-ausente:io`, `shim-ausente:reflect` |
| 1069 | `github.com/ipfs/kubo/core/corerepo` | unsupported | `shim-ausente:context`×8, `shim-simbolo:bytes.Buffer` |
| 1070 | `github.com/ipfs/kubo/fuse/mfs` | unsupported | `shim-ausente:time`×2, `shim-ausente:os` |
| 1071 | `github.com/ipfs/kubo/fuse/readonly` | unsupported | `shim-ausente:context`×3, `shim-ausente:time`×2, `shim-ausente:os`, `shim-ausente:sync` |
| 1072 | `github.com/ipfs/kubo/plugin` | bloqueado | `dart:uri_does_not_exist`×5 |
| 1073 | `github.com/ipfs/kubo/plugin/plugins/badgerds` | unsupported | `shim-ausente:os` |
| 1074 | `github.com/ipfs/kubo/plugin/plugins/dagjose` | bloqueado | `dart:uri_does_not_exist`×2 |
| 1075 | `github.com/ipfs/kubo/plugin/plugins/flatfs` | unsupported | `shim-ausente:path/filepath` |
| 1076 | `github.com/ipfs/kubo/plugin/plugins/fxtest` | unsupported | `shim-ausente:os` |
| 1077 | `github.com/ipfs/kubo/plugin/plugins/git` | unsupported | `shim-ausente:io` |
| 1078 | `github.com/ipfs/kubo/plugin/plugins/levelds` | unsupported | `shim-ausente:path/filepath` |
| 1079 | `github.com/ipfs/kubo/plugin/plugins/nopfs` | unsupported | `shim-ausente:os`, `shim-ausente:path/filepath` |
| 1080 | `github.com/ipfs/kubo/plugin/plugins/pebbleds` | unsupported | `shim-ausente:path/filepath`, `shim-ausente:time` |
| 1081 | `github.com/ipfs/kubo/plugin/plugins/peerlog` | unsupported | `tipo:chan` |
| 1082 | `github.com/ipfs/kubo/plugin/plugins/telemetry` | unsupported | `shim-ausente:time`×5, `shim-ausente:os`×3, `shim-ausente:sync` |
| 1083 | `google.golang.org/grpc/internal/transport` | unsupported | `shim-ausente:context`×15, `shim-ausente:time`×10, `tipo:chan`×9, `shim-ausente:io`×6, `shim-ausente:net`×4 (+9) |
| 1084 | `google.golang.org/grpc/internal/resolver/delegatingresolver` | unsupported | `shim-ausente:net/url`×5, `shim-ausente:net`, `shim-ausente:net/http` |
| 1085 | `google.golang.org/grpc` | unsupported | `import:_` |
| 1086 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc/internal/otlpconfig` | unsupported | `shim-ausente:crypto/tls`×4, `shim-ausente:net/url`×4, `shim-ausente:time`×4, `shim-ausente:net/http`, `shim-ausente:os` (+1) |
| 1087 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp/internal/otlpconfig` | unsupported | `shim-ausente:crypto/tls`×4, `shim-ausente:net/url`×4, `shim-ausente:time`×4, `shim-ausente:net/http`, `shim-ausente:os` (+1) |
| 1088 | `google.golang.org/grpc/health/grpc_health_v1` | unsupported | `shim-ausente:context`×6, `tipo-basico:Pointer`×4, `builtin:None`, `shim-ausente:reflect`, `shim-ausente:sync` |
| 1089 | `github.com/grpc-ecosystem/grpc-gateway/v2/runtime` | unsupported | `shim-ausente:context`×30, `shim-ausente:net/http`×9, `shim-ausente:reflect`×8, `shim-ausente:time`×5, `shim-ausente:encoding/json`×4 (+14) |
| 1090 | `go.opentelemetry.io/proto/otlp/collector/trace/v1` | unsupported | `shim-ausente:context`×12, `tipo-basico:Pointer`×3, `shim-ausente:reflect`, `shim-ausente:sync` |
| 1091 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc` | unsupported | `shim-ausente:time`×7, `shim-ausente:context`×2, `conversao:nao-basico` |
| 1092 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp/internal/otlpjson` | unsupported | `shim-ausente:encoding/json`×4, `tipo-nomeado:array`×2, `shim-simbolo:strconv.appendFloat` |
| 1093 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp` | unsupported | `shim-ausente:net/http`×7, `shim-ausente:time`×5, `shim-ausente:io`×3, `conversao:nao-basico`, `shim-ausente:context` (+3) |
| 1094 | `github.com/ipfs/boxo/tracing` | unsupported | `shim-ausente:context`, `shim-ausente:io/fs`, `shim-ausente:os` |
| 1095 | `github.com/ipfs/kubo/tracing` | unsupported | `shim-ausente:context`×4 |
| 1096 | `github.com/ipfs/kubo/core/coreunix` | unsupported | `shim-ausente:context`×2, `shim-ausente:io`, `shim-ausente:time`, `tipo:chan` |
| 1097 | `github.com/ipfs/kubo/core/coreapi` | unsupported | `shim-ausente:context`×15, `shim-ausente:time` |
| 1098 | `github.com/ipfs/kubo/assets` | unsupported | `shim-ausente:path`×2, `shim-ausente:embed` |
| 1099 | `github.com/ipfs/kubo/fuse/ipns` | unsupported | `shim-ausente:context`×7, `shim-ausente:time`×2, `shim-ausente:os` |
| 1100 | `github.com/ipfs/kubo/fuse/node` | unsupported | `shim-simbolo:strings.replaceAll` |
| 1101 | `github.com/ipfs/kubo/plugin/loader` | unsupported | `shim-ausente:os`×3, `shim-ausente:io` |
| 1102 | `github.com/ipfs/kubo/commands` | unsupported | `shim-ausente:context`, `shim-ausente:sync`, `shim-ausente:time` |
| 1103 | `github.com/ipfs/kubo/core/commands/cmdenv` | unsupported | `shim-ausente:context`×3, `shim-ausente:os`×2, `shim-simbolo:strconv.isPrint`, `shim-simbolo:strconv.quote` |
| 1104 | `github.com/ipfs/kubo/core/commands/dag` | unsupported | `import:_` |
| 1105 | `github.com/ipfs/kubo/core/commands/name` | unsupported | `shim-ausente:io`×4, `shim-ausente:time`×3, `shim-simbolo:bytes.Buffer`, `shim-simbolo:bytes.Reader` |
| 1106 | `github.com/ipfs/kubo/core/commands/object` | unsupported | `shim-ausente:io`×3 |
| 1107 | `github.com/ipfs/kubo/core/commands/pin` | unsupported | `shim-ausente:context`×7, `shim-ausente:io`×5, `make:chan`×2, `shim-ausente:net/url`, `tipo:chan` |
| 1108 | `github.com/ipfs/kubo/core/commands` | unsupported | `shim-ausente:io`×76, `shim-ausente:context`×37, `shim-ausente:time`×21, `shim-ausente:os`×13, `shim-ausente:path`×10 (+36) |
| 1109 | `github.com/ipfs/kubo/core/corehttp` | unsupported | `shim-ausente:net`×21, `shim-ausente:net/http`×9, `shim-ausente:time`×3, `shim-ausente:context`×2, `tipo:chan`×2 (+3) |
| 1110 | `github.com/ipfs/kubo/repo/fsrepo/migrations/ipfsfetcher` | unsupported | `shim-ausente:context`, `shim-ausente:net/url`, `shim-ausente:os`, `shim-ausente:sync` |
| 1111 | `github.com/ipfs/kubo/cmd/ipfs/kubo` | unsupported | `import:_` |
| 1112 | `github.com/ipfs/kubo/cmd/ipfs` | unsupported | `shim-ausente:os` |
