# Golang-to-Dart

Transpilador estático e determinístico de Go para Dart, guiado por AST.
Objetivo de longo prazo: transpilar o **kubo/boxo** (stack IPFS em Go) **incluindo o grafo completo de dependências Go** para Dart puro (sem Flutter).

## Arquitetura do pipeline

```
go list -deps (grafo do módulo)
        │
        ▼
Go source ──► [tools/goast]    ──► AST tipada em JSON (por pacote) ──┐
                                                                     ├──► [g2d: Python] ──► Dart source ──► dart format ──► dart analyze
Dart gerado ──► [tools/dartast] ──► AST em JSON ─────────────────────┘        (validação round-trip)
```

Regras fundamentais:

1. **Extração nativa apenas**: só Go extrai AST de Go (`go/ast` + `go/types`); só Dart extrai AST de Dart (`package:analyzer`). Python **nunca** parseia código-fonte — só consome JSON.
2. **Determinismo**: travessia em ordem fixa, saída canonicalizada via `dart format`, golden-file tests. Qualquer mudança no output gerado deve ser intencional e refletida nos golden files no mesmo commit.
3. **Componentes desacoplados** comunicando-se por JSON versionado (`schemaVersion` em todo dump).
4. **A unidade de trabalho é o pacote Go**; a transpilação percorre o grafo em ordem topológica.
5. **Stdlib Go não é transpilada** — é substituída por shims manuais em `golib_dart/`, priorizados pelo inventário automático de símbolos usados.
6. **Reflexão é resolvida estaticamente** em tempo de transpilação (descritores de tipo gerados + runtime emulado). `dart:mirrors` é proibido.
7. **Todas as plataformas Dart + classe intermediária para toda adaptação.** O código gerado roda igual em VM, AOT, Wasm e JS. Cada semântica Go que o Dart não tem nativamente vive numa classe de `golib_dart` (`Golang.*` para tipos básicos, inclusive `int`/`int64`; `go.GoStruct`, `go.Slice`, `go.GoMap`, `go.Ptr`, `go.Elem`, `go.Defers`...). O emissor só instancia e chama essas classes. Nativo só onde o comportamento é idêntico em todas as plataformas (`bool`). Classe que diverge do Go é corrigida **na classe**, com oráculo Go. Desempenho se ganha dentro das classes, nunca afrouxando o mapeamento. Tabela e roteiro por milestone em `docs/mapping-spec.md`.

## Estrutura

| Caminho | Componente | Linguagem |
|---|---|---|
| `tools/goast/` | Dumper de AST Go tipada → JSON | Go |
| `tools/dartast/` | Dumper de AST Dart → JSON | Dart (`package:analyzer`) |
| `g2d/` | Transpilador: motor (`engine/`), serviços (`services/`), análises (`analysis/`), comportamentos e plugins (`behaviors/`), dump do goast e consultas à AST (`model.py`), `pipeline.py`, `cli.py` — ver "Arquitetura do g2d" | Python (stdlib apenas) |
| `golib_dart/` | Core de adaptação: `fixed_types/` (tipos primitivos Go, origem `dart IPFS/packages/boilerplate`), shims da stdlib em `lib/<import path>.dart` (partes em `lib/src/<import path>/`), runtime em `lib/src/runtime/` exportado por `builtin.dart` (prefixo `go`) | Dart |
| `out/` | Mono-repo Dart gerado (não editar à mão): `lib/<import path>.dart` por pacote e `lib/_anon/<hash>.dart` por struct anônima canônica | Dart (gerado) |
| `tests/golden/<caso>/` | `<caso>.go` → `.goast.json` → `.dart` esperados (+ `.dartast.json` opcional) | — |
| `tests/corpus/kubo/` | Corpus real fixado: módulo que só declara `tool github.com/ipfs/kubo/cmd/ipfs` (kubo **v0.43.1**, boxo v0.42.x); `go.mod`/`go.sum` fixam o grafo inteiro | Go |
| `TODO/` | Backlog: um artefato markdown por problema, com prova real (ver "Processo") | Markdown |
| `docs/` | Documentos vivos (ver abaixo) | Markdown |

## Arquitetura do g2d

O g2d é um **motor** (`g2d/engine/Engine`) que despacha a AST Go tipada para
**comportamentos injetáveis**. Uma classe por responsabilidade e por
comportamento, com classes pais em `g2d/engine/behavior.py`:

