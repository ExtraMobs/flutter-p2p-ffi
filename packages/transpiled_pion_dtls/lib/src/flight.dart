/// DTLS flight identifier.
enum FlightVal {
  flight0(1),
  flight1(2),
  flight2(3),
  flight3(4),
  flight4(5),
  flight4b(6),
  flight5(7),
  flight5b(8),
  flight6(9);

  final int value;
  const FlightVal(this.value);

  String string() {
    switch (this) {
      case FlightVal.flight0:
        return 'Flight 0';
      case FlightVal.flight1:
        return 'Flight 1';
      case FlightVal.flight2:
        return 'Flight 2';
      case FlightVal.flight3:
        return 'Flight 3';
      case FlightVal.flight4:
        return 'Flight 4';
      case FlightVal.flight4b:
        return 'Flight 4b';
      case FlightVal.flight5:
        return 'Flight 5';
      case FlightVal.flight5b:
        return 'Flight 5b';
      case FlightVal.flight6:
        return 'Flight 6';
    }
  }

  bool isLastSendFlight() =>
      this == FlightVal.flight6 || this == FlightVal.flight5b;
  bool isLastRecvFlight() =>
      this == FlightVal.flight6 || this == FlightVal.flight5b;
}
