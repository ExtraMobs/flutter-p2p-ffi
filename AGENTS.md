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
| `g2d/` | Transpilador (model, graph, semantics, mapping, emit, cli) | Python (stdlib apenas) |
| `golib_dart/` | Core de adaptação: `fixed_types/` (tipos primitivos Go, origem `dart IPFS/packages/boilerplate`), shims da stdlib em `lib/<import path>.dart`, runtime em `lib/src/runtime/` exportado por `builtin.dart` (prefixo `go`) | Dart |
| `out/` | Mono-repo Dart gerado (não editar à mão) | Dart (gerado) |
| `tests/golden/<caso>/` | `<caso>.go` → `.goast.json` → `.dart` esperados (+ `.dartast.json` opcional) | — |
| `tests/corpus/` | Pacotes reais de complexidade crescente | Go |
| `docs/` | Documentos vivos (ver abaixo) | Markdown |

## Comandos padrão

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
python -m g2d transpile dump.json -o out                 # out/lib/<import path>.dart + pubspec
python -m g2d graph ./... -C <módulo Go>                 # pacotes não-stdlib em ordem topológica

# Validação de Dart gerado
dart format out/ && dart analyze out/
```

## Convenções

- **Sem novas dependências externas sem aprovação explícita do usuário.** As únicas permitidas hoje: `golang.org/x/tools` (goast), `package:analyzer` (dartast), shims Dart pontuais (`package:http`, `package:crypto`) quando um shim exigir.
- Python: stdlib apenas (`json`, `dataclasses`, `argparse`, `unittest`).
- Todo dump JSON carrega `schemaVersion`; bump ao mudar o schema. Atual: goast **5** (tipos inline na AST, `bytes`, method sets, `implements`, `$inst`, `initOrder`; ver `tools/goast/README.md`), dartast **1**.
- Ponteiros: `dart:ffi` não é usado (não existe no JS/Wasm). Identidade de tipo: uma classe Dart por tipo Go; testes de tipo sempre com `is T` (o `runtimeType` de coleções do core difere no JS).
- `golib_dart/fixed_types` e os ports de `net`/`net/netip`/`internal/poll` vieram do boilerplate do `dart IPFS`; correções feitas aqui ficam listadas em `golib_dart/README.md` para devolver à origem.
- Construção Go não coberta → `Unsupported` com posição; nunca emitir Dart aproximado em silêncio. Limites conhecidos ficam marcados ⚠️ em `docs/mapping-spec.md` e com `ponytail:` no código.
- Novo caso de teste = novo diretório em `tests/golden/` (pode ter vários `.go`; o e2e roda `go run` com todos); o e2e exige saída idêntica (em bytes) entre `go run` e o Dart gerado na VM, no JS (dart2js/Node) e no Wasm (dart2wasm/Node, via `tests/run_wasm.mjs`), e `dart analyze --fatal-infos` limpo.
- Runtime do `golib_dart` não usa API exclusiva de uma plataforma (ex. `ByteData.getUint64`, bitwise acima de 32 bits no JS); o que depende de plataforma vai por import condicional (`src/runtime/output.dart`).
- Código gerado em `out/` nunca é editado à mão — correções vão nas regras do `g2d`.

## Documentos vivos (atualizar no mesmo commit das mudanças)

- `docs/mapping-spec.md` — tabela de correspondência semântica Go↔Dart.
- `docs/stdlib-coverage.md` — inventário de símbolos stdlib usados × status do shim (gerado).
- `docs/reflection-report.md` — usos de `reflect` resolvidos × pendentes (gerado).
  (Os dois geradores ainda não existem; os dados brutos já saem em `stdlibUsage`/`reflectUsage` do goast.)
- Este `AGENTS.md` — atualizar quando arquitetura ou convenções mudarem.

## Milestones

Status: M0 ✅ · M1 ✅ · M2 em andamento (✅ inicialização de pacote/`init`, `switch` com break/fallthrough; falta import entre pacotes do grafo, `goto`, method values/expressions, structs anônimas) · M3 ✅ no escopo de pacote único (structs por valor, slices, maps, ponteiros, defer/recover, tipos nomeados, interfaces, embedding, genéricos, arrays; ⚠️ interfaces entre pacotes dependem do M2). Detalhes em `docs/mapping-spec.md`.

M0 AGENTS.md · M1 fundação (dumpers + grafo + esqueleto g2d) · M2 MVP transpilador · M3 semântica avançada (interfaces, embedding, generics, ponteiros, defer) · M4 concorrência (async/await + Streams, `Chan<T>`) · M5 reflexão estática + shims stdlib · M6 grafo completo boxo + deps (cobertura ≥ 95% por etapa).
