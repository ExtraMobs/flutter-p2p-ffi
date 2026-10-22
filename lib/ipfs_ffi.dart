/// Kubo (IPFS in Go) in a separate process, the `ipfs_host`, with Go's own
/// API in Dart.
///
/// This library is the entry point of the runtime: the service, its errors and
/// the handles. The Go API is generated from `go/gen/roots.txt` (the list of
/// what exists is in `API.md`), one library per Go package under
/// `package:ipfs_ffi/go/`, at the package's path in its module
/// (`github.com/ipfs/kubo/repo/fsrepo` → `package:ipfs_ffi/go/kubo/repo/fsrepo.dart`,
/// `github.com/ipfs/go-cid` → `package:ipfs_ffi/go/cid.dart`). Each Go type
/// lives only in the library of its package. Start the service before using it:
///
/// ```dart
/// import 'package:ipfs_ffi/go/context.dart' as context;
/// import 'package:ipfs_ffi/go/kubo/core.dart' as core;
/// import 'package:ipfs_ffi/go/kubo/core/node.dart' as node;
/// import 'package:ipfs_ffi/go/kubo/repo/fsrepo.dart' as fsrepo;
/// import 'package:ipfs_ffi/ipfs_ffi.dart';
///
/// await IpfsService.start();
/// final n = await core.newNode(context.background(), node.BuildCfg(repo: fsrepo.open(repo)));
/// ```
library;

export 'src/service.dart'
    show
        GoHandle,
        GoHandleUse,
        GoScope,
        IpfsBackground,
        IpfsBusy,
        IpfsCanceled,
        IpfsDeadlineExceeded,
        IpfsDeadlockException,
        IpfsEof,
        IpfsException,
        IpfsNotFound,
        IpfsPlatform,
        IpfsService,
        IpfsServiceException,
        IpfsStop,
        IpfsStopHandler,
        IpfsStopReason,
        IpfsUnexpectedEof,
        defaultHostPath,
        ipfsShmLibraryPath,
        withGoScope;
export 'src/network.dart' show hasIpv6, isGlobalIpv6;
