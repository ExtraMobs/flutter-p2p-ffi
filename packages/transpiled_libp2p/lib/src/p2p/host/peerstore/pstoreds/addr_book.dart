// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/p2p/host/peerstore/pstoreds/addr_book.dart
//
// Port of go-libp2p's pstoreds/addr_book.go: an AddrBook + CertifiedAddrBook
// backed by a Datastore, serializing one pb.AddrBookRecord per peer.
//
// See pstoreds.dart's doc comment for the central adaptation this whole
// package makes: [DsAddrBook.open] loads every persisted record into
// memory up front, and every [AddrBook] method below is synchronous
// against that cache (Go's version reads/writes the ds.Batching directly
// per call, and layers a bounded ARC cache in front of it -- viable there
// because Go's ds.Datastore is a synchronous/blocking interface; this
// port's [Datastore] is Future-based, so a synchronous [Peerstore] can
// only be built as a read-through-at-startup cache). Persistence writes
// are still async, queued and replayed in order (see [DsAddrBook.flush]).
//
// One consequence: `GetPeerRecord` doesn't need Go's per-call
// marshal/ConsumeEnvelope round trip -- the validated [Envelope] for each
// peer's signed record is kept in memory alongside the record bytes (see
// `_peerRecordEnvelopes`), populated once at [open] (verifying the
// signature, like Go's `ConsumeEnvelope` does on every call) and on every
// [consumePeerRecord].
//
// Not ported here: `addr_book_gc.go` (~400 lines: lookahead-indexed and
// full-purge background sweep algorithms) and the ARC cache from
// `cache.go`/the hashicorp lru dependency. Both are performance/disk-usage
// optimizations layered on top of what's already necessary for
// correctness -- expired addresses are pruned on every access via
// [AddrsRecord.clean], same trigger points as Go's (`loadRecord`, `Addrs`,
// after every mutation). See options.dart's doc comment for more detail;
// this is the explicit gap called out in PROGRESS.md for this port.
import 'dart:async';
import 'dart:typed_data';

import 'package:transpiled_base32/transpiled_base32.dart' as base32;
import 'package:transpiled_datastore/transpiled_datastore.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../../../core/peer/addr_info.dart' show splitAddr;
import '../../../../core/peer/peer_id.dart';
import '../../../../core/peer/peer_record.dart';
import '../../../../core/peerstore/peerstore.dart';
import '../../../../core/record/envelope.dart';
import '../../../../core/record/record.dart';
import 'options.dart';
import 'pb/pstore_message.dart';

final Key _addrBookBase = Key('/peers/addrs');

/// How a TTL write should combine with an existing entry's TTL. Equivalent
/// to go-libp2p's `pstoreds.ttlWriteMode`.
enum TtlWriteMode {
  /// Replace the existing TTL/expiry unconditionally.
  override_,

  /// Only raise the existing TTL/expiry, never lower it.
  extend,
}

/// Decorates a persisted [AddrBookRecord] with the housekeeping go-libp2p's
/// `addrsRecord` does. Equivalent to go-libp2p's `pstoreds.addrsRecord`
/// (minus the mutex -- this port has no concurrent access to guard against;
/// see the file's doc comment).
class AddrsRecord {
  AddrsRecord(this.record);

  final AddrBookRecord record;

  /// Whether this record has nothing left worth persisting. Mirrors
  /// go-libp2p's `addrsRecord.flush`, which deletes the datastore entry
  /// once `len(r.Addrs) == 0` regardless of any certified record.
  bool get isGhost => record.addrs.isEmpty;

