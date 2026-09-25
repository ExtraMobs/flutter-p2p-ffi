/// Saída padrão em bytes, independente de plataforma: `dart:io` na
/// VM/AOT; `process.stdout` (Node) ou `print` por linha (navegador) no JS/Wasm.
library;

export 'output_io.dart' if (dart.library.js_interop) 'output_web.dart';
