package main

import (
	"reflect"
	"testing"
)

func TestPublicNames(t *testing.T) {
	src := []byte(`library;

import 'package:ipfs_ffi/src/runtime.dart';

/// Go: x.
class File extends GoHandle {
  File.$h(super.$h);
}

final class _Api {
  const _Api._();
}

const tFile = 0;
const api = _Api._();
FsNode lookup(Root r, String path) {
Future<void> mv(
RoutingOption get dhtOption {
Option withMaxLinks(int n) => Option.$(1, (w) => w..i64(n));
Future<$cid.Cid> dagPut(
`)
	want := []string{"File", "tFile", "api", "lookup", "mv", "dhtOption", "withMaxLinks", "dagPut"}
	if got := publicNames(src); !reflect.DeepEqual(got, want) {
		t.Errorf("publicNames = %v, quero %v", got, want)
	}
}
