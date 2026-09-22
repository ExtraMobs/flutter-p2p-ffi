// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-libp2p/p2p/net/connmgr/decay.go.
part of 'connmgr.dart';

/// The default resolution of the decay tracker.
///
/// Go: `DefaultResolution` (`decay.go:16`).
const Duration defaultResolution = Duration(minutes: 1);

/// The configuration object for the decayer.
///
/// Go: `DecayerCfg` (`decay.go:57-60`).
class DecayerCfg {
  /// Creates a decayer configuration.
  DecayerCfg({this.resolution = Duration.zero, this.clock});

  /// How often the decay tick runs.
  Duration resolution;

  /// The time source. When null, the real clock is used, exactly as upstream
  /// substitutes `clock.New()` in `NewDecayer` (`decay.go:74-77`).
  ///
  /// Note that this is independent from [BasicConnMgr]'s own clock: upstream
  /// does not propagate one to the other, so a `withClock(mock)` without a
  /// matching `decayerConfig` leaves the decayer on the real clock.
  Clock? clock;

  /// Writes the default values onto this configuration and returns itself, so
  /// it can be chained.
  ///
  /// Go: `WithDefaults` (`decay.go:68-71`), which sets only the resolution.
  DecayerCfg withDefaults() {
    resolution = defaultResolution;
    return this;
  }
}

/// The decaying tag registry backing [BasicConnMgr].
///
/// Go: `decayer` (`decay.go:32-52`), constructed by `NewDecayer`
/// (`decay.go:73-98`).
///
/// The upstream runs a `process()` goroutine selecting over a tick and three
/// command channels (`bumpTagCh`, `removeTagCh`, `closeTagCh`, each buffered
/// at 128). Those channels exist to move work off the caller's thread so a
/// bump never blocks on a segment lock. With no threads and no locks, the
/// commands are applied synchronously and the channels disappear; only the
/// tick survives, as a subscription to the clock's ticker.
///
/// One observable consequence, recorded in PROGRESS.md: upstream's `Bump` and
/// `Remove` fail either because the tag is closed *or* because the queue is
/// full (`decay.go:322-326`, `:339-343`). Only the first reason remains here.
class _Decayer implements core.Decayer {
  _Decayer(this._cfg, this._mgr) : _clock = _cfg.clock ?? Clock() {
    if (_cfg.resolution <= Duration.zero) {
      // Upstream reaches `time.NewTicker(cfg.Resolution)` (`decay.go:157`),
      // which panics on a non-positive interval. Dart's `Timer.periodic`
      // would instead spin hot, so the panic is reproduced as a throw.
      throw ArgumentError.value(
        _cfg.resolution,
        'resolution',
        'decayer resolution must be positive',
      );
    }
    _lastTick = _clock.now();
    final ticker = _clock.ticker(_cfg.resolution);
    _ticker = ticker;
    _subscription = ticker.c.listen((_) => _tick());
  }

  final DecayerCfg _cfg;
  final BasicConnMgr _mgr;
  final Clock _clock;

  final Map<String, _DecayingTag> _knownTags = <String, _DecayingTag>{};
  late DateTime _lastTick;
  Ticker? _ticker;
  StreamSubscription<DateTime>? _subscription;
  bool _closed = false;

  /// Go: `RegisterDecayingTag` (`decay.go:101-134`).
  @override
  core.DecayingTag registerDecayingTag(
    String name,
    Duration interval,
    core.DecayFn decayFn,
    core.BumpFn bumpFn,
  ) {
    if (_knownTags.containsKey(name)) {
      throw ArgumentError.value(
        name,
        'name',
        'decaying tag with name $name already exists',
      );
    }

    var effective = interval;
    if (effective < _cfg.resolution) {
      dev.log(
        'decay interval was lower than tracker resolution; overridden to '
        'resolution: name=$name interval=$interval '
        'resolution=${_cfg.resolution}',
        name: 'connmgr.decay',
      );
      effective = _cfg.resolution;
    }

    if (_cfg.resolution > Duration.zero &&
        effective.inMicroseconds % _cfg.resolution.inMicroseconds != 0) {
      dev.log(
        'decay interval for tag is not a multiple of tracker resolution; some '
        'precision may be lost: tag=$name interval=$effective '
        'resolution=${_cfg.resolution}',
        name: 'connmgr.decay',
      );
    }

    final tag = _DecayingTag(
      trkr: this,
      name: name,
      interval: effective,
      nextTick: _lastTick.add(effective),
      decayFn: decayFn,
      bumpFn: bumpFn,
    );
    _knownTags[name] = tag;
    return tag;
  }

  /// Closes the decayer. It is idempotent.
  ///
  /// Go: `Close` (`decay.go:137-147`).
  @override
  void close() {
    if (_closed) return;
    _closed = true;
    unawaited(_subscription?.cancel());
    _ticker?.stop();
  }

