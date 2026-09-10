// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Port of go-ipld-prime/traversal.
library;

// ignore_for_file: duplicate_ignore, public_member_api_docs

import '../datamodel/kind.dart';
import '../datamodel/link.dart';
import '../datamodel/node.dart';
import '../datamodel/node_builder.dart';
import '../datamodel/path.dart';
import '../datamodel/path_segment.dart';
import '../linking/linking.dart';
import 'selector/selector.dart';

typedef VisitFn = void Function(Progress progress, Node node);
typedef TransformFn = Node? Function(Progress progress, Node? node);
typedef AdvVisitFn = void Function(
  Progress progress,
  Node node,
  VisitReason reason,
);
typedef LinkTargetNodePrototypeChooser = NodePrototype Function(
  Link link,
  LinkContext context,
);
typedef Preloader = void Function(PreloadContext context, PreloadLink link);

enum VisitReason { selectionMatch, selectionParent, selectionCandidate }

final class PreloadContext {
  const PreloadContext({
    this.context,
    required this.basePath,
    required this.parentNode,
  });
  final Object? context;
  final Path basePath;
  final Node parentNode;
}

final class PreloadLink {
  const PreloadLink({
    required this.segment,
    required this.linkNode,
    required this.link,
  });
  final PathSegment segment;
  final Node linkNode;
  final Link link;
}

final class Config {
  Config({
    this.context,
    this.linkSystem,
    this.linkTargetNodePrototypeChooser,
    this.linkVisitOnlyOnce = false,
    this.startAtPath = Path.empty,
    this.preloader,
  });
  Object? context;
  LinkSystem? linkSystem;
  LinkTargetNodePrototypeChooser? linkTargetNodePrototypeChooser;
  bool linkVisitOnlyOnce;
  Path startAtPath;
  Preloader? preloader;
}

final class Budget {
  Budget({required this.nodeBudget, required this.linkBudget});
  int nodeBudget;
  int linkBudget;
  Budget clone() => Budget(nodeBudget: nodeBudget, linkBudget: linkBudget);
}

final class LastBlock {
  LastBlock({this.path = Path.empty, this.link});
  Path path;
  Link? link;
  LastBlock copy() => LastBlock(path: path, link: link);
}

final class Progress {
  Progress({
    this.cfg,
    this.budget,
    this.path = Path.empty,
    LastBlock? lastBlock,
    this.pastStartAtPath = false,
    this.seenLinks,
  }) : lastBlock = lastBlock ?? LastBlock();

  Config? cfg;
  Budget? budget;
  Path path;
  LastBlock lastBlock;
  bool pastStartAtPath;
  Set<Link>? seenLinks;

  Progress _copy() => Progress(
    cfg: cfg,
    budget: budget,
    path: path,
    lastBlock: lastBlock.copy(),
    pastStartAtPath: pastStartAtPath,
    seenLinks: seenLinks,
  );

  void _init() {
    final config = cfg ??= Config();
    config.linkTargetNodePrototypeChooser ??= (_, _) => throw StateError(
      'no LinkTargetNodePrototypeChooser configured',
    );
    if (config.linkVisitOnlyOnce) seenLinks ??= <Link>{};
  }

  void walkMatching(Node node, Selector selector, VisitFn visit) {
    final progress = _copy().._init();
    progress._walkBlock(node, selector, (p, n, reason) {
      if (reason == VisitReason.selectionMatch) visit(p, n);
    });
  }

  void walkLocal(Node node, VisitFn visit) {
    final progress = _copy();
    progress._checkNodeBudget();
    try {
      visit(progress, node);
    } on SkipMeException {
      return;
    }
    switch (node.kind()) {
      case Kind.map:
        final iterator = node.mapIterator()!;
        while (!iterator.done()) {
          final (key, value) = iterator.next();
          final next = progress._copy()
            ..path = progress.path.appendSegmentString(key.asString());
          next.walkLocal(value, visit);
        }
      case Kind.list:
        final iterator = node.listIterator()!;
        while (!iterator.done()) {
          final (index, value) = iterator.next();
          final next = progress._copy()
            ..path = progress.path.appendSegmentInt(index);
          next.walkLocal(value, visit);
        }
      default:
        return;
    }
  }

