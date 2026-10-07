/// Sem `dart:ffi` (dart2js, dart2wasm): não há rede FFI.
///
/// É também o que a análise estática enxerga em `ffi.dart`: o que as etapas
/// seguintes expuserem por lá precisa existir aqui com a mesma assinatura
/// (só com tipos de `common.dart`), falhando como o Go em js/wasm (F4).
library;

/// A rede FFI existe neste processo: nunca, aqui.
bool get sysFfiAvailable => false;
