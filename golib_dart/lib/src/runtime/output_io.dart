import 'dart:io';

/// Escreve os bytes exatos em stdout.
void writeStdout(List<int> bytes) => stdout.add(bytes);

/// Escreve os bytes exatos em stderr.
void writeStderrBytes(List<int> bytes) => stderr.add(bytes);

/// Variável de ambiente, ou `null` se não definida.
String? getEnv(String key) => Platform.environment[key];

/// PID do processo.
int getPid() => pid;

/// Mensagem em stderr.
void writeStderr(String text) => stderr.write(text);

/// Descarrega os buffers de stdout/stderr. `exit()` do `dart:io` encerra o
/// processo sem esperar I/O assíncrono pendente — quem for chamar
/// [exitProcess] (`runMain`, `fatal`, panic de goroutine) descarrega antes,
/// ou perde saída já escrita (bug conhecido do `dart:io`, ver
/// https://github.com/dart-lang/sdk/issues/32061).
Future<void> flushOutput() async {
  await stdout.flush();
  await stderr.flush();
}

/// Encerra o processo. Chame [flushOutput] antes.
Never exitProcess(int code) => exit(code);

/// Só existe pro `dart2js` (ver `output_web.dart`): a VM não precisa de
/// ajuda pra agendar microtasks/timers.
void ensureAsyncScheduling() {}
