package main

import "runtime"

// schemaVersion do JSON emitido: o g2d (g2d/model.py) recusa dump de outra
// versão. Mudou o formato, mude aqui e lá.
const schemaVersion = 8

// DumpDoc é a raiz do JSON emitido pelo goast.
type DumpDoc struct {
	SchemaVersion int            `json:"schemaVersion"`
	Tool          string         `json:"tool"`
	GoVersion     string         `json:"goVersion"`
	Packages      []*PackageDump `json:"packages"`
}

// PackageDump é o dump de um único pacote Go (a unidade de trabalho).
type PackageDump struct {
	Path         string       `json:"path"`
	Name         string       `json:"name"`
	Files        []*FileDump  `json:"files"`
	Imports      []ImportDump `json:"imports"`
	TypeTable    []jobject    `json:"typeTable"`
	Implements   []jobject    `json:"implements"`
	InitOrder    [][]string   `json:"initOrder"`
	StdlibUsage  []string     `json:"stdlibUsage"`
	ReflectUsage []ReflectUse `json:"reflectUsage"`
	// OtherFiles: arquivos não-Go do pacote no contexto de build (.s =
	// assembly: funções sem corpo em Go, pedem substituição).
	OtherFiles []string    `json:"otherFiles,omitempty"`
	Module     *ModuleDump `json:"module,omitempty"`
}

// ModuleDump identifica o módulo Go do pacote (nil no modo loose e na stdlib).
type ModuleDump struct {
	Path    string `json:"path"`
	Version string `json:"version,omitempty"` // vazio no módulo principal
}

// FileDump associa o caminho do arquivo-fonte à sua AST.
type FileDump struct {
	Path string `json:"path"`
	AST  any    `json:"ast"`
}

// ImportDump registra um import do pacote.
type ImportDump struct {
	Path string `json:"path"`
	Name string `json:"name"`
}

// ReflectUse registra um ponto de uso do pacote reflect.
type ReflectUse struct {
	Pos  string `json:"pos"` // "file:line:column"
	Expr string `json:"expr"`
}

func newDoc() *DumpDoc {
	return &DumpDoc{SchemaVersion: schemaVersion, Tool: "goast", GoVersion: runtime.Version()}
}
