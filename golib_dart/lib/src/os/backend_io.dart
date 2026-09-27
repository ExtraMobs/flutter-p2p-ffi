/// Backend real de `os` (VM/AOT, com `dart:io`). API crua (tipos Dart, sem
/// `Golang.*`): quem traduz para os tipos e erros do Go é `os.dart` (parte
/// `file.dart`), que também é quem importa este arquivo (nunca o contrário,
/// para não formar ciclo entre os dois lados do import condicional).
library;

import 'dart:io' as io;

/// Alça de um arquivo aberto.
typedef Handle = io.RandomAccessFile;

/// Este backend dá suporte real a arquivos (`dart:io` existe aqui).
const bool available = true;

/// Falha de uma chamada: [errno] no padrão Linux (`man errno`) quando
/// conhecido; `-1` sinaliza "sem suporte nesta plataforma" (só o backend web
/// usa; existe aqui só para a assinatura ser igual nos dois backends).
final class OsFail implements Exception {
  OsFail(this.errno, this.message);

  final int? errno;
  final String message;

  @override
  String toString() => message;
}

Never _throw(Object e) {
  if (e is OsFail) throw e;
  if (e is io.FileSystemException) {
    final os = e.osError;
    throw OsFail(os?.errorCode, os?.message ?? e.message);
  }
  if (e is io.OSError) throw OsFail(e.errorCode, e.message);
  throw OsFail(null, '$e');
}

T _run<T>(T Function() f) {
  try {
    return f();
  } catch (e) {
    _throw(e);
  }
}

const _enoent = 2, _eexist = 17, _eisdir = 21;

io.FileSystemEntityType _typeOf(String path, {bool followLinks = true}) =>
    io.FileSystemEntity.typeSync(path, followLinks: followLinks);

bool exists(String path) => _typeOf(path) != io.FileSystemEntityType.notFound;

/// Resultado de [stat]: campos crus (bits de permissão Unix inclusos).
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

/// `stat`/`lstat`: [followLinks] falso não segue o link final do caminho.
StatResult stat(String path, {required bool followLinks}) => _run(() {
  final type = _typeOf(path, followLinks: followLinks);
  if (type == io.FileSystemEntityType.notFound) {
    throw OsFail(_enoent, 'No such file or directory');
  }
  if (type == io.FileSystemEntityType.link) {
    // Lstat de um link: dart:io não expõe o stat do link em si (só do alvo),
    // então aproxima-se pelos bits fixos `lrwxrwxrwx` e o tamanho do texto
    // do alvo (como o Go: `st_size` de um symlink é o tamanho do texto).
    final target = io.Link(path).targetSync();
    return StatResult(isDir: false, isSymlink: true, isFile: false, size: target.length, perm: 0x1ff);
  }
  final st = io.FileStat.statSync(path);
  return StatResult(
    isDir: type == io.FileSystemEntityType.directory,
    isSymlink: false,
    isFile: type == io.FileSystemEntityType.file,
    size: st.size,
    perm: st.mode & 0x1ff,
  );
});

void _chmodBestEffort(String path, int perm) {
  try {
    io.Process.runSync('chmod', [(perm & 0x1ff).toRadixString(8), path]);
  } catch (_) {
    // Melhor esforço: sem `chmod` no PATH, o arquivo fica com o modo padrão
    // do sistema (umask), como aconteceria num Go sem CAP_CHOWN nem isso.
  }
}

/// `os.Chmod`.
void chmod(String path, int perm) => _run(() {
  if (!exists(path)) throw OsFail(_enoent, 'No such file or directory');
  final r = io.Process.runSync('chmod', [(perm & 0xfff).toRadixString(8), path]);
  if (r.exitCode != 0) throw OsFail(null, '$r.stderr'.trim());
});

