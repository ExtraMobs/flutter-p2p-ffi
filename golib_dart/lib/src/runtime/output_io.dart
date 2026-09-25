import 'dart:io';

/// Escreve os bytes exatos em stdout.
void writeStdout(List<int> bytes) => stdout.add(bytes);

/// Mensagem em stderr.
void writeStderr(String text) => stderr.write(text);

/// Encerra o processo (depois de descarregar stdout).
Never exitProcess(int code) => exit(code);
