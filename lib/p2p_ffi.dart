/// Kubo (IPFS in Go) in a separate process, the `p2p_host`, with Go's own
/// API in Dart.
///
/// This library is the only import: the runtime (the service, its errors and
/// the handles) and the Go API, generated from `go/gen/roots.txt` (the list of
/// what exists is in `API.md`). A Go package's functions, constants and
/// variables are reached through `Go`, one getter per segment of the
/// package's path in its module (`github.com/ipfs/kubo/repo/fsrepo` →
/// `Go.kubo.repo.fsrepo`, `github.com/ipfs/go-cid` → `Go.cid`); its types are
/// top-level classes named after that path (`KuboCoreIpfsNode`,
/// `KuboCoreNodeBuildCfg`, `cid.Cid` → `Cid`). Start the service before using
/// it:
///
/// ```dart
/// import 'package:p2p_ffi/p2p_ffi.dart';
///
/// await P2pService.start();
/// final n = await Go.kubo.core.newNode(Go.context.background(),
///     KuboCoreNodeBuildCfg(repo: Go.kubo.repo.fsrepo.open(repo)));
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
export 'src/go.dart';
export 'src/io_stream.dart' show readerStream;
export 'src/network.dart' show hasIpv6, isGlobalIpv6;
