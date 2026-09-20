/// Port of `github.com/pion/transport/v3` (revision fixed in
/// doc/transpilation/UPSTREAM_LOCK.md).
///
/// Only the `deadline` subpackage is ported: it is the sole subpackage of
/// this module that `transpiled_pion_sctp` (the real consumer, per
/// `association.go:20` and `stream.go:16` of the upstream `pion/sctp`)
/// imports. `vnet` (a network simulator for pion's own tests) and every
/// other subpackage of `pion/transport/v3` are out of scope.
library;

export 'src/deadline.dart' show Deadline, DeadlineExceededException;
