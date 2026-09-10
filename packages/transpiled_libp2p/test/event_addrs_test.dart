// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

void main() {
  test('address event contracts preserve Go fields and enum order', () {
    expect(AddrAction.values, [
      AddrAction.unknown,
      AddrAction.added,
      AddrAction.maintained,
      AddrAction.removed,
    ]);
    const address = UpdatedAddress(
      address: Multiaddr.empty,
      action: AddrAction.added,
    );
    const event = EvtLocalAddressesUpdated(
      diffs: true,
      current: [address],
      removed: [],
    );
    const relay = EvtAutoRelayAddrsUpdated([Multiaddr.empty]);
    expect(event.current.single.action, AddrAction.added);
    expect(event.diffs, isTrue);
    expect(relay.relayAddrs.single, Multiaddr.empty);
  });
}
