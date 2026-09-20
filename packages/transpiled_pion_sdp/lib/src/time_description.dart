// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
part of '../transpiled_pion_sdp.dart';

// Port of github.com/pion/sdp/v3 time_description.go (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md).

/// The `t=`/`r=` fields, specifying a session's start/stop times and repeat
/// intervals. Port of `sdp.TimeDescription` (time_description.go:13).
class TimeDescription {
  TimeDescription({required this.timing, List<RepeatTime>? repeatTimes})
      : repeatTimes = repeatTimes ?? [];

  /// `t=<start-time> <stop-time>`.
  /// https://tools.ietf.org/html/rfc4566#section-5.9
  Timing timing;

  /// `r=<repeat interval> <active duration> <offsets from start-time>`.
  /// https://tools.ietf.org/html/rfc4566#section-5.10
  List<RepeatTime> repeatTimes;
}

/// The `t=` field's structured representation for the start and stop times.
/// Port of `sdp.Timing` (time_description.go:25).
class Timing {
  Timing({required this.startTime, required this.stopTime});

  Golang.Uint64 startTime;
  Golang.Uint64 stopTime;

  @override
  String toString() => '$startTime $stopTime';

  int _marshalSize() => _lenUint(startTime) + 1 + _lenUint(stopTime);
}

/// The `r=` fields, representing the intervals and durations for repeated
/// scheduled sessions. Port of `sdp.RepeatTime` (time_description.go:46).
class RepeatTime {
  RepeatTime({
    required this.interval,
    required this.duration,
    List<int>? offsets,
  }) : offsets = offsets ?? [];

  int interval;
  int duration;
  List<int> offsets;

  @override
  String toString() {
    final buffer = StringBuffer('$interval $duration');
    for (final value in offsets) {
      buffer
        ..write(' ')
        ..write(value);
    }
    return buffer.toString();
  }

  int _marshalSize() {
    var size = _lenInt(interval) + 1 + _lenInt(duration);
    for (final offset in offsets) {
      size += 1 + _lenInt(offset);
    }
    return size;
  }
}
