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

## Marco final: Android

Objetivo de longo prazo do dono: o mesmo nó mínimo rodando num app Android. A API
Dart gerada não muda; muda só o build e o empacotamento da lib nativa. Fica depois do
linux (F1) e das fases F2–F4 do roteiro.

- **Build**: `GOOS=android`, `CGO_ENABLED=1`, `-buildmode=c-shared`, com o clang do
  NDK de cada ABI (`aarch64-linux-android<api>-clang` etc.) → uma `libipfs.so` por ABI
  (`arm64-v8a`, `armeabi-v7a`, `x86_64`). Novo alvo `tool/build.dart android`.
- **Empacotamento**: pelo hook de native assets do Dart (`hook/build.dart`) ou por
  `jniLibs/<abi>/libipfs.so` no app; no Dart, `ipfsLibraryPath = 'libipfs.so'` (sem
  caminho: o loader do Android acha a lib do APK).
- **Execução**: repo no diretório de dados do app; permissão de rede; perfil
  `lowpower` (ou `randomports`); fechar o nó (`close`) quando o app vai para
  background e reabrir na volta.
- **A validar lá**: tamanho da `.so` (~57 MB no Windows hoje), consumo de bateria e de
  dados, NAT de rede móvel, tempo de subida do nó.