  void walkAdv(Node node, Selector selector, AdvVisitFn visit) {
    final progress = _copy().._init();
    progress._walkBlock(node, selector, visit);
  }

  Node walkTransforming(Node node, Selector selector, TransformFn transform) {
    final progress = _copy().._init();
    return progress._walkTransforming(node, selector, transform);
  }

  void focus(Node node, Path target, VisitFn visit) {
    final progress = _copy();
    final result = progress._get(node, target, trackProgress: true);
    visit(progress, result);
  }

  Node get(Node node, Path target) =>
      _copy()._get(node, target, trackProgress: false);

  Node focusedTransform(
    Node node,
    Path target,
    TransformFn transform,
    bool createParents,
  ) {
    final progress = _copy().._init();
    final builder = node.prototype().newBuilder();
    progress._focusedTransform(node, builder, target, transform, createParents);
    return builder.build();
  }

  void _walkBlock(Node node, Selector selector, AdvVisitFn visit) {
    final preloader = cfg!.preloader;
    if (preloader == null) {
      _walkAdv(_Phase.traverse, node, selector, visit);
      return;
    }
    final savedBudget = budget?.clone();
    try {
      _walkAdv(_Phase.preload, node, selector, visit);
    } on BudgetExceededException {
      // A preload is advisory: its best-effort budget must not stop the walk.
    }
    budget = savedBudget;
    _walkAdv(_Phase.traverse, node, selector, visit);
  }

  void _walkAdv(_Phase phase, Node node, Selector selector, AdvVisitFn visit) {
    _checkNodeBudget();
    final reified = _reify(node, selector);
    node = reified.$1;
    selector = reified.$2;
    _visit(phase, node, selector, visit);
    if (node.kind() != Kind.map && node.kind() != Kind.list) return;

    final target = cfg!.startAtPath;
    final haveStart = target.length > 0;
    var reachedStart = false;
    void recurse(Node value, PathSegment segment) {
      if (haveStart) {
        if (reachedStart) {
          pastStartAtPath = true;
        } else if (!pastStartAtPath && path.length < target.length) {
          if (segment.equals(target.segments[path.length])) reachedStart = true;
          if (!reachedStart) return;
        }
      }
      _explore(phase, selector, node, visit, value, segment);
    }

    final interests = selector.interests();
    if (interests == null) {
      final iterator = SegmentIterator(node);
      while (!iterator.done) {
        final (segment, value) = iterator.next();
        recurse(value, segment);
      }
    } else {
      for (final segment in interests) {
        try {
          recurse(node.lookupBySegment(segment), segment);
        } catch (_) {
          // Selector interests are allowed not to exist on this node.
        }
      }
    }
  }

  (Node, Selector) _reify(Node node, Selector selector) {
    if (selector is! Reifiable) return (node, selector);
    final reifiable = selector as Reifiable;
    final system = cfg!.linkSystem;
    final reifier = system?.knownReifiers[reifiable.namedReifier];
    if (reifier == null) {
      throw TraversalException(
        'unregistered adl requested: ${reifiable.namedReifier}',
      );
    }
    final reified = reifier(
      LinkContext(context: cfg!.context, linkPath: path),
      node,
      system!,
    );
    final next = selector.explore(node, PathSegment.empty);
    if (next == null) throw StateError('reifier selector has no child');
    return (reified, next);
  }

  void _visit(_Phase phase, Node node, Selector selector, AdvVisitFn visit) {
    if (phase != _Phase.traverse) return;
    final target = cfg!.startAtPath;
    if (!pastStartAtPath && path.length < target.length) return;
    final match = selector.match(node);
    visit(
      this,
      match ?? node,
      match == null
          ? VisitReason.selectionCandidate
          : VisitReason.selectionMatch,
    );
  }