| Classe pai | Papel | Onde |
|---|---|---|
| `Service` | responsabilidade compartilhada, registrada por nome e substituível (`engine.services.replace`) | `services/`: `ImportTable`, `Naming`, `TypeSystem`, `TypeMapper`, `DescriptorRegistry`, `ValueSemantics`, `Literals`, `GoTypeInfo`, `Operands`, `Calls`, `Assertions`, `ControlFlow`, `Functions`, `VarDecls`, `Promotion`, `Concurrency`, `DualIO`, `Reflection` (descritores `go.RType` do M5) |
| `Analysis` | pré-passo sobre as declarações; grava em `engine.facts`. As do grafo inteiro (cor `async`, `implements` entre pacotes) resumem cada pacote e juntam numa tabela | `analysis/analyses.py`, `analysis/color.py`, `analysis/ifacecross.py` |
| `ExprBehavior` / `StmtBehavior` | um por nó Go (`kinds`) | `behaviors/exprs.py`, `behaviors/stmts.py` |
| `TypeDeclBehavior` | struct, interface ou nomeado, escolhido por `accepts(t, u)` | `behaviors/decls.py` |
| `BuiltinBehavior` | um por builtin (`name`) | `behaviors/builtins.py` |
| `ConversionBehavior` | uma regra por par de categorias (`accepts`) | `behaviors/conversions.py` |
| `Plugin` | instala serviços, análises e comportamentos | `behaviors/plugins.py` (`DEFAULT_PLUGINS`) |
| `Stage` | passo do pipeline (Load → Emit → Format → Write) | `pipeline.py` |

**Injeção.** `HandlerRegistry` é uma pilha por chave: o último registrado é
tentado primeiro, e quem devolve `NOT_HANDLED` passa a vez ao anterior. Um
plugin pode **substituir** (sempre trata) ou **especializar** (trata só o
seu caso). As cadeias (`accepts`) também preferem o último registrado.

```python
Engine(pkg, plugins=[*DEFAULT_PLUGINS, MeuPlugin()]).emit_package()
```

**Regra:** comportamento novo = classe nova + registro num plugin. Não se
edita o `Engine` para isso. Exemplos em `tests/test_engine.py`.

## Comandos padrão

Go de referência: **1.26.5** (exigido pelo kubo v0.43.1). O `tools/goast/go.mod`
fixa a versão (o `go` baixa o toolchain via `GOTOOLCHAIN=auto`); o e2e fixa
`GOTOOLCHAIN=go1.26.5` para o oráculo `go run`.

```bash
# goast: build + test
cd tools/goast && go build ./... && go test ./...

# dartast: deps + test
cd tools/dartast && dart pub get && dart test

# golib_dart: shims + fixed_types (oráculos exigem `go` no PATH)
cd golib_dart && dart pub get && dart analyze && dart test

# g2d: testes (unitários + golden + e2e: go run × VM × JS × Wasm; JS/Wasm exigem `node`)
python -m unittest discover -s tests -v
G2D_UPDATE_GOLDEN=1 python -m unittest discover -s tests   # regrava goldens; revisar o diff

# g2d: uso
(cd tools/goast && go run . dump <dir-do-pacote> -o dump.json)
(cd tools/goast && go run . dump -C <módulo> @pacotes.txt -outdir dumps/)   # grafo: um JSON por pacote
python -m g2d transpile dump.json -o out                 # out/lib/<import path>.dart + pubspec
python -m g2d graph ./... -C <módulo Go>                 # pacotes não-stdlib em ordem topológica
python -m g2d graph github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo   # grafo do corpus
python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo   # mede o grafo → docs/audit.md, stdlib-coverage.md, reflection-report.md

# Validação de Dart gerado
dart format out/ && dart analyze out/
```

## Convenções

