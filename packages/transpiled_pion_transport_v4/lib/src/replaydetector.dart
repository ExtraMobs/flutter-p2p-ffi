// ignore_for_file: library_prefixes
// Port of github.com/pion/transport/v4/replaydetector (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md): replaydetector.go, fixedbig.go.
//
// Both upstream files are ported into one Dart file because `fixedBigInt`
// (fixedbig.go:11) is an unexported Go type used only as private backing
// state of the two exported detectors in replaydetector.go; it has no
// exported Go counterpart, so it stays Dart-private (`_FixedBigInt`), and
// Dart's per-library privacy makes one file the simplest way to share it
// with the two detector classes without an extra library/part split.
import 'package:boilerplate/fixed_types/golang.dart' as Golang;

/// Sequence-number replay detector. Port of the `ReplayDetector` interface
/// (replaydetector.go:8-13).
abstract interface class ReplayDetector {
  /// Creates a detector that does not allow sequence-number wrapping; it can
  /// handle monotonically increasing sequence numbers up to a full 64-bit
  /// number. Suitable for DTLS replay protection. Port of `New`
  /// (replaydetector.go:32-38).
  factory ReplayDetector(int windowSize, Golang.Uint64 maxSeq) =
      _SlidingWindowDetector;

  /// Creates a detector that allows sequence-number wrapping. Suitable for
  /// short bit-width counters like SRTP and SRTCP. Port of `WithWrap`
  /// (replaydetector.go:73-79).
  factory ReplayDetector.withWrap(int windowSize, Golang.Uint64 maxSeq) =
      _WrappedSlidingWindowDetector;

  /// Returns a callback to call if the packet identified by [seq] should be
  /// accepted, or `null` if it must be rejected (already seen, too old, or
  /// beyond the configured maximum sequence number). Calling the returned
  /// callback marks the packet as received and returns whether it carries
  /// the newest observed sequence number so far.
  ///
  /// Port of `Check(seq uint64) (accept func() bool, ok bool)`. Go returns a
  /// `nop` sentinel function (replaydetector.go:17-19) alongside `ok=false`
  /// on rejection; that pair collapses here into a `null` return, since
  /// nothing in this module ever calls the rejection sentinel and `null`
  /// already conveys "not accepted" without an unused callable.
  bool Function()? check(Golang.Uint64 seq);
}

class _SlidingWindowDetector implements ReplayDetector {
  _SlidingWindowDetector(this._windowSize, this._maxSeq)
    : _mask = _FixedBigInt(_windowSize);

  Golang.Uint64 _latestSeq = Golang.Uint64(0);
  final Golang.Uint64 _maxSeq;
  final int _windowSize;
  final _FixedBigInt _mask;

  /// Port of `(*slidingWindowDetector) Check` (replaydetector.go:40-71).
  @override
  bool Function()? check(Golang.Uint64 seq) {
    if (seq > _maxSeq) {
      // Exceeded upper limit.
      return null;
    }

    if (seq <= _latestSeq) {
      if (_latestSeq >= Golang.Uint64(_windowSize) + seq) return null;
      if (_mask.bit((_latestSeq - seq).toBigInt().toInt()) != 0) {
        // The sequence number is duplicated.
        return null;
      }
    }

    return () {
      var latest = seq == Golang.Uint64(0);
      if (seq > _latestSeq) {
        // Update the head of the window.
        _mask.lsh((seq - _latestSeq).toBigInt().toInt());
        _latestSeq = seq;
        latest = true;
      }
      final diff = (_latestSeq - seq) % _maxSeq;
      _mask.setBit(diff.toBigInt().toInt());
      return latest;
    };
  }
}

class _WrappedSlidingWindowDetector implements ReplayDetector {
  _WrappedSlidingWindowDetector(this._windowSize, this._maxSeq)
    : _mask = _FixedBigInt(_windowSize);

  Golang.Uint64 _latestSeq = Golang.Uint64(0);
  final Golang.Uint64 _maxSeq;
  final int _windowSize;
  final _FixedBigInt _mask;
  bool _init = false;

