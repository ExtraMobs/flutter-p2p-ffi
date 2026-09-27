/// Sistema de arquivos e processo, independente de plataforma: `dart:io` na
/// VM/AOT; um stub que reporta "sem suporte" no JS/Wasm (onde `dart:io` não
/// existe). `os.dart` (parte `file.dart`) consome só esta API, nunca
/// `dart:io` diretamente, para rodar igual nas quatro plataformas (ver
/// `src/runtime/output.dart`, mesmo padrão).
library;

export 'backend_io.dart' if (dart.library.js_interop) 'backend_web.dart';
