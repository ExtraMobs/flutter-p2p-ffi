# ipfs_ffi

O kubo (IPFS em Go, v0.43.1) usado do Dart sem HTTP. O kubo roda no executável `ipfs_host`,
noutro processo; o app fala com ele por memória compartilhada (a `ipfs_shm`, em C), num
protocolo binário (`WIRE.md`). A API Dart é a do próprio Go, gerada a partir de
`go/gen/roots.txt` e organizada em namespaces por módulo Go (`kubo`, `boxo`, `car`, `ipld`,
`multiformats`, `libp2p`, `go`). Alvos: VM/AOT no Windows, no linux e no Android (não serve
para JS/Wasm).

O `README.md` é o guia de uso; o `DOCS.md` indexa os exemplos por operação; o `API.md`
(gerado) lista cada símbolo exposto e as regras de adaptação; o `TODO.md` guarda o que foi
feito por versão e o que está pendente.

## Estrutura

| Caminho | O que é |
|---|---|
| `lib/` | o pacote Dart: o gerado (uma library por pacote Go, nos namespaces) e o runtime em `lib/src/` (`runtime.dart` e partes, `shm.dart`) |
| `go/` | o `ipfs_host` (`host*.go`, `wire.go`, `callback.go`, `deadlock.go`, os portes à mão `manual_*.go`) e o gerador (`go/gen`, com o `roots.txt` e a tabela de namespaces) |
| `shm/` | a `ipfs_shm` em C (anéis, sininho, a thread que acorda o Dart) |
| `tool/` | `build.dart` (gera e compila por plataforma, com os patches do upstream) e as medidas (`bench*.dart`) |
| `test/` | a suíte Dart (exige o build) |
| `example/` | exemplos numerados; `example/car/` tem as operações com CAR (ver `DOCS.md`); `example/android_app/` é o app Flutter de validação |
| `flutter/` | o plugin companheiro `ipfs_ffi_flutter` (o segundo plano do Android) |

## Comandos

```bash
dart run tool/build.dart [windows|linux|android]   # roda o gerador e compila em native/ (fora do git)
cd go && go vet ./... && go test ./... && go run ./gen -check   # o host e o gerador
dart analyze lib test tool example/*.dart example/car/*.dart
dart test                                          # a suíte inteira (exige o build da plataforma)
```

- Go 1.26.5 (`GOTOOLCHAIN=auto` baixa). Compilador C só para a `ipfs_shm`: mingw-w64 no
  Windows, gcc no linux, o NDK no Android.
- Para expor mais do Go: uma linha no `go/gen/roots.txt` e o build. Módulo novo precisa de
  uma linha em `go/gen/namespaces.go`.
- linux pelo WSL: o WSL e o Windows regravam o `.dart_tool/package_config.json` um do outro;
  rodar `dart pub get` no lado em uso antes de analisar ou testar.
- Android: `dart run tool/build.dart android` e, em `example/android_app/`,
  `flutter test integration_test/ipfs_test.dart -d <aparelho>`. O resto (emulador, aparelho
  real, depuração sem fio) está no README.

## Convenções

- **`dart format` antes de todo commit** em todo `.dart` escrito à mão (o gerado já sai
  formatado): `dart format --output=none --set-exit-if-changed <arquivos>`.
- **A lib em inglês, o resto em português:** comentários e mensagens de `lib/`, do que o
  gerador escreve nela, de `flutter/` e as mensagens que o `ipfs_host` e a `ipfs_shm`
  devolvem ao app ficam em inglês. Testes, ferramentas, comentários internos do Go e do C e
  as docs ficam em português.
- **Expor o que existe em Go,** gerado, sem refazer à mão em Dart. Porte à mão só para corpo
  de comando do kubo (`ipfs dag export/import/put/get`). Ajuste de desempenho de uma chamada
  vira argumento opcional dela (ex. `batchSize`), não configuração global.
- **Sem dependência nova** (Go ou Dart) sem aprovação explícita do dono.
- **Nada de dados pessoais no git** (IPs, número de série de aparelho, caminhos da máquina);
  o repositório é público.
- **Entrega por etapa:** commit do que já está pronto antes de começar a próxima; ao fim,
  versão nos dois `pubspec.yaml`, "Feito" no `TODO.md`, tag `ipfs_ffi-vX.Y.Z`, push direto
  no `main` (remoto `github`) e parar para a revisão do dono.
- **Comportamento do Go conferido com o próprio Go:** quando um resultado surpreende,
  reproduzir num `go run` (oráculo) antes de concluir que a ponte está errada.

## Tentativas anteriores (para consultar abordagens)

O repositório já tentou outros caminhos para ter IPFS em Dart. Vale consultá-los antes de
reinventar algo, ou quando uma abordagem diferente fizer sentido:

- **branch `transpilador`** (tag `transpilador-final`): o transpilador Go→Dart por AST
  (`g2d`, com `goast`, `dartast` e os shims da stdlib em `golib_dart`). Chegou a 192 de 1112
  pacotes do grafo do kubo verdes. Tem o próprio `AGENTS.md`, as decisões D1–D12 (reflexão,
  I/O que suspende, rede, `goto`...), o backlog em `TODO/` e as docs em `docs/`.
- **branch `archive`:** o port manual `dart IPFS`, com Bitswap e DHT interoperando com o kubo
  (inclui o DNS de multiaddr).
- **branches `claude/*`:** trabalho do transpilador interrompido e não integrado.
