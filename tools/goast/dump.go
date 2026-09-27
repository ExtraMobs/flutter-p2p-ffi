package main

// Dump carrega os pacotes indicados pelos alvos e produz o documento JSON.
// Com dir, os alvos são padrões resolvidos no módulo de dir; sem dir, um
// alvo único pode ser um diretório (ver resolveTarget).
func Dump(dir string, targets ...string) (*DumpDoc, error) {
	doc := newDoc()
	err := DumpEach(dir, targets, func(p *PackageDump) error {
		doc.Packages = append(doc.Packages, p)
		return nil
	})
	if err != nil {
		return nil, err
	}
	return doc, nil
}

// DumpEach é o Dump sem acumular: entrega cada pacote em ordem de import
// path e libera a AST dele. O grafo inteiro do corpus não cabe na memória
// como um documento só.
func DumpEach(dir string, targets []string, emit func(*PackageDump) error) error {
	fset, pkgs, err := load(dir, targets)
	if err != nil {
		return err
	}
	for _, p := range pkgs {
		if err := emit(dumpPackage(fset, p)); err != nil {
			return err
		}
		p.Syntax, p.TypesInfo = nil, nil
	}
	return nil
}