  /// Port of `(*wrappedSlidingWindowDetector) Check` (replaydetector.go:89-133).
  ///
  /// The `diff` extremes this method computes (`-diff` fed to [_FixedBigInt.lsh]
  /// on a very large forward jump) are converted through
  /// [Golang.Int64.toIntExact], which throws if the magnitude does not fit a
  /// native Dart `int`. On every platform this project targets that range is
  /// the full signed 64-bit range, so this only matters for jumps close to
  /// `2^63`, far beyond any real DTLS/SRTP/SRTCP sequence counter; Go's own
  /// `int64` arithmetic here is equally exercised only within realistic
  /// counter ranges.
  @override
  bool Function()? check(Golang.Uint64 seq) {
    if (seq > _maxSeq) {
      // Exceeded upper limit.
      return null;
    }
    if (!_init) {
      _latestSeq = seq != Golang.Uint64(0) ? seq - Golang.Uint64(1) : _maxSeq;
      _init = true;
    }

    var diff =
        Golang.Int64.fromUint64(_latestSeq) - Golang.Int64.fromUint64(seq);
    final maxSeqPlusOne = Golang.Int64.fromUint64(_maxSeq) + Golang.Int64(1);
    final half = Golang.Int64.fromUint64(_maxSeq) ~/ Golang.Int64(2);
    // Wrap the number.
    if (diff > half) {
      diff -= maxSeqPlusOne;
    } else if (diff <= -half) {
      diff += maxSeqPlusOne;
    }

    if (diff >= Golang.Int64(_windowSize)) {
      // Too old.
      return null;
    }
    if (diff >= Golang.Int64(0)) {
      if (_mask.bit(diff.toIntExact()) != 0) {
        // The sequence number is duplicated.
        return null;
      }
    }

    return () {
      var latest = false;
      if (diff < Golang.Int64(0)) {
        // Update the head of the window.
        _mask.lsh((-diff).toIntExact());
        _latestSeq = seq;
        latest = true;
        _mask.setBit(0);
      } else {
        _mask.setBit(diff.toIntExact());
      }
      return latest;
    };
  }
}

/// Fixed-size multi-word integer used as the replay detector's sliding-window
/// bitmask. Port of the unexported `fixedBigInt` (fixedbig.go:11-16); has no
/// exported Go counterpart, so it stays private per this project's rule for
/// auxiliary symbols.
class _FixedBigInt {
  /// Port of `newFixedBigInt` (fixedbig.go:18-29).
  _FixedBigInt(this._n)
    : _bits = List.generate(_chunkCount(_n), (_) => Golang.Uint64(0)),
      _msbMask = (Golang.Uint64(1) << (64 - _n % 64)) - Golang.Uint64(1);

  static int _chunkCount(int n) {
    final chunkSize = (n + 63) ~/ 64;
    return chunkSize == 0 ? 1 : chunkSize;
  }

  final List<Golang.Uint64> _bits;
  final int _n;
  final Golang.Uint64 _msbMask;

  /// Left shift operation. Port of `Lsh` (fixedbig.go:32-49).
  void lsh(int n) {
    if (n == 0) return;
    final nChunk = n ~/ 64;
    final nN = n % 64;

    for (var i = _bits.length - 1; i >= 0; i--) {
      var carry = Golang.Uint64(0);
      if (i - nChunk >= 0) {
        carry = _bits[i - nChunk] << nN;
        if (i - nChunk - 1 >= 0) {
          carry = carry | (_bits[i - nChunk - 1] >> (64 - nN));
        }
      }
      _bits[i] = (_bits[i] << n) | carry;
    }
    _bits[_bits.length - 1] = _bits[_bits.length - 1] & _msbMask;
  }

  /// Returns the i-th bit. Port of `Bit` (fixedbig.go:53-64).
  int bit(int i) {
    if (i >= _n) return 0;
    final chunk = i ~/ 64;
    final pos = i % 64;
    return (_bits[chunk] & (Golang.Uint64(1) << pos)) != Golang.Uint64(0)
        ? 1
        : 0;
  }

  /// Sets the i-th bit to 1. Port of `SetBit` (fixedbig.go:67-73).
  void setBit(int i) {
    if (i >= _n) return;
    final chunk = i ~/ 64;
    final pos = i % 64;
    _bits[chunk] = _bits[chunk] | (Golang.Uint64(1) << pos);
  }

  /// String representation, big-endian hex chunks. Port of `String`
  /// (fixedbig.go:77-84).
  @override
  String toString() {
    final out = StringBuffer();
    for (var i = _bits.length - 1; i >= 0; i--) {
      out.write(
        _bits[i].toBigInt().toRadixString(16).toUpperCase().padLeft(16, '0'),
      );
    }
    return out.toString();
  }
}