/// `os.OpenFile`: `accmode` 0=RDONLY, 1=WRONLY, 2=RDWR (como as flags do Go).
Handle openFile(
  String path, {
  required int accmode,
  required bool create,
  required bool excl,
  required bool trunc,
  required bool append,
  required int perm,
}) => _run(() {
  final wantWrite = accmode != 0;
  final type = _typeOf(path);
  final existed = type != io.FileSystemEntityType.notFound;
  if (existed && type == io.FileSystemEntityType.directory && wantWrite) {
    throw OsFail(_eisdir, 'Is a directory');
  }
  if (create && excl && existed) throw OsFail(_eexist, 'File exists');
  if (!create && !existed) throw OsFail(_enoent, 'No such file or directory');
  if (!wantWrite) {
    if (!existed) {
      io.File(path).createSync();
      _chmodBestEffort(path, perm);
    }
    return io.File(path).openSync(mode: io.FileMode.read);
  }
  final wantRead = accmode == 2;
  final io.FileMode mode;
  if (trunc) {
    mode = wantRead ? io.FileMode.write : io.FileMode.writeOnly;
  } else {
    // Sem O_TRUNC: `append`/`writeOnlyAppend` não truncam ao abrir (só
    // `write`/`writeOnly` truncam). Sem O_APPEND, a posição volta a 0 abaixo.
    mode = wantRead ? io.FileMode.append : io.FileMode.writeOnlyAppend;
  }
  final freshlyCreated = !existed;
  final h = io.File(path).openSync(mode: mode);
  if (!append && !trunc) h.setPositionSync(0);
  if (freshlyCreated) _chmodBestEffort(path, perm);
  return h;
});

int readInto(Handle h, List<int> buf, int start, int end) => _run(() => h.readIntoSync(buf, start, end));

void writeFrom(Handle h, List<int> buf, int start, int end) => _run(() => h.writeFromSync(buf, start, end));

int position(Handle h) => _run(() => h.positionSync());

void setPosition(Handle h, int pos) => _run(() => h.setPositionSync(pos));

int length(Handle h) => _run(() => h.lengthSync());

void truncate(Handle h, int size) => _run(() => h.truncateSync(size));

void flush(Handle h) => _run(() => h.flushSync());

void closeHandle(Handle h) => _run(() => h.closeSync());

/// Lê `count` bytes a partir de `off` sem mover a posição corrente do
/// arquivo (salva e restaura, já que `dart:io` não tem `pread`).
int readAt(Handle h, List<int> buf, int start, int end, int off) => _run(() {
  final saved = h.positionSync();
  try {
    h.setPositionSync(off);
    return h.readIntoSync(buf, start, end);
  } finally {
    h.setPositionSync(saved);
  }
});

void writeAt(Handle h, List<int> buf, int start, int end, int off) => _run(() {
  final saved = h.positionSync();
  try {
    h.setPositionSync(off);
    h.writeFromSync(buf, start, end);
  } finally {
    h.setPositionSync(saved);
  }
});

int fd(Handle h) => h.fd;

void mkdir(String path, int perm) => _run(() {
  if (exists(path)) throw OsFail(_eexist, 'File exists');
  io.Directory(path).createSync();
  _chmodBestEffort(path, perm);
});

void mkdirAll(String path, int perm) => _run(() {
  if (_typeOf(path) == io.FileSystemEntityType.directory) return;
  io.Directory(path).createSync(recursive: true);
  _chmodBestEffort(path, perm);
});

void remove(String path) => _run(() {
  final type = _typeOf(path, followLinks: false);
  if (type == io.FileSystemEntityType.notFound) throw OsFail(_enoent, 'No such file or directory');
  if (type == io.FileSystemEntityType.directory) {
    io.Directory(path).deleteSync();
  } else if (type == io.FileSystemEntityType.link) {
    io.Link(path).deleteSync();
  } else {
    io.File(path).deleteSync();
  }
});

