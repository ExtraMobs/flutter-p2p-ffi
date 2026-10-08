# `net.ListenMulticastUDP` sem shim

- **Prioridade:** P2 · **Área:** shim (`net`)
- **Depende de:** —

## Problema

`net.ListenMulticastUDP` não existe no shim `net`; o g2d recusa com
`shim-simbolo:net.listenMulticastUDP`. Usuário no grafo do kubo:
`github.com/huin/goupnp@v1.3.0/httpu/serve.go:59`
(`net.ListenMulticastUDP("udp", srv.Interface, addr)`). O Go
(`udpsock_posix.go`, `sockoptip4_linux.go`, `sockoptip6_posix.go`) escuta no
não especificado da família com `SO_REUSEADDR`, faz `IP_MULTICAST_IF` (com
interface), `IP_MULTICAST_LOOP = 0` e `IP_ADD_MEMBERSHIP` (`ip_mreqn` com o
índice da interface); erros como `setsockopt: ...` no `*OpError` `listen`.
O sandbox tem multicast (gVisor): o `go run` abaixo funciona.

## Prova

`tests/golden/netmulticast/netmulticast.go`:

```text
$ GOTOOLCHAIN=go1.26.5 go run netmulticast.go
listen: <nil>
local: 0.0.0.0 true
listen2: <nil>
write self: <nil>
dial group: <nil>
write: <nil>
c: ping SENDER
c2: ping SENDER
unicast: unicast UNI
listen loopback: <nil>
tcp: listen tcp 239.255.0.77:PORT: unknown network tcp
nil: listen udp: missing address
sem ip: listen udp :1: missing address
unicast group: listen udp4 127.0.0.1:0: setsockopt: invalid argument

$ G2D_UPDATE_GOLDEN=1 G2D_CASES=netmulticast python -m unittest tests.test_golden
g2d.model.Unsupported: não suportado [shim-simbolo:net.listenMulticastUDP]: símbolo sem shim: net.listenMulticastUDP em netmulticast.go:47:6
```

## Critério de pronto

- `ListenMulticastUDP` no shim com a sequência do Go: na VM no linux pela
  rede FFI (`setsockopt` no fd real), no Node pelo `dgram` (`reuseAddr`,
  `addMembership`, `setMulticastLoopback`, `setMulticastInterface`); fixture
  `netmulticast` idêntica ao `go run` na VM, JS e Wasm.
