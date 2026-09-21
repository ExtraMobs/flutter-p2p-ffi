// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:typed_data';

import 'varint.dart';

/// Transport parameter IDs from RFC 9000 Section 18.2 and quic-go.
const int paramOriginalDestinationConnectionId = 0x00;
const int paramMaxIdleTimeout = 0x01;
const int paramStatelessResetToken = 0x02;
const int paramMaxUdpPayloadSize = 0x03;
const int paramInitialMaxData = 0x04;
const int paramInitialMaxStreamDataBidiLocal = 0x05;
const int paramInitialMaxStreamDataBidiRemote = 0x06;
const int paramInitialMaxStreamDataUni = 0x07;
const int paramInitialMaxStreamsBidi = 0x08;
const int paramInitialMaxStreamsUni = 0x09;
const int paramAckDelayExponent = 0x0a;
const int paramMaxAckDelay = 0x0b;
const int paramDisableActiveMigration = 0x0c;
const int paramPreferredAddress = 0x0d;
const int paramActiveConnectionIdLimit = 0x0e;
const int paramInitialSourceConnectionId = 0x0f;
const int paramRetrySourceConnectionId = 0x10;

/// The largest DATAGRAM frame this endpoint accepts, per RFC 9221 Section 3.
/// Its presence is what advertises QUIC datagram support at all; WebTransport
/// requires it, because an HTTP/3 server refuses a session whose client has
/// not enabled datagrams.
const int paramMaxDatagramFrameSize = 0x20;

/// TransportParameters sent during the QUIC TLS handshake (RFC 9000, Section 18).
class TransportParameters {
  TransportParameters({
    this.initialMaxStreamDataBidiLocal = 0,
    this.initialMaxStreamDataBidiRemote = 0,
    this.initialMaxStreamDataUni = 0,
    this.initialMaxData = 0,
    this.initialMaxStreamsBidi = 0,
    this.initialMaxStreamsUni = 0,
    this.maxIdleTimeout = Duration.zero,
    this.maxUdpPayloadSize = 65527,
    this.activeConnectionIdLimit = 2,
    this.initialSourceConnectionId,
    this.originalDestinationConnectionId,
    this.disableActiveMigration = false,
    this.maxDatagramFrameSize = 0,
  });

  int initialMaxStreamDataBidiLocal;
  int initialMaxStreamDataBidiRemote;
  int initialMaxStreamDataUni;
  int initialMaxData;
  int initialMaxStreamsBidi;
  int initialMaxStreamsUni;
  Duration maxIdleTimeout;
  int maxUdpPayloadSize;
  int activeConnectionIdLimit;
  Uint8List? initialSourceConnectionId;
  Uint8List? originalDestinationConnectionId;
  bool disableActiveMigration;

  /// The largest DATAGRAM frame this endpoint accepts; zero omits the
  /// parameter, which tells the peer datagrams are not supported.
  int maxDatagramFrameSize;

