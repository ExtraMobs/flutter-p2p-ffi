part of 'nat.dart';

/// Standard UPnP implementation of the [Nat] interface.
class _UpnpNat implements Nat {
  _UpnpNat({
    required this.controlUrl,
    required this.serviceType,
    required this.typ,
  });

  final String controlUrl;
  final String serviceType;
  final String typ;
  static const Duration httpTimeout = Duration(seconds: 4);

  final Map<int, int> ports = {};
  InternetAddress? _deviceAddress;
  InternetAddress? _internalAddress;

  @override
  String type() => typ;

  @override
  Future<InternetAddress> getDeviceAddress() async {
    if (_deviceAddress != null) return _deviceAddress!;
    final uri = Uri.parse(controlUrl);
    final host = uri.host;
    try {
      final addrs = await InternetAddress.lookup(host);
      if (addrs.isNotEmpty) {
        _deviceAddress = addrs.first;
        return _deviceAddress!;
      }
    } catch (_) {}
    _deviceAddress = InternetAddress(host);
    return _deviceAddress!;
  }

  @override
  Future<InternetAddress> getInternalAddress() async {
    if (_internalAddress != null) return _internalAddress!;
    final devAddr = await getDeviceAddress();

    try {
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );

      // 1. Try to find an interface in the exact same subnet as devAddr (e.g. 192.168.1.x)
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback || addr.isLinkLocal) continue;
          if (_isSameSubnet(addr.address, devAddr.address)) {
            _internalAddress = addr;
            return _internalAddress!;
          }
        }
      }

      // 2. Fallback to first non-loopback IPv4 address
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !addr.isLinkLocal) {
            _internalAddress = addr;
            return _internalAddress!;
          }
        }
      }
    } catch (e) {
      dev.log(
        'Error discovering internal interface: $e',
        name: 'libp2p.nat.upnp',
      );
    }

    throw const NoInternalAddressException();
  }

  static bool _isSameSubnet(String ip1, String ip2) {
    final p1 = ip1.split('.');
    final p2 = ip2.split('.');
    if (p1.length == 4 && p2.length == 4) {
      // Compare first 3 octets (standard /24 subnet)
      return p1[0] == p2[0] && p1[1] == p2[1] && p1[2] == p2[2];
    }
    return false;
  }

  @override
  Future<InternetAddress> getExternalAddress() async {
    final client = HttpClient();
    try {
      final req = await client
          .postUrl(Uri.parse(controlUrl))
          .timeout(httpTimeout);
      final soap =
          '<?xml version="1.0"?>'
          '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
          '<s:Body>'
          '<u:GetExternalIPAddress xmlns:u="$serviceType"/>'
          '</s:Body>'
          '</s:Envelope>';
      final bytes = utf8.encode(soap);
      req.headers.set('SOAPAction', '"$serviceType#GetExternalIPAddress"');
      req.headers.set('Content-Type', 'text/xml; charset="utf-8"');
      req.headers.set('Connection', 'Close');
      req.contentLength = bytes.length;
      req.add(bytes);

      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await utf8.decodeStream(resp);
        final match = RegExp(
          r'<NewExternalIPAddress>([^<]+)</NewExternalIPAddress>',
        ).firstMatch(body);
        if (match != null) {
          final ipStr = match.group(1)?.trim();
          if (ipStr != null && ipStr.isNotEmpty) {
            return InternetAddress(ipStr);
          }
        }
      }
    } catch (e) {
      dev.log('GetExternalAddress error: $e', name: 'libp2p.nat.upnp');
    } finally {
      client.close();
    }
    throw const NoExternalAddressException();
  }

  @override
  Future<int> addPortMapping(
    String protocol,
    int internalPort,
    String description,
    Duration timeout,
  ) async {
    final internalIp = await getInternalAddress();
    final requestedExtPort = ports[internalPort] ?? internalPort;

    // 1. Try with requested timeout
    final port = await _sendAddPortMapping(
      protocol: protocol,
      internalPort: internalPort,
      externalPort: requestedExtPort,
      internalIp: internalIp.address,
      description: description,
      timeoutInSeconds: timeout.inSeconds,
    );
    if (port != null) {
      ports[internalPort] = port;
      return port;
    }

    // 2. Fallback: some hardware requires LeaseDuration = 0 (permanent lease)
    if (timeout.inSeconds != 0) {
      final fallbackPort = await _sendAddPortMapping(
        protocol: protocol,
        internalPort: internalPort,
        externalPort: requestedExtPort,
        internalIp: internalIp.address,
        description: description,
        timeoutInSeconds: 0,
      );
      if (fallbackPort != null) {
        ports[internalPort] = fallbackPort;
        return fallbackPort;
      }
    }

    // 3. Fallback: try up to 3 random external ports (like Go upstream)
    for (var i = 0; i < 3; i++) {
      final randPort = randomPort();
      final port = await _sendAddPortMapping(
        protocol: protocol,
        internalPort: internalPort,
        externalPort: randPort,
        internalIp: internalIp.address,
        description: description,
        timeoutInSeconds: 0,
      );
      if (port != null) {
        ports[internalPort] = port;
        return port;
      }
    }

    throw Exception('Failed to add port mapping for $protocol:$internalPort');
  }

  Future<int?> _sendAddPortMapping({
    required String protocol,
    required int internalPort,
    required int externalPort,
    required String internalIp,
    required String description,
    required int timeoutInSeconds,
  }) async {
    final client = HttpClient();
    try {
      final req = await client
          .postUrl(Uri.parse(controlUrl))
          .timeout(httpTimeout);
      final soap =
          '<?xml version="1.0"?>'
          '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
          '<s:Body>'
          '<u:AddPortMapping xmlns:u="$serviceType">'
          '<NewRemoteHost></NewRemoteHost>'
          '<NewExternalPort>$externalPort</NewExternalPort>'
          '<NewProtocol>${protocol.toUpperCase()}</NewProtocol>'
          '<NewInternalPort>$internalPort</NewInternalPort>'
          '<NewInternalClient>$internalIp</NewInternalClient>'
          '<NewEnabled>1</NewEnabled>'
          '<NewPortMappingDescription>$description</NewPortMappingDescription>'
          '<NewLeaseDuration>$timeoutInSeconds</NewLeaseDuration>'
          '</u:AddPortMapping>'
          '</s:Body>'
          '</s:Envelope>';
      final bytes = utf8.encode(soap);
      req.headers.set('SOAPAction', '"$serviceType#AddPortMapping"');
      req.headers.set('Content-Type', 'text/xml; charset="utf-8"');
      req.headers.set('Connection', 'Close');
      req.contentLength = bytes.length;
      req.add(bytes);

      final resp = await req.close();
      if (resp.statusCode == 200) {
        return externalPort;
      }
    } catch (_) {
    } finally {
      client.close();
    }
    return null;
  }

  @override
  Future<void> deletePortMapping(String protocol, int internalPort) async {
    final externalPort = ports.remove(internalPort) ?? internalPort;
    final client = HttpClient();
    try {
      final req = await client
          .postUrl(Uri.parse(controlUrl))
          .timeout(httpTimeout);
      final soap =
          '<?xml version="1.0"?>'
          '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
          '<s:Body>'
          '<u:DeletePortMapping xmlns:u="$serviceType">'
          '<NewRemoteHost></NewRemoteHost>'
          '<NewExternalPort>$externalPort</NewExternalPort>'
          '<NewProtocol>${protocol.toUpperCase()}</NewProtocol>'
          '</u:DeletePortMapping>'
          '</s:Body>'
          '</s:Envelope>';
      final bytes = utf8.encode(soap);
      req.headers.set('SOAPAction', '"$serviceType#DeletePortMapping"');
      req.headers.set('Content-Type', 'text/xml; charset="utf-8"');
      req.headers.set('Connection', 'Close');
      req.contentLength = bytes.length;
      req.add(bytes);

      final resp = await req.close();
      await resp.drain<void>();
    } catch (_) {
    } finally {
      client.close();
    }
  }
}

