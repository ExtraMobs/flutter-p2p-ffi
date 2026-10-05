# Auditoria do grafo real

Gerado por `python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo`. **Não edite**: rode o comando de novo.

- Alvo: `github.com/ipfs/kubo/cmd/ipfs` (`github.com/ipfs/kubo` v0.43.1), 1112 pacotes fora da stdlib.
- Contexto: go1.26.5, `CGO_ENABLED=0 GOARCH=amd64 GOFLAGS=-tags=purego,noasm GOOS=linux`.
- Ocorrência = declaração de nível de pacote que falha (o primeiro problema dela);
  do `dart analyze`, cada diagnóstico. Pacote bloqueado não conta no ranking.

## Resumo

| status | pacotes | % |
|---|---:|---:|
| verde | 177 | 15.9 |
| dart-invalido | 5 | 0.4 |
| bloqueado | 257 | 23.1 |
| unsupported | 666 | 59.9 |
| substituicao | 7 | 0.6 |

**Verde: 177 de 1112 (15.9%).**

## Ranking de códigos

Ordem: pacotes da fronteira afetados, pacotes afetados, ocorrências.

| código | ocorrências | pacotes | na fronteira | exemplo |
|---|---:|---:|---:|---|
| `shim-ausente:net` | 860 | 140 | 19 | `github.com/coreos/go-systemd/v22/daemon` sdnotify.go:56:6: pacote sem shim/transpilação: net |
| `shim-ausente:net/http` | 956 | 65 | 14 | `github.com/caddyserver/zerossl` client.go:132:1: pacote sem shim/transpilação: net/http |
| `unsafe:Pointer` | 405 | 81 | 12 | `github.com/cockroachdb/pebble/v2/internal/rawalloc` rawalloc.go:21:6: unsafe.Pointer (sem memória crua fora do dart:ffi) |
| `shim-ausente:log` | 78 | 33 | 11 | `github.com/AndreasBriese/bbloom` bbloom.go:64:6: pacote sem shim/transpilação: log |
| `shim-ausente:hash` | 85 | 28 | 11 | `github.com/spaolacci/murmur3` murmur128.go:23:1: pacote sem shim/transpilação: hash |
| `shim-ausente:slices` | 179 | 85 | 10 | `golang.org/x/exp/slices` slices.go:20:6: pacote sem shim/transpilação: slices |
| `shim-ausente:runtime` | 72 | 41 | 10 | `github.com/cockroachdb/pebble/v2/internal/invariants` invariants.go:40:6: pacote sem shim/transpilação: runtime |
| `branch:goto` | 74 | 28 | 10 | `gonum.org/v1/gonum/mathext/internal/cephes` hyp2f1.go:106:4: goto |
| `shim-ausente:encoding/hex` | 58 | 26 | 10 | `github.com/dunglas/httpsfv` displaystring.go:11:1: pacote sem shim/transpilação: encoding/hex |
| `shim-ausente:net/url` | 177 | 53 | 9 | `github.com/cockroachdb/pebble/v2/internal/lsmview` url.go:17:6: pacote sem shim/transpilação: net/url |
| `shim-ausente:encoding/base64` | 52 | 28 | 9 | `github.com/dunglas/httpsfv` binary.go:14:6: pacote sem shim/transpilação: encoding/base64 |
| `shim-ausente:bufio` | 76 | 32 | 8 | `github.com/anmitsu/go-shlex` shlex.go:52:1: pacote sem shim/transpilação: bufio |
| `async:contexto-sincrono` | 157 | 63 | 7 | `github.com/benbjohnson/clock` context.go:85:79: chamada que suspende num contexto que não pode suspender (contexto-sincrono) |
| `async:shim-sincrono` | 92 | 38 | 7 | `github.com/anmitsu/go-shlex` shlex.go:64:20: NewReader do shim chamaria Read de forma síncrona, mas o argumento suspende |
| `shim-ausente:math/big` | 91 | 18 | 7 | `github.com/dustin/go-humanize` big.go:8:6: pacote sem shim/transpilação: math/big |
| `conversao:pointer-pointer` | 192 | 41 | 5 | `github.com/spaolacci/murmur3` murmur64.go:34:11: conversão pointer → pointer |
| `shim-ausente:path/filepath` | 62 | 39 | 5 | `github.com/caddyserver/certmagic/internal/atomicfile` file.go:76:6: pacote sem shim/transpilação: path/filepath |
| `shim-ausente:crypto/rand` | 41 | 30 | 5 | `github.com/flynn/noise` cipher_suite.go:105:1: pacote sem shim/transpilação: crypto/rand |
| `shim-ausente:iter` | 37 | 20 | 5 | `github.com/cockroachdb/pebble/v2/sstable/block/blockkind` kind.go:46:6: pacote sem shim/transpilação: iter |
| `shim-ausente:hash/crc32` | 33 | 12 | 5 | `github.com/cockroachdb/pebble/v2/internal/crc` crc.go:21:1: pacote sem shim/transpilação: hash/crc32 |
| `shim-ausente:log/slog` | 192 | 51 | 4 | `github.com/go-logr/logr` context_slog.go:28:6: pacote sem shim/transpilação: log/slog |
| `shim-ausente:syscall` | 177 | 35 | 4 | `github.com/pbnjay/memory` memory_linux.go:7:6: pacote sem shim/transpilação: syscall |
| `shim-ausente:math/rand/v2` | 27 | 24 | 4 | `google.golang.org/grpc/balancer/pickfirst/internal` internal.go:28:2: pacote sem shim/transpilação: math/rand/v2 |
| `shim-simbolo:os.open` | 36 | 22 | 4 | `github.com/prometheus/procfs/internal/util` readfile.go:26:6: símbolo sem shim: os.open |
| `shim-ausente:runtime/debug` | 28 | 22 | 4 | `github.com/ipfs/boxo/util` util.go:34:6: pacote sem shim/transpilação: runtime/debug |
| `shim-ausente:crypto/x509` | 60 | 20 | 4 | `github.com/libp2p/go-libp2p/core/crypto` ecdsa.go:76:6: pacote sem shim/transpilação: crypto/x509 |
| `shim-ausente:crypto` | 52 | 15 | 4 | `golang.org/x/crypto/blake2s` blake2s.go:59:6: pacote sem shim/transpilação: crypto |
| `construtor-ambiguo` | 13 | 7 | 4 | `github.com/cenkalti/backoff/v4` ticker.go:13:1: parâmetro de construtor ambíguo para campo c |
| `unsafe:Slice` | 62 | 30 | 3 | `filippo.io/bigmod` nat_noasm.go:12:19: unsafe.Slice (sem memória crua fora do dart:ffi) |
| `shim-ausente:crypto/sha256` | 20 | 16 | 3 | `github.com/multiformats/go-multihash/register/sha256` sha256.go:19:6: pacote sem shim/transpilação: crypto/sha256 |
| `shim-simbolo:os.stat` | 20 | 16 | 3 | `github.com/ipfs/kubo/misc/fsutil` fsutil.go:13:6: símbolo sem shim: os.stat |
| `shim-simbolo:strings.splitSeq` | 13 | 10 | 3 | `github.com/klauspost/cpuid/v2` cpuid.go:478:6: símbolo sem shim: strings.splitSeq |
| `shim-ausente:container/list` | 18 | 9 | 3 | `github.com/golang/groupcache/lru` lru.go:23:1: pacote sem shim/transpilação: container/list |
| `shim-ausente:crypto/cipher` | 30 | 7 | 3 | `github.com/davidlazar/go-crypto/salsa20` salsa20.go:20:6: pacote sem shim/transpilação: crypto/cipher |
| `shim-simbolo:io/fs.DirEntry` | 6 | 5 | 3 | `github.com/facebookgo/atomicfile` atomicfile.go:15:1: símbolo sem shim: io/fs.DirEntry |
| `shim-ausente:database/sql/driver` | 4 | 3 | 3 | `github.com/blang/semver/v4` semver.go:24:1: pacote sem shim/transpilação: database/sql/driver |
| `tipo-nomeado:pointer` | 3 | 3 | 3 | `github.com/klauspost/cpuid/v2` cpuid.go:553:6: tipo nomeado sobre pointer |
| `shim-ausente:crypto/tls` | 108 | 29 | 2 | `github.com/coreos/go-systemd/v22/activation` listeners.go:58:6: pacote sem shim/transpilação: crypto/tls |
| `shim-ausente:path` | 45 | 24 | 2 | `github.com/ipfs/go-datastore/query` query_impl.go:111:6: pacote sem shim/transpilação: path |
| `shim-ausente:cmp` | 35 | 24 | 2 | `go.opentelemetry.io/auto/sdk/internal/telemetry` value.go:290:6: pacote sem shim/transpilação: cmp |
| `shim-ausente:math/rand` | 49 | 23 | 2 | `github.com/cenkalti/backoff/v4` exponential.go:54:1: pacote sem shim/transpilação: math/rand |
| `shim-ausente:maps` | 23 | 20 | 2 | `github.com/guillaumemichel/reservedpool` pool.go:14:1: pacote sem shim/transpilação: maps |
| `shim-simbolo:os.readFile` | 18 | 14 | 2 | `github.com/crackcomm/go-gitignore` ignore.go:173:6: símbolo sem shim: os.readFile |
| `range:pointer` | 7 | 6 | 2 | `github.com/klauspost/compress/huff0` build_table.go:107:2: range sobre pointer |
| `func-sem-corpo` | 7 | 5 | 2 | `github.com/cockroachdb/pebble/v2/internal/rawalloc` rawalloc_go1.9.go:27:6: função sem corpo (assembly ou go:linkname): substituição |
| `shim-ausente:io/ioutil` | 5 | 5 | 2 | `github.com/minio/sha256-simd` cpuid_other.go:31:6: pacote sem shim/transpilação: io/ioutil |
| `shim-ausente:unicode/utf16` | 5 | 5 | 2 | `github.com/go-jose/go-jose/v4/json` decode.go:1104:6: pacote sem shim/transpilação: unicode/utf16 |
| `shim-ausente:encoding/xml` | 7 | 4 | 2 | `github.com/huin/goupnp/scpd` scpd.go:20:1: pacote sem shim/transpilação: encoding/xml |
| `shim-simbolo:fmt.sscanf` | 6 | 4 | 2 | `github.com/syndtr/goleveldb/leveldb/storage` file_storage.go:649:6: símbolo sem shim: fmt.sscanf |
| `unsafe:String` | 5 | 4 | 2 | `go.opentelemetry.io/auto/sdk/internal/telemetry` value.go:140:10: unsafe.String (sem memória crua fora do dart:ffi) |
| `shim-ausente:crypto/md5` | 4 | 4 | 2 | `github.com/multiformats/go-multihash/core` registry.go:112:6: pacote sem shim/transpilação: crypto/md5 |
| `shim-ausente:crypto/sha1` | 4 | 4 | 2 | `github.com/pion/stun/v3/internal/hmac` pool.go:40:5: pacote sem shim/transpilação: crypto/sha1 |
| `shim-ausente:crypto/ecdh` | 4 | 3 | 2 | `golang.org/x/crypto/curve25519` curve25519.go:38:6: pacote sem shim/transpilação: crypto/ecdh |
| `shim-ausente:flag` | 3 | 3 | 2 | `github.com/grpc-ecosystem/grpc-gateway/v2/utilities` string_array_flag.go:9:1: pacote sem shim/transpilação: flag |
| `conversao:pointer-named-pointer` | 8 | 2 | 2 | `go.opentelemetry.io/auto/sdk/internal/telemetry` value.go:84:8: conversão pointer → named-pointer |
| `dart:invalid_assignment` | 4 | 2 | 2 | `github.com/cockroachdb/crlib/fifo` 385:19: error: A value of type 'Ptr<$_semaWaiter>?' can't be assigned to a variable of type '$_semaWaiter?'. |
| `dart:return_of_invalid_type` | 2 | 2 | 2 | `github.com/pion/transport/v3/deadline` 262:8: error: A value of type 'Timer' can't be returned from the function '_afterFunc' because it has a return type of '$_timer?'. |
| `go:embed` | 2 | 2 | 2 | `google.golang.org/protobuf/internal/editiondefaults` defaults.go:9:8: //go:embed (import _ embed) |
| `async:valor-func` | 94 | 61 | 1 | `github.com/ipfs/go-datastore/query` query_impl.go:21:10: função que suspende usada como valor de uma assinatura que precisa ficar síncrona |
| `shim-ausente:net/netip` | 52 | 17 | 1 | `github.com/libdns/libdns` record.go:39:1: pacote sem shim/transpilação: net/netip |
| `shim-simbolo:os.openFile` | 15 | 10 | 1 | `github.com/syndtr/goleveldb/leveldb/storage` file_storage.go:53:6: símbolo sem shim: os.openFile |
| `shim-ausente:container/heap` | 8 | 7 | 1 | `github.com/ipfs/go-ipfs-pq` pq.go:35:6: pacote sem shim/transpilação: container/heap |
| `shim-simbolo:os.Signal` | 11 | 6 | 1 | `github.com/cheggaaa/pb/v3/termutil` term.go:56:6: símbolo sem shim: os.Signal |
| `shim-simbolo:os.lstat` | 6 | 6 | 1 | `github.com/ipfs/kubo/misc/fsutil` fsutil.go:79:6: símbolo sem shim: os.lstat |
| `shim-ausente:os/exec` | 14 | 5 | 1 | `golang.org/x/sys/execabs` execabs.go:54:6: pacote sem shim/transpilação: os/exec |
| `shim-simbolo:os.executable` | 5 | 5 | 1 | `google.golang.org/protobuf/internal/detrand` rand.go:40:6: símbolo sem shim: os.executable |
| `shim-simbolo:os.getuid` | 5 | 5 | 1 | `github.com/google/uuid` dce.go:46:6: símbolo sem shim: os.getuid |
| `shim-ausente:encoding/asn1` | 11 | 4 | 1 | `golang.org/x/crypto/cryptobyte` asn1.go:163:6: pacote sem shim/transpilação: encoding/asn1 |
| `shim-ausente:crypto/rsa` | 6 | 4 | 1 | `filippo.io/keygen` rsa.go:30:6: pacote sem shim/transpilação: crypto/rsa |
| `shim-simbolo:os.SyscallError` | 5 | 4 | 1 | `github.com/syndtr/goleveldb/leveldb/storage` file_storage_unix.go:67:6: símbolo sem shim: os.SyscallError |
| `shim-ausente:runtime/pprof` | 13 | 3 | 1 | `go.opencensus.io/tag` profile_19.go:25:6: pacote sem shim/transpilação: runtime/pprof |
| `shim-ausente:crypto/ecdsa` | 8 | 3 | 1 | `github.com/decred/dcrd/dcrec/secp256k1/v4` privkey.go:16:1: pacote sem shim/transpilação: crypto/ecdsa |
| `shim-ausente:crypto/elliptic` | 7 | 3 | 1 | `filippo.io/keygen` ecdsa.go:32:6: pacote sem shim/transpilação: crypto/elliptic |
| `shim-simbolo:fmt.appendf` | 5 | 3 | 1 | `go.opentelemetry.io/otel/codes` codes.go:36:1: símbolo sem shim: fmt.appendf |
| `shim-simbolo:os.remove` | 4 | 3 | 1 | `github.com/caddyserver/certmagic/internal/atomicfile` file.go:69:1: símbolo sem shim: os.remove |
| `shim-simbolo:os.rename` | 3 | 3 | 1 | `github.com/syndtr/goleveldb/leveldb/storage` file_storage_unix.go:63:6: símbolo sem shim: os.rename |
| `shim-ausente:math/cmplx` | 9 | 2 | 1 | `gonum.org/v1/gonum/mathext/internal/amos` amos.go:31:6: pacote sem shim/transpilação: math/cmplx |
| `shim-ausente:os/user` | 3 | 2 | 1 | `github.com/hanwen/go-fuse/v2/internal` access.go:14:6: pacote sem shim/transpilação: os/user |
| `shim-ausente:text/tabwriter` | 3 | 2 | 1 | `github.com/kr/pretty` formatter.go:14:1: pacote sem shim/transpilação: text/tabwriter |
| `len:typeparam` | 2 | 2 | 1 | `go.uber.org/zap/zapcore` json_encoder.go:526:18: len de typeparam |
| `shim-simbolo:os.unsetenv` | 2 | 2 | 1 | `github.com/coreos/go-systemd/v22/daemon` watchdog.go:36:6: símbolo sem shim: os.unsetenv |
| `builtin:print` | 1 | 1 | 1 | `github.com/gogo/protobuf/proto` properties.go:441:4: builtin print |
| `builtin:println` | 1 | 1 | 1 | `golang.org/x/exp/mmap` mmap_unix.go:51:3: builtin println |
| `conversao:slice-typeparam` | 1 | 1 | 1 | `github.com/multiformats/go-multistream` multistream.go:263:9: conversão slice → typeparam |
| `conversao:typeparam-slice` | 1 | 1 | 1 | `github.com/multiformats/go-multistream` client.go:139:33: conversão typeparam → slice |
| `dart:argument_type_not_assignable` | 1 | 1 | 1 | `github.com/polydawn/refmt/shared` 112:30: error: The argument type 'Buffer' can't be assigned to the parameter type '$_readerScanner?'.  |
| `shim-ausente:crypto/fips140` | 1 | 1 | 1 | `golang.org/x/crypto/chacha20poly1305` fips140only_go1.26.go:11:6: pacote sem shim/transpilação: crypto/fips140 |
| `shim-simbolo:os.getgid` | 1 | 1 | 1 | `github.com/google/uuid` dce.go:54:6: símbolo sem shim: os.getgid |
| `shim-simbolo:os.interrupt` | 1 | 1 | 1 | `github.com/cheggaaa/pb/v3/termutil` term_x.go:17:2: símbolo sem shim: os.interrupt |
| `shim-simbolo:os.userHomeDir` | 1 | 1 | 1 | `github.com/ipfs/kubo/misc/fsutil` fsutil.go:57:6: símbolo sem shim: os.userHomeDir |
| `shim-simbolo:reflect.Value.unsafeAddr` | 1 | 1 | 1 | `github.com/kr/pretty` diff.go:108:17: membro sem shim: reflect.Value.unsafeAddr (UnsafeAddr) |
| `promocao:nao-exportada` | 156 | 24 | 0 | `go.opentelemetry.io/otel/metric/noop` noop.go:48:1: método não exportado meterProvider promovido de go.opentelemetry.io/otel/metric/embedded.MeterProvider (interface ou genérico, sem mixin) |
| `shim-simbolo:io/fs.FileInfo` | 30 | 9 | 0 | `github.com/ipfs/boxo/filestore/posinfo` posinfo.go:12:1: símbolo sem shim: io/fs.FileInfo |
| `shim-ausente:compress/gzip` | 13 | 8 | 0 | `google.golang.org/protobuf/internal/impl` legacy_file.go:43:6: pacote sem shim/transpilação: compress/gzip |
| `shim-ausente:net/textproto` | 12 | 6 | 0 | `golang.org/x/net/http/httpguts` guts.go:20:6: pacote sem shim/transpilação: net/textproto |
| `conversao:slice-named-slice` | 11 | 5 | 0 | `github.com/mgutz/ansi` print.go:32:12: conversão slice → named-slice |
| `shim-simbolo:os.create` | 6 | 5 | 0 | `github.com/ipld/go-car/v2` selective.go:68:6: símbolo sem shim: os.create |
| `shim-ausente:encoding/base32` | 19 | 4 | 0 | `github.com/miekg/dns` msg_helpers.go:142:1: pacote sem shim/transpilação: encoding/base32 |
| `shim-ausente:text/template` | 12 | 4 | 0 | `github.com/cheggaaa/pb/v3` pb.go:89:1: pacote sem shim/transpilação: text/template |
| `shim-ausente:crypto/aes` | 8 | 4 | 0 | `github.com/flynn/noise` cipher_suite.go:140:6: pacote sem shim/transpilação: crypto/aes |
| `shim-ausente:net/http/httptrace` | 22 | 3 | 0 | `github.com/quic-go/quic-go/http3` stream.go:54:6: pacote sem shim/transpilação: net/http/httptrace |
| `shim-ausente:html/template` | 11 | 3 | 0 | `github.com/ipfs/boxo/gateway/assets` : pacote sem shim/transpilação: html/template |
| `shim-ausente:go/token` | 8 | 3 | 0 | `google.golang.org/protobuf/internal/strs` strings.go:71:6: pacote sem shim/transpilação: go/token |
| `generico:ptr-valor` | 6 | 3 | 0 | `github.com/cockroachdb/pebble/v2/internal/cache` block_map.go:42:30: *T de genérico instanciado com struct/array (ou *N com métodos) dentro de tipo composto |
| `shim-ausente:archive/zip` | 4 | 3 | 0 | `github.com/ipfs/kubo/profile` profile.go:117:6: pacote sem shim/transpilação: archive/zip |
| `shim-simbolo:os.mkdir` | 4 | 3 | 0 | `github.com/ipfs/boxo/keystore` keystore.go:49:6: símbolo sem shim: os.mkdir |
| `opassign-impuro` | 3 | 3 | 0 | `github.com/pion/interceptor/pkg/nack` receive_log.go:128:2: &^= sobre alvo com efeito (avaliado duas vezes) |
| `shim-ausente:encoding/pem` | 3 | 3 | 0 | `github.com/caddyserver/certmagic` ocsp.go:47:6: pacote sem shim/transpilação: encoding/pem |
| `shim-simbolo:os.File.stat` | 3 | 3 | 0 | `github.com/ipfs/go-ipfs-cmds/cli` parse.go:596:16: membro sem shim: os.File.stat (Stat) |
| `shim-simbolo:os.File.sync` | 3 | 3 | 0 | `github.com/ipfs/go-ds-flatfs` sync.go:41:9: membro sem shim: os.File.sync (Sync) |
| `shim-simbolo:os.hostname` | 3 | 3 | 0 | `google.golang.org/grpc/internal/resolver/dns` dns_resolver.go:445:6: símbolo sem shim: os.hostname |
| `shim-simbolo:os.writeFile` | 3 | 3 | 0 | `github.com/ipfs/boxo/autoconf` client.go:22:6: símbolo sem shim: os.writeFile |
| `tipo-nomeado:chan` | 3 | 3 | 0 | `github.com/libp2p/go-libp2p-kad-dht/internal` ctx_mutex.go:7:6: tipo nomeado sobre chan |
| `shim-ausente:testing` | 8 | 2 | 0 | `github.com/ipfs/kubo/repo/fsrepo/migrations/common` testing_helpers.go:28:6: pacote sem shim/transpilação: testing |
| `shim-ausente:mime/multipart` | 7 | 2 | 0 | `github.com/ipfs/boxo/files` multifilereader.go:45:6: pacote sem shim/transpilação: mime/multipart |
| `shim-simbolo:encoding/binary.NativeEndian._littleEndian` | 5 | 2 | 0 | `golang.org/x/net/ipv6` control_rfc3542_unix.go:24:3: membro sem shim: encoding/binary.NativeEndian._littleEndian (littleEndian) |
| `conversao:pointer-typeparam` | 4 | 2 | 0 | `google.golang.org/protobuf/proto` wrapperopaque.go:68:10: conversão pointer → typeparam |
| `shim-simbolo:os.LinkError` | 4 | 2 | 0 | `github.com/cockroachdb/errors/errbase` adapters.go:114:6: símbolo sem shim: os.LinkError |
| `conversao:named-slice-slice` | 3 | 2 | 0 | `github.com/ipfs/boxo/routing/http/types` record_bitswap.go:116:24: conversão named-slice → slice |
| `shim-ausente:crypto/ed25519` | 3 | 2 | 0 | `github.com/libp2p/go-libp2p/core/crypto` ed25519.go:16:1: pacote sem shim/transpilação: crypto/ed25519 |
| `shim-ausente:expvar` | 3 | 2 | 0 | `github.com/dgraph-io/badger/y` metrics.go:21:1: pacote sem shim/transpilação: expvar |
| `shim-simbolo:os.getpagesize` | 3 | 2 | 0 | `github.com/hanwen/go-fuse/v2/fuse` bufferpool.go:24:5: símbolo sem shim: os.getpagesize |
| `shim-ausente:archive/tar` | 2 | 2 | 0 | `github.com/ipfs/boxo/files` tarwriter.go:15:1: pacote sem shim/transpilação: archive/tar |
| `shim-ausente:crypto/x509/pkix` | 2 | 2 | 0 | `github.com/caddyserver/certmagic` config.go:1385:2: pacote sem shim/transpilação: crypto/x509/pkix |
| `shim-ausente:go/build` | 2 | 2 | 0 | `github.com/getsentry/sentry-go` stacktrace.go:333:5: pacote sem shim/transpilação: go/build |
| `shim-ausente:hash/fnv` | 2 | 2 | 0 | `github.com/ipfs/boxo/chunker` rabin.go:31:6: pacote sem shim/transpilação: hash/fnv |
| `shim-simbolo:os.File.readAt` | 2 | 2 | 0 | `github.com/ipfs/boxo/filestore` filereader.go:23:9: membro sem shim: os.File.readAt (ReadAt) |
| `shim-simbolo:os.createTemp` | 2 | 2 | 0 | `github.com/ipfs/go-ds-flatfs` util_unix.go:9:6: símbolo sem shim: os.createTemp |
| `shim-simbolo:os.newSyscallError` | 2 | 2 | 0 | `github.com/cockroachdb/errors/errbase` adapters.go:151:6: símbolo sem shim: os.newSyscallError |
| `shim-simbolo:os.readDir` | 2 | 2 | 0 | `github.com/prometheus/procfs` net_dev_snmp6.go:45:6: símbolo sem shim: os.readDir |
| `shim-simbolo:strconv.NumError` | 2 | 2 | 0 | `github.com/polydawn/refmt/json` jsonDecoder.go:17:1: símbolo sem shim: strconv.NumError |
| `shim-ausente:crypto/sha3` | 9 | 1 | 0 | `golang.org/x/crypto/sha3` hashes.go:66:6: pacote sem shim/transpilação: crypto/sha3 |
| `shim-ausente:compress/flate` | 3 | 1 | 0 | `github.com/gorilla/websocket` compression.go:48:6: pacote sem shim/transpilação: compress/flate |
| `shim-ausente:hash/maphash` | 3 | 1 | 0 | `github.com/ipfs/boxo/bitswap/server/internal/decision` scheduler.go:34:1: pacote sem shim/transpilação: hash/maphash |
| `shim-ausente:mime` | 3 | 1 | 0 | `github.com/gabriel-vasile/mimetype` mime.go:14:1: pacote sem shim/transpilação: mime |
| `constraint:ponteiro` | 2 | 1 | 0 | `github.com/quic-go/webtransport-go` streams_map_incoming.go:57:1: constraint com ponteiro e métodos próprios (sem interface Dart comum) |
| `conversao:chan-chan` | 2 | 1 | 0 | `github.com/ipfs/go-ipfs-cmds` chan.go:125:7: conversão chan → chan |
| `conversao:slice-named-array-pointer` | 2 | 1 | 0 | `github.com/cockroachdb/pebble/v2/sstable/block` buffer_pool.go:48:9: conversão slice → ponteiro para array nomeado |
| `layout:typeparam` | 2 | 1 | 0 | `github.com/RaduBerinde/axisds/regiontree` region_tree.go:49:1: layout de typeparam |
| `shim-ausente:container/ring` | 2 | 1 | 0 | `github.com/getsentry/sentry-go` profiler.go:70:1: pacote sem shim/transpilação: container/ring |
| `shim-ausente:weak` | 2 | 1 | 0 | `github.com/klauspost/compress/zstd` simple_go124.go:16:1: pacote sem shim/transpilação: weak |
| `for-multi-atribuicao` | 1 | 1 | 0 | `github.com/miekg/dns` dnssec_keyscan.go:156:29: cláusula de for com múltiplas atribuições |
| `indice:typeparam` | 1 | 1 | 0 | `github.com/miekg/dns` msg.go:555:6: índice sobre typeparam |
| `min:typeparam` | 1 | 1 | 0 | `github.com/cockroachdb/pebble/v2/sstable/colblk` uints.go:472:13: min de typeparam |
| `shim-ausente:crypto/hmac` | 1 | 1 | 0 | `github.com/pion/dtls/v3/pkg/crypto/prf` prf.go:159:6: pacote sem shim/transpilação: crypto/hmac |
| `shim-ausente:crypto/sha512` | 1 | 1 | 0 | `github.com/flynn/noise` cipher_suite.go:202:5: pacote sem shim/transpilação: crypto/sha512 |
| `shim-ausente:embed` | 1 | 1 | 0 | `github.com/ipfs/kubo/assets` assets.go:16:1: pacote sem shim/transpilação: embed |
| `shim-ausente:encoding/gob` | 1 | 1 | 0 | `github.com/pion/dtls/v3` state.go:21:1: pacote sem shim/transpilação: encoding/gob |
| `shim-ausente:go/format` | 1 | 1 | 0 | `github.com/ipld/go-ipld-prime/node/bindnode` generate.go:116:6: pacote sem shim/transpilação: go/format |
| `shim-ausente:os/signal` | 1 | 1 | 0 | `go.uber.org/fx` signal.go:47:6: pacote sem shim/transpilação: os/signal |
| `shim-ausente:runtime/metrics` | 1 | 1 | 0 | `github.com/prometheus/client_golang/prometheus/internal` go_runtime_metrics.go:39:6: pacote sem shim/transpilação: runtime/metrics |
| `shim-ausente:runtime/trace` | 1 | 1 | 0 | `go.opencensus.io/trace` trace_go11.go:25:6: pacote sem shim/transpilação: runtime/trace |
| `shim-simbolo:fmt.append$` | 1 | 1 | 0 | `github.com/ipfs/boxo/ipns` record.go:619:6: símbolo sem shim: fmt.append$ |
| `shim-simbolo:fmt.scanf` | 1 | 1 | 0 | `github.com/ipfs/kubo/cmd/ipfs/kubo` daemon.go:1356:6: símbolo sem shim: fmt.scanf |
| `shim-simbolo:io/fs.FS` | 1 | 1 | 0 | `github.com/miekg/dns` scan.go:168:1: símbolo sem shim: io/fs.FS |
| `shim-simbolo:os.File.truncate` | 1 | 1 | 0 | `github.com/dgraph-io/badger/table` table.go:95:13: membro sem shim: os.File.truncate (Truncate) |
| `shim-simbolo:os.chmod` | 1 | 1 | 0 | `github.com/ipfs/boxo/files` meta_posix.go:14:6: símbolo sem shim: os.chmod |
| `shim-simbolo:os.environ` | 1 | 1 | 0 | `github.com/getsentry/sentry-go` integrations.go:380:6: símbolo sem shim: os.environ |
| `shim-simbolo:os.getwd` | 1 | 1 | 0 | `github.com/ipfs/boxo/tracing` exporters.go:24:6: símbolo sem shim: os.getwd |
| `shim-simbolo:os.mkdirTemp` | 1 | 1 | 0 | `github.com/ipfs/kubo/repo/fsrepo/migrations/ipfsfetcher` ipfsfetcher.go:172:6: símbolo sem shim: os.mkdirTemp |
| `shim-simbolo:os.newFile` | 1 | 1 | 0 | `github.com/fsnotify/fsnotify` backend_inotify.go:147:6: símbolo sem shim: os.newFile |
| `shim-simbolo:os.pipe` | 1 | 1 | 0 | `github.com/hanwen/go-fuse/v2/fuse` mount.go:12:6: símbolo sem shim: os.pipe |
| `shim-simbolo:os.removeAll` | 1 | 1 | 0 | `github.com/ipfs/kubo/cmd/ipfs/kubo` daemon.go:213:6: símbolo sem shim: os.removeAll |
| `shim-simbolo:sort.searchFloat64s` | 1 | 1 | 0 | `go.opentelemetry.io/otel/sdk/metric/internal/aggregate` histogram.go:96:1: símbolo sem shim: sort.searchFloat64s |
| `shim-simbolo:strconv.formatComplex` | 1 | 1 | 0 | `github.com/go-logr/logr/funcr` funcr.go:238:1: símbolo sem shim: strconv.formatComplex |
| `shim-simbolo:time.$_absSeconds` | 1 | 1 | 0 | `github.com/ipfs/boxo/routing/http/types` time.go:10:1: símbolo sem shim: time.$_absSeconds |
| `unsafe:Add` | 1 | 1 | 0 | `github.com/cockroachdb/pebble/v2/sstable/colblk` prefix_bytes.go:1034:4: unsafe.Add (sem memória crua fora do dart:ffi) |
| `unsafe:Sizeof` | 1 | 1 | 0 | `github.com/cockroachdb/pebble/v2/internal/genericcache` cache.go:177:3: unsafe.Sizeof (sem memória crua fora do dart:ffi) |

