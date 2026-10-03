# TODO — backlog do desafio kubo/boxo

Estado em 2026-10-03: **158 de 1112** pacotes do grafo do kubo verdes
(`docs/audit.md`). A fronteira (pacotes não verdes com as dependências todas
verdes) tem 184 pacotes. Os números abaixo saem do ranking do audit
(pacotes afetados / pacotes na fronteira).

## 1. Decisões do dono antes de seguir

Estes itens não andam sem uma escolha de desenho. Cada um tem um artefato com
as opções e a recomendação; a tabela é o resumo.

| # | Decisão | O que trava | Recomendação | Artefato |
|---|---|---|---|---|
| D1 | Recorte inicial do M5 (reflexão) | `reflect` 126 / 21 (1º do ranking); `encoding/json` 62 / 12 depende dele | shim `reflect` sobre descritores gerados, começando por `TypeOf`/`ValueOf`/`Kind`/`Elem`/`Type`/`Interface` | `P0-design-m5-reflexao.md` |
| D2 | I/O que suspende atrás de interface da stdlib (`io.Reader`, `net.Conn`) | `async:contexto-sincrono` 62 / 5; é pré-requisito de D4 (arquivos podem ser lidos de forma síncrona, rede não) | interfaces de I/O do shim entram na cor como interface comum; shims que as chamam ganham versão `$async` | `P0-design-io-suspende.md` |
| D3 | `os` acessa o sistema de arquivos real? | `os.*` + `io/fs.*` 24 ocorrências na fronteira (`os.open` sozinho: 22 / 4) | sim: `dart:io` na VM/AOT, `node:fs` no JS/Wasm sob Node, erro `*PathError` no navegador | `P0-design-os-arquivos.md` |
| D4 | Rede real no `net` | `net` 139 / 20, `net/http` 65 / 13 | mesmo modelo do D3 (`dart:io` / `node:net`), sobre o port que já existe | `P0-shim-net.md` |
| D5 | Como entra a substituição manual de pacote (`unsafe`, assembly, `go:linkname`) | `unsafe:Pointer` 80 / 11, `conversao:pointer-pointer` 39 / 5, `unsafe:Slice` 30 / 3, 7 pacotes com assembly | substituto Dart escrito à mão por pacote inteiro, registrado como um shim | `P0-design-substituicao.md` |
| D6 | Reabrir `goto` (hoje ❌ por decisão) | `branch:goto` 28 / 10 (era 14 / 3 quando foi decidido) | implementar no g2d, começando pelos saltos que viram `break`/`continue` rotulados | `P0-design-goto.md` |
| D8 | Interface satisfeita por tipo de outro pacote | invisível no audit hoje (os pacotes param antes em shim); saída errada em silêncio com `fmt.Stringer` | `implements` sobre o grafo, restrito às conversões que acontecem e a donos fora da stdlib | `P1-design-interfaces-entre-pacotes.md` |

