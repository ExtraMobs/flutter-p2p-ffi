// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/p2p/discovery/backoff/backoff.dart
//
// Port of go-libp2p/p2p/discovery/backoff/backoff.go: stateful backoff
// strategies (fixed, polynomial, exponential, exponential-decorrelated) and
// the jitter functions that randomize them.
//
// Go's `time.Duration` is nanosecond-resolution `int64`; Dart's [Duration]
// is microsecond-resolution. Everything below that only ever deals in
// milliseconds/seconds (the real-world backoff domain this module serves)
// is unaffected. The one place resolution is observably different is
// [fullJitter]/[exponentialDecorrelatedJitter]'s sub-microsecond behavior,
// which cannot be reproduced in Dart's `Duration` -- documented at each
// call site.
//
// Go's `math/rand.Source`-seeded exact sequences are not reproduced (no
// upstream test asserts exact jittered values -- `backoff_test.go`'s
// `TestFullJitter` only asserts a statistically even spread, which any
// reasonable PRNG satisfies); `dart:math`'s `Random` is used instead of
// porting Go's specific lagged-Fibonacci generator.
import 'dart:math';

/// Produces a new, independent [BackoffStrategy] on each call. Equivalent
/// to go-libp2p's `BackoffFactory`.
typedef BackoffFactory = BackoffStrategy Function();

/// Describes how backoff is computed. Strategies are stateful. Equivalent
/// to go-libp2p's `BackoffStrategy`.
abstract class BackoffStrategy {
  /// Computes how long the next backoff duration should be, given prior
  /// calls to [delay].
  Duration delay();

  /// Clears the strategy's internal state.
  void reset();
}

/// Computes a jittered duration in `[minDelay, maxDelay]` from a base [duration].
/// [minDelay] must be lower than or equal to [maxDelay]. Equivalent to go-libp2p's
/// `Jitter`.
typedef Jitter =
    Duration Function(Duration duration, Duration minDelay, Duration maxDelay, Random? rng);

/// Returns a random duration, uniformly chosen from `[minDelay, boundedDur]`,
/// where `boundedDur` is [duration] bounded between [minDelay] and [maxDelay].
/// Equivalent to go-libp2p's `FullJitter`.
///
/// [rng] must be non-null (mirrors Go's `*rand.Rand` being dereferenced).
Duration fullJitter(Duration duration, Duration minDelay, Duration maxDelay, Random? rng) {
  if (duration <= minDelay) return minDelay;

  final normalizedDur = _boundedDuration(duration, minDelay, maxDelay) - minDelay;
  final micros = normalizedDur.inMicroseconds;
  final jittered = Duration(microseconds: rng!.nextInt(micros));
  return _boundedDuration(jittered + minDelay, minDelay, maxDelay);
}

/// Returns [duration] bounded between [minDelay] and [maxDelay], ignoring [rng].
/// Equivalent to go-libp2p's `NoJitter`.
Duration noJitter(Duration duration, Duration minDelay, Duration maxDelay, Random? rng) =>
    _boundedDuration(duration, minDelay, maxDelay);

Duration _boundedDuration(Duration d, Duration minDelay, Duration maxDelay) {
  if (d < minDelay) return minDelay;
  if (d > maxDelay) return maxDelay;
  return d;
}

/// Shared minDelay/maxDelay bound plus PRNG, mirroring go-libp2p's private
/// `randomizedBackoff`.
abstract class _RandomizedBackoff {
  _RandomizedBackoff({required this.minDelay, required this.maxDelay, required this.rng});

  final Duration minDelay;
  final Duration maxDelay;
  final Random rng;

  Duration _boundedDelay(Duration duration) => _boundedDuration(duration, minDelay, maxDelay);
}

/// Adds an attempt counter and jitter function on top of
/// [_RandomizedBackoff], mirroring go-libp2p's private `attemptBackoff`.
abstract class _AttemptBackoff extends _RandomizedBackoff {
  _AttemptBackoff({
    required this.jitter,
    required super.minDelay,
    required super.maxDelay,
    required super.rng,
  });

  final Jitter jitter;
  int attempt = 0;

  void resetAttempt() => attempt = 0;
}

/// Creates a [BackoffFactory] with a constant backoff duration. Equivalent
/// to go-libp2p's `NewFixedBackoff`.
BackoffFactory fixedBackoff(Duration delay) => () => _FixedBackoff(delay);

class _FixedBackoff implements BackoffStrategy {
  _FixedBackoff(this._delay);
  final Duration _delay;

  @override
  Duration delay() => _delay;

  @override
  void reset() {}
}