  /// Sorts addresses by soonest-expiring-first and drops expired ones.
  /// Entries held by a live connection or marked permanent (TTL >=
  /// [connectedAddrTtl]) never expire, regardless of their stored expiry
  /// -- their expiry is what an astronomically large TTL added to "now"
  /// overflows to, which is meaningless and must never be compared.
  /// Returns whether anything changed. Equivalent to go-libp2p's
  /// `addrsRecord.clean`.
  bool clean(DateTime now) {
    final addrs = record.addrs;
    if (addrs.isEmpty) return false;
    final before = addrs.length;
    addrs.sort((a, b) => a.expiry.compareTo(b.expiry));
    addrs.removeWhere(
      (e) => e.ttl < connectedAddrTtl.inMicroseconds && e.expiry <= now.microsecondsSinceEpoch,
    );
    return addrs.length != before;
  }
}

/// Strips a trailing `/p2p/<peer id>` suffix from each of [addrs], dropping
/// entries whose suffix doesn't match [pid]. Equivalent to go-libp2p's
/// `pstoreds.cleanAddrs`.
List<Multiaddr> cleanAddrs(List<Multiaddr> addrs, PeerId pid) {
  final clean = <Multiaddr>[];
  for (final addr in addrs) {
    final (stripped, addrPid) = splitAddr(addr);
    if (stripped == null) continue;
    if (addrPid != null && addrPid != pid) continue;
    clean.add(stripped);
  }
  return clean;
}

/// An [AddrBook] and [CertifiedAddrBook] backed by a persistent
/// [Datastore]. Equivalent to go-libp2p's `pstoreds.dsAddrBook`.
class DsAddrBook implements AddrBook, CertifiedAddrBook {
  DsAddrBook._(this._store, this._opts);

  final Datastore _store;
  final Options _opts;

  final Map<String, AddrsRecord> _records = {};
  final Map<String, Envelope> _peerRecordEnvelopes = {};
  final Map<String, List<StreamController<Multiaddr>>> _addrStreams = {};

  Future<void> _writeQueue = Future<void>.value();
  Object? _writeFailure;
  StackTrace? _writeFailureStack;

  void _enqueue(Future<void> Function() op) {
    _writeQueue = _writeQueue.then((_) async {
      try {
        await op();
      } catch (error, stack) {
        // Continue draining, but never report a failed mutation as durable.
        if (_writeFailure == null) {
          _writeFailure = error;
          _writeFailureStack = stack;
        }
      }
    });
  }

  /// Waits for every queued persistence write to reach the underlying
  /// [Datastore].
  Future<void> flush() async {
    await _writeQueue;
    final failure = _writeFailure;
    if (failure != null) {
      Error.throwWithStackTrace(failure, _writeFailureStack!);
    }
  }

  /// Loads every address record persisted under [_addrBookBase] from
  /// [store]. Equivalent to go-libp2p's `pstoreds.NewAddrBook`, plus the
  /// eager load and signed-record verification this port needs (see this
  /// file's doc comment).
  static Future<DsAddrBook> open(Datastore store, Options opts) async {
    final ab = DsAddrBook._(store, opts);
    final results = await store.query(Query(prefix: _addrBookBase.value));
    for (final entry in results.rest()) {
      final value = entry.value;
      if (value == null) continue;
      final AddrBookRecord record;
      final PeerId peerId;
      try {
        record = AddrBookRecord.unmarshal(Uint8List.fromList(value));
        peerId = PeerId.fromBytes(record.id);
      } catch (_) {
        continue;
      }
      final canonical = _addrBookBase.childString(base32.rawStdEncoding.encodeToString(peerId.value));
      if (entry.key != canonical.value) {
        final legacy = _addrBookBase.childString(peerId.toBase58());
        if (entry.key != legacy.value) continue;
        if (await store.has(canonical)) {
          await store.delete(legacy);
          continue;
        }
        await store.put(canonical, value);
        await store.delete(legacy);
      }
      try {
        final pKey = peerId.toBase58();
        final rec = AddrsRecord(record);
        rec.clean(opts.clock.now());
        ab._records[pKey] = rec;

        final cr = record.certifiedRecord;
        if (cr != null && cr.raw.isNotEmpty) {
          try {
            final (envelope, _) = await Envelope.consumeEnvelope(
              cr.raw,
              peerRecordEnvelopeDomain,
            );
            ab._peerRecordEnvelopes[pKey] = envelope;
          } catch (_) {
            // Corrupted/tampered signed record: drop it, same as Go's
            // GetPeerRecord logging the error and returning nil.
          }
        }
      } catch (_) {
        // Skip malformed/foreign entries under this prefix.
      }
    }
    return ab;
  }

