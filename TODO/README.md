# TODO — backlog do desafio kubo/boxo

Estado em 2026-10-05, com o D1 completo (reflexão, `encoding/json`, `time` com layout), o D8
(interfaces entre pacotes) e o D4 (rede real no `net`) no `main`: **191 de 1112** pacotes
do grafo do kubo verdes (`docs/audit.md`, Dart SDK 3.13.5; o `main` de
2026-10-02 regerado no mesmo ambiente dá 157, não os 167 registrados antes).
A fronteira (pacotes não verdes com as dependências todas verdes) tem 167
pacotes. Os números abaixo saem do ranking do audit
(pacotes afetados / pacotes na fronteira).

## 1. Decisões do dono antes de seguir

Estes itens não andam sem uma escolha de desenho. Cada um tem um artefato com
as opções e a recomendação; a tabela é o resumo.

| # | Decisão | O que trava | Recomendação | Artefato |
|---|---|---|---|---|
| D3 | `os` acessa o sistema de arquivos real? | `os.*` + `io/fs.*` 24 ocorrências na fronteira (`os.open` sozinho: 22 / 4) | sim: `dart:io` na VM/AOT, `node:fs` no JS/Wasm sob Node, erro `*PathError` no navegador | `P0-design-os-arquivos.md` (+ pendências da rede: `FileConn`/`FileListener`, go-fuse) |
| D5 | Como entra a substituição manual de pacote (`unsafe`, assembly, `go:linkname`) | `unsafe:Pointer` 80 / 11, `conversao:pointer-pointer` 38 / 4, `unsafe:Slice` 30 / 3, 7 pacotes com assembly | substituto Dart escrito à mão por pacote inteiro, registrado como um shim | `P0-design-substituicao.md` (+ pendências da rede: `x/sys/unix` para `Control`/reuseport) |
| D6 | Reabrir `goto` (hoje ❌ por decisão) | `branch:goto` 28 / 10 (era 14 / 3 quando foi decidido) | implementar no g2d, começando pelos saltos que viram `break`/`continue` rotulados | `P0-design-goto.md` |

