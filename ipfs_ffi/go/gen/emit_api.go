package main

import (
	"fmt"
	"sort"
	"strings"
)

// emitAPI: checklist Go → Dart por pacote, com omissões e motivos.
func emitAPI(m *model, fns []*fn) []byte {
	byPkg := map[string][]*fn{}
	for _, f := range fns {
		byPkg[f.pkg.Path()] = append(byPkg[f.pkg.Path()], f)
	}
	var b strings.Builder
	b.WriteString("# API do ipfs_ffi\n\nGerado por `go run ./gen` (na pasta `go/`) a partir de `go/gen/roots.txt`; não editar.\n")
	b.WriteString("Cada linha é um símbolo Go exposto e onde ele está no Dart.\n")
	for _, pkg := range sortedKeys(byPkg) {
		fmt.Fprintf(&b, "\n## `%s` → `package:ipfs_ffi/%s`\n\n| Go | Dart | Modo |\n|---|---|---|\n", pkg, dartPath(pkg))
		var omitted []string
		for _, f := range byPkg[pkg] {
			if f.why != "" {
				omitted = append(omitted, fmt.Sprintf("- `%s`: %s", goDoc(f.obj), f.why))
				continue
			}
			dart := memberName(f.obj.Name())
			switch {
			case f.recv != nil:
				dart = className(f.recv) + "." + dart
			case isFactory(f):
				dart = "factory " + className(f.results[0])
			}
			mode := "síncrona"
			switch {
			case f.stream != nil:
				mode = "Stream"
			case f.async:
				mode = "Future"
			}
			fmt.Fprintf(&b, "| `%s` | `%s` | %s |\n", goDoc(f.obj), dart, mode)
		}
		if len(omitted) > 0 {
			b.WriteString("\nOmitidos:\n\n" + strings.Join(omitted, "\n") + "\n")
		}
	}

	var fields, opts []string
	for _, key := range sortedKeys(m.types) {
		t := m.types[key]
		if t.ptr {
			continue
		}
		for _, f := range t.fields {
			if t.k == kDTO && f.skipped != "" {
				fields = append(fields, fmt.Sprintf("- `%s.%s`: %s", key, f.name, f.skipped))
			}
		}
		if t.k == kOpts {
			for _, c := range t.ctors {
				if ok, why := okOptCtor(c); !ok {
					opts = append(opts, fmt.Sprintf("- `%s.%s` (%s): %s", t.named.Obj().Pkg().Name(), strings.Join(c.path, "."), t.named.Obj().Name(), why))
				}
			}
		}
	}
	sort.Strings(opts)
	if len(fields) > 0 {
		b.WriteString("\n## Campos de struct que não atravessam\n\n" + strings.Join(fields, "\n") + "\n")
	}
	if len(opts) > 0 {
		b.WriteString("\n## Construtores de opção omitidos\n\n" + strings.Join(opts, "\n") + "\n")
	}
	b.WriteString(`
## Adaptações (regras do gerador e código à mão)

- ` + "`context`" + ` (` + "`package:ipfs_ffi/context.dart`" + `, à mão): ` + "`background`" + `, ` + "`withCancel`" + `, ` + "`withTimeout`" + `, ` + "`withDeadline`" + `; ` + "`CancelFunc`" + ` é chamável (` + "`cancel()`" + `).
- ` + "`config.Profiles`" + ` (à mão): ` + "`profiles[nome]!.transform(cfg)`" + `; no Go é um mapa de funções.
- Métodos e funções com ` + "`context.Context`" + ` são assíncronos (` + "`Future`" + `); canais viram ` + "`Stream`" + `; ` + "`(T, error)`" + ` vira ` + "`T`" + ` com ` + "`IpfsException`" + `.
- Variádicos viram ` + "`List`" + ` opcional; opções funcionais espelham as variáveis do pacote (` + "`options.unixfs.pin(true, '')`" + `).
- ` + "`NewX`" + ` síncrono que devolve ` + "`X`" + ` do mesmo pacote vira ` + "`factory X(...)`" + `.
- ` + "`io.Writer`" + ` em parâmetro não aparece no Dart: o Go usa ` + "`io.Discard`" + `.
- ` + "`io.Reader`" + ` em parâmetro aceita ` + "`Uint8List`" + ` ou um handle de leitor (ex. o ` + "`files.File`" + ` devolvido pelo kubo).
- Tipos-valor (CID, path, peer ID, multiaddr) guardam a string; a validação acontece no Go, quando atravessam.
- ` + "`config.Config`" + ` guarda o JSON do kubo (o mesmo do arquivo ` + "`config`" + ` do repo) em ` + "`json`" + `.
- Resultado ` + "`nil`" + ` do Go onde o Dart espera um objeto vira ` + "`IpfsException`" + `.
- Handles são soltos por ` + "`NativeFinalizer`" + `; recursos do Go (nó, repo) continuam exigindo o ` + "`Close`" + ` do próprio Go.
`)
	return []byte(b.String())
}