  void _explore(
    _Phase phase,
    Selector selector,
    Node parent,
    AdvVisitFn visit,
    Node value,
    PathSegment segment,
  ) {
    final next = selector.explore(parent, segment);
    if (next == null) return;
    final progress = _copy()..path = path.appendSegment(segment);
    if (value.kind() != Kind.link) {
      progress._walkAdv(phase, value, next, visit);
      return;
    }
    final link = value.asLink();
    if (cfg!.linkVisitOnlyOnce) {
      final seen = seenLinks!;
      if (seen.contains(link)) return;
      if (phase == _Phase.traverse) seen.add(link);
    }
    if (phase == _Phase.preload) {
      _checkLinkBudget(link);
      cfg!.preloader!(
        PreloadContext(
          context: cfg!.context,
          basePath: path,
          parentNode: parent,
        ),
        PreloadLink(segment: segment, linkNode: value, link: link),
      );
      return;
    }
    progress.lastBlock = LastBlock(path: progress.path, link: link);
    Node loaded;
    try {
      loaded = progress._loadLink(link, value, parent);
    } on SkipMeException {
      return;
    }
    progress._walkBlock(loaded, next, visit);
  }

  Node _loadLink(Link link, Node linkNode, Node? parent) {
    _checkLinkBudget(link);
    final context = LinkContext(
      context: cfg!.context,
      linkPath: path,
      linkNode: linkNode,
      parentNode: parent,
    );
    final prototype = cfg!.linkTargetNodePrototypeChooser!(link, context);
    final system = cfg!.linkSystem;
    if (system == null) throw const TraversalException('no LinkSystem configured');
    return system.load(context, link, prototype);
  }

  void _checkNodeBudget() {
    final value = budget;
    if (value == null) return;
    if (value.nodeBudget <= 0) {
      throw BudgetExceededException('node', path);
    }
    value.nodeBudget--;
  }

  void _checkLinkBudget(Link link) {
    final value = budget;
    if (value == null) return;
    if (value.linkBudget <= 0) {
      throw BudgetExceededException('link', path, link);
    }
    value.linkBudget--;
  }

  Node _walkTransforming(Node node, Selector selector, TransformFn transform) {
    _checkNodeBudget();
    final reified = _reify(node, selector);
    node = reified.$1;
    selector = reified.$2;
    if (selector.decide(node)) {
      final replacement = transform(this, node);
      if (!identical(replacement, node)) {
        if (replacement == null) {
          throw const TraversalException('a walk transform cannot remove its root');
        }
        return replacement;
      }
    }
    if (node.kind() == Kind.list) {
      return _transformList(node, selector, transform);
    }
    if (node.kind() == Kind.map) {
      return _transformMap(node, selector, transform);
    }
    return node;
  }

  Node _transformList(Node node, Selector selector, TransformFn transform) {
    final builder = node.prototype().newBuilder();
    final list = builder.beginList(node.length());
    final interests = selector.interests();
    final iterator = SegmentIterator(node);
    while (!iterator.done) {
      final (segment, original) = iterator.next();
      var value = original;
      if (interests == null || _contains(interests, segment)) {
        final next = selector.explore(node, segment);
        if (next != null) {
          final progress = _copy()..path = path.appendSegment(segment);
          if (value.kind() == Kind.link) {
            final link = value.asLink();
            if (cfg!.linkVisitOnlyOnce && !seenLinks!.add(link)) continue;
            progress.lastBlock = LastBlock(path: progress.path, link: link);
            try {
              value = progress._loadLink(link, value, node);
            } on SkipMeException {
              continue;
            }
          }
          value = progress._walkTransforming(value, next, transform);
        }
      }
      list.assembleValue().assignNode(value);
    }
    list.finish();
    return builder.build();
  }

  Node _transformMap(Node node, Selector selector, TransformFn transform) {
    final builder = node.prototype().newBuilder();
    final map = builder.beginMap(node.length());
    final interests = selector.interests();
    final iterator = SegmentIterator(node);
    while (!iterator.done) {
      final (segment, original) = iterator.next();
      map.assembleKey().assignString(segment.toString());
      var value = original;
      if (interests == null || _contains(interests, segment)) {
        final next = selector.explore(node, segment);
        if (next != null) {
          final progress = _copy()..path = path.appendSegment(segment);
          if (value.kind() == Kind.link) {
            final link = value.asLink();
            if (cfg!.linkVisitOnlyOnce && !seenLinks!.add(link)) continue;
            progress.lastBlock = LastBlock(path: progress.path, link: link);
            try {
              value = progress._loadLink(link, value, node);
            } on SkipMeException {
              continue;
            }
          }
          value = progress._walkTransforming(value, next, transform);
        }
      }
      map.assembleValue().assignNode(value);
    }
    map.finish();
    return builder.build();
  }