  /// Marshals transport parameters to varint-prefixed TLV bytes.
  Uint8List marshal({bool isServer = false}) {
    final buf = BytesBuilder(copy: false);

    void writeVarintParam(int id, int value) {
      final valBytes = appendVarInt(const [], value);
      buf.add(appendVarInt(const [], id));
      buf.add(appendVarInt(const [], valBytes.length));
      buf.add(valBytes);
    }

    void writeBytesParam(int id, Uint8List bytes) {
      buf.add(appendVarInt(const [], id));
      buf.add(appendVarInt(const [], bytes.length));
      buf.add(bytes);
    }

    if (initialMaxStreamDataBidiLocal > 0) {
      writeVarintParam(
        paramInitialMaxStreamDataBidiLocal,
        initialMaxStreamDataBidiLocal,
      );
    }
    if (initialMaxStreamDataBidiRemote > 0) {
      writeVarintParam(
        paramInitialMaxStreamDataBidiRemote,
        initialMaxStreamDataBidiRemote,
      );
    }
    if (initialMaxStreamDataUni > 0) {
      writeVarintParam(paramInitialMaxStreamDataUni, initialMaxStreamDataUni);
    }
    if (initialMaxData > 0) {
      writeVarintParam(paramInitialMaxData, initialMaxData);
    }
    if (initialMaxStreamsBidi > 0) {
      writeVarintParam(paramInitialMaxStreamsBidi, initialMaxStreamsBidi);
    }
    if (initialMaxStreamsUni > 0) {
      writeVarintParam(paramInitialMaxStreamsUni, initialMaxStreamsUni);
    }
    if (maxIdleTimeout > Duration.zero) {
      writeVarintParam(paramMaxIdleTimeout, maxIdleTimeout.inMilliseconds);
    }
    if (maxUdpPayloadSize > 0 && maxUdpPayloadSize != 65527) {
      writeVarintParam(paramMaxUdpPayloadSize, maxUdpPayloadSize);
    }
    if (activeConnectionIdLimit != 2 && activeConnectionIdLimit > 0) {
      writeVarintParam(paramActiveConnectionIdLimit, activeConnectionIdLimit);
    }
    if (disableActiveMigration) {
      buf.add(appendVarInt(const [], paramDisableActiveMigration));
      buf.add(appendVarInt(const [], 0));
    }
    if (maxDatagramFrameSize > 0) {
      writeVarintParam(paramMaxDatagramFrameSize, maxDatagramFrameSize);
    }
    if (initialSourceConnectionId != null) {
      writeBytesParam(
        paramInitialSourceConnectionId,
        initialSourceConnectionId!,
      );
    }
    if (isServer && originalDestinationConnectionId != null) {
      writeBytesParam(
        paramOriginalDestinationConnectionId,
        originalDestinationConnectionId!,
      );
    }

    return buf.toBytes();
  }

  /// Unmarshals transport parameters from raw wire bytes.
  factory TransportParameters.unmarshal(
    Uint8List data, {
    bool isServer = false,
  }) {
    final params = TransportParameters();
    var cursor = 0;

    while (cursor < data.length) {
      final (id, idLen) = parseVarInt(data, cursor);
      cursor += idLen;

      final (valLen, lenLen) = parseVarInt(data, cursor);
      cursor += lenLen;

      if (cursor + valLen > data.length) {
        throw const FormatException('Truncated transport parameter value');
      }

      final valBytes = Uint8List.sublistView(data, cursor, cursor + valLen);
      cursor += valLen;

      switch (id) {
        case paramInitialMaxStreamDataBidiLocal:
          params.initialMaxStreamDataBidiLocal = parseVarInt(valBytes).$1;
        case paramInitialMaxStreamDataBidiRemote:
          params.initialMaxStreamDataBidiRemote = parseVarInt(valBytes).$1;
        case paramInitialMaxStreamDataUni:
          params.initialMaxStreamDataUni = parseVarInt(valBytes).$1;
        case paramInitialMaxData:
          params.initialMaxData = parseVarInt(valBytes).$1;
        case paramInitialMaxStreamsBidi:
          params.initialMaxStreamsBidi = parseVarInt(valBytes).$1;
        case paramInitialMaxStreamsUni:
          params.initialMaxStreamsUni = parseVarInt(valBytes).$1;
        case paramMaxIdleTimeout:
          params.maxIdleTimeout = Duration(
            milliseconds: parseVarInt(valBytes).$1,
          );
        case paramMaxUdpPayloadSize:
          params.maxUdpPayloadSize = parseVarInt(valBytes).$1;
        case paramActiveConnectionIdLimit:
          params.activeConnectionIdLimit = parseVarInt(valBytes).$1;
        case paramDisableActiveMigration:
          params.disableActiveMigration = true;
        case paramMaxDatagramFrameSize:
          params.maxDatagramFrameSize = parseVarInt(valBytes).$1;
        case paramInitialSourceConnectionId:
          params.initialSourceConnectionId = Uint8List.fromList(valBytes);
        case paramOriginalDestinationConnectionId:
          params.originalDestinationConnectionId = Uint8List.fromList(valBytes);
        default:
          // Ignore unknown/greased transport parameters per RFC 9000
          break;
      }
    }

    return params;
  }
}
