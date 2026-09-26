# TODO — um artefato por problema

Backlog do desafio kubo/boxo. Cada problema pequeno é um arquivo isolado
nesta pasta; **o commit que resolve o problema apaga o arquivo** (a mensagem
de commit cita o nome). O histórico fica no git.

## Nome

`<prioridade>-<área>-<slug>.md` — `ls` já lista na ordem de ataque.

A prioridade vem de `docs/audit.md` (grafo real do kubo), coluna **na fronteira**
(pacotes com as deps todas verdes que o problema bloqueia):

| Prioridade | Significado |
|---|---|
| `P0` | bloqueia ≥ 10 pacotes da fronteira, ou é pré-requisito de infraestrutura |
| `P1` | bloqueia pacotes da fronteira ou ≥ 5 pacotes do grafo; Dart inválido em silêncio |
| `P2` | raro no grafo (< 5 pacotes, fora da fronteira), ou limite com contorno |

Reclassificar quando o audit regerado mudar a coluna. Shim de pacote da stdlib
abaixo de P0 não precisa de artefato: a fila dele é `docs/stdlib-coverage.md`
com o ranking do `docs/audit.md`.

Áreas: `construcao` (Go → Dart no g2d), `shim` (stdlib em `golib_dart`),
`runtime` (classes de `golib_dart`), `design` (decisão de mapeamento),
`infra` (ferramentas, testes, pipeline), `substituicao` (pacote com
cgo/asm/unsafe/syscall), `docs`.

## Conteúdo

1. **Problema** — o que falta ou está errado, em uma ou duas frases.
2. **Prova** — obrigatória e **real**: o repro Go mínimo, o comando executado
   e a saída colada (mensagem `não suportado`, erro do `dart analyze`,
   divergência `go run` × `dart run`, ou o estado verificável para infra).
   Candidato sem prova reproduzida não vira artefato.
3. **Critério de pronto** — em geral: repro vira fixture em `tests/golden/`
   (multi-pacote quando for o caso), e2e idêntico em VM × JS × Wasm,
   `dart analyze --fatal-infos` limpo, docs vivas atualizadas.
4. **Depende de** — outros artefatos.
5. **Notas** — opcional.

## Como provar

- Pacote único: `goast dump <dir>` → `python -m g2d transpile` → se gerar
  Dart, `dart analyze` e `go run` × `dart run` (VM e JS).
- Multi-pacote: módulo `go.mod` com os pacotes; `goast dump -C <módulo> ./...
  -o dump.json` → `python -m g2d transpile dump.json -o out` (os pacotes do
  grafo viram `package:out/<import path>.dart`) → `dart analyze` e
  `go run ./cmd` × `dart run out/lib/<módulo>/cmd.dart`.
- Grafo real: `python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo`
  e a linha do código em `docs/audit.md` (ocorrências, pacotes, exemplo com
  posição) são prova; o repro mínimo sai do exemplo.
- Limites decididos (ex.: `goto`, ordem de chaves por endereço) ficam em
  `docs/mapping-spec.md`, não aqui.
