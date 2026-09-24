part of 'protocol.dart';

// Port of pkg/protocol/application_data.go.

/// ApplicationData messages are carried by the record layer and are
/// fragmented, compressed, and encrypted based on the current connection
/// state. The messages are treated as transparent data to the record layer.
/// https://tools.ietf.org/html/rfc5246#section-10
///
/// Port of `ApplicationData` (application_data.go:9-11) and its methods
/// `ContentType`/`Marshal`/`Unmarshal` (application_data.go:14-28).
final class ApplicationData implements Content {
  Uint8List data;

  ApplicationData([Uint8List? data]) : data = data ?? Uint8List(0);

  @override
  ContentType contentType() => ContentType.applicationData;

  @override
  Uint8List marshal() => Uint8List.fromList(data);

  @override
  void unmarshal(Uint8List raw) {
    data = Uint8List.fromList(raw);
  }
}
