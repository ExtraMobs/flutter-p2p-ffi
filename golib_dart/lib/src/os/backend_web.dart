/// Backend de `os` no JS/Wasm: `dart:io` não existe nessas plataformas, então
/// todo acesso a sistema de arquivos e a processo (exceto variáveis de
/// ambiente, que ficam num overlay em memória — ver `src/os/env.dart`) devolve
/// "sem suporte". `os.dart` (parte `file.dart`) traduz [OsFail] com
/// `errno == -1` para `errors.ErrUnsupported`. ⚠️ Limite documentado em
/// `docs/mapping-spec.md`.
library;

/// Alça de um arquivo aberto: nunca existe de fato aqui (todo `open` falha).
typedef Handle = Never;

/// Este backend não dá suporte real a arquivos.
const bool available = false;

/// Falha de uma chamada; `errno == -1` é a sentinela "sem suporte".
final class OsFail implements Exception {
  OsFail(this.errno, this.message);

  final int? errno;
  final String message;

  @override
  String toString() => message;
}

Never _unsupported() => throw OsFail(-1, 'unsupported operation');

final class StatResult {
  StatResult({
    required this.isDir,
    required this.isSymlink,
    required this.isFile,
    required this.size,
    required this.perm,
  });

  final bool isDir, isSymlink, isFile;
  final int size, perm;
}

bool exists(String path) => false;

StatResult stat(String path, {required bool followLinks}) => _unsupported();

void chmod(String path, int perm) => _unsupported();

Handle openFile(
  String path, {
  required int accmode,
  required bool create,
  required bool excl,
  required bool trunc,
  required bool append,
  required int perm,
}) => _unsupported();

int readInto(Handle h, List<int> buf, int start, int end) => _unsupported();
void writeFrom(Handle h, List<int> buf, int start, int end) => _unsupported();
int position(Handle h) => _unsupported();
void setPosition(Handle h, int pos) => _unsupported();
int length(Handle h) => _unsupported();
void truncate(Handle h, int size) => _unsupported();
void flush(Handle h) => _unsupported();
void closeHandle(Handle h) => _unsupported();
int readAt(Handle h, List<int> buf, int start, int end, int off) => _unsupported();
void writeAt(Handle h, List<int> buf, int start, int end, int off) => _unsupported();
int fd(Handle h) => _unsupported();

void mkdir(String path, int perm) => _unsupported();
void mkdirAll(String path, int perm) => _unsupported();
void remove(String path) => _unsupported();
void removeAll(String path) => _unsupported();
void rename(String oldPath, String newPath) => _unsupported();
void symlink(String target, String linkPath) => _unsupported();
String readlink(String path) => _unsupported();

final class RawEntry {
  RawEntry(this.name, this.isDir, this.isSymlink);
  final String name;
  final bool isDir, isSymlink;
}

List<RawEntry> listDir(String path) => _unsupported();

String getwd() => _unsupported();
void chdir(String path) => _unsupported();
String mkdirTemp(String dir, String prefix) => _unsupported();
(String, Handle) createTemp(String dir, String prefix) => _unsupported();
List<int> readFile(String path) => _unsupported();
void writeFile(String path, List<int> bytes, {required bool append, required int perm}) => _unsupported();

// ---------------------------------------------------------------- processo
//
// Sem `dart:io`, não há id de processo, hostname nem caminho do executável
// verdadeiros (nem no Node nem no navegador, sem interop extra); devolve os
// valores neutros do Go para plataforma sem suporte.

int currentPid() => 0;

String hostname() => '';

String executable() => '';

String? env(String key) => null;

Map<String, String> environAll() => const {};
