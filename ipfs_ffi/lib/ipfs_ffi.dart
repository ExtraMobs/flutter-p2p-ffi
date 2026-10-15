/// Kubo (IPFS in Go) in a separate process, the `ipfs_host`, with Go's own
/// API in Dart.
///
/// The API is one library per package (without the `github.com/<org>/`
/// prefix), generated from `go/gen/roots.txt`; the list of what exists is in
/// `API.md`. Start the service before using it and import each package with a
/// prefix, as in Go:
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
        IpfsBackground,
        IpfsException,
        IpfsPlatform,
        IpfsService,
        IpfsServiceException,
        IpfsStop,
        IpfsStopHandler,
        IpfsStopReason,
        defaultHostPath,
        ipfsShmLibraryPath;
export 'src/network.dart' show hasIpv6, isGlobalIpv6;
