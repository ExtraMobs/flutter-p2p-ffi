package main

import (
	"fmt"
	"go/types"
	"sort"
	"strings"
)

// pkgName: qualifica um tipo pelo nome curto do pacote (mfs.File).
func pkgName(p *types.Package) string { return p.Name() }

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
			case f.setter:
				dart = className(f.recv) + "." + dart + " ="
			case f.recv != nil:
				dart = className(f.recv) + "." + dart
			case isFactory(f):
				dart = "factory " + className(f.results[0])
			}
			mode := "síncrona"
			switch {
			case isConstObj(f.obj):
				mode = "const"
			case f.cast != nil:
				mode = "cast"
			case f.field:
				mode = "campo"
			case f.stream != nil:
				mode = "Stream"
			case f.async:
				mode = "Future"
			}
			doc := goDoc(f.obj)
			switch {
			case f.cast != nil:
				doc = types.TypeString(f.recv.t, pkgName) + " → x.(" + types.TypeString(f.cast.t, pkgName) + ")"
			case f.field:
				doc = "(" + types.TypeString(f.recv.t, pkgName) + ")." + f.obj.Name() + " " + types.TypeString(f.obj.Type(), pkgName)
			}
			fmt.Fprintf(&b, "| `%s` | `%s` | %s |\n", doc, dart, mode)
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

