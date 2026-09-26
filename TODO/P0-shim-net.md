# Shim do pacote `net`

- **Prioridade:** P0 · **Área:** shim
- **Depende de:** P0-design-m4-concorrencia (I/O bloqueante)

## Problema

Sem shim, 154 pacotes do grafo do kubo que usam `net` não transpilam (`shim-ausente:net`).
São 126 símbolos distintos.

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `shim-ausente:net` | 617 | 109 | 17 | `github.com/google/gopacket/routing` common.go:16:1: pacote sem shim/transpilação: net |
```

```text
docs/stdlib-coverage.md:
| pacote | pacotes do grafo | shim | símbolos |
| `net` | 154 | ❌ | Addr(69), Conn(63), IP(54), Close(48), String(48), UDPAddr(34), To4(31), PacketConn(30), LocalAddr(27), SplitHostPort(26), Port(25), ParseIP(22), TCPAddr(21), Listener(20), RemoteAddr(20), Write(20), Dialer(19), IPNet(19), To16(18), Interface(16), ResolveUDPAddr(16), Equal(15), IPAddr(15), Timeout(15), Error(14), … (+101) |
```

## Critério de pronto

- `golib_dart/lib/net.dart` registrado em `STDLIB_SHIMS` (`g2d/config.py`), cobrindo os símbolos da
  linha `net` de `docs/stdlib-coverage.md` a partir dos mais usados; os ausentes continuam
  `Unsupported` (nunca chamada a função inexistente).
- Semântica com oráculo Go nos testes do golib_dart; fixture e2e em VM × JS × Wasm.
- Audit regerado e commitado.

## Notas

Já existe um port em `golib_dart/lib/net.dart` (boilerplate do dart IPFS), mas não está registrado em `STDLIB_SHIMS` e a API é Dart idiomática: falta a camada com a forma Go (`net.IP`, `net.Conn`, `ParseIP`...).
