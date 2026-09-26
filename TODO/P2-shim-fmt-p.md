# `%p` (endereço)

- **Prioridade:** P2 · **Área:** shim
- **Depende de:** `P1-runtime-fmt-endereco-ponteiro-func` (mesma forma `0x` + hex)

## Problema

`%p` imprime o endereço de ponteiro, slice, map, func ou chan. O valor não é reproduzível nem no Go
(muda a cada execução), então só a forma pode ser igual. O g2d recusa na transpilação
(`fmt-verbo:%p`); com operando interface, o shim lança em runtime.

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

| código | ocorrências | pacotes | na fronteira | exemplo |
| `fmt-verbo:%p` | 11 | 7 | 1 | `google.golang.org/grpc/attributes` attributes.go:145:21: fmt: %p não portado no shim |
```

Medição sobre todas as chamadas Printf-like dos dumps: 49 ocorrências em 19 pacotes (uma em
`github.com/libp2p/go-libp2p-kad-dht`).

## Critério de pronto

- Decisão registrada no `mapping-spec` (⚠️: endereço estável por objeto, não o do Go); `%p` com as
  flags do Go (`%#p` sem `0x`); a regra sai do `fmtcheck.py`.
