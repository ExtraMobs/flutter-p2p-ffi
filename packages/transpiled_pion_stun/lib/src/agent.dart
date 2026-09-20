/// Port of `agent.go` (pion/stun v3.1.1).
///
/// Go's `Agent` guards its transaction map with a `sync.Mutex` because Go
/// goroutines can call it concurrently. A single Dart isolate's event loop
/// is cooperative -- every [Agent] method here runs to completion without
/// an `await` in the middle, so no interleaving can occur between two
/// calls -- and this codebase's convention (AGENTS.md,
/// "RULE_NO_ARTIFICIAL_CONCURRENCY") is to drop Go-specific concurrency
/// primitives rather than port them as inert ceremony; the mutex was
/// already private to upstream's own implementation, not public API, so
/// there is nothing here for a consumer to have depended on.
library;

import 'client.dart';
import 'message.dart';

/// Port of `Handler` (agent.go:47): handles transaction state changes.
/// Usage of the [Event] is valid only during the call.
typedef Handler = void Function(Event e);

/// Port of `NoopHandler` (agent.go:13-15): a [Handler] that discards any
/// event.
Handler noopHandler() => (Event e) {};

/// Port of `Event` (agent.go:51-55): passed to a [Handler] describing the
/// transaction event. Do not reuse outside the handler call.
final class Event {
  const Event({required this.transactionId, this.message, this.error});

  final List<int> transactionId;
  final Message? message;
  final Object? error;
}

/// Port of `agentTransaction` (agent.go:58-63): a transaction in progress.
final class _AgentTransaction {
  _AgentTransaction(this.id, this.deadline);

  final List<int> id;
  final DateTime deadline;
}

/// Port of `ErrTransactionStopped` (agent.go:66): transaction was manually
/// stopped.
final class TransactionStoppedException implements Exception {
  const TransactionStoppedException();

  @override
  String toString() => 'transaction is stopped';
}

/// Port of `ErrTransactionNotExists` (agent.go:68): agent failed to find
/// the transaction.
final class TransactionNotExistsException implements Exception {
  const TransactionNotExistsException();

  @override
  String toString() => 'transaction not exists';
}

/// Port of `ErrTransactionExists` (agent.go:70): a transaction with the
/// same ID is already registered.
final class TransactionExistsException implements Exception {
  const TransactionExistsException();

  @override
  String toString() => 'transaction exists with same id';
}

/// Port of `ErrAgentClosed` (agent.go:117): the agent is closed and unable
/// to handle transactions.
final class AgentClosedException implements Exception {
  const AgentClosedException();

  @override
  String toString() => 'agent is closed';
}

/// Port of `ErrTransactionTimeOut` (agent.go:158): the transaction has
/// reached its deadline.
final class TransactionTimeOutException implements Exception {
  const TransactionTimeOutException();

  @override
  String toString() => 'transaction is timed out';
}

/// Port of `Agent` (agent.go:31-42): a low-level abstraction over a
/// transaction list that handles timeouts (via [collect]). Implements
/// [ClientAgent] structurally (Go interfaces are duck-typed, so `*Agent`
/// satisfies `client.go`'s `ClientAgent` there with no explicit
/// declaration; Dart requires the `implements` clause spelled out).
final class Agent implements ClientAgent {
  /// Port of `NewAgent` (agent.go:18-28). If [handler] is `null`, a
  /// [noopHandler] is used.
  Agent([Handler? handler]) : _handler = handler ?? noopHandler();

  final Map<String, _AgentTransaction> _transactions = {};
  bool _closed = false;
  Handler _handler;

  static String _key(List<int> id) => id.join(',');

  /// Port of `Agent.StopWithError` (agent.go:74-90): removes the
  /// transaction from the list and calls the handler with the provided
  /// error. Throws [TransactionNotExistsException] or
  /// [AgentClosedException].
  void stopWithError(List<int> id, Object err) {
    if (_closed) throw const AgentClosedException();
    final t = _transactions.remove(_key(id));
    if (t == null) throw const TransactionNotExistsException();
    _handler(Event(transactionId: t.id, error: err));
  }

  /// Port of `Agent.Stop` (agent.go:94-96).
  void stop(List<int> id) => stopWithError(id, const TransactionStoppedException());

  /// Port of `Agent.Start` (agent.go:104-121): registers a transaction with
  /// the provided ID and deadline. Throws [AgentClosedException] or
  /// [TransactionExistsException].
  void start(List<int> id, DateTime deadline) {
    if (_closed) throw const AgentClosedException();
    final key = _key(id);
    if (_transactions.containsKey(key)) throw const TransactionExistsException();
    _transactions[key] = _AgentTransaction(id, deadline);
  }

  /// Port of `Agent.Collect` (agent.go:132-160): terminates all
  /// transactions with a deadline before [gcTime], calling the handler with
  /// [TransactionTimeOutException] for each. Throws [AgentClosedException]
  /// if the agent is already closed.
  void collect(DateTime gcTime) {
    if (_closed) throw const AgentClosedException();
    final toRemove = <String>[];
    for (final entry in _transactions.entries) {
      if (entry.value.deadline.isBefore(gcTime)) toRemove.add(entry.key);
    }
    final removed = toRemove.map((k) => _transactions.remove(k)!).toList();
    for (final t in removed) {
      _handler(Event(transactionId: t.id, error: const TransactionTimeOutException()));
    }
  }

  /// Port of `Agent.Process` (agent.go:163-178): processes an incoming
  /// message, synchronously passing it to the handler. Throws
  /// [AgentClosedException].
  void process(Message m) {
    if (_closed) throw const AgentClosedException();
    _transactions.remove(_key(m.transactionId));
    _handler(Event(transactionId: m.transactionId, message: m));
  }

  /// Port of `Agent.SetHandler` (agent.go:181-190): throws
  /// [AgentClosedException] if the agent is closed.
  void setHandler(Handler h) {
    if (_closed) throw const AgentClosedException();
    _handler = h;
  }

  /// Port of `Agent.Close` (agent.go:193-210): terminates all transactions
  /// with [AgentClosedException] and renders the agent closed. Throws
  /// [AgentClosedException] if already closed.
  void close() {
    if (_closed) throw const AgentClosedException();
    for (final t in _transactions.values) {
      _handler(Event(transactionId: t.id, error: const AgentClosedException()));
    }
    _transactions.clear();
    _closed = true;
  }
}
