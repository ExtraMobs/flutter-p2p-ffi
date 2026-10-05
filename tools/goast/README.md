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

## Schema do JSON (`schemaVersion: 9`)

```jsonc
{
  "schemaVersion": 9,
  "tool": "goast",
  "goVersion": "go1.26.5",
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
  "conversions": [ { "type": 4, "iface": 7 } ],            // tipo concreto → interface, no pacote
  "asserts": [ 9 ],                                        // alvos dinâmicos (assertion, type switch, interface → interface)
  "initOrder": [ ["a.go:120", "a.go:123"], ... ],          // types.Info.InitOrder: decl das variáveis por inicializador
  "stdlibUsage":  [ "fmt.Println", ... ],   // ordenado alfabeticamente
  "reflectUsage": [ { "pos": "arquivo.go:linha:coluna", "expr": "reflect.ValueOf(x)" } ],
  "otherFiles": [ "asm_amd64.s" ],          // omitido se vazio: não-Go do contexto de build (.s = assembly)
  "module": { "path": "exemplo.com/mod", "version": "v1.2.3" }  // omitido no modo loose; version vazia no módulo principal
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

`$obj`: `{name, kind, def?, type?, decl?, pkg?, top?, fold?, embedded?, value?}`

- `kind` ∈ `func | method | var | field | const | type | label | package | builtin | nil`;
- `decl`: `"arquivo:offset"` da declaração — com `pkg`, identifica o objeto;
- `def: true` na ocorrência que define; `top: true` para objetos de escopo de pacote;
- `fold: true` no objeto exportado de escopo de pacote que tem outro exportado igual a ele sem
  diferenciar caixa no mesmo pacote (`BOOL` e `Bool`: o g2d os distingue);
- `pkg`: import path do pacote do objeto; para `kind: package`, o pacote importado.

Valor constante: `{"kind": "string|bool|int|float", "value"}` (string já
decodificada; int em decimal exato; float em `%g` float64) ou
`{"kind": "complex", "real", "imag"}`. String que não é UTF-8 válido traz
também `"bytes": [...]` (o JSON trocaria os bytes inválidos por U+FFFD).

`implements`: para cada tipo nomeado de nível de pacote, as interfaces com
métodos (e no máximo `comparable` embutido; uniões não) que `T` ou `*T`
satisfaz (`types.Implements`): as nomeadas (do
pacote, dos imports diretos e `error`), as instâncias de interfaces genéricas
dos mesmos escopos cujos argumentos saem dos métodos de `T` (`Key[k8]` para
`Xor(k8) k8`) e as anônimas usadas no pacote (literais `interface{...}` com
métodos fora de uma declaração de tipo, em ordem do fonte). Tipo genérico
entra instanciado com os próprios parâmetros (`KeyList[K]` → `sort.Interface`).

`conversions`: os pares (tipo concreto, interface) das conversões que
acontecem no pacote (`conversions.go`, `conversions_sites.go`): atribuição, `var x I = v`, argumento
(variádico inclusive), retorno, elemento de literal composto (campo, slice,
array, chave e valor de map), `append`, envio em canal, chave de índice de
map, `==`/`!=` com interface, conversão `I(x)` e argumento de tipo de
restrição com métodos (`F[T]` com `[X I]`). O tipo é nomeado ou `*nomeado`
não-interface; a interface pode ser vazia (`any`: o tipo "escapa"). Um par
por identidade, na ordem do fonte. `asserts`: as interfaces com métodos que
o pacote testa no runtime (type assertion `x.(I)`, `case I:` de type switch
e a atribuição de uma interface a outra não idêntica). O g2d junta os dois
do grafo inteiro para declarar `implements` de interfaces que o pacote do
tipo não enxerga (D8, `g2d/analysis/ifacecross.py`).

Histórico: v2 moveu os tipos para dentro da AST; v3 adicionou `bytes`; v4
adicionou `methods` e `implements`; v5 adicionou `initOrder`; v6 incluiu as
interfaces anônimas no `implements`; v7 adicionou `otherFiles` e
`module`, o campo `valueEnd` do `BasicLit` (go/ast 1.26) e corrigiu o `decl` de
objetos importados no modo loose (antes caía num arquivo errado); v8 adicionou `fold` e
incluiu tipos genéricos e instâncias de interfaces genéricas no `implements`; v9
adicionou `pkg` aos campos de struct e métodos de interface não exportados; v10
adicionou `conversions` e `asserts`.

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
| `struct` | `fields: [{name, type, embedded, tag, pkg?}]` (`pkg` só no campo não exportado: entra na identidade do tipo) |
| `interface` | `methods: [{name, type, pkg?}]` (conjunto completo; `pkg` só no não exportado), `embeddeds` |
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
