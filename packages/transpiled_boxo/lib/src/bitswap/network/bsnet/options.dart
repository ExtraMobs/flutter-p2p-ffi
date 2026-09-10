import 'package:transpiled_libp2p/transpiled_libp2p.dart';

import '../connecteventmanager.dart';

typedef NetOpt = void Function(Settings);

class Settings {
  ProtocolId? protocolPrefix;
  List<ProtocolId>? supportedProtocols;
  ConnectEventManager? connEvtMgr;
}

NetOpt prefix(ProtocolId prefix) {
  return (Settings settings) {
    settings.protocolPrefix = prefix;
  };
}

NetOpt supportedProtocols(List<ProtocolId> protos) {
  return (Settings settings) {
    settings.supportedProtocols = protos;
  };
}

/// withConnectEventManager allows to set the ConnectEventManager. Upon
/// Start(), we will run SetListeners(). If not provided, an event manager will
/// be created internally. This allows re-using the event manager among several
/// Network instances.
NetOpt withConnectEventManager(ConnectEventManager evm) {
  return (Settings settings) {
    settings.connEvtMgr = evm;
  };
}
