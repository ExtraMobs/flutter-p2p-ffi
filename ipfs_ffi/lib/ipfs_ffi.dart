/// Kubo (IPFS in Go) in a separate process, the `ipfs_host`, with Go's own
/// API in Dart.
///
/// The API is generated from `go/gen/roots.txt` (the list of what exists is in
/// `API.md`) and grouped in namespaces, one per Go module: `kubo`, `boxo`,
/// `car`, `ipld`, `multiformats`, `libp2p` and `go` (the Go standard library
/// pieces it uses). Import a namespace with a prefix, or one Go package at a
/// time from under it (`package:ipfs_ffi/kubo/repo/fsrepo.dart`). Start the
/// service before using it:
///
/// ```dart
/// import 'package:ipfs_ffi/go.dart' as go;
/// import 'package:ipfs_ffi/ipfs_ffi.dart';
/// import 'package:ipfs_ffi/kubo.dart' as kubo;
///
/// await IpfsService.start();
/// final node = await kubo.newNode(go.background(), kubo.BuildCfg(repo: kubo.open(repo)));
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
