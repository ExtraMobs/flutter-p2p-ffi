/// Kubo (IPFS em Go) num processo separado, o `ipfs_host`, com a API do
/// próprio Go no Dart.
///
/// A API é uma library por pacote (sem o prefixo `github.com/<org>/`), gerada
/// a partir de `go/gen/roots.txt`; a lista do que existe está no `API.md`.
/// Inicie o serviço antes de usá-la e importe cada pacote com prefixo, como no
/// Go:
///
/// ```dart
/// import 'package:ipfs_ffi/context.dart' as context;
/// import 'package:ipfs_ffi/ipfs_ffi.dart';
/// import 'package:ipfs_ffi/kubo/core.dart' as core;
///
/// await IpfsService.start();
/// ```
library;

export 'service.dart'
    show
        IpfsException,
        IpfsService,
        IpfsServiceException,
        defaultHostPath,
        ipfsShmLibraryPath;
export 'src/network.dart' show hasIpv6, isGlobalIpv6;
