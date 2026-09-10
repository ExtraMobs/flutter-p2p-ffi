// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-libp2p's core/routing/query.go and query_serde.go.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../peer/addr_info.dart';
import '../peer/peer_id.dart';

/// The integer type used by go-libp2p to identify a query event kind.
///
/// This remains an integer instead of a Dart enum because Go accepts and
/// round-trips event kinds outside the currently known range.
typedef QueryEventType = int;

/// Sending a query to a peer.
const QueryEventType sendingQuery = 0;

/// Got a response from a peer.
const QueryEventType peerResponse = 1;

/// Found a closest peer (currently unused by go-libp2p).
const QueryEventType finalPeer = 2;

/// Got an error when querying.
const QueryEventType queryError = 3;

/// Found a provider.
const QueryEventType provider = 4;

/// Found a value.
const QueryEventType value = 5;

/// Adding a peer to the query.
const QueryEventType addingPeer = 6;

/// Dialing a peer.
const QueryEventType dialingPeer = 7;

/// The channel buffer size used by the Go implementation.
///
/// Dart's single-subscription stream queues events for its listener, so this
/// value is retained for API correspondence rather than as a separate queue.
int queryEventBufferSize = 16;

/// A notable event emitted during a DHT query.
class QueryEvent {
  /// Creates a query event.
  QueryEvent({
    this.id,
    this.type = sendingQuery,
    this.responses,
    this.extra = '',
  });

  /// Decodes the representation produced by [toJson].
  factory QueryEvent.fromJson(Map<String, Object?> json) {
    final idText = json['ID'] as String? ?? '';
    final rawResponses = json['Responses'];
    return QueryEvent(
      id: idText.isEmpty ? null : PeerId.decode(idText),
      type: (json['Type'] as num?)?.toInt() ?? sendingQuery,
      responses: rawResponses == null
          ? null
          : (rawResponses as List<Object?>)
                .map(
                  (response) => response == null
                      ? null
                      : AddrInfo.fromJson(response as Map<String, Object?>),
                )
                .toList(),
      extra: json['Extra'] as String? ?? '',
    );
  }

  /// Decodes a JSON string produced by [toJsonString].
  factory QueryEvent.fromJsonString(String source) =>
      QueryEvent.fromJson(jsonDecode(source) as Map<String, Object?>);

  /// The peer associated with the event, or `null` for Go's zero-value ID.
  PeerId? id;

  /// The event kind.
  QueryEventType type;

  /// Peers returned by the query. A `null` list matches a nil Go slice.
  List<AddrInfo?>? responses;

  /// Additional event-specific information.
  String extra;

  /// The JSON representation used by go-libp2p's `MarshalJSON`.
  Map<String, Object?> toJson() => {
    // Go's encoding/json sorts map keys lexicographically.
    'Extra': extra,
    'ID': id?.toString() ?? '',
    'Responses': responses?.map((response) => response?.toJson()).toList(),
    'Type': type,
  };

  /// Encodes this event as JSON.
  String toJsonString() => jsonEncode(toJson());
}

final Object _routingQueryKey = Object();

class _EventChannel {
  final StreamController<QueryEvent> controller =
      StreamController<QueryEvent>();

  void send(QueryEvent event) {
    if (!controller.isClosed) controller.add(_cloneForPublish(event));
  }
}

/// A query-event stream and the execution zone that publishes into it.
///
/// This is the Dart counterpart of the `(context.Context, <-chan
/// *QueryEvent)` returned by go-libp2p's `RegisterForQueryEvents`: [run]
/// supplies the derived context and [events] supplies its channel. Call
/// [close] when events are no longer wanted, just as the Go caller must cancel
/// its context.
class QueryEventRegistration {
  QueryEventRegistration._() : _channel = _EventChannel();

  final _EventChannel _channel;

  /// The single-consumer stream of published events.
  Stream<QueryEvent> get events => _channel.controller.stream;

  /// Runs [body] in a zone that subscribes to query events.
  T run<T>(T Function() body) =>
      runZoned<T>(body, zoneValues: {_routingQueryKey: _channel});

  /// Stops accepting events and closes [events] after queued events drain.
  Future<void> close() => _channel.controller.close();
}

/// Registers a query-event stream for work run through the returned handle.
QueryEventRegistration registerForQueryEvents() => QueryEventRegistration._();

/// Publishes [event] to the query-event stream associated with the current
/// zone, if any.
void publishQueryEvent(QueryEvent event) {
  final channel = Zone.current[_routingQueryKey] as _EventChannel?;
  channel?.send(event);
}

/// Whether the current zone subscribes to query events.
bool subscribesToQueryEvents() => Zone.current[_routingQueryKey] != null;

QueryEvent _cloneForPublish(QueryEvent event) {
  final responses = event.responses;
  if (responses == null || responses.isEmpty) return event;

  return QueryEvent(
    id: event.id == null
        ? null
        : PeerId(value: Uint8List.fromList(event.id!.value)),
    type: event.type,
    responses: [
      for (final info in responses)
        if (info == null)
          null
        else
          AddrInfo(
            id: PeerId(value: Uint8List.fromList(info.id.value)),
            addrs: List.of(info.addrs),
          ),
    ],
    extra: event.extra,
  );
}
