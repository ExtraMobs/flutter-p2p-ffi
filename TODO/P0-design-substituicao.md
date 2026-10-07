# Substituição manual de pacote (`unsafe`, assembly, `go:linkname`)

- **Prioridade:** P0 · **Área:** design (decisão D5 do `TODO/README.md`)
- **Depende de:** —

## Problema

O `AGENTS.md` e o `docs/mapping-spec.md` dizem que pacote com `unsafe` de
memória crua, assembly ou função sem corpo "vai para substituição manual",
mas não existe mecanismo para isso: o g2d só conhece shims da stdlib
(`STDLIB_SHIMS`), e o audit só marca o status `substituicao` para os 7
pacotes com assembly. Os pacotes com `unsafe` ficam `unsupported` sem
caminho de saída, e são muitos na fronteira (hashes, `swiss`, `pebble`).

## Prova

```go
package main

import (
	"fmt"
	"unsafe"
)

func main() {
	x := uint32(0x01020304)
	b := (*[4]byte)(unsafe.Pointer(&x))
	fmt.Println(b[0])
}
```

```text
$ go run .
4
$ goast dump . -o dump.json && python -m g2d transpile dump.json -o out
main: não suportado [unsafe:Pointer]: unsafe.Pointer (sem memória crua fora do dart:ffi) em main.go:8:6
```

No grafo do kubo (`docs/audit.md`, pacotes / na fronteira):

```text
| `unsafe:Pointer` | 399 | 80 | 11 | `github.com/cockroachdb/pebble/v2/internal/rawalloc` rawalloc.go:21:6 |
| `conversao:pointer-pointer` | 169 | 39 | 5 | `github.com/spaolacci/murmur3` murmur64.go:34:11 |
| `unsafe:Slice` | 38 | 30 | 3 | `filippo.io/bigmod` nat_noasm.go:12:19 |
| `unsafe:String` | 5 | 4 | 2 | `go.opentelemetry.io/auto/sdk/internal/telemetry` value.go:140:10 |
| `func-sem-corpo` | 7 | 5 | 2 | `github.com/cockroachdb/pebble/v2/internal/rawalloc` rawalloc_go1.9.go:27:6 |
```

Na fronteira: `cespare/xxhash` (v1 e v2), `spaolacci/murmur3`,
`zeebo/blake3/internal/utils`, `cockroachdb/swiss`, `mikioh/tcpopt`,
`pebble/v2/internal/{rawalloc,binfmt}`, `redact/internal/buffer`.

## Decisão pendente

1. **Substituto escrito à mão por pacote inteiro (recomendado).** Um
   diretório (ex. `golib_dart/lib/subst/<import path>.dart`, ou um pacote
   Dart próprio) com a API que o g2d geraria para o pacote; o g2d o trata como
   um shim (registro ao lado de `STDLIB_SHIMS`, `python -m g2d shims` lê os
   símbolos) e não transpila o original. O audit passa a contar esses pacotes
   como verdes. Ordem: os da fronteira acima.
2. **Emular os padrões comuns de `unsafe` no g2d** (`(*[N]byte)(unsafe.Pointer(&x))`
   como vista de bytes sobre o valor). Cobre parte dos hashes, mas cada
   padrão novo é uma regra; `swiss`/`pebble` usam aritmética de ponteiro que
   não cabe aqui.
3. **As duas coisas:** substituição como regra geral, emulação só para os
   padrões que aparecem em muitos pacotes.

## Critério de pronto

- Mecanismo escolhido documentado no `AGENTS.md` e no `docs/mapping-spec.md`.
- Um pacote da fronteira (ex. `cespare/xxhash/v2`) substituído, com teste
  contra oráculo Go; audit regerado.

## Pendências da rede para quando o D5 for decidido (dono, 2026-10-07)

Implementar junto com o D5, assim que possível. Plano completo em
`TODO/P1-rede-ffi-vm.md` (etapas E2 e E6).

- `golang.org/x/sys/unix` substituído à mão sobre a mesma camada libc do
  `dart:ffi` da VM (`golib_dart/lib/src/net/sys/ffi/`, exceção F1 do plano):
  `SetsockoptInt`, `GetsockoptInt`, `GetsockoptLinger`, `GetsockoptTimeval`,
  `GetsockoptTCPInfo` e as constantes `SO_*`/`IPPROTO_*`/`TCP_*`/`IP_*`/
  `IPV6_*`/`UDP_SEGMENT` de linux/amd64. É por ele que passa a maior parte
  do uso real de `Dialer.Control`/`ListenConfig.Control`/`SyscallConn`:
  go-reuseport e go-libp2p (`SO_REUSEADDR`+`SO_REUSEPORT`), quic-go
  (buffers `SO_RCVBUFFORCE`/`SO_SNDBUFFORCE`, GSO, `IP_MTU_DISCOVER`, ECN:
  falha com "activating ECN failed for both IPv4 and IPv6" se as duas
  opções falharem), miekg/dns, grpc (`TCP_USER_TIMEOUT`, channelz).
- `golang.org/x/net/internal/socket` (de `x/net/ipv4`/`ipv6`, usado por
  quic-go, miekg/dns, zeroconf, pion/mdns, go-ssdp): `RawConn.Read/Write`
  com `recvmmsg`/`sendmmsg`, também sobre a camada libc.
- No Node e no navegador o substituto devolve o erro do Go
  (`operation not supported`): não há syscall ali.