void removeAll(String path) => _run(() {
  final type = _typeOf(path, followLinks: false);
  if (type == io.FileSystemEntityType.notFound) return;
  if (type == io.FileSystemEntityType.directory) {
    io.Directory(path).deleteSync(recursive: true);
  } else if (type == io.FileSystemEntityType.link) {
    io.Link(path).deleteSync();
  } else {
    io.File(path).deleteSync();
  }
});

void rename(String oldPath, String newPath) => _run(() {
  final type = _typeOf(oldPath, followLinks: false);
  if (type == io.FileSystemEntityType.notFound) throw OsFail(_enoent, 'No such file or directory');
  if (type == io.FileSystemEntityType.directory) {
    io.Directory(oldPath).renameSync(newPath);
  } else if (type == io.FileSystemEntityType.link) {
    io.Link(oldPath).renameSync(newPath);
  } else {
    io.File(oldPath).renameSync(newPath);
  }
});

void symlink(String target, String linkPath) => _run(() {
  if (exists(linkPath)) throw OsFail(_eexist, 'File exists');
  io.Link(linkPath).createSync(target);
});

String readlink(String path) => _run(() {
  if (_typeOf(path, followLinks: false) != io.FileSystemEntityType.link) {
    throw OsFail(22, 'Invalid argument');
  }
  return io.Link(path).targetSync();
});

/// Uma entrada de diretório crua (nome + tipo).
final class RawEntry {
  RawEntry(this.name, this.isDir, this.isSymlink);
  final String name;
  final bool isDir, isSymlink;
}

List<RawEntry> listDir(String path) => _run(() {
  final type = _typeOf(path);
  if (type == io.FileSystemEntityType.notFound) throw OsFail(_enoent, 'No such file or directory');
  if (type != io.FileSystemEntityType.directory) throw OsFail(20, 'Not a directory');
  final out = <RawEntry>[];
  for (final e in io.Directory(path).listSync(followLinks: false)) {
    final base = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
    final et = _typeOf(e.path, followLinks: false);
    out.add(RawEntry(base, et == io.FileSystemEntityType.directory, et == io.FileSystemEntityType.link));
  }
  return out;
});

String getwd() => _run(() => io.Directory.current.path);

void chdir(String path) => _run(() {
  if (_typeOf(path) != io.FileSystemEntityType.directory) throw OsFail(_enoent, 'No such file or directory');
  io.Directory.current = path;
});

String mkdirTemp(String dir, String prefix) =>
    _run(() => io.Directory(dir.isEmpty ? io.Directory.systemTemp.path : dir).createTempSync(prefix).path);

/// `os.CreateTemp`: cria e já devolve a alça aberta (`O_RDWR|O_CREATE|O_EXCL`).
(String, Handle) createTemp(String dir, String prefix) => _run(() {
  final base = dir.isEmpty ? io.Directory.systemTemp.path : dir;
  final f = io.File(
    '$base${io.Platform.pathSeparator}$prefix${DateTime.now().microsecondsSinceEpoch}',
  );
  final h = f.openSync(mode: io.FileMode.write);
  return (f.path, h);
});

List<int> readFile(String path) => _run(() {
  if (_typeOf(path) == io.FileSystemEntityType.notFound) throw OsFail(_enoent, 'No such file or directory');
  return io.File(path).readAsBytesSync();
});

void writeFile(String path, List<int> bytes, {required bool append, required int perm}) => _run(() {
  final freshlyCreated = !exists(path);
  io.File(path).writeAsBytesSync(bytes, mode: append ? io.FileMode.append : io.FileMode.write);
  if (freshlyCreated) _chmodBestEffort(path, perm);
});

// ---------------------------------------------------------------- processo

int currentPid() => io.pid;

String hostname() => _run(() => io.Platform.localHostname);

String executable() => _run(() => io.Platform.resolvedExecutable);

String? env(String key) => io.Platform.environment[key];

Map<String, String> environAll() => io.Platform.environment;
