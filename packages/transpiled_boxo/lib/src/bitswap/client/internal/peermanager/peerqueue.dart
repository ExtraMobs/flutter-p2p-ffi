import 'package:transpiled_cid/transpiled_cid.dart';

abstract interface class PeerQueue {
  void addBroadcastWantHaves(List<Cid> wantHaves);
  void addWants(List<Cid> wantBlocks, List<Cid> wantHaves);
  void addCancels(List<Cid> cancels);
  void responseReceived(List<Cid> ks);
  bool hasMessage();
  void startup();
  void shutdown();
}