Já decidido (não reabrir): D7 (2026-10-02), tipo de função nomeado da
stdlib (`context.CancelFunc`) é classe de cor própria e a `func()` comum
segue a cor dela, com cor própria para campo `func()` não exportado
(`docs/mapping-spec.md` § "Cor transitiva"). M4 usa cor `async` transitiva calculada pelo g2d;
contextos que precisam ficar síncronos viram `Unsupported`; Riverpod,
"tudo async" e isolates foram descartados (`docs/mapping-spec.md` § "Cor
transitiva").

## 2. Fila sem decisão pendente

### 2a. Destravam a fronteira do audit

| Artefato | Pacotes / fronteira | Resumo |
|---|---|---|
| `P1-construcao-construtor-ambiguo.md` | 7 / 4 | campos `C` e `c` na mesma struct colidem no construtor |
| `P1-shim-io.md` | 58 ocorrências / 6 | `LimitReader`, `CopyN`, `Copy`, `MultiWriter`, `SectionReader`... |
| `P1-shim-iter.md` | 19 / 4 (`iter`) e 10 / 3 (`SplitSeq`) | `iter.Seq` e `strings.SplitSeq`/`Lines` (range sobre func já funciona) |
| `P1-shim-time-layout.md` | 10 / 2 | `time.Format`/`Parse` com layout |

### 2b. Saída errada em silêncio (o audit não vê)

Achados da revisão diferencial de 2026-10-02 (programa Go × Dart gerado, VM e
JS): o g2d gera Dart válido que imprime outra coisa. São os mais perigosos,
porque um pacote "verde" pode estar errado.

| Artefato | Resumo |
|---|---|
| `P1-runtime-copyof-ponteiro.md` | `append`/`copy`/cópia de array de `[]*T` duplicam os objetos apontados |
| `P1-construcao-chave-de-map-sem-copia.md` | chave struct/array guardada por referência; mudar a variável perde a entrada |
| `P1-construcao-generico-sem-copia.md` | valor de tipo `T` não é copiado dentro de genérico |
| `P1-construcao-defer-go-receptor-valor.md` | `defer x.M()` vê mudanças feitas depois do `defer` |
| `P1-construcao-for-variavel-por-iteracao.md` | `for i := ...` com `&i` ou struct compartilha a variável (Go ≥ 1.22 não) |
| `P1-construcao-ordem-avaliacao.md` | `x + f()`, `x += f()`, `a[i] = f()`, literais e atribuição múltipla leem fora da ordem do gc |
| `P1-construcao-incdec-impuro.md` | `m[f()]++` chama `f` duas vezes |
| `P1-runtime-method-set-ponteiro.md` | `T` em interface satisfaz interface que exige método de `*T` |
| `P1-construcao-assert-nomeado.md` | `x.([]int)` aceita `type IntList []int` |
| `P1-runtime-comparacao-incomparavel.md` | `==` de interface com slice dentro não dá panic |
| `P1-shim-fmt-metodos-aninhados.md` | `fmt` não chama `String()` de `*T` aninhado, chama em campo não exportado, quebra com panic/nil no método |
| `P1-shim-fmt-formatos.md` | `Sprint` com string nomeada, nil aninhado com `%d`, `&slice`, `[]Code` com `%s` |
| `P1-design-interfaces-entre-pacotes.md` | (D8) inclui tipo de shim em interface local: `err.(interface{ Unwrap() error })` falha |

### 2c. Dart inválido ou g2d quebra (sem `Unsupported`)

| Artefato | Resumo |
|---|---|
| `P1-construcao-statements-quebram.md` | `(*p)++`, `switch` vazio, rótulo `in:`, variável de type switch atribuída |
| `P1-construcao-genericos-dart-invalido.md` | `*T`, `/=` e `+` sobre parâmetro de tipo |
| `P1-construcao-promocao-dart-invalido.md` | embutir nomeado não-struct com método `*T`; embedding em tipo local |
| `P1-construcao-array-nomeado-interface.md` | `type Arr [2]int` com métodos em interface |
| `P1-infra-metodos-de-shim.md` | método ausente em tipo de shim (`t.Format`) não vira `Unsupported` |
| `P1-construcao-metodo-sombreia-pacote.md` | método `_sub` sombreia constante `_sub` |
| `P1-design-anonimas-canonicas.md` | `struct{ X int }` de pacotes diferentes vira classes diferentes |
| `P1-design-promocao-transitiva-nao-exportada.md` | método não exportado promovido por dois saltos de pacote quebra em runtime |

### 2d. P2

`P2-construcao-shift-constante.md`, `P2-runtime-panic-nil-e-texto.md`,
`P2-construcao-defer-iface-recover.md`, `P2-runtime-complex64.md`,
`P2-shim-fmt-tipo-T.md`, `P2-runtime-slice-de-array-mensagem.md`.

Shims sem artefato: a fila é o ranking do `docs/audit.md`. Hoje os que mais
destravam a fronteira e não dependem de decisão são `hash` (28 / 11),
`slices` (83 / 10), `encoding/hex` (24 / 10), `net/url` (53 / 9), `runtime`
(39 / 9), `log` (31 / 8), `encoding/base64` (26 / 8), `math/big` (18 / 7),
`bufio` (32 / 6) e `crypto/rand` (32 / 6).

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

- Já contidas no `main`, podem ser apagadas: `wip-evalorder`,
  `wip-fmt-sharp-v`, `wip-m4a-runtime`, `wip-privacidade-libraries`,
  `wip-shims-pequenos` (aponta para um commit antigo do `main`; os shims
  pequenos que ela descrevia nunca foram feitos), `wip-strings-bytes`,
  `wip-time`, `wip-typeswitch-func`, `wip-unicode`.
- Superadas, podem ser apagadas: `wip-handoff` (plano de 2026-09-27, já
  executado ou refletido aqui), `wip-m4b-g2d-async` (a etapa 1 do M4b, que
  entrou reescrita pelo PR #3), `wip-regexp` (port parcial do parser; o
  `main` tem o shim completo).
- Com trabalho aproveitável: `wip-os` (erros e constantes do `os`, espera
  D3), `wip-ifacecross` (`implements` sobre o grafo, espera D8),
  `wip-strconv` (snapshot com `FormatComplex`, ainda ausente no `main`).