- **Sem novas dependências externas sem aprovação explícita do usuário.** As únicas permitidas hoje: `golang.org/x/tools` (goast), `package:analyzer` (dartast), shims Dart pontuais (`package:http`, `package:crypto`) quando um shim exigir.
- Python: stdlib apenas (`json`, `dataclasses`, `argparse`, `unittest`).
- Todo dump JSON carrega `schemaVersion`; bump ao mudar o schema. Atual: goast **10** (tipos inline na AST, `bytes`, method sets, `implements` com interfaces anônimas e genéricas, `$inst`, `initOrder`, `otherFiles`/`module`, `fold`, `pkg` de campos/métodos não exportados, `conversions`/`asserts` para o `implements` entre pacotes; ver `tools/goast/README.md`), dartast **1**.
- Ponteiros: `dart:ffi` não é usado (não existe no JS/Wasm). Identidade de tipo: uma classe Dart por tipo Go; testes de tipo sempre com `is T` (o `runtimeType` de coleções do core difere no JS).
- `golib_dart/fixed_types` e os ports de `net`/`net/netip`/`internal/poll` vieram do boilerplate do `dart IPFS`; correções feitas aqui ficam listadas em `golib_dart/README.md` para devolver à origem.
- Construção Go não coberta → `Unsupported(código, mensagem, nó)` com código estável (`área` ou `área:detalhe`, ex. `range:func`, `shim-ausente:errors`) e posição (a do nó, ou a da declaração em emissão); nunca emitir Dart aproximado em silêncio. Limites conhecidos ficam marcados ⚠️ em `docs/mapping-spec.md` e com `ponytail:` no código.
- Novo caso de teste = novo diretório em `tests/golden/` (pode ter vários `.go`; o e2e roda `go run` com todos). Caso com `go.mod` é um módulo multi-pacote (`module g2d.test/<caso>`, main em `cmd/`): um `<caso>.goast.json` com o grafo e um `<caso>.<pacote>.dart` por pacote, e o e2e roda `go run ./cmd`; o e2e exige saída idêntica (em bytes) entre `go run` e o Dart gerado na VM, no JS (dart2js/Node) e no Wasm (dart2wasm/Node, via `tests/run_wasm.mjs`), e `dart analyze --fatal-infos` limpo.
- Shim novo ou símbolo novo num shim: rodar `python -m g2d shims` (regera `g2d/shim_symbols.json`, a lista do que o g2d pode chamar — nível de pacote e membros de cada classe, somando as partes `part` de cada shim; o resto vira `Unsupported` `shim-simbolo:`).
- Arquivo escrito à mão acima de ~300 linhas é dividido por responsabilidade: no Go, um arquivo por responsabilidade (métodos de um tipo podem se espalhar por arquivos); no Dart, a library vira partes (`part`, em `lib/src/<import path>/`), com a mesma API e privacidade. Uma classe não é fatiada entre arquivos; arquivo gerado não se divide.
- Runtime do `golib_dart` não usa API exclusiva de uma plataforma (ex. `ByteData.getUint64`, bitwise acima de 32 bits no JS); o que depende de plataforma vai por import condicional (`src/runtime/output.dart`).
- Código gerado em `out/` nunca é editado à mão — correções vão nas regras do `g2d`.

## Processo (desafio kubo/boxo)

Caso real: o grafo de `github.com/ipfs/kubo/cmd/ipfs` em `tests/corpus/kubo`, no
contexto de build fixo do g2d (`g2d/graph.py` `BUILD_ENV`: `CGO_ENABLED=0
GOOS=linux GOARCH=amd64 GOFLAGS=-tags=purego,noasm`), Go 1.26.5. Medido em
2026-09: **1112 pacotes fora da stdlib** (7 com assembly `.s`; 24 sem as tags)
sobre **244 pacotes da stdlib**. Os maiores
módulos: boxo (93), go-libp2p (82), kubo (66), pebble (58).
O `go.mod` do corpus replica o `replace` de go-libp2p do kubo (replace de
dependência não vale para quem importa). Despejar o grafo inteiro
(`goast dump -outdir`) leva ~3 min, ~2,3 GB de pico e ~1,2 GB de JSON.
O `BUILD_ENV` inclui `-tags=purego,noasm`: pacotes com assembly e versão Go pura
usam a pura (sobram 7 com assembly, status `substituicao` no audit).

**Medição (`docs/audit.md`)** é o que ordena o trabalho: a fronteira são os
pacotes não verdes com as dependências todas verdes, e o ranking diz qual
problema destrava mais pacotes dela.

O trabalho é guiado pelo backlog em `TODO/`. O `TODO/README.md` abre com as
**decisões do dono** que travam o próximo passo (D1–D9) e a **fila** sem
decisão pendente; leia antes de escolher o que atacar.

