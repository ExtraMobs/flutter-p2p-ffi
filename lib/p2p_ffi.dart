/// Kubo (IPFS in Go) in a separate process, the `p2p_host`, with Go's own
/// API in Dart.
///
/// This library is the entry point of the runtime: the service, its errors and
/// the handles. The Go API is generated from `go/gen/roots.txt` (the list of
/// what exists is in `API.md`), one library per Go package under
/// `package:p2p_ffi/go/`, at the package's path in its module
/// (`github.com/ipfs/kubo/repo/fsrepo` → `package:p2p_ffi/go/kubo/repo/fsrepo.dart`,
/// `github.com/ipfs/go-cid` → `package:p2p_ffi/go/cid.dart`). Each Go type
/// lives only in the library of its package. Start the service before using it:
///
/// ```dart
/// import 'package:p2p_ffi/go/context.dart' as context;
/// import 'package:p2p_ffi/go/kubo/core.dart' as core;
/// import 'package:p2p_ffi/go/kubo/core/node.dart' as node;
/// import 'package:p2p_ffi/go/kubo/repo/fsrepo.dart' as fsrepo;
/// import 'package:p2p_ffi/p2p_ffi.dart';
///
/// await P2pService.start();
/// final n = await core.newNode(context.background(), node.BuildCfg(repo: fsrepo.open(repo)));
/// ```
library;

export 'src/service.dart'
    show
        GoHandle,
        GoHandleUse,
        GoScope,
        P2pBackground,
        P2pBusy,
        GolangCanceledException,
        GolangDeadlineExceededException,
        GolangDeadlockException,
        GolangEofException,
        GolangException,
        GolangNotFoundException,
        P2pPlatform,
        P2pService,
        P2pServiceException,
        P2pStop,
        P2pStopHandler,
        P2pStopReason,
        GolangUnexpectedEofException,
        defaultHostPath,
        p2pShmLibraryPath,
        withGoScope;
export 'src/network.dart' show hasIpv6, isGlobalIpv6;
