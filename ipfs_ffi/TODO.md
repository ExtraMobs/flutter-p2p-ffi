# Pendências do ipfs_ffi

## Exports diretos para assinaturas simples (sem JSON)

**Situação.** Toda chamada passa pelo export único `IpfsCall` (`go/runtime.go`) com
os argumentos e o resultado em JSON, inclusive um `bool` ou um `int`. Isso deixa o
gerador simples (um símbolo novo = uma linha no `go/gen/roots.txt`) e cobre o que é
estruturado (structs, listas, mapas, opções, múltiplos resultados, `nil`) com a
biblioteca padrão dos dois lados. Bytes já não vão no JSON (buffer C, commit
`3334369`).

**Custo medido** (Windows, 2026-10-11, nó offline): ~27 µs por chamada síncrona sem
trabalho no Go (`ctx.err()`); ~142 µs por `resolvePath` assíncrono sequencial (~40 µs
em paralelo). O custo vem do JSON nos dois sentidos e de ~6 transições Go↔C por
chamada (`GoMalloc`/`GoFree` das strings + a chamada). Irrelevante diante de
operações IPFS (ms no disco, mais na rede); pesa só em laços com milhares de
chamadas pequenas.

**Proposta.** O gerador decide por função: se todos os parâmetros e resultados são
números, `bool`, string ou handle, emite um `//export` próprio com os tipos C
(`int64_t`, `double`, `char*`) e, no Dart, o `lookupFunction` com essa assinatura,
sem JSON; o resto continua no `IpfsCall`. A API Dart gerada não muda (a regra do
projeto: desempenho se ganha dentro do runtime/gerador). Esperado: ~1–3 µs nessas
chamadas. Alternativa menor: alocar os argumentos no Dart sem `GoMalloc` por string
e responder sem JSON quando o resultado for simples.

**Quando.** Só se um uso real mostrar chamadas pequenas e repetidas pesando (medir
antes e depois com o mesmo cenário acima).
