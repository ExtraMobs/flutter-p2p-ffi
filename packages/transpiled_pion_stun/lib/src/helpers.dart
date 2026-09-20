/// Port of `helpers.go` (pion/stun v3.1.1).
///
/// Go's `(error)`-returning `AddTo`/`GetFrom`/`Check` become `void` methods
/// that throw a typed exception on failure (AGENTS.md,
/// "RULE_NO_GO_STYLE_ERROR_TUPLES"): a thrown exception already unwinds
/// through `Build`/`Check`/`Parse`/`ForEach` exactly like Go's early
/// `return err`, so those loops need no explicit error propagation code.
library;

import 'attributes.dart';
import 'message.dart';

/// Port of `Setter` (helpers.go:5-7): sets some attribute of the message.
abstract interface class Setter {
  /// Port of `Setter.AddTo(m *Message) error`.
  void addTo(Message m);
}

/// Port of `Getter` (helpers.go:10-12): parses attribute from the message.
abstract interface class Getter {
  /// Port of `Getter.GetFrom(m *Message) error`.
  void getFrom(Message m);
}

/// Port of `Checker` (helpers.go:15-17): checks the message for some
/// condition.
abstract interface class Checker {
  /// Port of `Checker.Check(m *Message) error`.
  void check(Message m);
}

/// Port of `Message.Build` (helpers.go:33-51): resets the message and
/// applies [setters] to it in batch, throwing on the first failure.
extension MessageBuildX on Message {
  void build(List<Setter> setters) {
    reset();
    writeHeader();
    for (final s in setters) {
      s.addTo(this);
    }
  }

  /// Port of `Message.Check` (helpers.go:54-61): applies [checkers] to the
  /// message in batch, throwing on the first failure.
  void check(List<Checker> checkers) {
    for (final c in checkers) {
      c.check(this);
    }
  }

  /// Port of `Message.Parse` (helpers.go:65-73): applies [getters] to the
  /// message in batch, throwing on the first failure.
  void parse(List<Getter> getters) {
    for (final g in getters) {
      g.getFrom(this);
    }
  }

  /// Port of `Message.ForEach` (helpers.go:82-96): iterates over message
  /// attributes of type [t], calling [f] once per remaining occurrence.
  /// `m.Get`/[Message.get] inside `f` returns the next attribute of that
  /// type on each call.
  void forEach(AttrType t, void Function(Message m) f) {
    final attrs = attributes;
    try {
      for (var i = 0; i < attrs.length; i++) {
        if (attrs[i].type != t) continue;
        attributes = attrs.sublist(i);
        f(this);
      }
    } finally {
      attributes = attrs;
    }
  }
}

/// Port of `MustBuild` (helpers.go:14-21 of message.go... see
/// attributes.dart) -- wraps [build] and, per Go's `panic(err)` on failure,
/// simply lets the thrown exception propagate (Dart has no
/// error-return/panic distinction once errors are exceptions, so
/// [mustBuild] and [build] share one implementation; both names are kept to
/// preserve the upstream API surface).
Message mustBuild(List<Setter> setters) => build(setters);

/// Port of `Build` (helpers.go): allocates a new [Message] and applies
/// [setters] to it, throwing on the first failure.
Message build(List<Setter> setters) {
  final m = Message();
  m.build(setters);
  return m;
}