  Node _get(Node node, Path target, {required bool trackProgress}) {
    _init();
    Node current = node;
    Node? previous;
    for (var index = 0; index < target.length; index++) {
      _checkNodeBudget();
      final segment = target.segments[index];
      try {
        previous = current;
        current = switch (current.kind()) {
          Kind.map => current.lookupByString(segment.toString()),
          Kind.list => current.lookupByIndex(segment.index()),
          _ => throw TraversalException(
              'cannot traverse terminals at ${target.truncate(index)}',
            ),
        };
      } catch (error) {
        if (error is TraversalException) rethrow;
        throw TraversalException(
          'error traversing segment "$segment" on ${target.truncate(index)}',
          error,
        );
      }
      while (current.kind() == Kind.link) {
        final link = current.asLink();
        _checkLinkBudget(link);
        final context = LinkContext(
          context: cfg!.context,
          linkPath: target.truncate(index),
          linkNode: current,
          parentNode: previous,
        );
        final prototype = cfg!.linkTargetNodePrototypeChooser!(link, context);
        final system = cfg!.linkSystem;
        if (system == null) throw const TraversalException('no LinkSystem configured');
        previous = current;
        current = system.load(context, link, prototype);
        if (trackProgress) {
          lastBlock = LastBlock(path: target.truncate(index + 1), link: link);
        }
      }
    }
    if (trackProgress) path = path.join(target);
    return current;
  }

  void _focusedTransform(
    Node? node,
    NodeAssembler assembler,
    Path target,
    TransformFn transform,
    bool createParents,
  ) {
    final at = path;
    if (target.length == 0) {
      final replacement = transform(this, node);
      if (replacement == null) {
        throw const TraversalException('cannot remove the traversal root');
      }
      assembler.assignNode(replacement);
      return;
    }
    final (segment, rest) = target.shift();
    _checkNodeBudget();
    if (node == null) {
      final map = assembler.beginMap(1);
      path = at.appendSegment(segment);
      map.assembleKey().assignString(segment.toString());
      _focusedTransform(null, map.assembleValue(), rest, transform, createParents);
      map.finish();
      return;
    }
    switch (node.kind()) {
      case Kind.map:
        _focusedMap(node, assembler, segment, rest, transform, createParents, at);
      case Kind.list:
        _focusedList(node, assembler, segment, rest, transform, createParents);
      case Kind.link:
        final link = node.asLink();
        _checkLinkBudget(link);
        final context = LinkContext(
          context: cfg!.context,
          linkPath: path,
          linkNode: node,
        );
        final prototype = cfg!.linkTargetNodePrototypeChooser!(link, context);
        final system = cfg!.linkSystem;
        if (system == null) throw const TraversalException('no LinkSystem configured');
        final loaded = system.load(context, link, prototype);
        lastBlock = LastBlock(path: path, link: link);
        final builder = prototype.newBuilder();
        _focusedTransform(loaded, builder, target, transform, createParents);
        assembler.assignLink(system.store(context, link.prototype(), builder.build()));
      default:
        throw TraversalException('transform parent at $path was a scalar');
    }
  }