  AddrsRecord _recordFor(PeerId p) =>
      _records.putIfAbsent(p.toBase58(), () => AddrsRecord(AddrBookRecord(id: p.value)));

  void _persistOrRemove(PeerId p, AddrsRecord r) {
    final pKey = p.toBase58();
    final key = _addrBookBase.childString(base32.rawStdEncoding.encodeToString(p.value));
    if (r.isGhost) {
      _records.remove(pKey);
      _peerRecordEnvelopes.remove(pKey);
      _enqueue(() => _store.delete(key));
      return;
    }
    final bytes = r.record.marshal();
    _enqueue(() => _store.put(key, bytes));
  }

  void _broadcast(PeerId p, Multiaddr addr) {
    final list = _addrStreams[p.toBase58()];
    if (list == null) return;
    for (final c in list) {
      if (!c.isClosed) c.add(addr);
    }
  }

  /// Equivalent to go-libp2p's `dsAddrBook.AddAddr`.
  @override
  void addAddr(PeerId p, Multiaddr addr, Duration ttl) => addAddrs(p, [addr], ttl);

  /// Equivalent to go-libp2p's `dsAddrBook.AddAddrs`.
  @override
  void addAddrs(PeerId p, List<Multiaddr> addrs, Duration ttl) {
    if (ttl <= Duration.zero) return;
    _setAddrs(p, cleanAddrs(addrs, p), ttl, TtlWriteMode.extend);
  }

  /// Equivalent to go-libp2p's `dsAddrBook.SetAddr`.
  @override
  void setAddr(PeerId p, Multiaddr addr, Duration ttl) => setAddrs(p, [addr], ttl);

  /// Equivalent to go-libp2p's `dsAddrBook.SetAddrs`.
  @override
  void setAddrs(PeerId p, List<Multiaddr> addrs, Duration ttl) {
    final cleaned = cleanAddrs(addrs, p);
    if (ttl <= Duration.zero) {
      _deleteAddrs(p, cleaned);
      return;
    }
    _setAddrs(p, cleaned, ttl, TtlWriteMode.override_);
  }

  /// Equivalent to go-libp2p's `dsAddrBook.UpdateAddrs`.
  @override
  void updateAddrs(PeerId p, Duration oldTtl, Duration newTtl) {
    final r = _records[p.toBase58()];
    if (r == null) return;
    final now = _opts.clock.now();
    final newExpiry = now.add(newTtl).microsecondsSinceEpoch;
    var changed = false;
    for (final e in r.record.addrs) {
      if (e.ttl != oldTtl.inMicroseconds) continue;
      e.ttl = newTtl.inMicroseconds;
      e.expiry = newExpiry;
      changed = true;
    }
    if (r.clean(now) || changed) {
      _persistOrRemove(p, r);
    }
  }

  /// Equivalent to go-libp2p's `dsAddrBook.Addrs`.
  @override
  List<Multiaddr> addrs(PeerId p) {
    final r = _records[p.toBase58()];
    if (r == null) return const [];
    if (r.clean(_opts.clock.now())) {
      _persistOrRemove(p, r);
    }
    return [for (final e in r.record.addrs) Multiaddr.fromBytes(e.addr)];
  }

  /// Equivalent to go-libp2p's `dsAddrBook.PeersWithAddrs`.
  @override
  List<PeerId> peersWithAddrs() {
    final result = <PeerId>[];
    for (final key in _records.keys.toList()) {
      final p = PeerId.decode(key);
      if (addrs(p).isNotEmpty) result.add(p);
    }
    return result;
  }

