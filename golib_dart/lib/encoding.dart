/// Shim do pacote Go `encoding`: as interfaces de (de)serialização que os
/// codecs (`encoding/json`...) procuram nos valores.
///
/// Entram em `SHIM_INTERFACES` (`g2d/config.py`): um tipo gerado com
/// `MarshalText() ([]byte, error)` declara `implements encoding.TextMarshaler`.
// ignore_for_file: library_prefixes
library;

import 'builtin.dart';
import 'fixed_types/golang.dart' as Golang;

/// `encoding.TextMarshaler`.
abstract interface class TextMarshaler {
  (Slice<Golang.Uint8>, GoError?) marshalText();
}

/// `encoding.TextUnmarshaler`.
abstract interface class TextUnmarshaler {
  GoError? unmarshalText(Slice<Golang.Uint8> text);
}

/// `encoding.BinaryMarshaler`.
abstract interface class BinaryMarshaler {
  (Slice<Golang.Uint8>, GoError?) marshalBinary();
}

/// `encoding.BinaryUnmarshaler`.
abstract interface class BinaryUnmarshaler {
  GoError? unmarshalBinary(Slice<Golang.Uint8> data);
}
