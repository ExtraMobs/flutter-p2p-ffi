/// Kubo (IPFS in Go) in a separate process, the `p2p_host`, with Go's own
/// API in Dart.
///
/// This library is the only import: the runtime (the service, its errors and
/// the handles) and the Go API, generated from `go/gen/roots.txt` (the list of
/// what exists is in `API.md`). A Go package's functions, constants and
/// variables are reached through the constant `go`, then one getter per segment
/// of the package's path after the host of its URL
/// (`github.com/ipfs/kubo/repo/fsrepo` → `go.ipfs.kubo.repo.fsrepo`,
/// `github.com/ipfs/go-cid` → `go.ipfs.cid`); its types are top-level classes
/// named after that path without the author (`KuboCoreIpfsNode`,
/// `KuboCoreNodeBuildCfg`, `cid.Cid` → `Cid`). Start the service before using
/// it:
///
/// ```dart
/// import 'package:p2p_ffi/p2p_ffi.dart';
///
/// await P2pService.start();
/// final n = await go.ipfs.kubo.core.newNode(go.context.background(),
///     KuboCoreNodeBuildCfg(repo: go.ipfs.kubo.repo.fsrepo.open(repo)));
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
        GolangPanicException,
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
export 'src/go.dart';
export 'src/io_stream.dart' show readerStream;
export 'src/network.dart' show hasIpv6, isGlobalIpv6;
