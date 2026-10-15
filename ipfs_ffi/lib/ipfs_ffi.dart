/// Kubo (IPFS em Go) dentro do processo Dart, por dart:ffi.
///
/// A API é a do próprio Go, uma library por pacote (sem o prefixo
/// `github.com/<org>/`), gerada a partir de `go/gen/roots.txt`; a lista do
/// que existe está no `API.md`. Importe cada pacote com prefixo, como no Go:
///
/// ```dart
/// import 'package:ipfs_ffi/context.dart' as context;
/// import 'package:ipfs_ffi/kubo/core.dart' as core;
/// ```
library;

export 'src/network.dart' show hasIpv6, isGlobalIpv6;
export 'src/runtime.dart' show IpfsException, ipfsLibraryPath;
