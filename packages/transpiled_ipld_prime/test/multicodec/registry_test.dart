// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'package:test/test.dart';
import 'package:transpiled_ipld_prime/codec.dart';

void main() {
  test('custom registry registers and replaces codecs', () {
    final registry = Registry();
    void encoder(_, Sink<List<int>> _) {}
    void decoder(_, Iterable<int> _) {}
    registry.registerEncoder(0x55, encoder);
    registry.registerDecoder(0x0200, decoder);
    expect(registry.lookupEncoder(0x55), same(encoder));
    expect(registry.lookupDecoder(0x0200), same(decoder));
    expect(registry.listEncoders(), [0x55]);
    expect(registry.listDecoders(), [0x0200]);
    expect(() => registry.lookupEncoder(1), throwsStateError);
  });

  test('raw and json register their multicodecs', () {
    final registry = Registry();
    registerRawCodec(registry);
    registerJsonCodec(registry);
    expect(registry.listEncoders(), containsAll(<int>[0x55, 0x0200]));
    expect(registry.listDecoders(), containsAll(<int>[0x55, 0x0200]));
  });

  test('default registry exposes built-in codecs on first access', () {
    expect(lookupEncoder(0x55), isNotNull);
    expect(lookupDecoder(0x0200), isNotNull);
    expect(lookupEncoder(0x0129), isNotNull);
    expect(lookupDecoder(0x0129), isNotNull);
  });
}