  /// One decay round: visits every peer and decays the tags that fell due.
  ///
  /// Go: the `<-ticker.C` arm of `process` (`decay.go:167-216`).
  void _tick() {
    if (_closed) return;
    final now = _clock.now();
    _lastTick = now;

    final visit = <_DecayingTag>{};
    for (final tag in _knownTags.values) {
      if (tag.nextTick.isAfter(now)) continue;
      visit.add(tag);
    }
    if (visit.isEmpty) return;

    for (final s in _mgr._segments.buckets) {
      for (final p in s.peers.values) {
        for (final tag in p.decaying.keys.toList()) {
          if (!visit.contains(tag)) continue;
          final v = p.decaying[tag]!;

          var delta = 0;
          final result = tag.decayFn(v);
          if (result.remove) {
            delta -= v.value;
            p.decaying.remove(tag);
          } else {
            delta += result.after - v.value;
            p.decaying[tag] = core.DecayingValue(
              tag: v.tag,
              peer: v.peer,
              added: v.added,
              lastVisit: now,
              value: result.after,
            );
          }
          // Keep the cached score the trim reads in step with the decay.
          p.value += delta;
        }
      }
    }

    for (final tag in visit) {
      tag.nextTick = tag.nextTick.add(tag.interval());
    }
  }

  /// Go: the `<-d.bumpTagCh` arm of `process` (`decay.go:218-244`).
  void _bump(_DecayingTag tag, PeerId peer, int delta) {
    final now = _clock.now();
    final s = _mgr._segments.get(peer);
    final p = s.tagInfoFor(peer, now);

    var v = p.decaying[tag];
    if (v == null) {
      v = core.DecayingValue(
        tag: tag,
        peer: peer,
        lastVisit: now,
        added: now,
        value: 0,
      );
      p.decaying[tag] = v;
    }

    final prev = v.value;
    final after = tag.bumpFn(v, delta);
    p.decaying[tag] = core.DecayingValue(
      tag: v.tag,
      peer: v.peer,
      added: v.added,
      lastVisit: now,
      value: after,
    );
    p.value += after - prev;
  }

  /// Go: the `<-d.removeTagCh` arm of `process` (`decay.go:246-258`).
  void _remove(_DecayingTag tag, PeerId peer) {
    final s = _mgr._segments.get(peer);
    final p = s.tagInfoFor(peer, _clock.now());
    final v = p.decaying[tag];
    if (v == null) return;
    p.value -= v.value;
    p.decaying.remove(tag);
  }

  /// Go: the `<-d.closeTagCh` arm of `process` (`decay.go:260-278`).
  void _closeTag(_DecayingTag tag) {
    _knownTags.remove(tag.name());

    for (final s in _mgr._segments.buckets) {
      for (final p in s.peers.values) {
        final dt = p.decaying[tag];
        if (dt == null) continue;
        p.value -= dt.value;
        p.decaying.remove(tag);
      }
    }
  }
}

/// A decaying tag, with its decay interval, decay function and bump function.
///
/// Go: `decayingTag` (`decay.go:288-299`).
class _DecayingTag implements core.DecayingTag {
  _DecayingTag({
    required this.trkr,
    required String name,
    required Duration interval,
    required this.nextTick,
    required this.decayFn,
    required this.bumpFn,
  }) : _name = name,
       _interval = interval;

  final _Decayer trkr;
  final String _name;
  final Duration _interval;
  DateTime nextTick;
  final core.DecayFn decayFn;
  final core.BumpFn bumpFn;

  /// Marks this tag as closed, so a bump after closure can be rejected.
  bool _closed = false;

  /// Go: `Name` (`decay.go:302-304`).
  @override
  String name() => _name;

  /// Go: `Interval` (`decay.go:306-308`).
  @override
  Duration interval() => _interval;

  /// Bumps this tag for [p].
  ///
  /// Throws [StateError] once the tag has been closed, which is the surviving
  /// half of upstream's two failure modes (`decay.go:311-326`).
  ///
  /// Go: `Bump` (`decay.go:311-326`).
  @override
  void bump(PeerId p, int delta) {
    if (_closed) {
      throw StateError(
        'decaying tag $_name had been closed; no further bumps are accepted',
      );
    }
    trkr._bump(this, p, delta);
  }

  /// Removes this tag's value for [p].
  ///
  /// Go: `Remove` (`decay.go:328-343`).
  @override
  void remove(PeerId p) {
    if (_closed) {
      throw StateError(
        'decaying tag $_name had been closed; no further removals are accepted',
      );
    }
    trkr._remove(this, p);
  }

  /// Closes this tag and removes it from every peer that held it.
  ///
  /// A second close logs and returns, as upstream does rather than failing.
  ///
  /// Go: `Close` (`decay.go:345-356`).
  @override
  void close() {
    if (_closed) {
      dev.log(
        'duplicate decaying tag closure; skipping: tag=$_name',
        name: 'connmgr.decay',
      );
      return;
    }
    _closed = true;
    trkr._closeTag(this);
  }
}