1. Todo problema encontrado vira **um artefato** `TODO/<P0|P1|P2>-<área>-<slug>.md`
   com **prova real** (repro Go mínimo, comando executado e saída colada).
   Candidato que não se reproduz não entra.
2. Ataque pela fila do `TODO/README.md`, respeitando o "Depende de"; item
   com decisão pendente só anda depois da escolha do dono.
3. O commit que resolve o problema **apaga o artefato** (a mensagem cita o
   nome), traz o repro como fixture e atualiza as docs vivas e o
   `TODO/README.md`.
4. Problemas descobertos no caminho viram novos artefatos, provados antes
   de serem escritos.

## Multiagentes

**Sempre que puder, use multiagentes**: divida o trabalho em partes
independentes e rode subagentes em paralelo, em vez de um agente fazendo tudo
em sequência. O agente principal planeja, integra e faz a verificação final.

- Bons cortes: explorar áreas diferentes (`g2d`, `goast`, `dartast`,
  `golib_dart`) ao mesmo tempo; um artefato de `TODO/` ou um shim por agente;
  revisão independente do diff; medir (audit, e2e) enquanto outro agente
  trabalha.
- Agente que edita arquivos em paralelo com outro trabalha numa worktree git
  própria (no Claude Code, `isolation: "worktree"`); o principal integra.
- **Entrega (decisão do dono, 2026-10-03):** nada de PRs paralelos que
  conflitam. Todo o trabalho é integrado numa branch só, com as docs vivas
  (`TODO/`, `AGENTS.md`, `docs/`) atualizadas nela, e sobe direto no `main`;
  só se o push direto for recusado abre-se um único PR. Antes de subir, a
  suíte inteira e o audit rodam sobre o resultado integrado.
- O e2e e o audit leem `g2d/` e `golib_dart/` ao vivo: não edite esses
  diretórios na mesma worktree enquanto eles rodam.

## Documentos vivos (atualizar no mesmo commit das mudanças)

- `docs/mapping-spec.md` — tabela de correspondência semântica Go↔Dart.
- `docs/audit.md` — status de cada pacote do grafo real, ranking de problemas e fronteira (gerado).
- `docs/stdlib-coverage.md` — pacotes/símbolos da stdlib usados pelo grafo × shim (gerado).
- `docs/reflection-report.md` — usos de `reflect` no grafo × pendentes (gerado).
  Os três saem de `python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo`
  (~2 min com os dumps em `.g2d-cache/`; ~6 min sem). Regerar e commitar junto com
  toda mudança que altere o resultado.
- `TODO/README.md` — decisões em aberto e fila; atualizar quando um artefato
  entra, sai ou muda de prioridade.
- Este `AGENTS.md` — atualizar quando arquitetura ou convenções mudarem.

## Milestones

| Milestone | Escopo | Status |
|---|---|---|
| M0 | `AGENTS.md` | ✅ |
| M1 | fundação: dumpers, grafo, esqueleto do g2d | ✅ |
| M2 | MVP do transpilador (import entre pacotes, `init`, `switch`, method values, literais, tipos locais...) | ✅ menos `goto` (decisão D6) |
| M3 | semântica avançada: structs por valor, slices, maps, ponteiros, `defer`/`recover`, tipos nomeados, interfaces, embedding, genéricos, arrays | ✅; interfaces entre pacotes pelo `implements` sobre o grafo (D8) |
| M4 | concorrência: `Chan<T>`, `select`, `go`, `sync`, timers, `context`, cor `async` transitiva | ✅ runtime, emissão, I/O que suspende (D2, versão dupla) e `CancelFunc` com cor própria (D7); ⚠️ classes de func de formato fixo da stdlib (`sort.Slice`...) ficam síncronas |
| M5 | reflexão estática + shims da stdlib | shims em andamento; `reflect` ✅ sobre descritores gerados (D1), inclusive `Call`/`Method`/`MakeFunc`/`StructOf`/`Select`, e `encoding/json` ✅; `Call` sempre suspende (D9); ⚠️ o que depende de `unsafe` (D5) |
| M6 | grafo completo do kubo/boxo (cobertura ≥ 95% por etapa) | **177 de 1112** verdes (`docs/audit.md`) |

As decisões D1–D9 e a fila de trabalho estão em `TODO/README.md`; o que já
funciona, com os limites ⚠️, em `docs/mapping-spec.md`.
