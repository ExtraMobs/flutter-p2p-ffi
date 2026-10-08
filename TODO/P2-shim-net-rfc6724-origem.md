# RFC 6724: origem de cada destino pela lista de interfaces

- **Prioridade:** P2 · **Área:** shim (`net`)
- **Depende de:** —

## Problema

O `sortByRFC6724` do Go (`addrselect.go`, `srcAddrs`) acha a origem de cada
destino com `DialUDP("udp", nil, dst:9)` e lê o `LocalAddr` (a rota do
kernel). O shim (`golib_dart/lib/src/net/addrselect.dart`, `_srcAddr`)
aproxima pela lista de interfaces e erra quando a rota escolhe outra
origem: para `0.0.0.0` o kernel usa `127.0.0.1` (escopo link-local, que não
casa com o do destino: a regra 2 o põe depois de um destino global), e o
shim dá o IP da `eth0`.

## Prova

`tests/golden/netaddrselect/netaddrselect.go` (servidor DNS falso com
A/AAAA, `Resolver{PreferGo, Dial}`):

```text
$ GOTOOLCHAIN=go1.26.5 go run netaddrselect.go
zero.test [{8.8.8.8 } {0.0.0.0 }] <nil>
loop.test [{127.0.0.1 } {8.8.8.8 }] <nil>
lo2.test [{127.0.0.2 } {8.8.4.4 } {0.0.0.0 }] <nil>
v6.test [{8.8.8.8 } {2001:db8::1 }] <nil>
local.test [{8.8.8.8 } {169.254.1.1 }] <nil>
lo6.test [{8.8.8.8 } {::1 }] <nil>
bcast.test [{8.8.8.8 } {255.255.255.255 }] <nil>
mcast.test [{224.0.0.1 } {8.8.8.8 }] <nil>

$ dart run lib/netaddrselect.dart          (JS e Wasm iguais)
zero.test [{0.0.0.0 } {8.8.8.8 }] <nil>
loop.test [{127.0.0.1 } {8.8.8.8 }] <nil>
...                                         (o resto igual)
```

(Sandbox: `eth0` 192.0.2.2/24, rota padrão por 192.0.2.1, sem IPv6.)

## Critério de pronto

- `srcAddrs` como o Go: `DialUDP` para a porta 9 de cada destino e o
  `LocalAddr` (na VM no linux o `connect` da rede FFI, no Node o
  `dgram.connect`); fixture `netaddrselect` idêntica ao `go run` na VM,
  JS e Wasm.
