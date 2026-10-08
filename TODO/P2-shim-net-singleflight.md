# `LookupIPAddr` sem `singleflight`: consultas iguais saem várias vezes

- **Prioridade:** P2 · **Área:** shim (`net`)
- **Depende de:** —

## Problema

O `(*Resolver).lookupIPAddr` do Go junta consultas iguais simultâneas
(`network + "\0" + host`) no `singleflight.Group` do `Resolver` e espera o
resultado num `select` com o `ctx.Done()`: quem cancela sai na hora com
`lookup <host>: operation was canceled` (sem `Server`), e a consulta só é
cancelada se ninguém mais a compartilha (`ForgetUnshared`). O shim
(`golib_dart/lib/src/net/lookup_ip.dart`) disca uma vez por chamada e só vê o
cancelamento quando a `Conn` volta, com o servidor no erro.

## Prova

`tests/golden/netsingleflight/netsingleflight.go` (Resolver `PreferGo` com
`Dial` que conta as discagens e espera um portão):

```text
$ GOTOOLCHAIN=go1.26.5 go run netsingleflight.go
single: true [true]
concurrent == single: true [true true true]
two names == 2*single: true
two resolvers == 2*single: true
canceled: lookup sf.test: operation was canceled
background: err=true
shared after cancel == single: true
alone canceled: lookup sf.test: operation was canceled
after forget: true true

$ dart run lib/netsingleflight.dart        (VM; JS e Wasm iguais)
single: true [true]
concurrent == single: false [true true true]
two names == 2*single: true
two resolvers == 2*single: true
canceled: lookup sf.test on 8.8.4.4:53: operation was canceled
background: err=true
shared after cancel == single: false
alone canceled: lookup sf.test on 8.8.4.4:53: operation was canceled
after forget: true true
```

## Critério de pronto

- Porta do `internal/singleflight` (`DoChan` + `ForgetUnshared`) por
  `Resolver`, em Dart puro; o `select` com o `ctx` do Go; fixture
  `netsingleflight` idêntica ao `go run` na VM, JS e Wasm.
