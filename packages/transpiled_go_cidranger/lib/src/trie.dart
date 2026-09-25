part of '../transpiled_go_cidranger.dart';

// Port of github.com/libp2p/go-cidranger/trie.go (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md): the path-compressed (PC) trie
// implementation of [Ranger], single-IP-version (wrapped by
// `_VersionedRanger` for dual IPv4/IPv6 dispatch, matching upstream's
// `versionedRanger`).
//
// Go distinguishes the exported `Insert`/`Remove`/... (the `Ranger`
// interface) from the same-named private recursive workers only by
// letter case (`insert`/`remove`/...); Dart is case-sensitive but this
// project's naming rules forbid a public method from using anything but
// lowerCamelCase, so the private workers below are given distinct names
// (`_insertNetwork`, `_removeNetwork`, ...) instead of relying on an
// impossible-in-Dart case-only distinction.

final IpNet _ip4ZeroCidr = IpNet.tryParseCidr('0.0.0.0/0')!;
final IpNet _ip6ZeroCidr = IpNet.tryParseCidr('0::0/0')!;

/// A path-compressed (PC) trie implementation of [Ranger], inspired by
/// <https://vincent.bernat.im/en/blog/2017-ipv4-route-lookup-linux>.
///
/// CIDR blocks are stored using a prefix tree structure where each node has
/// its parent as prefix, and the path from the root node represents the
/// current CIDR block.
///
/// For IPv4, the trie structure guarantees a max depth of 32, as IPv4
/// addresses are 32 bits long and each bit represents a prefix tree
/// starting at that bit. This property also guarantees constant lookup
/// time in Big-O notation.
///
/// Path compression compresses a run of nodes with only 1 child into a
/// single node, decreasing the number of lookups necessary during
/// containment tests.
///
/// Note: can not insert both IPv4 and IPv6 network addresses into the same
/// prefix trie; use [_VersionedRanger] instead.
///
/// Equivalent to go-cidranger's private `prefixTrie` (this port keeps it
/// Dart-private for the same reason: it has no exported Go counterpart of
/// its own, only via [Ranger.pcTrie]).
class _PrefixTrie implements Ranger {
  _PrefixTrie._({required this.network});

  /// A fresh, empty trie for [version]. Equivalent to go-cidranger's
  /// `newPrefixTree`.
  factory _PrefixTrie.tree(IpVersion version) {
    final rootNet = version == IpVersion.ipv6 ? _ip6ZeroCidr : _ip4ZeroCidr;
    return _PrefixTrie._(network: Network.fromIpNetwork(rootNet));
  }

  factory _PrefixTrie._pathPrefix(Network network, int numBitsSkipped) {
    final version = network.number.length == ipv6Uint32Count
        ? IpVersion.ipv6
        : IpVersion.ipv4;
    final path = _PrefixTrie.tree(version);
    path.numBitsSkipped = numBitsSkipped;
    path.network = network.masked(numBitsSkipped);
    return path;
  }

  factory _PrefixTrie._entry(Network network, RangerEntry entry) {
    final leaf = _PrefixTrie._pathPrefix(network, network.mask.ones);
    leaf.entry = entry;
    return leaf;
  }

  /// This node's parent, `null` for the root.
  _PrefixTrie? parent;

  /// The two possible children, indexed by the bit value (0 or 1) at
  /// [_targetBitPosition].
  final List<_PrefixTrie?> children = [null, null];

  int numBitsSkipped = 0;

  /// Kept for structural fidelity with go-cidranger's `prefixTrie` --
  /// upstream itself only ever writes `1` into this field at construction
  /// and never reads it back.
  int numBitsHandled = 1;

  /// This node's network (its path from the root).
  Network network;

  /// The entry stored at this exact network, if any.
  RangerEntry? entry;

  /// The number of networks in this trie. Only meaningful on the root.
  int _size = 0;

  @override
  void insert(RangerEntry entry) {
    final inserted = Network.fromIpNetwork(entry.network());
    final sizeIncreased = _insertNetwork(inserted, entry);
    if (sizeIncreased) _size++;
  }

  @override
  RangerEntry? remove(IpNet network) {
    final removed = _removeNetwork(Network.fromIpNetwork(network));
    if (removed != null) _size--;
    return removed;
  }

  @override
  bool contains(Ip ip) {
    final nn = NetworkNumber.fromIp(ip);
    if (nn == null) throw const InvalidNetworkNumberInputException();
    return _containsNumber(nn);
  }

  @override
  List<RangerEntry> containingNetworks(Ip ip) {
    final nn = NetworkNumber.fromIp(ip);
    if (nn == null) throw const InvalidNetworkNumberInputException();
    return _containingNetworksForNumber(nn);
  }

  @override
  List<RangerEntry> coveredNetworks(IpNet network) =>
      _coveredNetworksForNetwork(Network.fromIpNetwork(network));

  @override
  int get length => _size;

