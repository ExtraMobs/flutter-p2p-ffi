# UDP "conectado" no Node sem `connect`

- **Prioridade:** P2 · **Área:** shim (`net`), camada `sys` do Node
- **Depende de:** —

## Problema

`DialUDP`/`Dial("udp")` no Node (`golib_dart/lib/src/net/dial.dart`,
`sys/js_udp.dart`) abrem um socket com `bind` no endereço não especificado
e só filtram o par no shim: `LocalAddr` sai `0.0.0.0`, e o `ECONNREFUSED` do
ICMP (que o Node entrega como evento `error` do `recvmsg` num socket com
`dgram.connect`) nunca chega; o Go conecta o socket, e o erro pendente sai
na próxima operação (`read: connection refused` ou `write: connection
refused`).

## Prova

`tests/golden/netudpconnect/netudpconnect.go`:

```text
$ GOTOOLCHAIN=go1.26.5 go run netudpconnect.go      (a VM é igual)
listen: <nil>
dial: <nil>
local ip: 127.0.0.1 true
remote: SRV
write: <nil>
srv got: oi CL <nil>
client read: resposta <nil>
write to closed: <nil>
read after icmp: read udp CL->SRV: read: connection refused
read again: read udp CL->SRV: i/o timeout
write again: <nil>
write after icmp: write udp CL->SRV: write: connection refused
readfrom after icmp: read udp CL->SRV: i/o timeout
dial port 9: <nil>
dial local ip: 127.0.0.1
dial read: read udp D->127.0.0.1:9: read: connection refused

$ dart compile js ... && node out.js                  (Wasm igual)
listen: <nil>
dial: <nil>
local ip: 0.0.0.0 true
remote: SRV
write: <nil>
srv got: oi 127.0.0.1:40010 <nil>
client read: resposta <nil>
write to closed: <nil>
read after icmp: read udp CL->SRV: i/o timeout
read again: read udp CL->SRV: i/o timeout
write again: <nil>
write after icmp: <nil>
readfrom after icmp: read udp CL->SRV: i/o timeout
dial port 9: <nil>
dial local ip: 0.0.0.0
dial read: read udp D->127.0.0.1:9: i/o timeout
```

O Node 22 tem `dgram.connect` (sondado: `address()` traz `127.0.0.1` e o
ICMP vira `error` com `code: 'ECONNREFUSED', syscall: 'recvmsg'`).

## Critério de pronto

- `sysDialUdp` no Node com `dgram.connect`, `LocalAddr` real, o erro do
  evento guardado e devolvido pela próxima `Read`/`Write` (`read`/`write`
  no `SyscallError`); fixture `netudpconnect` idêntica ao `go run` na VM,
  JS e Wasm.
