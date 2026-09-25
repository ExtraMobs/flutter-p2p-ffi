# TODO — um artefato por problema

Backlog do desafio kubo/boxo. Cada problema pequeno é um arquivo isolado
nesta pasta; **o commit que resolve o problema apaga o arquivo** (a mensagem
de commit cita o nome). O histórico fica no git.

## Nome

`<prioridade>-<área>-<slug>.md` — `ls` já lista na ordem de ataque.

| Prioridade | Significado |
|---|---|
| `P0` | pré-requisito da auditoria do kubo/boxo ou de qualquer código multi-pacote |
| `P1` | construção/shim comum em código real |
| `P2` | raro, ou limite com contorno |

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
- Multi-pacote: módulo `go.mod` com os pacotes; hoje o dump precisa ser por
  import path dentro do módulo (ver `P0-infra-goast-padrao-windows`) e, para
  expor a camada abaixo do import, um plugin de sonda que qualifica os
  pacotes do módulo como `package:out/<import path>.dart`:

  ```python
  class ProbeImports(ImportTable):
      def qualify(self, pkg_path, name):
          if pkg_path and pkg_path.startswith("repro.local/"):
              if pkg_path == self.pkg.path:
                  return name
              prefix = pkg_path.rsplit("/", 1)[-1]
              self.used[prefix] = f"package:out/{pkg_path}.dart"
              return f"{prefix}.{name}"
          return super().qualify(pkg_path, name)

  class ProbePlugin(Plugin):
      def install(self, engine):
          engine.services.replace(ProbeImports(engine))

  Engine(pkg, plugins=[*DEFAULT_PLUGINS, ProbePlugin()]).emit_package()
  ```
- Limites decididos (ex.: `goto`, ordem de chaves por endereço) ficam em
  `docs/mapping-spec.md`, não aqui.
