/// Port of `golang.org/x/time/rate` (v0.15.0, pinned in
/// doc/transpilation/UPSTREAM_LOCK.md as `golang-x-time` /
/// `812b343c8714c317b0dad633efa6d103e554c006`).
library;

export 'src/rate.dart'
    show
        Limit,
        Limiter,
        Reservation,
        WaitBurstExceededException,
        WaitCanceledException,
        WaitDeadlineExceededException,
        every,
        infDuration;
export 'src/sometimes.dart' show Sometimes;