- Namespaces: cada módulo Go num namespace (` + "`kubo`, `boxo`, `ipld`, `multiformats`, `libp2p`, `car` (o `github.com/ipld/go-car/v2`), `go`" + `), com um arquivo ` + "`package:ipfs_ffi/<namespace>.dart`" + ` que exporta todas as libraries dele (` + "`import 'package:ipfs_ffi/kubo.dart' as kubo;`" + `); as libraries por pacote Go continuam embaixo. A tabela módulo → namespace fica em ` + "`go/gen/namespaces.go`" + `.
- ` + "`context`" + ` (` + "`package:ipfs_ffi/go/context.dart`" + `, à mão): ` + "`background`" + `, ` + "`withCancel`" + `, ` + "`withTimeout`" + `, ` + "`withDeadline`" + `; ` + "`CancelFunc`" + ` é chamável (` + "`cancel()`" + `).
- ` + "`config.Profiles`" + ` (à mão): ` + "`profiles[nome]!.transform(cfg)`" + `; no Go é um mapa de funções.
- ` + "`ipfs dag put`/`ipfs dag get`" + ` (` + "`dagPut`/`dagGet`" + ` em ` + "`package:ipfs_ffi/kubo/core/commands/dag.dart`" + `, porte à mão em ` + "`go/manual_dag.go`" + `): no kubo é o corpo dos comandos, não função de biblioteca; mesmos padrões do CLI (dag-json → dag-cbor, limite de 2 MiB), hash padrão ` + "`sha2-256`" + `.
- ` + "`ipfs dag export`/`ipfs dag import`" + ` (arquivos CAR; mesma library do ` + "`dagPut`/`dagGet`" + `, porte à mão em ` + "`go/manual_car.go`" + `): ` + "`dagExport`/`dagExportFile`" + ` (CARv1, ` + "`localOnly`" + ` = ` + "`--local-only`" + `) e ` + "`dagImport`/`dagImportFiles`" + ` (CARv1/v2, ` + "`pinRoots`" + ` = ` + "`--pin-roots`" + `, devolve raízes e estatísticas); recebem o ` + "`IpfsNode`" + `, como o comando. Sem barra de progresso nem fast-provide do DAG inteiro; a raiz é anunciada pelo ` + "`Provide`" + ` da CoreAPI.
- Pubsub: o nó precisa de ` + "`node.BuildCfg(extraOpts: {'pubsub': true})`" + ` (o ` + "`Pubsub.Enabled`" + ` do daemon); ` + "`sub.next(ctx)`" + ` entrega uma mensagem por vez (o exemplo 08 a transforma em ` + "`Stream`" + `).
- Handle concreto que implementa uma interface exposta estende a classe dela (` + "`merkledag.RawNode`/`ProtoNode` → `Node`" + `), para valer onde o Go aceita a interface; struct que embute interface é handle, não DTO.
- Mapa com chave tipo-valor (` + "`map[peer.ID][]Multiaddr`" + `) vira ` + "`Map<Id, List<Multiaddr>>`" + `; com chave inteira (` + "`map[multicodec.Code]uint64`" + `), ` + "`Map<int, int>`" + `.
- Struct de campos exportados que é objeto (` + "`linking.LinkSystem`" + `, tabela ` + "`handleTypes`" + `) é handle; o handle de struct devolvida por valor guarda o ponteiro (vale como ` + "`T`" + ` e ` + "`*T`" + `).
- Método de DTO (` + "`car.Header.hasIndex`" + `, ` + "`cid.Prefix.sum`" + `): o receptor vai por valor; o que o método altera nele não volta.
- Interface só de getters (instantâneo, ` + "`blocks.Block`" + `) em parâmetro: o Dart monta a classe (` + "`Block(cid: c, rawData: d)`" + `) e o Go recebe uma struct que devolve esses valores.
- Canal ` + "`chan<- T`" + ` passado numa opção (` + "`options.Unixfs.Events`" + `) vira ` + "`StreamSink<T>`" + ` (` + "`options.unixfs.events(controller.sink)`" + `); o tipo real dos itens de ` + "`chan<- any`" + ` vem da tabela ` + "`chanElem`" + ` do gerador (` + "`AddEvent`" + `). Como o ` + "`ipfs add`" + `, o canal é fechado quando a chamada volta: todos os eventos chegam e o sink fecha antes do ` + "`Future`" + ` completar.
- Variável de pacote vira getter; tipo função nomeado (` + "`libp2p.RoutingOption`" + `) é handle opaco, criado só no Go.
- Métodos e funções com ` + "`context.Context`" + ` são assíncronos (` + "`Future`" + `); canais viram ` + "`Stream`" + `; ` + "`(T, error)`" + ` vira ` + "`T`" + ` com ` + "`IpfsException`" + `.
- Variádicos viram ` + "`List`" + ` opcional; opções funcionais espelham as variáveis do pacote (` + "`options.unixfs.pin(true, '')`" + `).
- ` + "`NewX`" + ` síncrono que devolve o handle ` + "`X`" + ` do mesmo pacote vira ` + "`factory X(...)`" + ` (um DTO não: ` + "`car.newHeader`" + ` é função).
- ` + "`io.Writer`" + ` em parâmetro é ` + "`GoHandle?`" + `: um objeto do Go que o implementa (` + "`os.File`" + `, ` + "`bytes.Buffer`" + `); null = ` + "`io.Discard`" + `.
- ` + "`fsrepo.Open`" + `: o host limpa o caminho (` + "`repoPath`" + `, a forma que o ` + "`Repo.Path()`" + ` devolve) antes de abrir, para os comandos de config, que reabrem o repo pelo ` + "`Path()`" + `, reaproveitarem o repo aberto (o ` + "`fsrepo`" + ` guarda o aberto pela string crua).
- Inteiros ` + "`uint64`" + ` vão com os mesmos 64 bits num ` + "`int`" + ` do Dart (como o ` + "`Uint64List`" + `): de 2^63 para cima saem negativos; ` + "`BigInt.from(v).toUnsigned(64)`" + ` os lê sem sinal (a doc de cada campo avisa).
- Interface de E/S em parâmetro (` + "`io.Reader`, `io.ReaderAt`, `io.ReadSeeker`, `car.SectionReader`" + `...) aceita ` + "`Uint8List`" + ` (quando um ` + "`bytes.Reader`" + ` a implementa) ou um handle que a implementa (o ` + "`files.File`" + ` do kubo, ` + "`os.open`" + `).
- Tipos-valor (CID, path, peer ID, multiaddr) guardam a string; a validação acontece no Go, quando atravessam.
- ` + "`config.Config`" + ` guarda o JSON do kubo (o mesmo do arquivo ` + "`config`" + ` do repo) em ` + "`json`" + `.
- Resultado ` + "`nil`" + ` do Go onde o Dart espera um objeto vira ` + "`IpfsException`" + `.
- O kubo roda no ` + "`ipfs_host`" + `, noutro processo (` + "`IpfsService.start()`" + ` antes da API; protocolo no ` + "`WIRE.md`" + `): um panic do Go derruba só o serviço, e as chamadas pendentes falham com ` + "`IpfsServiceException`" + `.
- Handles são soltos pelo ` + "`Finalizer`" + ` do Dart (em lote, pela função Free do serviço) e só valem no serviço em que nasceram; recursos do Go (nó, repo) continuam exigindo o ` + "`Close`" + ` do próprio Go.
`)
	return []byte(b.String())
}
