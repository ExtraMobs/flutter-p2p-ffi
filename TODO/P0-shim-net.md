# Shim do pacote `net`

- **Prioridade:** P0 · **Área:** shim (decisão D4 do `TODO/README.md`)
- **Depende de:** segue o modelo de plataforma de `P0-design-os-arquivos`
  (D3). O D2 (I/O que suspende) já está feito: `net.Conn` entra em
  `DUAL_IFACES` e `SHIM_INTERFACES`, e `Read`/`Write` reais vão no `$async`

## Problema

Sem shim de `net`, nada de rede transpila; `net/http` (65 pacotes) e boa
parte do libp2p vêm atrás. Já existe um port em `golib_dart/lib/net.dart`
(do boilerplate do dart IPFS), mas a API é Dart idiomática (`Ip`,
`tryParse`) e não está registrada em `STDLIB_SHIMS`.

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo
| `shim-ausente:net` | 858 | 139 | 20 | `github.com/coreos/go-systemd/v22/daemon` sdnotify.go:56:6: pacote sem shim/transpilação: net |
| `shim-ausente:net/http` | 955 | 65 | 13 | `github.com/caddyserver/zerossl` client.go:132:1: pacote sem shim/transpilação: net/http |
| `shim-ausente:net/netip` | 52 | 17 | 1 | `github.com/libdns/libdns` record.go:39:1: pacote sem shim/transpilação: net/netip |
```

Símbolos mais usados (`docs/stdlib-coverage.md`): `Addr`, `Conn`, `IP`,
`UDPAddr`, `PacketConn`, `SplitHostPort`, `ParseIP`, `TCPAddr`, `Listener`,
`Dialer`, `IPNet`...

## Decidido (dono, 2026-10-05)

- **Navegador:** sem emular TCP sobre WebSocket (exigiria servidor-ponte,
  sem `Listen`/UDP e com semântica diferente da do Go). No navegador o `net`
  devolve erro Go em runtime, como em `js/wasm`; o libp2p/IPFS ali usa os
  próprios transportes de browser (WebSocket, WebTransport, WebRTC), por
  substituição (D5) quando chegar a hora.
- **DNS:** resolver do sistema para IP **e TXT**. O `/dnsaddr` do libp2p
  consulta `_dnsaddr.<domínio>` por TXT (`go-multiaddr-dns` v0.6.0
  `resolve.go:224`, sobre `net.DefaultResolver`). O `dart:io` não faz TXT, então
  a VM leva um cliente DNS UDP próprio; o Node usa `dns.resolveTxt`. O DoH do
  kubo (`DNS.Resolvers`, `go-doh-resolver`) é código transpilado e vem com o
  shim `net/http`.

## Decisão pendente

Como D3, para sockets: `dart:io` na VM/AOT, `node:net`/`node:dgram` no
JS/Wasm sob Node (escolha em runtime: o import condicional não distingue Node
de navegador), e escopo da 1ª entrega (recomendado: endereços, TCP, UDP, DNS e
interfaces de uma vez). A parte sem I/O (`IP`, `IPNet`,
`ParseIP`, `SplitHostPort`, `netip`) não depende de decisão e pode começar
antes.

## Critério de pronto

- Camada com a forma Go (`net.IP`, `net.Conn`, `ParseIP`...) sobre o port,
  registrada em `STDLIB_SHIMS`; ausentes seguem `Unsupported`.
- Oráculo Go nos testes do golib_dart; fixture e2e em VM × JS × Wasm.
- Audit regerado.
