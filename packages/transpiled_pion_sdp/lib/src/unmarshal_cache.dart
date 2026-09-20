// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
part of '../transpiled_pion_sdp.dart';

// Port of github.com/pion/sdp/v3 unmarshal_cache.go (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md).
//
// Upstream backs this with a `sync.Pool` (unmarshal.go) purely to reduce GC
// pressure across concurrent `UnmarshalString` calls in Go. That pooling is
// a Go-specific performance device with no effect on observable behavior --
// `reset()` already clears it before every use -- so this port allocates a
// fresh `_UnmarshalCache` per call instead of pooling one; see
// `SessionDescription.unmarshalString` in unmarshal.dart.

/// Accumulates session/media attributes while parsing, so a whole media
/// description's attributes can be attached at once when the next `m=` line
/// (or end of document) is reached. Port of `sdp.unmarshalCache`
/// (unmarshal_cache.go:6).
class _UnmarshalCache {
  final List<Attribute> _sessionAttributes = [];
  final List<Attribute> _mediaAttributes = [];

  void reset() {
    _sessionAttributes.clear();
    _mediaAttributes.clear();
  }

  Attribute getSessionAttribute() {
    final attribute = Attribute();
    _sessionAttributes.add(attribute);
    return attribute;
  }

  List<Attribute> cloneSessionAttributes() {
    if (_sessionAttributes.isEmpty) {
      return [];
    }
    final cloned = List<Attribute>.of(_sessionAttributes);
    _sessionAttributes.clear();
    return cloned;
  }

  Attribute getMediaAttribute() {
    final attribute = Attribute();
    _mediaAttributes.add(attribute);
    return attribute;
  }

  List<Attribute> cloneMediaAttributes() {
    if (_mediaAttributes.isEmpty) {
      return [];
    }
    final cloned = List<Attribute>.of(_mediaAttributes);
    _mediaAttributes.clear();
    return cloned;
  }
}
