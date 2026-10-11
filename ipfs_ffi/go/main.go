// Package main é o kubo compilado como biblioteca C (-buildmode=c-shared;
// ver tool/build.dart) para o Dart chamar por dart:ffi. A API exposta é
// gerada por gen/ a partir de gen/roots.txt (zz_generated.go) e despachada
// pelo IpfsCall de runtime.go.
package main

/*
#include <stdlib.h>
*/
import "C"

import "unsafe"

// GoMalloc existe para o Dart alocar com o mesmo allocator de GoFree
// (no Windows não há DynamicLibrary.process()).
//
//export GoMalloc
func GoMalloc(n C.size_t) unsafe.Pointer { return C.malloc(n) }

//export GoFree
func GoFree(p unsafe.Pointer) { C.free(p) }

func main() {}