  /// Equivalent to go-libp2p's `dsAddrBook.AddrStream`.
  @override
  Stream<Multiaddr> addrStream(PeerId p) async* {
    for (final a in addrs(p)) {
      yield a;
    }
    final controller = StreamController<Multiaddr>();
    final list = _addrStreams.putIfAbsent(p.toBase58(), () => []);
    list.add(controller);
    try {
      yield* controller.stream;
    } finally {
      list.remove(controller);
      await controller.close();
    }
  }

  /// Equivalent to go-libp2p's `dsAddrBook.ClearAddrs`.
  @override
  void clearAddrs(PeerId p) {
    final pKey = p.toBase58();
    _records.remove(pKey);
    _peerRecordEnvelopes.remove(pKey);
    final key = _addrBookBase.childString(base32.rawStdEncoding.encodeToString(p.value));
    _enqueue(() => _store.delete(key));
  }

  void _deleteAddrs(PeerId p, List<Multiaddr> addrs) {
    final r = _records[p.toBase58()];
    if (r == null) return;
    final toRemove = {for (final a in addrs) a.toAddrString()};
    r.record.addrs.removeWhere((e) => toRemove.contains(Multiaddr.fromBytes(e.addr).toAddrString()));
    r.clean(_opts.clock.now());
    _persistOrRemove(p, r);
  }

  /// Equivalent to go-libp2p's `dsAddrBook.setAddrs`.
  void _setAddrs(PeerId p, List<Multiaddr> addrs, Duration ttl, TtlWriteMode mode) {
    if (addrs.isEmpty) return;

    final r = _recordFor(p);
    final now = _opts.clock.now();
    final newExpiry = now.add(ttl).microsecondsSinceEpoch;
    final newTtl = ttl.inMicroseconds;

    final addrsMap = <String, AddrBookRecord_AddrEntry>{
      for (final e in r.record.addrs) Multiaddr.fromBytes(e.addr).toAddrString(): e,
    };

    AddrBookRecord_AddrEntry? updateExisting(Multiaddr incoming) {
      final existing = addrsMap[incoming.toAddrString()];
      if (existing == null) return null;
      switch (mode) {
        case TtlWriteMode.override_:
          existing.ttl = newTtl;
          existing.expiry = newExpiry;
        case TtlWriteMode.extend:
          if (newTtl > existing.ttl) existing.ttl = newTtl;
          if (newExpiry > existing.expiry) existing.expiry = newExpiry;
      }
      return existing;
    }

    // Per-peer cap on unconnected addrs. Entries held by a live connection
    // (TTL >= connectedAddrTtl) bypass the cap and survive eviction.
    final maxCap = _opts.maxAddrsPerPeer;
    final incomingIsUnconnected = newTtl < connectedAddrTtl.inMicroseconds;
    var unconnectedCount = 0;
    if (maxCap > 0 && incomingIsUnconnected) {
      for (final e in r.record.addrs) {
        if (e.ttl < connectedAddrTtl.inMicroseconds) unconnectedCount++;
      }
    }

    bool evictNearestUnconnected() {
      var victim = -1;
      var soonest = 0;
      for (var i = 0; i < r.record.addrs.length; i++) {
        final e = r.record.addrs[i];
        if (e.ttl >= connectedAddrTtl.inMicroseconds) continue;
        if (victim == -1 || e.expiry < soonest) {
          victim = i;
          soonest = e.expiry;
        }
      }
      if (victim == -1) return false;
      final victimKey = Multiaddr.fromBytes(r.record.addrs[victim].addr).toAddrString();
      addrsMap.remove(victimKey);
      r.record.addrs.removeAt(victim);
      return true;
    }

    final newEntries = <AddrBookRecord_AddrEntry>[];
    for (final incoming in addrs) {
      final existing = updateExisting(incoming);
      if (existing != null) continue;

      if (maxCap > 0 && incomingIsUnconnected && unconnectedCount >= maxCap) {
        if (!evictNearestUnconnected()) continue;
        unconnectedCount--;
      }

      final entry = AddrBookRecord_AddrEntry(addr: incoming.toBytes(), expiry: newExpiry, ttl: newTtl);
      newEntries.add(entry);
      if (incomingIsUnconnected) unconnectedCount++;
      _broadcast(p, incoming);
    }

    r.record.addrs.addAll(newEntries);
    r.clean(now);
    _persistOrRemove(p, r);
  }

