# Auditoria do grafo real

Gerado por `python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo`. **Não edite**: rode o comando de novo.

- Alvo: `github.com/ipfs/kubo/cmd/ipfs` (`github.com/ipfs/kubo` v0.43.1), 1112 pacotes fora da stdlib.
- Contexto: go1.26.5, `CGO_ENABLED=0 GOARCH=amd64 GOFLAGS=-tags=purego,noasm GOOS=linux`.
- Ocorrência = declaração de nível de pacote que falha (o primeiro problema dela);
  do `dart analyze`, cada diagnóstico. Pacote bloqueado não conta no ranking.

## Resumo

| status | pacotes | % |
|---|---:|---:|
| verde | 142 | 12.8 |
| dart-invalido | 0 | 0.0 |
| bloqueado | 165 | 14.8 |
| unsupported | 798 | 71.8 |
| substituicao | 7 | 0.6 |

**Verde: 142 de 1112 (12.8%).**

## Ranking de códigos

Ordem: pacotes da fronteira afetados, pacotes afetados, ocorrências.

| código | ocorrências | pacotes | na fronteira | exemplo |
|---|---:|---:|---:|---|
| `shim-ausente:context` | 2170 | 369 | 39 | `github.com/cenkalti/backoff/v4` context.go:10:1: pacote sem shim/transpilação: context |
| `shim-ausente:reflect` | 919 | 124 | 21 | `github.com/cockroachdb/redact/internal/rfmt/fmtsort` sort.go:23:1: pacote sem shim/transpilação: reflect |
| `shim-ausente:net` | 748 | 128 | 18 | `github.com/coreos/go-systemd/v22/daemon` sdnotify.go:56:6: pacote sem shim/transpilação: net |
| `shim-ausente:encoding/json` | 203 | 60 | 12 | `github.com/ipfs/boxo/routing/http/internal/drjson` json.go:8:6: pacote sem shim/transpilação: encoding/json |
| `unsafe:Pointer` | 393 | 80 | 11 | `github.com/cockroachdb/pebble/v2/internal/rawalloc` rawalloc.go:21:6: unsafe.Pointer (sem memória crua fora do dart:ffi) |
| `shim-ausente:net/http` | 891 | 61 | 11 | `github.com/caddyserver/zerossl` client.go:132:1: pacote sem shim/transpilação: net/http |
| `shim-ausente:hash` | 85 | 28 | 10 | `github.com/spaolacci/murmur3` murmur128.go:23:1: pacote sem shim/transpilação: hash |
| `branch:goto` | 71 | 25 | 10 | `gonum.org/v1/gonum/mathext/internal/cephes` hyp2f1.go:106:4: goto |
| `shim-ausente:encoding/hex` | 54 | 24 | 10 | `github.com/dunglas/httpsfv` displaystring.go:11:1: pacote sem shim/transpilação: encoding/hex |
| `shim-ausente:slices` | 157 | 70 | 9 | `golang.org/x/exp/slices` slices.go:20:6: pacote sem shim/transpilação: slices |
| `shim-ausente:runtime` | 58 | 37 | 9 | `github.com/cockroachdb/pebble/v2/internal/invariants` invariants.go:40:6: pacote sem shim/transpilação: runtime |
| `shim-ausente:net/url` | 147 | 53 | 8 | `github.com/cockroachdb/pebble/v2/internal/lsmview` url.go:17:6: pacote sem shim/transpilação: net/url |
| `shim-ausente:log` | 57 | 26 | 8 | `github.com/AndreasBriese/bbloom` bbloom.go:64:6: pacote sem shim/transpilação: log |
| `shim-ausente:encoding/base64` | 48 | 26 | 8 | `github.com/dunglas/httpsfv` binary.go:14:6: pacote sem shim/transpilação: encoding/base64 |
| `shim-ausente:math/big` | 89 | 18 | 7 | `github.com/dustin/go-humanize` big.go:8:6: pacote sem shim/transpilação: math/big |
| `shim-ausente:bufio` | 109 | 32 | 6 | `github.com/anmitsu/go-shlex` shlex.go:52:1: pacote sem shim/transpilação: bufio |
| `shim-ausente:crypto/rand` | 42 | 30 | 6 | `github.com/flynn/noise` cipher_suite.go:105:1: pacote sem shim/transpilação: crypto/rand |
| `shim-ausente:path/filepath` | 57 | 38 | 5 | `github.com/caddyserver/certmagic/internal/atomicfile` file.go:76:6: pacote sem shim/transpilação: path/filepath |
| `shim-simbolo:time.Timer` | 15 | 13 | 5 | `github.com/cenkalti/backoff/v4` timer.go:12:1: símbolo sem shim: time.Timer |
| `shim-ausente:hash/crc32` | 32 | 12 | 5 | `github.com/cockroachdb/pebble/v2/internal/crc` crc.go:21:1: pacote sem shim/transpilação: hash/crc32 |
| `shim-ausente:log/slog` | 132 | 51 | 4 | `github.com/go-logr/logr` sloghandler.go:141:6: pacote sem shim/transpilação: log/slog |
| `shim-ausente:syscall` | 101 | 32 | 4 | `github.com/pbnjay/memory` memory_linux.go:7:6: pacote sem shim/transpilação: syscall |
| `shim-simbolo:os.open` | 34 | 21 | 4 | `github.com/prometheus/procfs/internal/util` readfile.go:26:6: símbolo sem shim: os.open |
| `shim-ausente:math/rand/v2` | 23 | 21 | 4 | `google.golang.org/grpc/balancer/pickfirst/internal` internal.go:28:2: pacote sem shim/transpilação: math/rand/v2 |
| `shim-ausente:crypto/x509` | 54 | 20 | 4 | `github.com/libp2p/go-libp2p/core/crypto` ecdsa.go:76:6: pacote sem shim/transpilação: crypto/x509 |
| `shim-ausente:iter` | 34 | 17 | 4 | `github.com/cockroachdb/pebble/v2/sstable/block/blockkind` kind.go:46:6: pacote sem shim/transpilação: iter |
| `shim-ausente:runtime/debug` | 21 | 17 | 4 | `github.com/ipfs/boxo/util` util.go:34:6: pacote sem shim/transpilação: runtime/debug |
| `shim-ausente:crypto` | 48 | 15 | 4 | `golang.org/x/crypto/blake2s` blake2s.go:59:6: pacote sem shim/transpilação: crypto |
| `construtor-ambiguo` | 13 | 7 | 4 | `github.com/cenkalti/backoff/v4` ticker.go:13:1: parâmetro de construtor ambíguo para campo c |
| `conversao:pointer-pointer` | 149 | 30 | 3 | `github.com/spaolacci/murmur3` murmur64.go:34:11: conversão pointer → pointer |
| `unsafe:Slice` | 38 | 30 | 3 | `filippo.io/bigmod` nat_noasm.go:12:19: unsafe.Slice (sem memória crua fora do dart:ffi) |
| `shim-ausente:crypto/sha256` | 20 | 16 | 3 | `github.com/multiformats/go-multihash/register/sha256` sha256.go:19:6: pacote sem shim/transpilação: crypto/sha256 |
| `shim-simbolo:os.stat` | 19 | 15 | 3 | `github.com/ipfs/kubo/misc/fsutil` fsutil.go:13:6: símbolo sem shim: os.stat |
| `shim-ausente:container/list` | 15 | 7 | 3 | `github.com/golang/groupcache/lru` lru.go:23:1: pacote sem shim/transpilação: container/list |
| `shim-simbolo:io/fs.DirEntry` | 6 | 5 | 3 | `github.com/facebookgo/atomicfile` atomicfile.go:15:1: símbolo sem shim: io/fs.DirEntry |
| `shim-simbolo:time.sleep` | 6 | 5 | 3 | `github.com/jbenet/go-temp-err-catcher` temp_err_catcher.go:43:1: símbolo sem shim: time.sleep |
| `shim-ausente:database/sql/driver` | 4 | 3 | 3 | `github.com/blang/semver/v4` semver.go:24:1: pacote sem shim/transpilação: database/sql/driver |
| `tipo-nomeado:pointer` | 3 | 3 | 3 | `github.com/klauspost/cpuid/v2` cpuid.go:553:6: tipo nomeado sobre pointer |
| `async:contexto-sincrono` | 55 | 37 | 2 | `github.com/pion/transport/v3/packetio` buffer.go:188:6: Read precisa ser síncrono (chamado pelo shim) mas espera outra goroutine |
| `shim-ausente:crypto/tls` | 93 | 29 | 2 | `github.com/coreos/go-systemd/v22/activation` listeners.go:58:6: pacote sem shim/transpilação: crypto/tls |
| `async:valor-func` | 45 | 27 | 2 | `github.com/ipfs/go-datastore/query` query_impl.go:21:10: função que suspende usada como valor de uma assinatura que precisa ficar síncrona |
| `shim-ausente:math/rand` | 43 | 20 | 2 | `github.com/cenkalti/backoff/v4` exponential.go:54:1: pacote sem shim/transpilação: math/rand |
| `shim-ausente:cmp` | 29 | 20 | 2 | `go.opentelemetry.io/auto/sdk/internal/telemetry` value.go:290:6: pacote sem shim/transpilação: cmp |
| `shim-ausente:maps` | 21 | 18 | 2 | `github.com/guillaumemichel/reservedpool` pool.go:14:1: pacote sem shim/transpilação: maps |
| `shim-ausente:path` | 35 | 17 | 2 | `github.com/ipfs/go-datastore/query` query_impl.go:111:6: pacote sem shim/transpilação: path |
| `shim-simbolo:os.readFile` | 18 | 14 | 2 | `github.com/crackcomm/go-gitignore` ignore.go:173:6: símbolo sem shim: os.readFile |
| `shim-simbolo:strings.splitSeq` | 13 | 10 | 2 | `github.com/klauspost/cpuid/v2` cpuid.go:478:6: símbolo sem shim: strings.splitSeq |
| `shim-simbolo:time.parse` | 10 | 10 | 2 | `github.com/gabriel-vasile/mimetype/internal/magic` text.go:504:6: símbolo sem shim: time.parse |
| `shim-ausente:crypto/cipher` | 30 | 7 | 2 | `github.com/davidlazar/go-crypto/salsa20` salsa20.go:20:6: pacote sem shim/transpilação: crypto/cipher |
| `range:pointer` | 7 | 6 | 2 | `github.com/klauspost/compress/huff0` build_table.go:107:2: range sobre pointer |
| `func-sem-corpo` | 7 | 5 | 2 | `github.com/cockroachdb/pebble/v2/internal/rawalloc` rawalloc_go1.9.go:27:6: função sem corpo (assembly ou go:linkname): substituição |
| `shim-simbolo:fmt.sscanf` | 6 | 4 | 2 | `github.com/syndtr/goleveldb/leveldb/storage` file_storage.go:649:6: símbolo sem shim: fmt.sscanf |
| `shim-simbolo:time.afterFunc` | 5 | 4 | 2 | `google.golang.org/grpc/balancer/pickfirst/internal` internal.go:33:2: símbolo sem shim: time.afterFunc |
| `unsafe:String` | 5 | 4 | 2 | `go.opentelemetry.io/auto/sdk/internal/telemetry` value.go:140:10: unsafe.String (sem memória crua fora do dart:ffi) |
| `shim-ausente:crypto/md5` | 4 | 4 | 2 | `github.com/multiformats/go-multihash/core` registry.go:112:6: pacote sem shim/transpilação: crypto/md5 |
| `shim-ausente:crypto/sha1` | 4 | 4 | 2 | `github.com/pion/stun/v3/internal/hmac` pool.go:40:5: pacote sem shim/transpilação: crypto/sha1 |
| `shim-ausente:encoding` | 8 | 3 | 2 | `github.com/go-logfmt/logfmt` encode.go:125:6: pacote sem shim/transpilação: encoding |
| `shim-ausente:encoding/xml` | 5 | 3 | 2 | `github.com/huin/goupnp/scpd` scpd.go:20:1: pacote sem shim/transpilação: encoding/xml |
| `shim-ausente:crypto/ecdh` | 4 | 3 | 2 | `golang.org/x/crypto/curve25519` curve25519.go:38:6: pacote sem shim/transpilação: crypto/ecdh |
| `shim-ausente:flag` | 3 | 3 | 2 | `github.com/grpc-ecosystem/grpc-gateway/v2/utilities` string_array_flag.go:9:1: pacote sem shim/transpilação: flag |
| `conversao:pointer-named-pointer` | 8 | 2 | 2 | `go.opentelemetry.io/auto/sdk/internal/telemetry` value.go:84:8: conversão pointer → named-pointer |
| `go:embed` | 2 | 2 | 2 | `google.golang.org/protobuf/internal/editiondefaults` defaults.go:9:8: //go:embed (import _ embed) |
| `shim-ausente:net/netip` | 46 | 15 | 1 | `github.com/libdns/libdns` record.go:39:1: pacote sem shim/transpilação: net/netip |
| `shim-simbolo:io.limitReader` | 12 | 11 | 1 | `github.com/libp2p/go-msgio` limit.go:11:6: símbolo sem shim: io.limitReader |
| `shim-simbolo:os.openFile` | 14 | 9 | 1 | `github.com/syndtr/goleveldb/leveldb/storage` file_storage.go:53:6: símbolo sem shim: os.openFile |
| `shim-simbolo:time.Ticker` | 9 | 7 | 1 | `go.uber.org/zap/zapcore` clock.go:30:1: símbolo sem shim: time.Ticker |
| `shim-simbolo:time.newTimer` | 9 | 7 | 1 | `github.com/libp2p/go-libp2p-kad-dht/provider/internal/connectivity` connectivity.go:41:1: símbolo sem shim: time.newTimer |
| `shim-simbolo:os.lstat` | 6 | 6 | 1 | `github.com/ipfs/kubo/misc/fsutil` fsutil.go:79:6: símbolo sem shim: os.lstat |
| `shim-ausente:os/exec` | 12 | 5 | 1 | `golang.org/x/sys/execabs` execabs.go:54:6: pacote sem shim/transpilação: os/exec |
| `shim-simbolo:os.Signal` | 9 | 5 | 1 | `github.com/cheggaaa/pb/v3/termutil` term.go:56:6: símbolo sem shim: os.Signal |
| `shim-ausente:container/heap` | 6 | 5 | 1 | `github.com/ipfs/go-ipfs-pq` pq.go:35:6: pacote sem shim/transpilação: container/heap |
| `shim-simbolo:os.getuid` | 5 | 5 | 1 | `github.com/google/uuid` dce.go:46:6: símbolo sem shim: os.getuid |
| `shim-ausente:encoding/asn1` | 10 | 4 | 1 | `golang.org/x/crypto/cryptobyte` asn1.go:163:6: pacote sem shim/transpilação: encoding/asn1 |
| `shim-ausente:crypto/rsa` | 7 | 4 | 1 | `filippo.io/keygen` rsa.go:30:6: pacote sem shim/transpilação: crypto/rsa |
| `shim-simbolo:os.remove` | 5 | 4 | 1 | `github.com/caddyserver/certmagic/internal/atomicfile` file.go:69:1: símbolo sem shim: os.remove |
| `shim-ausente:io/ioutil` | 4 | 4 | 1 | `github.com/minio/sha256-simd` cpuid_other.go:31:6: pacote sem shim/transpilação: io/ioutil |
| `shim-ausente:unicode/utf16` | 4 | 4 | 1 | `github.com/go-logfmt/logfmt` jsonstring.go:165:6: pacote sem shim/transpilação: unicode/utf16 |
| `shim-simbolo:io.LimitedReader` | 4 | 4 | 1 | `github.com/ipfs/go-ipfs-redirects-file` redirects.go:96:6: símbolo sem shim: io.LimitedReader |
| `shim-simbolo:os.executable` | 4 | 4 | 1 | `google.golang.org/protobuf/internal/detrand` rand.go:40:6: símbolo sem shim: os.executable |
| `shim-ausente:crypto/ecdsa` | 8 | 3 | 1 | `github.com/decred/dcrd/dcrec/secp256k1/v4` privkey.go:16:1: pacote sem shim/transpilação: crypto/ecdsa |
| `shim-ausente:crypto/elliptic` | 7 | 3 | 1 | `filippo.io/keygen` ecdsa.go:32:6: pacote sem shim/transpilação: crypto/elliptic |
| `shim-simbolo:os.SyscallError` | 4 | 3 | 1 | `github.com/syndtr/goleveldb/leveldb/storage` file_storage_unix.go:67:6: símbolo sem shim: os.SyscallError |
| `shim-simbolo:io.copyN` | 3 | 3 | 1 | `github.com/ipld/go-car/v2/internal/io` converter.go:18:1: símbolo sem shim: io.copyN |
| `shim-simbolo:os.rename` | 3 | 3 | 1 | `github.com/syndtr/goleveldb/leveldb/storage` file_storage_unix.go:63:6: símbolo sem shim: os.rename |
| `shim-ausente:math/cmplx` | 9 | 2 | 1 | `gonum.org/v1/gonum/mathext/internal/amos` amos.go:31:6: pacote sem shim/transpilação: math/cmplx |
| `shim-ausente:os/user` | 3 | 2 | 1 | `github.com/hanwen/go-fuse/v2/internal` access.go:14:6: pacote sem shim/transpilação: os/user |
| `len:typeparam` | 2 | 2 | 1 | `go.uber.org/zap/zapcore` json_encoder.go:526:18: len de typeparam |
| `shim-simbolo:io.ByteScanner` | 2 | 2 | 1 | `github.com/polydawn/refmt/shared` reader.go:287:1: símbolo sem shim: io.ByteScanner |
| `shim-simbolo:os.unsetenv` | 2 | 2 | 1 | `github.com/coreos/go-systemd/v22/daemon` watchdog.go:36:6: símbolo sem shim: os.unsetenv |
| `builtin:println` | 1 | 1 | 1 | `golang.org/x/exp/mmap` mmap_unix.go:51:3: builtin println |
| `conversao:slice-typeparam` | 1 | 1 | 1 | `github.com/multiformats/go-multistream` multistream.go:263:9: conversão slice → typeparam |
| `conversao:typeparam-slice` | 1 | 1 | 1 | `github.com/multiformats/go-multistream` client.go:139:33: conversão typeparam → slice |
| `shim-simbolo:io.SectionReader` | 1 | 1 | 1 | `github.com/whyrusleeping/chunker` chunker.go:50:1: símbolo sem shim: io.SectionReader |
| `shim-simbolo:io.multiWriter` | 1 | 1 | 1 | `google.golang.org/grpc/grpclog/internal` loggerv2.go:236:6: símbolo sem shim: io.multiWriter |
| `shim-simbolo:os.getgid` | 1 | 1 | 1 | `github.com/google/uuid` dce.go:54:6: símbolo sem shim: os.getgid |
| `shim-simbolo:os.interrupt` | 1 | 1 | 1 | `github.com/cheggaaa/pb/v3/termutil` term_x.go:17:2: símbolo sem shim: os.interrupt |
| `shim-simbolo:os.userHomeDir` | 1 | 1 | 1 | `github.com/ipfs/kubo/misc/fsutil` fsutil.go:57:6: símbolo sem shim: os.userHomeDir |
| `shim-simbolo:time.newTicker` | 12 | 10 | 0 | `github.com/pion/interceptor/pkg/report` sender_interceptor.go:20:1: símbolo sem shim: time.newTicker |
| `shim-simbolo:io.copy` | 10 | 10 | 0 | `github.com/hanwen/go-fuse/v2/splice` copy.go:58:6: símbolo sem shim: io.copy |
| `shim-ausente:compress/gzip` | 19 | 9 | 0 | `google.golang.org/protobuf/internal/impl` legacy_file.go:43:6: pacote sem shim/transpilação: compress/gzip |
| `shim-simbolo:io/fs.FileInfo` | 28 | 7 | 0 | `github.com/ipfs/boxo/filestore/posinfo` posinfo.go:12:1: símbolo sem shim: io/fs.FileInfo |
| `shim-ausente:net/textproto` | 12 | 6 | 0 | `golang.org/x/net/http/httpguts` guts.go:20:6: pacote sem shim/transpilação: net/textproto |
| `shim-simbolo:time.after` | 5 | 5 | 0 | `github.com/syndtr/goleveldb/leveldb` db_transaction.go:22:1: símbolo sem shim: time.after |
| `shim-ausente:encoding/base32` | 19 | 4 | 0 | `github.com/miekg/dns` msg_helpers.go:142:1: pacote sem shim/transpilação: encoding/base32 |
| `shim-ausente:text/template` | 17 | 4 | 0 | `github.com/cheggaaa/pb/v3` pb.go:89:1: pacote sem shim/transpilação: text/template |
| `shim-ausente:text/tabwriter` | 13 | 4 | 0 | `go.opencensus.io/zpages` rpcz.go:98:6: pacote sem shim/transpilação: text/tabwriter |
| `conversao:slice-named-slice` | 10 | 4 | 0 | `github.com/mgutz/ansi` print.go:32:12: conversão slice → named-slice |
| `shim-ausente:go/token` | 9 | 4 | 0 | `google.golang.org/protobuf/internal/strs` strings.go:71:6: pacote sem shim/transpilação: go/token |
| `shim-ausente:crypto/aes` | 8 | 4 | 0 | `github.com/flynn/noise` cipher_suite.go:140:6: pacote sem shim/transpilação: crypto/aes |
| `shim-simbolo:os.create` | 5 | 4 | 0 | `github.com/ipfs/go-ds-flatfs` util_unix.go:17:6: símbolo sem shim: os.create |
| `shim-simbolo:io.WriterTo` | 4 | 4 | 0 | `google.golang.org/grpc/mem` buffer_slice.go:249:6: símbolo sem shim: io.WriterTo |
| `shim-ausente:net/http/httptrace` | 22 | 3 | 0 | `github.com/quic-go/quic-go/http3` stream.go:54:6: pacote sem shim/transpilação: net/http/httptrace |
| `shim-ausente:html/template` | 15 | 3 | 0 | `github.com/ipfs/boxo/gateway/assets` : pacote sem shim/transpilação: html/template |
| `shim-simbolo:io.pipe` | 4 | 3 | 0 | `github.com/ipfs/go-log/v2` pipe.go:40:6: símbolo sem shim: io.pipe |
| `shim-simbolo:os.mkdir` | 4 | 3 | 0 | `github.com/ipfs/boxo/keystore` keystore.go:49:6: símbolo sem shim: os.mkdir |
| `opassign-impuro` | 3 | 3 | 0 | `github.com/pion/interceptor/pkg/nack` receive_log.go:128:2: &^= sobre alvo com efeito (avaliado duas vezes) |
| `shim-simbolo:io.multiReader` | 3 | 3 | 0 | `github.com/ipfs/go-unixfsnode/file` shard.go:30:1: símbolo sem shim: io.multiReader |
| `shim-simbolo:os.writeFile` | 3 | 3 | 0 | `github.com/ipfs/boxo/autoconf` client.go:22:6: símbolo sem shim: os.writeFile |
| `tipo-nomeado:chan` | 3 | 3 | 0 | `github.com/libp2p/go-libp2p-kad-dht/internal` ctx_mutex.go:7:6: tipo nomeado sobre chan |
| `shim-ausente:runtime/pprof` | 8 | 2 | 0 | `github.com/cockroachdb/pebble/v2/record` log_writer.go:23:1: pacote sem shim/transpilação: runtime/pprof |
| `shim-ausente:testing` | 8 | 2 | 0 | `github.com/ipfs/kubo/repo/fsrepo/migrations/common` testing_helpers.go:28:6: pacote sem shim/transpilação: testing |
| `shim-ausente:mime/multipart` | 7 | 2 | 0 | `github.com/ipfs/boxo/files` multifilereader.go:45:6: pacote sem shim/transpilação: mime/multipart |
| `conversao:pointer-typeparam` | 4 | 2 | 0 | `google.golang.org/protobuf/proto` wrapperopaque.go:68:10: conversão pointer → typeparam |
| `shim-ausente:crypto/ed25519` | 4 | 2 | 0 | `github.com/libp2p/go-libp2p/core/crypto` ed25519.go:16:1: pacote sem shim/transpilação: crypto/ed25519 |
| `shim-ausente:expvar` | 4 | 2 | 0 | `github.com/dgraph-io/badger/y` metrics.go:21:1: pacote sem shim/transpilação: expvar |
| `shim-ausente:archive/tar` | 3 | 2 | 0 | `github.com/ipfs/boxo/files` tarwriter.go:15:1: pacote sem shim/transpilação: archive/tar |
| `shim-simbolo:os.getpagesize` | 3 | 2 | 0 | `github.com/hanwen/go-fuse/v2/fuse` bufferpool.go:24:5: símbolo sem shim: os.getpagesize |
| `shim-ausente:archive/zip` | 2 | 2 | 0 | `github.com/ipfs/kubo/repo/fsrepo/migrations` unpack.go:68:6: pacote sem shim/transpilação: archive/zip |
| `shim-ausente:compress/zlib` | 2 | 2 | 0 | `github.com/ipfs/go-ipld-git` helper.go:30:6: pacote sem shim/transpilação: compress/zlib |
| `shim-ausente:crypto/x509/pkix` | 2 | 2 | 0 | `github.com/caddyserver/certmagic` config.go:1385:2: pacote sem shim/transpilação: crypto/x509/pkix |
| `shim-ausente:go/build` | 2 | 2 | 0 | `github.com/getsentry/sentry-go` stacktrace.go:333:5: pacote sem shim/transpilação: go/build |
| `shim-ausente:hash/fnv` | 2 | 2 | 0 | `github.com/ipfs/boxo/chunker` rabin.go:31:6: pacote sem shim/transpilação: hash/fnv |
| `shim-simbolo:io.newSectionReader` | 2 | 2 | 0 | `github.com/ipld/go-ipld-prime/traversal/selector` matcher.go:36:1: símbolo sem shim: io.newSectionReader |
| `shim-simbolo:os.createTemp` | 2 | 2 | 0 | `github.com/ipfs/go-ds-flatfs` util_unix.go:9:6: símbolo sem shim: os.createTemp |
| `shim-simbolo:os.readDir` | 2 | 2 | 0 | `github.com/prometheus/procfs` net_dev_snmp6.go:45:6: símbolo sem shim: os.readDir |
| `shim-simbolo:strconv.NumError` | 2 | 2 | 0 | `github.com/polydawn/refmt/json` jsonDecoder.go:17:1: símbolo sem shim: strconv.NumError |
| `shim-ausente:crypto/sha3` | 9 | 1 | 0 | `golang.org/x/crypto/sha3` hashes.go:66:6: pacote sem shim/transpilação: crypto/sha3 |
| `fmt-verbo:%#v-ponteiro` | 7 | 1 | 0 | `github.com/gogo/protobuf/protoc-gen-gogo/descriptor` descriptor_gostring.gen.go:71:41: fmt: %#v-ponteiro não portado no shim |
| `shim-ausente:compress/flate` | 3 | 1 | 0 | `github.com/gorilla/websocket` compression.go:48:6: pacote sem shim/transpilação: compress/flate |
| `shim-ausente:hash/maphash` | 3 | 1 | 0 | `github.com/ipfs/boxo/bitswap/server/internal/decision` scheduler.go:34:1: pacote sem shim/transpilação: hash/maphash |
| `shim-ausente:mime` | 3 | 1 | 0 | `github.com/gabriel-vasile/mimetype` mime.go:14:1: pacote sem shim/transpilação: mime |
| `constraint:ponteiro` | 2 | 1 | 0 | `github.com/quic-go/webtransport-go` streams_map_incoming.go:57:1: constraint com ponteiro e métodos próprios (sem interface Dart comum) |
| `conversao:chan-chan` | 2 | 1 | 0 | `github.com/ipfs/go-ipfs-cmds` chan.go:125:7: conversão chan → chan |
| `conversao:slice-named-array-pointer` | 2 | 1 | 0 | `github.com/cockroachdb/pebble/v2/sstable/block` buffer_pool.go:48:9: conversão slice → ponteiro para array nomeado |
| `shim-ausente:container/ring` | 2 | 1 | 0 | `github.com/getsentry/sentry-go` profiler.go:70:1: pacote sem shim/transpilação: container/ring |
| `shim-ausente:encoding/pem` | 2 | 1 | 0 | `github.com/ipfs/kubo/core/commands` keystore.go:320:6: pacote sem shim/transpilação: encoding/pem |
| `shim-ausente:weak` | 2 | 1 | 0 | `github.com/klauspost/compress/zstd` simple_go124.go:16:1: pacote sem shim/transpilação: weak |
| `shim-simbolo:io.nopCloser` | 2 | 1 | 0 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp` client.go:378:6: símbolo sem shim: io.nopCloser |
| `for-multi-atribuicao` | 1 | 1 | 0 | `github.com/miekg/dns` dnssec_keyscan.go:156:29: cláusula de for com múltiplas atribuições |
| `indice:typeparam` | 1 | 1 | 0 | `github.com/miekg/dns` msg.go:555:6: índice sobre typeparam |
| `layout:typeparam` | 1 | 1 | 0 | `github.com/RaduBerinde/axisds/regiontree` region_tree.go:49:1: layout de typeparam |
| `min:typeparam` | 1 | 1 | 0 | `github.com/cockroachdb/pebble/v2/sstable/colblk` uints.go:472:13: min de typeparam |
| `shim-ausente:crypto/fips140` | 1 | 1 | 0 | `golang.org/x/crypto/chacha20poly1305` fips140only_go1.26.go:11:6: pacote sem shim/transpilação: crypto/fips140 |
| `shim-ausente:crypto/hmac` | 1 | 1 | 0 | `github.com/pion/dtls/v3/pkg/crypto/prf` prf.go:159:6: pacote sem shim/transpilação: crypto/hmac |
| `shim-ausente:crypto/sha512` | 1 | 1 | 0 | `github.com/flynn/noise` cipher_suite.go:202:5: pacote sem shim/transpilação: crypto/sha512 |
| `shim-ausente:embed` | 1 | 1 | 0 | `github.com/ipfs/kubo/assets` assets.go:16:1: pacote sem shim/transpilação: embed |
| `shim-ausente:encoding/csv` | 1 | 1 | 0 | `github.com/ipfs/kubo/core/commands/dag` dag.go:352:5: pacote sem shim/transpilação: encoding/csv |
| `shim-ausente:encoding/gob` | 1 | 1 | 0 | `github.com/pion/dtls/v3` state.go:21:1: pacote sem shim/transpilação: encoding/gob |
| `shim-ausente:go/format` | 1 | 1 | 0 | `github.com/ipld/go-ipld-prime/node/bindnode` generate.go:116:6: pacote sem shim/transpilação: go/format |
| `shim-ausente:os/signal` | 1 | 1 | 0 | `go.uber.org/fx` signal.go:47:6: pacote sem shim/transpilação: os/signal |
| `shim-ausente:runtime/metrics` | 1 | 1 | 0 | `github.com/prometheus/client_golang/prometheus/internal` go_runtime_metrics.go:39:6: pacote sem shim/transpilação: runtime/metrics |
| `shim-simbolo:fmt.append$` | 1 | 1 | 0 | `github.com/ipfs/boxo/ipns` record.go:619:6: símbolo sem shim: fmt.append$ |
| `shim-simbolo:fmt.scanf` | 1 | 1 | 0 | `github.com/ipfs/kubo/cmd/ipfs/kubo` daemon.go:1356:6: símbolo sem shim: fmt.scanf |
| `shim-simbolo:io.PipeReader` | 1 | 1 | 0 | `github.com/ipfs/go-log/v2` pipe.go:12:1: símbolo sem shim: io.PipeReader |
| `shim-simbolo:io.ReadSeekCloser` | 1 | 1 | 0 | `github.com/ipfs-shipyard/nopfs` denylist.go:155:6: símbolo sem shim: io.ReadSeekCloser |
| `shim-simbolo:io/fs.FS` | 1 | 1 | 0 | `github.com/miekg/dns` scan.go:168:1: símbolo sem shim: io/fs.FS |
| `shim-simbolo:os.LinkError` | 1 | 1 | 0 | `github.com/cockroachdb/pebble/v2/vfs` mem_fs.go:82:1: símbolo sem shim: os.LinkError |
| `shim-simbolo:os.chmod` | 1 | 1 | 0 | `github.com/ipfs/boxo/files` meta_posix.go:14:6: símbolo sem shim: os.chmod |
| `shim-simbolo:os.environ` | 1 | 1 | 0 | `github.com/getsentry/sentry-go` integrations.go:380:6: símbolo sem shim: os.environ |
| `shim-simbolo:os.hostname` | 1 | 1 | 0 | `github.com/getsentry/sentry-go` client.go:43:5: símbolo sem shim: os.hostname |
| `shim-simbolo:os.newFile` | 1 | 1 | 0 | `github.com/fsnotify/fsnotify` backend_inotify.go:147:6: símbolo sem shim: os.newFile |
| `shim-simbolo:os.newSyscallError` | 1 | 1 | 0 | `golang.org/x/net/internal/socket` socket.go:20:1: símbolo sem shim: os.newSyscallError |
| `shim-simbolo:os.pipe` | 1 | 1 | 0 | `github.com/hanwen/go-fuse/v2/fuse` mount.go:12:6: símbolo sem shim: os.pipe |
| `shim-simbolo:strconv.formatComplex` | 1 | 1 | 0 | `github.com/go-logr/logr/funcr` funcr.go:238:1: símbolo sem shim: strconv.formatComplex |
| `unsafe:Add` | 1 | 1 | 0 | `github.com/cockroachdb/pebble/v2/sstable/colblk` prefix_bytes.go:1034:4: unsafe.Add (sem memória crua fora do dart:ffi) |

## Ranking por área

| área | ocorrências | pacotes |
|---|---:|---:|
| `shim-ausente` | 6924 | 740 |
| `shim-simbolo` | 332 | 149 |
| `unsafe` | 437 | 85 |
| `async` | 100 | 58 |
| `conversao` | 177 | 38 |
| `branch` | 71 | 25 |
| `construtor-ambiguo` | 13 | 7 |
| `range` | 7 | 6 |
| `tipo-nomeado` | 6 | 6 |
| `func-sem-corpo` | 7 | 5 |
| `opassign-impuro` | 3 | 3 |
| `go` | 2 | 2 |
| `len` | 2 | 2 |
| `fmt-verbo` | 7 | 1 |
| `constraint` | 2 | 1 |
| `builtin` | 1 | 1 |
| `for-multi-atribuicao` | 1 | 1 |
| `indice` | 1 | 1 |
| `layout` | 1 | 1 |
| `min` | 1 | 1 |

## Fronteira (198 pacotes)

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
| `github.com/ipld/go-car/v2/internal/io` | unsupported | `shim-simbolo:io.copyN` |
| `github.com/spaolacci/murmur3` | unsupported | `shim-ausente:hash`×5, `unsafe:Pointer`×3, `conversao:pointer-pointer` |
| `github.com/cockroachdb/pebble/v2/internal/crc` | unsupported | `shim-ausente:hash/crc32`×3 |
| `filippo.io/bigmod` | unsupported | `unsafe:Slice`×3 |
| `github.com/cespare/xxhash` | unsupported | `shim-ausente:hash`, `unsafe:Pointer` |
| `github.com/cespare/xxhash/v2` | unsupported | `unsafe:Pointer`×2 |
| `github.com/cockroachdb/redact/internal/rfmt/fmtsort` | unsupported | `shim-ausente:reflect`×4 |
| `github.com/gabriel-vasile/mimetype/internal/scan` | unsupported | `branch:goto` |
| `github.com/golang/snappy` | unsupported | `shim-ausente:hash/crc32`×3, `branch:goto` |
| `github.com/klauspost/compress/internal/snapref` | unsupported | `shim-ausente:hash/crc32`×3, `branch:goto` |
| `github.com/rogpeppe/go-internal/fmtsort` | unsupported | `shim-ausente:reflect`×5 |
| `github.com/zeebo/blake3/internal/utils` | unsupported | `unsafe:Pointer`×2 |
| `go.opentelemetry.io/otel/attribute/internal` | unsupported | `shim-ausente:reflect`×2 |
| `golang.org/x/crypto/blake2b` | unsupported | `shim-ausente:hash`×5 |
| `golang.org/x/crypto/blake2s` | unsupported | `shim-ausente:hash`×2, `shim-ausente:crypto` |
| `golang.org/x/crypto/internal/alias` | unsupported | `shim-ausente:reflect` |
| `github.com/anmitsu/go-shlex` | unsupported | `shim-ausente:bufio`×2 |
| `github.com/ipfs/go-libdht/kad/trie` | unsupported | `shim-ausente:slices` |
| `github.com/libp2p/go-buffer-pool` | unsupported | `shim-ausente:bufio`×2 |
| `github.com/pbnjay/memory` | unsupported | `shim-ausente:syscall`×2 |
| `github.com/cenkalti/backoff/v4` | unsupported | `shim-ausente:context`×5, `construtor-ambiguo`, `shim-ausente:math/rand`, `shim-simbolo:time.Timer` |
| `github.com/cockroachdb/tokenbucket` | unsupported | `shim-ausente:context` |
| `github.com/ipfs/boxo/routing/http/internal` | unsupported | `shim-ausente:context` |
| `github.com/ipfs/go-metrics-interface` | unsupported | `shim-ausente:context`×4 |
| `github.com/ipfs/kubo/internal/fusemount` | unsupported | `shim-ausente:context`×2 |
| `github.com/jbenet/go-temp-err-catcher` | unsupported | `shim-simbolo:time.sleep` |
| `github.com/libp2p/go-libp2p-pubsub/timecache` | unsupported | `shim-ausente:context`×3 |
| `github.com/pion/dtls/v3/internal/closer` | unsupported | `shim-ausente:context`×3 |
| `github.com/pion/ice/v4/internal/taskloop` | unsupported | `shim-ausente:context`×2 |
| `github.com/pion/transport/v3/deadline` | unsupported | `shim-ausente:context`, `shim-simbolo:time.Timer` |
| `github.com/pion/transport/v4/deadline` | unsupported | `shim-ausente:context`, `shim-simbolo:time.Timer` |
| `github.com/slok/go-http-metrics/metrics` | unsupported | `shim-ausente:context`×2 |
| `go.opentelemetry.io/otel/internal/baggage` | unsupported | `shim-ausente:context`×6 |
| `go.uber.org/fx/internal/fxclock` | unsupported | `shim-ausente:context`×4 |
| `go.uber.org/zap/internal/stacktrace` | unsupported | `shim-ausente:runtime`×3 |
| `golang.org/x/net/internal/httpsfv` | unsupported | `shim-ausente:slices`×5 |
| `google.golang.org/grpc/balancer/pickfirst/internal` | unsupported | `shim-ausente:math/rand/v2`×2, `shim-simbolo:time.afterFunc` |
| `google.golang.org/grpc/internal/backoff` | unsupported | `shim-ausente:context`, `shim-ausente:math/rand/v2` |
| `google.golang.org/grpc/internal/grpcsync` | unsupported | `shim-ausente:context`×4 |
| `google.golang.org/grpc/internal/idle` | unsupported | `shim-simbolo:time.Timer`×2, `shim-simbolo:time.afterFunc` |
| `google.golang.org/protobuf/internal/editiondefaults` | unsupported | `go:embed` |
| `github.com/RaduBerinde/btreemap` | unsupported | `shim-ausente:iter` |
| `github.com/benbjohnson/clock` | unsupported | `shim-ausente:context`×5, `construtor-ambiguo`×4, `shim-simbolo:time.sleep` |
| `github.com/blang/semver/v4` | unsupported | `shim-ausente:database/sql/driver` |
| `github.com/cenkalti/backoff/v5` | unsupported | `construtor-ambiguo`, `shim-ausente:context`, `shim-ausente:math/rand/v2`, `shim-simbolo:time.Timer` |
| `github.com/cockroachdb/crlib/crstrings` | unsupported | `shim-ausente:slices` |
| `github.com/cockroachdb/crlib/fifo` | unsupported | `shim-ausente:context` |
| `github.com/cockroachdb/logtags` | unsupported | `shim-ausente:context`×5 |
| `github.com/cockroachdb/pebble/v2/internal/binfmt` | unsupported | `unsafe:Pointer` |
| `github.com/cockroachdb/redact/internal/buffer` | unsupported | `unsafe:Pointer` |
| `github.com/cockroachdb/swiss` | unsupported | `unsafe:Pointer`×12, `unsafe:Slice`×2, `func-sem-corpo` |
| `github.com/crackcomm/go-gitignore` | unsupported | `shim-simbolo:os.readFile`×2 |
| `github.com/davidlazar/go-crypto/salsa20` | unsupported | `shim-ausente:crypto/cipher` |
| `github.com/dunglas/httpsfv` | unsupported | `shim-ausente:encoding/base64`×2, `shim-ausente:reflect`×2, `shim-ausente:encoding/hex` |
| `github.com/filecoin-project/go-clock` | unsupported | `shim-ausente:context`×5, `construtor-ambiguo`×4, `shim-simbolo:time.sleep` |
| `github.com/gammazero/deque` | unsupported | `shim-ausente:iter` |
| `github.com/go-jose/go-jose/v4/json` | unsupported | `shim-ausente:reflect` |
| `github.com/go-logfmt/logfmt` | unsupported | `shim-ausente:bufio`×3, `shim-ausente:encoding`×3, `shim-ausente:reflect`×3, `shim-ausente:unicode/utf16` |
| `github.com/grpc-ecosystem/grpc-gateway/v2/utilities` | unsupported | `shim-ausente:flag` |
| `github.com/hashicorp/go-version` | unsupported | `shim-ausente:database/sql/driver` |
| `github.com/huin/goupnp/scpd` | unsupported | `shim-ausente:encoding/xml` |
| `github.com/ipfs/boxo/routing/http/internal/drjson` | unsupported | `shim-ausente:encoding/json` |
| `github.com/ipfs/boxo/routing/http/types/iter` | unsupported | `shim-ausente:encoding/json`×2 |
| `github.com/ipfs/go-datastore/query` | unsupported | `async:valor-func`×3, `shim-ausente:context`×3, `shim-ausente:path`, `shim-ausente:slices` |
| `github.com/ipfs/go-libdht/kad/key/bit256` | unsupported | `shim-ausente:encoding/hex` |
| `github.com/ipfs/kubo/repo/common` | unsupported | `shim-ausente:maps` |
| `github.com/ipld/go-ipld-prime/fluent` | unsupported | `shim-ausente:reflect`×2, `async:valor-func` |
| `github.com/ipld/go-ipld-prime/linking/preload` | unsupported | `shim-ausente:context` |
| `github.com/ipld/go-ipld-prime/storage` | unsupported | `shim-ausente:context`×14 |
| `github.com/klauspost/compress/huff0` | unsupported | `range:pointer`, `shim-ausente:runtime` |
| `github.com/klauspost/cpuid/v2` | unsupported | `shim-simbolo:strings.splitSeq`×2, `shim-ausente:flag`, `shim-ausente:slices`, `tipo-nomeado:pointer` |
| `github.com/libp2p/go-libp2p-kad-dht/provider/internal/connectivity` | unsupported | `shim-simbolo:time.newTimer` |
| `github.com/libp2p/go-libp2p/core/pnet` | unsupported | `shim-ausente:bufio`×3 |
| `github.com/mikioh/tcpopt` | unsupported | `unsafe:Pointer`×13 |
| `github.com/multiformats/go-multihash/core` | unsupported | `shim-ausente:hash`×7, `shim-ausente:crypto/md5` |
| `github.com/opentracing/opentracing-go/log` | unsupported | `shim-ausente:reflect` |
| `github.com/pion/dtls/v3/pkg/crypto/ccm` | unsupported | `shim-ausente:crypto/cipher`×3 |
| `github.com/pion/dtls/v3/pkg/crypto/hash` | unsupported | `shim-ausente:crypto` |
| `github.com/pion/rtcp` | unsupported | `shim-ausente:reflect`×4 |
| `github.com/pion/stun/v3/internal/hmac` | unsupported | `shim-ausente:hash`×6, `shim-ausente:crypto/sha1`, `shim-ausente:crypto/sha256` |
| `github.com/pion/webrtc/v4/internal/fmtp` | unsupported | `shim-ausente:encoding/hex` |
| `github.com/pkg/errors` | unsupported | `shim-ausente:runtime`×2 |
| `github.com/polydawn/refmt/obj/atlas` | unsupported | `shim-ausente:reflect`×18 |
| `github.com/polydawn/refmt/pretty` | unsupported | `shim-ausente:encoding/hex` |
| `github.com/polydawn/refmt/shared` | unsupported | `shim-simbolo:io.ByteScanner` |
| `github.com/prometheus/otlptranslator` | unsupported | `shim-ausente:slices` |
| `github.com/prometheus/procfs/internal/util` | unsupported | `shim-simbolo:os.readFile`×3, `shim-simbolo:os.open`×2 |
| `github.com/quic-go/quic-go/qlogwriter/jsontext` | unsupported | `unsafe:Slice` |
| `github.com/syndtr/goleveldb/leveldb/util` | unsupported | `shim-ausente:hash/crc32`×3 |
| `go.opencensus.io/resource` | unsupported | `shim-ausente:context`×4 |
| `go.opentelemetry.io/auto/sdk/internal/telemetry` | unsupported | `shim-ausente:encoding/json`×9, `shim-ausente:encoding/hex`×5, `conversao:pointer-named-pointer`×4, `shim-ausente:cmp`, `tipo-nomeado:pointer` (+1) |
| `go.opentelemetry.io/otel/codes` | unsupported | `shim-ausente:encoding/json` |
| `go.opentelemetry.io/otel/trace/internal/telemetry` | unsupported | `shim-ausente:encoding/json`×9, `shim-ausente:encoding/hex`×5, `conversao:pointer-named-pointer`×4, `shim-ausente:cmp`, `tipo-nomeado:pointer` (+1) |
| `go.uber.org/dig/internal/dot` | unsupported | `shim-ausente:reflect`×4 |
| `go.uber.org/zap/zapcore` | unsupported | `shim-ausente:reflect`×3, `shim-ausente:encoding/json`×2, `shim-simbolo:time.Ticker`×2, `len:typeparam`, `shim-ausente:bufio` (+2) |
| `golang.org/x/crypto/curve25519` | unsupported | `shim-ausente:crypto/ecdh`×2, `range:pointer` |
| `golang.org/x/crypto/hkdf` | unsupported | `shim-ausente:hash`×4 |
| `golang.org/x/exp/mmap` | unsupported | `builtin:println`, `shim-simbolo:os.open` |
| `golang.org/x/sync/errgroup` | unsupported | `shim-ausente:context` |
| `golang.org/x/text/language` | unsupported | `conversao:pointer-pointer` |
| `golang.org/x/text/unicode/bidi` | unsupported | `shim-ausente:container/list`×2 |
| `golang.org/x/text/unicode/norm` | unsupported | `branch:goto`×3 |
| `golang.org/x/time/rate` | unsupported | `shim-ausente:context` |
| `golang.org/x/xerrors` | unsupported | `shim-ausente:runtime`×2, `branch:goto`, `conversao:pointer-pointer` |
| `google.golang.org/grpc/attributes` | unsupported | `shim-ausente:iter` |
| `google.golang.org/grpc/internal/envconfig` | unsupported | `shim-simbolo:strings.splitSeq` |
| `google.golang.org/protobuf/internal/detrand` | unsupported | `shim-simbolo:os.executable` |
| `gopkg.in/yaml.v2` | unsupported | `shim-ausente:reflect`×22, `shim-ausente:encoding/base64`, `shim-simbolo:time.parse` |
| `gopkg.in/yaml.v3` | unsupported | `shim-ausente:reflect`×26, `shim-ausente:encoding/base64`, `shim-simbolo:time.parse` |
| `github.com/AndreasBriese/bbloom` | unsupported | `unsafe:Pointer`×2, `shim-ausente:encoding/json`, `shim-ausente:log` |
| `github.com/gogo/protobuf/proto` | unsupported | `shim-ausente:reflect`×193, `branch:goto`×2, `shim-ausente:encoding`×2, `shim-ausente:encoding/json`×2, `shim-ausente:log`×2 |
| `github.com/ipfs/bbloom` | unsupported | `shim-ausente:encoding/json`×2 |
| `github.com/koron/go-ssdp/internal/ssdplog` | unsupported | `shim-ausente:log`×2 |
| `github.com/pion/logging` | unsupported | `shim-ausente:log`×2 |
| `go.opentelemetry.io/otel/internal/errorhandler` | unsupported | `shim-ausente:log`×2 |
| `golang.org/x/net/internal/timeseries` | unsupported | `shim-ausente:log` |
| `google.golang.org/grpc/grpclog/internal` | unsupported | `shim-ausente:log`×2, `shim-simbolo:io.multiWriter` |
| `github.com/go-logr/logr` | unsupported | `shim-ausente:context`×7, `shim-ausente:log/slog`×6 |
| `github.com/libp2p/go-libp2p-pubsub/internal/gologshim` | unsupported | `shim-ausente:log/slog`×6 |
| `github.com/libp2p/go-libp2p/gologshim` | unsupported | `shim-ausente:log/slog`×8, `shim-ausente:context` |
| `github.com/dustin/go-humanize` | unsupported | `shim-ausente:math/big`×38 |
| `github.com/klauspost/compress/s2` | unsupported | `branch:goto`×14, `shim-ausente:hash/crc32`×3, `async:contexto-sincrono`, `shim-ausente:encoding/json`, `shim-ausente:runtime` (+1) |
| `github.com/mr-tron/base58` | unsupported | `shim-ausente:math/big`×5 |
| `github.com/mr-tron/base58/base58` | unsupported | `shim-ausente:math/big`×5 |
| `github.com/pion/dtls/v3/pkg/crypto/elliptic` | unsupported | `shim-ausente:crypto/ecdh`, `shim-ausente:crypto/rand` |
| `github.com/pion/randutil` | unsupported | `shim-ausente:crypto/rand`×2, `shim-ausente:math/rand`×2 |
| `github.com/whyrusleeping/cbor/go` | unsupported | `shim-ausente:reflect`×12, `shim-ausente:math/big`×3 |
| `github.com/whyrusleeping/chunker` | unsupported | `shim-ausente:hash`×2, `shim-ausente:crypto/rand`, `shim-simbolo:io.SectionReader` |
| `github.com/whyrusleeping/go-keyspace` | unsupported | `shim-ausente:math/big`×4 |
| `golang.org/x/crypto/cryptobyte` | unsupported | `shim-ausente:math/big`×3, `shim-ausente:encoding/asn1`, `shim-ausente:reflect` |
| `github.com/cheggaaa/pb/v3/termutil` | unsupported | `unsafe:Pointer`×3, `shim-simbolo:os.Signal`×2, `shim-simbolo:os.interrupt`, `shim-simbolo:os.open` |
| `github.com/hanwen/go-fuse/v2/internal` | unsupported | `shim-ausente:os/user` |
| `github.com/caddyserver/certmagic/internal/atomicfile` | unsupported | `shim-ausente:path/filepath`, `shim-simbolo:os.remove` |
| `github.com/facebookgo/atomicfile` | unsupported | `shim-ausente:path/filepath`, `shim-simbolo:io/fs.DirEntry` |
| `github.com/ipfs/kubo/misc/fsutil` | unsupported | `shim-simbolo:os.lstat`, `shim-simbolo:os.stat`, `shim-simbolo:os.userHomeDir` |
| `github.com/ipfs/kubo/repo/fsrepo/migrations/atomicfile` | unsupported | `shim-ausente:path/filepath`, `shim-simbolo:io/fs.DirEntry` |
| `github.com/prometheus/procfs/internal/fs` | unsupported | `shim-ausente:path/filepath`, `shim-simbolo:os.stat` |
| `github.com/syndtr/goleveldb/leveldb/storage` | unsupported | `shim-simbolo:os.openFile`×2, `shim-ausente:path/filepath`, `shim-ausente:syscall`, `shim-simbolo:fmt.sscanf`, `shim-simbolo:io/fs.DirEntry` (+4) |
| `golang.org/x/sys/execabs` | unsupported | `shim-ausente:os/exec`×6, `shim-ausente:context` |
| `github.com/RaduBerinde/axisds` | unsupported | `shim-simbolo:fmt.sscanf` |
| `github.com/ipfs/kubo/core/commands/e` | unsupported | `shim-ausente:runtime/debug` |
| `github.com/libp2p/go-libp2p/core/internal/catch` | unsupported | `shim-ausente:runtime/debug` |
| `github.com/libp2p/go-libp2p/p2p/protocol/identify/internal/user-agent` | unsupported | `shim-ausente:runtime/debug` |
| `github.com/multiformats/go-multistream` | unsupported | `shim-ausente:bufio`×4, `shim-ausente:runtime/debug`×3, `async:contexto-sincrono`, `conversao:slice-typeparam`, `conversao:typeparam-slice` |
| `go.opencensus.io/tag` | unsupported | `shim-ausente:context`×5 |
| `github.com/decred/dcrd/dcrec/secp256k1/v4` | unsupported | `shim-ausente:math/big`×6, `shim-ausente:encoding/hex`×4, `shim-ausente:crypto/ecdsa`×2, `shim-ausente:crypto/elliptic`, `shim-ausente:crypto/rand` (+3) |
| `github.com/libdns/libdns` | unsupported | `shim-ausente:context`×5, `shim-ausente:net/netip`×2 |
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
| `github.com/pion/transport/v4` | unsupported | `shim-ausente:net`×7, `shim-ausente:context` |
| `github.com/pion/transport/v4/netctx` | unsupported | `shim-ausente:net`×7, `shim-ausente:context`×5 |
| `github.com/pion/turn/v4/internal/ipnet` | unsupported | `shim-ausente:net`×3 |
| `github.com/whyrusleeping/multiaddr-filter` | unsupported | `shim-ausente:net`×2 |
| `github.com/wlynxg/anet` | unsupported | `shim-ausente:net`×3 |
| `golang.org/x/net/internal/socks` | unsupported | `shim-ausente:net`×4, `shim-ausente:context` |
| `google.golang.org/grpc/internal/resolver/dns/internal` | unsupported | `shim-ausente:context`, `shim-ausente:net` |
| `github.com/cockroachdb/pebble/v2/internal/lsmview` | unsupported | `shim-ausente:net/url` |
| `github.com/coreos/go-systemd/v22/activation` | unsupported | `shim-ausente:net`×3, `shim-ausente:crypto/tls`×2, `shim-simbolo:os.unsetenv` |
| `github.com/getsentry/sentry-go/internal/otel/baggage` | unsupported | `shim-ausente:net/url` |
| `github.com/ipfs/go-ipfs-redirects-file` | unsupported | `shim-ausente:net/url`×3, `shim-simbolo:io.LimitedReader` |
| `github.com/pion/dtls/v3/pkg/crypto/fingerprint` | unsupported | `shim-ausente:crypto`×3, `shim-ausente:crypto/x509` |
| `github.com/quic-go/quic-go/internal/protocol` | unsupported | `shim-ausente:crypto/rand`×3, `shim-ausente:crypto/tls`×2, `shim-ausente:encoding/hex`×2, `shim-ausente:slices`×2, `shim-ausente:math/rand/v2` |
| `go.uber.org/dig/internal/digreflect` | unsupported | `shim-ausente:net/url`, `shim-ausente:reflect`, `shim-ausente:runtime` |
| `go.uber.org/fx/internal/fxreflect` | unsupported | `shim-ausente:net/url`, `shim-ausente:reflect`, `shim-ausente:runtime` |
| `golang.org/x/crypto/ocsp` | unsupported | `shim-ausente:crypto/x509` |
| `github.com/caddyserver/zerossl` | unsupported | `shim-ausente:net/http`×2, `shim-ausente:context`, `shim-ausente:crypto/x509`, `shim-ausente:encoding/base64` |
| `github.com/felixge/httpsnoop` | unsupported | `shim-ausente:net/http`×521, `shim-ausente:net` |
| `github.com/gorilla/mux` | unsupported | `shim-ausente:net/http`×25, `shim-ausente:net/url`, `shim-ausente:path` |
| `github.com/huin/goupnp/soap` | unsupported | `shim-ausente:net/url`×3, `shim-ausente:encoding/base64`×2, `shim-ausente:encoding/hex`×2, `shim-ausente:encoding/xml`×2, `shim-ausente:context` (+1) |
| `github.com/ipfs/kubo/client/rpc/auth` | unsupported | `shim-ausente:net/http`×2 |
| `github.com/mholt/acmez/v3/acme` | unsupported | `shim-ausente:crypto`×7, `shim-ausente:net/http`×4, `shim-ausente:context`×3, `shim-ausente:log/slog`×2, `shim-ausente:crypto/sha256` (+3) |
| `github.com/prometheus/client_golang/internal/github.com/golang/gddo/httputil/header` | unsupported | `shim-ausente:net/http` |
| `github.com/rs/cors` | unsupported | `shim-ausente:net/http`×2, `shim-ausente:log` |
| `go.opencensus.io/zpages/internal` | unsupported | `shim-ausente:net/http`×7, `shim-ausente:io/ioutil` |
| `go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp/internal/request` | unsupported | `shim-ausente:net/http`×2 |
| `golang.org/x/oauth2/internal` | unsupported | `shim-ausente:context`×3, `shim-ausente:net/url`×2, `shim-ausente:crypto/rsa`, `shim-ausente:encoding/json`, `shim-ausente:net/http` |
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
| 47 | `github.com/cockroachdb/pebble/v2/internal/bytealloc` | bloqueado |  |
| 48 | `github.com/zeebo/blake3/internal/alg/compress/compress_pure` | verde |  |
| 49 | `github.com/zeebo/blake3/internal/alg/compress` | bloqueado |  |
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
| 87 | `github.com/ipld/go-car/v2/internal/io` | unsupported | `shim-simbolo:io.copyN` |
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
| 98 | `github.com/cockroachdb/redact/internal/rfmt/fmtsort` | unsupported | `shim-ausente:reflect`×4 |
| 99 | `github.com/gabriel-vasile/mimetype/internal/scan` | unsupported | `branch:goto` |
| 100 | `github.com/gabriel-vasile/mimetype/internal/cdf` | bloqueado |  |
| 101 | `github.com/gabriel-vasile/mimetype/internal/csv` | bloqueado |  |
| 102 | `github.com/gabriel-vasile/mimetype/internal/markup` | bloqueado |  |
| 103 | `github.com/golang/snappy` | unsupported | `shim-ausente:hash/crc32`×3, `branch:goto` |
| 104 | `github.com/klauspost/compress/internal/le` | verde |  |
| 105 | `github.com/klauspost/compress/internal/snapref` | unsupported | `shim-ausente:hash/crc32`×3, `branch:goto` |
| 106 | `github.com/klauspost/compress/zstd/internal/xxhash` | verde |  |
| 107 | `github.com/multiformats/go-varint` | verde |  |
| 108 | `github.com/pion/dtls/v3/internal/util` | verde |  |
| 109 | `github.com/rogpeppe/go-internal/fmtsort` | unsupported | `shim-ausente:reflect`×5 |
| 110 | `github.com/zeebo/blake3/internal/utils` | unsupported | `unsafe:Pointer`×2 |
| 111 | `github.com/zeebo/blake3/internal/alg/hash/hash_pure` | unsupported | `unsafe:Pointer` |
| 112 | `github.com/zeebo/blake3/internal/alg/hash` | bloqueado |  |
| 113 | `github.com/zeebo/blake3/internal/alg` | bloqueado |  |
| 114 | `go.opentelemetry.io/otel/attribute/internal` | unsupported | `shim-ausente:reflect`×2 |
| 115 | `go.opentelemetry.io/otel/attribute/internal/xxhash` | bloqueado |  |
| 116 | `golang.org/x/crypto/blake2b` | unsupported | `shim-ausente:hash`×5 |
| 117 | `golang.org/x/crypto/blake2s` | unsupported | `shim-ausente:hash`×2, `shim-ausente:crypto` |
| 118 | `golang.org/x/crypto/internal/alias` | unsupported | `shim-ausente:reflect` |
| 119 | `golang.org/x/crypto/internal/poly1305` | verde |  |
| 120 | `golang.org/x/crypto/salsa20` | bloqueado |  |
| 121 | `github.com/anmitsu/go-shlex` | unsupported | `shim-ausente:bufio`×2 |
| 122 | `github.com/gabriel-vasile/mimetype/internal/charset` | bloqueado |  |
| 123 | `github.com/ipfs/go-libdht/kad/key` | verde |  |
| 124 | `github.com/ipfs/go-libdht/kad/key/bitstr` | verde |  |
| 125 | `github.com/ipfs/go-libdht/kad/trie` | unsupported | `shim-ausente:slices` |
| 126 | `github.com/libp2p/go-buffer-pool` | unsupported | `shim-ausente:bufio`×2 |
| 127 | `github.com/libp2p/go-msgio` | unsupported | `shim-simbolo:io.limitReader` |
| 128 | `github.com/munnerz/goautoneg` | verde |  |
| 129 | `github.com/probe-lab/go-libdht/kad/key` | verde |  |
| 130 | `github.com/rs/cors/internal` | verde |  |
| 131 | `github.com/ucarion/urlpath` | verde |  |
| 132 | `github.com/pbnjay/memory` | unsupported | `shim-ausente:syscall`×2 |
| 133 | `github.com/cenkalti/backoff/v4` | unsupported | `shim-ausente:context`×5, `construtor-ambiguo`, `shim-ausente:math/rand`, `shim-simbolo:time.Timer` |
| 134 | `github.com/cockroachdb/crlib/crtime` | verde |  |
| 135 | `github.com/cockroachdb/pebble/v2/internal/genericcache` | unsupported | `shim-ausente:context`×3 |
| 136 | `github.com/cockroachdb/tokenbucket` | unsupported | `shim-ausente:context` |
| 137 | `github.com/hashicorp/golang-lru/v2/internal` | verde |  |
| 138 | `github.com/hashicorp/golang-lru/v2/simplelru` | verde |  |
| 139 | `github.com/hashicorp/golang-lru/v2` | verde |  |
| 140 | `github.com/ipfs/boxo/routing/http/internal` | unsupported | `shim-ausente:context` |
| 141 | `github.com/ipfs/go-metrics-interface` | unsupported | `shim-ausente:context`×4 |
| 142 | `github.com/ipfs/boxo/bitswap/metrics` | unsupported | `shim-ausente:context`×11 |
| 143 | `github.com/ipfs/kubo/internal/fusemount` | unsupported | `shim-ausente:context`×2 |
| 144 | `github.com/jbenet/go-temp-err-catcher` | unsupported | `shim-simbolo:time.sleep` |
| 145 | `github.com/libp2p/go-libp2p-kad-dht/provider/stats` | verde |  |
| 146 | `github.com/libp2p/go-libp2p-pubsub/timecache` | unsupported | `shim-ausente:context`×3 |
| 147 | `github.com/pion/dtls/v3/internal/closer` | unsupported | `shim-ausente:context`×3 |
| 148 | `github.com/pion/ice/v4/internal/taskloop` | unsupported | `shim-ausente:context`×2 |
| 149 | `github.com/pion/interceptor/internal/ntp` | verde |  |
| 150 | `github.com/pion/transport/v3/deadline` | unsupported | `shim-ausente:context`, `shim-simbolo:time.Timer` |
| 151 | `github.com/pion/transport/v3/packetio` | unsupported | `async:contexto-sincrono` |
| 152 | `github.com/pion/transport/v4/deadline` | unsupported | `shim-ausente:context`, `shim-simbolo:time.Timer` |
| 153 | `github.com/quic-go/quic-go/internal/monotime` | verde |  |
| 154 | `github.com/slok/go-http-metrics/metrics` | unsupported | `shim-ausente:context`×2 |
| 155 | `go.opentelemetry.io/otel/internal/baggage` | unsupported | `shim-ausente:context`×6 |
| 156 | `go.uber.org/dig/internal/digclock` | verde |  |
| 157 | `go.uber.org/fx/internal/fxclock` | unsupported | `shim-ausente:context`×4 |
| 158 | `go.uber.org/zap/buffer` | verde |  |
| 159 | `go.uber.org/zap/internal/bufferpool` | verde |  |
| 160 | `go.uber.org/zap/internal/stacktrace` | unsupported | `shim-ausente:runtime`×3 |
| 161 | `golang.org/x/net/internal/httpsfv` | unsupported | `shim-ausente:slices`×5 |
| 162 | `golang.org/x/sys/unix` | substituicao | assembly: asm_linux_amd64.s |
| 163 | `github.com/hanwen/go-fuse/v2/internal/fallocate` | bloqueado |  |
| 164 | `github.com/hanwen/go-fuse/v2/internal/openat` | unsupported | `shim-ausente:syscall`×2 |
| 165 | `github.com/hanwen/go-fuse/v2/internal/renameat` | bloqueado |  |
| 166 | `github.com/hanwen/go-fuse/v2/internal/xattr` | unsupported | `shim-ausente:syscall` |
| 167 | `github.com/ipfs/kubo/core/node/libp2p/fd` | bloqueado |  |
| 168 | `github.com/mattn/go-isatty` | bloqueado |  |
| 169 | `google.golang.org/grpc/backoff` | verde |  |
| 170 | `google.golang.org/grpc/balancer/pickfirst/internal` | unsupported | `shim-ausente:math/rand/v2`×2, `shim-simbolo:time.afterFunc` |
| 171 | `google.golang.org/grpc/internal/backoff` | unsupported | `shim-ausente:context`, `shim-ausente:math/rand/v2` |
| 172 | `google.golang.org/grpc/internal/grpcsync` | unsupported | `shim-ausente:context`×4 |
| 173 | `google.golang.org/grpc/internal/idle` | unsupported | `shim-simbolo:time.Timer`×2, `shim-simbolo:time.afterFunc` |
| 174 | `google.golang.org/grpc/keepalive` | verde |  |
| 175 | `google.golang.org/protobuf/internal/editiondefaults` | unsupported | `go:embed` |
| 176 | `github.com/RaduBerinde/btreemap` | unsupported | `shim-ausente:iter` |
| 177 | `github.com/benbjohnson/clock` | unsupported | `shim-ausente:context`×5, `construtor-ambiguo`×4, `shim-simbolo:time.sleep` |
| 178 | `github.com/blang/semver/v4` | unsupported | `shim-ausente:database/sql/driver` |
| 179 | `github.com/cenkalti/backoff/v5` | unsupported | `construtor-ambiguo`, `shim-ausente:context`, `shim-ausente:math/rand/v2`, `shim-simbolo:time.Timer` |
| 180 | `github.com/cockroachdb/crlib/crbytes` | substituicao | assembly: common_prefix_amd64.s |
| 181 | `github.com/cockroachdb/crlib/crstrings` | unsupported | `shim-ausente:slices` |
| 182 | `github.com/cockroachdb/crlib/fifo` | unsupported | `shim-ausente:context` |
| 183 | `github.com/cockroachdb/logtags` | unsupported | `shim-ausente:context`×5 |
| 184 | `github.com/cockroachdb/pebble/v2/internal/manual` | unsupported | `unsafe:Pointer`×3 |
| 185 | `github.com/cockroachdb/pebble/v2/internal/treeprinter` | verde |  |
| 186 | `github.com/cockroachdb/pebble/v2/internal/binfmt` | unsupported | `unsafe:Pointer` |
| 187 | `github.com/cockroachdb/redact/interfaces` | verde |  |
| 188 | `github.com/cockroachdb/redact/internal/fmtforward` | verde |  |
| 189 | `github.com/cockroachdb/redact/internal/markers` | verde |  |
| 190 | `github.com/cockroachdb/redact/internal/escape` | verde |  |
| 191 | `github.com/cockroachdb/redact/internal/buffer` | unsupported | `unsafe:Pointer` |
| 192 | `github.com/cockroachdb/redact/internal/redact` | verde |  |
| 193 | `github.com/cockroachdb/redact/internal/rfmt` | unsupported | `shim-ausente:reflect`×12 |
| 194 | `github.com/cockroachdb/redact/builder` | bloqueado |  |
| 195 | `github.com/cockroachdb/redact` | unsupported | `shim-ausente:reflect`×2 |
| 196 | `github.com/cockroachdb/pebble/v2/internal/humanize` | bloqueado |  |
| 197 | `github.com/cockroachdb/swiss` | unsupported | `unsafe:Pointer`×12, `unsafe:Slice`×2, `func-sem-corpo` |
| 198 | `github.com/crackcomm/go-gitignore` | unsupported | `shim-simbolo:os.readFile`×2 |
| 199 | `github.com/davidlazar/go-crypto/salsa20` | unsupported | `shim-ausente:crypto/cipher` |
| 200 | `github.com/dunglas/httpsfv` | unsupported | `shim-ausente:encoding/base64`×2, `shim-ausente:reflect`×2, `shim-ausente:encoding/hex` |
| 201 | `github.com/filecoin-project/go-clock` | unsupported | `shim-ausente:context`×5, `construtor-ambiguo`×4, `shim-simbolo:time.sleep` |
| 202 | `github.com/fsnotify/fsnotify/internal` | unsupported | `shim-ausente:syscall`×4 |
| 203 | `github.com/gabriel-vasile/mimetype/internal/magic` | unsupported | `shim-ausente:slices`×5, `shim-simbolo:time.parse` |
| 204 | `github.com/gammazero/deque` | unsupported | `shim-ausente:iter` |
| 205 | `github.com/gammazero/chanqueue` | bloqueado |  |
| 206 | `github.com/go-jose/go-jose/v4/json` | unsupported | `shim-ausente:reflect` |
| 207 | `github.com/go-logfmt/logfmt` | unsupported | `shim-ausente:bufio`×3, `shim-ausente:encoding`×3, `shim-ausente:reflect`×3, `shim-ausente:unicode/utf16` |
| 208 | `github.com/grpc-ecosystem/grpc-gateway/v2/utilities` | unsupported | `shim-ausente:flag` |
| 209 | `github.com/grpc-ecosystem/grpc-gateway/v2/internal/httprule` | bloqueado |  |
| 210 | `github.com/hashicorp/go-version` | unsupported | `shim-ausente:database/sql/driver` |
| 211 | `github.com/huin/goupnp/scpd` | unsupported | `shim-ausente:encoding/xml` |
| 212 | `github.com/ipfs/boxo/routing/http/internal/drjson` | unsupported | `shim-ausente:encoding/json` |
| 213 | `github.com/ipfs/boxo/routing/http/types/iter` | unsupported | `shim-ausente:encoding/json`×2 |
| 214 | `github.com/ipfs/go-bitfield` | verde |  |
| 215 | `github.com/ipfs/go-datastore/query` | unsupported | `async:valor-func`×3, `shim-ausente:context`×3, `shim-ausente:path`, `shim-ausente:slices` |
| 216 | `github.com/ipfs/go-libdht/kad/key/bit256` | unsupported | `shim-ausente:encoding/hex` |
| 217 | `github.com/ipfs/kubo/repo/common` | unsupported | `shim-ausente:maps` |
| 218 | `github.com/ipld/go-ipld-prime/datamodel` | verde |  |
| 219 | `github.com/ipld/go-ipld-prime/adl` | verde |  |
| 220 | `github.com/ipld/go-ipld-prime/codec` | verde |  |
| 221 | `github.com/ipld/go-ipld-prime/fluent` | unsupported | `shim-ausente:reflect`×2, `async:valor-func` |
| 222 | `github.com/ipld/go-ipld-prime/fluent/qp` | verde |  |
| 223 | `github.com/ipld/go-ipld-prime/linking/preload` | unsupported | `shim-ausente:context` |
| 224 | `github.com/ipld/go-ipld-prime/multicodec` | verde |  |
| 225 | `github.com/ipld/go-ipld-prime/codec/raw` | verde |  |
| 226 | `github.com/ipld/go-ipld-prime/node/mixins` | verde |  |
| 227 | `github.com/ipld/go-ipld-prime/schema` | verde |  |
| 228 | `github.com/ipld/go-ipld-prime/storage` | unsupported | `shim-ausente:context`×14 |
| 229 | `github.com/ipld/go-ipld-prime/linking` | unsupported | `shim-ausente:context`, `shim-ausente:hash` |
| 230 | `github.com/ipld/go-ipld-prime/node/basicnode` | bloqueado |  |
| 231 | `github.com/ipld/go-ipld-prime/node/basic` | bloqueado |  |
| 232 | `github.com/klauspost/compress/fse` | verde |  |
| 233 | `github.com/klauspost/compress/huff0` | unsupported | `range:pointer`, `shim-ausente:runtime` |
| 234 | `github.com/klauspost/cpuid/v2` | unsupported | `shim-simbolo:strings.splitSeq`×2, `shim-ausente:flag`, `shim-ausente:slices`, `tipo-nomeado:pointer` |
| 235 | `github.com/libp2p/go-flow-metrics` | unsupported | `async:contexto-sincrono`, `async:valor-func` |
| 236 | `github.com/libp2p/go-libp2p-kad-dht/provider/internal/connectivity` | unsupported | `shim-simbolo:time.newTimer` |
| 237 | `github.com/libp2p/go-libp2p/core/pnet` | unsupported | `shim-ausente:bufio`×3 |
| 238 | `github.com/mattn/go-colorable` | bloqueado |  |
| 239 | `github.com/fatih/color` | bloqueado |  |
| 240 | `github.com/mattn/go-runewidth` | verde |  |
| 241 | `github.com/mgutz/ansi` | unsupported | `conversao:slice-named-slice` |
| 242 | `github.com/elgris/jsondiff` | unsupported | `shim-ausente:encoding/json`×2, `shim-ausente:reflect` |
| 243 | `github.com/mikioh/tcpopt` | unsupported | `unsafe:Pointer`×13 |
| 244 | `github.com/mikioh/tcpinfo` | unsupported | `unsafe:Pointer`×4, `shim-ausente:encoding/json` |
| 245 | `github.com/multiformats/go-base36` | verde |  |
| 246 | `github.com/multiformats/go-multiaddr/x/meg` | verde |  |
| 247 | `github.com/multiformats/go-multicodec` | verde |  |
| 248 | `github.com/multiformats/go-multihash/core` | unsupported | `shim-ausente:hash`×7, `shim-ausente:crypto/md5` |
| 249 | `github.com/multiformats/go-multihash/register/blake2` | bloqueado |  |
| 250 | `github.com/multiformats/go-multihash/register/murmur3` | unsupported | `shim-ausente:hash` |
| 251 | `github.com/multiformats/go-multihash/register/sha256` | unsupported | `shim-ausente:crypto/sha256` |
| 252 | `github.com/multiformats/go-multihash/register/miniosha256` | bloqueado |  |
| 253 | `github.com/opentracing/opentracing-go/log` | unsupported | `shim-ausente:reflect` |
| 254 | `github.com/pion/dtls/v3/pkg/crypto/ccm` | unsupported | `shim-ausente:crypto/cipher`×3 |
| 255 | `github.com/pion/dtls/v3/pkg/crypto/hash` | unsupported | `shim-ausente:crypto` |
| 256 | `github.com/pion/dtls/v3/pkg/crypto/signature` | bloqueado |  |
| 257 | `github.com/pion/rtcp` | unsupported | `shim-ausente:reflect`×4 |
| 258 | `github.com/pion/rtp/codecs/av1/obu` | verde |  |
| 259 | `github.com/pion/stun/v3/internal/hmac` | unsupported | `shim-ausente:hash`×6, `shim-ausente:crypto/sha1`, `shim-ausente:crypto/sha256` |
| 260 | `github.com/pion/transport/v3/replaydetector` | verde |  |
| 261 | `github.com/pion/transport/v4/replaydetector` | verde |  |
| 262 | `github.com/pion/webrtc/v4/internal/fmtp` | unsupported | `shim-ausente:encoding/hex` |
| 263 | `github.com/pion/webrtc/v4/pkg/rtcerr` | verde |  |
| 264 | `github.com/pkg/errors` | unsupported | `shim-ausente:runtime`×2 |
| 265 | `github.com/polydawn/refmt/obj/atlas` | unsupported | `shim-ausente:reflect`×18 |
| 266 | `github.com/polydawn/refmt/tok` | verde |  |
| 267 | `github.com/polydawn/refmt/obj` | unsupported | `shim-ausente:reflect`×54 |
| 268 | `github.com/polydawn/refmt/pretty` | unsupported | `shim-ausente:encoding/hex` |
| 269 | `github.com/polydawn/refmt/shared` | unsupported | `shim-simbolo:io.ByteScanner` |
| 270 | `github.com/polydawn/refmt/cbor` | unsupported | `branch:goto` |
| 271 | `github.com/polydawn/refmt/json` | unsupported | `shim-ausente:unicode/utf16`, `shim-simbolo:strconv.NumError` |
| 272 | `github.com/polydawn/refmt` | bloqueado |  |
| 273 | `github.com/ipfs/go-ipld-cbor/encoding` | bloqueado |  |
| 274 | `github.com/prometheus/otlptranslator` | unsupported | `shim-ausente:slices` |
| 275 | `github.com/prometheus/procfs/internal/util` | unsupported | `shim-simbolo:os.readFile`×3, `shim-simbolo:os.open`×2 |
| 276 | `github.com/quic-go/quic-go/qlogwriter/jsontext` | unsupported | `unsafe:Slice` |
| 277 | `github.com/quic-go/quic-go/quicvarint` | verde |  |
| 278 | `github.com/slok/go-http-metrics/middleware` | unsupported | `shim-ausente:context`×2 |
| 279 | `github.com/syndtr/goleveldb/leveldb/util` | unsupported | `shim-ausente:hash/crc32`×3 |
| 280 | `github.com/syndtr/goleveldb/leveldb/cache` | unsupported | `unsafe:Pointer`×7 |
| 281 | `github.com/syndtr/goleveldb/leveldb/filter` | bloqueado |  |
| 282 | `github.com/syndtr/goleveldb/leveldb/opt` | bloqueado |  |
| 283 | `github.com/texttheater/golang-levenshtein/levenshtein` | verde |  |
| 284 | `github.com/zeebo/blake3` | unsupported | `unsafe:Pointer`×6 |
| 285 | `go.opencensus.io/internal` | verde |  |
| 286 | `go.opencensus.io/resource` | unsupported | `shim-ausente:context`×4 |
| 287 | `go.opencensus.io/metric/metricdata` | bloqueado |  |
| 288 | `go.opencensus.io/metric/metricproducer` | bloqueado |  |
| 289 | `go.opencensus.io/trace/tracestate` | verde |  |
| 290 | `go.opentelemetry.io/auto/sdk/internal/telemetry` | unsupported | `shim-ausente:encoding/json`×9, `shim-ausente:encoding/hex`×5, `conversao:pointer-named-pointer`×4, `shim-ausente:cmp`, `tipo-nomeado:pointer` (+1) |
| 291 | `go.opentelemetry.io/otel/attribute` | unsupported | `shim-ausente:reflect`×27, `shim-ausente:cmp`×2, `shim-ausente:encoding/base64`, `shim-ausente:encoding/json` |
| 292 | `go.opentelemetry.io/otel/codes` | unsupported | `shim-ausente:encoding/json` |
| 293 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc/internal` | verde |  |
| 294 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc/internal/retry` | unsupported | `shim-ausente:context`×4 |
| 295 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc/internal/x` | verde |  |
| 296 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp/internal` | verde |  |
| 297 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp/internal/retry` | unsupported | `shim-ausente:context`×4 |
| 298 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp/internal/x` | verde |  |
| 299 | `go.opentelemetry.io/otel/exporters/prometheus/internal/x` | verde |  |
| 300 | `go.opentelemetry.io/otel/exporters/stdout/stdouttrace/internal/x` | verde |  |
| 301 | `go.opentelemetry.io/otel/metric` | unsupported | `shim-ausente:context`×11, `shim-ausente:slices` |
| 302 | `go.opentelemetry.io/otel/metric/noop` | unsupported | `shim-ausente:context`×8 |
| 303 | `go.opentelemetry.io/otel/sdk/instrumentation` | bloqueado |  |
| 304 | `go.opentelemetry.io/otel/sdk/internal/attrnorm` | unsupported | `shim-ausente:reflect`×5, `shim-ausente:slices`×3, `unsafe:Pointer` |
| 305 | `go.opentelemetry.io/otel/sdk/internal/x` | verde |  |
| 306 | `go.opentelemetry.io/otel/sdk/metric/internal/attrnorm` | unsupported | `shim-ausente:reflect`×5, `unsafe:Pointer` |
| 307 | `go.opentelemetry.io/otel/sdk/metric/internal/x` | verde |  |
| 308 | `go.opentelemetry.io/otel/semconv/internal/metricpool` | bloqueado |  |
| 309 | `go.opentelemetry.io/otel/semconv/v1.37.0` | unsupported | `shim-ausente:reflect` |
| 310 | `go.opentelemetry.io/otel/semconv/v1.41.0` | unsupported | `shim-ausente:reflect`×4 |
| 311 | `go.opentelemetry.io/otel/semconv/v1.41.0/otelconv` | unsupported | `shim-ausente:context`×13 |
| 312 | `go.opentelemetry.io/otel/semconv/v1.43.0` | unsupported | `shim-ausente:reflect`×4 |
| 313 | `go.opentelemetry.io/otel/semconv/v1.43.0/httpconv` | unsupported | `shim-ausente:context`×10 |
| 314 | `go.opentelemetry.io/otel/semconv/v1.43.0/otelconv` | unsupported | `shim-ausente:context`×13 |
| 315 | `go.opentelemetry.io/otel/trace/internal/telemetry` | unsupported | `shim-ausente:encoding/json`×9, `shim-ausente:encoding/hex`×5, `conversao:pointer-named-pointer`×4, `shim-ausente:cmp`, `tipo-nomeado:pointer` (+1) |
| 316 | `go.opentelemetry.io/otel/trace` | unsupported | `shim-ausente:context`×11, `shim-ausente:encoding/json`×2, `construtor-ambiguo`, `shim-ausente:reflect`, `shim-ausente:slices` |
| 317 | `go.opentelemetry.io/otel/sdk/metric/exemplar` | unsupported | `shim-ausente:context`×9, `shim-ausente:math/rand/v2`×2, `shim-ausente:slices` |
| 318 | `go.opentelemetry.io/otel/trace/noop` | unsupported | `shim-ausente:context` |
| 319 | `go.uber.org/dig/internal/digerror` | verde |  |
| 320 | `go.uber.org/dig/internal/dot` | unsupported | `shim-ausente:reflect`×4 |
| 321 | `go.uber.org/multierr` | verde |  |
| 322 | `go.uber.org/zap/internal/color` | verde |  |
| 323 | `go.uber.org/zap/internal/exit` | verde |  |
| 324 | `go.uber.org/zap/zapcore` | unsupported | `shim-ausente:reflect`×3, `shim-ausente:encoding/json`×2, `shim-simbolo:time.Ticker`×2, `len:typeparam`, `shim-ausente:bufio` (+2) |
| 325 | `go.uber.org/zap/internal` | bloqueado |  |
| 326 | `golang.org/x/crypto/chacha20` | bloqueado |  |
| 327 | `golang.org/x/crypto/chacha20poly1305` | unsupported | `shim-ausente:crypto/cipher`×2, `shim-ausente:crypto/fips140` |
| 328 | `golang.org/x/crypto/curve25519` | unsupported | `shim-ausente:crypto/ecdh`×2, `range:pointer` |
| 329 | `golang.org/x/crypto/hkdf` | unsupported | `shim-ausente:hash`×4 |
| 330 | `golang.org/x/exp/mmap` | unsupported | `builtin:println`, `shim-simbolo:os.open` |
| 331 | `golang.org/x/net/bpf` | verde |  |
| 332 | `golang.org/x/net/http2/hpack` | verde |  |
| 333 | `github.com/quic-go/qpack` | verde |  |
| 334 | `golang.org/x/sync/errgroup` | unsupported | `shim-ausente:context` |
| 335 | `golang.org/x/sys/cpu` | substituicao | assembly: cpu_gc_x86.s |
| 336 | `golang.org/x/crypto/sha3` | unsupported | `shim-ausente:crypto/sha3`×9, `shim-ausente:hash`×7, `range:pointer` |
| 337 | `github.com/multiformats/go-multihash/register/sha3` | bloqueado |  |
| 338 | `golang.org/x/term` | bloqueado |  |
| 339 | `golang.org/x/text/internal/language` | verde |  |
| 340 | `golang.org/x/text/internal/language/compact` | verde |  |
| 341 | `golang.org/x/text/language` | unsupported | `conversao:pointer-pointer` |
| 342 | `golang.org/x/text/internal` | bloqueado |  |
| 343 | `golang.org/x/text/unicode/bidi` | unsupported | `shim-ausente:container/list`×2 |
| 344 | `golang.org/x/text/secure/bidirule` | bloqueado |  |
| 345 | `golang.org/x/text/unicode/norm` | unsupported | `branch:goto`×3 |
| 346 | `golang.org/x/net/idna` | bloqueado |  |
| 347 | `golang.org/x/text/cases` | bloqueado |  |
| 348 | `golang.org/x/time/rate` | unsupported | `shim-ausente:context` |
| 349 | `golang.org/x/xerrors` | unsupported | `shim-ausente:runtime`×2, `branch:goto`, `conversao:pointer-pointer` |
| 350 | `google.golang.org/grpc/attributes` | unsupported | `shim-ausente:iter` |
| 351 | `google.golang.org/grpc/internal/envconfig` | unsupported | `shim-simbolo:strings.splitSeq` |
| 352 | `google.golang.org/protobuf/internal/detrand` | unsupported | `shim-simbolo:os.executable` |
| 353 | `google.golang.org/protobuf/internal/errors` | bloqueado |  |
| 354 | `google.golang.org/protobuf/encoding/protowire` | bloqueado |  |
| 355 | `google.golang.org/protobuf/internal/version` | verde |  |
| 356 | `google.golang.org/protobuf/reflect/protoreflect` | unsupported | `unsafe:Pointer`×10, `shim-ausente:reflect` |
| 357 | `google.golang.org/protobuf/internal/descfmt` | unsupported | `shim-ausente:reflect`×3 |
| 358 | `google.golang.org/protobuf/internal/descopts` | bloqueado |  |
| 359 | `google.golang.org/protobuf/internal/encoding/messageset` | bloqueado |  |
| 360 | `google.golang.org/protobuf/internal/genid` | bloqueado |  |
| 361 | `google.golang.org/protobuf/internal/order` | bloqueado |  |
| 362 | `google.golang.org/protobuf/internal/strs` | unsupported | `shim-ausente:go/token`, `unsafe:Slice`, `unsafe:String` |
| 363 | `google.golang.org/protobuf/internal/encoding/json` | unsupported | `shim-ausente:unicode/utf16` |
| 364 | `google.golang.org/protobuf/internal/encoding/text` | unsupported | `shim-ausente:unicode/utf16`, `shim-simbolo:strconv.NumError` |
| 365 | `google.golang.org/protobuf/internal/encoding/defval` | bloqueado |  |
| 366 | `google.golang.org/protobuf/reflect/protoregistry` | bloqueado |  |
| 367 | `google.golang.org/protobuf/runtime/protoiface` | bloqueado |  |
| 368 | `google.golang.org/protobuf/internal/protolazy` | unsupported | `branch:goto`×2, `unsafe:Pointer`×2 |
| 369 | `google.golang.org/protobuf/proto` | unsupported | `conversao:pointer-typeparam`, `shim-ausente:reflect` |
| 370 | `google.golang.org/protobuf/encoding/protodelim` | unsupported | `shim-ausente:bufio` |
| 371 | `google.golang.org/protobuf/encoding/prototext` | bloqueado |  |
| 372 | `google.golang.org/protobuf/internal/filedesc` | unsupported | `shim-ausente:reflect` |
| 373 | `google.golang.org/protobuf/encoding/protojson` | unsupported | `shim-ausente:encoding/base64`×2, `shim-simbolo:time.parse` |
| 374 | `google.golang.org/protobuf/internal/encoding/tag` | unsupported | `shim-ausente:reflect`×3 |
| 375 | `google.golang.org/protobuf/internal/impl` | unsupported | `shim-ausente:reflect`×124, `unsafe:Pointer`×12, `conversao:pointer-pointer`, `shim-ausente:compress/gzip` |
| 376 | `google.golang.org/protobuf/internal/filetype` | unsupported | `shim-ausente:reflect`×3 |
| 377 | `google.golang.org/protobuf/runtime/protoimpl` | bloqueado |  |
| 378 | `github.com/ipfs/boxo/bitswap/message/pb` | unsupported | `unsafe:Pointer`×5, `shim-ausente:reflect` |
| 379 | `github.com/ipfs/boxo/filestore/pb` | unsupported | `shim-ausente:reflect`, `unsafe:Pointer` |
| 380 | `github.com/ipfs/boxo/ipld/merkledag/pb` | unsupported | `unsafe:Pointer`×2, `shim-ausente:reflect` |
| 381 | `github.com/ipfs/boxo/ipld/unixfs/pb` | unsupported | `unsafe:Pointer`×3, `shim-ausente:reflect` |
| 382 | `github.com/ipfs/boxo/ipns/pb` | unsupported | `shim-ausente:reflect`, `unsafe:Pointer` |
| 383 | `github.com/libp2p/go-libp2p-record/pb` | unsupported | `shim-ausente:reflect`, `unsafe:Pointer` |
| 384 | `github.com/libp2p/go-libp2p/core/crypto/pb` | unsupported | `unsafe:Pointer`×2, `shim-ausente:reflect`, `unsafe:Slice` |
| 385 | `github.com/libp2p/go-libp2p/core/peer/pb` | unsupported | `unsafe:Pointer`×2, `shim-ausente:reflect`, `unsafe:Slice` |
| 386 | `github.com/libp2p/go-libp2p/core/record/pb` | unsupported | `shim-ausente:reflect`, `unsafe:Pointer`, `unsafe:Slice` |
| 387 | `github.com/libp2p/go-libp2p/p2p/host/autonat/pb` | unsupported | `unsafe:Pointer`×4, `shim-ausente:reflect`, `unsafe:Slice` |
| 388 | `github.com/libp2p/go-libp2p/p2p/protocol/autonatv2/pb` | unsupported | `unsafe:Pointer`×7, `shim-ausente:reflect`, `unsafe:Slice` |
| 389 | `github.com/libp2p/go-libp2p/p2p/protocol/circuitv2/pb` | unsupported | `unsafe:Pointer`×6, `shim-ausente:reflect`×2, `unsafe:Slice`×2 |
| 390 | `github.com/libp2p/go-libp2p/p2p/protocol/holepunch/pb` | unsupported | `shim-ausente:reflect`, `unsafe:Pointer`, `unsafe:Slice` |
| 391 | `github.com/libp2p/go-libp2p/p2p/protocol/identify/pb` | unsupported | `shim-ausente:reflect`, `unsafe:Pointer`, `unsafe:Slice` |
| 392 | `github.com/libp2p/go-libp2p/p2p/security/insecure/pb` | unsupported | `shim-ausente:reflect`, `unsafe:Pointer`, `unsafe:Slice` |
| 393 | `github.com/libp2p/go-libp2p/p2p/security/noise/pb` | unsupported | `unsafe:Pointer`×2, `shim-ausente:reflect`, `unsafe:Slice` |
| 394 | `github.com/libp2p/go-libp2p/p2p/transport/webrtc/pb` | unsupported | `shim-ausente:reflect`, `unsafe:Pointer`, `unsafe:Slice` |
| 395 | `go.opentelemetry.io/proto/otlp/common/v1` | unsupported | `unsafe:Pointer`×6, `shim-ausente:reflect` |
| 396 | `go.opentelemetry.io/proto/otlp/resource/v1` | unsupported | `shim-ausente:reflect`, `unsafe:Pointer` |
| 397 | `go.opentelemetry.io/proto/otlp/trace/v1` | unsupported | `unsafe:Pointer`×7, `shim-ausente:reflect` |
| 398 | `google.golang.org/protobuf/protoadapt` | bloqueado |  |
| 399 | `google.golang.org/grpc/internal/pretty` | unsupported | `shim-ausente:encoding/json`×2 |
| 400 | `google.golang.org/protobuf/types/descriptorpb` | unsupported | `unsafe:Pointer`×34, `shim-ausente:reflect`, `unsafe:Slice` |
| 401 | `google.golang.org/protobuf/internal/editionssupport` | bloqueado |  |
| 402 | `google.golang.org/protobuf/types/gofeaturespb` | unsupported | `shim-ausente:reflect`, `unsafe:Pointer`, `unsafe:Slice` |
| 403 | `google.golang.org/protobuf/reflect/protodesc` | bloqueado |  |
| 404 | `google.golang.org/protobuf/types/known/anypb` | unsupported | `shim-ausente:reflect`, `unsafe:Pointer`, `unsafe:Slice` |
| 405 | `google.golang.org/genproto/googleapis/api/httpbody` | unsupported | `shim-ausente:reflect`, `unsafe:Pointer` |
| 406 | `google.golang.org/genproto/googleapis/rpc/status` | unsupported | `shim-ausente:reflect`, `unsafe:Pointer` |
| 407 | `google.golang.org/protobuf/types/known/durationpb` | unsupported | `shim-ausente:reflect`, `unsafe:Pointer`, `unsafe:Slice` |
| 408 | `google.golang.org/genproto/googleapis/rpc/errdetails` | unsupported | `unsafe:Pointer`×14, `shim-ausente:reflect` |
| 409 | `google.golang.org/protobuf/types/known/fieldmaskpb` | unsupported | `shim-ausente:reflect`, `unsafe:Pointer`, `unsafe:Slice` |
| 410 | `google.golang.org/protobuf/types/known/structpb` | unsupported | `unsafe:Pointer`×3, `shim-ausente:encoding/json`, `shim-ausente:reflect`, `unsafe:Slice` |
| 411 | `google.golang.org/protobuf/types/known/timestamppb` | unsupported | `shim-ausente:reflect`, `unsafe:Pointer`, `unsafe:Slice` |
| 412 | `github.com/prometheus/client_model/go` | unsupported | `unsafe:Pointer`×12, `shim-ausente:reflect` |
| 413 | `github.com/prometheus/common/model` | unsupported | `shim-ausente:encoding/json`×13, `shim-ausente:maps`×2, `conversao:pointer-pointer` |
| 414 | `github.com/prometheus/client_golang/prometheus/internal` | unsupported | `shim-ausente:bufio`, `shim-ausente:runtime/metrics` |
| 415 | `google.golang.org/grpc/binarylog/grpc_binarylog_v1` | unsupported | `unsafe:Pointer`×8, `shim-ausente:reflect`, `unsafe:Slice` |
| 416 | `google.golang.org/protobuf/types/known/wrapperspb` | unsupported | `unsafe:Pointer`×9, `shim-ausente:reflect`, `unsafe:Slice` |
| 417 | `gopkg.in/yaml.v2` | unsupported | `shim-ausente:reflect`×22, `shim-ausente:encoding/base64`, `shim-simbolo:time.parse` |
| 418 | `gopkg.in/yaml.v3` | unsupported | `shim-ausente:reflect`×26, `shim-ausente:encoding/base64`, `shim-simbolo:time.parse` |
| 419 | `github.com/golang/protobuf/proto` | unsupported | `shim-ausente:reflect`×14, `shim-ausente:encoding`×3, `shim-ausente:compress/gzip`, `shim-ausente:encoding/json` |
| 420 | `github.com/dgraph-io/badger/pb` | bloqueado |  |
| 421 | `github.com/minio/sha256-simd` | unsupported | `shim-ausente:hash`, `shim-ausente:io/ioutil` |
| 422 | `github.com/AndreasBriese/bbloom` | unsupported | `unsafe:Pointer`×2, `shim-ausente:encoding/json`, `shim-ausente:log` |
| 423 | `github.com/dgraph-io/ristretto/z` | substituicao | assembly: rtutil.s |
| 424 | `github.com/go-kit/log` | unsupported | `async:valor-func`×2, `shim-ausente:encoding/json`×2, `shim-ausente:reflect`×2, `shim-ausente:log`, `shim-ausente:runtime` |
| 425 | `github.com/go-kit/log/level` | bloqueado |  |
| 426 | `github.com/gogo/protobuf/proto` | unsupported | `shim-ausente:reflect`×193, `branch:goto`×2, `shim-ausente:encoding`×2, `shim-ausente:encoding/json`×2, `shim-ausente:log`×2 |
| 427 | `github.com/gogo/protobuf/protoc-gen-gogo/descriptor` | unsupported | `fmt-verbo:%#v-ponteiro`×7, `shim-ausente:compress/gzip`, `shim-ausente:reflect` |
| 428 | `github.com/gogo/protobuf/gogoproto` | bloqueado |  |
| 429 | `github.com/gogo/protobuf/types` | unsupported | `shim-ausente:reflect`×19 |
| 430 | `github.com/cockroachdb/errors/errorspb` | bloqueado |  |
| 431 | `github.com/hanwen/go-fuse/v2/splice` | unsupported | `shim-ausente:syscall`×5, `shim-simbolo:io.copy`, `shim-simbolo:os.open`, `shim-simbolo:os.readFile` |
| 432 | `github.com/ipfs/bbloom` | unsupported | `shim-ausente:encoding/json`×2 |
| 433 | `github.com/koron/go-ssdp/internal/ssdplog` | unsupported | `shim-ausente:log`×2 |
| 434 | `github.com/libp2p/go-libp2p-pubsub-router/pb` | bloqueado |  |
| 435 | `github.com/pion/logging` | unsupported | `shim-ausente:log`×2 |
| 436 | `github.com/prometheus/statsd_exporter/pkg/level` | bloqueado |  |
| 437 | `github.com/prometheus/statsd_exporter/pkg/mapper/fsm` | bloqueado |  |
| 438 | `go.opentelemetry.io/otel/internal/errorhandler` | unsupported | `shim-ausente:log`×2 |
| 439 | `golang.org/x/net/internal/timeseries` | unsupported | `shim-ausente:log` |
| 440 | `google.golang.org/grpc/grpclog/internal` | unsupported | `shim-ausente:log`×2, `shim-simbolo:io.multiWriter` |
| 441 | `google.golang.org/grpc/grpclog` | bloqueado |  |
| 442 | `google.golang.org/grpc/connectivity` | bloqueado |  |
| 443 | `google.golang.org/grpc/internal/grpclog` | bloqueado |  |
| 444 | `github.com/go-logr/logr` | unsupported | `shim-ausente:context`×7, `shim-ausente:log/slog`×6 |
| 445 | `github.com/libp2p/go-libp2p-pubsub/internal/gologshim` | unsupported | `shim-ausente:log/slog`×6 |
| 446 | `github.com/libp2p/go-libp2p-pubsub/pb` | unsupported | `unsafe:Pointer`×35, `shim-ausente:log/slog`×2, `shim-ausente:reflect`×2, `unsafe:Slice`×2 |
| 447 | `github.com/libp2p/go-libp2p/gologshim` | unsupported | `shim-ausente:log/slog`×8, `shim-ausente:context` |
| 448 | `go.opentelemetry.io/auto/sdk` | unsupported | `shim-ausente:context`×3, `construtor-ambiguo`, `shim-ausente:log/slog`, `shim-ausente:reflect` |
| 449 | `lukechampine.com/blake3/guts` | substituicao | assembly: compress_amd64.s |
| 450 | `lukechampine.com/blake3/bao` | unsupported | `range:pointer` |
| 451 | `lukechampine.com/blake3` | unsupported | `async:contexto-sincrono`×2 |
| 452 | `github.com/multiformats/go-multihash/register/blake3` | bloqueado |  |
| 453 | `github.com/multiformats/go-multihash/register/all` | bloqueado |  |
| 454 | `github.com/dustin/go-humanize` | unsupported | `shim-ausente:math/big`×38 |
| 455 | `github.com/flynn/noise` | unsupported | `shim-ausente:hash`×8, `shim-ausente:crypto/rand`×2, `shim-ausente:crypto/aes`, `shim-ausente:crypto/cipher`, `shim-ausente:crypto/sha256` (+1) |
| 456 | `github.com/klauspost/compress/s2` | unsupported | `branch:goto`×14, `shim-ausente:hash/crc32`×3, `async:contexto-sincrono`, `shim-ausente:encoding/json`, `shim-ausente:runtime` (+1) |
| 457 | `github.com/libp2p/go-libp2p-kbucket/keyspace` | unsupported | `shim-ausente:math/big`×5 |
| 458 | `github.com/minio/minlz` | unsupported | `branch:goto`×6, `shim-ausente:hash/crc32`×4, `async:contexto-sincrono`, `shim-ausente:encoding/json`, `shim-ausente:runtime` (+1) |
| 459 | `github.com/mr-tron/base58` | unsupported | `shim-ausente:math/big`×5 |
| 460 | `github.com/mr-tron/base58/base58` | unsupported | `shim-ausente:math/big`×5 |
| 461 | `github.com/multiformats/go-multibase` | unsupported | `shim-ausente:encoding/hex`×2 |
| 462 | `github.com/multiformats/go-multihash` | unsupported | `shim-ausente:hash`×3, `shim-ausente:encoding/hex`×2, `shim-simbolo:io.copy` |
| 463 | `github.com/ipfs/go-cid` | unsupported | `shim-ausente:encoding/json` |
| 464 | `github.com/ipfs/boxo/bitswap/client/wantlist` | unsupported | `shim-ausente:cmp` |
| 465 | `github.com/ipfs/boxo/ipld/unixfs/private/linksize` | bloqueado |  |
| 466 | `github.com/ipfs/boxo/path` | unsupported | `shim-ausente:path` |
| 467 | `github.com/ipfs/boxo/verifcid` | bloqueado |  |
| 468 | `github.com/ipfs/boxo/bitswap/internal/defaults` | bloqueado |  |
| 469 | `github.com/ipfs/go-cidutil` | unsupported | `shim-ausente:context`, `shim-ausente:slices` |
| 470 | `github.com/ipfs/go-cidutil/cidenc` | bloqueado |  |
| 471 | `github.com/ipld/go-car/v2/internal/carv1/util` | unsupported | `shim-simbolo:io.limitReader` |
| 472 | `github.com/ipld/go-ipld-prime/linking/cid` | bloqueado |  |
| 473 | `github.com/ipld/go-ipld-prime/codec/dagcbor` | bloqueado |  |
| 474 | `github.com/ipld/go-ipld-prime/codec/cbor` | bloqueado |  |
| 475 | `github.com/ipld/go-ipld-prime/codec/dagjson` | unsupported | `shim-ausente:encoding/base64`×2 |
| 476 | `github.com/ceramicnetwork/go-dag-jose/dagjose` | unsupported | `conversao:pointer-pointer`×44, `branch:goto`×14, `shim-ausente:encoding/base64`×2, `shim-ausente:reflect`×2 |
| 477 | `github.com/ipld/go-ipld-prime/codec/json` | bloqueado |  |
| 478 | `github.com/ipld/go-ipld-prime/traversal/selector` | unsupported | `shim-simbolo:io.newSectionReader` |
| 479 | `github.com/ipld/go-ipld-prime/traversal` | unsupported | `shim-ausente:context` |
| 480 | `github.com/ipld/go-ipld-prime/traversal/selector/builder` | bloqueado |  |
| 481 | `github.com/ipld/go-ipld-prime/traversal/selector/parse` | bloqueado |  |
| 482 | `github.com/libp2p/go-libp2p-kad-dht/provider/internal` | bloqueado |  |
| 483 | `github.com/pion/dtls/v3/pkg/crypto/elliptic` | unsupported | `shim-ausente:crypto/ecdh`, `shim-ausente:crypto/rand` |
| 484 | `github.com/pion/randutil` | unsupported | `shim-ausente:crypto/rand`×2, `shim-ausente:math/rand`×2 |
| 485 | `github.com/pion/rtp` | bloqueado |  |
| 486 | `github.com/pion/interceptor` | bloqueado |  |
| 487 | `github.com/pion/interceptor/internal/rtpbuffer` | bloqueado |  |
| 488 | `github.com/pion/interceptor/pkg/flexfec/util` | bloqueado |  |
| 489 | `github.com/pion/interceptor/pkg/flexfec` | bloqueado |  |
| 490 | `github.com/pion/interceptor/pkg/nack` | unsupported | `async:contexto-sincrono`, `opassign-impuro` |
| 491 | `github.com/pion/interceptor/pkg/report` | unsupported | `async:contexto-sincrono`×2, `opassign-impuro`, `shim-ausente:math/rand`, `shim-simbolo:time.Ticker`, `shim-simbolo:time.newTicker` |
| 492 | `github.com/pion/interceptor/pkg/rfc8888` | unsupported | `async:contexto-sincrono`, `shim-simbolo:time.Ticker`, `shim-simbolo:time.newTicker` |
| 493 | `github.com/pion/interceptor/pkg/twcc` | unsupported | `shim-ausente:math/rand` |
| 494 | `github.com/pion/rtp/codecs` | bloqueado |  |
| 495 | `github.com/pion/webrtc/v4/internal/util` | bloqueado |  |
| 496 | `github.com/pion/webrtc/v4/pkg/media` | bloqueado |  |
| 497 | `github.com/whyrusleeping/cbor/go` | unsupported | `shim-ausente:reflect`×12, `shim-ausente:math/big`×3 |
| 498 | `github.com/ipld/go-car/v2/index` | bloqueado |  |
| 499 | `github.com/whyrusleeping/chunker` | unsupported | `shim-ausente:hash`×2, `shim-ausente:crypto/rand`, `shim-simbolo:io.SectionReader` |
| 500 | `github.com/whyrusleeping/go-keyspace` | unsupported | `shim-ausente:math/big`×4 |
| 501 | `github.com/whyrusleeping/go-sysinfo` | unsupported | `shim-ausente:io/ioutil`, `shim-ausente:syscall` |
| 502 | `golang.org/x/crypto/cryptobyte` | unsupported | `shim-ausente:math/big`×3, `shim-ausente:encoding/asn1`, `shim-ausente:reflect` |
| 503 | `github.com/gabriel-vasile/mimetype` | unsupported | `shim-ausente:mime`×3, `shim-simbolo:os.open` |
| 504 | `github.com/cheggaaa/pb/v3/termutil` | unsupported | `unsafe:Pointer`×3, `shim-simbolo:os.Signal`×2, `shim-simbolo:os.interrupt`, `shim-simbolo:os.open` |
| 505 | `github.com/hanwen/go-fuse/v2/internal` | unsupported | `shim-ausente:os/user` |
| 506 | `github.com/caddyserver/certmagic/internal/atomicfile` | unsupported | `shim-ausente:path/filepath`, `shim-simbolo:os.remove` |
| 507 | `github.com/facebookgo/atomicfile` | unsupported | `shim-ausente:path/filepath`, `shim-simbolo:io/fs.DirEntry` |
| 508 | `github.com/fsnotify/fsnotify` | unsupported | `async:contexto-sincrono`, `shim-ausente:path/filepath`, `shim-simbolo:os.newFile`, `unsafe:Pointer` |
| 509 | `github.com/go-logr/logr/funcr` | unsupported | `shim-ausente:context`, `shim-ausente:log/slog`, `shim-ausente:reflect`, `shim-simbolo:strconv.formatComplex` |
| 510 | `github.com/go-logr/stdr` | unsupported | `shim-ausente:log` |
| 511 | `github.com/ipfs/kubo/misc/fsutil` | unsupported | `shim-simbolo:os.lstat`, `shim-simbolo:os.stat`, `shim-simbolo:os.userHomeDir` |
| 512 | `github.com/ipfs/kubo/repo/fsrepo/migrations/atomicfile` | unsupported | `shim-ausente:path/filepath`, `shim-simbolo:io/fs.DirEntry` |
| 513 | `github.com/prometheus/procfs/internal/fs` | unsupported | `shim-ausente:path/filepath`, `shim-simbolo:os.stat` |
| 514 | `github.com/syndtr/goleveldb/leveldb/storage` | unsupported | `shim-simbolo:os.openFile`×2, `shim-ausente:path/filepath`, `shim-ausente:syscall`, `shim-simbolo:fmt.sscanf`, `shim-simbolo:io/fs.DirEntry` (+4) |
| 515 | `github.com/syndtr/goleveldb/leveldb/errors` | bloqueado |  |
| 516 | `github.com/syndtr/goleveldb/leveldb/iterator` | unsupported | `shim-ausente:container/heap` |
| 517 | `github.com/syndtr/goleveldb/leveldb/journal` | bloqueado |  |
| 518 | `github.com/syndtr/goleveldb/leveldb/memdb` | unsupported | `shim-ausente:math/rand`×2, `branch:goto` |
| 519 | `github.com/syndtr/goleveldb/leveldb/table` | bloqueado |  |
| 520 | `github.com/syndtr/goleveldb/leveldb` | unsupported | `shim-ausente:container/list`×3, `unsafe:Pointer`×2, `async:valor-func`, `branch:goto`, `construtor-ambiguo` (+3) |
| 521 | `go4.org/lock` | unsupported | `shim-simbolo:os.stat`×2, `shim-ausente:path/filepath`, `shim-ausente:syscall`, `shim-simbolo:os.Signal`, `shim-simbolo:os.open` (+1) |
| 522 | `golang.org/x/sys/execabs` | unsupported | `shim-ausente:os/exec`×6, `shim-ausente:context` |
| 523 | `github.com/RaduBerinde/axisds` | unsupported | `shim-simbolo:fmt.sscanf` |
| 524 | `github.com/RaduBerinde/axisds/regiontree` | unsupported | `layout:typeparam` |
| 525 | `github.com/ipfs/boxo/util` | unsupported | `shim-ausente:path/filepath`, `shim-ausente:runtime/debug`, `shim-simbolo:os.lstat`, `shim-simbolo:time.parse` |
| 526 | `github.com/ipfs/go-block-format` | unsupported | `async:contexto-sincrono` |
| 527 | `github.com/ipfs/boxo/bitswap/client/internal/sessioninterestmanager` | unsupported | `shim-ausente:slices` |
| 528 | `github.com/ipfs/boxo/exchange` | unsupported | `shim-ausente:context`×3 |
| 529 | `github.com/ipfs/go-ipld-format` | unsupported | `shim-ausente:context`×19, `shim-ausente:runtime` |
| 530 | `github.com/ipfs/boxo/filestore/posinfo` | unsupported | `shim-simbolo:io/fs.FileInfo` |
| 531 | `github.com/ipfs/boxo/ipld/merkledag/traverse` | unsupported | `shim-ausente:context` |
| 532 | `github.com/ipfs/boxo/pinning/pinner` | unsupported | `shim-ausente:context` |
| 533 | `github.com/ipfs/kubo/core/commands/e` | unsupported | `shim-ausente:runtime/debug` |
| 534 | `github.com/libp2p/go-libp2p/core/internal/catch` | unsupported | `shim-ausente:runtime/debug` |
| 535 | `github.com/libp2p/go-libp2p/p2p/protocol/identify/internal/user-agent` | unsupported | `shim-ausente:runtime/debug` |
| 536 | `github.com/libp2p/go-msgio/pbio` | unsupported | `shim-ausente:bufio`×2, `shim-ausente:runtime/debug` |
| 537 | `github.com/libp2p/go-msgio/protoio` | unsupported | `shim-ausente:bufio`×2, `shim-ausente:runtime/debug` |
| 538 | `github.com/multiformats/go-multistream` | unsupported | `shim-ausente:bufio`×4, `shim-ausente:runtime/debug`×3, `async:contexto-sincrono`, `conversao:slice-typeparam`, `conversao:typeparam-slice` |
| 539 | `github.com/libp2p/go-libp2p/core/protocol` | bloqueado |  |
| 540 | `github.com/ipfs/boxo/bitswap/network/bsnet/internal` | bloqueado |  |
| 541 | `github.com/libp2p/go-libp2p-kad-dht/amino` | bloqueado |  |
| 542 | `go.opencensus.io/trace` | unsupported | `shim-ausente:context`×7, `shim-ausente:math/rand` |
| 543 | `go.opencensus.io/metric/metricexport` | unsupported | `shim-ausente:context`×2, `shim-simbolo:time.Ticker` |
| 544 | `github.com/ipfs/kubo/repo/fsrepo/migrations/common` | unsupported | `shim-ausente:testing`×6, `shim-ausente:path/filepath`×3, `shim-ausente:encoding/json`×2, `shim-ausente:maps`×2, `shim-ausente:slices` (+2) |
| 545 | `github.com/ipfs/kubo/repo/fsrepo/migrations/fs-repo-17-to-18/migration` | bloqueado |  |
| 546 | `github.com/kr/pretty` | unsupported | `shim-ausente:reflect`×14, `shim-ausente:log`×3, `conversao:pointer-pointer` |
| 547 | `github.com/cockroachdb/errors/errbase` | unsupported | `shim-ausente:context`×41, `conversao:pointer-pointer`×3, `shim-ausente:reflect`×3, `shim-ausente:syscall` |
| 548 | `github.com/cockroachdb/errors/barriers` | unsupported | `shim-ausente:context`×3 |
| 549 | `github.com/cockroachdb/errors/contexttags` | unsupported | `shim-ausente:context`×3 |
| 550 | `github.com/cockroachdb/errors/domains` | unsupported | `shim-ausente:context`, `shim-ausente:runtime` |
| 551 | `github.com/cockroachdb/errors/hintdetail` | unsupported | `shim-ausente:context`×4 |
| 552 | `github.com/cockroachdb/errors/join` | unsupported | `shim-ausente:context` |
| 553 | `github.com/cockroachdb/errors/markers` | unsupported | `shim-ausente:reflect`×5, `shim-ausente:context`×2 |
| 554 | `github.com/cockroachdb/errors/assert` | unsupported | `shim-ausente:context` |
| 555 | `github.com/cockroachdb/errors/issuelink` | unsupported | `shim-ausente:context`×2 |
| 556 | `github.com/cockroachdb/errors/safedetails` | unsupported | `shim-ausente:reflect`×2, `shim-ausente:context` |
| 557 | `github.com/cockroachdb/errors/secondary` | unsupported | `shim-ausente:context`×2 |
| 558 | `github.com/cockroachdb/errors/telemetrykeys` | unsupported | `shim-ausente:context` |
| 559 | `github.com/ipld/go-ipld-prime/node/bindnode` | unsupported | `shim-ausente:reflect`×65, `conversao:pointer-pointer`, `shim-ausente:go/format`, `shim-ausente:go/token`, `shim-ausente:runtime` |
| 560 | `github.com/ipld/go-ipld-prime/schema/dmt` | bloqueado |  |
| 561 | `github.com/ipld/go-ipld-prime/schema/dsl` | unsupported | `shim-ausente:bufio`×2, `shim-ausente:reflect`, `shim-simbolo:os.open` |
| 562 | `github.com/ipld/go-ipld-prime` | unsupported | `shim-ausente:reflect`, `shim-simbolo:os.open` |
| 563 | `github.com/ipfs/boxo/fetcher` | unsupported | `shim-ausente:context`×2 |
| 564 | `github.com/ipfs/boxo/fetcher/helpers` | unsupported | `shim-ausente:context`×3 |
| 565 | `github.com/ipfs/go-ipld-git` | unsupported | `conversao:pointer-pointer`×24, `shim-ausente:bufio`×11, `shim-ausente:encoding/hex`×2, `branch:goto`, `shim-ausente:compress/zlib` |
| 566 | `github.com/ipfs/go-ipld-legacy` | unsupported | `shim-ausente:context`, `shim-ausente:encoding/json` |
| 567 | `github.com/ipfs/go-unixfsnode/data` | unsupported | `conversao:pointer-pointer`×12, `branch:goto`×6 |
| 568 | `github.com/ipld/go-car/v2/internal/loader` | bloqueado |  |
| 569 | `github.com/ipld/go-codec-dagpb` | unsupported | `conversao:pointer-pointer`×9, `branch:goto`×4 |
| 570 | `github.com/ipfs/go-unixfsnode/file` | unsupported | `shim-ausente:context`×5, `async:contexto-sincrono`×2, `shim-simbolo:io.multiReader` |
| 571 | `github.com/ipfs/go-unixfsnode/iter` | bloqueado |  |
| 572 | `github.com/ipfs/go-unixfsnode/hamt` | unsupported | `shim-ausente:context`×4, `shim-ausente:hash` |
| 573 | `github.com/ipfs/go-unixfsnode/utils` | bloqueado |  |
| 574 | `github.com/ipfs/go-unixfsnode/directory` | unsupported | `shim-ausente:context` |
| 575 | `github.com/ipfs/go-unixfsnode` | unsupported | `shim-ausente:context`×5, `shim-simbolo:io.copy` |
| 576 | `go.opencensus.io/tag` | unsupported | `shim-ausente:context`×5 |
| 577 | `go.opencensus.io/stats/internal` | bloqueado |  |
| 578 | `go.opencensus.io/stats` | unsupported | `shim-ausente:context`×3 |
| 579 | `go.opencensus.io/stats/view` | unsupported | `shim-ausente:reflect`×2, `shim-simbolo:time.Ticker`×2, `shim-simbolo:time.newTicker` |
| 580 | `filippo.io/keygen` | unsupported | `shim-ausente:crypto/elliptic`×3, `shim-ausente:crypto/rsa`×2, `shim-ausente:crypto/rand`, `shim-ausente:crypto/sha256` |
| 581 | `github.com/decred/dcrd/dcrec/secp256k1/v4` | unsupported | `shim-ausente:math/big`×6, `shim-ausente:encoding/hex`×4, `shim-ausente:crypto/ecdsa`×2, `shim-ausente:crypto/elliptic`, `shim-ausente:crypto/rand` (+3) |
| 582 | `github.com/decred/dcrd/dcrec/secp256k1/v4/ecdsa` | unsupported | `shim-ausente:math/big` |
| 583 | `github.com/klauspost/compress/zstd` | unsupported | `shim-ausente:runtime`×6, `shim-ausente:hash/crc32`×4, `async:contexto-sincrono`×2, `range:pointer`×2, `shim-ausente:context`×2 (+7) |
| 584 | `github.com/libdns/libdns` | unsupported | `shim-ausente:context`×5, `shim-ausente:net/netip`×2 |
| 585 | `github.com/coreos/go-systemd/v22/daemon` | unsupported | `shim-ausente:net`, `shim-simbolo:os.unsetenv` |
| 586 | `github.com/google/gopacket/routing` | unsupported | `shim-ausente:net`×4, `shim-ausente:syscall` |
| 587 | `github.com/google/uuid` | unsupported | `shim-ausente:crypto/rand`×2, `shim-ausente:database/sql/driver`×2, `shim-ausente:net`×2, `shim-ausente:crypto/md5`, `shim-ausente:crypto/sha1` (+4) |
| 588 | `github.com/hanwen/go-fuse/v2/fuse` | unsupported | `unsafe:Pointer`×47, `shim-ausente:syscall`×19, `shim-ausente:log`×7, `shim-ausente:context`×3, `shim-simbolo:io/fs.FileInfo`×2 (+10) |
| 589 | `github.com/hanwen/go-fuse/v2/fs` | unsupported | `shim-ausente:context`×66, `shim-ausente:syscall`×15, `unsafe:Pointer` |
| 590 | `github.com/ipfs/go-datastore` | unsupported | `shim-ausente:context`×30, `shim-ausente:path`, `shim-ausente:reflect` |
| 591 | `github.com/ipfs/boxo/datastore/dshelp` | bloqueado |  |
| 592 | `github.com/ipfs/go-datastore/keytransform` | unsupported | `shim-ausente:context`×3 |
| 593 | `github.com/ipfs/go-datastore/mount` | unsupported | `shim-ausente:context`×2, `shim-ausente:container/heap`, `shim-ausente:slices` |
| 594 | `github.com/ipfs/go-datastore/namespace` | bloqueado |  |
| 595 | `github.com/ipfs/boxo/pinning/pinner/dsindex` | unsupported | `shim-ausente:context`×3 |
| 596 | `github.com/ipfs/go-datastore/sync` | unsupported | `shim-ausente:context`×2 |
| 597 | `github.com/ipfs/go-ds-leveldb` | unsupported | `shim-ausente:context`×4 |
| 598 | `github.com/ipfs/go-ds-measure` | unsupported | `shim-ausente:context`×2 |
| 599 | `github.com/ipfs/go-ipfs-ds-help` | bloqueado |  |
| 600 | `github.com/jackpal/go-nat-pmp` | unsupported | `shim-ausente:net`×3 |
| 601 | `github.com/libp2p/go-cidranger/net` | unsupported | `shim-ausente:net`×6 |
| 602 | `github.com/libp2p/go-cidranger` | unsupported | `shim-ausente:net`×13 |
| 603 | `github.com/libp2p/go-libp2p-asn-util` | unsupported | `go:embed` |
| 604 | `github.com/libp2p/go-libp2p/p2p/net/pnet` | unsupported | `shim-ausente:net`×3 |
| 605 | `github.com/libp2p/go-netroute` | unsupported | `shim-ausente:net`×6, `shim-ausente:syscall`×5 |
| 606 | `github.com/libp2p/go-reuseport` | unsupported | `shim-ausente:net`×7, `shim-ausente:syscall` |
| 607 | `github.com/libp2p/go-yamux/v5` | unsupported | `shim-ausente:net`×6, `shim-simbolo:time.Timer` |
| 608 | `github.com/marten-seemann/tcp` | unsupported | `unsafe:Pointer`×4, `shim-ausente:net`×3, `shim-ausente:syscall` |
| 609 | `github.com/pion/dtls/v3/internal/net` | unsupported | `shim-ausente:net`×2 |
| 610 | `github.com/pion/dtls/v3/pkg/net` | unsupported | `shim-ausente:net`×5 |
| 611 | `github.com/pion/dtls/v3/internal/net/udp` | unsupported | `shim-ausente:net`×4 |
| 612 | `github.com/pion/dtls/v3/pkg/protocol` | unsupported | `shim-ausente:net` |
| 613 | `github.com/pion/dtls/v3/pkg/crypto/prf` | unsupported | `shim-ausente:hash`×2, `shim-ausente:crypto/ecdh`, `shim-ausente:crypto/hmac` |
| 614 | `github.com/pion/dtls/v3/pkg/protocol/alert` | bloqueado |  |
| 615 | `github.com/pion/ice/v4/internal/fakenet` | unsupported | `shim-ausente:net`×2 |
| 616 | `github.com/pion/sctp` | unsupported | `shim-ausente:context`×3, `shim-ausente:hash/crc32`×3, `shim-simbolo:time.Timer`×2, `shim-simbolo:time.afterFunc`×2, `async:contexto-sincrono` (+3) |
| 617 | `github.com/pion/datachannel` | unsupported | `async:contexto-sincrono` |
| 618 | `github.com/pion/srtp/v3` | unsupported | `async:contexto-sincrono`×4, `shim-ausente:crypto/aes`×3, `shim-ausente:net`×3, `shim-ausente:crypto/cipher`×2, `shim-ausente:hash` (+1) |
| 619 | `github.com/pion/transport/v3` | unsupported | `shim-ausente:net`×7 |
| 620 | `github.com/pion/transport/v3/vnet` | unsupported | `shim-ausente:net`×26, `shim-ausente:context`, `shim-ausente:math/rand` |
| 621 | `github.com/pion/transport/v4` | unsupported | `shim-ausente:net`×7, `shim-ausente:context` |
| 622 | `github.com/pion/transport/v4/netctx` | unsupported | `shim-ausente:net`×7, `shim-ausente:context`×5 |
| 623 | `github.com/pion/turn/v4/internal/ipnet` | unsupported | `shim-ausente:net`×3 |
| 624 | `github.com/prometheus/procfs` | unsupported | `shim-ausente:bufio`×36, `shim-simbolo:os.open`×7, `shim-ausente:net`×6, `shim-simbolo:fmt.sscanf`×3, `shim-simbolo:os.getpagesize`×2 (+5) |
| 625 | `github.com/whyrusleeping/multiaddr-filter` | unsupported | `shim-ausente:net`×2 |
| 626 | `github.com/wlynxg/anet` | unsupported | `shim-ausente:net`×3 |
| 627 | `github.com/pion/transport/v3/stdnet` | unsupported | `shim-ausente:net`×3 |
| 628 | `github.com/pion/transport/v4/stdnet` | unsupported | `shim-ausente:net`×3, `shim-ausente:context` |
| 629 | `golang.org/x/net/internal/socket` | unsupported | `shim-ausente:net`×14, `shim-ausente:syscall`×8, `unsafe:Pointer`×7, `func-sem-corpo`×2, `shim-simbolo:os.newSyscallError` |
| 630 | `golang.org/x/net/internal/socks` | unsupported | `shim-ausente:net`×4, `shim-ausente:context` |
| 631 | `golang.org/x/net/ipv4` | unsupported | `shim-ausente:net`×15, `unsafe:Pointer`×3 |
| 632 | `github.com/koron/go-ssdp/internal/multicast` | unsupported | `shim-ausente:net`×15 |
| 633 | `golang.org/x/net/ipv6` | unsupported | `shim-ausente:net`×13, `unsafe:Pointer`×4, `opassign-impuro` |
| 634 | `github.com/pion/mdns/v2` | unsupported | `shim-ausente:net/netip`×9, `shim-ausente:net`×7, `shim-ausente:context` |
| 635 | `google.golang.org/grpc/internal` | unsupported | `shim-ausente:context`, `shim-ausente:net`, `shim-simbolo:time.Timer` |
| 636 | `google.golang.org/grpc/codes` | bloqueado |  |
| 637 | `google.golang.org/grpc/internal/mem` | unsupported | `shim-ausente:slices` |
| 638 | `google.golang.org/grpc/internal/resolver/dns/internal` | unsupported | `shim-ausente:context`, `shim-ausente:net` |
| 639 | `google.golang.org/grpc/internal/status` | bloqueado |  |
| 640 | `google.golang.org/grpc/internal/syscall` | unsupported | `shim-ausente:net`×2, `shim-ausente:syscall`×2 |
| 641 | `google.golang.org/grpc/mem` | unsupported | `shim-simbolo:io.WriterTo` |
| 642 | `google.golang.org/grpc/internal/transport/readyreader` | unsupported | `shim-ausente:syscall`×3, `shim-ausente:net` |
| 643 | `google.golang.org/grpc/metadata` | unsupported | `shim-ausente:context`×7 |
| 644 | `google.golang.org/grpc/internal/balancerload` | bloqueado |  |
| 645 | `google.golang.org/grpc/internal/grpcutil` | unsupported | `shim-ausente:context`×2 |
| 646 | `google.golang.org/grpc/encoding` | unsupported | `shim-ausente:slices` |
| 647 | `google.golang.org/grpc/encoding/gzip` | unsupported | `shim-ausente:compress/gzip`×5 |
| 648 | `google.golang.org/grpc/encoding/proto` | bloqueado |  |
| 649 | `google.golang.org/grpc/stats` | unsupported | `shim-ausente:context`×5, `shim-ausente:net`×3, `shim-ausente:maps` |
| 650 | `google.golang.org/grpc/experimental/stats` | unsupported | `conversao:pointer-pointer`×14, `shim-ausente:context`×2, `shim-ausente:maps` |
| 651 | `google.golang.org/grpc/internal/stats` | unsupported | `shim-ausente:context`×4 |
| 652 | `google.golang.org/grpc/status` | unsupported | `shim-ausente:context` |
| 653 | `google.golang.org/grpc/internal/binarylog` | unsupported | `shim-ausente:net`×5, `shim-ausente:bufio`×2, `shim-ausente:context`×2 |
| 654 | `google.golang.org/grpc/tap` | unsupported | `shim-ausente:context` |
| 655 | `golang.org/x/net/http/httpguts` | unsupported | `shim-ausente:net`, `shim-ausente:net/textproto` |
| 656 | `github.com/cockroachdb/pebble/v2/internal/lsmview` | unsupported | `shim-ausente:net/url` |
| 657 | `github.com/coreos/go-systemd/v22/activation` | unsupported | `shim-ausente:net`×3, `shim-ausente:crypto/tls`×2, `shim-simbolo:os.unsetenv` |
| 658 | `github.com/getsentry/sentry-go/internal/otel/baggage` | unsupported | `shim-ausente:net/url` |
| 659 | `github.com/ipfs/go-ipfs-redirects-file` | unsupported | `shim-ausente:net/url`×3, `shim-simbolo:io.LimitedReader` |
| 660 | `github.com/libp2p/go-libp2p/core/crypto` | unsupported | `conversao:pointer-pointer`×5, `shim-ausente:crypto/ecdsa`×5, `shim-ausente:crypto/x509`×5, `shim-ausente:crypto`×3, `shim-ausente:crypto/ed25519`×3 (+6) |
| 661 | `github.com/libp2p/go-libp2p/core/record` | unsupported | `shim-ausente:reflect`×4 |
| 662 | `github.com/miekg/dns` | unsupported | `shim-ausente:net`×41, `shim-ausente:crypto`×8, `shim-ausente:encoding/hex`×8, `shim-ausente:encoding/base64`×7, `shim-ausente:crypto/tls`×6 (+20) |
| 663 | `github.com/libp2p/zeroconf/v2` | unsupported | `shim-ausente:net`×19, `shim-ausente:context`×3 |
| 664 | `github.com/multiformats/go-multiaddr` | unsupported | `shim-ausente:encoding/base32`×8, `shim-ausente:encoding/base64`×4, `shim-ausente:net`×4, `conversao:slice-named-slice`×2, `shim-ausente:log`×2 (+4) |
| 665 | `github.com/libp2p/go-libp2p/core/peer` | unsupported | `shim-ausente:encoding/json`×2 |
| 666 | `github.com/ipfs/boxo/bitswap/client/internal/blockpresencemanager` | bloqueado |  |
| 667 | `github.com/ipfs/boxo/bitswap/client/traceability` | bloqueado |  |
| 668 | `github.com/ipfs/boxo/bitswap/client/internal/notifications` | unsupported | `shim-ausente:context`×2 |
| 669 | `github.com/ipfs/boxo/retrieval` | unsupported | `shim-ausente:context`×3, `shim-ausente:slices` |
| 670 | `github.com/ipfs/boxo/routing/http/types` | unsupported | `shim-ausente:encoding/json`×9 |
| 671 | `github.com/ipfs/boxo/routing/http/types/json` | unsupported | `shim-ausente:encoding/json` |
| 672 | `github.com/ipfs/boxo/routing/http/types/ndjson` | unsupported | `shim-ausente:encoding/json`×2 |
| 673 | `github.com/ipfs/go-peertaskqueue/peertask` | bloqueado |  |
| 674 | `github.com/ipfs/go-peertaskqueue/peertracker` | bloqueado |  |
| 675 | `github.com/ipfs/go-peertaskqueue` | bloqueado |  |
| 676 | `github.com/libp2p/go-libp2p-kad-dht/qpeerset` | unsupported | `shim-ausente:math/big`×3 |
| 677 | `github.com/libp2p/go-libp2p-pubsub/partialmessages` | unsupported | `shim-ausente:iter`×2, `shim-ausente:log/slog` |
| 678 | `github.com/libp2p/go-libp2p-record` | bloqueado |  |
| 679 | `github.com/libp2p/go-libp2p/core/discovery` | unsupported | `shim-ausente:context`×3 |
| 680 | `github.com/libp2p/go-libp2p/core/metrics` | bloqueado |  |
| 681 | `github.com/libp2p/go-libp2p/core/peerstore` | unsupported | `shim-ausente:context`×2 |
| 682 | `github.com/libp2p/go-libp2p/core/network` | unsupported | `shim-ausente:context`×19, `shim-ausente:net`×4 |
| 683 | `github.com/ipfs/boxo/bitswap/message` | unsupported | `shim-ausente:maps` |
| 684 | `github.com/ipfs/boxo/bitswap/tracer` | bloqueado |  |
| 685 | `github.com/libp2p/go-libp2p/core/connmgr` | unsupported | `shim-ausente:context`×2 |
| 686 | `github.com/libp2p/go-libp2p/core/event` | unsupported | `shim-ausente:reflect` |
| 687 | `github.com/libp2p/go-libp2p/core/host` | unsupported | `shim-ausente:context` |
| 688 | `github.com/libp2p/go-libp2p-gostream` | unsupported | `shim-ausente:net`×4, `shim-ausente:context` |
| 689 | `github.com/libp2p/go-libp2p/core/routing` | unsupported | `shim-ausente:context`×12, `shim-ausente:encoding/json`, `shim-ausente:maps`, `shim-ausente:slices` |
| 690 | `github.com/libp2p/go-libp2p/core/sec` | unsupported | `shim-ausente:context`, `shim-ausente:net` |
| 691 | `github.com/libp2p/go-libp2p/p2p/discovery/backoff` | unsupported | `shim-ausente:math/rand`×9, `shim-ausente:context`×4, `shim-ausente:log/slog` |
| 692 | `github.com/libp2p/go-libp2p/p2p/discovery/mdns` | unsupported | `shim-ausente:math/rand`×2, `shim-ausente:context`, `shim-ausente:log/slog` |
| 693 | `github.com/libp2p/go-libp2p/p2p/discovery/routing` | unsupported | `shim-ausente:context`×2 |
| 694 | `github.com/libp2p/go-libp2p/p2p/host/peerstore` | bloqueado |  |
| 695 | `github.com/libp2p/go-libp2p/p2p/host/routed` | unsupported | `shim-ausente:context`×2, `shim-ausente:log/slog` |
| 696 | `github.com/libp2p/go-libp2p/p2p/muxer/yamux` | unsupported | `conversao:pointer-pointer`×3, `shim-ausente:context`, `shim-ausente:net` |
| 697 | `github.com/libp2p/go-libp2p/p2p/net/connmgr` | unsupported | `shim-ausente:context`×3, `shim-ausente:log/slog`×3, `async:valor-func` |
| 698 | `github.com/libp2p/go-libp2p/p2p/net/gostream` | unsupported | `shim-ausente:net`×4, `shim-ausente:context` |
| 699 | `github.com/libp2p/go-libp2p/p2p/protocol/circuitv2/proto` | bloqueado |  |
| 700 | `github.com/libp2p/go-libp2p/p2p/protocol/circuitv2/util` | bloqueado |  |
| 701 | `github.com/libp2p/go-libp2p/p2p/protocol/ping` | unsupported | `shim-ausente:context`×2, `shim-ausente:log/slog`×2, `async:valor-func` |
| 702 | `github.com/libp2p/go-libp2p/p2p/security/insecure` | unsupported | `shim-ausente:context`, `shim-ausente:net` |
| 703 | `github.com/multiformats/go-multiaddr-dns` | unsupported | `shim-ausente:context`×5, `shim-ausente:net`×2 |
| 704 | `github.com/multiformats/go-multiaddr-fmt` | bloqueado |  |
| 705 | `github.com/multiformats/go-multiaddr/net` | unsupported | `shim-ausente:net`×36, `conversao:slice-named-slice`×5, `shim-ausente:context`, `shim-ausente:path/filepath` |
| 706 | `github.com/libp2p/go-libp2p/core/transport` | unsupported | `shim-ausente:context`×7, `shim-ausente:net`×2 |
| 707 | `github.com/libp2p/go-libp2p/p2p/canonicallog` | unsupported | `shim-ausente:log/slog`×3, `shim-ausente:context`, `shim-ausente:math/rand`, `shim-ausente:net` |
| 708 | `github.com/libp2p/go-libp2p/p2p/host/peerstore/pstoremem` | unsupported | `shim-ausente:context`×5, `shim-ausente:container/heap`, `shim-ausente:log/slog` |
| 709 | `github.com/libp2p/go-libp2p-pubsub` | unsupported | `shim-ausente:context`×26, `shim-ausente:log/slog`×20, `shim-ausente:math/rand`×5, `shim-ausente:iter`×4, `async:valor-func`×2 (+4) |
| 710 | `github.com/libp2p/go-libp2p/p2p/net/reuseport` | unsupported | `shim-ausente:net`×6, `shim-ausente:context`×2, `shim-ausente:log/slog` |
| 711 | `github.com/libp2p/go-libp2p/p2p/net/upgrader` | unsupported | `shim-ausente:context`×2, `shim-ausente:net`×2, `shim-ausente:log/slog` |
| 712 | `github.com/libp2p/go-libp2p/p2p/protocol/circuitv2/client` | unsupported | `shim-ausente:context`×5, `shim-ausente:net`×2, `shim-ausente:log/slog` |
| 713 | `github.com/libp2p/go-libp2p/p2p/security/noise` | unsupported | `shim-ausente:context`×5, `shim-ausente:net`, `shim-ausente:slices` |
| 714 | `github.com/libp2p/go-libp2p/p2p/security/tls` | unsupported | `shim-ausente:crypto/x509`×5, `shim-ausente:crypto/tls`×3, `shim-ausente:context`, `shim-ausente:crypto` |
| 715 | `github.com/libp2p/go-libp2p/p2p/transport/tcpreuse/internal/sampledconn` | unsupported | `shim-ausente:net`×3 |
| 716 | `github.com/libp2p/go-libp2p/p2p/transport/tcpreuse` | unsupported | `shim-ausente:net`×3, `shim-ausente:log/slog`×2, `shim-ausente:context` |
| 717 | `github.com/libp2p/go-libp2p/x/rate` | unsupported | `shim-ausente:net/netip`×4, `shim-ausente:context`×2 |
| 718 | `github.com/pion/dtls/v3/pkg/crypto/fingerprint` | unsupported | `shim-ausente:crypto`×3, `shim-ausente:crypto/x509` |
| 719 | `github.com/pion/dtls/v3/pkg/crypto/signaturehash` | unsupported | `shim-ausente:crypto`×3, `shim-ausente:crypto/tls`×2, `shim-ausente:crypto/x509` |
| 720 | `github.com/pion/dtls/v3/pkg/protocol/extension` | unsupported | `shim-ausente:crypto/tls`, `shim-ausente:slices` |
| 721 | `github.com/pion/dtls/v3/pkg/protocol/handshake` | unsupported | `shim-ausente:crypto/tls`×3, `shim-ausente:crypto/rand` |
| 722 | `github.com/pion/dtls/v3/pkg/protocol/recordlayer` | bloqueado |  |
| 723 | `github.com/pion/dtls/v3/pkg/crypto/ciphersuite` | unsupported | `shim-ausente:crypto/cipher`×5, `shim-ausente:crypto/aes`×3, `shim-ausente:hash` |
| 724 | `github.com/pion/dtls/v3/internal/ciphersuite` | unsupported | `shim-ausente:hash`×15 |
| 725 | `github.com/pion/dtls/v3` | unsupported | `shim-ausente:net`×18, `shim-ausente:context`×17, `shim-ausente:crypto/tls`×14, `shim-ausente:crypto/x509`×11, `shim-ausente:crypto`×3 (+6) |
| 726 | `github.com/pion/sdp/v3` | unsupported | `shim-ausente:net/url`×4, `shim-ausente:slices`×2 |
| 727 | `github.com/pion/stun/v3` | unsupported | `shim-ausente:net`×10, `conversao:pointer-pointer`×4, `shim-ausente:crypto/rand`×2, `shim-ausente:net/url`×2, `async:contexto-sincrono` (+7) |
| 728 | `github.com/pion/ice/v4/internal/stun` | unsupported | `shim-ausente:net` |
| 729 | `github.com/pion/turn/v4/internal/proto` | unsupported | `shim-ausente:net`×3 |
| 730 | `github.com/pion/turn/v4/internal/allocation` | unsupported | `shim-ausente:net`×10 |
| 731 | `github.com/pion/turn/v4/internal/client` | unsupported | `shim-ausente:net`×16, `shim-simbolo:time.newTimer`×3 |
| 732 | `github.com/pion/turn/v4/internal/server` | unsupported | `shim-ausente:net`×7, `shim-ausente:crypto/rand`, `shim-ausente:crypto/sha256` |
| 733 | `github.com/pion/turn/v4` | unsupported | `shim-ausente:net`×18, `shim-ausente:crypto/md5`, `shim-ausente:crypto/sha1` |
| 734 | `github.com/quic-go/quic-go/internal/protocol` | unsupported | `shim-ausente:crypto/rand`×3, `shim-ausente:crypto/tls`×2, `shim-ausente:encoding/hex`×2, `shim-ausente:slices`×2, `shim-ausente:math/rand/v2` |
| 735 | `github.com/quic-go/quic-go/internal/qerr` | unsupported | `shim-ausente:net`×6, `shim-ausente:crypto/tls` |
| 736 | `github.com/quic-go/quic-go/internal/utils` | unsupported | `shim-ausente:bufio`×2, `shim-ausente:crypto/rand`, `shim-ausente:log` |
| 737 | `github.com/quic-go/quic-go/internal/wire` | unsupported | `shim-ausente:crypto/rand`, `shim-ausente:net/netip`, `shim-ausente:slices` |
| 738 | `github.com/quic-go/quic-go/qlogwriter` | unsupported | `async:contexto-sincrono`, `shim-ausente:runtime/debug`, `shim-ausente:slices` |
| 739 | `github.com/quic-go/quic-go/qlog` | unsupported | `shim-ausente:encoding/hex`×4, `shim-ausente:context`×2, `shim-ausente:net/netip`×2, `shim-ausente:hash/crc32`, `shim-simbolo:os.stat` |
| 740 | `github.com/quic-go/quic-go/internal/congestion` | bloqueado |  |
| 741 | `github.com/quic-go/quic-go/internal/ackhandler` | unsupported | `shim-ausente:iter`×3 |
| 742 | `github.com/quic-go/quic-go/internal/handshake` | unsupported | `shim-ausente:crypto/cipher`×16, `shim-ausente:crypto`×6, `shim-ausente:crypto/tls`×6, `shim-ausente:net`×5, `shim-ausente:context`×2 (+2) |
| 743 | `github.com/quic-go/quic-go` | unsupported | `shim-ausente:net`×33, `shim-ausente:context`×30, `shim-ausente:syscall`×8, `shim-ausente:slices`×6, `conversao:pointer-pointer`×4 (+9) |
| 744 | `github.com/quic-go/quic-go/http3/qlog` | unsupported | `shim-ausente:context` |
| 745 | `go.opentelemetry.io/otel/baggage` | unsupported | `shim-ausente:context`×3, `shim-ausente:net/url`×3, `shim-simbolo:strings.splitSeq`×2 |
| 746 | `go.uber.org/dig/internal/digreflect` | unsupported | `shim-ausente:net/url`, `shim-ausente:reflect`, `shim-ausente:runtime` |
| 747 | `go.uber.org/dig` | unsupported | `shim-ausente:reflect`×55, `shim-ausente:math/rand`×3 |
| 748 | `go.uber.org/fx/internal/fxreflect` | unsupported | `shim-ausente:net/url`, `shim-ausente:reflect`, `shim-ausente:runtime` |
| 749 | `golang.org/x/crypto/ocsp` | unsupported | `shim-ausente:crypto/x509` |
| 750 | `golang.org/x/net/proxy` | unsupported | `shim-ausente:context`×4, `shim-ausente:net/url`×4, `shim-ausente:net`×3 |
| 751 | `github.com/pion/ice/v4` | unsupported | `shim-ausente:net`×61, `shim-ausente:net/netip`×10, `shim-ausente:context`×3, `async:valor-func`, `shim-ausente:reflect` |
| 752 | `github.com/libp2p/go-libp2p/p2p/transport/webrtc/udpmux` | unsupported | `shim-ausente:net`×4, `shim-ausente:context`×2, `shim-ausente:log/slog` |
| 753 | `github.com/pion/webrtc/v4/internal/mux` | unsupported | `shim-ausente:net`×3 |
| 754 | `github.com/pion/webrtc/v4` | unsupported | `shim-ausente:encoding/json`×27, `async:contexto-sincrono`×5, `shim-ausente:crypto`×4, `shim-ausente:crypto/x509`×3, `shim-ausente:container/list`×2 (+5) |
| 755 | `google.golang.org/grpc/internal/credentials` | unsupported | `shim-ausente:context`×2, `shim-ausente:crypto/tls`×2, `shim-ausente:net`×2, `shim-ausente:crypto/x509` |
| 756 | `google.golang.org/grpc/credentials` | unsupported | `shim-ausente:context`×6, `shim-ausente:crypto/tls`×6, `shim-ausente:crypto/x509`, `shim-simbolo:os.readFile` |
| 757 | `google.golang.org/grpc/credentials/insecure` | unsupported | `shim-ausente:context` |
| 758 | `google.golang.org/grpc/internal/channelz` | unsupported | `shim-ausente:net`, `shim-ausente:syscall` |
| 759 | `google.golang.org/grpc/channelz` | bloqueado |  |
| 760 | `google.golang.org/grpc/peer` | unsupported | `shim-ausente:context`×2, `shim-ausente:net` |
| 761 | `google.golang.org/grpc/resolver` | unsupported | `shim-ausente:iter`×2, `shim-ausente:encoding/base64`, `shim-ausente:net`, `shim-ausente:net/url` |
| 762 | `google.golang.org/grpc/balancer` | unsupported | `shim-ausente:context`, `shim-ausente:encoding/json`, `shim-ausente:net` |
| 763 | `google.golang.org/grpc/balancer/base` | bloqueado |  |
| 764 | `google.golang.org/grpc/balancer/endpointsharding` | unsupported | `shim-ausente:math/rand/v2` |
| 765 | `google.golang.org/grpc/balancer/grpclb/state` | bloqueado |  |
| 766 | `google.golang.org/grpc/experimental/balancer/weight` | bloqueado |  |
| 767 | `google.golang.org/grpc/balancer/pickfirst` | unsupported | `shim-ausente:cmp`, `shim-ausente:encoding/json`, `shim-ausente:net` |
| 768 | `google.golang.org/grpc/balancer/roundrobin` | bloqueado |  |
| 769 | `google.golang.org/grpc/internal/balancer/gracefulswitch` | unsupported | `shim-ausente:encoding/json` |
| 770 | `google.golang.org/grpc/internal/metadata` | bloqueado |  |
| 771 | `google.golang.org/grpc/internal/proxyattributes` | unsupported | `shim-ausente:net/url` |
| 772 | `google.golang.org/grpc/internal/resolver/dns` | unsupported | `shim-ausente:context`×3, `shim-ausente:net`×3, `shim-ausente:encoding/json`×2, `shim-ausente:net/netip`×2, `shim-ausente:math/rand/v2` (+1) |
| 773 | `google.golang.org/grpc/internal/resolver/passthrough` | bloqueado |  |
| 774 | `google.golang.org/grpc/internal/serviceconfig` | unsupported | `shim-ausente:encoding/json`×3 |
| 775 | `google.golang.org/grpc/internal/resolver` | unsupported | `shim-ausente:context`×3 |
| 776 | `google.golang.org/grpc/internal/transport/networktype` | bloqueado |  |
| 777 | `google.golang.org/grpc/internal/resolver/unix` | bloqueado |  |
| 778 | `google.golang.org/grpc/resolver/dns` | bloqueado |  |
| 779 | `golang.org/x/net/internal/httpcommon` | unsupported | `shim-ausente:net/textproto`×3, `shim-ausente:net/url`×2, `shim-ausente:context` |
| 780 | `github.com/cheggaaa/pb/v3` | unsupported | `shim-ausente:text/template`×6, `async:contexto-sincrono`×2, `shim-ausente:math/rand`×2, `shim-simbolo:time.after` |
| 781 | `github.com/whyrusleeping/cbor-gen` | unsupported | `shim-ausente:reflect`×10, `shim-ausente:bufio`×4, `conversao:pointer-pointer`, `shim-ausente:math/big`, `shim-ausente:text/template` (+2) |
| 782 | `github.com/ipfs/go-ipld-cbor` | unsupported | `shim-ausente:context`×4, `async:contexto-sincrono`, `shim-ausente:bufio`, `shim-ausente:encoding/json`, `shim-ausente:math/big` |
| 783 | `github.com/ipld/go-car/v2/internal/carv1` | unsupported | `shim-ausente:context`×6 |
| 784 | `github.com/ipld/go-car/v2` | unsupported | `shim-ausente:context`×5, `shim-simbolo:os.open`×3, `shim-simbolo:io.limitReader`×2, `shim-simbolo:os.openFile`×2, `shim-simbolo:io.WriterTo` (+2) |
| 785 | `github.com/ipld/go-car/v2/internal/store` | bloqueado |  |
| 786 | `github.com/ipld/go-car/v2/storage` | unsupported | `shim-ausente:context`×3 |
| 787 | `github.com/ipfs/boxo/gateway/assets` | unsupported | `shim-ausente:html/template` |
| 788 | `github.com/caddyserver/zerossl` | unsupported | `shim-ausente:net/http`×2, `shim-ausente:context`, `shim-ausente:crypto/x509`, `shim-ausente:encoding/base64` |
| 789 | `github.com/felixge/httpsnoop` | unsupported | `shim-ausente:net/http`×521, `shim-ausente:net` |
| 790 | `github.com/getsentry/sentry-go/internal/ratelimit` | unsupported | `shim-ausente:net/http`×2, `branch:goto` |
| 791 | `github.com/gorilla/mux` | unsupported | `shim-ausente:net/http`×25, `shim-ausente:net/url`, `shim-ausente:path` |
| 792 | `github.com/gorilla/websocket` | unsupported | `shim-ausente:net/http`×9, `shim-ausente:net`×6, `shim-ausente:compress/flate`×3, `shim-ausente:context`×3, `async:contexto-sincrono`×2 (+8) |
| 793 | `github.com/huin/goupnp/httpu` | unsupported | `shim-ausente:net/http`×7, `shim-ausente:net`×4 |
| 794 | `github.com/huin/goupnp/soap` | unsupported | `shim-ausente:net/url`×3, `shim-ausente:encoding/base64`×2, `shim-ausente:encoding/hex`×2, `shim-ausente:encoding/xml`×2, `shim-ausente:context` (+1) |
| 795 | `github.com/huin/goupnp/ssdp` | unsupported | `shim-ausente:net/http`×7, `shim-ausente:context`×3, `shim-ausente:net/url` |
| 796 | `github.com/huin/goupnp` | unsupported | `shim-ausente:net/url`×9, `shim-ausente:context`×8, `shim-ausente:net`×2, `shim-ausente:net/http`×2 |
| 797 | `github.com/huin/goupnp/dcps/internetgateway1` | unsupported | `shim-ausente:context`×36, `shim-ausente:net/url`×18 |
| 798 | `github.com/huin/goupnp/dcps/internetgateway2` | unsupported | `shim-ausente:context`×48, `shim-ausente:net/url`×24 |
| 799 | `github.com/ipfs/boxo/files` | unsupported | `shim-simbolo:io/fs.FileInfo`×18, `shim-ausente:mime/multipart`×6, `shim-ausente:archive/tar`×2, `shim-ausente:cmp`, `shim-ausente:net/textproto` (+7) |
| 800 | `github.com/ipfs/boxo/tar` | unsupported | `shim-ausente:archive/tar` |
| 801 | `github.com/ipfs/kubo/client/rpc/auth` | unsupported | `shim-ausente:net/http`×2 |
| 802 | `github.com/koron/go-ssdp` | unsupported | `shim-ausente:net`×14, `shim-ausente:net/http`×4, `shim-ausente:bufio`, `shim-ausente:log` |
| 803 | `github.com/libp2p/go-libp2p-http` | unsupported | `shim-ausente:net`, `shim-ausente:net/http` |
| 804 | `github.com/libp2p/go-libp2p/p2p/http/auth/internal/handshake` | unsupported | `shim-ausente:bufio`×2, `shim-ausente:net/http`×2, `shim-ausente:crypto/rand`, `shim-ausente:encoding/base64`, `shim-ausente:hash` (+1) |
| 805 | `github.com/libp2p/go-libp2p/p2p/http/auth` | unsupported | `shim-ausente:net/http`×6, `shim-ausente:crypto/sha256`, `shim-ausente:hash`, `shim-ausente:log/slog` |
| 806 | `github.com/libp2p/go-libp2p/p2p/http` | unsupported | `shim-ausente:net/http`×9, `shim-ausente:net`×2, `shim-ausente:net/url`×2, `shim-ausente:context`, `shim-ausente:log/slog` |
| 807 | `github.com/libp2p/go-libp2p/p2p/net/nat/internal/nat` | unsupported | `shim-ausente:context`×13, `shim-ausente:math/rand`×3, `shim-ausente:log/slog`, `shim-ausente:net` |
| 808 | `github.com/libp2p/go-libp2p/p2p/net/nat` | unsupported | `shim-ausente:context`×3, `shim-ausente:log/slog`, `shim-ausente:net/netip` |
| 809 | `github.com/libp2p/go-libp2p/p2p/transport/websocket` | unsupported | `shim-ausente:net`×8, `shim-ausente:crypto/tls`×4, `shim-ausente:net/url`×3, `shim-ausente:context`×2, `shim-ausente:log/slog`×2 (+1) |
| 810 | `github.com/mholt/acmez/v3/acme` | unsupported | `shim-ausente:crypto`×7, `shim-ausente:net/http`×4, `shim-ausente:context`×3, `shim-ausente:log/slog`×2, `shim-ausente:crypto/sha256` (+3) |
| 811 | `github.com/mholt/acmez/v3` | unsupported | `shim-ausente:context`×6, `shim-ausente:crypto/x509`×5, `shim-ausente:encoding/asn1`×4, `shim-ausente:math/rand`×2, `shim-ausente:crypto` (+1) |
| 812 | `github.com/opentracing/opentracing-go` | unsupported | `shim-ausente:context`×5, `shim-ausente:net/http` |
| 813 | `github.com/prometheus/client_golang/internal/github.com/golang/gddo/httputil/header` | unsupported | `shim-ausente:net/http` |
| 814 | `github.com/prometheus/client_golang/internal/github.com/golang/gddo/httputil` | unsupported | `shim-ausente:net/http` |
| 815 | `github.com/prometheus/common/expfmt` | unsupported | `shim-ausente:bufio`×5, `shim-ausente:net/http`×3, `shim-simbolo:strings.splitSeq` |
| 816 | `github.com/prometheus/client_golang/prometheus` | unsupported | `shim-ausente:runtime` |
| 817 | `github.com/libp2p/go-libp2p/p2p/metricshelper` | bloqueado |  |
| 818 | `github.com/libp2p/go-libp2p/p2p/host/eventbus` | unsupported | `shim-ausente:reflect`×10, `shim-ausente:log/slog`×4, `async:contexto-sincrono`, `shim-ausente:runtime` |
| 819 | `github.com/libp2p/go-libp2p/p2p/host/autonat` | unsupported | `shim-ausente:context`×5, `shim-ausente:log/slog`, `shim-ausente:net` |
| 820 | `github.com/libp2p/go-libp2p/p2p/host/blank` | unsupported | `async:valor-func`, `shim-ausente:context`, `shim-ausente:log/slog` |
| 821 | `github.com/libp2p/go-libp2p/p2p/host/pstoremanager` | unsupported | `shim-ausente:context`, `shim-ausente:log/slog` |
| 822 | `github.com/libp2p/go-libp2p/p2p/host/resource-manager` | unsupported | `shim-ausente:net/netip`×7, `shim-ausente:encoding/json`×5, `shim-ausente:net`×5, `shim-ausente:log/slog`×4, `conversao:pointer-pointer` (+3) |
| 823 | `github.com/libp2p/go-libp2p/p2p/net/swarm` | unsupported | `shim-ausente:context`×17, `shim-ausente:log/slog`×3, `shim-ausente:net/netip`×2, `async:contexto-sincrono`, `async:valor-func` (+3) |
| 824 | `github.com/libp2p/go-libp2p/p2p/protocol/autonatv2` | unsupported | `shim-ausente:context`×4, `shim-ausente:log/slog`×2, `shim-ausente:iter`, `shim-ausente:math/rand`, `shim-ausente:net` |
| 825 | `github.com/libp2p/go-libp2p/p2p/protocol/circuitv2/relay` | unsupported | `shim-ausente:context`×2, `shim-ausente:log/slog`×2, `shim-ausente:slices` |
| 826 | `github.com/libp2p/go-libp2p/p2p/host/relaysvc` | unsupported | `shim-ausente:context`×2 |
| 827 | `github.com/libp2p/go-libp2p/p2p/protocol/identify` | unsupported | `shim-ausente:context`×4, `shim-ausente:slices`×3, `shim-ausente:log/slog`, `shim-ausente:net/netip` |
| 828 | `github.com/libp2p/go-libp2p/p2p/host/autorelay` | unsupported | `shim-ausente:context`×5, `shim-ausente:log/slog`, `shim-simbolo:time.Timer`, `shim-simbolo:time.newTimer` |
| 829 | `github.com/libp2p/go-libp2p/p2p/protocol/holepunch` | unsupported | `shim-ausente:context`×7, `shim-ausente:log/slog`, `shim-ausente:slices` |
| 830 | `github.com/libp2p/go-libp2p/p2p/host/basic` | unsupported | `shim-ausente:context`×15, `shim-ausente:slices`×5, `shim-ausente:log/slog`×2, `shim-ausente:maps` |
| 831 | `github.com/libp2p/go-libp2p/p2p/host/observedaddrs` | unsupported | `shim-ausente:context`×2, `shim-ausente:log/slog`×2, `shim-ausente:net` |
| 832 | `github.com/libp2p/go-libp2p/p2p/transport/quicreuse` | unsupported | `shim-ausente:context`×12, `shim-ausente:net`×11, `shim-ausente:crypto/tls`×3, `shim-ausente:log/slog` |
| 833 | `github.com/libp2p/go-libp2p/p2p/transport/quic` | unsupported | `shim-ausente:context`×3, `shim-ausente:log/slog`×3, `shim-ausente:net`×2 |
| 834 | `github.com/libp2p/go-libp2p/p2p/transport/tcp` | unsupported | `shim-ausente:net`×6, `shim-ausente:context`×2, `shim-ausente:log/slog`, `shim-simbolo:time.newTicker` |
| 835 | `github.com/libp2p/go-libp2p/p2p/transport/webrtc` | unsupported | `shim-ausente:net`×6, `shim-ausente:context`×5, `shim-ausente:log/slog`×3, `shim-ausente:crypto`×2, `shim-ausente:encoding/hex`×2 (+6) |
| 836 | `github.com/prometheus/client_golang/prometheus/promauto` | bloqueado |  |
| 837 | `github.com/prometheus/client_golang/prometheus/promhttp` | unsupported | `shim-ausente:net/http` |
| 838 | `github.com/prometheus/statsd_exporter/pkg/mapper` | unsupported | `shim-simbolo:os.readFile` |
| 839 | `contrib.go.opencensus.io/exporter/prometheus` | unsupported | `shim-ausente:context`×2, `shim-ausente:log`, `shim-ausente:net/http` |
| 840 | `github.com/quic-go/quic-go/http3` | unsupported | `shim-ausente:net/http`×16, `shim-ausente:net/http/httptrace`×15, `shim-ausente:context`×12, `shim-ausente:net`×8, `shim-ausente:log/slog`×4 (+9) |
| 841 | `github.com/quic-go/webtransport-go` | unsupported | `shim-ausente:context`×11, `async:valor-func`×2, `constraint:ponteiro`×2, `shim-ausente:net`×2, `async:contexto-sincrono` (+4) |
| 842 | `github.com/libp2p/go-libp2p/p2p/transport/webtransport` | unsupported | `shim-ausente:context`×8, `shim-ausente:crypto/tls`×4, `shim-ausente:crypto/sha256`×3, `shim-ausente:net`×3, `shim-ausente:log/slog`×2 (+2) |
| 843 | `github.com/rs/cors` | unsupported | `shim-ausente:net/http`×2, `shim-ausente:log` |
| 844 | `github.com/slok/go-http-metrics/metrics/prometheus` | unsupported | `shim-ausente:context` |
| 845 | `github.com/slok/go-http-metrics/middleware/std` | unsupported | `shim-ausente:net/http`×3, `shim-ausente:context` |
| 846 | `go.opencensus.io/trace/propagation` | unsupported | `shim-ausente:net/http` |
| 847 | `go.opencensus.io/plugin/ocgrpc` | unsupported | `shim-ausente:context`×9 |
| 848 | `go.opencensus.io/zpages/internal` | unsupported | `shim-ausente:net/http`×7, `shim-ausente:io/ioutil` |
| 849 | `go.opencensus.io/zpages` | unsupported | `shim-ausente:html/template`×7, `shim-ausente:net/http`×6, `shim-ausente:text/tabwriter`×3, `shim-ausente:log` |
| 850 | `go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp/internal/request` | unsupported | `shim-ausente:net/http`×2 |
| 851 | `go.opentelemetry.io/otel/propagation` | unsupported | `shim-ausente:context`×6, `shim-ausente:encoding/hex` |
| 852 | `go.opentelemetry.io/contrib/propagators/b3` | unsupported | `shim-ausente:context`×7 |
| 853 | `go.opentelemetry.io/contrib/propagators/jaeger` | unsupported | `shim-ausente:context`×4 |
| 854 | `go.opentelemetry.io/contrib/propagators/ot` | unsupported | `shim-ausente:context` |
| 855 | `go.opentelemetry.io/otel/internal/global` | unsupported | `shim-ausente:context`×11, `shim-ausente:container/list`, `shim-ausente:log`, `shim-ausente:reflect` |
| 856 | `go.opentelemetry.io/otel` | bloqueado |  |
| 857 | `github.com/ipfs/boxo/bitswap/client/internal` | unsupported | `shim-ausente:context`×2 |
| 858 | `github.com/ipfs/boxo/bitswap/internal` | unsupported | `shim-ausente:context`×2 |
| 859 | `github.com/ipfs/boxo/blockservice/internal` | unsupported | `shim-ausente:context`×2 |
| 860 | `github.com/libp2p/go-libp2p-kad-dht/internal` | unsupported | `shim-ausente:context`, `shim-simbolo:time.parse`, `tipo-nomeado:chan` |
| 861 | `github.com/libp2p/go-libp2p-routing-helpers/tracing` | unsupported | `shim-ausente:context` |
| 862 | `go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp/internal/semconv` | unsupported | `shim-ausente:net/http`×3, `shim-ausente:net` |
| 863 | `go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp` | unsupported | `shim-ausente:net/http`×12, `shim-ausente:context`×4, `async:contexto-sincrono`, `shim-ausente:net/http/httptrace` |
| 864 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc/internal/envconfig` | unsupported | `shim-ausente:crypto/x509`×2, `shim-ausente:net/url`×2, `shim-ausente:crypto/tls` |
| 865 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc/internal/observ` | unsupported | `shim-ausente:context`×2, `shim-ausente:net`, `shim-ausente:net/netip` |
| 866 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp/internal/envconfig` | unsupported | `shim-ausente:crypto/x509`×2, `shim-ausente:net/url`×2, `shim-ausente:crypto/tls` |
| 867 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp/internal/observ` | unsupported | `shim-ausente:context`×2, `shim-ausente:net`, `shim-ausente:net/netip` |
| 868 | `go.opentelemetry.io/otel/exporters/prometheus/internal/observ` | unsupported | `shim-ausente:context`×3 |
| 869 | `go.opentelemetry.io/otel/exporters/stdout/stdouttrace/internal/observ` | unsupported | `shim-ausente:context`×2 |
| 870 | `go.opentelemetry.io/otel/sdk/metric/internal/observ` | unsupported | `shim-ausente:context`×2 |
| 871 | `go.opentelemetry.io/otel/sdk/resource` | unsupported | `shim-ausente:context`×15, `shim-ausente:bufio`×2, `shim-ausente:os/user`×2, `shim-simbolo:os.open`×2, `shim-ausente:net/url` (+6) |
| 872 | `go.opentelemetry.io/otel/sdk/metric/metricdata` | unsupported | `shim-ausente:encoding/json` |
| 873 | `go.opentelemetry.io/otel/sdk/metric/internal/aggregate` | unsupported | `shim-ausente:context`×17, `shim-ausente:slices`×2, `shim-ausente:runtime` |
| 874 | `go.opentelemetry.io/otel/sdk/metric` | unsupported | `shim-ausente:context`×21, `shim-ausente:reflect`, `shim-ausente:runtime`, `shim-ausente:slices`, `shim-simbolo:time.Ticker` (+1) |
| 875 | `go.opentelemetry.io/otel/exporters/prometheus` | unsupported | `shim-ausente:context`×6, `shim-ausente:slices`×2, `shim-ausente:encoding/hex` |
| 876 | `go.opentelemetry.io/otel/sdk/trace/internal/env` | bloqueado |  |
| 877 | `go.opentelemetry.io/otel/sdk/trace/internal/observ` | unsupported | `shim-ausente:context`×4 |
| 878 | `go.opentelemetry.io/otel/sdk/trace` | unsupported | `shim-ausente:context`×11, `shim-ausente:reflect`, `shim-ausente:runtime`, `shim-ausente:slices`, `shim-simbolo:time.newTimer` |
| 879 | `go.opentelemetry.io/contrib/propagators/aws/xray` | unsupported | `shim-ausente:context`×2, `shim-ausente:crypto/rand`, `shim-ausente:encoding/hex` |
| 880 | `go.opentelemetry.io/contrib/propagators/autoprop` | bloqueado |  |
| 881 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/internal/tracetransform` | bloqueado |  |
| 882 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace` | unsupported | `shim-ausente:context`×3 |
| 883 | `go.opentelemetry.io/otel/sdk/trace/tracetest` | unsupported | `shim-ausente:context`×3 |
| 884 | `go.opentelemetry.io/otel/exporters/stdout/stdouttrace` | unsupported | `shim-ausente:context`, `shim-ausente:encoding/json` |
| 885 | `go.opentelemetry.io/otel/semconv/internal` | unsupported | `shim-ausente:net`, `shim-ausente:net/http` |
| 886 | `go.opentelemetry.io/otel/semconv/v1.4.0` | unsupported | `shim-ausente:net/http`×5 |
| 887 | `go.uber.org/zap` | unsupported | `shim-ausente:log`×3, `shim-ausente:net/http`×3, `shim-ausente:net/url`×3, `shim-ausente:encoding/json`, `shim-ausente:flag` |
| 888 | `github.com/ipfs/go-log/v2` | unsupported | `shim-ausente:log/slog`×9, `shim-ausente:context`×2, `shim-ausente:path/filepath`, `shim-ausente:reflect`, `shim-simbolo:io.PipeReader` (+2) |
| 889 | `github.com/ipfs-shipyard/nopfs` | unsupported | `shim-ausente:bufio`, `shim-ausente:net/url`, `shim-ausente:path/filepath`, `shim-simbolo:io.LimitedReader`, `shim-simbolo:io.ReadSeekCloser` (+4) |
| 890 | `github.com/ipfs/boxo/autoconf` | unsupported | `shim-ausente:slices`×4, `shim-ausente:net/http`×3, `shim-ausente:context`×2, `shim-ausente:math/rand/v2`, `shim-ausente:net/url` (+1) |
| 891 | `github.com/ipfs/boxo/bitswap/client/internal/getter` | unsupported | `shim-ausente:context`×5 |
| 892 | `github.com/ipfs/boxo/bitswap/client/internal/sessionpeermanager` | bloqueado |  |
| 893 | `github.com/ipfs/boxo/bitswap/network` | unsupported | `shim-ausente:context`×6, `shim-ausente:net`, `shim-ausente:net/url` |
| 894 | `github.com/ipfs/boxo/bitswap/client/internal/messagequeue` | unsupported | `shim-ausente:context`×8 |
| 895 | `github.com/ipfs/boxo/bitswap/network/bsnet` | unsupported | `shim-ausente:context`×9, `conversao:pointer-pointer` |
| 896 | `github.com/ipfs/boxo/bitswap/network/httpnet` | unsupported | `shim-ausente:context`×19, `shim-ausente:net`, `shim-ausente:reflect`, `shim-simbolo:time.parse` |
| 897 | `github.com/ipfs/boxo/bootstrap` | unsupported | `shim-ausente:context`×8, `shim-ausente:math/rand/v2` |
| 898 | `github.com/ipfs/boxo/chunker` | unsupported | `shim-ausente:hash/fnv` |
| 899 | `github.com/ipfs/boxo/ipns` | unsupported | `shim-ausente:cmp`, `shim-ausente:encoding/json`, `shim-ausente:iter`, `shim-simbolo:fmt.append$` |
| 900 | `github.com/ipfs/boxo/keystore` | unsupported | `shim-ausente:encoding/base32`×4, `shim-ausente:path/filepath`, `shim-simbolo:os.mkdir` |
| 901 | `github.com/ipfs/boxo/path/resolver` | unsupported | `shim-ausente:context`×5, `shim-ausente:slices` |
| 902 | `github.com/ipfs/boxo/peering` | unsupported | `conversao:pointer-pointer`×2, `shim-ausente:context` |
| 903 | `github.com/ipfs/boxo/bitswap/client/internal/peermanager` | unsupported | `shim-ausente:context`×3 |
| 904 | `github.com/ipfs/boxo/bitswap/client/internal/session` | unsupported | `shim-ausente:context`×4, `shim-ausente:math/rand/v2`, `shim-ausente:slices` |
| 905 | `github.com/ipfs/boxo/bitswap/client/internal/sessionmanager` | unsupported | `shim-ausente:context`×3 |
| 906 | `github.com/ipfs/boxo/routing/http/filters` | unsupported | `shim-ausente:net/url`, `shim-ausente:reflect`, `shim-ausente:slices` |
| 907 | `github.com/ipfs/boxo/routing/http/server` | unsupported | `shim-ausente:net/http`×9, `shim-ausente:context` |
| 908 | `github.com/ipfs/boxo/routing/providerquerymanager` | unsupported | `shim-ausente:context`×9 |
| 909 | `github.com/ipfs/go-ds-flatfs` | unsupported | `shim-ausente:context`×5, `shim-ausente:path/filepath`×3, `shim-simbolo:os.open`×3, `shim-simbolo:os.mkdir`×2, `shim-simbolo:os.stat`×2 (+7) |
| 910 | `github.com/ipfs/go-dsqueue` | unsupported | `shim-ausente:context`×2, `shim-ausente:encoding/base64`×2 |
| 911 | `github.com/ipfs/boxo/provider` | unsupported | `shim-ausente:context`×14 |
| 912 | `github.com/ipfs/boxo/blockstore` | unsupported | `shim-ausente:context`×19 |
| 913 | `github.com/ipfs/boxo/bitswap/client` | unsupported | `shim-ausente:context`×2 |
| 914 | `github.com/ipfs/boxo/bitswap/server/internal/decision` | unsupported | `shim-ausente:context`×3, `shim-ausente:hash/maphash`×3, `shim-simbolo:time.newTicker` |
| 915 | `github.com/ipfs/boxo/bitswap/server` | unsupported | `shim-ausente:context`×2 |
| 916 | `github.com/ipfs/boxo/bitswap` | unsupported | `shim-ausente:context`×3 |
| 917 | `github.com/ipfs/boxo/blockservice` | unsupported | `shim-ausente:context`×12 |
| 918 | `github.com/ipfs/boxo/exchange/offline` | unsupported | `shim-ausente:context` |
| 919 | `github.com/ipfs/boxo/fetcher/impl/blockservice` | unsupported | `shim-ausente:context`×3 |
| 920 | `github.com/ipfs/boxo/filestore` | unsupported | `shim-ausente:context`×10, `shim-simbolo:os.open` |
| 921 | `github.com/ipfs/boxo/ipld/merkledag` | unsupported | `shim-ausente:context`×19, `async:contexto-sincrono`, `shim-ausente:slices` |
| 922 | `github.com/ipfs/boxo/ipld/merkledag/dagutils` | unsupported | `shim-ausente:context`×6 |
| 923 | `github.com/ipfs/boxo/ipld/merkledag/test` | unsupported | `shim-ausente:context` |
| 924 | `github.com/ipfs/boxo/ipld/unixfs` | bloqueado |  |
| 925 | `github.com/ipfs/boxo/dag/walker` | unsupported | `shim-ausente:context`×9, `shim-ausente:crypto/rand` |
| 926 | `github.com/ipfs/boxo/ipld/unixfs/hamt` | unsupported | `shim-ausente:context`×4, `shim-ausente:hash` |
| 927 | `github.com/ipfs/boxo/ipld/unixfs/importer/helpers` | unsupported | `shim-ausente:context`, `shim-simbolo:io/fs.FileInfo` |
| 928 | `github.com/ipfs/boxo/ipld/unixfs/importer/balanced` | bloqueado |  |
| 929 | `github.com/ipfs/boxo/ipld/unixfs/importer/trickle` | unsupported | `shim-ausente:context`×4 |
| 930 | `github.com/ipfs/boxo/ipld/unixfs/io` | unsupported | `shim-ausente:context`×8, `shim-simbolo:io.WriterTo` |
| 931 | `github.com/ipfs/boxo/ipld/unixfs/file` | unsupported | `shim-ausente:context`×5 |
| 932 | `github.com/ipfs/boxo/ipld/unixfs/mod` | unsupported | `shim-ausente:context`×3 |
| 933 | `github.com/ipfs/boxo/mfs` | unsupported | `shim-ausente:context`×15, `shim-ausente:path`×2 |
| 934 | `github.com/ipfs/boxo/pinning/pinner/dspinner` | unsupported | `shim-ausente:context`×9, `shim-ausente:path`×3 |
| 935 | `github.com/ipfs/go-fs-lock` | unsupported | `shim-ausente:path/filepath`×2, `shim-ausente:context`, `shim-ausente:syscall`, `shim-simbolo:os.lstat` |
| 936 | `github.com/ipfs/go-ipfs-cmds` | unsupported | `shim-ausente:reflect`×17, `shim-ausente:context`×4, `conversao:chan-chan`×2, `shim-ausente:bufio`×2, `shim-ausente:encoding/json`×2 (+4) |
| 937 | `github.com/ipfs/go-ipfs-cmds/cli` | unsupported | `shim-ausente:reflect`×5, `shim-ausente:text/template`×5, `shim-ausente:net/url`×3, `shim-ausente:context`×2, `async:contexto-sincrono` (+2) |
| 938 | `github.com/ipfs/go-ipfs-cmds/http` | unsupported | `shim-ausente:net/http`×21, `shim-ausente:net/url` |
| 939 | `github.com/ipfs/go-metrics-prometheus` | bloqueado |  |
| 940 | `github.com/ipfs/kubo/blocks/blockstoreutil` | unsupported | `shim-ausente:context`×2 |
| 941 | `github.com/ipfs/kubo/cmd/ipfs/util` | unsupported | `shim-ausente:context`, `shim-ausente:syscall`, `shim-simbolo:os.Signal` |
| 942 | `github.com/ipfs/kubo/core/commands/keyencode` | bloqueado |  |
| 943 | `github.com/ipfs/kubo/core/shutdown` | unsupported | `shim-ausente:context` |
| 944 | `github.com/ipfs/kubo/fuse/mount` | unsupported | `shim-ausente:os/exec`×2, `async:contexto-sincrono`, `shim-ausente:crypto/sha256`, `shim-ausente:syscall`, `shim-simbolo:time.after` |
| 945 | `github.com/ipfs/kubo/fuse/writable` | unsupported | `shim-ausente:context`×6 |
| 946 | `github.com/ipfs/kubo/gc` | unsupported | `shim-ausente:context`×3 |
| 947 | `github.com/ipfs/kubo/p2p` | unsupported | `shim-ausente:context`×3, `async:valor-func`, `shim-simbolo:io.copy` |
| 948 | `github.com/ipfs/kubo/thirdparty/verifbs` | unsupported | `shim-ausente:context`×2 |
| 949 | `github.com/libp2p/go-doh-resolver` | unsupported | `shim-ausente:context`×5, `shim-ausente:net`×2 |
| 950 | `github.com/libp2p/go-libp2p-kad-dht/pb` | unsupported | `shim-ausente:context`×3, `unsafe:Pointer`×2, `shim-ausente:reflect` |
| 951 | `github.com/libp2p/go-libp2p-kad-dht/internal/metrics` | unsupported | `shim-ausente:context`×11 |
| 952 | `github.com/libp2p/go-libp2p-kad-dht/internal/net` | unsupported | `shim-ausente:bufio`×2, `shim-ausente:context`×2 |
| 953 | `github.com/libp2p/go-libp2p-kad-dht/records` | unsupported | `shim-ausente:context`×4, `shim-ausente:maps`, `shim-ausente:math/rand/v2` |
| 954 | `github.com/ipfs/boxo/routing/offline` | unsupported | `shim-ausente:context` |
| 955 | `github.com/libp2p/go-libp2p-kbucket/peerdiversity` | unsupported | `shim-ausente:net`×2, `shim-ausente:maps` |
| 956 | `github.com/libp2p/go-libp2p-kad-dht/internal/config` | unsupported | `shim-ausente:context` |
| 957 | `github.com/libp2p/go-libp2p-kbucket` | unsupported | `shim-ausente:container/list`×3, `shim-ausente:context`×2, `shim-ausente:crypto/rand` |
| 958 | `github.com/libp2p/go-libp2p-kad-dht/crawler` | unsupported | `shim-ausente:context`×3, `shim-ausente:slices` |
| 959 | `github.com/libp2p/go-libp2p-kad-dht/netsize` | unsupported | `shim-ausente:math/big`×4 |
| 960 | `github.com/libp2p/go-libp2p-kad-dht/provider/internal/keyspace` | unsupported | `shim-ausente:iter`×4, `shim-ausente:crypto/sha256`×2, `shim-ausente:cmp`, `shim-ausente:slices` |
| 961 | `github.com/libp2p/go-libp2p-kad-dht/provider/internal/queue` | unsupported | `shim-ausente:context`, `shim-ausente:slices` |
| 962 | `github.com/libp2p/go-libp2p-kad-dht/provider/internal/timeseries` | bloqueado |  |
| 963 | `github.com/libp2p/go-libp2p-kad-dht/provider/keystore` | unsupported | `shim-ausente:context`×7, `shim-ausente:encoding/base64` |
| 964 | `github.com/libp2p/go-libp2p-kad-dht/provider` | unsupported | `shim-ausente:context`×6, `async:valor-func`, `shim-simbolo:fmt.sscanf` |
| 965 | `github.com/libp2p/go-libp2p-kad-dht/provider/buffered` | bloqueado |  |
| 966 | `github.com/libp2p/go-libp2p-kad-dht/rtrefresh` | unsupported | `shim-ausente:context`×2 |
| 967 | `github.com/libp2p/go-libp2p-kad-dht` | unsupported | `shim-ausente:context`×10, `shim-ausente:net`×8, `shim-ausente:testing`×2, `async:valor-func`, `shim-ausente:encoding/json` (+2) |
| 968 | `github.com/ipfs/boxo/namesys` | unsupported | `shim-ausente:context`×22, `shim-simbolo:strings.splitSeq` |
| 969 | `github.com/ipfs-shipyard/nopfs/ipfs` | unsupported | `shim-ausente:context`×3 |
| 970 | `github.com/ipfs/boxo/namesys/republisher` | unsupported | `shim-ausente:context`×2 |
| 971 | `github.com/ipfs/kubo/core/coreiface/options` | bloqueado |  |
| 972 | `github.com/ipfs/kubo/core/coreiface` | unsupported | `shim-ausente:context`×14, `shim-simbolo:io.WriterTo` |
| 973 | `github.com/ipfs/kubo/core/commands/cmdutils` | unsupported | `shim-ausente:slices` |
| 974 | `github.com/ipfs/kubo` | unsupported | `shim-ausente:runtime`, `shim-ausente:runtime/debug` |
| 975 | `github.com/ipfs/kubo/profile` | unsupported | `shim-ausente:context`×14, `shim-ausente:runtime` |
| 976 | `github.com/libp2p/go-libp2p-pubsub-router` | unsupported | `shim-ausente:context`×8, `shim-ausente:encoding/base64` |
| 977 | `github.com/libp2p/go-libp2p-routing-helpers` | unsupported | `shim-ausente:context`×18 |
| 978 | `github.com/ipfs/boxo/gateway` | unsupported | `shim-ausente:net/http`×51, `shim-ausente:context`×34, `shim-ausente:net/textproto`×4, `shim-ausente:net`×2, `shim-ausente:net/url`×2 (+3) |
| 979 | `github.com/ipfs/boxo/routing/http/contentrouter` | unsupported | `shim-ausente:context`×4 |
| 980 | `github.com/ipfs/boxo/routing/http/client` | unsupported | `shim-ausente:net/http`×5, `shim-ausente:context`×4, `shim-ausente:slices`×2, `shim-ausente:net/url`, `shim-ausente:reflect` (+2) |
| 981 | `github.com/libp2p/go-libp2p-kad-dht/dual` | unsupported | `shim-ausente:context` |
| 982 | `github.com/libp2p/go-libp2p-kad-dht/provider/dual` | unsupported | `async:valor-func`, `shim-ausente:context` |
| 983 | `github.com/libp2p/go-libp2p-xor/key` | unsupported | `shim-ausente:math/big`×2 |
| 984 | `github.com/libp2p/go-libp2p-xor/trie` | unsupported | `shim-ausente:encoding/json` |
| 985 | `github.com/libp2p/go-libp2p-xor/kademlia` | unsupported | `shim-ausente:encoding/json`×2 |
| 986 | `github.com/libp2p/go-libp2p-kad-dht/fullrt` | unsupported | `shim-ausente:context`×2 |
| 987 | `github.com/libp2p/go-socket-activation` | unsupported | `async:valor-func`, `shim-ausente:net`, `shim-ausente:syscall` |
| 988 | `go.uber.org/fx/fxevent` | unsupported | `shim-ausente:log/slog`×4, `shim-ausente:context`, `shim-simbolo:os.Signal` |
| 989 | `go.uber.org/fx/internal/fxlog` | unsupported | `shim-ausente:reflect`×2 |
| 990 | `go.uber.org/fx/internal/lifecycle` | unsupported | `shim-ausente:reflect`×5, `shim-ausente:context`×4 |
| 991 | `go.uber.org/fx` | unsupported | `shim-ausente:reflect`×36, `shim-ausente:context`×7, `shim-simbolo:os.Signal`×4, `shim-ausente:syscall`×2, `shim-ausente:os/signal` |
| 992 | `github.com/ipfs/kubo/core/node/helpers` | unsupported | `shim-ausente:context` |
| 993 | `github.com/libp2p/go-libp2p/config` | unsupported | `shim-ausente:context`×2, `shim-ausente:crypto/sha256`×2, `shim-ausente:log/slog`×2 |
| 994 | `github.com/libp2p/go-libp2p` | unsupported | `shim-ausente:crypto/rand`×2, `conversao:pointer-pointer`, `shim-ausente:reflect` |
| 995 | `go.uber.org/zap/exp/zapslog` | unsupported | `shim-ausente:log/slog`×5, `shim-ausente:context` |
| 996 | `github.com/caddyserver/certmagic` | unsupported | `shim-ausente:context`×43, `shim-ausente:net`×10, `shim-ausente:net/http`×10, `shim-ausente:crypto/tls`×9, `shim-ausente:crypto/x509`×6 (+10) |
| 997 | `golang.org/x/net/http2` | unsupported | `shim-ausente:net/http`×42, `shim-ausente:net`×13, `shim-ausente:net/http/httptrace`×6, `async:contexto-sincrono`×4, `shim-ausente:compress/gzip`×4 (+11) |
| 998 | `golang.org/x/net/trace` | unsupported | `shim-ausente:net/http`×8, `shim-ausente:html/template`×7, `shim-ausente:runtime`×3, `shim-ausente:context`×2, `shim-ausente:net/url` (+1) |
| 999 | `github.com/dgraph-io/badger/y` | unsupported | `shim-simbolo:os.openFile`×4, `shim-ausente:log`×3, `shim-ausente:expvar`×2, `shim-ausente:hash/crc32`×2, `shim-ausente:context` |
| 1000 | `github.com/dgraph-io/badger/skl` | unsupported | `unsafe:Pointer` |
| 1001 | `github.com/dgraph-io/badger/table` | unsupported | `shim-ausente:path`, `shim-ausente:path/filepath`, `shim-simbolo:os.remove` |
| 1002 | `github.com/dgraph-io/badger` | unsupported | `shim-ausente:bufio`×4, `async:valor-func`×3, `shim-ausente:context`×3, `shim-ausente:log`×3, `shim-ausente:path/filepath`×3 (+11) |
| 1003 | `github.com/ipfs/go-ds-badger` | unsupported | `shim-ausente:context`×3 |
| 1004 | `golang.org/x/oauth2/internal` | unsupported | `shim-ausente:context`×3, `shim-ausente:net/url`×2, `shim-ausente:crypto/rsa`, `shim-ausente:encoding/json`, `shim-ausente:net/http` |
| 1005 | `golang.org/x/oauth2` | unsupported | `shim-ausente:context`×7, `shim-ausente:net/http`×3, `shim-ausente:net/url`×3, `conversao:pointer-pointer`, `shim-ausente:crypto/rand` (+1) |
| 1006 | `github.com/ipshipyard/p2p-forge/client` | unsupported | `shim-ausente:context`×10, `shim-ausente:net/http`×5, `shim-ausente:crypto/x509`×2, `shim-ausente:net`×2, `shim-ausente:crypto/tls` (+2) |
| 1007 | `github.com/getsentry/sentry-go/internal/debug` | unsupported | `shim-ausente:net/http` |
| 1008 | `github.com/getsentry/sentry-go` | unsupported | `shim-ausente:context`×14, `shim-ausente:log`×9, `shim-ausente:encoding/json`×8, `shim-ausente:net/http`×8, `shim-ausente:runtime`×6 (+16) |
| 1009 | `github.com/cockroachdb/errors/withstack` | unsupported | `shim-ausente:go/build`, `shim-ausente:path/filepath`, `shim-ausente:runtime` |
| 1010 | `github.com/cockroachdb/errors/errutil` | unsupported | `shim-ausente:context`×7, `shim-ausente:reflect`×3 |
| 1011 | `github.com/cockroachdb/errors/report` | bloqueado |  |
| 1012 | `github.com/cockroachdb/errors` | unsupported | `shim-ausente:context`×9 |
| 1013 | `github.com/cockroachdb/errors/oserror` | bloqueado |  |
| 1014 | `github.com/cockroachdb/pebble/v2/internal/dsl` | unsupported | `shim-ausente:go/token`×6 |
| 1015 | `github.com/cockroachdb/pebble/v2/vfs` | unsupported | `shim-ausente:syscall`×5, `shim-simbolo:io/fs.FileInfo`×4, `shim-ausente:maps`×2, `shim-simbolo:io/fs.DirEntry`×2, `shim-simbolo:time.newTicker`×2 (+7) |
| 1016 | `github.com/cockroachdb/pebble/v2/internal/base` | unsupported | `shim-ausente:context`×9, `shim-ausente:slices`×2, `shim-ausente:cmp`, `shim-ausente:log`, `shim-ausente:path/filepath` |
| 1017 | `github.com/cockroachdb/pebble/v2/batchrepr` | unsupported | `unsafe:Pointer` |
| 1018 | `github.com/cockroachdb/pebble/v2/bloom` | bloqueado |  |
| 1019 | `github.com/cockroachdb/pebble/v2/internal/arenaskl` | unsupported | `unsafe:Pointer`×3, `shim-ausente:context`×2 |
| 1020 | `github.com/cockroachdb/pebble/v2/internal/batchskl` | unsupported | `shim-ausente:math/rand/v2` |
| 1021 | `github.com/cockroachdb/pebble/v2/internal/cache` | unsupported | `shim-ausente:runtime`×3, `unsafe:Pointer`×3, `shim-ausente:context`×2, `async:valor-func`, `shim-ausente:runtime/debug` (+1) |
| 1022 | `github.com/cockroachdb/pebble/v2/internal/compression` | unsupported | `shim-ausente:math/rand/v2` |
| 1023 | `github.com/cockroachdb/pebble/v2/internal/invalidating` | unsupported | `shim-ausente:context` |
| 1024 | `github.com/cockroachdb/pebble/v2/internal/keyspan` | unsupported | `shim-ausente:context`×12, `shim-ausente:slices`×4, `shim-ausente:cmp`×2, `shim-ausente:go/token`, `shim-ausente:reflect` |
| 1025 | `github.com/cockroachdb/pebble/v2/internal/private` | bloqueado |  |
| 1026 | `github.com/cockroachdb/pebble/v2/internal/problemspans` | bloqueado |  |
| 1027 | `github.com/cockroachdb/pebble/v2/internal/rangedel` | bloqueado |  |
| 1028 | `github.com/cockroachdb/pebble/v2/internal/rangekey` | unsupported | `shim-ausente:slices` |
| 1029 | `github.com/cockroachdb/pebble/v2/internal/sstableinternal` | bloqueado |  |
| 1030 | `github.com/cockroachdb/pebble/v2/internal/strparse` | bloqueado |  |
| 1031 | `github.com/cockroachdb/pebble/v2/internal/testkeys` | unsupported | `branch:goto`, `shim-ausente:cmp`, `shim-ausente:math/rand/v2` |
| 1032 | `github.com/cockroachdb/pebble/v2/objstorage/remote` | unsupported | `shim-ausente:context`×8 |
| 1033 | `github.com/cockroachdb/pebble/v2/objstorage/objstorageprovider/sharedcache` | unsupported | `shim-ausente:context` |
| 1034 | `github.com/cockroachdb/pebble/v2/objstorage` | unsupported | `shim-ausente:context`×7 |
| 1035 | `github.com/cockroachdb/pebble/v2/objstorage/objstorageprovider/objiotracing` | unsupported | `shim-ausente:context`×4 |
| 1036 | `github.com/cockroachdb/pebble/v2/record` | unsupported | `shim-ausente:runtime/pprof`×2, `shim-ausente:context`, `shim-simbolo:time.Timer` |
| 1037 | `github.com/cockroachdb/pebble/v2/sstable/virtual` | bloqueado |  |
| 1038 | `github.com/cockroachdb/pebble/v2/vfs/atomicfs` | bloqueado |  |
| 1039 | `github.com/cockroachdb/pebble/v2/objstorage/objstorageprovider/remoteobjcat` | unsupported | `shim-ausente:bufio`, `shim-ausente:cmp`, `shim-ausente:path/filepath` |
| 1040 | `github.com/cockroachdb/pebble/v2/objstorage/objstorageprovider` | unsupported | `shim-ausente:context`×6, `shim-ausente:bufio`×2, `shim-ausente:runtime/debug`, `shim-ausente:slices` |
| 1041 | `github.com/cockroachdb/pebble/v2/sstable/block` | unsupported | `shim-ausente:context`×4, `unsafe:Pointer`×4, `shim-ausente:slices`×3, `conversao:slice-named-array-pointer`×2, `shim-ausente:cmp` (+3) |
| 1042 | `github.com/cockroachdb/pebble/v2/sstable/colblk` | unsupported | `unsafe:Pointer`×24, `unsafe:Slice`×4, `shim-ausente:context`×3, `func-sem-corpo`×2, `min:typeparam` (+4) |
| 1043 | `github.com/cockroachdb/pebble/v2/sstable/blob` | unsupported | `shim-ausente:context`×7, `unsafe:Pointer`×2 |
| 1044 | `github.com/cockroachdb/pebble/v2/internal/blobtest` | unsupported | `shim-ausente:context`, `shim-ausente:math/rand/v2` |
| 1045 | `github.com/cockroachdb/pebble/v2/sstable/rowblk` | unsupported | `shim-ausente:context`×2, `shim-ausente:iter`, `unsafe:Pointer`, `unsafe:Slice` |
| 1046 | `github.com/cockroachdb/pebble/v2/sstable/valblk` | unsupported | `shim-ausente:context`×4, `unsafe:Pointer`×2 |
| 1047 | `github.com/cockroachdb/pebble/v2/sstable` | unsupported | `shim-ausente:context`×24, `shim-ausente:reflect`×6, `conversao:pointer-typeparam`×3, `shim-ausente:iter`×3, `shim-ausente:cmp`×2 (+7) |
| 1048 | `github.com/cockroachdb/pebble/v2/internal/manifest` | unsupported | `shim-ausente:container/heap` |
| 1049 | `github.com/cockroachdb/pebble/v2/internal/compact` | unsupported | `shim-ausente:slices`×2 |
| 1050 | `github.com/cockroachdb/pebble/v2/internal/keyspan/keyspanimpl` | unsupported | `shim-ausente:context`×4 |
| 1051 | `github.com/cockroachdb/pebble/v2/internal/overlap` | unsupported | `shim-ausente:context`×2 |
| 1052 | `github.com/cockroachdb/pebble/v2/internal/rangekeystack` | bloqueado |  |
| 1053 | `github.com/cockroachdb/pebble/v2/rangekey` | bloqueado |  |
| 1054 | `github.com/cockroachdb/pebble/v2/wal` | unsupported | `async:valor-func`×2, `conversao:pointer-pointer`×2, `shim-ausente:cmp`×2, `shim-ausente:slices`×2, `shim-ausente:math/rand/v2` (+1) |
| 1055 | `github.com/cockroachdb/pebble/v2` | unsupported | `shim-ausente:context`×43, `shim-ausente:slices`×11, `shim-ausente:iter`×6, `shim-ausente:runtime/pprof`×6, `shim-ausente:cmp`×4 (+7) |
| 1056 | `github.com/ipfs/boxo/pinning/remote/client/openapi` | unsupported | `shim-ausente:encoding/json`×21, `shim-ausente:net/http`×11, `shim-ausente:context`×6, `shim-ausente:reflect`×2, `shim-ausente:mime/multipart` |
| 1057 | `github.com/ipfs/boxo/pinning/remote/client` | unsupported | `shim-ausente:encoding/json`×3, `async:contexto-sincrono`, `shim-ausente:context`, `shim-ausente:net/http`, `shim-ausente:slices` |
| 1058 | `github.com/ipfs/go-ds-pebble` | unsupported | `shim-ausente:context`×2 |
| 1059 | `github.com/ipfs/kubo/config` | unsupported | `shim-ausente:encoding/json`×16, `shim-ausente:path/filepath`×3, `shim-ausente:encoding/base64`×2, `shim-ausente:slices`×2, `shim-ausente:crypto/rand` (+6) |
| 1060 | `github.com/ipfs/kubo/config/serialize` | unsupported | `shim-ausente:path/filepath`, `shim-simbolo:os.open` |
| 1061 | `github.com/ipfs/kubo/repo` | unsupported | `shim-ausente:context`×4 |
| 1062 | `github.com/ipfs/kubo/repo/fsrepo/migrations/fs-repo-16-to-17/migration` | unsupported | `shim-ausente:slices` |
| 1063 | `github.com/ipfs/kubo/repo/fsrepo/migrations` | unsupported | `shim-ausente:context`×15, `shim-ausente:net/http`×2, `shim-ausente:path/filepath`×2, `shim-simbolo:os.open`×2, `shim-ausente:archive/zip` (+5) |
| 1064 | `github.com/ipfs/kubo/repo/fsrepo` | unsupported | `shim-ausente:path/filepath`×3, `shim-ausente:context`×2, `shim-ausente:encoding/json`, `shim-simbolo:os.writeFile` |
| 1065 | `github.com/ipfs/kubo/routing` | unsupported | `shim-ausente:context`×3, `shim-ausente:encoding/base64`, `shim-ausente:net/http` |
| 1066 | `github.com/ipfs/kubo/core/node/libp2p` | unsupported | `shim-ausente:context`×7, `shim-ausente:net`×7, `async:valor-func`×5, `conversao:pointer-pointer`×3, `shim-ausente:path/filepath`×2 (+4) |
| 1067 | `github.com/ipfs/kubo/core/node` | unsupported | `shim-ausente:context`×27, `async:valor-func`×5, `shim-ausente:encoding/base32`×3, `shim-ausente:path/filepath`×2, `shim-ausente:crypto/rand` |
| 1068 | `github.com/ipfs/kubo/core` | unsupported | `shim-ausente:context`×3, `shim-ausente:reflect` |
| 1069 | `github.com/ipfs/kubo/core/corerepo` | unsupported | `shim-ausente:context`×8 |
| 1070 | `github.com/ipfs/kubo/fuse/mfs` | unsupported | `shim-simbolo:os.getuid` |
| 1071 | `github.com/ipfs/kubo/fuse/readonly` | unsupported | `shim-ausente:context`×4, `shim-simbolo:os.getuid` |
| 1072 | `github.com/ipfs/kubo/plugin` | bloqueado |  |
| 1073 | `github.com/ipfs/kubo/plugin/plugins/badgerds` | unsupported | `shim-ausente:path/filepath` |
| 1074 | `github.com/ipfs/kubo/plugin/plugins/dagjose` | bloqueado |  |
| 1075 | `github.com/ipfs/kubo/plugin/plugins/flatfs` | unsupported | `shim-ausente:path/filepath` |
| 1076 | `github.com/ipfs/kubo/plugin/plugins/fxtest` | bloqueado |  |
| 1077 | `github.com/ipfs/kubo/plugin/plugins/git` | unsupported | `shim-ausente:compress/zlib` |
| 1078 | `github.com/ipfs/kubo/plugin/plugins/levelds` | unsupported | `shim-ausente:path/filepath` |
| 1079 | `github.com/ipfs/kubo/plugin/plugins/nopfs` | unsupported | `shim-ausente:path/filepath` |
| 1080 | `github.com/ipfs/kubo/plugin/plugins/pebbleds` | unsupported | `shim-ausente:path/filepath` |
| 1081 | `github.com/ipfs/kubo/plugin/plugins/peerlog` | unsupported | `shim-ausente:context` |
| 1082 | `github.com/ipfs/kubo/plugin/plugins/telemetry` | unsupported | `shim-simbolo:os.stat`×2, `shim-ausente:path` |
| 1083 | `google.golang.org/grpc/internal/transport` | unsupported | `shim-ausente:context`×20, `shim-ausente:net`×5, `shim-ausente:encoding/base64`×3, `shim-ausente:bufio`, `shim-ausente:math/rand/v2` (+2) |
| 1084 | `google.golang.org/grpc/internal/resolver/delegatingresolver` | unsupported | `shim-ausente:net/url`×5, `shim-ausente:net`, `shim-ausente:net/http` |
| 1085 | `google.golang.org/grpc` | unsupported | `shim-ausente:context`×70, `shim-ausente:net`×6, `shim-ausente:compress/gzip`×3, `shim-ausente:encoding/json`×2, `shim-ausente:net/url`×2 (+4) |
| 1086 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc/internal/otlpconfig` | unsupported | `shim-ausente:crypto/tls`×4, `shim-ausente:net/url`×4, `shim-ausente:net/http`, `shim-ausente:path`, `shim-simbolo:os.readFile` |
| 1087 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp/internal/otlpconfig` | unsupported | `shim-ausente:crypto/tls`×4, `shim-ausente:net/url`×4, `shim-ausente:net/http`, `shim-ausente:path`, `shim-simbolo:os.readFile` |
| 1088 | `google.golang.org/grpc/health/grpc_health_v1` | unsupported | `shim-ausente:context`×6, `unsafe:Pointer`×4, `shim-ausente:reflect`, `unsafe:Slice` |
| 1089 | `github.com/grpc-ecosystem/grpc-gateway/v2/runtime` | unsupported | `shim-ausente:context`×30, `shim-ausente:net/http`×9, `shim-ausente:reflect`×8, `shim-ausente:encoding/json`×7, `shim-ausente:net/url`×3 (+3) |
| 1090 | `go.opentelemetry.io/proto/otlp/collector/trace/v1` | unsupported | `shim-ausente:context`×12, `unsafe:Pointer`×3, `shim-ausente:reflect` |
| 1091 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc` | unsupported | `shim-ausente:context`×3 |
| 1092 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp/internal/otlpjson` | unsupported | `shim-ausente:encoding/json`×7 |
| 1093 | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp` | unsupported | `shim-ausente:net/http`×7, `shim-ausente:context`×2, `shim-simbolo:io.nopCloser`×2, `shim-ausente:compress/gzip`, `shim-ausente:crypto/tls` (+1) |
| 1094 | `github.com/ipfs/boxo/tracing` | unsupported | `shim-ausente:context`×2, `shim-simbolo:os.openFile` |
| 1095 | `github.com/ipfs/kubo/tracing` | unsupported | `shim-ausente:context`×4 |
| 1096 | `github.com/ipfs/kubo/core/coreunix` | unsupported | `shim-ausente:context`×2, `async:contexto-sincrono`, `shim-simbolo:io/fs.FileInfo` |
| 1097 | `github.com/ipfs/kubo/core/coreapi` | unsupported | `shim-ausente:context`×15 |
| 1098 | `github.com/ipfs/kubo/assets` | unsupported | `shim-ausente:path`×2, `shim-ausente:embed` |
| 1099 | `github.com/ipfs/kubo/fuse/ipns` | unsupported | `shim-ausente:context`×7, `shim-simbolo:os.getuid` |
| 1100 | `github.com/ipfs/kubo/fuse/node` | bloqueado |  |
| 1101 | `github.com/ipfs/kubo/plugin/loader` | unsupported | `shim-ausente:path/filepath`, `shim-simbolo:os.open`, `shim-simbolo:os.stat` |
| 1102 | `github.com/ipfs/kubo/commands` | unsupported | `shim-ausente:context` |
| 1103 | `github.com/ipfs/kubo/core/commands/cmdenv` | unsupported | `shim-ausente:context`×3 |
| 1104 | `github.com/ipfs/kubo/core/commands/dag` | unsupported | `shim-ausente:context`×2, `shim-simbolo:io.pipe`×2, `shim-ausente:encoding/csv`, `shim-ausente:path` |
| 1105 | `github.com/ipfs/kubo/core/commands/name` | unsupported | `shim-simbolo:io.copy`, `shim-simbolo:io.limitReader` |
| 1106 | `github.com/ipfs/kubo/core/commands/object` | bloqueado |  |
| 1107 | `github.com/ipfs/kubo/core/commands/pin` | unsupported | `shim-ausente:context`×9, `shim-ausente:encoding/json`, `shim-ausente:net/url`, `shim-ausente:text/tabwriter` |
| 1108 | `github.com/ipfs/kubo/core/commands` | unsupported | `shim-ausente:context`×38, `shim-ausente:path`×13, `shim-ausente:slices`×12, `shim-ausente:text/tabwriter`×8, `shim-ausente:encoding/json`×5 (+30) |
| 1109 | `github.com/ipfs/kubo/core/corehttp` | unsupported | `shim-ausente:net`×21, `shim-ausente:net/http`×10, `shim-ausente:context`×3, `shim-ausente:maps` |
| 1110 | `github.com/ipfs/kubo/repo/fsrepo/migrations/ipfsfetcher` | unsupported | `shim-ausente:context`×2, `shim-ausente:net/url`, `shim-simbolo:os.open` |
| 1111 | `github.com/ipfs/kubo/cmd/ipfs/kubo` | unsupported | `shim-ausente:context`×16, `shim-ausente:net/http`×3, `shim-simbolo:os.create`×2, `shim-simbolo:os.stat`×2, `shim-ausente:encoding/json` (+7) |
| 1112 | `github.com/ipfs/kubo/cmd/ipfs` | bloqueado |  |