/// Creates a [BackoffFactory] with backoff of the form
/// `c0*x^0 + c1*x^1 + ... + cn*x^n`, where `x` is the attempt number.
/// [jitter] adds randomness around the backoff; [timeUnits] are the units
/// of time the polynomial is evaluated in; [polyCoefficients] are the
/// coefficients `[c0, c1, ..., cn]`. Equivalent to go-libp2p's
/// `NewPolynomialBackoff`.
BackoffFactory polynomialBackoff(
  Duration minDelay,
  Duration maxDelay,
  Jitter jitter,
  Duration timeUnits,
  List<double> polyCoefficients,
  Random rng,
) => () => _PolynomialBackoff(
  minDelay: minDelay,
  maxDelay: maxDelay,
  jitter: jitter,
  rng: rng,
  timeUnits: timeUnits,
  poly: polyCoefficients,
);

class _PolynomialBackoff extends _AttemptBackoff implements BackoffStrategy {
  _PolynomialBackoff({
    required super.minDelay,
    required super.maxDelay,
    required super.jitter,
    required super.rng,
    required this.timeUnits,
    required this.poly,
  });

  final Duration timeUnits;
  final List<double> poly;

  @override
  Duration delay() {
    double polySum;
    switch (poly.length) {
      case 0:
        return Duration.zero;
      case 1:
        polySum = poly[0];
      default:
        polySum = poly[0];
        var exp = 1;
        final currentAttempt = attempt;
        attempt++;
        for (final c in poly.skip(1)) {
          exp *= currentAttempt;
          polySum += exp * c;
        }
    }
    return jitter(
      Duration(microseconds: (timeUnits.inMicroseconds * polySum).truncate()),
      minDelay,
      maxDelay,
      rng,
    );
  }

  @override
  void reset() => resetAttempt();
}

/// Creates a [BackoffFactory] with backoff of the form
/// `base^x * timeUnits + offset`, where `x` is the attempt number.
/// [jitter] adds randomness around the backoff. Equivalent to go-libp2p's
/// `NewExponentialBackoff`.
BackoffFactory exponentialBackoff(
  Duration minDelay,
  Duration maxDelay,
  Jitter jitter,
  Duration timeUnits,
  double base,
  Duration offset,
  Random rng,
) => () => _ExponentialBackoff(
  minDelay: minDelay,
  maxDelay: maxDelay,
  jitter: jitter,
  rng: rng,
  timeUnits: timeUnits,
  base: base,
  offset: offset,
);

class _ExponentialBackoff extends _AttemptBackoff implements BackoffStrategy {
  _ExponentialBackoff({
    required super.minDelay,
    required super.maxDelay,
    required super.jitter,
    required super.rng,
    required this.timeUnits,
    required this.base,
    required this.offset,
  });

  final Duration timeUnits;
  final double base;
  final Duration offset;

  @override
  Duration delay() {
    final currentAttempt = attempt;
    attempt++;
    final micros = (pow(base, currentAttempt) * timeUnits.inMicroseconds).truncate();
    return jitter(Duration(microseconds: micros) + offset, minDelay, maxDelay, rng);
  }

  @override
  void reset() => resetAttempt();
}

/// Creates a [BackoffFactory] with backoff roughly of the form `base^x`,
/// where `x` is the attempt number. Delays start at [minDelay] and, after each
/// attempt, `delay = rand(minDelay, delay * base)`, bounded by [maxDelay]. Equivalent
/// to go-libp2p's `NewExponentialDecorrelatedJitter`.
BackoffFactory exponentialDecorrelatedJitter(
  Duration minDelay,
  Duration maxDelay,
  double base,
  Random rng,
) => () => _ExponentialDecorrelatedJitter(minDelay: minDelay, maxDelay: maxDelay, rng: rng, base: base);

class _ExponentialDecorrelatedJitter extends _RandomizedBackoff
    implements BackoffStrategy {
  _ExponentialDecorrelatedJitter({
    required super.minDelay,
    required super.maxDelay,
    required super.rng,
    required this.base,
  });

  final double base;
  Duration _lastDelay = Duration.zero;

  @override
  Duration delay() {
    if (_lastDelay < minDelay) {
      _lastDelay = minDelay;
      return _lastDelay;
    }

    final nextMax = (_lastDelay.inMicroseconds * base).toInt();
    final span = nextMax - minDelay.inMicroseconds;
    final random = Duration(microseconds: rng.nextInt(span)) + minDelay;
    _lastDelay = _boundedDelay(random);
    return _lastDelay;
  }

  @override
  void reset() => _lastDelay = Duration.zero;
}