  int _latestPeerRecordSeq(PeerId p) {
    final r = _records[p.toBase58()];
    if (r == null) return 0;
    final cr = r.record.certifiedRecord;
    if (r.record.addrs.isEmpty || cr == null || cr.raw.isEmpty) return 0;
    return cr.seq;
  }

  /// Addrs that were present in the previously stored signed peer record
  /// for [p] but are absent in [newAddrs]. Addrs held by a live connection
  /// are excluded. Equivalent to go-libp2p's
  /// `dsAddrBook.supersededSignedAddrs`.
  List<Multiaddr> _supersededSignedAddrs(PeerId p, List<Multiaddr> newAddrs) {
    final prevEnv = getPeerRecord(p);
    if (prevEnv == null) return const [];
    final prevRec = prevEnv.record();
    if (prevRec is! PeerRecord) return const [];

    final newSet = {for (final a in newAddrs) a.toAddrString()};

    final connected = <String>{};
    final r = _records[p.toBase58()];
    if (r != null) {
      for (final e in r.record.addrs) {
        if (e.ttl >= connectedAddrTtl.inMicroseconds) {
          connected.add(Multiaddr.fromBytes(e.addr).toAddrString());
        }
      }
    }

    final superseded = <Multiaddr>[];
    for (final a in prevRec.addrs) {
      final key = a.toAddrString();
      if (newSet.contains(key)) continue;
      if (connected.contains(key)) continue;
      superseded.add(a);
    }
    return superseded;
  }

  void _storeSignedPeerRecord(PeerId p, Envelope envelope, PeerRecord rec) {
    final envelopeBytes = envelope.marshal();
    final r = _recordFor(p);
    r.record.certifiedRecord = CertifiedRecord(seq: rec.seq, raw: envelopeBytes);
    _peerRecordEnvelopes[p.toBase58()] = envelope;
    _persistOrRemove(p, r);
  }

  /// Equivalent to go-libp2p's `dsAddrBook.ConsumePeerRecord`.
  @override
  bool consumePeerRecord(Envelope s, Duration ttl) {
    final Record rec = s.record();
    if (rec is! PeerRecord) {
      throw StateError('envelope did not contain PeerRecord');
    }
    if (!rec.peerId.matchesPublicKey(s.publicKey)) {
      throw StateError('signing key does not match PeerID in PeerRecord');
    }

    if (_latestPeerRecordSeq(rec.peerId) > rec.seq) return false;

    final cleaned = cleanAddrs(rec.addrs, rec.peerId);

    final superseded = _supersededSignedAddrs(rec.peerId, cleaned);
    if (superseded.isNotEmpty) {
      _deleteAddrs(rec.peerId, superseded);
    }

    _setAddrs(rec.peerId, cleaned, ttl, TtlWriteMode.extend);
    _storeSignedPeerRecord(rec.peerId, s, rec);
    return true;
  }

  /// Equivalent to go-libp2p's `dsAddrBook.GetPeerRecord`. Unlike Go, this
  /// doesn't re-parse/re-verify the envelope on every call -- see this
  /// file's doc comment.
  @override
  Envelope? getPeerRecord(PeerId p) => _peerRecordEnvelopes[p.toBase58()];
}
