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