  void _focusedMap(
    Node node,
    NodeAssembler assembler,
    PathSegment segment,
    Path rest,
    TransformFn transform,
    bool createParents,
    Path at,
  ) {
    final map = assembler.beginMap(node.length());
    final end = rest.length == 0;
    Node? replacement;
    if (end) {
      try {
        replacement = transform(this..path = at.appendSegment(segment), node.lookupBySegment(segment));
      } catch (error) {
        if (error is TraversalException) rethrow;
        replacement = transform(this..path = at.appendSegment(segment), null);
      }
    }
    var replaced = false;
    final iterator = node.mapIterator()!;
    while (!iterator.done()) {
      final (key, value) = iterator.next();
      if (PathSegment.ofString(key.asString()).equals(segment)) {
        replaced = true;
        if (end && replacement == null) continue;
        map.assembleKey().assignNode(key);
        if (end) {
          map.assembleValue().assignNode(replacement!);
        } else {
          path = at.appendSegment(segment);
          _focusedTransform(value, map.assembleValue(), rest, transform, createParents);
        }
      } else {
        map.assembleKey().assignNode(key);
        map.assembleValue().assignNode(value);
      }
    }
    if (replaced) {
      map.finish();
      return;
    }
    path = at.appendSegment(segment);
    if (rest.length > 0 && !createParents) {
      throw TraversalException('transform parent at $path did not exist');
    }
    if (end && replacement == null) {
      throw TraversalException('transform target at $path did not exist');
    }
    map.assembleKey().assignString(segment.toString());
    if (end) {
      map.assembleValue().assignNode(replacement!);
    } else {
      _focusedTransform(null, map.assembleValue(), rest, transform, createParents);
    }
    map.finish();
  }

  void _focusedList(
    Node node,
    NodeAssembler assembler,
    PathSegment segment,
    Path rest,
    TransformFn transform,
    bool createParents,
  ) {
    final list = assembler.beginList(node.length());
    final index = segment.toString() == '-' ? -1 : _parseIndex(segment);
    var replaced = false;
    final iterator = node.listIterator()!;
    while (!iterator.done()) {
      final (current, value) = iterator.next();
      if (current == index) {
        path = path.appendSegment(segment);
        _focusedTransform(value, list.assembleValue(), rest, transform, createParents);
        replaced = true;
      } else {
        list.assembleValue().assignNode(value);
      }
    }
    if (replaced) {
      list.finish();
      return;
    }
    if (index >= 0) {
      throw TraversalException('transform list index $segment is out of bounds');
    }
    path = path.appendSegmentInt(node.length());
    _focusedTransform(null, list.assembleValue(), rest, transform, createParents);
    list.finish();
  }
}

enum _Phase { preload, traverse }

bool _contains(List<PathSegment> values, PathSegment candidate) =>
    values.any(candidate.equals);

int _parseIndex(PathSegment segment) {
  try {
    return segment.index();
  } on FormatException {
    throw TraversalException('cannot use path segment $segment on a list');
  }
}

final class SkipMeException implements Exception {
  const SkipMeException();
  @override
  String toString() => 'skip';
}

final class BudgetExceededException implements Exception {
  const BudgetExceededException(this.budgetKind, this.path, [this.link]);
  final String budgetKind;
  final Path path;
  final Link? link;
  @override
  String toString() =>
      'traversal budget exceeded: budget for ${budgetKind}s reached zero while on path "$path"';
}

final class TraversalException implements Exception {
  const TraversalException(this.message, [this.cause]);
  final String message;
  final Object? cause;
  @override
  String toString() => cause == null ? message : '$message: $cause';
}

void walkLocal(Node node, VisitFn visit) => Progress().walkLocal(node, visit);
void walkMatching(Node node, Selector selector, VisitFn visit) =>
    Progress().walkMatching(node, selector, visit);
void walkAdv(Node node, Selector selector, AdvVisitFn visit) =>
    Progress().walkAdv(node, selector, visit);
Node walkTransforming(Node node, Selector selector, TransformFn transform) =>
    Progress().walkTransforming(node, selector, transform);
void focus(Node node, Path path, VisitFn visit) => Progress().focus(node, path, visit);
Node get(Node node, Path path) => Progress().get(node, path);
Node focusedTransform(
  Node node,
  Path path,
  TransformFn transform,
  bool createParents,
) => Progress().focusedTransform(node, path, transform, createParents);

List<Link> selectLinks(Node node) {
  final links = <Link>[];
  void collect(Node value) {
    switch (value.kind()) {
      case Kind.map:
      case Kind.list:
        final iterator = SegmentIterator(value);
        while (!iterator.done) {
          collect(iterator.next().$2);
        }
      case Kind.link:
        links.add(value.asLink());
      default:
        return;
    }
  }
  collect(node);
  return links;
}