  @override
  String toString() {
    final childStrings = <String>[];
    final padding = '| ' * (_level() + 1);
    for (var bit = 0; bit < children.length; bit++) {
      final child = children[bit];
      if (child == null) continue;
      childStrings.add('\n$padding$bit--> $child');
    }
    return '$network (target_pos:${_targetBitPosition()}:'
        'has_entry:${_hasEntry()})${childStrings.join()}';
  }

  bool _containsNumber(NetworkNumber number) {
    if (!network.contains(number)) return false;
    if (_hasEntry()) return true;
    if (_targetBitPosition() < 0) return false;
    final child = children[_targetBitFromIp(number)];
    if (child != null) return child._containsNumber(number);
    return false;
  }

  List<RangerEntry> _containingNetworksForNumber(NetworkNumber number) {
    var results = <RangerEntry>[];
    if (!network.contains(number)) return results;
    if (_hasEntry()) results = [entry!];
    if (_targetBitPosition() < 0) return results;
    final child = children[_targetBitFromIp(number)];
    if (child != null) {
      final ranges = child._containingNetworksForNumber(number);
      if (ranges.isNotEmpty) {
        results = results.isNotEmpty ? [...results, ...ranges] : ranges;
      }
    }
    return results;
  }

  List<RangerEntry> _coveredNetworksForNetwork(Network searched) {
    if (searched.covers(network)) return _walkDepth().toList();
    if (_targetBitPosition() >= 0) {
      final child = children[_targetBitFromIp(searched.number)];
      if (child != null) return child._coveredNetworksForNetwork(searched);
    }
    return const [];
  }

  bool _insertNetwork(Network inserted, RangerEntry insertedEntry) {
    if (network == inserted) {
      final sizeIncreased = entry == null;
      entry = insertedEntry;
      return sizeIncreased;
    }

    final bit = _targetBitFromIp(inserted.number);
    var existingChild = children[bit];

    // No existing child: insert a new leaf trie.
    if (existingChild == null) {
      _appendTrie(bit, _PrefixTrie._entry(inserted, insertedEntry));
      return true;
    }

    // Insert an additional path prefix between this trie and the existing
    // child if the inserted network diverges on its path to it.
    final lcb = inserted.leastCommonBitPosition(existingChild.network);
    final divergingBitPos = lcb - 1;
    if (divergingBitPos > existingChild._targetBitPosition()) {
      final pathPrefix = _PrefixTrie._pathPrefix(
        inserted,
        _totalNumberOfBits() - lcb,
      );
      _insertPrefix(bit, pathPrefix, existingChild);
      existingChild = pathPrefix;
    }
    return existingChild._insertNetwork(inserted, insertedEntry);
  }

  void _appendTrie(int bit, _PrefixTrie prefix) {
    children[bit] = prefix;
    prefix.parent = this;
  }

  void _insertPrefix(int bit, _PrefixTrie pathPrefix, _PrefixTrie child) {
    children[bit] = pathPrefix;
    pathPrefix.parent = this;

    final pathPrefixBit = pathPrefix._targetBitFromIp(child.network.number);
    pathPrefix.children[pathPrefixBit] = child;
    child.parent = pathPrefix;
  }

  RangerEntry? _removeNetwork(Network removed) {
    if (_hasEntry() && network == removed) {
      final removedEntry = entry;
      entry = null;
      _compressPathIfPossible();
      return removedEntry;
    }
    final child = children[_targetBitFromIp(removed.number)];
    if (child != null) return child._removeNetwork(removed);
    return null;
  }

  bool _qualifiesForPathCompression() =>
      !_hasEntry() && _childrenCount() <= 1 && parent != null;

  void _compressPathIfPossible() {
    if (!_qualifiesForPathCompression()) return;

    _PrefixTrie? loneChild;
    for (final child in children) {
      if (child != null) {
        loneChild = child;
        break;
      }
    }

    var p = parent!;
    while (p._qualifiesForPathCompression()) {
      p = p.parent!;
    }
    final parentBit = p._targetBitFromIp(network.number);
    p.children[parentBit] = loneChild;

    p._compressPathIfPossible();
  }

  int _childrenCount() => children.where((c) => c != null).length;

  int _totalNumberOfBits() => bitsPerUint32 * network.number.length;

  int _targetBitPosition() => _totalNumberOfBits() - numBitsSkipped - 1;

  int _targetBitFromIp(NetworkNumber n) => n.bit(_targetBitPosition());

  bool _hasEntry() => entry != null;

  int _level() => parent == null ? 0 : parent!._level() + 1;

  /// Walks the trie in depth order. Used by [_coveredNetworksForNetwork]
  /// (production logic, not only a test helper -- go-cidranger's own
  /// `coveredNetworks` relies on its `walkDepth` the same way). Go
  /// implements this with a goroutine and a channel; a synchronous lazy
  /// `Iterable` is the idiomatic Dart equivalent for what is, here, a pure
  /// depth-first traversal with no concurrency (per AGENTS.md's veto on
  /// artificial `Chan`/goroutine use in ports).
  Iterable<RangerEntry> _walkDepth() sync* {
    if (_hasEntry()) yield entry!;
    for (final child in children) {
      if (child == null) continue;
      yield* child._walkDepth();
    }
  }
}
