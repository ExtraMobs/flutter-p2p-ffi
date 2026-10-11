# Pendências do ipfs_ffi

## Feito: exports diretos para assinaturas simples (0.5.0)

Toda chamada passava pelo export único `IpfsCall` com JSON (~27 µs no Windows,
mesmo para um `bool`). Desde a 0.5.0 o gerador emite um `//export IpfsD<n>` com
tipos C para cada função **síncrona** só com número, `bool`, string e handle (26
das raízes: os getters da `CoreAPI`, `fsrepo.isInitialized/open`, `files.toFile`,
`os.stat`...); o resto continua no `IpfsCall`. A API Dart não mudou. Medido com
`dart run tool/bench.dart` (20 mil chamadas depois do aquecimento):

| Chamada | Windows antes | Windows depois | linux depois |
|---|---|---|---|
| `api.unixfs()` (handle → handle) | 24–26 µs | 4,2–4,4 µs | 1,5 µs |
| `fsrepo.isInitialized` (string → bool, consulta o disco) | 73–78 µs | 49–50 µs | 3,7 µs |
| `ctx.err()` (à mão, continua em JSON: controle) | 19 µs | 20 µs | 5,9 µs |

Se um dia pesar: o `context.dart` escrito à mão ainda usa JSON (`background`,
`withCancel`, `err`) e pode ganhar exports diretos à mão no mesmo molde.

## Feito: relatório de crash (0.5.0)

Um panic numa goroutine interna do kubo (fora de uma chamada) não é recuperável no
processo: derruba o app. O `guard` cobre só a chamada. `os.create(caminho)` +
`debug.setCrashOutput(f, debug.CrashOptions())` fazem o Go gravar o relatório
(`panic: ...` e o stack das goroutines) nesse arquivo; o app o lê no próximo início.

## Pendente: o resto da comunicação por JSON

Desde a 0.5.0, 26 das 91 funções usam export direto sem JSON; os bytes já atravessam
como buffer C (0.3.0). Ainda passam por JSON: 19 síncronas (bytes em parâmetro ou
resultado, tipos-valor como `Cid`, structs como `Identity`/`Config`/`Link`, opções
funcionais), as 39 `Future` e 7 `Stream` (argumentos e resultado pelo listener) e o
`context.dart` escrito à mão. Passos, em custo crescente:

1. **Exports diretos para bytes e tipos-valor**: bytes como ponteiro+tamanho, CID/path/
   peer ID/multiaddr/ipns.Name como string C. Tira ~10 das 19 síncronas do JSON.
2. **Medir as assíncronas**: quanto de um `resolvePath`/`add` é JSON e quanto é o salto
   do `NativeCallable.listener` e o trabalho do kubo. Se o JSON for fração pequena,
   trocar o formato rende pouco.
3. **Formato binário gerado no lugar do JSON** (structs, listas, mapas, opções,
   resultados assíncronos, eventos de stream), com codificador e decodificador gerados
   nos dois lados. Trabalho do tamanho da F2; decidir com os números do passo 2.

## Marco final: Android

Objetivo de longo prazo do dono: o mesmo nó mínimo rodando num app Android. A API Dart
gerada não muda; mudam o build, o empacotamento da lib nativa e o ciclo de vida no app.
Pré-requisitos: Android SDK + NDK (r27+), um emulador x86_64 e um aparelho arm64.

| Etapa | O quê | Pronto quando |
|---|---|---|
| **A1. Build por ABI** | Alvo `dart run tool/build.dart android`: `GOOS=android GOARCH=arm64/arm/amd64 CGO_ENABLED=1 -buildmode=c-shared` com o clang do NDK de cada ABI (`aarch64-linux-android<api>-clang`, `armv7a-linux-androideabi<api>-clang`, `x86_64-linux-android<api>-clang`) → `native/android/<abi>/libipfs.so`. | as três `.so` saem do build e exportam `IpfsCall`/`IpfsD*`/`GoMalloc` (conferido com `llvm-nm` do NDK); tamanho medido |
| **A2. Carregar a lib** | `ipfsLibraryPath = 'libipfs.so'` no Android (o loader acha a lib do APK); empacotar por `jniLibs/<abi>/` num app de exemplo e, se der, pelo hook de native assets (`hook/build.dart`). | `example` Flutter/Dart mínimo abre a lib no emulador e chama `context.background()` |
| **A3. Nó no app** | Repo no diretório de dados do app (`getApplicationSupportDirectory`), plugins 1x, perfil `lowpower` (ou `randomports`), nó offline e depois online; `add`/`get`/pin/GC como nos exemplos 01–03. | os testes do `kubo_test.dart` que não dependem de dois processos rodam no emulador (integration test) |
| **A4. Rede móvel** | Nó online com o roteamento do `Routing.Type`; permissão `INTERNET`; medir peers, NAT (rede celular x Wi-Fi), relay/AutoTLS. | o exemplo 04 conecta à rede pública num aparelho real, em Wi-Fi e em dados móveis |
| **A5. Ciclo de vida** | Fechar o nó (`close`) quando o app vai para background e reabrir na volta; `debug.setCrashOutput` no diretório do app e leitura do relatório no próximo início; isolates auxiliares para o trabalho longo. | ir e voltar do background 10x sem vazar handles nem travar; crash de teste gera relatório legível no app |
| **A6. Custo** | Medir tamanho do APK por ABI, memória, bateria e dados em 1 h de nó online; `tool/bench.dart` no aparelho (JSON x direto). | números registrados aqui, com o perfil e o roteamento recomendados para celular |

Limites esperados: a `.so` grande (~57 MB no Windows; reduzir com `-ldflags=-s -w` e
`-trimpath`, que o build já usa, e talvez cortando plugins/transportes não usados);
um nó por processo (plugins e métricas globais do kubo); iOS fora do escopo atual.
