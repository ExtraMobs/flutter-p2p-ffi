# goast

Dumper de AST Go tipada → JSON. É a única etapa do pipeline que toca
código-fonte Go; o transpilador Python (`g2d`) consome apenas este JSON.

## Uso

```bash
goast dump <alvo> [-o out.json]
```

- `<alvo>`: diretório de pacote Go (`./foo`, `../bar`) ou padrão de pacote
  (`./...` para o módulo inteiro, ou um import path).
- Sem `-o`, escreve em stdout (sempre com indentação de 2 espaços).

## Carregamento

Usa **`golang.org/x/tools/go/packages`** (a rede permitiu o download).
Isso cobre qualquer pacote Go, incluindo dependências externas resolvidas
via `go list`. Se o alvo não pertence a um módulo (ex. fixtures em
`tests/golden/`), cai no fallback `load_loose.go` (`go/parser` + `go/types` +
`importer.Default()`, só imports da stdlib).

## Schema do JSON (`schemaVersion: 5`)

```jsonc
{
  "schemaVersion": 5,
  "tool": "goast",
  "goVersion": "go1.25.7",
  "packages": [ ... ]  // ordenados por import path (determinístico)
}
```

Cada pacote:

```jsonc
{
  "path": "exemplo.com/mod/pkg",
  "name": "pkg",
  "files": [ { "path": "arquivo.go", "ast": { "node": "File", ... } } ],
  "imports": [ { "path": "fmt", "name": "fmt" } ],
  "typeTable": [ { "kind": "basic", "name": "int" }, ... ],
  "implements": [ { "type": 3, "interfaces": [7, 9] } ],  // tipo nomeado → interfaces satisfeitas
  "initOrder": [ ["a.go:120", "a.go:123"], ... ],          // types.Info.InitOrder: decl das variáveis por inicializador
  "stdlibUsage":  [ "fmt.Println", ... ],   // ordenado alfabeticamente
  "reflectUsage": [ { "pos": "arquivo.go:linha:coluna", "expr": "reflect.ValueOf(x)" } ]
}
```

### Nós da AST

A serialização é genérica (reflection sobre `go/ast`), sem enumeração manual
de tipos de nó. Cada nó é um objeto `{"node": "<NomeDoTipo>", "<campo>": ...}`
com os campos na ordem de declaração da struct (primeira letra minúscula).
Casos especiais:

- `token.Pos` → `{"file", "line", "column", "offset"}` (posição inválida → `null`);
  `file` é só o nome base (todo pacote vive num diretório);
- `token.Token` → string (`"func"`, `"+"`, ...);
- ponteiros/interfaces nil → `null`;
- `*ast.Object` → `{"node": "Object", "name", "kind"}` (não seguido, evita ciclos);
- `*ast.Scope` → `null` (idem).

### Anotações de tipo (inline, prefixo `$`)

A informação de `go/types` fica no próprio nó — sem mapas por posição (nós
aninhados compartilham offset inicial, ex. `g` e `g.Name`).

| Chave | Em | Conteúdo |
|---|---|---|
| `$type` | expressões | índice em `typeTable` |
| `$isType` | expressões | `true` se a expressão denota um tipo (ex. `int` em `int(x)`) |
| `$builtin` | expressões | `true` se denota um builtin (`len`, `append`, ...) |
| `$value` | expressões constantes | valor constante (abaixo) |
| `$obj` | `Ident` | objeto definido/usado (abaixo) |
| `$inst` | `Ident` | argumentos de tipo de uma instanciação de genérico (índices), de `types.Info.Instances` |
| `$sel` | `SelectorExpr` | `{kind: field\|method\|methodExpr, recv, index, indirect}` — `index` é o caminho pelos campos embutidos |

`$obj`: `{name, kind, def?, type?, decl?, pkg?, top?, embedded?, value?}`

- `kind` ∈ `func | method | var | field | const | type | label | package | builtin | nil`;
- `decl`: `"arquivo:offset"` da declaração — com `pkg`, identifica o objeto;
- `def: true` na ocorrência que define; `top: true` para objetos de escopo de pacote;
- `pkg`: import path do pacote do objeto; para `kind: package`, o pacote importado.

Valor constante: `{"kind": "string|bool|int|float", "value"}` (string já
decodificada; int em decimal exato; float em `%g` float64) ou
`{"kind": "complex", "real", "imag"}`. String que não é UTF-8 válido traz
também `"bytes": [...]` (o JSON trocaria os bytes inválidos por U+FFFD).

`implements`: para cada tipo nomeado de nível de pacote, as interfaces
nomeadas com métodos (do pacote, dos imports diretos e `error`) que `T` ou
`*T` satisfaz (`types.Implements`).

Histórico: v2 moveu os tipos para dentro da AST; v3 adicionou `bytes`; v4
adicionou `methods` e `implements`; v5 adicionou `initOrder`.

### Tabela de tipos

Descritores estruturados, deduplicados por `types.Identical`, índices na
ordem de travessia. Aliases são resolvidos. Tipos nomeados são referenciados
por índice (sem ciclos).

| `kind` | Campos |
|---|---|
| `basic` | `name` (`int`, `string`, `untyped int`, ...) |
| `named` | `pkg` (`""` = universo: `error`, `comparable`), `name`, `args?`, `underlying`, `methods?` (não-interface: method set de `*T` — `{name, type, index, ptr}`; `index` = caminho de embedding; `ptr` = só em `*T`) |
| `pointer` / `slice` | `elem` |
| `array` | `len`, `elem` |
| `map` | `key`, `elem` |
| `chan` | `dir` (`both\|send\|recv`), `elem` |
| `struct` | `fields: [{name, type, embedded, tag}]` |
| `interface` | `methods: [{name, type}]` (conjunto completo), `embeddeds` |
| `func` | `params`, `results`, `variadic` |
| `tuple` | `elems` |
| `typeparam` | `name`, `index`, `constraint` |
| `union` | `terms: [{tilde, type}]` |

### Convenções

- Tipos nomeados locais a funções com mesmo nome são distintos (identidade, não nome).
- Stdlib = import path cujo primeiro segmento não contém ponto; símbolos do
  próprio pacote nunca contam.
- Determinismo: pacotes por import path, `stdlibUsage`/`reflectUsage`
  ordenados, arquivos na ordem do loader, tabela de tipos na ordem de
  travessia. Sem timestamps nem caminhos absolutos.
