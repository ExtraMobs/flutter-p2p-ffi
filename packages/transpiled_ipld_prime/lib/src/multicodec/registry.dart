// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-ipld-prime/multicodec/{registry,defaultRegistry}.go.
import '../codec/api.dart';
import '../codec/json/codec.dart';
import '../codec/raw/codec.dart';
import '../codec/dagjson/codec.dart';

/// Maps multicodec indicator numbers to codec functions.
final class Registry {
  final Map<int, Encoder> _encoders = <int, Encoder>{};
  final Map<int, Decoder> _decoders = <int, Decoder>{};

  /// Registers [encode] for [indicator], replacing any previous value.
  void registerEncoder(int indicator, Encoder encode) =>
      _encoders[indicator] = encode;

  /// Looks up the encoder for [indicator].
  Encoder lookupEncoder(int indicator) =>
      _encoders[indicator] ??
      (throw StateError(
        'no encoder registered for multicodec code $indicator (0x${indicator.toRadixString(16)})',
      ));

  /// Lists indicators with registered encoders.
  List<int> listEncoders() => List.unmodifiable(_encoders.keys);

  /// Registers [decode] for [indicator], replacing any previous value.
  void registerDecoder(int indicator, Decoder decode) =>
      _decoders[indicator] = decode;

  /// Looks up the decoder for [indicator].
  Decoder lookupDecoder(int indicator) =>
      _decoders[indicator] ??
      (throw StateError(
        'no decoder registered for multicodec code $indicator (0x${indicator.toRadixString(16)})',
      ));

  /// Lists indicators with registered decoders.
  List<int> listDecoders() => List.unmodifiable(_decoders.keys);
}

/// Global registry used by default link-system integrations.
Registry? _defaultRegistry;
bool _defaultCodecsInitialized = false;

/// Global registry used by default link-system integrations.
///
/// The built-in raw and JSON codecs are installed on first access, matching
/// the effect of Go package initialization without relying on Dart's eager
/// top-level initialization.
Registry get defaultRegistry {
  final registry = _defaultRegistry ??= Registry();
  if (!_defaultCodecsInitialized) {
    _defaultCodecsInitialized = true;
    registerRawCodec(registry);
    registerJsonCodec(registry);
    registerDagJsonCodec(registry);
  }
  return registry;
}

/// Registers an encoder in [defaultRegistry].
void registerEncoder(int indicator, Encoder encode) =>
    defaultRegistry.registerEncoder(indicator, encode);

/// Looks up an encoder in [defaultRegistry].
Encoder lookupEncoder(int indicator) =>
    defaultRegistry.lookupEncoder(indicator);

/// Lists encoders in [defaultRegistry].
List<int> listEncoders() => defaultRegistry.listEncoders();

/// Registers a decoder in [defaultRegistry].
void registerDecoder(int indicator, Decoder decode) =>
    defaultRegistry.registerDecoder(indicator, decode);

/// Looks up a decoder in [defaultRegistry].
Decoder lookupDecoder(int indicator) =>
    defaultRegistry.lookupDecoder(indicator);

/// Lists decoders in [defaultRegistry].
List<int> listDecoders() => defaultRegistry.listDecoders();