Já decidido (não reabrir): D10 (2026-10-07), rede pelo `dart:ffi` na VM: `dart:ffi` só em `golib_dart/lib/src/sysffi/` atrás de `if (dart.library.ffi)` (F1), UDP da VM no linux pelo FFI (F2), linux antes do macOS e Windows sem FFI (F3), `Control`/`SyscallConn` no Node falham como o Go em js/wasm (F4) e o e2e aceita `<caso>.node.out` só com o erro de "não suportado" da mesma operação (F5); plano e etapas em `P1-rede-ffi-vm.md`. D4 (2026-10-05), rede real no `net` com o
comportamento do Go: `dart:io` na VM/AOT, `node:net`/`node:dgram`/`node:dns`
no JS/Wasm sob Node (escolha em runtime) e erro Go no navegador, sem emular
TCP sobre WebSocket; DNS do sistema para IP e TXT (cliente UDP próprio na
VM); feito: TCP, UDP, sockets Unix de fluxo (`unix`; `unixgram`/`unixpacket`
seguem `operation not supported`), DNS, portas e interfaces
(`docs/mapping-spec.md` § "Rede (D4)"). D8 (2026-10-05), interface satisfeita por tipo
de outro pacote: `implements` sobre o grafo, restrito às conversões que
acontecem (e aos tipos que viram interface e são testados por type
assertion), com a library do tipo importando a da interface
(`docs/mapping-spec.md` § "Interfaces entre pacotes (D8)"). D9 (2026-10-04), `reflect.Value.Call`/`CallSlice`
sempre suspendem e quem chama ganha a cor `async` (forma síncrona só em
contexto que precisa ficar síncrono). D1 (2026-10-04), reflexão por descritores
estáticos que o g2d gera por tipo (nome, tipo, tag, getter e setter como
closures, métodos, assinaturas de func e tear-offs), com o shim `reflect` só lendo o descritor;
`Call`/`Method`/`MakeFunc`/`FuncOf`/`StructOf`/`Select` prontos
(`docs/mapping-spec.md` § "Reflexão (M5, D1)"). D7 (2026-10-02), tipo de função nomeado da
stdlib (`context.CancelFunc`) é classe de cor própria e a `func()` comum
segue a cor dela, com cor própria para campo `func()` não exportado
(`docs/mapping-spec.md` § "Cor transitiva"). M4 usa cor `async` transitiva calculada pelo g2d;
contextos que precisam ficar síncronos viram `Unsupported`; Riverpod,
"tudo async" e isolates foram descartados (`docs/mapping-spec.md` § "Cor
transitiva"). D2 (I/O que suspende): **versão dupla** — métodos de I/O e
funções do shim que os chamam têm a forma síncrona e a `$async`, escolhida
pela cor (`docs/mapping-spec.md` § "I/O que suspende").

## 2. Fila sem decisão pendente

### 2a. Destravam a fronteira do audit

| Artefato | Pacotes / fronteira | Resumo |
|---|---|---|
| `P1-construcao-construtor-ambiguo.md` | 7 / 4 | campos `C` e `c` na mesma struct colidem no construtor |
| `P1-shim-iter.md` | 19 / 4 (`iter`) e 10 / 3 (`splitSeq`) | `iter.Seq` e `strings.SplitSeq`/`Lines` (range sobre func já funciona) |

### 2b. Saída errada em silêncio (o audit não vê)

Achados da revisão diferencial de 2026-10-02 (programa Go × Dart gerado, VM e
JS): o g2d gera Dart válido que imprime outra coisa. São os mais perigosos,
porque um pacote "verde" pode estar errado. Os sete primeiros (cópia de
ponteiro em `append`/`copy`, chave de map, `T` em genéricos, receptor no
`defer`/`go`, `for` por iteração, method set de `*T`, `String()` aninhado
no `fmt`) foram resolvidos em 2026-10-03.

| Artefato | Resumo |
|---|---|
| `P1-construcao-ordem-avaliacao.md` | `x + f()`, `x += f()`, `a[i] = f()`, literais e atribuição múltipla leem fora da ordem do gc |
| `P1-construcao-incdec-impuro.md` | `m[f()]++` chama `f` duas vezes |
| `P1-construcao-assert-nomeado.md` | `x.([]int)` aceita `type IntList []int` |
| `P1-runtime-comparacao-incomparavel.md` | `==` de interface com slice dentro não dá panic |
| `P1-shim-fmt-formatos.md` | `Sprint` com string nomeada, nil aninhado com `%d`, `&slice`, `[]Code` com `%s` |

### 2c. Dart inválido ou g2d quebra (sem `Unsupported`)

| Artefato | Resumo |
|---|---|
| `P1-construcao-generico-metodo-ptr-t.md` | método ou campo `*T` de tipo genérico instanciado com struct (`Box[P].Set(&x)`; `crlib/fifo` no audit) |
| `P1-construcao-dart-invalido-audit.md` | `pion/transport/deadline` e `x/text/.../compact` com Dart inválido no audit |

### 2d. Em execução

| Artefato | Resumo |
|---|---|
| `P1-rede-ffi-vm.md` | D10: shim `syscall`, `IPConn`, base FFI (poller, ponte), `Control`/`SyscallConn`, `unixgram`/`unixpacket`, IP bruto, UDP no FFI, e as correções S1–S5 do `net` (`Resolver.Dial`, `LookupSRV`/`MX`..., `/etc/services`, `KeepAliveConfig`, `FallbackDelay`) |

### 2e. P2

`P2-construcao-shift-constante.md`, `P2-runtime-panic-nil-e-texto.md`,
`P2-construcao-defer-iface-recover.md`, `P2-runtime-complex64.md`,
`P2-shim-fmt-tipo-T.md`, `P2-runtime-slice-de-array-mensagem.md`,
`P2-design-interface-nomeada-valor-de-shim.md`.

Shims sem artefato: a fila é o ranking do `docs/audit.md`. Hoje os que mais
destravam a fronteira e não dependem de decisão são `hash` (28 / 11),
`slices` (84 / 10), `encoding/hex` (24 / 10), `net/url` (53 / 9), `log`
(31 / 8), `runtime` (40 / 7), `encoding/base64` (26 / 7), `math/big`
(18 / 7), `bufio` (30 / 5) e `crypto/rand` (30 / 5).

Sem artefato ainda: `async:contexto-sincrono` (63 / 7; ex. `benbjohnson/clock`,
chamada que suspende onde o contexto precisa ficar síncrono) subiu no ranking
depois do D2 e de novo com o D8 (de 40 para 63 pacotes, todos antes
bloqueados): com o `implements` entre pacotes, a cor `async` de uma
implementação chega à interface de outro pacote, e um `String()`/`Error()`
que chama um logger (`grpclog` em `grpc/connectivity`) ou o `redact`
(`cockroachdb/errors`) passa a ver a chamada que suspende. Precisa de prova
e artefato antes de entrar na fila.

## 3. Convenção

Um problema por arquivo, `<prioridade>-<área>-<slug>.md` (`ls` lista na
ordem de ataque). **O commit que resolve o problema apaga o arquivo** e cita
o nome na mensagem; o histórico fica no git. Ao resolver, atualize as seções
1 e 2 acima.

| Prioridade | Significado |
|---|---|
| `P0` | bloqueia ≥ 10 pacotes da fronteira, ou é pré-requisito de outro P0 |
| `P1` | bloqueia pacotes da fronteira ou ≥ 5 pacotes do grafo; ou Dart inválido / saída errada em silêncio |
| `P2` | raro no grafo (< 5 pacotes, fora da fronteira), ou limite com contorno |

Áreas: `construcao` (Go → Dart no g2d), `shim` (stdlib em `golib_dart`),
`runtime` (classes de `golib_dart`), `design` (decisão de mapeamento),
`infra` (ferramentas, testes, pipeline), `substituicao` (pacote com
cgo/asm/unsafe/syscall), `docs`.

Shim de pacote da stdlib só ganha artefato quando precisa de decisão ou tem
limite a registrar; o resto segue o ranking do audit e a linha do pacote em
`docs/stdlib-coverage.md`. O que já foi feito num shim fica em
`docs/mapping-spec.md` § "Stdlib", não no artefato.

Seções de um artefato:

1. **Problema**: o que falta ou está errado, em uma ou duas frases.
2. **Prova**: obrigatória e **real**: repro Go mínimo, comando executado e
   saída colada (`não suportado`, erro do `dart analyze`, divergência
   `go run` × `dart run`). Para o grafo real, a linha do `docs/audit.md`
   (código, ocorrências, pacotes, exemplo com posição) é prova.
3. **Decisão pendente** (só em `design`): opções, recomendação e o que muda
   em cada uma.
4. **Critério de pronto**: em geral, o repro vira fixture em `tests/golden/`,
   e2e idêntico em VM × JS × Wasm, `dart analyze --fatal-infos` limpo, docs
   vivas atualizadas, audit regerado.
5. **Depende de**: outros artefatos.

Como provar:

- Pacote único: `goast dump <dir> -o dump.json` → `python -m g2d transpile
  dump.json -o out` → `dart analyze` e `go run` × `dart run` (VM e JS).
- Multi-pacote: módulo com `go.mod`; `goast dump -C <módulo> ./... -o
  dump.json` → `python -m g2d transpile dump.json -o out` → `dart analyze`
  e `go run ./cmd` × `dart run out/lib/<módulo>/cmd.dart`.
- Grafo real: `python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C
  tests/corpus/kubo`.
- Limites decididos (ex.: ordem de chaves por endereço) ficam em
  `docs/mapping-spec.md`, não aqui.

## 4. Branches `claude/wip-*` antigas

Conferido em 2026-10-02 contra o `main` (`git merge-base --is-ancestor`).
As sessões daqui não apagam branches; o dono apaga pelo GitHub.

- Branches dos PRs #1 a #10, já mesclados no `main`, podem ser apagadas
  (#1, `wonderful-mendel-00xe54`, o resto do shim `io`, entrou em
  2026-10-04 portado para a versão dupla do D2).

- Já contidas no `main`, podem ser apagadas: `wip-evalorder`,
  `wip-fmt-sharp-v`, `wip-m4a-runtime`, `wip-privacidade-libraries`,
  `wip-shims-pequenos` (aponta para um commit antigo do `main`; os shims
  pequenos que ela descrevia nunca foram feitos), `wip-strings-bytes`,
  `wip-time`, `wip-typeswitch-func`, `wip-unicode`.
- Superadas, podem ser apagadas: `wip-ifacecross` (o D8 entrou
  reescrito em 2026-10-05), `wip-handoff` (plano de 2026-09-27, já
  executado ou refletido aqui), `wip-m4b-g2d-async` (a etapa 1 do M4b, que
  entrou reescrita pelo PR #3), `wip-regexp` (port parcial do parser; o
  `main` tem o shim completo).
- Com trabalho aproveitável: `wip-os` (erros e constantes do `os`, espera
  D3), `wip-strconv` (snapshot com `FormatComplex`, ainda ausente no `main`).