/// Discovers InternetGatewayDevice 1 UPnP devices.
Future<(List<Nat>, List<Exception>)> _discoverUpnpIg1({
  Duration timeout = const Duration(seconds: 3),
}) async {
  return _discoverSsdpTarget(
    'urn:schemas-upnp-org:device:InternetGatewayDevice:1',
    timeout: timeout,
    typ: 'UPNP (IG1)',
  );
}

/// Discovers InternetGatewayDevice 2 UPnP devices.
Future<(List<Nat>, List<Exception>)> _discoverUpnpIg2({
  Duration timeout = const Duration(seconds: 3),
}) async {
  return _discoverSsdpTarget(
    'urn:schemas-upnp-org:device:InternetGatewayDevice:2',
    timeout: timeout,
    typ: 'UPNP (IG2)',
  );
}

/// Generic fallback discovering any InternetGatewayDevice on the network.
Future<(List<Nat>, List<Exception>)> _discoverUpnpGenIgDev({
  Duration timeout = const Duration(seconds: 3),
}) async {
  return _discoverSsdpTarget('ssdp:all', timeout: timeout, typ: 'UPNP (GenIG)');
}

Future<(List<Nat>, List<Exception>)> _discoverSsdpTarget(
  String target, {
  required Duration timeout,
  required String typ,
}) async {
  final nats = <Nat>[];
  final errs = <Exception>[];

  RawDatagramSocket? socket;
  try {
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;

    final msg =
        'M-SEARCH * HTTP/1.1\r\n'
        'HOST: 239.255.255.250:1900\r\n'
        'MAN: "ssdp:discover"\r\n'
        'MX: 2\r\n'
        'ST: $target\r\n\r\n';

    final dest = InternetAddress('239.255.255.250');
    socket.send(utf8.encode(msg), dest, 1900);

    final locations = <String>{};
    final completer = Completer<void>();

    final timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete();
    });

    socket.listen((event) {
      if (event == RawSocketEvent.read) {
        final dg = socket?.receive();
        if (dg != null) {
          final text = utf8.decode(dg.data, allowMalformed: true);
          for (final line in text.split('\r\n')) {
            if (line.toLowerCase().startsWith('location:')) {
              final loc = line.substring(9).trim();
              if (loc.isNotEmpty) {
                locations.add(loc);
              }
            }
          }
        }
      }
    });

    await completer.future;
    timer.cancel();

    // Query discovered locations for WANIPConnection or WANPPPConnection service
    for (final loc in locations) {
      try {
        final nat = await _inspectDeviceXml(loc, typ);
        if (nat != null) {
          nats.add(nat);
        }
      } catch (e) {
        errs.add(e is Exception ? e : Exception(e.toString()));
      }
    }
  } catch (e) {
    errs.add(e is Exception ? e : Exception(e.toString()));
  } finally {
    socket?.close();
  }

  // Also check standard local router endpoint if multicast was filtered
  if (nats.isEmpty) {
    try {
      final fallback = _UpnpNat(
        controlUrl: 'http://192.168.1.1:52869/upnp/control/WANIPConn1',
        serviceType: 'urn:schemas-upnp-org:service:WANIPConnection:1',
        typ: typ,
      );
      // Quick verify with getExternalAddress
      await fallback.getExternalAddress();
      nats.add(fallback);
    } catch (_) {}
  }

  return (nats, errs);
}

