@Tags(['p0'])
@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_ipfs/transpiled_ipfs.dart';

import '../lib/local_kubo_harness.dart';

void main() {
  test(
      'Kubo discovers the embedded node by mDNS without bootstrap or manual dial',
      () async {
    final kubo = await LocalKuboHarness.start(mdnsEnabled: true);
    addTearDown(kubo.dispose);
    final node = await IpfsNode.fromBuildCfg(BuildCfg(online: true));
    addTearDown(node.close);
    var peers = '';
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      peers = await kubo.swarmPeers();
      if (peers.contains(node.peerId.toString())) break;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    expect(peers, contains(node.peerId.toString()));
    final bytes = Uint8List.fromList('mDNS discovered Dart seeder'.codeUnits);
    final cid = await node.putRawBlock(bytes);
    expect(await kubo.getRawBlock(cid.toString()), bytes);
  }, timeout: const Timeout(Duration(seconds: 90)));

  test(
      'Dart stores third-party ADD_PROVIDER and answers a different Kubo GET_PROVIDERS',
      () async {
    final node = await IpfsNode.fromBuildCfg(BuildCfg(
      online: true,
      config: const IpfsConfig(network: NetworkConfig(mdnsEnabled: false)),
    ));
    addTearDown(node.close);
    // The isolated LAN has no WAN bootstrap for the sweeping scheduler.
    // Use Kubo's supported legacy provider to send the announcement now.
    // LAN DHT deliberately filters loopback addresses from provider records.
    final interfaces =
        await NetworkInterface.list(type: InternetAddressType.IPv4);
    final lanAddress = interfaces
        .expand((i) => i.addresses)
        .firstWhere((a) => !a.isLoopback)
        .address;
    final provider = await LocalKuboHarness.start(
        routingType: 'dhtserver', sweepEnabled: false, swarmHost: lanAddress);
    addTearDown(provider.dispose);
    final consumer = await LocalKuboHarness.start(routingType: 'dhtserver');
    addTearDown(consumer.dispose);
    final address =
        node.swarmAddresses.firstWhere((a) => a.startsWith('/ip4/127.0.0.1/'));
    await provider.swarmConnect(address);
    await consumer.swarmConnect(address);
    var table = '';
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(deadline)) {
      table = await consumer.routingTables();
      if (table.contains(node.peerId.toString())) break;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    printOnFailure(table);
    expect(table, contains(node.peerId.toString()));
    final bytes = Uint8List.fromList(
        'third-party provider stored only in the Dart DHT'.codeUnits);
    final cid = await provider.putRawBlock(bytes);
    await provider.provide(cid);
    var providers = '';
    final provideDeadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(provideDeadline)) {
      providers = await consumer.findProviders(cid);
      if (providers.contains(provider.peerId)) break;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    printOnFailure(await provider.diagnostics());
    printOnFailure(await consumer.diagnostics());
    expect(providers, contains(provider.peerId));
    expect(providers, isNot(contains(node.peerId.toString())));
    expect(await consumer.getRawBlock(cid), bytes);
  }, timeout: const Timeout(Duration(seconds: 120)));
}
