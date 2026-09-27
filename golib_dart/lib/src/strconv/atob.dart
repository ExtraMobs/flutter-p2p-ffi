part of '../../strconv.dart';

const _boolStrings = <String, bool>{
  '1': true, 't': true, 'T': true, 'true': true, 'TRUE': true, 'True': true,
  '0': false, 'f': false, 'F': false, 'false': false, 'FALSE': false, 'False': false,
};

/// `strconv.ParseBool(str)`: aceita `1 t T true TRUE True 0 f F false FALSE
/// False`; qualquer outro valor é `ErrSyntax`.
(bool, GoError?) parseBool(Golang.String str) {
  final b = _boolStrings[str.toString()];
  if (b == null) return (false, NumError('ParseBool', str, errSyntax));
  return (b, null);
}

/// `strconv.FormatBool(b)`.
Golang.String formatBool(bool b) => Golang.String.fromDart(b ? 'true' : 'false');

/// `strconv.AppendBool(dst, b)`.
Slice<Golang.Uint8> appendBool(Slice<Golang.Uint8> dst, bool b) =>
    dst.append(_asciiBytes(formatBool(b)));