## Ranking por área

| área | ocorrências | pacotes |
|---|---:|---:|
| `shim-ausente` | 4063 | 522 |
| `async` | 343 | 149 |
| `shim-simbolo` | 252 | 96 |
| `unsafe` | 474 | 87 |
| `conversao` | 224 | 50 |
| `branch` | 74 | 28 |
| `promocao` | 156 | 24 |
| `construtor-ambiguo` | 13 | 7 |
| `range` | 7 | 6 |
| `tipo-nomeado` | 6 | 6 |
| `dart` | 7 | 5 |
| `func-sem-corpo` | 7 | 5 |
| `generico` | 6 | 3 |
| `opassign-impuro` | 3 | 3 |
| `builtin` | 2 | 2 |
| `go` | 2 | 2 |
| `len` | 2 | 2 |
| `constraint` | 2 | 1 |
| `layout` | 2 | 1 |
| `for-multi-atribuicao` | 1 | 1 |
| `indice` | 1 | 1 |
| `min` | 1 | 1 |

## Fronteira (176 pacotes)

Não verdes com todas as dependências do grafo verdes: o próximo trabalho.

| pacote | status | problemas |
|---|---|---|
| `github.com/golang/groupcache/lru` | unsupported | `shim-ausente:container/list`×2 |
| `github.com/cockroachdb/pebble/v2/internal/rawalloc` | unsupported | `func-sem-corpo`, `unsafe:Pointer` |
| `gonum.org/v1/gonum/mathext/internal/cephes` | unsupported | `branch:goto`×4 |
| `gonum.org/v1/gonum/mathext/internal/amos` | unsupported | `shim-ausente:math/cmplx`×8 |
| `github.com/cockroachdb/pebble/v2/internal/invariants` | unsupported | `shim-ausente:runtime` |
| `github.com/hashicorp/golang-lru/simplelru` | unsupported | `shim-ausente:container/list`×2 |
| `github.com/cockroachdb/pebble/v2/sstable/block/blockkind` | unsupported | `shim-ausente:iter` |
| `golang.org/x/exp/slices` | unsupported | `shim-ausente:slices`×29 |
| `golang.org/x/net/dns/dnsmessage` | unsupported | `shim-ausente:slices` |
| `github.com/beorn7/perks/quantile` | unsupported | `branch:goto` |
| `github.com/ipfs/go-ipfs-pq` | unsupported | `shim-ausente:container/heap`×2 |
| `github.com/guillaumemichel/reservedpool` | unsupported | `shim-ausente:maps` |
| `github.com/gabriel-vasile/mimetype/internal/json` | unsupported | `branch:goto` |
| `github.com/spaolacci/murmur3` | unsupported | `shim-ausente:hash`×5, `unsafe:Pointer`×3, `conversao:pointer-pointer` |
| `github.com/cockroachdb/pebble/v2/internal/crc` | unsupported | `shim-ausente:hash/crc32`×3 |
| `filippo.io/bigmod` | unsupported | `unsafe:Slice`×3 |
| `github.com/cespare/xxhash` | unsupported | `shim-ausente:hash`, `unsafe:Pointer` |
| `github.com/cespare/xxhash/v2` | unsupported | `unsafe:Pointer`×2 |
| `github.com/gabriel-vasile/mimetype/internal/scan` | unsupported | `branch:goto` |
| `github.com/golang/snappy` | unsupported | `shim-ausente:hash/crc32`×3, `branch:goto` |
| `github.com/klauspost/compress/internal/snapref` | unsupported | `shim-ausente:hash/crc32`×3, `branch:goto` |
| `github.com/zeebo/blake3/internal/utils` | unsupported | `unsafe:Pointer`×2 |
| `golang.org/x/crypto/blake2b` | unsupported | `shim-ausente:hash`×5 |
| `golang.org/x/crypto/blake2s` | unsupported | `shim-ausente:hash`×2, `shim-ausente:crypto` |
| `github.com/anmitsu/go-shlex` | unsupported | `async:shim-sincrono`, `shim-ausente:bufio` |
| `github.com/ipfs/go-libdht/kad/trie` | unsupported | `shim-ausente:slices` |
| `github.com/libp2p/go-buffer-pool` | unsupported | `shim-ausente:bufio`×2 |
| `github.com/pbnjay/memory` | unsupported | `shim-ausente:syscall`×2 |
| `github.com/cenkalti/backoff/v4` | unsupported | `construtor-ambiguo`, `shim-ausente:math/rand` |
| `github.com/ipfs/boxo/routing/http/internal` | unsupported | `shim-ausente:slices` |
| `github.com/pion/transport/v3/deadline` | dart-invalido | `dart:return_of_invalid_type` |
| `github.com/pion/transport/v4/deadline` | dart-invalido | `dart:return_of_invalid_type` |
| `go.uber.org/zap/internal/stacktrace` | unsupported | `shim-ausente:runtime`×3 |
| `golang.org/x/net/internal/httpsfv` | unsupported | `shim-ausente:slices`×5 |
| `google.golang.org/grpc/balancer/pickfirst/internal` | unsupported | `shim-ausente:math/rand/v2`×2 |
| `google.golang.org/grpc/internal/backoff` | unsupported | `shim-ausente:math/rand/v2` |
| `google.golang.org/protobuf/internal/editiondefaults` | unsupported | `go:embed` |
| `github.com/RaduBerinde/btreemap` | unsupported | `shim-ausente:iter` |
| `github.com/benbjohnson/clock` | unsupported | `construtor-ambiguo`×4, `async:contexto-sincrono`, `conversao:pointer-pointer` |
| `github.com/blang/semver/v4` | unsupported | `shim-ausente:database/sql/driver` |
| `github.com/cenkalti/backoff/v5` | unsupported | `construtor-ambiguo`, `shim-ausente:math/rand/v2` |
| `github.com/cockroachdb/crlib/crstrings` | unsupported | `shim-ausente:slices` |
| `github.com/cockroachdb/crlib/fifo` | dart-invalido | `dart:invalid_assignment`×2 |
| `github.com/cockroachdb/pebble/v2/internal/binfmt` | unsupported | `unsafe:Pointer` |
| `github.com/cockroachdb/redact/internal/buffer` | unsupported | `unsafe:Pointer` |
| `github.com/cockroachdb/swiss` | unsupported | `unsafe:Pointer`×12, `unsafe:Slice`×2, `func-sem-corpo` |
| `github.com/crackcomm/go-gitignore` | unsupported | `shim-simbolo:os.readFile`×2 |
| `github.com/davidlazar/go-crypto/salsa20` | unsupported | `shim-ausente:crypto/cipher` |
| `github.com/dunglas/httpsfv` | unsupported | `shim-ausente:encoding/base64`×2, `shim-ausente:encoding/hex` |
| `github.com/filecoin-project/go-clock` | unsupported | `construtor-ambiguo`×4, `async:contexto-sincrono`, `conversao:pointer-pointer` |
| `github.com/gammazero/deque` | unsupported | `shim-ausente:iter` |
| `github.com/go-jose/go-jose/v4/json` | unsupported | `shim-ausente:runtime`×2, `shim-ausente:encoding/base64`, `shim-ausente:unicode/utf16` |
| `github.com/go-logfmt/logfmt` | unsupported | `async:shim-sincrono`×2, `shim-ausente:bufio`, `shim-ausente:unicode/utf16` |
| `github.com/grpc-ecosystem/grpc-gateway/v2/utilities` | unsupported | `shim-ausente:flag` |
| `github.com/hashicorp/go-version` | unsupported | `shim-ausente:database/sql/driver` |
| `github.com/huin/goupnp/scpd` | unsupported | `shim-ausente:encoding/xml` |
| `github.com/ipfs/go-datastore/query` | unsupported | `async:valor-func`×3, `shim-ausente:path`, `shim-ausente:slices` |
| `github.com/ipfs/go-libdht/kad/key/bit256` | unsupported | `shim-ausente:encoding/hex` |
| `github.com/ipfs/kubo/repo/common` | unsupported | `shim-ausente:maps` |
| `github.com/ipld/go-ipld-prime/fluent` | unsupported | `async:contexto-sincrono`×2 |
| `github.com/ipld/go-ipld-prime/linking` | unsupported | `shim-ausente:hash` |
| `github.com/klauspost/compress/huff0` | unsupported | `range:pointer`, `shim-ausente:runtime` |
| `github.com/klauspost/cpuid/v2` | unsupported | `shim-simbolo:strings.splitSeq`×2, `shim-ausente:flag`, `shim-ausente:slices`, `tipo-nomeado:pointer` |
| `github.com/libp2p/go-libp2p/core/pnet` | unsupported | `shim-ausente:bufio`×2, `async:shim-sincrono` |
| `github.com/mikioh/tcpopt` | unsupported | `unsafe:Pointer`×13 |
| `github.com/multiformats/go-multihash/core` | unsupported | `shim-ausente:hash`×7, `shim-ausente:crypto/md5` |
| `github.com/pion/dtls/v3/pkg/crypto/ccm` | unsupported | `shim-ausente:crypto/cipher`×3 |
| `github.com/pion/dtls/v3/pkg/crypto/hash` | unsupported | `shim-ausente:crypto` |
| `github.com/pion/rtcp` | unsupported | `unsafe:Pointer` |
| `github.com/pion/stun/v3/internal/hmac` | unsupported | `shim-ausente:hash`×6, `shim-ausente:crypto/sha1`, `shim-ausente:crypto/sha256` |
| `github.com/pion/webrtc/v4/internal/fmtp` | unsupported | `shim-ausente:encoding/hex` |
| `github.com/pkg/errors` | unsupported | `shim-ausente:runtime`×2 |
| `github.com/polydawn/refmt/pretty` | unsupported | `shim-ausente:encoding/hex` |
| `github.com/polydawn/refmt/shared` | dart-invalido | `dart:argument_type_not_assignable` |
| `github.com/prometheus/otlptranslator` | unsupported | `shim-ausente:slices` |
| `github.com/prometheus/procfs/internal/util` | unsupported | `shim-simbolo:os.readFile`×3, `shim-simbolo:os.open`×2 |
| `github.com/quic-go/quic-go/qlogwriter/jsontext` | unsupported | `unsafe:Slice` |
| `github.com/syndtr/goleveldb/leveldb/util` | unsupported | `shim-ausente:hash/crc32`×3 |
| `go.opentelemetry.io/auto/sdk/internal/telemetry` | unsupported | `shim-ausente:encoding/hex`×5, `conversao:pointer-named-pointer`×4, `shim-ausente:cmp`, `tipo-nomeado:pointer`, `unsafe:String` |
| `go.opentelemetry.io/otel/codes` | unsupported | `shim-simbolo:fmt.appendf` |
| `go.opentelemetry.io/otel/trace/internal/telemetry` | unsupported | `shim-ausente:encoding/hex`×5, `conversao:pointer-named-pointer`×4, `shim-ausente:cmp`, `tipo-nomeado:pointer`, `unsafe:String` |
| `go.uber.org/zap/zapcore` | unsupported | `len:typeparam`, `shim-ausente:bufio`, `shim-ausente:encoding/base64`, `shim-ausente:runtime` |
| `golang.org/x/crypto/chacha20poly1305` | unsupported | `shim-ausente:crypto/cipher`×2, `shim-ausente:crypto/fips140` |
| `golang.org/x/crypto/curve25519` | unsupported | `shim-ausente:crypto/ecdh`×2, `range:pointer` |
| `golang.org/x/crypto/hkdf` | unsupported | `shim-ausente:hash`×4 |
| `golang.org/x/exp/mmap` | unsupported | `builtin:println`, `shim-simbolo:os.open` |
| `golang.org/x/text/internal/language/compact` | dart-invalido | `dart:invalid_assignment`×2 |
| `golang.org/x/text/unicode/bidi` | unsupported | `shim-ausente:container/list`×2 |
| `golang.org/x/text/unicode/norm` | unsupported | `branch:goto`×3 |
| `golang.org/x/xerrors` | unsupported | `shim-ausente:runtime`×2, `branch:goto`, `conversao:pointer-pointer` |
| `google.golang.org/grpc/attributes` | unsupported | `shim-ausente:iter` |
| `google.golang.org/grpc/internal/envconfig` | unsupported | `shim-simbolo:strings.splitSeq` |
| `google.golang.org/protobuf/internal/detrand` | unsupported | `shim-simbolo:os.executable` |
| `gopkg.in/yaml.v2` | unsupported | `shim-ausente:encoding/base64`×2 |
| `gopkg.in/yaml.v3` | unsupported | `shim-ausente:encoding/base64`×2 |
| `github.com/AndreasBriese/bbloom` | unsupported | `unsafe:Pointer`×2, `shim-ausente:log` |
| `github.com/gogo/protobuf/proto` | unsupported | `shim-ausente:log`×9, `async:contexto-sincrono`×2, `branch:goto`×2, `builtin:print`, `shim-ausente:bufio` |
| `github.com/ipfs/bbloom` | unsupported | `shim-ausente:log` |
| `github.com/koron/go-ssdp/internal/ssdplog` | unsupported | `shim-ausente:log`×2 |
| `github.com/pion/logging` | unsupported | `async:shim-sincrono`, `shim-ausente:log` |
| `go.opentelemetry.io/otel/internal/errorhandler` | unsupported | `shim-ausente:log`×2 |
| `golang.org/x/net/internal/timeseries` | unsupported | `shim-ausente:log` |
| `google.golang.org/grpc/grpclog/internal` | unsupported | `async:shim-sincrono`, `shim-ausente:log` |
| `github.com/go-logr/logr` | unsupported | `shim-ausente:log/slog`×11, `async:contexto-sincrono` |
| `github.com/libp2p/go-libp2p-pubsub/internal/gologshim` | unsupported | `shim-ausente:log/slog`×6 |
| `github.com/libp2p/go-libp2p/gologshim` | unsupported | `shim-ausente:log/slog`×9 |
| `github.com/dustin/go-humanize` | unsupported | `shim-ausente:math/big`×38 |
| `github.com/klauspost/compress/s2` | unsupported | `branch:goto`×14, `shim-ausente:hash/crc32`×3, `async:contexto-sincrono`, `shim-ausente:io/ioutil`, `shim-ausente:runtime` |
| `github.com/mr-tron/base58` | unsupported | `shim-ausente:math/big`×5 |
| `github.com/mr-tron/base58/base58` | unsupported | `shim-ausente:math/big`×5 |
| `github.com/pion/dtls/v3/pkg/crypto/elliptic` | unsupported | `async:shim-sincrono`, `shim-ausente:crypto/ecdh` |
| `github.com/pion/randutil` | unsupported | `shim-ausente:math/rand`×2, `async:shim-sincrono`, `shim-ausente:crypto/rand` |
| `github.com/whyrusleeping/cbor/go` | unsupported | `shim-ausente:math/big`×5, `shim-ausente:iter`, `shim-ausente:log` |
| `github.com/whyrusleeping/chunker` | unsupported | `shim-ausente:hash`×2, `shim-ausente:crypto/rand` |
| `github.com/whyrusleeping/go-keyspace` | unsupported | `shim-ausente:math/big`×4 |
| `golang.org/x/crypto/cryptobyte` | unsupported | `shim-ausente:math/big`×3, `shim-ausente:encoding/asn1`×2 |
| `github.com/cheggaaa/pb/v3/termutil` | unsupported | `unsafe:Pointer`×3, `shim-simbolo:os.Signal`×2, `shim-simbolo:os.interrupt`, `shim-simbolo:os.open` |
| `github.com/hanwen/go-fuse/v2/internal` | unsupported | `shim-ausente:os/user` |
| `github.com/caddyserver/certmagic/internal/atomicfile` | unsupported | `shim-ausente:path/filepath`, `shim-simbolo:os.remove` |
| `github.com/facebookgo/atomicfile` | unsupported | `shim-ausente:path/filepath`, `shim-simbolo:io/fs.DirEntry` |
| `github.com/ipfs/kubo/misc/fsutil` | unsupported | `shim-simbolo:os.lstat`, `shim-simbolo:os.stat`, `shim-simbolo:os.userHomeDir` |
| `github.com/ipfs/kubo/repo/fsrepo/migrations/atomicfile` | unsupported | `shim-ausente:path/filepath`, `shim-simbolo:io/fs.DirEntry` |
| `github.com/prometheus/procfs/internal/fs` | unsupported | `shim-ausente:path/filepath`, `shim-simbolo:os.stat` |
| `github.com/syndtr/goleveldb/leveldb/storage` | unsupported | `shim-simbolo:os.openFile`×2, `shim-ausente:path/filepath`, `shim-ausente:syscall`, `shim-simbolo:fmt.sscanf`, `shim-simbolo:io/fs.DirEntry` (+4) |
| `golang.org/x/sys/execabs` | unsupported | `shim-ausente:os/exec`×7 |
| `github.com/RaduBerinde/axisds` | unsupported | `shim-simbolo:fmt.sscanf` |
| `github.com/ipfs/kubo/core/commands/e` | unsupported | `shim-ausente:runtime/debug` |
| `github.com/libp2p/go-libp2p/core/internal/catch` | unsupported | `shim-ausente:runtime/debug` |
| `github.com/libp2p/go-libp2p/p2p/protocol/identify/internal/user-agent` | unsupported | `shim-ausente:runtime/debug` |
| `github.com/multiformats/go-multistream` | unsupported | `shim-ausente:bufio`×5, `shim-ausente:runtime/debug`×3, `conversao:slice-typeparam`, `conversao:typeparam-slice` |
| `github.com/kr/pretty` | unsupported | `shim-ausente:log`×3, `shim-ausente:text/tabwriter`×2, `conversao:pointer-pointer`, `shim-simbolo:reflect.Value.unsafeAddr` |
| `go.opencensus.io/tag` | unsupported | `shim-ausente:runtime/pprof` |
| `github.com/decred/dcrd/dcrec/secp256k1/v4` | unsupported | `shim-ausente:math/big`×6, `shim-ausente:encoding/hex`×4, `shim-ausente:crypto/ecdsa`×2, `shim-ausente:crypto/elliptic`, `shim-ausente:crypto/rand` (+3) |
| `github.com/libdns/libdns` | unsupported | `shim-ausente:net/netip`×2 |
| `github.com/google/gopacket/routing` | unsupported | `shim-ausente:net`×4, `shim-ausente:syscall` |
| `github.com/google/uuid` | unsupported | `shim-ausente:crypto/rand`×2, `shim-ausente:database/sql/driver`×2, `shim-ausente:net`×2, `shim-ausente:crypto/md5`, `shim-ausente:crypto/sha1` (+4) |
| `github.com/jackpal/go-nat-pmp` | unsupported | `shim-ausente:net`×3 |
| `github.com/libp2p/go-cidranger/net` | unsupported | `shim-ausente:net`×6 |
| `github.com/libp2p/go-libp2p-asn-util` | unsupported | `go:embed` |
| `github.com/libp2p/go-netroute` | unsupported | `shim-ausente:net`×6, `shim-ausente:syscall`×5 |
| `github.com/pion/dtls/v3/pkg/net` | unsupported | `shim-ausente:net`×5 |
| `github.com/pion/dtls/v3/pkg/protocol` | unsupported | `shim-ausente:net` |
| `github.com/pion/ice/v4/internal/fakenet` | unsupported | `shim-ausente:net`×2 |
| `github.com/pion/transport/v3` | unsupported | `shim-ausente:net`×7 |
| `github.com/pion/transport/v4` | unsupported | `shim-ausente:net`×8 |
| `github.com/pion/transport/v4/netctx` | unsupported | `shim-ausente:net`×9 |
| `github.com/pion/turn/v4/internal/ipnet` | unsupported | `shim-ausente:net`×3 |
| `github.com/whyrusleeping/multiaddr-filter` | unsupported | `shim-ausente:net`×2 |
| `github.com/wlynxg/anet` | unsupported | `shim-ausente:net`×3 |
| `golang.org/x/net/internal/socks` | unsupported | `shim-ausente:net`×4 |
| `google.golang.org/grpc/internal/resolver/dns/internal` | unsupported | `shim-ausente:net`×2 |
| `github.com/cockroachdb/pebble/v2/internal/lsmview` | unsupported | `shim-ausente:net/url` |
| `github.com/coreos/go-systemd/v22/activation` | unsupported | `shim-ausente:net`×3, `shim-ausente:crypto/tls`×2, `shim-simbolo:os.unsetenv` |
| `github.com/getsentry/sentry-go/internal/otel/baggage` | unsupported | `async:contexto-sincrono`, `shim-ausente:net/url` |
| `github.com/ipfs/go-ipfs-redirects-file` | unsupported | `shim-ausente:net/url`×3, `shim-ausente:bufio` |
| `github.com/pion/dtls/v3/pkg/crypto/fingerprint` | unsupported | `shim-ausente:crypto`×3, `shim-ausente:crypto/x509` |
| `github.com/quic-go/quic-go/internal/protocol` | unsupported | `shim-ausente:crypto/rand`×3, `shim-ausente:crypto/tls`×2, `shim-ausente:encoding/hex`×2, `shim-ausente:slices`×2, `shim-ausente:math/rand/v2` |
| `go.opentelemetry.io/otel/baggage` | unsupported | `shim-ausente:net/url`×3, `shim-simbolo:strings.splitSeq`×2 |
| `go.uber.org/dig/internal/digreflect` | unsupported | `shim-ausente:net/url`, `shim-ausente:runtime` |
| `go.uber.org/fx/internal/fxreflect` | unsupported | `shim-ausente:runtime`×2, `shim-ausente:net/url` |
| `golang.org/x/crypto/ocsp` | unsupported | `shim-ausente:crypto/x509` |
| `github.com/caddyserver/zerossl` | unsupported | `shim-ausente:crypto/x509`×2, `shim-ausente:net/http`×2, `shim-ausente:encoding/base64` |
| `github.com/felixge/httpsnoop` | unsupported | `shim-ausente:net/http`×521, `shim-ausente:net` |
| `github.com/gorilla/mux` | unsupported | `shim-ausente:net/http`×25, `shim-ausente:net/url`, `shim-ausente:path` |
| `github.com/huin/goupnp/httpu` | unsupported | `shim-ausente:net/http`×7, `shim-ausente:net`×4 |
| `github.com/huin/goupnp/soap` | unsupported | `shim-ausente:net/url`×4, `shim-ausente:encoding/xml`×3, `shim-ausente:encoding/base64`×2, `shim-ausente:encoding/hex`×2 |
| `github.com/ipfs/kubo/client/rpc/auth` | unsupported | `shim-ausente:net/http`×2 |
| `github.com/mholt/acmez/v3/acme` | unsupported | `shim-ausente:crypto`×9, `shim-ausente:net/http`×4, `shim-ausente:log/slog`×2, `shim-ausente:crypto/sha256`, `shim-ausente:crypto/x509` (+1) |
| `github.com/opentracing/opentracing-go` | unsupported | `shim-ausente:net/http` |
| `github.com/prometheus/client_golang/internal/github.com/golang/gddo/httputil/header` | unsupported | `shim-ausente:net/http` |
| `github.com/rs/cors` | unsupported | `shim-ausente:net/http`×2, `shim-ausente:log` |
| `github.com/slok/go-http-metrics/middleware/std` | unsupported | `shim-ausente:net/http`×4 |
| `go.opencensus.io/zpages/internal` | unsupported | `shim-ausente:net/http`×7, `shim-ausente:io/ioutil` |
| `go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp/internal/request` | unsupported | `shim-ausente:net/http`×2 |
| `golang.org/x/oauth2/internal` | unsupported | `shim-ausente:net/http`×3, `shim-ausente:net/url`×3, `shim-ausente:crypto/rsa` |
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
| 7 | `github.com/cskr/pubsub` | verde |  |
| 8 | `github.com/dgraph-io/badger/options` | verde |  |
| 9 | `github.com/dgraph-io/badger/trie` | verde |  |
| 10 | `github.com/getsentry/sentry-go/internal/otel/baggage/internal/baggage` | verde |  |
| 11 | `github.com/golang/groupcache/lru` | unsupported | `shim-ausente:container/list`×2 |
| 12 | `github.com/hanwen/go-fuse/v2/internal/ioctl` | verde |  |
| 13 | `github.com/ipfs/boxo/ipld/unixfs/internal` | verde |  |
| 14 | `github.com/ipfs/go-libdht/kad` | verde |  |
| 15 | `github.com/klauspost/compress/internal/race` | verde |  |
| 16 | `github.com/libp2p/go-libp2p/core/control` | verde |  |
| 17 | `github.com/pion/dtls/v3/internal/ciphersuite/types` | verde |  |
| 18 | `github.com/pion/dtls/v3/pkg/crypto/clientcertificate` | verde |  |
| 19 | `github.com/pion/interceptor/internal/sequencenumber` | verde |  |
| 20 | `github.com/probe-lab/go-libdht/kad` | verde |  |
| 21 | `github.com/quic-go/quic-go/internal/utils/minheap` | verde |  |
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
| 45 | `github.com/rivo/uniseg` | verde |  |
| 46 | `github.com/cockroachdb/pebble/v2/internal/rawalloc` | unsupported | `func-sem-corpo`, `unsafe:Pointer` |
| 47 | `github.com/cockroachdb/pebble/v2/internal/bytealloc` | bloqueado | `dart:uri_does_not_exist` |
| 48 | `github.com/zeebo/blake3/internal/alg/compress/compress_pure` | verde |  |
| 49 | `github.com/zeebo/blake3/internal/alg/compress` | bloqueado | `dart:uri_does_not_exist` |
| 50 | `golang.org/x/crypto/salsa20/salsa` | verde |  |
| 51 | `google.golang.org/protobuf/internal/set` | verde |  |
| 52 | `github.com/klauspost/compress` | verde |  |
| 53 | `github.com/petar/GoLLRB/llrb` | verde |  |
| 54 | `gonum.org/v1/gonum/mathext/internal/gonum` | verde |  |
| 55 | `gonum.org/v1/gonum/mathext/internal/cephes` | unsupported | `branch:goto`×4 |
| 56 | `gonum.org/v1/gonum/mathext/internal/amos` | unsupported | `shim-ausente:math/cmplx`×8 |
| 57 | `gonum.org/v1/gonum/mathext` | unsupported | `shim-ausente:math/cmplx` |
| 58 | `github.com/cockroachdb/pebble/v2/internal/invariants` | unsupported | `shim-ausente:runtime` |
| 59 | `github.com/cockroachdb/pebble/v2/internal/ewma` | bloqueado |  |
| 60 | `github.com/pion/transport/v3/utils/xor` | verde |  |
| 61 | `github.com/pion/transport/v4/utils/xor` | verde |  |
| 62 | `github.com/hashicorp/golang-lru/simplelru` | unsupported | `shim-ausente:container/list`×2 |
| 63 | `github.com/pion/rtp/codecs/vp9` | verde |  |
| 64 | `github.com/cockroachdb/pebble/v2/sstable/block/blockkind` | unsupported | `shim-ausente:iter` |
| 65 | `golang.org/x/exp/slices` | unsupported | `shim-ausente:slices`×29 |
| 66 | `golang.org/x/net/dns/dnsmessage` | unsupported | `shim-ausente:slices` |
| 67 | `github.com/beorn7/perks/quantile` | unsupported | `branch:goto` |
| 68 | `github.com/gogo/protobuf/sortkeys` | verde |  |
| 69 | `github.com/ipfs/go-ipfs-pq` | unsupported | `shim-ausente:container/heap`×2 |
| 70 | `golang.org/x/text/internal/tag` | verde |  |
| 71 | `github.com/cockroachdb/crlib/crsync` | verde |  |
| 72 | `github.com/pion/ice/v4/internal/atomic` | verde |  |
| 73 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc/internal/counter` | verde |  |
| 74 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp/internal/counter` | verde |  |
| 75 | `go.opentelemetry.io/otel/exporters/prometheus/internal/counter` | verde |  |
| 76 | `go.opentelemetry.io/otel/exporters/stdout/stdouttrace/internal/counter` | verde |  |
| 77 | `github.com/Jorropo/jsync` | verde |  |
| 78 | `github.com/cockroachdb/pebble/v2/internal/intern` | verde |  |
| 79 | `github.com/guillaumemichel/reservedpool` | unsupported | `shim-ausente:maps` |
| 80 | `github.com/quic-go/quic-go/internal/utils/linkedlist` | verde |  |
| 81 | `go.uber.org/zap/internal/pool` | verde |  |
| 82 | `google.golang.org/grpc/internal/buffer` | verde |  |
| 83 | `google.golang.org/protobuf/internal/pragma` | verde |  |
| 84 | `github.com/gabriel-vasile/mimetype/internal/json` | unsupported | `branch:goto` |
| 85 | `github.com/gabriel-vasile/mimetype/internal/mp3` | verde |  |
| 86 | `github.com/getsentry/sentry-go/internal/traceparser` | verde |  |
| 87 | `github.com/ipld/go-car/v2/internal/io` | verde |  |
| 88 | `github.com/kr/text` | verde |  |
| 89 | `github.com/multiformats/go-base32` | verde |  |
| 90 | `github.com/prometheus/client_golang/prometheus/promhttp/internal` | verde |  |
| 91 | `github.com/syndtr/goleveldb/leveldb/comparer` | verde |  |
| 92 | `golang.org/x/text/transform` | verde |  |
| 93 | `github.com/spaolacci/murmur3` | unsupported | `shim-ausente:hash`×5, `unsafe:Pointer`×3, `conversao:pointer-pointer` |
| 94 | `github.com/cockroachdb/pebble/v2/internal/crc` | unsupported | `shim-ausente:hash/crc32`×3 |
| 95 | `filippo.io/bigmod` | unsupported | `unsafe:Slice`×3 |
| 96 | `github.com/cespare/xxhash` | unsupported | `shim-ausente:hash`, `unsafe:Pointer` |
| 97 | `github.com/cespare/xxhash/v2` | unsupported | `unsafe:Pointer`×2 |
| 98 | `github.com/cockroachdb/redact/internal/rfmt/fmtsort` | verde |  |
| 99 | `github.com/gabriel-vasile/mimetype/internal/scan` | unsupported | `branch:goto` |
| 100 | `github.com/gabriel-vasile/mimetype/internal/cdf` | bloqueado | `dart:uri_does_not_exist` |
| 101 | `github.com/gabriel-vasile/mimetype/internal/csv` | bloqueado | `dart:uri_does_not_exist` |
| 102 | `github.com/gabriel-vasile/mimetype/internal/markup` | bloqueado | `dart:uri_does_not_exist` |
| 103 | `github.com/golang/snappy` | unsupported | `shim-ausente:hash/crc32`×3, `branch:goto` |
| 104 | `github.com/klauspost/compress/internal/le` | verde |  |
| 105 | `github.com/klauspost/compress/internal/snapref` | unsupported | `shim-ausente:hash/crc32`×3, `branch:goto` |
| 106 | `github.com/klauspost/compress/zstd/internal/xxhash` | verde |  |
| 107 | `github.com/multiformats/go-varint` | verde |  |
| 108 | `github.com/pion/dtls/v3/internal/util` | verde |  |
| 109 | `github.com/rogpeppe/go-internal/fmtsort` | verde |  |
| 110 | `github.com/zeebo/blake3/internal/utils` | unsupported | `unsafe:Pointer`×2 |
| 111 | `github.com/zeebo/blake3/internal/alg/hash/hash_pure` | unsupported | `unsafe:Pointer` |
| 112 | `github.com/zeebo/blake3/internal/alg/hash` | bloqueado | `dart:uri_does_not_exist`×2 |
| 113 | `github.com/zeebo/blake3/internal/alg` | bloqueado |  |
| 114 | `go.opentelemetry.io/otel/attribute/internal` | verde |  |
| 115 | `go.opentelemetry.io/otel/attribute/internal/xxhash` | bloqueado | `dart:uri_does_not_exist` |
| 116 | `golang.org/x/crypto/blake2b` | unsupported | `shim-ausente:hash`×5 |
| 117 | `golang.org/x/crypto/blake2s` | unsupported | `shim-ausente:hash`×2, `shim-ausente:crypto` |
| 118 | `golang.org/x/crypto/internal/alias` | verde |  |
| 119 | `golang.org/x/crypto/internal/poly1305` | verde |  |
| 120 | `golang.org/x/crypto/salsa20` | verde |  |
| 121 | `github.com/anmitsu/go-shlex` | unsupported | `async:shim-sincrono`, `shim-ausente:bufio` |
| 122 | `github.com/gabriel-vasile/mimetype/internal/charset` | bloqueado | `dart:uri_does_not_exist` |
| 123 | `github.com/ipfs/go-libdht/kad/key` | verde |  |
| 124 | `github.com/ipfs/go-libdht/kad/key/bitstr` | verde |  |
| 125 | `github.com/ipfs/go-libdht/kad/trie` | unsupported | `shim-ausente:slices` |
| 126 | `github.com/libp2p/go-buffer-pool` | unsupported | `shim-ausente:bufio`×2 |
| 127 | `github.com/libp2p/go-msgio` | bloqueado | `dart:uri_does_not_exist` |
| 128 | `github.com/munnerz/goautoneg` | verde |  |
| 129 | `github.com/probe-lab/go-libdht/kad/key` | verde |  |
| 130 | `github.com/rs/cors/internal` | verde |  |
| 131 | `github.com/ucarion/urlpath` | verde |  |
| 132 | `github.com/pbnjay/memory` | unsupported | `shim-ausente:syscall`×2 |
| 133 | `github.com/cenkalti/backoff/v4` | unsupported | `construtor-ambiguo`, `shim-ausente:math/rand` |
| 134 | `github.com/cockroachdb/crlib/crtime` | verde |  |
| 135 | `github.com/cockroachdb/pebble/v2/internal/genericcache` | unsupported | `unsafe:Sizeof` |
| 136 | `github.com/cockroachdb/tokenbucket` | verde |  |
| 137 | `github.com/hashicorp/golang-lru/v2/internal` | verde |  |
| 138 | `github.com/hashicorp/golang-lru/v2/simplelru` | verde |  |
| 139 | `github.com/hashicorp/golang-lru/v2` | verde |  |
| 140 | `github.com/ipfs/boxo/routing/http/internal` | unsupported | `shim-ausente:slices` |
| 141 | `github.com/ipfs/go-metrics-interface` | verde |  |
| 142 | `github.com/ipfs/boxo/bitswap/metrics` | verde |  |
| 143 | `github.com/ipfs/kubo/internal/fusemount` | verde |  |
| 144 | `github.com/jbenet/go-temp-err-catcher` | verde |  |
| 145 | `github.com/libp2p/go-libp2p-kad-dht/provider/stats` | verde |  |
| 146 | `github.com/libp2p/go-libp2p-pubsub/timecache` | verde |  |
| 147 | `github.com/pion/dtls/v3/internal/closer` | verde |  |
| 148 | `github.com/pion/ice/v4/internal/taskloop` | verde |  |
| 149 | `github.com/pion/interceptor/internal/ntp` | verde |  |
| 150 | `github.com/pion/transport/v3/deadline` | dart-invalido | `dart:return_of_invalid_type` |
| 151 | `github.com/pion/transport/v3/packetio` | bloqueado |  |
| 152 | `github.com/pion/transport/v4/deadline` | dart-invalido | `dart:return_of_invalid_type` |
| 153 | `github.com/quic-go/quic-go/internal/monotime` | verde |  |
| 154 | `github.com/slok/go-http-metrics/metrics` | verde |  |
| 155 | `go.opentelemetry.io/otel/internal/baggage` | verde |  |
| 156 | `go.uber.org/dig/internal/digclock` | verde |  |
| 157 | `go.uber.org/fx/internal/fxclock` | verde |  |
| 158 | `go.uber.org/zap/buffer` | verde |  |
| 159 | `go.uber.org/zap/internal/bufferpool` | verde |  |
| 160 | `go.uber.org/zap/internal/stacktrace` | unsupported | `shim-ausente:runtime`×3 |
| 161 | `golang.org/x/net/internal/httpsfv` | unsupported | `shim-ausente:slices`×5 |
| 162 | `golang.org/x/sys/unix` | substituicao | assembly: asm_linux_amd64.s |
| 163 | `github.com/hanwen/go-fuse/v2/internal/fallocate` | bloqueado | `dart:uri_does_not_exist` |
| 164 | `github.com/hanwen/go-fuse/v2/internal/openat` | unsupported | `shim-ausente:syscall`×2 |
| 165 | `github.com/hanwen/go-fuse/v2/internal/renameat` | bloqueado | `dart:uri_does_not_exist` |
| 166 | `github.com/hanwen/go-fuse/v2/internal/xattr` | unsupported | `shim-ausente:syscall` |
| 167 | `github.com/ipfs/kubo/core/node/libp2p/fd` | bloqueado | `dart:uri_does_not_exist` |
| 168 | `github.com/mattn/go-isatty` | bloqueado | `dart:uri_does_not_exist` |
| 169 | `google.golang.org/grpc/backoff` | verde |  |
| 170 | `google.golang.org/grpc/balancer/pickfirst/internal` | unsupported | `shim-ausente:math/rand/v2`×2 |
| 171 | `google.golang.org/grpc/internal/backoff` | unsupported | `shim-ausente:math/rand/v2` |
| 172 | `google.golang.org/grpc/internal/grpcsync` | verde |  |
| 173 | `google.golang.org/grpc/internal/idle` | verde |  |
| 174 | `google.golang.org/grpc/keepalive` | verde |  |
| 175 | `google.golang.org/protobuf/internal/editiondefaults` | unsupported | `go:embed` |
| 176 | `github.com/RaduBerinde/btreemap` | unsupported | `shim-ausente:iter` |
| 177 | `github.com/benbjohnson/clock` | unsupported | `construtor-ambiguo`×4, `async:contexto-sincrono`, `conversao:pointer-pointer` |
| 178 | `github.com/blang/semver/v4` | unsupported | `shim-ausente:database/sql/driver` |
| 179 | `github.com/cenkalti/backoff/v5` | unsupported | `construtor-ambiguo`, `shim-ausente:math/rand/v2` |
| 180 | `github.com/cockroachdb/crlib/crbytes` | substituicao | assembly: common_prefix_amd64.s |
| 181 | `github.com/cockroachdb/crlib/crstrings` | unsupported | `shim-ausente:slices` |
| 182 | `github.com/cockroachdb/crlib/fifo` | dart-invalido | `dart:invalid_assignment`×2 |
| 183 | `github.com/cockroachdb/logtags` | verde |  |
| 184 | `github.com/cockroachdb/pebble/v2/internal/manual` | unsupported | `unsafe:Pointer`×3 |
| 185 | `github.com/cockroachdb/pebble/v2/internal/treeprinter` | verde |  |
| 186 | `github.com/cockroachdb/pebble/v2/internal/binfmt` | unsupported | `unsafe:Pointer` |
| 187 | `github.com/cockroachdb/redact/interfaces` | verde |  |
| 188 | `github.com/cockroachdb/redact/internal/fmtforward` | verde |  |
| 189 | `github.com/cockroachdb/redact/internal/markers` | verde |  |
| 190 | `github.com/cockroachdb/redact/internal/escape` | verde |  |
| 191 | `github.com/cockroachdb/redact/internal/buffer` | unsupported | `unsafe:Pointer` |
| 192 | `github.com/cockroachdb/redact/internal/redact` | verde |  |
| 193 | `github.com/cockroachdb/redact/internal/rfmt` | bloqueado | `dart:undefined_getter`×11, `dart:undefined_method`×11, `dart:non_abstract_class_inherits_abstract_member`, `dart:override_on_non_overriding_member`, `dart:uri_does_not_exist` |
| 194 | `github.com/cockroachdb/redact/builder` | bloqueado | `dart:override_on_non_overriding_member`, `dart:uri_does_not_exist` |
| 195 | `github.com/cockroachdb/redact` | bloqueado |  |
| 196 | `github.com/cockroachdb/pebble/v2/internal/humanize` | bloqueado |  |
| 197 | `github.com/cockroachdb/swiss` | unsupported | `unsafe:Pointer`×12, `unsafe:Slice`×2, `func-sem-corpo` |
| 198 | `github.com/crackcomm/go-gitignore` | unsupported | `shim-simbolo:os.readFile`×2 |
| 199 | `github.com/davidlazar/go-crypto/salsa20` | unsupported | `shim-ausente:crypto/cipher` |
| 200 | `github.com/dunglas/httpsfv` | unsupported | `shim-ausente:encoding/base64`×2, `shim-ausente:encoding/hex` |
| 201 | `github.com/filecoin-project/go-clock` | unsupported | `construtor-ambiguo`×4, `async:contexto-sincrono`, `conversao:pointer-pointer` |
| 202 | `github.com/fsnotify/fsnotify/internal` | unsupported | `shim-ausente:syscall`×4 |
| 203 | `github.com/gabriel-vasile/mimetype/internal/magic` | unsupported | `shim-ausente:slices`×5 |
| 204 | `github.com/gammazero/deque` | unsupported | `shim-ausente:iter` |
| 205 | `github.com/gammazero/chanqueue` | bloqueado | `dart:uri_does_not_exist` |
| 206 | `github.com/go-jose/go-jose/v4/json` | unsupported | `shim-ausente:runtime`×2, `shim-ausente:encoding/base64`, `shim-ausente:unicode/utf16` |
| 207 | `github.com/go-logfmt/logfmt` | unsupported | `async:shim-sincrono`×2, `shim-ausente:bufio`, `shim-ausente:unicode/utf16` |
| 208 | `github.com/grpc-ecosystem/grpc-gateway/v2/utilities` | unsupported | `shim-ausente:flag` |
| 209 | `github.com/grpc-ecosystem/grpc-gateway/v2/internal/httprule` | bloqueado | `dart:uri_does_not_exist` |
| 210 | `github.com/hashicorp/go-version` | unsupported | `shim-ausente:database/sql/driver` |
| 211 | `github.com/huin/goupnp/scpd` | unsupported | `shim-ausente:encoding/xml` |
| 212 | `github.com/ipfs/boxo/routing/http/internal/drjson` | verde |  |
| 213 | `github.com/ipfs/boxo/routing/http/types/iter` | verde |  |
| 214 | `github.com/ipfs/go-bitfield` | verde |  |
| 215 | `github.com/ipfs/go-datastore/query` | unsupported | `async:valor-func`×3, `shim-ausente:path`, `shim-ausente:slices` |
| 216 | `github.com/ipfs/go-libdht/kad/key/bit256` | unsupported | `shim-ausente:encoding/hex` |
| 217 | `github.com/ipfs/kubo/repo/common` | unsupported | `shim-ausente:maps` |
| 218 | `github.com/ipld/go-ipld-prime/datamodel` | verde |  |
| 219 | `github.com/ipld/go-ipld-prime/adl` | verde |  |
| 220 | `github.com/ipld/go-ipld-prime/codec` | verde |  |
| 221 | `github.com/ipld/go-ipld-prime/fluent` | unsupported | `async:contexto-sincrono`×2 |
| 222 | `github.com/ipld/go-ipld-prime/fluent/qp` | verde |  |
| 223 | `github.com/ipld/go-ipld-prime/linking/preload` | verde |  |
| 224 | `github.com/ipld/go-ipld-prime/multicodec` | verde |  |
| 225 | `github.com/ipld/go-ipld-prime/codec/raw` | verde |  |
| 226 | `github.com/ipld/go-ipld-prime/node/mixins` | verde |  |
| 227 | `github.com/ipld/go-ipld-prime/schema` | verde |  |
| 228 | `github.com/ipld/go-ipld-prime/storage` | verde |  |
| 229 | `github.com/ipld/go-ipld-prime/linking` | unsupported | `shim-ausente:hash` |
| 230 | `github.com/ipld/go-ipld-prime/node/basicnode` | bloqueado | `dart:return_of_invalid_type`, `dart:uri_does_not_exist` |
| 231 | `github.com/ipld/go-ipld-prime/node/basic` | bloqueado | `dart:uri_does_not_exist` |
| 232 | `github.com/klauspost/compress/fse` | verde |  |
| 233 | `github.com/klauspost/compress/huff0` | unsupported | `range:pointer`, `shim-ausente:runtime` |
| 234 | `github.com/klauspost/cpuid/v2` | unsupported | `shim-simbolo:strings.splitSeq`×2, `shim-ausente:flag`, `shim-ausente:slices`, `tipo-nomeado:pointer` |
| 235 | `github.com/libp2p/go-flow-metrics` | unsupported | `async:contexto-sincrono`, `async:valor-func` |
| 236 | `github.com/libp2p/go-libp2p-kad-dht/provider/internal/connectivity` | verde |  |
| 237 | `github.com/libp2p/go-libp2p/core/pnet` | unsupported | `shim-ausente:bufio`×2, `async:shim-sincrono` |
| 238 | `github.com/mattn/go-colorable` | bloqueado |  |
| 239 | `github.com/fatih/color` | bloqueado |  |
| 240 | `github.com/mattn/go-runewidth` | verde |  |
| 241 | `github.com/mgutz/ansi` | unsupported | `conversao:slice-named-slice` |
| 242 | `github.com/elgris/jsondiff` | bloqueado | `dart:uri_does_not_exist` |
| 243 | `github.com/mikioh/tcpopt` | unsupported | `unsafe:Pointer`×13 |
| 244 | `github.com/mikioh/tcpinfo` | unsupported | `unsafe:Pointer`×5 |
| 245 | `github.com/multiformats/go-base36` | verde |  |
| 246 | `github.com/multiformats/go-multiaddr/x/meg` | verde |  |
| 247 | `github.com/multiformats/go-multicodec` | verde |  |
| 248 | `github.com/multiformats/go-multihash/core` | unsupported | `shim-ausente:hash`×7, `shim-ausente:crypto/md5` |
| 249 | `github.com/multiformats/go-multihash/register/blake2` | bloqueado | `dart:uri_does_not_exist`×3 |
| 250 | `github.com/multiformats/go-multihash/register/murmur3` | unsupported | `shim-ausente:hash` |
| 251 | `github.com/multiformats/go-multihash/register/sha256` | unsupported | `shim-ausente:crypto/sha256` |
| 252 | `github.com/multiformats/go-multihash/register/miniosha256` | bloqueado |  |
| 253 | `github.com/opentracing/opentracing-go/log` | verde |  |
| 254 | `github.com/pion/dtls/v3/pkg/crypto/ccm` | unsupported | `shim-ausente:crypto/cipher`×3 |
| 255 | `github.com/pion/dtls/v3/pkg/crypto/hash` | unsupported | `shim-ausente:crypto` |
| 256 | `github.com/pion/dtls/v3/pkg/crypto/signature` | bloqueado | `dart:uri_does_not_exist` |
| 257 | `github.com/pion/rtcp` | unsupported | `unsafe:Pointer` |
| 258 | `github.com/pion/rtp/codecs/av1/obu` | verde |  |
| 259 | `github.com/pion/stun/v3/internal/hmac` | unsupported | `shim-ausente:hash`×6, `shim-ausente:crypto/sha1`, `shim-ausente:crypto/sha256` |
| 260 | `github.com/pion/transport/v3/replaydetector` | verde |  |
| 261 | `github.com/pion/transport/v4/replaydetector` | verde |  |
| 262 | `github.com/pion/webrtc/v4/internal/fmtp` | unsupported | `shim-ausente:encoding/hex` |
| 263 | `github.com/pion/webrtc/v4/pkg/rtcerr` | verde |  |
| 264 | `github.com/pkg/errors` | unsupported | `shim-ausente:runtime`×2 |
| 265 | `github.com/polydawn/refmt/obj/atlas` | verde |  |
| 266 | `github.com/polydawn/refmt/tok` | verde |  |
| 267 | `github.com/polydawn/refmt/obj` | verde |  |
| 268 | `github.com/polydawn/refmt/pretty` | unsupported | `shim-ausente:encoding/hex` |
| 269 | `github.com/polydawn/refmt/shared` | dart-invalido | `dart:argument_type_not_assignable` |
| 270 | `github.com/polydawn/refmt/cbor` | unsupported | `branch:goto` |
| 271 | `github.com/polydawn/refmt/json` | unsupported | `shim-ausente:unicode/utf16`, `shim-simbolo:strconv.NumError` |
| 272 | `github.com/polydawn/refmt` | bloqueado | `dart:uri_does_not_exist`×2 |
| 273 | `github.com/ipfs/go-ipld-cbor/encoding` | bloqueado | `dart:uri_does_not_exist` |
| 274 | `github.com/prometheus/otlptranslator` | unsupported | `shim-ausente:slices` |
| 275 | `github.com/prometheus/procfs/internal/util` | unsupported | `shim-simbolo:os.readFile`×3, `shim-simbolo:os.open`×2 |
| 276 | `github.com/quic-go/quic-go/qlogwriter/jsontext` | unsupported | `unsafe:Slice` |
| 277 | `github.com/quic-go/quic-go/quicvarint` | verde |  |
| 278 | `github.com/slok/go-http-metrics/middleware` | verde |  |
| 279 | `github.com/syndtr/goleveldb/leveldb/util` | unsupported | `shim-ausente:hash/crc32`×3 |
| 280 | `github.com/syndtr/goleveldb/leveldb/cache` | unsupported | `unsafe:Pointer`×7 |
| 281 | `github.com/syndtr/goleveldb/leveldb/filter` | bloqueado | `dart:uri_does_not_exist` |
| 282 | `github.com/syndtr/goleveldb/leveldb/opt` | bloqueado | `dart:uri_does_not_exist` |
| 283 | `github.com/texttheater/golang-levenshtein/levenshtein` | verde |  |
| 284 | `github.com/zeebo/blake3` | unsupported | `unsafe:Pointer`×6 |
| 285 | `go.opencensus.io/internal` | verde |  |
| 286 | `go.opencensus.io/resource` | verde |  |
| 287 | `go.opencensus.io/metric/metricdata` | verde |  |
| 288 | `go.opencensus.io/metric/metricproducer` | verde |  |
| 289 | `go.opencensus.io/trace/tracestate` | verde |  |
| 290 | `go.opentelemetry.io/auto/sdk/internal/telemetry` | unsupported | `shim-ausente:encoding/hex`×5, `conversao:pointer-named-pointer`×4, `shim-ausente:cmp`, `tipo-nomeado:pointer`, `unsafe:String` |
| 291 | `go.opentelemetry.io/otel/attribute` | unsupported | `shim-ausente:cmp`×2, `shim-ausente:encoding/base64` |
| 292 | `go.opentelemetry.io/otel/codes` | unsupported | `shim-simbolo:fmt.appendf` |
| 293 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc/internal` | verde |  |
| 294 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc/internal/retry` | bloqueado | `dart:uri_does_not_exist` |
| 295 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc/internal/x` | verde |  |
| 296 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp/internal` | verde |  |
| 297 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp/internal/retry` | bloqueado | `dart:uri_does_not_exist` |
| 298 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp/internal/x` | verde |  |
| 299 | `go.opentelemetry.io/otel/exporters/prometheus/internal/x` | verde |  |
| 300 | `go.opentelemetry.io/otel/exporters/stdout/stdouttrace/internal/x` | verde |  |
| 301 | `go.opentelemetry.io/otel/metric` | unsupported | `shim-ausente:slices` |
| 302 | `go.opentelemetry.io/otel/metric/noop` | unsupported | `promocao:nao-exportada`×20 |
| 303 | `go.opentelemetry.io/otel/sdk/instrumentation` | bloqueado | `dart:uri_does_not_exist` |
| 304 | `go.opentelemetry.io/otel/sdk/internal/attrnorm` | unsupported | `shim-ausente:slices`×3, `unsafe:Pointer` |
| 305 | `go.opentelemetry.io/otel/sdk/internal/x` | verde |  |
| 306 | `go.opentelemetry.io/otel/sdk/metric/internal/attrnorm` | unsupported | `unsafe:Pointer` |
| 307 | `go.opentelemetry.io/otel/sdk/metric/internal/x` | verde |  |
| 308 | `go.opentelemetry.io/otel/semconv/internal/metricpool` | bloqueado | `dart:uri_does_not_exist` |
| 309 | `go.opentelemetry.io/otel/semconv/v1.37.0` | bloqueado | `dart:uri_does_not_exist` |
| 310 | `go.opentelemetry.io/otel/semconv/v1.41.0` | bloqueado | `dart:uri_does_not_exist` |
| 311 | `go.opentelemetry.io/otel/semconv/v1.41.0/otelconv` | unsupported | `promocao:nao-exportada`×28 |
| 312 | `go.opentelemetry.io/otel/semconv/v1.43.0` | bloqueado | `dart:uri_does_not_exist` |
| 313 | `go.opentelemetry.io/otel/semconv/v1.43.0/httpconv` | unsupported | `promocao:nao-exportada`×13 |
| 314 | `go.opentelemetry.io/otel/semconv/v1.43.0/otelconv` | unsupported | `promocao:nao-exportada`×28 |
| 315 | `go.opentelemetry.io/otel/trace/internal/telemetry` | unsupported | `shim-ausente:encoding/hex`×5, `conversao:pointer-named-pointer`×4, `shim-ausente:cmp`, `tipo-nomeado:pointer`, `unsafe:String` |
| 316 | `go.opentelemetry.io/otel/trace` | unsupported | `promocao:nao-exportada`×6, `construtor-ambiguo`, `shim-ausente:slices` |
| 317 | `go.opentelemetry.io/otel/sdk/metric/exemplar` | unsupported | `promocao:nao-exportada`×2, `shim-ausente:math/rand/v2`×2, `shim-ausente:slices` |
| 318 | `go.opentelemetry.io/otel/trace/noop` | unsupported | `promocao:nao-exportada`×3 |
| 319 | `go.uber.org/dig/internal/digerror` | verde |  |
| 320 | `go.uber.org/dig/internal/dot` | verde |  |
| 321 | `go.uber.org/multierr` | verde |  |
| 322 | `go.uber.org/zap/internal/color` | verde |  |
| 323 | `go.uber.org/zap/internal/exit` | verde |  |
| 324 | `go.uber.org/zap/zapcore` | unsupported | `len:typeparam`, `shim-ausente:bufio`, `shim-ausente:encoding/base64`, `shim-ausente:runtime` |
| 325 | `go.uber.org/zap/internal` | bloqueado | `dart:uri_does_not_exist` |
| 326 | `golang.org/x/crypto/chacha20` | verde |  |
| 327 | `golang.org/x/crypto/chacha20poly1305` | unsupported | `shim-ausente:crypto/cipher`×2, `shim-ausente:crypto/fips140` |
| 328 | `golang.org/x/crypto/curve25519` | unsupported | `shim-ausente:crypto/ecdh`×2, `range:pointer` |
| 329 | `golang.org/x/crypto/hkdf` | unsupported | `shim-ausente:hash`×4 |
| 330 | `golang.org/x/exp/mmap` | unsupported | `builtin:println`, `shim-simbolo:os.open` |
| 331 | `golang.org/x/net/bpf` | verde |  |
| 332 | `golang.org/x/net/http2/hpack` | verde |  |
| 333 | `github.com/quic-go/qpack` | verde |  |
| 334 | `golang.org/x/sync/errgroup` | verde |  |
| 335 | `golang.org/x/sys/cpu` | substituicao | assembly: cpu_gc_x86.s |
| 336 | `golang.org/x/crypto/sha3` | unsupported | `shim-ausente:crypto/sha3`×9, `shim-ausente:hash`×7, `range:pointer` |
| 337 | `github.com/multiformats/go-multihash/register/sha3` | bloqueado | `dart:uri_does_not_exist`×2 |
| 338 | `golang.org/x/term` | bloqueado | `dart:uri_does_not_exist` |
| 339 | `golang.org/x/text/internal/language` | verde |  |
| 340 | `golang.org/x/text/internal/language/compact` | dart-invalido | `dart:invalid_assignment`×2 |
| 341 | `golang.org/x/text/language` | unsupported | `conversao:pointer-pointer` |
| 342 | `golang.org/x/text/internal` | bloqueado | `dart:invalid_constant`, `dart:undefined_getter`, `dart:uri_does_not_exist` |
| 343 | `golang.org/x/text/unicode/bidi` | unsupported | `shim-ausente:container/list`×2 |
| 344 | `golang.org/x/text/secure/bidirule` | bloqueado | `dart:invalid_constant`, `dart:undefined_getter`, `dart:uri_does_not_exist` |
| 345 | `golang.org/x/text/unicode/norm` | unsupported | `branch:goto`×3 |
| 346 | `golang.org/x/net/idna` | bloqueado | `dart:uri_does_not_exist`×2 |
| 347 | `golang.org/x/text/cases` | bloqueado | `dart:uri_does_not_exist`×2, `dart:invalid_constant`, `dart:undefined_getter` |
| 348 | `golang.org/x/time/rate` | verde |  |
| 349 | `golang.org/x/xerrors` | unsupported | `shim-ausente:runtime`×2, `branch:goto`, `conversao:pointer-pointer` |
| 350 | `google.golang.org/grpc/attributes` | unsupported | `shim-ausente:iter` |
| 351 | `google.golang.org/grpc/internal/envconfig` | unsupported | `shim-simbolo:strings.splitSeq` |
| 352 | `google.golang.org/protobuf/internal/detrand` | unsupported | `shim-simbolo:os.executable` |
| 353 | `google.golang.org/protobuf/internal/errors` | bloqueado | `dart:uri_does_not_exist` |
| 354 | `google.golang.org/protobuf/encoding/protowire` | bloqueado |  |
| 355 | `google.golang.org/protobuf/internal/version` | verde |  |
| 356 | `google.golang.org/protobuf/reflect/protoreflect` | unsupported | `unsafe:Pointer`×10 |
| 357 | `google.golang.org/protobuf/internal/descfmt` | bloqueado | `dart:uri_does_not_exist`×2 |
| 358 | `google.golang.org/protobuf/internal/descopts` | bloqueado | `dart:uri_does_not_exist` |
| 359 | `google.golang.org/protobuf/internal/encoding/messageset` | unsupported | `async:contexto-sincrono` |
| 360 | `google.golang.org/protobuf/internal/genid` | bloqueado | `dart:uri_does_not_exist` |
| 361 | `google.golang.org/protobuf/internal/order` | unsupported | `async:contexto-sincrono` |
| 362 | `google.golang.org/protobuf/internal/strs` | unsupported | `shim-ausente:go/token`, `unsafe:Slice`, `unsafe:String` |
| 363 | `google.golang.org/protobuf/internal/encoding/json` | unsupported | `shim-ausente:unicode/utf16` |
| 364 | `google.golang.org/protobuf/internal/encoding/text` | unsupported | `shim-ausente:unicode/utf16`, `shim-simbolo:strconv.NumError` |
| 365 | `google.golang.org/protobuf/internal/encoding/defval` | bloqueado | `dart:uri_does_not_exist`×2 |
| 366 | `google.golang.org/protobuf/reflect/protoregistry` | bloqueado | `dart:invalid_override`×3, `dart:uri_does_not_exist`×2, `dart:invalid_constant`, `dart:undefined_getter` |
| 367 | `google.golang.org/protobuf/runtime/protoiface` | bloqueado |  |
| 368 | `google.golang.org/protobuf/internal/protolazy` | unsupported | `branch:goto`×2, `unsafe:Pointer`×2 |
| 369 | `google.golang.org/protobuf/proto` | unsupported | `async:contexto-sincrono`×3, `conversao:pointer-typeparam` |
| 370 | `google.golang.org/protobuf/encoding/protodelim` | unsupported | `shim-ausente:bufio` |
| 371 | `google.golang.org/protobuf/encoding/prototext` | bloqueado | `dart:undefined_getter`×15, `dart:undefined_method`×15, `dart:uri_does_not_exist`×6, `dart:invalid_assignment`×3, `dart:invalid_override`×2 (+2) |
| 372 | `google.golang.org/protobuf/internal/filedesc` | unsupported | `async:contexto-sincrono` |
| 373 | `google.golang.org/protobuf/encoding/protojson` | unsupported | `async:contexto-sincrono`×2, `shim-ausente:encoding/base64` |
| 374 | `google.golang.org/protobuf/internal/encoding/tag` | bloqueado | `dart:uri_does_not_exist`×3 |
| 375 | `google.golang.org/protobuf/internal/impl` | unsupported | `unsafe:Pointer`×15, `conversao:pointer-pointer`×2, `shim-ausente:compress/gzip` |
| 376 | `google.golang.org/protobuf/internal/filetype` | bloqueado | `dart:invalid_constant`×5, `dart:undefined_getter`×4, `dart:uri_does_not_exist`×4 |
| 377 | `google.golang.org/protobuf/runtime/protoimpl` | bloqueado | `dart:uri_does_not_exist` |
| 378 | `github.com/ipfs/boxo/bitswap/message/pb` | unsupported | `unsafe:Pointer`×5 |
| 379 | `github.com/ipfs/boxo/filestore/pb` | unsupported | `unsafe:Pointer` |
| 380 | `github.com/ipfs/boxo/ipld/merkledag/pb` | unsupported | `unsafe:Pointer`×2 |
| 381 | `github.com/ipfs/boxo/ipld/unixfs/pb` | unsupported | `unsafe:Pointer`×3 |
| 382 | `github.com/ipfs/boxo/ipns/pb` | unsupported | `unsafe:Pointer` |
| 383 | `github.com/libp2p/go-libp2p-record/pb` | unsupported | `unsafe:Pointer` |
| 384 | `github.com/libp2p/go-libp2p/core/crypto/pb` | unsupported | `unsafe:Pointer`×2, `unsafe:Slice`×2 |
| 385 | `github.com/libp2p/go-libp2p/core/peer/pb` | unsupported | `unsafe:Pointer`×2, `unsafe:Slice`×2 |
| 386 | `github.com/libp2p/go-libp2p/core/record/pb` | unsupported | `unsafe:Slice`×2, `unsafe:Pointer` |
| 387 | `github.com/libp2p/go-libp2p/p2p/host/autonat/pb` | unsupported | `unsafe:Pointer`×4, `unsafe:Slice`×2 |
| 388 | `github.com/libp2p/go-libp2p/p2p/protocol/autonatv2/pb` | unsupported | `unsafe:Pointer`×7, `unsafe:Slice`×2 |
| 389 | `github.com/libp2p/go-libp2p/p2p/protocol/circuitv2/pb` | unsupported | `unsafe:Pointer`×6, `unsafe:Slice`×4 |
| 390 | `github.com/libp2p/go-libp2p/p2p/protocol/holepunch/pb` | unsupported | `unsafe:Slice`×2, `unsafe:Pointer` |
| 391 | `github.com/libp2p/go-libp2p/p2p/protocol/identify/pb` | unsupported | `unsafe:Slice`×2, `unsafe:Pointer` |
| 392 | `github.com/libp2p/go-libp2p/p2p/security/insecure/pb` | unsupported | `unsafe:Slice`×2, `unsafe:Pointer` |
| 393 | `github.com/libp2p/go-libp2p/p2p/security/noise/pb` | unsupported | `unsafe:Pointer`×2, `unsafe:Slice`×2 |
| 394 | `github.com/libp2p/go-libp2p/p2p/transport/webrtc/pb` | unsupported | `unsafe:Slice`×2, `unsafe:Pointer` |
| 395 | `go.opentelemetry.io/proto/otlp/common/v1` | unsupported | `unsafe:Pointer`×6 |
| 396 | `go.opentelemetry.io/proto/otlp/resource/v1` | unsupported | `unsafe:Pointer` |
| 397 | `go.opentelemetry.io/proto/otlp/trace/v1` | unsupported | `unsafe:Pointer`×7 |
| 398 | `google.golang.org/protobuf/protoadapt` | bloqueado | `dart:uri_does_not_exist` |
| 399 | `google.golang.org/grpc/internal/pretty` | bloqueado | `dart:uri_does_not_exist`×2 |
| 400 | `google.golang.org/protobuf/types/descriptorpb` | unsupported | `unsafe:Pointer`×34, `unsafe:Slice`×2 |
| 401 | `google.golang.org/protobuf/internal/editionssupport` | bloqueado | `dart:uri_does_not_exist` |
| 402 | `google.golang.org/protobuf/types/gofeaturespb` | unsupported | `unsafe:Slice`×2, `unsafe:Pointer` |
| 403 | `google.golang.org/protobuf/reflect/protodesc` | bloqueado | `dart:invalid_constant`×14, `dart:undefined_getter`×12, `dart:uri_does_not_exist`×8 |
| 404 | `google.golang.org/protobuf/types/known/anypb` | unsupported | `unsafe:Slice`×2, `unsafe:Pointer` |
| 405 | `google.golang.org/genproto/googleapis/api/httpbody` | unsupported | `unsafe:Pointer` |
| 406 | `google.golang.org/genproto/googleapis/rpc/status` | unsupported | `unsafe:Pointer` |
| 407 | `google.golang.org/protobuf/types/known/durationpb` | unsupported | `unsafe:Slice`×2, `unsafe:Pointer` |
| 408 | `google.golang.org/genproto/googleapis/rpc/errdetails` | unsupported | `unsafe:Pointer`×14 |
| 409 | `google.golang.org/protobuf/types/known/fieldmaskpb` | unsupported | `unsafe:Slice`×2, `unsafe:Pointer` |
| 410 | `google.golang.org/protobuf/types/known/structpb` | unsupported | `unsafe:Pointer`×3, `unsafe:Slice`×2, `shim-ausente:encoding/base64` |
| 411 | `google.golang.org/protobuf/types/known/timestamppb` | unsupported | `unsafe:Slice`×2, `unsafe:Pointer` |
| 412 | `github.com/prometheus/client_model/go` | unsupported | `unsafe:Pointer`×12 |
| 413 | `github.com/prometheus/common/model` | unsupported | `shim-simbolo:fmt.appendf`×3, `shim-ausente:maps`×2, `conversao:pointer-pointer` |
| 414 | `github.com/prometheus/client_golang/prometheus/internal` | unsupported | `async:shim-sincrono`, `shim-ausente:runtime/metrics` |
| 415 | `google.golang.org/grpc/binarylog/grpc_binarylog_v1` | unsupported | `unsafe:Pointer`×8, `unsafe:Slice`×2 |
| 416 | `google.golang.org/protobuf/types/known/wrapperspb` | unsupported | `unsafe:Pointer`×9, `unsafe:Slice`×2 |
| 417 | `gopkg.in/yaml.v2` | unsupported | `shim-ausente:encoding/base64`×2 |
| 418 | `gopkg.in/yaml.v3` | unsupported | `shim-ausente:encoding/base64`×2 |
| 419 | `github.com/golang/protobuf/proto` | unsupported | `shim-ausente:compress/gzip` |
| 420 | `github.com/dgraph-io/badger/pb` | bloqueado | `dart:uri_does_not_exist` |
| 421 | `github.com/minio/sha256-simd` | unsupported | `shim-ausente:hash`, `shim-ausente:io/ioutil` |
| 422 | `github.com/AndreasBriese/bbloom` | unsupported | `unsafe:Pointer`×2, `shim-ausente:log` |
| 423 | `github.com/dgraph-io/ristretto/z` | substituicao | assembly: rtutil.s |
| 424 | `github.com/go-kit/log` | unsupported | `shim-ausente:log`, `shim-ausente:runtime` |
| 425 | `github.com/go-kit/log/level` | bloqueado | `dart:uri_does_not_exist` |
| 426 | `github.com/gogo/protobuf/proto` | unsupported | `shim-ausente:log`×9, `async:contexto-sincrono`×2, `branch:goto`×2, `builtin:print`, `shim-ausente:bufio` |
| 427 | `github.com/gogo/protobuf/protoc-gen-gogo/descriptor` | unsupported | `async:contexto-sincrono`×27, `shim-ausente:compress/gzip` |
| 428 | `github.com/gogo/protobuf/gogoproto` | bloqueado | `dart:uri_does_not_exist`×2 |
| 429 | `github.com/gogo/protobuf/types` | bloqueado | `dart:missing_identifier`×9, `dart:argument_type_not_assignable`×6, `dart:uri_does_not_exist` |
| 430 | `github.com/cockroachdb/errors/errorspb` | unsupported | `async:contexto-sincrono`×12 |
| 431 | `github.com/hanwen/go-fuse/v2/splice` | unsupported | `shim-ausente:syscall`×5, `shim-simbolo:os.open`, `shim-simbolo:os.readFile` |
| 432 | `github.com/ipfs/bbloom` | unsupported | `shim-ausente:log` |
| 433 | `github.com/koron/go-ssdp/internal/ssdplog` | unsupported | `shim-ausente:log`×2 |
| 434 | `github.com/libp2p/go-libp2p-pubsub-router/pb` | unsupported | `async:contexto-sincrono`×2 |
| 435 | `github.com/pion/logging` | unsupported | `async:shim-sincrono`, `shim-ausente:log` |
| 436 | `github.com/prometheus/statsd_exporter/pkg/level` | bloqueado | `dart:uri_does_not_exist` |
| 437 | `github.com/prometheus/statsd_exporter/pkg/mapper/fsm` | bloqueado | `dart:uri_does_not_exist` |
| 438 | `go.opentelemetry.io/otel/internal/errorhandler` | unsupported | `shim-ausente:log`×2 |
| 439 | `golang.org/x/net/internal/timeseries` | unsupported | `shim-ausente:log` |
| 440 | `google.golang.org/grpc/grpclog/internal` | unsupported | `async:shim-sincrono`, `shim-ausente:log` |
| 441 | `google.golang.org/grpc/grpclog` | bloqueado | `dart:uri_does_not_exist` |
| 442 | `google.golang.org/grpc/connectivity` | unsupported | `async:contexto-sincrono`×2 |
| 443 | `google.golang.org/grpc/internal/grpclog` | bloqueado |  |
| 444 | `github.com/go-logr/logr` | unsupported | `shim-ausente:log/slog`×11, `async:contexto-sincrono` |
| 445 | `github.com/libp2p/go-libp2p-pubsub/internal/gologshim` | unsupported | `shim-ausente:log/slog`×6 |
| 446 | `github.com/libp2p/go-libp2p-pubsub/pb` | unsupported | `unsafe:Pointer`×35, `unsafe:Slice`×4, `shim-ausente:log/slog`×2 |
| 447 | `github.com/libp2p/go-libp2p/gologshim` | unsupported | `shim-ausente:log/slog`×9 |
| 448 | `go.opentelemetry.io/auto/sdk` | unsupported | `promocao:nao-exportada`×2, `construtor-ambiguo`, `shim-ausente:log/slog` |
| 449 | `lukechampine.com/blake3/guts` | substituicao | assembly: compress_amd64.s |
| 450 | `lukechampine.com/blake3/bao` | unsupported | `async:valor-func`, `range:pointer` |
| 451 | `lukechampine.com/blake3` | unsupported | `async:contexto-sincrono`, `shim-ausente:runtime` |
| 452 | `github.com/multiformats/go-multihash/register/blake3` | bloqueado | `dart:uri_does_not_exist`×2 |
| 453 | `github.com/multiformats/go-multihash/register/all` | bloqueado |  |
| 454 | `github.com/dustin/go-humanize` | unsupported | `shim-ausente:math/big`×38 |
| 455 | `github.com/flynn/noise` | unsupported | `shim-ausente:hash`×8, `shim-ausente:crypto/rand`×2, `shim-ausente:crypto/aes`, `shim-ausente:crypto/cipher`, `shim-ausente:crypto/sha256` (+1) |
| 456 | `github.com/klauspost/compress/s2` | unsupported | `branch:goto`×14, `shim-ausente:hash/crc32`×3, `async:contexto-sincrono`, `shim-ausente:io/ioutil`, `shim-ausente:runtime` |
| 457 | `github.com/libp2p/go-libp2p-kbucket/keyspace` | unsupported | `shim-ausente:math/big`×5 |
| 458 | `github.com/minio/minlz` | unsupported | `branch:goto`×6, `shim-ausente:hash/crc32`×5, `shim-ausente:runtime`×2, `async:contexto-sincrono` |
| 459 | `github.com/mr-tron/base58` | unsupported | `shim-ausente:math/big`×5 |
| 460 | `github.com/mr-tron/base58/base58` | unsupported | `shim-ausente:math/big`×5 |
| 461 | `github.com/multiformats/go-multibase` | unsupported | `shim-ausente:encoding/hex`×2 |
| 462 | `github.com/multiformats/go-multihash` | unsupported | `shim-ausente:hash`×3, `shim-ausente:encoding/hex`×2 |
| 463 | `github.com/ipfs/go-cid` | unsupported | `shim-simbolo:fmt.appendf` |
| 464 | `github.com/ipfs/boxo/bitswap/client/wantlist` | unsupported | `shim-ausente:cmp` |
| 465 | `github.com/ipfs/boxo/ipld/unixfs/private/linksize` | bloqueado | `dart:uri_does_not_exist` |
| 466 | `github.com/ipfs/boxo/path` | unsupported | `shim-ausente:path` |
| 467 | `github.com/ipfs/boxo/verifcid` | bloqueado | `dart:uri_does_not_exist`×2 |
| 468 | `github.com/ipfs/boxo/bitswap/internal/defaults` | bloqueado |  |
| 469 | `github.com/ipfs/go-cidutil` | unsupported | `async:valor-func`, `shim-ausente:slices` |
| 470 | `github.com/ipfs/go-cidutil/cidenc` | bloqueado | `dart:uri_does_not_exist`×2 |
| 471 | `github.com/ipld/go-car/v2/internal/carv1/util` | bloqueado | `dart:uri_does_not_exist` |
| 472 | `github.com/ipld/go-ipld-prime/linking/cid` | bloqueado | `dart:uri_does_not_exist`×5, `dart:undefined_getter`×3, `dart:undefined_method`×3, `dart:non_abstract_class_inherits_abstract_member`, `dart:override_on_non_overriding_member` |
| 473 | `github.com/ipld/go-ipld-prime/codec/dagcbor` | bloqueado | `dart:uri_does_not_exist`×2 |
| 474 | `github.com/ipld/go-ipld-prime/codec/cbor` | bloqueado |  |
| 475 | `github.com/ipld/go-ipld-prime/codec/dagjson` | unsupported | `shim-ausente:encoding/base64`×2 |
| 476 | `github.com/ceramicnetwork/go-dag-jose/dagjose` | unsupported | `conversao:pointer-pointer`×44, `branch:goto`×14, `shim-ausente:encoding/base64`×2 |
| 477 | `github.com/ipld/go-ipld-prime/codec/json` | bloqueado | `dart:uri_does_not_exist`×2 |
| 478 | `github.com/ipld/go-ipld-prime/traversal/selector` | bloqueado | `dart:argument_type_not_assignable` |
| 479 | `github.com/ipld/go-ipld-prime/traversal` | bloqueado | `dart:return_of_invalid_type`×2, `dart:uri_does_not_exist` |
| 480 | `github.com/ipld/go-ipld-prime/traversal/selector/builder` | bloqueado | `dart:uri_does_not_exist` |
| 481 | `github.com/ipld/go-ipld-prime/traversal/selector/parse` | bloqueado | `dart:uri_does_not_exist` |
| 482 | `github.com/libp2p/go-libp2p-kad-dht/provider/internal` | bloqueado | `dart:uri_does_not_exist` |
| 483 | `github.com/pion/dtls/v3/pkg/crypto/elliptic` | unsupported | `async:shim-sincrono`, `shim-ausente:crypto/ecdh` |
| 484 | `github.com/pion/randutil` | unsupported | `shim-ausente:math/rand`×2, `async:shim-sincrono`, `shim-ausente:crypto/rand` |
| 485 | `github.com/pion/rtp` | bloqueado | `dart:uri_does_not_exist` |
| 486 | `github.com/pion/interceptor` | bloqueado | `dart:uri_does_not_exist` |
| 487 | `github.com/pion/interceptor/internal/rtpbuffer` | bloqueado |  |
| 488 | `github.com/pion/interceptor/pkg/flexfec/util` | bloqueado |  |
| 489 | `github.com/pion/interceptor/pkg/flexfec` | bloqueado | `dart:uri_does_not_exist` |
| 490 | `github.com/pion/interceptor/pkg/nack` | unsupported | `opassign-impuro`, `shim-ausente:math/rand` |
| 491 | `github.com/pion/interceptor/pkg/report` | unsupported | `async:valor-func`×2, `opassign-impuro`, `shim-ausente:math/rand` |
| 492 | `github.com/pion/interceptor/pkg/rfc8888` | bloqueado | `dart:invalid_constant`×2, `dart:undefined_getter`×2, `dart:uri_does_not_exist`×2 |
| 493 | `github.com/pion/interceptor/pkg/twcc` | unsupported | `shim-ausente:math/rand` |
| 494 | `github.com/pion/rtp/codecs` | unsupported | `async:valor-func` |
| 495 | `github.com/pion/webrtc/v4/internal/util` | bloqueado | `dart:uri_does_not_exist` |
| 496 | `github.com/pion/webrtc/v4/pkg/media` | bloqueado |  |
| 497 | `github.com/whyrusleeping/cbor/go` | unsupported | `shim-ausente:math/big`×5, `shim-ausente:iter`, `shim-ausente:log` |
| 498 | `github.com/ipld/go-car/v2/index` | bloqueado | `dart:undefined_getter`×13, `dart:undefined_method`×13, `dart:uri_does_not_exist`×4, `dart:instance_access_to_static_member`×2, `dart:non_abstract_class_inherits_abstract_member` (+2) |
| 499 | `github.com/whyrusleeping/chunker` | unsupported | `shim-ausente:hash`×2, `shim-ausente:crypto/rand` |
| 500 | `github.com/whyrusleeping/go-keyspace` | unsupported | `shim-ausente:math/big`×4 |
| 501 | `github.com/whyrusleeping/go-sysinfo` | unsupported | `shim-ausente:io/ioutil`, `shim-ausente:syscall` |
| 502 | `golang.org/x/crypto/cryptobyte` | unsupported | `shim-ausente:math/big`×3, `shim-ausente:encoding/asn1`×2 |
| 503 | `github.com/gabriel-vasile/mimetype` | unsupported | `shim-ausente:mime`×3, `shim-simbolo:os.open` |
| 504 | `github.com/cheggaaa/pb/v3/termutil` | unsupported | `unsafe:Pointer`×3, `shim-simbolo:os.Signal`×2, `shim-simbolo:os.interrupt`, `shim-simbolo:os.open` |
| 505 | `github.com/hanwen/go-fuse/v2/internal` | unsupported | `shim-ausente:os/user` |
| 506 | `github.com/caddyserver/certmagic/internal/atomicfile` | unsupported | `shim-ausente:path/filepath`, `shim-simbolo:os.remove` |
| 507 | `github.com/facebookgo/atomicfile` | unsupported | `shim-ausente:path/filepath`, `shim-simbolo:io/fs.DirEntry` |
| 508 | `github.com/fsnotify/fsnotify` | unsupported | `async:valor-func`, `shim-ausente:path/filepath`, `shim-simbolo:os.newFile`, `unsafe:Pointer` |
| 509 | `github.com/go-logr/logr/funcr` | unsupported | `shim-ausente:log/slog`×2, `shim-simbolo:strconv.formatComplex` |
| 510 | `github.com/go-logr/stdr` | unsupported | `async:contexto-sincrono`, `shim-ausente:log` |
| 511 | `github.com/ipfs/kubo/misc/fsutil` | unsupported | `shim-simbolo:os.lstat`, `shim-simbolo:os.stat`, `shim-simbolo:os.userHomeDir` |
| 512 | `github.com/ipfs/kubo/repo/fsrepo/migrations/atomicfile` | unsupported | `shim-ausente:path/filepath`, `shim-simbolo:io/fs.DirEntry` |
| 513 | `github.com/prometheus/procfs/internal/fs` | unsupported | `shim-ausente:path/filepath`, `shim-simbolo:os.stat` |
| 514 | `github.com/syndtr/goleveldb/leveldb/storage` | unsupported | `shim-simbolo:os.openFile`×2, `shim-ausente:path/filepath`, `shim-ausente:syscall`, `shim-simbolo:fmt.sscanf`, `shim-simbolo:io/fs.DirEntry` (+4) |
| 515 | `github.com/syndtr/goleveldb/leveldb/errors` | bloqueado | `dart:uri_does_not_exist`×2, `dart:invalid_constant`, `dart:undefined_getter` |
| 516 | `github.com/syndtr/goleveldb/leveldb/iterator` | unsupported | `shim-ausente:container/heap` |
| 517 | `github.com/syndtr/goleveldb/leveldb/journal` | bloqueado | `dart:uri_does_not_exist`×2 |
| 518 | `github.com/syndtr/goleveldb/leveldb/memdb` | unsupported | `shim-ausente:math/rand`×2, `branch:goto` |
| 519 | `github.com/syndtr/goleveldb/leveldb/table` | bloqueado | `dart:uri_does_not_exist`×5 |
| 520 | `github.com/syndtr/goleveldb/leveldb` | unsupported | `shim-ausente:container/list`×3, `unsafe:Pointer`×2, `branch:goto`, `construtor-ambiguo`, `shim-ausente:bufio` (+1) |
| 521 | `go4.org/lock` | unsupported | `shim-simbolo:os.stat`×2, `shim-ausente:path/filepath`, `shim-ausente:syscall`, `shim-simbolo:os.Signal`, `shim-simbolo:os.open` (+1) |
| 522 | `golang.org/x/sys/execabs` | unsupported | `shim-ausente:os/exec`×7 |
| 523 | `github.com/RaduBerinde/axisds` | unsupported | `shim-simbolo:fmt.sscanf` |
| 524 | `github.com/RaduBerinde/axisds/regiontree` | unsupported | `layout:typeparam`×2 |
| 525 | `github.com/ipfs/boxo/util` | unsupported | `shim-ausente:path/filepath`, `shim-ausente:runtime/debug`, `shim-simbolo:os.lstat` |
| 526 | `github.com/ipfs/go-block-format` | unsupported | `async:contexto-sincrono` |
| 527 | `github.com/ipfs/boxo/bitswap/client/internal/sessioninterestmanager` | unsupported | `shim-ausente:slices` |
| 528 | `github.com/ipfs/boxo/exchange` | bloqueado | `dart:uri_does_not_exist`×2 |
| 529 | `github.com/ipfs/go-ipld-format` | unsupported | `shim-ausente:runtime` |
| 530 | `github.com/ipfs/boxo/filestore/posinfo` | unsupported | `shim-simbolo:io/fs.FileInfo` |
| 531 | `github.com/ipfs/boxo/ipld/merkledag/traverse` | bloqueado | `dart:uri_does_not_exist`×3 |
| 532 | `github.com/ipfs/boxo/pinning/pinner` | bloqueado | `dart:uri_does_not_exist`×2 |
| 533 | `github.com/ipfs/kubo/core/commands/e` | unsupported | `shim-ausente:runtime/debug` |
| 534 | `github.com/libp2p/go-libp2p/core/internal/catch` | unsupported | `shim-ausente:runtime/debug` |
| 535 | `github.com/libp2p/go-libp2p/p2p/protocol/identify/internal/user-agent` | unsupported | `shim-ausente:runtime/debug` |
| 536 | `github.com/libp2p/go-msgio/pbio` | unsupported | `async:shim-sincrono`, `shim-ausente:bufio`, `shim-ausente:runtime/debug` |
| 537 | `github.com/libp2p/go-msgio/protoio` | unsupported | `async:shim-sincrono`, `shim-ausente:bufio`, `shim-ausente:runtime/debug` |
| 538 | `github.com/multiformats/go-multistream` | unsupported | `shim-ausente:bufio`×5, `shim-ausente:runtime/debug`×3, `conversao:slice-typeparam`, `conversao:typeparam-slice` |
| 539 | `github.com/libp2p/go-libp2p/core/protocol` | bloqueado | `dart:uri_does_not_exist` |
| 540 | `github.com/ipfs/boxo/bitswap/network/bsnet/internal` | bloqueado |  |
| 541 | `github.com/libp2p/go-libp2p-kad-dht/amino` | bloqueado |  |
| 542 | `go.opencensus.io/trace` | unsupported | `shim-ausente:math/rand`, `shim-ausente:runtime/trace` |
| 543 | `go.opencensus.io/metric/metricexport` | bloqueado | `dart:uri_does_not_exist` |
| 544 | `github.com/ipfs/kubo/repo/fsrepo/migrations/common` | unsupported | `shim-ausente:testing`×6, `shim-ausente:path/filepath`×3, `shim-ausente:maps`×2, `shim-ausente:slices`, `shim-simbolo:os.readFile` (+1) |
| 545 | `github.com/ipfs/kubo/repo/fsrepo/migrations/fs-repo-17-to-18/migration` | bloqueado | `dart:uri_does_not_exist` |
| 546 | `github.com/kr/pretty` | unsupported | `shim-ausente:log`×3, `shim-ausente:text/tabwriter`×2, `conversao:pointer-pointer`, `shim-simbolo:reflect.Value.unsafeAddr` |
| 547 | `github.com/cockroachdb/errors/errbase` | unsupported | `async:contexto-sincrono`×4, `conversao:pointer-pointer`×3, `shim-ausente:syscall`×3, `shim-simbolo:os.LinkError`×3, `shim-ausente:log` (+2) |
| 548 | `github.com/cockroachdb/errors/barriers` | unsupported | `async:contexto-sincrono` |
| 549 | `github.com/cockroachdb/errors/contexttags` | unsupported | `async:contexto-sincrono` |
| 550 | `github.com/cockroachdb/errors/domains` | unsupported | `async:contexto-sincrono`, `shim-ausente:runtime` |
| 551 | `github.com/cockroachdb/errors/hintdetail` | unsupported | `async:contexto-sincrono`×2 |
| 552 | `github.com/cockroachdb/errors/join` | unsupported | `async:contexto-sincrono` |
| 553 | `github.com/cockroachdb/errors/markers` | unsupported | `async:contexto-sincrono` |
| 554 | `github.com/cockroachdb/errors/assert` | unsupported | `async:contexto-sincrono` |
| 555 | `github.com/cockroachdb/errors/issuelink` | unsupported | `async:contexto-sincrono`×2 |
| 556 | `github.com/cockroachdb/errors/safedetails` | unsupported | `async:contexto-sincrono` |
| 557 | `github.com/cockroachdb/errors/secondary` | unsupported | `async:contexto-sincrono` |
| 558 | `github.com/cockroachdb/errors/telemetrykeys` | unsupported | `async:contexto-sincrono` |
| 559 | `github.com/ipld/go-ipld-prime/node/bindnode` | unsupported | `conversao:pointer-pointer`×18, `shim-ausente:go/format`, `shim-ausente:go/token`, `shim-ausente:runtime` |
| 560 | `github.com/ipld/go-ipld-prime/schema/dmt` | bloqueado | `dart:uri_does_not_exist` |
| 561 | `github.com/ipld/go-ipld-prime/schema/dsl` | unsupported | `async:shim-sincrono`, `shim-ausente:bufio`, `shim-simbolo:os.open` |
| 562 | `github.com/ipld/go-ipld-prime` | unsupported | `shim-simbolo:os.open` |
| 563 | `github.com/ipfs/boxo/fetcher` | bloqueado |  |
| 564 | `github.com/ipfs/boxo/fetcher/helpers` | bloqueado | `dart:uri_does_not_exist` |
| 565 | `github.com/ipfs/go-ipld-git` | unsupported | `conversao:pointer-pointer`×24, `shim-ausente:bufio`×9, `async:shim-sincrono`×3, `shim-ausente:encoding/hex`×2, `branch:goto` |
| 566 | `github.com/ipfs/go-ipld-legacy` | unsupported | `async:contexto-sincrono` |
| 567 | `github.com/ipfs/go-unixfsnode/data` | unsupported | `conversao:pointer-pointer`×12, `branch:goto`×6 |
| 568 | `github.com/ipld/go-car/v2/internal/loader` | bloqueado | `dart:uri_does_not_exist`×2, `dart:invalid_constant`, `dart:undefined_getter` |
| 569 | `github.com/ipld/go-codec-dagpb` | unsupported | `conversao:pointer-pointer`×9, `branch:goto`×4 |
| 570 | `github.com/ipfs/go-unixfsnode/file` | unsupported | `async:contexto-sincrono`×3 |
| 571 | `github.com/ipfs/go-unixfsnode/iter` | bloqueado | `dart:uri_does_not_exist` |
| 572 | `github.com/ipfs/go-unixfsnode/hamt` | unsupported | `shim-ausente:hash` |
| 573 | `github.com/ipfs/go-unixfsnode/utils` | bloqueado | `dart:uri_does_not_exist` |
| 574 | `github.com/ipfs/go-unixfsnode/directory` | bloqueado | `dart:uri_does_not_exist`×4, `dart:argument_type_not_assignable`×2 |
| 575 | `github.com/ipfs/go-unixfsnode` | bloqueado | `dart:uri_does_not_exist`×6, `dart:argument_type_not_assignable`×2 |
| 576 | `go.opencensus.io/tag` | unsupported | `shim-ausente:runtime/pprof` |
| 577 | `go.opencensus.io/stats/internal` | bloqueado | `dart:uri_does_not_exist` |
| 578 | `go.opencensus.io/stats` | bloqueado | `dart:uri_does_not_exist` |
| 579 | `go.opencensus.io/stats/view` | bloqueado | `dart:invalid_constant`×2, `dart:undefined_getter`×2, `dart:uri_does_not_exist` |
| 580 | `filippo.io/keygen` | unsupported | `shim-ausente:crypto/elliptic`×3, `shim-ausente:crypto/rsa`×2, `shim-ausente:crypto/rand`, `shim-ausente:crypto/sha256` |
| 581 | `github.com/decred/dcrd/dcrec/secp256k1/v4` | unsupported | `shim-ausente:math/big`×6, `shim-ausente:encoding/hex`×4, `shim-ausente:crypto/ecdsa`×2, `shim-ausente:crypto/elliptic`, `shim-ausente:crypto/rand` (+3) |
| 582 | `github.com/decred/dcrd/dcrec/secp256k1/v4/ecdsa` | unsupported | `shim-ausente:math/big` |
| 583 | `github.com/klauspost/compress/zstd` | unsupported | `shim-ausente:runtime`×6, `shim-ausente:hash/crc32`×4, `range:pointer`×2, `shim-ausente:log`×2, `shim-ausente:weak`×2 (+3) |
| 584 | `github.com/libdns/libdns` | unsupported | `shim-ausente:net/netip`×2 |
| 585 | `github.com/coreos/go-systemd/v22/daemon` | unsupported | `shim-ausente:net`, `shim-simbolo:os.unsetenv` |
| 586 | `github.com/google/gopacket/routing` | unsupported | `shim-ausente:net`×4, `shim-ausente:syscall` |
| 587 | `github.com/google/uuid` | unsupported | `shim-ausente:crypto/rand`×2, `shim-ausente:database/sql/driver`×2, `shim-ausente:net`×2, `shim-ausente:crypto/md5`, `shim-ausente:crypto/sha1` (+4) |
| 588 | `github.com/hanwen/go-fuse/v2/fuse` | unsupported | `unsafe:Pointer`×47, `shim-ausente:syscall`×19, `shim-ausente:log`×7, `shim-simbolo:io/fs.FileInfo`×2, `range:pointer` (+8) |
| 589 | `github.com/hanwen/go-fuse/v2/fs` | unsupported | `shim-ausente:syscall`×76, `shim-ausente:log`, `unsafe:Pointer` |
| 590 | `github.com/ipfs/go-datastore` | unsupported | `shim-ausente:log`×2, `shim-ausente:iter`, `shim-ausente:path` |
| 591 | `github.com/ipfs/boxo/datastore/dshelp` | bloqueado | `dart:uri_does_not_exist`×3 |
| 592 | `github.com/ipfs/go-datastore/keytransform` | unsupported | `async:valor-func` |
| 593 | `github.com/ipfs/go-datastore/mount` | unsupported | `async:valor-func`, `shim-ausente:container/heap`, `shim-ausente:slices` |
| 594 | `github.com/ipfs/go-datastore/namespace` | bloqueado | `dart:uri_does_not_exist`×2 |
| 595 | `github.com/ipfs/boxo/pinning/pinner/dsindex` | unsupported | `shim-ausente:path` |
| 596 | `github.com/ipfs/go-datastore/sync` | bloqueado | `dart:uri_does_not_exist`×2 |
| 597 | `github.com/ipfs/go-ds-leveldb` | unsupported | `async:valor-func`, `shim-simbolo:io/fs.FileInfo` |
| 598 | `github.com/ipfs/go-ds-measure` | bloqueado | `dart:uri_does_not_exist`×2 |
| 599 | `github.com/ipfs/go-ipfs-ds-help` | bloqueado | `dart:uri_does_not_exist`×3 |
| 600 | `github.com/jackpal/go-nat-pmp` | unsupported | `shim-ausente:net`×3 |
| 601 | `github.com/libp2p/go-cidranger/net` | unsupported | `shim-ausente:net`×6 |
| 602 | `github.com/libp2p/go-cidranger` | unsupported | `shim-ausente:net`×13 |
| 603 | `github.com/libp2p/go-libp2p-asn-util` | unsupported | `go:embed` |
| 604 | `github.com/libp2p/go-libp2p/p2p/net/pnet` | unsupported | `shim-ausente:net`×3 |
| 605 | `github.com/libp2p/go-netroute` | unsupported | `shim-ausente:net`×6, `shim-ausente:syscall`×5 |
| 606 | `github.com/libp2p/go-reuseport` | unsupported | `shim-ausente:net`×7, `shim-ausente:syscall` |
| 607 | `github.com/libp2p/go-yamux/v5` | unsupported | `shim-ausente:net`×6 |
| 608 | `github.com/marten-seemann/tcp` | unsupported | `unsafe:Pointer`×4, `shim-ausente:net`×3, `shim-ausente:syscall` |
| 609 | `github.com/pion/dtls/v3/internal/net` | unsupported | `shim-ausente:net`×2 |
| 610 | `github.com/pion/dtls/v3/pkg/net` | unsupported | `shim-ausente:net`×5 |
| 611 | `github.com/pion/dtls/v3/internal/net/udp` | unsupported | `shim-ausente:net`×4 |
| 612 | `github.com/pion/dtls/v3/pkg/protocol` | unsupported | `shim-ausente:net` |
| 613 | `github.com/pion/dtls/v3/pkg/crypto/prf` | unsupported | `shim-ausente:hash`×2, `shim-ausente:crypto/ecdh`, `shim-ausente:crypto/hmac` |
| 614 | `github.com/pion/dtls/v3/pkg/protocol/alert` | bloqueado | `dart:uri_does_not_exist` |
| 615 | `github.com/pion/ice/v4/internal/fakenet` | unsupported | `shim-ausente:net`×2 |
| 616 | `github.com/pion/sctp` | unsupported | `shim-ausente:hash/crc32`×3, `shim-ausente:net`×2, `shim-ausente:crypto/rand`, `shim-ausente:encoding/hex` |
| 617 | `github.com/pion/datachannel` | unsupported | `async:contexto-sincrono` |
| 618 | `github.com/pion/srtp/v3` | unsupported | `shim-ausente:crypto/aes`×3, `shim-ausente:net`×3, `shim-ausente:crypto/cipher`×2, `shim-ausente:hash`, `unsafe:Pointer` |
| 619 | `github.com/pion/transport/v3` | unsupported | `shim-ausente:net`×7 |
| 620 | `github.com/pion/transport/v3/vnet` | unsupported | `shim-ausente:net`×27, `shim-ausente:math/rand` |
| 621 | `github.com/pion/transport/v4` | unsupported | `shim-ausente:net`×8 |
| 622 | `github.com/pion/transport/v4/netctx` | unsupported | `shim-ausente:net`×9 |
| 623 | `github.com/pion/turn/v4/internal/ipnet` | unsupported | `shim-ausente:net`×3 |
| 624 | `github.com/prometheus/procfs` | unsupported | `async:shim-sincrono`×20, `shim-ausente:bufio`×16, `shim-simbolo:os.open`×7, `shim-ausente:net`×6, `shim-simbolo:fmt.sscanf`×3 (+6) |
| 625 | `github.com/whyrusleeping/multiaddr-filter` | unsupported | `shim-ausente:net`×2 |
| 626 | `github.com/wlynxg/anet` | unsupported | `shim-ausente:net`×3 |
| 627 | `github.com/pion/transport/v3/stdnet` | unsupported | `shim-ausente:net`×3 |
| 628 | `github.com/pion/transport/v4/stdnet` | unsupported | `shim-ausente:net`×4 |
| 629 | `golang.org/x/net/internal/socket` | unsupported | `shim-ausente:net`×14, `shim-ausente:syscall`×8, `unsafe:Pointer`×7, `func-sem-corpo`×2, `shim-simbolo:os.newSyscallError` |
| 630 | `golang.org/x/net/internal/socks` | unsupported | `shim-ausente:net`×4 |
| 631 | `golang.org/x/net/ipv4` | unsupported | `shim-ausente:net`×15, `unsafe:Pointer`×3 |
| 632 | `github.com/koron/go-ssdp/internal/multicast` | unsupported | `shim-ausente:net`×15 |
| 633 | `golang.org/x/net/ipv6` | unsupported | `shim-ausente:net`×13, `shim-simbolo:encoding/binary.NativeEndian._littleEndian`×4, `unsafe:Pointer`×4, `opassign-impuro` |
| 634 | `github.com/pion/mdns/v2` | unsupported | `shim-ausente:net/netip`×9, `shim-ausente:net`×8 |
| 635 | `google.golang.org/grpc/internal` | unsupported | `shim-ausente:net` |
| 636 | `google.golang.org/grpc/codes` | bloqueado | `dart:uri_does_not_exist` |
| 637 | `google.golang.org/grpc/internal/mem` | unsupported | `shim-ausente:slices` |
| 638 | `google.golang.org/grpc/internal/resolver/dns/internal` | unsupported | `shim-ausente:net`×2 |
| 639 | `google.golang.org/grpc/internal/status` | bloqueado | `dart:uri_does_not_exist`×3, `dart:invalid_override` |
| 640 | `google.golang.org/grpc/internal/syscall` | unsupported | `shim-ausente:net`×2, `shim-ausente:syscall`×2 |
| 641 | `google.golang.org/grpc/mem` | unsupported | `async:shim-sincrono` |
| 642 | `google.golang.org/grpc/internal/transport/readyreader` | unsupported | `shim-ausente:syscall`×3, `shim-ausente:net` |
| 643 | `google.golang.org/grpc/metadata` | bloqueado | `dart:uri_does_not_exist` |
| 644 | `google.golang.org/grpc/internal/balancerload` | bloqueado |  |
| 645 | `google.golang.org/grpc/internal/grpcutil` | bloqueado |  |
| 646 | `google.golang.org/grpc/encoding` | unsupported | `shim-ausente:slices` |
| 647 | `google.golang.org/grpc/encoding/gzip` | unsupported | `async:shim-sincrono`×3, `shim-ausente:compress/gzip`×2 |
| 648 | `google.golang.org/grpc/encoding/proto` | bloqueado | `dart:uri_does_not_exist`×4 |
| 649 | `google.golang.org/grpc/stats` | unsupported | `shim-ausente:net`×3, `shim-ausente:maps` |
| 650 | `google.golang.org/grpc/experimental/stats` | unsupported | `conversao:pointer-pointer`×14, `promocao:nao-exportada`, `shim-ausente:maps` |
| 651 | `google.golang.org/grpc/internal/stats` | unsupported | `promocao:nao-exportada`, `shim-ausente:maps` |
| 652 | `google.golang.org/grpc/status` | bloqueado | `dart:uri_does_not_exist` |
| 653 | `google.golang.org/grpc/internal/binarylog` | unsupported | `shim-ausente:net`×5, `async:shim-sincrono`, `shim-ausente:bufio` |
| 654 | `google.golang.org/grpc/tap` | bloqueado |  |
| 655 | `golang.org/x/net/http/httpguts` | unsupported | `shim-ausente:net`, `shim-ausente:net/textproto` |
| 656 | `github.com/cockroachdb/pebble/v2/internal/lsmview` | unsupported | `shim-ausente:net/url` |
| 657 | `github.com/coreos/go-systemd/v22/activation` | unsupported | `shim-ausente:net`×3, `shim-ausente:crypto/tls`×2, `shim-simbolo:os.unsetenv` |
| 658 | `github.com/getsentry/sentry-go/internal/otel/baggage` | unsupported | `async:contexto-sincrono`, `shim-ausente:net/url` |
| 659 | `github.com/ipfs/go-ipfs-redirects-file` | unsupported | `shim-ausente:net/url`×3, `shim-ausente:bufio` |
| 660 | `github.com/libp2p/go-libp2p/core/crypto` | unsupported | `conversao:pointer-pointer`×5, `shim-ausente:crypto/ecdsa`×5, `shim-ausente:crypto/x509`×5, `shim-ausente:crypto`×3, `shim-ausente:crypto/elliptic`×3 (+7) |
| 661 | `github.com/libp2p/go-libp2p/core/record` | bloqueado | `dart:uri_does_not_exist`×6 |
| 662 | `github.com/miekg/dns` | unsupported | `shim-ausente:net`×43, `shim-ausente:crypto`×8, `shim-ausente:encoding/hex`×8, `shim-ausente:crypto/tls`×7, `shim-ausente:encoding/base64`×7 (+18) |
| 663 | `github.com/libp2p/zeroconf/v2` | unsupported | `shim-ausente:net`×20 |
| 664 | `github.com/multiformats/go-multiaddr` | unsupported | `shim-ausente:encoding/base32`×8, `shim-ausente:encoding/base64`×4, `shim-ausente:net`×4, `conversao:slice-named-slice`×2, `shim-ausente:log`×2 (+4) |
| 665 | `github.com/libp2p/go-libp2p/core/peer` | unsupported | `async:contexto-sincrono`×2 |
| 666 | `github.com/ipfs/boxo/bitswap/client/internal/blockpresencemanager` | bloqueado | `dart:invalid_constant`×2, `dart:undefined_getter`×2, `dart:uri_does_not_exist`×2 |
| 667 | `github.com/ipfs/boxo/bitswap/client/traceability` | bloqueado | `dart:uri_does_not_exist`×3 |
| 668 | `github.com/ipfs/boxo/bitswap/client/internal/notifications` | bloqueado | `dart:uri_does_not_exist`×3, `dart:unnecessary_cast` |
| 669 | `github.com/ipfs/boxo/retrieval` | unsupported | `shim-ausente:slices` |
| 670 | `github.com/ipfs/boxo/routing/http/types` | unsupported | `async:contexto-sincrono`, `conversao:named-slice-slice`, `shim-simbolo:time.$_absSeconds` |
| 671 | `github.com/ipfs/boxo/routing/http/types/json` | bloqueado | `dart:uri_does_not_exist` |
| 672 | `github.com/ipfs/boxo/routing/http/types/ndjson` | bloqueado | `dart:invalid_constant`, `dart:undefined_getter`, `dart:uri_does_not_exist` |
| 673 | `github.com/ipfs/go-peertaskqueue/peertask` | bloqueado | `dart:uri_does_not_exist`×2 |
| 674 | `github.com/ipfs/go-peertaskqueue/peertracker` | bloqueado | `dart:uri_does_not_exist`×2 |
| 675 | `github.com/ipfs/go-peertaskqueue` | bloqueado | `dart:uri_does_not_exist`×2, `dart:invalid_constant`, `dart:undefined_getter` |
| 676 | `github.com/libp2p/go-libp2p-kad-dht/qpeerset` | unsupported | `shim-ausente:math/big`×3 |
| 677 | `github.com/libp2p/go-libp2p-pubsub/partialmessages` | unsupported | `shim-ausente:iter`×2, `shim-ausente:log/slog` |
| 678 | `github.com/libp2p/go-libp2p-record` | bloqueado | `dart:uri_does_not_exist`×4 |
| 679 | `github.com/libp2p/go-libp2p/core/discovery` | bloqueado | `dart:uri_does_not_exist` |
| 680 | `github.com/libp2p/go-libp2p/core/metrics` | bloqueado | `dart:uri_does_not_exist`×2, `dart:invalid_constant`, `dart:undefined_getter` |
| 681 | `github.com/libp2p/go-libp2p/core/peerstore` | bloqueado | `dart:uri_does_not_exist`×3, `dart:invalid_constant`, `dart:undefined_getter` |
| 682 | `github.com/libp2p/go-libp2p/core/network` | unsupported | `shim-ausente:net`×4 |
| 683 | `github.com/ipfs/boxo/bitswap/message` | unsupported | `shim-ausente:maps` |
| 684 | `github.com/ipfs/boxo/bitswap/tracer` | bloqueado | `dart:uri_does_not_exist`×2 |
| 685 | `github.com/libp2p/go-libp2p/core/connmgr` | bloqueado | `dart:uri_does_not_exist`×3 |
| 686 | `github.com/libp2p/go-libp2p/core/event` | bloqueado | `dart:uri_does_not_exist`×3, `dart:invalid_constant`, `dart:undefined_getter` |
| 687 | `github.com/libp2p/go-libp2p/core/host` | bloqueado | `dart:uri_does_not_exist`×3 |
| 688 | `github.com/libp2p/go-libp2p-gostream` | unsupported | `shim-ausente:net`×5 |
| 689 | `github.com/libp2p/go-libp2p/core/routing` | unsupported | `shim-ausente:maps`, `shim-ausente:slices` |
| 690 | `github.com/libp2p/go-libp2p/core/sec` | unsupported | `shim-ausente:net`×2 |
| 691 | `github.com/libp2p/go-libp2p/p2p/discovery/backoff` | unsupported | `shim-ausente:math/rand`×9, `shim-ausente:log/slog`×2 |
| 692 | `github.com/libp2p/go-libp2p/p2p/discovery/mdns` | unsupported | `shim-ausente:math/rand`×2, `shim-ausente:log/slog`, `shim-ausente:net` |
| 693 | `github.com/libp2p/go-libp2p/p2p/discovery/routing` | bloqueado | `dart:uri_does_not_exist`×4, `dart:expected_token`×2, `dart:non_bool_negation_expression`×2, `dart:undefined_identifier_await`×2 |
| 694 | `github.com/libp2p/go-libp2p/p2p/host/peerstore` | bloqueado | `dart:invalid_constant`×2, `dart:undefined_getter`×2, `dart:uri_does_not_exist` |
| 695 | `github.com/libp2p/go-libp2p/p2p/host/routed` | unsupported | `shim-ausente:log/slog`×2 |
| 696 | `github.com/libp2p/go-libp2p/p2p/muxer/yamux` | unsupported | `conversao:pointer-pointer`×3, `shim-ausente:log`, `shim-ausente:net` |
| 697 | `github.com/libp2p/go-libp2p/p2p/net/connmgr` | unsupported | `shim-ausente:log/slog`×4, `async:valor-func`, `conversao:pointer-pointer` |
| 698 | `github.com/libp2p/go-libp2p/p2p/net/gostream` | unsupported | `shim-ausente:net`×5 |
| 699 | `github.com/libp2p/go-libp2p/p2p/protocol/circuitv2/proto` | bloqueado | `dart:uri_does_not_exist`×3 |
| 700 | `github.com/libp2p/go-libp2p/p2p/protocol/circuitv2/util` | bloqueado | `dart:uri_does_not_exist`×7, `dart:invalid_constant`, `dart:undefined_getter` |
| 701 | `github.com/libp2p/go-libp2p/p2p/protocol/ping` | unsupported | `shim-ausente:log/slog`×4, `async:valor-func` |
| 702 | `github.com/libp2p/go-libp2p/p2p/security/insecure` | unsupported | `shim-ausente:net`×2 |
| 703 | `github.com/multiformats/go-multiaddr-dns` | unsupported | `shim-ausente:net`×5 |
| 704 | `github.com/multiformats/go-multiaddr-fmt` | bloqueado | `dart:invalid_constant`, `dart:undefined_getter`, `dart:uri_does_not_exist` |
| 705 | `github.com/multiformats/go-multiaddr/net` | unsupported | `shim-ausente:net`×36, `conversao:slice-named-slice`×5, `shim-ausente:net/netip`, `shim-ausente:path/filepath` |
| 706 | `github.com/libp2p/go-libp2p/core/transport` | unsupported | `shim-ausente:net`×2 |
| 707 | `github.com/libp2p/go-libp2p/p2p/canonicallog` | unsupported | `shim-ausente:log/slog`×4, `shim-ausente:math/rand`, `shim-ausente:net` |
| 708 | `github.com/libp2p/go-libp2p/p2p/host/peerstore/pstoremem` | unsupported | `shim-ausente:log/slog`×2, `async:valor-func`, `shim-ausente:container/heap` |
| 709 | `github.com/libp2p/go-libp2p-pubsub` | unsupported | `shim-ausente:log/slog`×31, `shim-ausente:math/rand`×6, `shim-ausente:iter`×4, `async:valor-func`, `shim-ausente:crypto/sha256` (+2) |
| 710 | `github.com/libp2p/go-libp2p/p2p/net/reuseport` | unsupported | `shim-ausente:net`×8, `shim-ausente:log/slog` |
| 711 | `github.com/libp2p/go-libp2p/p2p/net/upgrader` | unsupported | `shim-ausente:net`×3, `async:contexto-sincrono`, `shim-ausente:log/slog` |
| 712 | `github.com/libp2p/go-libp2p/p2p/protocol/circuitv2/client` | unsupported | `shim-ausente:log/slog`×2, `shim-ausente:net`×2, `async:valor-func` |
| 713 | `github.com/libp2p/go-libp2p/p2p/security/noise` | unsupported | `shim-ausente:net`×6, `shim-ausente:slices` |
| 714 | `github.com/libp2p/go-libp2p/p2p/security/tls` | unsupported | `shim-ausente:crypto/x509`×5, `shim-ausente:crypto/tls`×3, `shim-ausente:crypto`, `shim-ausente:net` |
| 715 | `github.com/libp2p/go-libp2p/p2p/transport/tcpreuse/internal/sampledconn` | unsupported | `shim-ausente:net`×3 |
| 716 | `github.com/libp2p/go-libp2p/p2p/transport/tcpreuse` | unsupported | `shim-ausente:net`×3, `shim-ausente:log/slog`×2, `async:valor-func` |
| 717 | `github.com/libp2p/go-libp2p/x/rate` | unsupported | `shim-ausente:net/netip`×5 |
| 718 | `github.com/pion/dtls/v3/pkg/crypto/fingerprint` | unsupported | `shim-ausente:crypto`×3, `shim-ausente:crypto/x509` |
| 719 | `github.com/pion/dtls/v3/pkg/crypto/signaturehash` | unsupported | `shim-ausente:crypto`×3, `shim-ausente:crypto/tls`×2, `shim-ausente:crypto/x509` |
| 720 | `github.com/pion/dtls/v3/pkg/protocol/extension` | unsupported | `shim-ausente:crypto/tls`, `shim-ausente:slices` |
| 721 | `github.com/pion/dtls/v3/pkg/protocol/handshake` | unsupported | `shim-ausente:crypto/tls`×3, `shim-ausente:crypto/rand` |
| 722 | `github.com/pion/dtls/v3/pkg/protocol/recordlayer` | bloqueado | `dart:uri_does_not_exist`×3 |
| 723 | `github.com/pion/dtls/v3/pkg/crypto/ciphersuite` | unsupported | `shim-ausente:crypto/cipher`×5, `shim-ausente:crypto/aes`×3, `shim-ausente:hash` |
| 724 | `github.com/pion/dtls/v3/internal/ciphersuite` | unsupported | `shim-ausente:hash`×15 |
| 725 | `github.com/pion/dtls/v3` | unsupported | `shim-ausente:net`×20, `shim-ausente:crypto/tls`×14, `shim-ausente:crypto/x509`×12, `shim-ausente:crypto`×3, `shim-ausente:crypto/rand`×3 (+5) |
| 726 | `github.com/pion/sdp/v3` | unsupported | `shim-ausente:net/url`×4, `shim-ausente:slices`×2, `async:contexto-sincrono` |
| 727 | `github.com/pion/stun/v3` | unsupported | `shim-ausente:net`×10, `conversao:pointer-pointer`×4, `shim-ausente:crypto/rand`×2, `shim-ausente:net/url`×2, `shim-ausente:crypto/md5` (+5) |
| 728 | `github.com/pion/ice/v4/internal/stun` | unsupported | `shim-ausente:net` |
| 729 | `github.com/pion/turn/v4/internal/proto` | unsupported | `shim-ausente:net`×3 |
| 730 | `github.com/pion/turn/v4/internal/allocation` | unsupported | `shim-ausente:net`×10 |
| 731 | `github.com/pion/turn/v4/internal/client` | unsupported | `shim-ausente:net`×16, `async:valor-func`×2 |
| 732 | `github.com/pion/turn/v4/internal/server` | unsupported | `shim-ausente:net`×7, `shim-ausente:crypto/rand`, `shim-ausente:crypto/sha256` |
| 733 | `github.com/pion/turn/v4` | unsupported | `shim-ausente:net`×18, `shim-ausente:crypto/md5`, `shim-ausente:crypto/sha1` |
| 734 | `github.com/quic-go/quic-go/internal/protocol` | unsupported | `shim-ausente:crypto/rand`×3, `shim-ausente:crypto/tls`×2, `shim-ausente:encoding/hex`×2, `shim-ausente:slices`×2, `shim-ausente:math/rand/v2` |
| 735 | `github.com/quic-go/quic-go/internal/qerr` | unsupported | `shim-ausente:net`×6, `shim-ausente:crypto/tls` |
| 736 | `github.com/quic-go/quic-go/internal/utils` | unsupported | `shim-ausente:bufio`×2, `shim-ausente:crypto/rand`, `shim-ausente:log` |
| 737 | `github.com/quic-go/quic-go/internal/wire` | unsupported | `shim-ausente:crypto/rand`, `shim-ausente:net/netip`, `shim-ausente:slices` |
| 738 | `github.com/quic-go/quic-go/qlogwriter` | unsupported | `shim-ausente:runtime/debug`, `shim-ausente:slices` |
| 739 | `github.com/quic-go/quic-go/qlog` | unsupported | `shim-ausente:encoding/hex`×4, `shim-ausente:net/netip`×2, `shim-ausente:hash/crc32`, `shim-ausente:slices`, `shim-simbolo:os.stat` |
| 740 | `github.com/quic-go/quic-go/internal/congestion` | bloqueado | `dart:unchecked_use_of_nullable_value`×5, `dart:uri_does_not_exist`×4 |
| 741 | `github.com/quic-go/quic-go/internal/ackhandler` | unsupported | `shim-ausente:iter`×3 |
| 742 | `github.com/quic-go/quic-go/internal/handshake` | unsupported | `shim-ausente:crypto/cipher`×16, `shim-ausente:crypto/tls`×7, `shim-ausente:crypto`×6, `shim-ausente:net`×5, `func-sem-corpo` (+1) |
| 743 | `github.com/quic-go/quic-go` | unsupported | `shim-ausente:net`×41, `shim-ausente:crypto/tls`×11, `shim-ausente:syscall`×8, `conversao:pointer-pointer`×7, `shim-ausente:slices`×7 (+8) |
| 744 | `github.com/quic-go/quic-go/http3/qlog` | bloqueado | `dart:uri_does_not_exist`×4 |
| 745 | `go.opentelemetry.io/otel/baggage` | unsupported | `shim-ausente:net/url`×3, `shim-simbolo:strings.splitSeq`×2 |
| 746 | `go.uber.org/dig/internal/digreflect` | unsupported | `shim-ausente:net/url`, `shim-ausente:runtime` |
| 747 | `go.uber.org/dig` | unsupported | `shim-ausente:math/rand`×5, `shim-ausente:container/list` |
| 748 | `go.uber.org/fx/internal/fxreflect` | unsupported | `shim-ausente:runtime`×2, `shim-ausente:net/url` |
| 749 | `golang.org/x/crypto/ocsp` | unsupported | `shim-ausente:crypto/x509` |
| 750 | `golang.org/x/net/proxy` | unsupported | `shim-ausente:net`×6, `shim-ausente:net/url`×4 |
| 751 | `github.com/pion/ice/v4` | unsupported | `shim-ausente:net`×62, `shim-ausente:net/netip`×11 |
| 752 | `github.com/libp2p/go-libp2p/p2p/transport/webrtc/udpmux` | unsupported | `shim-ausente:net`×5, `shim-ausente:log/slog` |
| 753 | `github.com/pion/webrtc/v4/internal/mux` | unsupported | `shim-ausente:net`×3 |
| 754 | `github.com/pion/webrtc/v4` | unsupported | `shim-ausente:crypto`×4, `shim-ausente:crypto/x509`×3, `async:contexto-sincrono`×2, `async:shim-sincrono`×2, `shim-ausente:container/list`×2 (+2) |
| 755 | `google.golang.org/grpc/internal/credentials` | unsupported | `shim-ausente:crypto/tls`×2, `shim-ausente:net`×2, `shim-ausente:crypto/x509` |
| 756 | `google.golang.org/grpc/credentials` | unsupported | `shim-ausente:crypto/tls`×6, `shim-ausente:net`×2, `shim-ausente:crypto/x509`, `shim-simbolo:os.readFile` |
| 757 | `google.golang.org/grpc/credentials/insecure` | unsupported | `shim-ausente:net` |
| 758 | `google.golang.org/grpc/internal/channelz` | unsupported | `shim-ausente:net`, `shim-ausente:syscall` |
| 759 | `google.golang.org/grpc/channelz` | bloqueado |  |
| 760 | `google.golang.org/grpc/peer` | unsupported | `shim-ausente:net` |
| 761 | `google.golang.org/grpc/resolver` | unsupported | `shim-ausente:iter`×2, `shim-ausente:encoding/base64`, `shim-ausente:net`, `shim-ausente:net/url` |
| 762 | `google.golang.org/grpc/balancer` | unsupported | `shim-ausente:net` |
| 763 | `google.golang.org/grpc/balancer/base` | bloqueado | `dart:invalid_constant`×3, `dart:uri_does_not_exist`×3, `dart:undefined_getter`×2, `dart:dot_shorthand_undefined_member`, `dart:expected_token` (+1) |
| 764 | `google.golang.org/grpc/balancer/endpointsharding` | unsupported | `promocao:nao-exportada`, `shim-ausente:math/rand/v2` |
| 765 | `google.golang.org/grpc/balancer/grpclb/state` | bloqueado | `dart:uri_does_not_exist`×2, `dart:invalid_constant`, `dart:undefined_getter` |
| 766 | `google.golang.org/grpc/experimental/balancer/weight` | bloqueado | `dart:uri_does_not_exist`×2 |
| 767 | `google.golang.org/grpc/balancer/pickfirst` | unsupported | `promocao:nao-exportada`, `shim-ausente:cmp`, `shim-ausente:net` |
| 768 | `google.golang.org/grpc/balancer/roundrobin` | bloqueado | `dart:uri_does_not_exist`×3 |
| 769 | `google.golang.org/grpc/internal/balancer/gracefulswitch` | unsupported | `promocao:nao-exportada`×2 |
| 770 | `google.golang.org/grpc/internal/metadata` | bloqueado | `dart:uri_does_not_exist`×2 |
| 771 | `google.golang.org/grpc/internal/proxyattributes` | unsupported | `shim-ausente:net/url` |
| 772 | `google.golang.org/grpc/internal/resolver/dns` | unsupported | `shim-ausente:net`×5, `shim-ausente:net/netip`×2, `shim-ausente:math/rand/v2`, `shim-simbolo:os.hostname` |
| 773 | `google.golang.org/grpc/internal/resolver/passthrough` | bloqueado | `dart:invalid_constant`, `dart:undefined_getter`, `dart:uri_does_not_exist` |
| 774 | `google.golang.org/grpc/internal/serviceconfig` | bloqueado | `dart:uri_does_not_exist` |
| 775 | `google.golang.org/grpc/internal/resolver` | bloqueado | `dart:uri_does_not_exist`×2 |
| 776 | `google.golang.org/grpc/internal/transport/networktype` | bloqueado | `dart:uri_does_not_exist`×2 |
| 777 | `google.golang.org/grpc/internal/resolver/unix` | bloqueado | `dart:invalid_constant`, `dart:undefined_getter`, `dart:uri_does_not_exist` |
| 778 | `google.golang.org/grpc/resolver/dns` | bloqueado | `dart:uri_does_not_exist`×2 |
| 779 | `golang.org/x/net/internal/httpcommon` | unsupported | `shim-ausente:net/textproto`×3, `shim-ausente:net/url`×3 |
| 780 | `github.com/cheggaaa/pb/v3` | unsupported | `shim-ausente:text/template`×6, `shim-ausente:math/rand`×2 |
| 781 | `github.com/whyrusleeping/cbor-gen` | unsupported | `shim-ausente:bufio`×4, `conversao:pointer-pointer`, `shim-ausente:math/big`, `shim-ausente:text/template` |
| 782 | `github.com/ipfs/go-ipld-cbor` | unsupported | `async:contexto-sincrono`, `shim-ausente:bufio`, `shim-ausente:math/big` |
| 783 | `github.com/ipld/go-car/v2/internal/carv1` | bloqueado | `dart:uri_does_not_exist`×3, `dart:invalid_constant`, `dart:undefined_getter` |
| 784 | `github.com/ipld/go-car/v2` | unsupported | `shim-simbolo:os.open`×3, `shim-simbolo:os.openFile`×2, `shim-simbolo:os.create` |
| 785 | `github.com/ipld/go-car/v2/internal/store` | bloqueado | `dart:uri_does_not_exist`×3 |
| 786 | `github.com/ipld/go-car/v2/storage` | bloqueado | `dart:uri_does_not_exist`×2, `dart:argument_type_not_assignable`, `dart:invalid_assignment`, `dart:invalid_constant`, `dart:undefined_getter` |
| 787 | `github.com/ipfs/boxo/gateway/assets` | unsupported | `shim-ausente:html/template` |
| 788 | `github.com/caddyserver/zerossl` | unsupported | `shim-ausente:crypto/x509`×2, `shim-ausente:net/http`×2, `shim-ausente:encoding/base64` |
| 789 | `github.com/felixge/httpsnoop` | unsupported | `shim-ausente:net/http`×521, `shim-ausente:net` |
| 790 | `github.com/getsentry/sentry-go/internal/ratelimit` | unsupported | `shim-ausente:net/http`×2, `branch:goto` |
| 791 | `github.com/gorilla/mux` | unsupported | `shim-ausente:net/http`×25, `shim-ausente:net/url`, `shim-ausente:path` |
| 792 | `github.com/gorilla/websocket` | unsupported | `shim-ausente:net/http`×9, `shim-ausente:net`×7, `shim-ausente:compress/flate`×3, `shim-ausente:crypto/tls`×3, `shim-ausente:crypto/rand`×2 (+6) |
| 793 | `github.com/huin/goupnp/httpu` | unsupported | `shim-ausente:net/http`×7, `shim-ausente:net`×4 |
| 794 | `github.com/huin/goupnp/soap` | unsupported | `shim-ausente:net/url`×4, `shim-ausente:encoding/xml`×3, `shim-ausente:encoding/base64`×2, `shim-ausente:encoding/hex`×2 |
| 795 | `github.com/huin/goupnp/ssdp` | unsupported | `shim-ausente:net/http`×10, `shim-ausente:net/url` |
| 796 | `github.com/huin/goupnp` | unsupported | `shim-ausente:net/url`×12, `shim-ausente:net/http`×4, `shim-ausente:net`×2 |
| 797 | `github.com/huin/goupnp/dcps/internetgateway1` | unsupported | `shim-ausente:net/url`×27, `shim-ausente:net`×9 |
| 798 | `github.com/huin/goupnp/dcps/internetgateway2` | unsupported | `shim-ausente:net/url`×36, `shim-ausente:net`×12 |
| 799 | `github.com/ipfs/boxo/files` | unsupported | `shim-simbolo:io/fs.FileInfo`×18, `shim-ausente:mime/multipart`×6, `async:shim-sincrono`, `shim-ausente:archive/tar`, `shim-ausente:cmp` (+8) |
| 800 | `github.com/ipfs/boxo/tar` | unsupported | `shim-ausente:archive/tar` |
| 801 | `github.com/ipfs/kubo/client/rpc/auth` | unsupported | `shim-ausente:net/http`×2 |
| 802 | `github.com/koron/go-ssdp` | unsupported | `shim-ausente:net`×14, `shim-ausente:net/http`×4, `shim-ausente:bufio`, `shim-ausente:log` |
| 803 | `github.com/libp2p/go-libp2p-http` | unsupported | `shim-ausente:net`, `shim-ausente:net/http` |
| 804 | `github.com/libp2p/go-libp2p/p2p/http/auth/internal/handshake` | unsupported | `shim-ausente:bufio`×2, `shim-ausente:net/http`×2, `shim-ausente:crypto/rand`, `shim-ausente:encoding/base64`, `shim-ausente:hash` (+1) |
| 805 | `github.com/libp2p/go-libp2p/p2p/http/auth` | unsupported | `shim-ausente:net/http`×6, `shim-ausente:crypto/sha256`, `shim-ausente:hash`, `shim-ausente:log/slog` |
| 806 | `github.com/libp2p/go-libp2p/p2p/http` | unsupported | `shim-ausente:net/http`×10, `shim-ausente:net`×2, `shim-ausente:net/url`×2, `shim-ausente:log/slog` |
| 807 | `github.com/libp2p/go-libp2p/p2p/net/nat/internal/nat` | unsupported | `shim-ausente:net`×5, `shim-ausente:log/slog`×3, `shim-ausente:math/rand`×3 |
| 808 | `github.com/libp2p/go-libp2p/p2p/net/nat` | unsupported | `shim-ausente:net/netip`×3, `shim-ausente:log/slog` |
| 809 | `github.com/libp2p/go-libp2p/p2p/transport/websocket` | unsupported | `shim-ausente:net`×8, `shim-ausente:crypto/tls`×5, `shim-ausente:net/url`×3, `shim-ausente:log/slog`×2, `shim-ausente:net/http`×2 |
| 810 | `github.com/mholt/acmez/v3/acme` | unsupported | `shim-ausente:crypto`×9, `shim-ausente:net/http`×4, `shim-ausente:log/slog`×2, `shim-ausente:crypto/sha256`, `shim-ausente:crypto/x509` (+1) |
| 811 | `github.com/mholt/acmez/v3` | unsupported | `shim-ausente:crypto/x509`×7, `shim-ausente:encoding/asn1`×4, `shim-ausente:crypto`×2, `shim-ausente:math/rand`×2, `shim-ausente:crypto/tls` |
| 812 | `github.com/opentracing/opentracing-go` | unsupported | `shim-ausente:net/http` |
| 813 | `github.com/prometheus/client_golang/internal/github.com/golang/gddo/httputil/header` | unsupported | `shim-ausente:net/http` |
| 814 | `github.com/prometheus/client_golang/internal/github.com/golang/gddo/httputil` | unsupported | `shim-ausente:net/http` |
| 815 | `github.com/prometheus/common/expfmt` | unsupported | `shim-ausente:bufio`×5, `shim-ausente:net/http`×3, `shim-simbolo:strings.splitSeq` |
| 816 | `github.com/prometheus/client_golang/prometheus` | unsupported | `shim-ausente:runtime` |
| 817 | `github.com/libp2p/go-libp2p/p2p/metricshelper` | bloqueado | `dart:uri_does_not_exist`×3 |
| 818 | `github.com/libp2p/go-libp2p/p2p/host/eventbus` | unsupported | `shim-ausente:log/slog`×7, `shim-ausente:runtime` |
| 819 | `github.com/libp2p/go-libp2p/p2p/host/autonat` | unsupported | `shim-ausente:log/slog`×4, `shim-ausente:net` |
| 820 | `github.com/libp2p/go-libp2p/p2p/host/blank` | unsupported | `shim-ausente:log/slog`×2, `async:valor-func` |
| 821 | `github.com/libp2p/go-libp2p/p2p/host/pstoremanager` | unsupported | `shim-ausente:log/slog`×2 |
| 822 | `github.com/libp2p/go-libp2p/p2p/host/resource-manager` | unsupported | `shim-ausente:net/netip`×7, `shim-ausente:net`×5, `shim-ausente:log/slog`×4, `async:shim-sincrono`, `conversao:pointer-pointer` (+3) |
| 823 | `github.com/libp2p/go-libp2p/p2p/net/swarm` | unsupported | `shim-ausente:log/slog`×5, `async:contexto-sincrono`×2, `shim-ausente:net`×2, `shim-ausente:net/netip`×2, `shim-ausente:slices` |
| 824 | `github.com/libp2p/go-libp2p/p2p/protocol/autonatv2` | unsupported | `shim-ausente:log/slog`×3, `async:valor-func`×2, `shim-ausente:iter`, `shim-ausente:math/rand`, `shim-ausente:net` |
| 825 | `github.com/libp2p/go-libp2p/p2p/protocol/circuitv2/relay` | unsupported | `shim-ausente:log/slog`×3, `async:valor-func`, `shim-ausente:slices` |
| 826 | `github.com/libp2p/go-libp2p/p2p/host/relaysvc` | bloqueado | `dart:uri_does_not_exist`×3, `dart:unnecessary_cast` |
| 827 | `github.com/libp2p/go-libp2p/p2p/protocol/identify` | unsupported | `shim-ausente:log/slog`×3, `shim-ausente:slices`×3, `conversao:pointer-pointer`×2, `shim-ausente:net/netip` |
| 828 | `github.com/libp2p/go-libp2p/p2p/host/autorelay` | unsupported | `shim-ausente:log/slog`×3 |
| 829 | `github.com/libp2p/go-libp2p/p2p/protocol/holepunch` | unsupported | `shim-ausente:log/slog`×4, `conversao:pointer-pointer`×2, `shim-ausente:slices` |
| 830 | `github.com/libp2p/go-libp2p/p2p/host/basic` | unsupported | `shim-ausente:log/slog`×6, `shim-ausente:slices`×6, `async:valor-func`, `conversao:pointer-pointer`, `shim-ausente:maps` (+1) |
| 831 | `github.com/libp2p/go-libp2p/p2p/host/observedaddrs` | unsupported | `shim-ausente:log/slog`×3, `shim-ausente:net` |
| 832 | `github.com/libp2p/go-libp2p/p2p/transport/quicreuse` | unsupported | `shim-ausente:net`×20, `shim-ausente:crypto/tls`×4, `shim-ausente:log/slog` |
| 833 | `github.com/libp2p/go-libp2p/p2p/transport/quic` | unsupported | `shim-ausente:log/slog`×3, `shim-ausente:net`×2, `shim-ausente:math/rand` |
| 834 | `github.com/libp2p/go-libp2p/p2p/transport/tcp` | unsupported | `shim-ausente:net`×8, `shim-ausente:log/slog`×2 |
| 835 | `github.com/libp2p/go-libp2p/p2p/transport/webrtc` | unsupported | `shim-ausente:log/slog`×6, `shim-ausente:net`×6, `shim-ausente:crypto`×3, `shim-ausente:encoding/hex`×2, `shim-ausente:crypto/rand` (+3) |
| 836 | `github.com/prometheus/client_golang/prometheus/promauto` | bloqueado | `dart:uri_does_not_exist` |
| 837 | `github.com/prometheus/client_golang/prometheus/promhttp` | unsupported | `shim-ausente:net/http` |
| 838 | `github.com/prometheus/statsd_exporter/pkg/mapper` | unsupported | `shim-simbolo:os.readFile` |
| 839 | `contrib.go.opencensus.io/exporter/prometheus` | unsupported | `shim-ausente:log`, `shim-ausente:net/http` |
| 840 | `github.com/quic-go/quic-go/http3` | unsupported | `shim-ausente:net/http`×21, `shim-ausente:net/http/httptrace`×15, `shim-ausente:net`×9, `shim-ausente:log/slog`×4, `shim-ausente:crypto/tls`×2 (+5) |
| 841 | `github.com/quic-go/webtransport-go` | unsupported | `async:valor-func`×4, `shim-ausente:net`×3, `shim-ausente:net/http`×3, `constraint:ponteiro`×2, `shim-ausente:math/rand/v2` (+1) |
| 842 | `github.com/libp2p/go-libp2p/p2p/transport/webtransport` | unsupported | `shim-ausente:net`×6, `shim-ausente:crypto/tls`×5, `shim-ausente:crypto/sha256`×3, `shim-ausente:log/slog`×2, `shim-ausente:crypto` (+2) |
| 843 | `github.com/rs/cors` | unsupported | `shim-ausente:net/http`×2, `shim-ausente:log` |
| 844 | `github.com/slok/go-http-metrics/metrics/prometheus` | bloqueado | `dart:uri_does_not_exist` |
| 845 | `github.com/slok/go-http-metrics/middleware/std` | unsupported | `shim-ausente:net/http`×4 |
| 846 | `go.opencensus.io/trace/propagation` | unsupported | `shim-ausente:net/http` |
| 847 | `go.opencensus.io/plugin/ocgrpc` | bloqueado | `dart:uri_does_not_exist`×4, `dart:invalid_constant`×2, `dart:undefined_getter`×2 |
| 848 | `go.opencensus.io/zpages/internal` | unsupported | `shim-ausente:net/http`×7, `shim-ausente:io/ioutil` |
| 849 | `go.opencensus.io/zpages` | unsupported | `async:shim-sincrono`×8, `shim-ausente:net/http`×6, `shim-ausente:html/template`×3, `shim-ausente:log` |
| 850 | `go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp/internal/request` | unsupported | `shim-ausente:net/http`×2 |
| 851 | `go.opentelemetry.io/otel/propagation` | unsupported | `shim-ausente:encoding/hex`×2 |
| 852 | `go.opentelemetry.io/contrib/propagators/b3` | bloqueado | `dart:uri_does_not_exist`×2 |
| 853 | `go.opentelemetry.io/contrib/propagators/jaeger` | bloqueado | `dart:uri_does_not_exist`×2 |
| 854 | `go.opentelemetry.io/contrib/propagators/ot` | bloqueado | `dart:uri_does_not_exist`×3, `dart:invalid_constant`×2, `dart:undefined_getter`×2 |
| 855 | `go.opentelemetry.io/otel/internal/global` | unsupported | `promocao:nao-exportada`×20, `shim-ausente:container/list`, `shim-ausente:log` |
| 856 | `go.opentelemetry.io/otel` | bloqueado | `dart:uri_does_not_exist`×5 |
| 857 | `github.com/ipfs/boxo/bitswap/client/internal` | bloqueado | `dart:uri_does_not_exist` |
| 858 | `github.com/ipfs/boxo/bitswap/internal` | bloqueado | `dart:uri_does_not_exist` |
| 859 | `github.com/ipfs/boxo/blockservice/internal` | bloqueado | `dart:uri_does_not_exist` |
| 860 | `github.com/libp2p/go-libp2p-kad-dht/internal` | unsupported | `tipo-nomeado:chan` |
| 861 | `github.com/libp2p/go-libp2p-routing-helpers/tracing` | bloqueado | `dart:uri_does_not_exist`×9, `dart:invalid_constant`, `dart:undefined_getter` |
| 862 | `go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp/internal/semconv` | unsupported | `shim-ausente:net/http`×3, `shim-ausente:net` |
| 863 | `go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp` | unsupported | `shim-ausente:net/http`×12, `shim-ausente:net/http/httptrace` |
| 864 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc/internal/envconfig` | unsupported | `shim-ausente:crypto/x509`×2, `shim-ausente:net/url`×2, `shim-ausente:crypto/tls` |
| 865 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc/internal/observ` | unsupported | `shim-ausente:net`, `shim-ausente:net/netip` |
| 866 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp/internal/envconfig` | unsupported | `shim-ausente:crypto/x509`×2, `shim-ausente:net/url`×2, `shim-ausente:crypto/tls` |
| 867 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp/internal/observ` | unsupported | `shim-ausente:net`, `shim-ausente:net/netip` |
| 868 | `go.opentelemetry.io/otel/exporters/prometheus/internal/observ` | bloqueado | `dart:uri_does_not_exist`×3, `dart:invalid_constant`, `dart:undefined_getter` |
| 869 | `go.opentelemetry.io/otel/exporters/stdout/stdouttrace/internal/observ` | bloqueado | `dart:uri_does_not_exist`×3, `dart:invalid_constant`, `dart:undefined_getter` |
| 870 | `go.opentelemetry.io/otel/sdk/metric/internal/observ` | bloqueado | `dart:uri_does_not_exist`×3, `dart:invalid_constant`, `dart:undefined_getter` |
| 871 | `go.opentelemetry.io/otel/sdk/resource` | unsupported | `async:shim-sincrono`×2, `shim-ausente:os/user`×2, `shim-simbolo:os.open`×2, `shim-ausente:net/url`, `shim-ausente:path/filepath` (+7) |
| 872 | `go.opentelemetry.io/otel/sdk/metric/metricdata` | bloqueado | `dart:uri_does_not_exist`×2, `dart:invalid_constant`, `dart:undefined_getter` |
| 873 | `go.opentelemetry.io/otel/sdk/metric/internal/aggregate` | unsupported | `async:valor-func`×4, `shim-ausente:slices`×2, `shim-ausente:runtime`, `shim-simbolo:sort.searchFloat64s` |
| 874 | `go.opentelemetry.io/otel/sdk/metric` | unsupported | `promocao:nao-exportada`×14, `async:contexto-sincrono`, `async:valor-func`, `shim-ausente:container/list`, `shim-ausente:runtime` (+1) |
| 875 | `go.opentelemetry.io/otel/exporters/prometheus` | unsupported | `shim-ausente:slices`×2, `promocao:nao-exportada`, `shim-ausente:encoding/hex` |
| 876 | `go.opentelemetry.io/otel/sdk/trace/internal/env` | bloqueado | `dart:uri_does_not_exist` |
| 877 | `go.opentelemetry.io/otel/sdk/trace/internal/observ` | bloqueado | `dart:uri_does_not_exist`×4, `dart:invalid_constant`, `dart:undefined_getter` |
| 878 | `go.opentelemetry.io/otel/sdk/trace` | unsupported | `promocao:nao-exportada`×4, `shim-ausente:runtime`, `shim-ausente:slices`, `shim-simbolo:encoding/binary.NativeEndian._littleEndian` |
| 879 | `go.opentelemetry.io/contrib/propagators/aws/xray` | unsupported | `shim-ausente:crypto/rand`, `shim-ausente:encoding/hex`, `shim-ausente:math/rand` |
| 880 | `go.opentelemetry.io/contrib/propagators/autoprop` | bloqueado | `dart:uri_does_not_exist`×2 |
| 881 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/internal/tracetransform` | bloqueado | `dart:uri_does_not_exist`×8, `dart:invalid_constant`, `dart:undefined_getter` |
| 882 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace` | bloqueado | `dart:uri_does_not_exist`×2 |
| 883 | `go.opentelemetry.io/otel/sdk/trace/tracetest` | unsupported | `promocao:nao-exportada` |
| 884 | `go.opentelemetry.io/otel/exporters/stdout/stdouttrace` | bloqueado | `dart:uri_does_not_exist`×2 |
| 885 | `go.opentelemetry.io/otel/semconv/internal` | unsupported | `shim-ausente:net`, `shim-ausente:net/http` |
| 886 | `go.opentelemetry.io/otel/semconv/v1.4.0` | unsupported | `shim-ausente:net/http`×5 |
| 887 | `go.uber.org/zap` | unsupported | `shim-ausente:log`×3, `shim-ausente:net/http`×3, `shim-ausente:net/url`×3, `async:contexto-sincrono`×2, `shim-ausente:flag` |
| 888 | `github.com/ipfs/go-log/v2` | unsupported | `shim-ausente:log/slog`×11, `shim-ausente:path/filepath`, `shim-simbolo:os.openFile` |
| 889 | `github.com/ipfs-shipyard/nopfs` | unsupported | `shim-ausente:bufio`×2, `shim-ausente:net/url`, `shim-ausente:path/filepath`, `shim-simbolo:io/fs.DirEntry`, `shim-simbolo:os.open` (+2) |
| 890 | `github.com/ipfs/boxo/autoconf` | unsupported | `shim-ausente:net/http`×4, `shim-ausente:slices`×4, `shim-ausente:math/rand/v2`, `shim-ausente:net/url`, `shim-simbolo:os.writeFile` |
| 891 | `github.com/ipfs/boxo/bitswap/client/internal/getter` | bloqueado | `dart:uri_does_not_exist`×6, `dart:expected_token`×2, `dart:invalid_constant`×2, `dart:non_bool_negation_expression`×2, `dart:undefined_getter`×2 (+1) |
| 892 | `github.com/ipfs/boxo/bitswap/client/internal/sessionpeermanager` | bloqueado | `dart:uri_does_not_exist`×2, `dart:invalid_constant`, `dart:undefined_getter` |
| 893 | `github.com/ipfs/boxo/bitswap/network` | unsupported | `shim-ausente:net`, `shim-ausente:net/url` |
| 894 | `github.com/ipfs/boxo/bitswap/client/internal/messagequeue` | unsupported | `branch:goto` |
| 895 | `github.com/ipfs/boxo/bitswap/network/bsnet` | unsupported | `async:valor-func`×2, `conversao:pointer-pointer` |
| 896 | `github.com/ipfs/boxo/bitswap/network/httpnet` | unsupported | `shim-ausente:net/http`×2, `shim-ausente:net`, `shim-ausente:runtime/debug`, `shim-ausente:slices` |
| 897 | `github.com/ipfs/boxo/bootstrap` | unsupported | `shim-ausente:math/rand/v2` |
| 898 | `github.com/ipfs/boxo/chunker` | unsupported | `shim-ausente:hash/fnv` |
| 899 | `github.com/ipfs/boxo/ipns` | unsupported | `shim-ausente:cmp`, `shim-ausente:iter`, `shim-simbolo:fmt.append$` |
| 900 | `github.com/ipfs/boxo/keystore` | unsupported | `shim-ausente:encoding/base32`×4, `shim-ausente:path/filepath`, `shim-simbolo:os.mkdir` |
| 901 | `github.com/ipfs/boxo/path/resolver` | unsupported | `shim-ausente:slices` |
| 902 | `github.com/ipfs/boxo/peering` | unsupported | `conversao:pointer-pointer`×2, `shim-ausente:slices` |
| 903 | `github.com/ipfs/boxo/bitswap/client/internal/peermanager` | bloqueado | `dart:uri_does_not_exist`×6, `dart:argument_type_not_assignable`×3, `dart:invalid_constant`×2, `dart:undefined_getter`×2 |
| 904 | `github.com/ipfs/boxo/bitswap/client/internal/session` | unsupported | `shim-ausente:slices`×2, `async:valor-func`, `shim-ausente:math/rand/v2` |
| 905 | `github.com/ipfs/boxo/bitswap/client/internal/sessionmanager` | bloqueado | `dart:uri_does_not_exist`×7, `dart:invalid_constant`×2, `dart:undefined_getter`×2 |
| 906 | `github.com/ipfs/boxo/routing/http/filters` | unsupported | `async:valor-func`, `shim-ausente:net/url`, `shim-ausente:slices` |
| 907 | `github.com/ipfs/boxo/routing/http/server` | unsupported | `shim-ausente:net/http`×9 |
| 908 | `github.com/ipfs/boxo/routing/providerquerymanager` | bloqueado | `dart:uri_does_not_exist`×10, `dart:invalid_constant`×4, `dart:undefined_getter`×4 |
| 909 | `github.com/ipfs/go-ds-flatfs` | unsupported | `shim-ausente:path/filepath`×5, `shim-simbolo:os.open`×4, `shim-simbolo:os.mkdir`×2, `shim-simbolo:os.stat`×2, `shim-ausente:syscall` (+6) |
| 910 | `github.com/ipfs/go-dsqueue` | unsupported | `shim-ausente:encoding/base64`×2 |
| 911 | `github.com/ipfs/boxo/provider` | unsupported | `async:valor-func` |
| 912 | `github.com/ipfs/boxo/blockstore` | unsupported | `async:valor-func` |
| 913 | `github.com/ipfs/boxo/bitswap/client` | bloqueado | `dart:uri_does_not_exist`×13, `dart:argument_type_not_assignable`×2, `dart:invalid_constant`×2, `dart:undefined_getter`×2, `dart:invalid_assignment` |
| 914 | `github.com/ipfs/boxo/bitswap/server/internal/decision` | unsupported | `shim-ausente:hash/maphash`×3, `async:valor-func`×2, `shim-ausente:slices` |
| 915 | `github.com/ipfs/boxo/bitswap/server` | unsupported | `shim-ausente:slices` |
| 916 | `github.com/ipfs/boxo/bitswap` | bloqueado | `dart:uri_does_not_exist`×10, `dart:argument_type_not_assignable`, `dart:invalid_constant`, `dart:invalid_override`, `dart:override_on_non_overriding_member` (+1) |
| 917 | `github.com/ipfs/boxo/blockservice` | bloqueado | `dart:uri_does_not_exist`×7, `dart:invalid_constant`×2, `dart:undefined_getter`×2 |
| 918 | `github.com/ipfs/boxo/exchange/offline` | bloqueado | `dart:uri_does_not_exist`×4 |
| 919 | `github.com/ipfs/boxo/fetcher/impl/blockservice` | bloqueado | `dart:uri_does_not_exist`×2 |
| 920 | `github.com/ipfs/boxo/filestore` | unsupported | `shim-ausente:cmp`, `shim-ausente:path/filepath`, `shim-simbolo:os.File.readAt`, `shim-simbolo:os.open` |
| 921 | `github.com/ipfs/boxo/ipld/merkledag` | unsupported | `shim-ausente:slices`×2, `async:contexto-sincrono` |
| 922 | `github.com/ipfs/boxo/ipld/merkledag/dagutils` | unsupported | `shim-ausente:path` |
| 923 | `github.com/ipfs/boxo/ipld/merkledag/test` | bloqueado | `dart:uri_does_not_exist`×6, `dart:invalid_constant`×2, `dart:undefined_getter`×2 |
| 924 | `github.com/ipfs/boxo/ipld/unixfs` | bloqueado | `dart:uri_does_not_exist`×5 |
| 925 | `github.com/ipfs/boxo/dag/walker` | unsupported | `shim-ausente:crypto/rand`, `shim-ausente:slices` |
| 926 | `github.com/ipfs/boxo/ipld/unixfs/hamt` | unsupported | `async:valor-func`, `shim-ausente:hash`, `shim-ausente:slices` |
| 927 | `github.com/ipfs/boxo/ipld/unixfs/importer/helpers` | unsupported | `shim-simbolo:io/fs.FileInfo` |
| 928 | `github.com/ipfs/boxo/ipld/unixfs/importer/balanced` | bloqueado | `dart:uri_does_not_exist`×3 |
| 929 | `github.com/ipfs/boxo/ipld/unixfs/importer/trickle` | bloqueado | `dart:uri_does_not_exist`×5 |
| 930 | `github.com/ipfs/boxo/ipld/unixfs/io` | unsupported | `async:contexto-sincrono` |
| 931 | `github.com/ipfs/boxo/ipld/unixfs/file` | bloqueado | `dart:uri_does_not_exist`×5 |
| 932 | `github.com/ipfs/boxo/ipld/unixfs/mod` | unsupported | `async:contexto-sincrono` |
| 933 | `github.com/ipfs/boxo/mfs` | unsupported | `async:contexto-sincrono`×4, `shim-ausente:path`×2 |
| 934 | `github.com/ipfs/boxo/pinning/pinner/dspinner` | unsupported | `shim-ausente:path`×3, `async:valor-func`×2 |
| 935 | `github.com/ipfs/go-fs-lock` | unsupported | `shim-ausente:path/filepath`×2, `branch:goto`, `shim-ausente:syscall`, `shim-simbolo:os.lstat` |
| 936 | `github.com/ipfs/go-ipfs-cmds` | unsupported | `conversao:chan-chan`×2, `shim-ausente:encoding/xml`×2, `async:contexto-sincrono`, `async:shim-sincrono`, `conversao:pointer-pointer` (+2) |
| 937 | `github.com/ipfs/go-ipfs-cmds/cli` | unsupported | `shim-ausente:net/url`×3, `shim-ausente:text/template`×3, `async:shim-sincrono`×2, `shim-ausente:syscall`, `shim-simbolo:os.File.stat` (+2) |
| 938 | `github.com/ipfs/go-ipfs-cmds/http` | unsupported | `shim-ausente:net/http`×21, `shim-ausente:net/url` |
| 939 | `github.com/ipfs/go-metrics-prometheus` | unsupported | `promocao:nao-exportada` |
| 940 | `github.com/ipfs/kubo/blocks/blockstoreutil` | bloqueado | `dart:uri_does_not_exist`×3, `dart:invalid_constant`, `dart:undefined_getter` |
| 941 | `github.com/ipfs/kubo/cmd/ipfs/util` | unsupported | `shim-ausente:syscall`×2, `shim-simbolo:os.Signal` |
| 942 | `github.com/ipfs/kubo/core/commands/keyencode` | bloqueado | `dart:uri_does_not_exist`×3 |
| 943 | `github.com/ipfs/kubo/core/shutdown` | bloqueado | `dart:uri_does_not_exist` |
| 944 | `github.com/ipfs/kubo/fuse/mount` | unsupported | `shim-ausente:os/exec`×2, `shim-ausente:crypto/sha256`, `shim-ausente:syscall` |
| 945 | `github.com/ipfs/kubo/fuse/writable` | unsupported | `shim-ausente:syscall`×5 |
| 946 | `github.com/ipfs/kubo/gc` | unsupported | `async:valor-func` |
| 947 | `github.com/ipfs/kubo/p2p` | unsupported | `async:valor-func` |
| 948 | `github.com/ipfs/kubo/thirdparty/verifbs` | bloqueado | `dart:uri_does_not_exist`×3 |
| 949 | `github.com/libp2p/go-doh-resolver` | unsupported | `shim-ausente:net`×5, `shim-ausente:net/http` |
| 950 | `github.com/libp2p/go-libp2p-kad-dht/pb` | unsupported | `unsafe:Pointer`×2 |
| 951 | `github.com/libp2p/go-libp2p-kad-dht/internal/metrics` | bloqueado | `dart:uri_does_not_exist`×3, `dart:invalid_constant`, `dart:undefined_getter` |
| 952 | `github.com/libp2p/go-libp2p-kad-dht/internal/net` | unsupported | `shim-ausente:bufio`×2, `async:shim-sincrono` |
| 953 | `github.com/libp2p/go-libp2p-kad-dht/records` | unsupported | `shim-ausente:maps`, `shim-ausente:math/rand/v2`, `shim-ausente:slices` |
| 954 | `github.com/ipfs/boxo/routing/offline` | bloqueado | `dart:uri_does_not_exist`×6 |
| 955 | `github.com/libp2p/go-libp2p-kbucket/peerdiversity` | unsupported | `shim-ausente:net`×2, `shim-ausente:maps` |
| 956 | `github.com/libp2p/go-libp2p-kad-dht/internal/config` | bloqueado | `dart:uri_does_not_exist`×10 |
| 957 | `github.com/libp2p/go-libp2p-kbucket` | unsupported | `shim-ausente:container/list`×4, `async:valor-func`, `shim-ausente:crypto/rand` |
| 958 | `github.com/libp2p/go-libp2p-kad-dht/crawler` | unsupported | `shim-ausente:slices` |
| 959 | `github.com/libp2p/go-libp2p-kad-dht/netsize` | unsupported | `shim-ausente:math/big`×4 |
| 960 | `github.com/libp2p/go-libp2p-kad-dht/provider/internal/keyspace` | unsupported | `shim-ausente:iter`×4, `shim-ausente:crypto/sha256`×2, `shim-ausente:cmp`, `shim-ausente:slices` |
| 961 | `github.com/libp2p/go-libp2p-kad-dht/provider/internal/queue` | unsupported | `shim-ausente:slices` |
| 962 | `github.com/libp2p/go-libp2p-kad-dht/provider/internal/timeseries` | bloqueado | `dart:uri_does_not_exist`×4, `dart:invalid_constant`, `dart:undefined_getter` |
| 963 | `github.com/libp2p/go-libp2p-kad-dht/provider/keystore` | unsupported | `shim-ausente:encoding/base64`×2, `async:valor-func` |
| 964 | `github.com/libp2p/go-libp2p-kad-dht/provider` | unsupported | `async:valor-func`, `shim-ausente:crypto/rand`, `shim-simbolo:fmt.sscanf` |
| 965 | `github.com/libp2p/go-libp2p-kad-dht/provider/buffered` | bloqueado | `dart:uri_does_not_exist`×4 |
| 966 | `github.com/libp2p/go-libp2p-kad-dht/rtrefresh` | bloqueado | `dart:uri_does_not_exist`×7, `dart:expected_token`×4, `dart:non_bool_negation_expression`×4, `dart:undefined_identifier_await`×4, `dart:invalid_constant` (+1) |
| 967 | `github.com/libp2p/go-libp2p-kad-dht` | unsupported | `shim-ausente:net`×8, `shim-ausente:math/rand/v2`×2, `shim-ausente:testing`×2, `async:valor-func`, `shim-ausente:iter` (+1) |
| 968 | `github.com/ipfs/boxo/namesys` | unsupported | `shim-ausente:net`, `shim-ausente:path`, `shim-simbolo:strings.splitSeq` |
| 969 | `github.com/ipfs-shipyard/nopfs/ipfs` | bloqueado | `dart:uri_does_not_exist`×9, `dart:invalid_constant`, `dart:undefined_getter` |
| 970 | `github.com/ipfs/boxo/namesys/republisher` | bloqueado | `dart:uri_does_not_exist`×10, `dart:expected_token`×2, `dart:non_bool_negation_expression`×2, `dart:undefined_identifier_await`×2, `dart:invalid_constant` (+1) |
| 971 | `github.com/ipfs/kubo/core/coreiface/options` | bloqueado | `dart:uri_does_not_exist`×5 |
| 972 | `github.com/ipfs/kubo/core/coreiface` | unsupported | `shim-ausente:iter` |
| 973 | `github.com/ipfs/kubo/core/commands/cmdutils` | unsupported | `shim-ausente:slices` |
| 974 | `github.com/ipfs/kubo` | unsupported | `shim-ausente:runtime`, `shim-ausente:runtime/debug` |
| 975 | `github.com/ipfs/kubo/profile` | unsupported | `async:shim-sincrono`×5, `shim-ausente:runtime`×3, `shim-ausente:archive/zip`×2, `shim-simbolo:os.executable` |
| 976 | `github.com/libp2p/go-libp2p-pubsub-router` | unsupported | `async:valor-func`, `shim-ausente:encoding/base64` |
| 977 | `github.com/libp2p/go-libp2p-routing-helpers` | unsupported | `async:valor-func`×2, `async:contexto-sincrono` |
| 978 | `github.com/ipfs/boxo/gateway` | unsupported | `shim-ausente:net/http`×54, `shim-ausente:net/textproto`×4, `shim-ausente:net`×3, `shim-ausente:net/url`×2, `shim-ausente:path`×2 (+3) |
| 979 | `github.com/ipfs/boxo/routing/http/contentrouter` | unsupported | `async:valor-func` |
| 980 | `github.com/ipfs/boxo/routing/http/client` | unsupported | `shim-ausente:net/http`×5, `shim-ausente:net/url`×2, `shim-ausente:slices`×2, `shim-ausente:net`, `shim-ausente:runtime/debug` |
| 981 | `github.com/libp2p/go-libp2p-kad-dht/dual` | bloqueado | `dart:uri_does_not_exist`×12, `dart:expected_token`×4, `dart:non_bool_negation_expression`×4, `dart:undefined_identifier_await`×4, `dart:invalid_constant`×3 (+1) |
| 982 | `github.com/libp2p/go-libp2p-kad-dht/provider/dual` | bloqueado | `dart:uri_does_not_exist`×8 |
| 983 | `github.com/libp2p/go-libp2p-xor/key` | unsupported | `shim-ausente:math/big`×2 |
| 984 | `github.com/libp2p/go-libp2p-xor/trie` | bloqueado | `dart:uri_does_not_exist` |
| 985 | `github.com/libp2p/go-libp2p-xor/kademlia` | bloqueado | `dart:uri_does_not_exist` |
| 986 | `github.com/libp2p/go-libp2p-kad-dht/fullrt` | unsupported | `shim-ausente:maps`, `shim-ausente:slices` |
| 987 | `github.com/libp2p/go-socket-activation` | unsupported | `shim-ausente:net`, `shim-ausente:syscall` |
| 988 | `go.uber.org/fx/fxevent` | unsupported | `shim-ausente:log/slog`×5, `shim-simbolo:os.Signal` |
| 989 | `go.uber.org/fx/internal/fxlog` | bloqueado | `dart:uri_does_not_exist` |
| 990 | `go.uber.org/fx/internal/lifecycle` | bloqueado | `dart:uri_does_not_exist`×2 |
| 991 | `go.uber.org/fx` | unsupported | `async:valor-func`×6, `shim-simbolo:os.Signal`×4, `shim-ausente:syscall`×2, `shim-ausente:os/signal` |
| 992 | `github.com/ipfs/kubo/core/node/helpers` | bloqueado | `dart:argument_type_not_assignable`, `dart:uri_does_not_exist` |
| 993 | `github.com/libp2p/go-libp2p/config` | unsupported | `shim-ausente:crypto/sha256`×2, `shim-ausente:log/slog`×2, `shim-simbolo:os.Signal`×2 |
| 994 | `github.com/libp2p/go-libp2p` | unsupported | `shim-ausente:crypto/rand`×2, `conversao:pointer-pointer` |
| 995 | `go.uber.org/zap/exp/zapslog` | unsupported | `shim-ausente:log/slog`×6 |
| 996 | `github.com/caddyserver/certmagic` | unsupported | `shim-ausente:net/http`×12, `shim-ausente:crypto/tls`×11, `shim-ausente:net`×11, `shim-ausente:crypto/x509`×8, `shim-ausente:crypto`×4 (+11) |
| 997 | `golang.org/x/net/http2` | unsupported | `shim-ausente:net/http`×44, `shim-ausente:net`×13, `shim-ausente:net/http/httptrace`×6, `shim-ausente:compress/gzip`×4, `shim-ausente:log`×3 (+9) |
| 998 | `golang.org/x/net/trace` | unsupported | `shim-ausente:net/http`×8, `shim-ausente:html/template`×7, `shim-ausente:runtime`×3, `shim-ausente:net/url`, `shim-ausente:text/tabwriter` |
| 999 | `github.com/dgraph-io/badger/y` | unsupported | `shim-simbolo:os.openFile`×4, `shim-ausente:log`×3, `shim-ausente:expvar`×2, `shim-ausente:hash/crc32`×2, `shim-ausente:container/heap` (+1) |
| 1000 | `github.com/dgraph-io/badger/skl` | unsupported | `unsafe:Pointer` |
| 1001 | `github.com/dgraph-io/badger/table` | unsupported | `shim-ausente:path`, `shim-ausente:path/filepath`, `shim-simbolo:os.File.stat`, `shim-simbolo:os.File.truncate` |
| 1002 | `github.com/dgraph-io/badger` | unsupported | `shim-ausente:bufio`×3, `shim-ausente:log`×3, `shim-ausente:path/filepath`×3, `shim-ausente:hash/crc32`×2, `shim-ausente:math/rand`×2 (+12) |
| 1003 | `github.com/ipfs/go-ds-badger` | unsupported | `shim-ausente:runtime`×2 |
| 1004 | `golang.org/x/oauth2/internal` | unsupported | `shim-ausente:net/http`×3, `shim-ausente:net/url`×3, `shim-ausente:crypto/rsa` |
| 1005 | `golang.org/x/oauth2` | unsupported | `shim-ausente:net/http`×5, `shim-ausente:net/url`×5, `conversao:pointer-pointer`, `shim-ausente:crypto/rand`, `shim-ausente:crypto/sha256` |
| 1006 | `github.com/ipshipyard/p2p-forge/client` | unsupported | `shim-ausente:net/http`×10, `shim-ausente:crypto/x509`×2, `shim-ausente:net`×2, `shim-ausente:crypto/tls`, `shim-ausente:encoding/pem` (+1) |
| 1007 | `github.com/getsentry/sentry-go/internal/debug` | unsupported | `shim-ausente:net/http` |
| 1008 | `github.com/getsentry/sentry-go` | unsupported | `shim-ausente:log`×11, `shim-ausente:net/http`×9, `shim-ausente:runtime`×7, `conversao:pointer-pointer`×3, `shim-ausente:net/url`×3 (+12) |
| 1009 | `github.com/cockroachdb/errors/withstack` | unsupported | `async:contexto-sincrono`, `shim-ausente:go/build`, `shim-ausente:path/filepath`, `shim-ausente:runtime` |
| 1010 | `github.com/cockroachdb/errors/errutil` | unsupported | `async:contexto-sincrono`×3, `shim-ausente:runtime` |
| 1011 | `github.com/cockroachdb/errors/report` | bloqueado | `dart:uri_does_not_exist`×5, `dart:invalid_constant`×2, `dart:undefined_getter`×2 |
| 1012 | `github.com/cockroachdb/errors` | bloqueado | `dart:uri_does_not_exist`×16 |
| 1013 | `github.com/cockroachdb/errors/oserror` | bloqueado | `dart:uri_does_not_exist` |
| 1014 | `github.com/cockroachdb/pebble/v2/internal/dsl` | unsupported | `shim-ausente:go/token`×6, `async:valor-func` |
| 1015 | `github.com/cockroachdb/pebble/v2/vfs` | unsupported | `async:contexto-sincrono`×6, `shim-ausente:syscall`×5, `shim-simbolo:io/fs.FileInfo`×4, `shim-ausente:maps`×2, `shim-simbolo:io/fs.DirEntry`×2 (+4) |
| 1016 | `github.com/cockroachdb/pebble/v2/internal/base` | unsupported | `async:contexto-sincrono`×3, `shim-ausente:slices`×2, `async:valor-func`, `shim-ausente:cmp`, `shim-ausente:log` (+1) |
| 1017 | `github.com/cockroachdb/pebble/v2/batchrepr` | unsupported | `unsafe:Pointer` |
| 1018 | `github.com/cockroachdb/pebble/v2/bloom` | bloqueado | `dart:uri_does_not_exist` |
| 1019 | `github.com/cockroachdb/pebble/v2/internal/arenaskl` | unsupported | `unsafe:Pointer`×3 |
| 1020 | `github.com/cockroachdb/pebble/v2/internal/batchskl` | unsupported | `shim-ausente:math/rand/v2` |
| 1021 | `github.com/cockroachdb/pebble/v2/internal/cache` | unsupported | `shim-ausente:runtime`×3, `unsafe:Pointer`×3, `generico:ptr-valor`, `promocao:nao-exportada`, `shim-ausente:runtime/debug` (+1) |
| 1022 | `github.com/cockroachdb/pebble/v2/internal/compression` | unsupported | `shim-ausente:math/rand/v2` |
| 1023 | `github.com/cockroachdb/pebble/v2/internal/invalidating` | unsupported | `shim-ausente:slices` |
| 1024 | `github.com/cockroachdb/pebble/v2/internal/keyspan` | unsupported | `shim-ausente:slices`×4, `shim-ausente:cmp`×2, `async:valor-func` |
| 1025 | `github.com/cockroachdb/pebble/v2/internal/private` | bloqueado | `dart:uri_does_not_exist`×2 |
| 1026 | `github.com/cockroachdb/pebble/v2/internal/problemspans` | bloqueado | `dart:uri_does_not_exist`×4 |
| 1027 | `github.com/cockroachdb/pebble/v2/internal/rangedel` | bloqueado | `dart:uri_does_not_exist`×2 |
| 1028 | `github.com/cockroachdb/pebble/v2/internal/rangekey` | unsupported | `shim-ausente:slices` |
| 1029 | `github.com/cockroachdb/pebble/v2/internal/sstableinternal` | bloqueado | `dart:uri_does_not_exist`×2 |
| 1030 | `github.com/cockroachdb/pebble/v2/internal/strparse` | bloqueado | `dart:uri_does_not_exist` |
| 1031 | `github.com/cockroachdb/pebble/v2/internal/testkeys` | unsupported | `async:valor-func`, `branch:goto`, `shim-ausente:cmp`, `shim-ausente:math/rand/v2` |
| 1032 | `github.com/cockroachdb/pebble/v2/objstorage/remote` | unsupported | `shim-ausente:path` |
| 1033 | `github.com/cockroachdb/pebble/v2/objstorage/objstorageprovider/sharedcache` | bloqueado | `dart:uri_does_not_exist`×4 |
| 1034 | `github.com/cockroachdb/pebble/v2/objstorage` | unsupported | `conversao:pointer-pointer`×2 |
| 1035 | `github.com/cockroachdb/pebble/v2/objstorage/objstorageprovider/objiotracing` | bloqueado | `dart:uri_does_not_exist`×4 |
| 1036 | `github.com/cockroachdb/pebble/v2/record` | unsupported | `shim-ausente:runtime/pprof`×3 |
| 1037 | `github.com/cockroachdb/pebble/v2/sstable/virtual` | bloqueado | `dart:uri_does_not_exist` |
| 1038 | `github.com/cockroachdb/pebble/v2/vfs/atomicfs` | bloqueado | `dart:uri_does_not_exist` |
| 1039 | `github.com/cockroachdb/pebble/v2/objstorage/objstorageprovider/remoteobjcat` | unsupported | `shim-ausente:bufio`, `shim-ausente:cmp`, `shim-ausente:path/filepath` |
| 1040 | `github.com/cockroachdb/pebble/v2/objstorage/objstorageprovider` | unsupported | `async:shim-sincrono`, `shim-ausente:bufio`, `shim-ausente:cmp`, `shim-ausente:runtime/debug`, `shim-ausente:slices` |
| 1041 | `github.com/cockroachdb/pebble/v2/sstable/block` | unsupported | `unsafe:Pointer`×4, `shim-ausente:slices`×3, `async:contexto-sincrono`×2, `conversao:slice-named-array-pointer`×2, `shim-ausente:runtime`×2 (+3) |
| 1042 | `github.com/cockroachdb/pebble/v2/sstable/colblk` | unsupported | `unsafe:Pointer`×25, `async:valor-func`×5, `unsafe:Slice`×4, `generico:ptr-valor`×3, `async:contexto-sincrono`×2 (+6) |
| 1043 | `github.com/cockroachdb/pebble/v2/sstable/blob` | unsupported | `async:contexto-sincrono`×2, `generico:ptr-valor`×2, `unsafe:Pointer`×2, `async:valor-func`, `shim-ausente:slices` |
| 1044 | `github.com/cockroachdb/pebble/v2/internal/blobtest` | unsupported | `shim-ausente:cmp`, `shim-ausente:math/rand/v2` |
| 1045 | `github.com/cockroachdb/pebble/v2/sstable/rowblk` | unsupported | `unsafe:Pointer`×2, `shim-ausente:iter`, `unsafe:Slice` |
| 1046 | `github.com/cockroachdb/pebble/v2/sstable/valblk` | unsupported | `unsafe:Pointer`×3 |
| 1047 | `github.com/cockroachdb/pebble/v2/sstable` | unsupported | `shim-ausente:cmp`×4, `shim-ausente:slices`×4, `conversao:pointer-typeparam`×3, `shim-ausente:iter`×3, `conversao:pointer-pointer`×2 (+5) |
| 1048 | `github.com/cockroachdb/pebble/v2/internal/manifest` | unsupported | `shim-ausente:container/heap` |
| 1049 | `github.com/cockroachdb/pebble/v2/internal/compact` | unsupported | `shim-ausente:slices`×2, `async:valor-func` |
| 1050 | `github.com/cockroachdb/pebble/v2/internal/keyspan/keyspanimpl` | unsupported | `shim-ausente:cmp` |
| 1051 | `github.com/cockroachdb/pebble/v2/internal/overlap` | bloqueado | `dart:uri_does_not_exist`×3 |
| 1052 | `github.com/cockroachdb/pebble/v2/internal/rangekeystack` | bloqueado | `dart:uri_does_not_exist`×4, `dart:invalid_constant`×2, `dart:undefined_getter`×2 |
| 1053 | `github.com/cockroachdb/pebble/v2/rangekey` | bloqueado | `dart:uri_does_not_exist`×3 |
| 1054 | `github.com/cockroachdb/pebble/v2/wal` | unsupported | `async:contexto-sincrono`×3, `conversao:pointer-pointer`×2, `shim-ausente:cmp`×2, `shim-ausente:slices`×2, `shim-ausente:math/rand/v2` |
| 1055 | `github.com/cockroachdb/pebble/v2` | unsupported | `async:contexto-sincrono`×23, `shim-ausente:slices`×11, `shim-ausente:runtime/pprof`×9, `shim-ausente:iter`×6, `unsafe:Pointer`×6 (+7) |
| 1056 | `github.com/ipfs/boxo/pinning/remote/client/openapi` | unsupported | `shim-ausente:net/http`×13, `shim-ausente:encoding/xml`, `shim-ausente:mime/multipart`, `shim-ausente:slices` |
| 1057 | `github.com/ipfs/boxo/pinning/remote/client` | unsupported | `async:contexto-sincrono`, `shim-ausente:net/http`, `shim-ausente:slices` |
| 1058 | `github.com/ipfs/go-ds-pebble` | unsupported | `async:valor-func` |
| 1059 | `github.com/ipfs/kubo/config` | unsupported | `shim-ausente:path/filepath`×3, `shim-ausente:encoding/base64`×2, `shim-ausente:slices`×2, `conversao:pointer-pointer`, `shim-ausente:crypto/rand` (+5) |
| 1060 | `github.com/ipfs/kubo/config/serialize` | unsupported | `shim-ausente:path/filepath`, `shim-simbolo:os.open` |
| 1061 | `github.com/ipfs/kubo/repo` | unsupported | `shim-ausente:net`×3 |
| 1062 | `github.com/ipfs/kubo/repo/fsrepo/migrations/fs-repo-16-to-17/migration` | unsupported | `shim-ausente:slices` |
| 1063 | `github.com/ipfs/kubo/repo/fsrepo/migrations` | unsupported | `shim-ausente:log`×7, `shim-ausente:path/filepath`×3, `shim-ausente:net/http`×2, `shim-ausente:os/exec`×2, `shim-ausente:path`×2 (+5) |
| 1064 | `github.com/ipfs/kubo/repo/fsrepo` | unsupported | `shim-ausente:path/filepath`×4, `shim-ausente:net`, `shim-simbolo:os.writeFile` |
| 1065 | `github.com/ipfs/kubo/routing` | unsupported | `shim-ausente:encoding/base64`, `shim-ausente:net/http` |
| 1066 | `github.com/ipfs/kubo/core/node/libp2p` | unsupported | `shim-ausente:net`×7, `conversao:pointer-pointer`×3, `shim-ausente:path/filepath`×2, `async:valor-func`, `shim-ausente:log/slog` (+4) |
| 1067 | `github.com/ipfs/kubo/core/node` | unsupported | `async:valor-func`×6, `shim-ausente:encoding/base32`×3, `shim-ausente:path/filepath`×2, `shim-ausente:crypto/rand`, `shim-ausente:net` |
| 1068 | `github.com/ipfs/kubo/core` | bloqueado | `dart:uri_does_not_exist`×32, `dart:expected_token`×2, `dart:non_bool_negation_expression`×2, `dart:undefined_identifier_await`×2, `dart:invalid_constant` (+1) |
| 1069 | `github.com/ipfs/kubo/core/corerepo` | bloqueado | `dart:uri_does_not_exist`×7, `dart:invalid_constant`, `dart:undefined_getter` |
| 1070 | `github.com/ipfs/kubo/fuse/mfs` | unsupported | `shim-simbolo:os.getuid` |
| 1071 | `github.com/ipfs/kubo/fuse/readonly` | unsupported | `shim-ausente:syscall`×4, `shim-simbolo:os.getuid` |
| 1072 | `github.com/ipfs/kubo/plugin` | bloqueado | `dart:uri_does_not_exist`×4 |
| 1073 | `github.com/ipfs/kubo/plugin/plugins/badgerds` | unsupported | `shim-ausente:path/filepath` |
| 1074 | `github.com/ipfs/kubo/plugin/plugins/dagjose` | bloqueado | `dart:uri_does_not_exist` |
| 1075 | `github.com/ipfs/kubo/plugin/plugins/flatfs` | unsupported | `shim-ausente:path/filepath` |
| 1076 | `github.com/ipfs/kubo/plugin/plugins/fxtest` | bloqueado | `dart:uri_does_not_exist`×2 |
| 1077 | `github.com/ipfs/kubo/plugin/plugins/git` | unsupported | `async:shim-sincrono` |
| 1078 | `github.com/ipfs/kubo/plugin/plugins/levelds` | unsupported | `shim-ausente:path/filepath` |
| 1079 | `github.com/ipfs/kubo/plugin/plugins/nopfs` | unsupported | `shim-ausente:path/filepath` |
| 1080 | `github.com/ipfs/kubo/plugin/plugins/pebbleds` | unsupported | `shim-ausente:path/filepath` |
| 1081 | `github.com/ipfs/kubo/plugin/plugins/peerlog` | bloqueado | `dart:uri_does_not_exist`×5, `dart:invalid_constant`, `dart:undefined_getter` |
| 1082 | `github.com/ipfs/kubo/plugin/plugins/telemetry` | unsupported | `shim-simbolo:os.stat`×2, `shim-ausente:path` |
| 1083 | `google.golang.org/grpc/internal/transport` | unsupported | `shim-ausente:net`×13, `shim-ausente:encoding/base64`×3, `shim-ausente:net/http`×3, `shim-ausente:bufio`, `shim-ausente:math/rand/v2` (+1) |
| 1084 | `google.golang.org/grpc/internal/resolver/delegatingresolver` | unsupported | `shim-ausente:net/url`×5, `shim-ausente:net`, `shim-ausente:net/http` |
| 1085 | `google.golang.org/grpc` | unsupported | `shim-ausente:net`×6, `promocao:nao-exportada`×3, `conversao:pointer-pointer`×2, `shim-ausente:compress/gzip`×2, `shim-ausente:net/url`×2 (+5) |
| 1086 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc/internal/otlpconfig` | unsupported | `shim-ausente:crypto/tls`×4, `shim-ausente:net/url`×4, `shim-ausente:net/http`, `shim-ausente:path`, `shim-simbolo:os.readFile` |
| 1087 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp/internal/otlpconfig` | unsupported | `shim-ausente:crypto/tls`×4, `shim-ausente:net/url`×4, `shim-ausente:net/http`, `shim-ausente:path`, `shim-simbolo:os.readFile` |
| 1088 | `google.golang.org/grpc/health/grpc_health_v1` | unsupported | `unsafe:Pointer`×4, `unsafe:Slice`×2 |
| 1089 | `github.com/grpc-ecosystem/grpc-gateway/v2/runtime` | unsupported | `shim-ausente:net/http`×26, `shim-ausente:net/url`×3, `conversao:named-slice-slice`×2, `shim-ausente:encoding/base64`×2, `async:valor-func` (+2) |
| 1090 | `go.opentelemetry.io/proto/otlp/collector/trace/v1` | unsupported | `shim-ausente:net/http`×5, `unsafe:Pointer`×3 |
| 1091 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc` | unsupported | `promocao:nao-exportada` |
| 1092 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp/internal/otlpjson` | unsupported | `shim-ausente:encoding/hex`×2 |
| 1093 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp` | unsupported | `shim-ausente:net/http`×8, `async:shim-sincrono`, `promocao:nao-exportada`, `shim-ausente:crypto/tls`, `shim-ausente:net/url` |
| 1094 | `github.com/ipfs/boxo/tracing` | unsupported | `shim-simbolo:os.getwd`, `shim-simbolo:os.openFile` |
| 1095 | `github.com/ipfs/kubo/tracing` | unsupported | `promocao:nao-exportada` |
| 1096 | `github.com/ipfs/kubo/core/coreunix` | unsupported | `shim-ausente:path`, `shim-simbolo:io/fs.FileInfo` |
| 1097 | `github.com/ipfs/kubo/core/coreapi` | unsupported | `conversao:pointer-pointer`×6, `async:valor-func`, `shim-ausente:crypto/rand` |
| 1098 | `github.com/ipfs/kubo/assets` | unsupported | `shim-ausente:path`×2, `shim-ausente:embed` |
| 1099 | `github.com/ipfs/kubo/fuse/ipns` | unsupported | `shim-ausente:syscall`×3, `shim-simbolo:os.getuid` |
| 1100 | `github.com/ipfs/kubo/fuse/node` | bloqueado | `dart:uri_does_not_exist`×5 |
| 1101 | `github.com/ipfs/kubo/plugin/loader` | unsupported | `shim-ausente:path/filepath`, `shim-simbolo:os.open`, `shim-simbolo:os.stat` |
| 1102 | `github.com/ipfs/kubo/commands` | bloqueado | `dart:uri_does_not_exist`×6 |
| 1103 | `github.com/ipfs/kubo/core/commands/cmdenv` | unsupported | `async:valor-func` |
| 1104 | `github.com/ipfs/kubo/core/commands/dag` | unsupported | `shim-ausente:runtime/debug`×2, `async:shim-sincrono`, `async:valor-func`, `shim-ausente:path` |
| 1105 | `github.com/ipfs/kubo/core/commands/name` | unsupported | `shim-ausente:encoding/hex` |
| 1106 | `github.com/ipfs/kubo/core/commands/object` | bloqueado | `dart:uri_does_not_exist`×6, `dart:invalid_constant`×2, `dart:undefined_getter`×2 |
| 1107 | `github.com/ipfs/kubo/core/commands/pin` | unsupported | `async:shim-sincrono`, `async:valor-func`, `shim-ausente:net/url` |
| 1108 | `github.com/ipfs/kubo/core/commands` | unsupported | `async:shim-sincrono`×15, `shim-ausente:path`×13, `shim-ausente:slices`×12, `shim-ausente:path/filepath`×5, `shim-ausente:encoding/asn1`×4 (+24) |
| 1109 | `github.com/ipfs/kubo/core/corehttp` | unsupported | `shim-ausente:net`×21, `shim-ausente:net/http`×10, `shim-ausente:maps` |
| 1110 | `github.com/ipfs/kubo/repo/fsrepo/migrations/ipfsfetcher` | unsupported | `shim-ausente:net/url`, `shim-ausente:path`, `shim-simbolo:os.mkdirTemp`, `shim-simbolo:os.open` |
| 1111 | `github.com/ipfs/kubo/cmd/ipfs/kubo` | unsupported | `shim-ausente:net/http`×3, `shim-simbolo:os.create`×2, `shim-simbolo:os.stat`×2, `shim-ausente:log/slog`, `shim-ausente:net` (+6) |
| 1112 | `github.com/ipfs/kubo/cmd/ipfs` | bloqueado | `dart:uri_does_not_exist`×673, `dart:built_in_identifier_in_declaration`×2 |