Future<Nat?> _inspectDeviceXml(String location, String typ) async {
  final client = HttpClient();
  try {
    final uri = Uri.parse(location);
    final req = await client.getUrl(uri).timeout(const Duration(seconds: 3));
    final resp = await req.close();
    if (resp.statusCode == 200) {
      final xml = await utf8.decodeStream(resp);

      // Search for WANIPConnection:1, WANIPConnection:2 or WANPPPConnection:1
      final serviceMatches = [
        'urn:schemas-upnp-org:service:WANIPConnection:1',
        'urn:schemas-upnp-org:service:WANIPConnection:2',
        'urn:schemas-upnp-org:service:WANPPPConnection:1',
      ];

      for (final srv in serviceMatches) {
        if (xml.contains(srv)) {
          // Extract controlURL
          final controlMatch = RegExp(
            r'<serviceType>' +
                RegExp.escape(srv) +
                r'</serviceType>[\s\S]*?<controlURL>([^<]+)</controlURL>',
          ).firstMatch(xml);

          if (controlMatch != null) {
            var controlPath = controlMatch.group(1)!.trim();
            final controlUri = controlPath.startsWith('http')
                ? Uri.parse(controlPath)
                : uri.resolve(controlPath);

            return _UpnpNat(
              controlUrl: controlUri.toString(),
              serviceType: srv,
              typ: typ,
            );
          }
        }
      }
    }
  } catch (_) {
  } finally {
    client.close();
  }
  return null;
}
