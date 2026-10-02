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

/// Encerra o processo (depois de descarregar stdout).
Never exitProcess(int code) => exit(code);
