part of '../../os.dart';

// -------------------------------------------------------------- flags/consts

/// `os.O_RDONLY`.
const int o_RDONLY = 0x0;

/// `os.O_WRONLY`.
const int o_WRONLY = 0x1;

/// `os.O_RDWR`.
const int o_RDWR = 0x2;

/// `os.O_APPEND`.
const int o_APPEND = 0x400;

/// `os.O_CREATE`.
const int o_CREATE = 0x40;

/// `os.O_EXCL`.
const int o_EXCL = 0x80;

/// `os.O_SYNC`.
const int o_SYNC = 0x101000;

/// `os.O_TRUNC`.
const int o_TRUNC = 0x200;

/// `os.SEEK_SET` (obsoleto no Go; use `io.SeekStart`).
const int seek_SET = 0;

/// `os.SEEK_CUR` (obsoleto no Go; use `io.SeekCurrent`).
const int seek_CUR = 1;

/// `os.SEEK_END` (obsoleto no Go; use `io.SeekEnd`).
const int seek_END = 2;

/// `os.PathSeparator` (`'/'`, GOOS=linux do `BUILD_ENV`).
final Golang.Rune pathSeparator = Golang.Rune(0x2f);

/// `os.PathListSeparator` (`':'`).
final Golang.Rune pathListSeparator = Golang.Rune(0x3a);

/// `os.DevNull`.
final Golang.String devNull = Golang.String.fromDart('/dev/null');

/// `fs.ModePerm` reexportado como `os.ModePerm`, e as demais `os.Mode*`
/// (mesmos valores de `fs.Mode*`; o Go os declara à parte, em `os`).
final fs.FileMode modePerm = fs.modePerm;
final fs.FileMode modeDir = fs.modeDir;
final fs.FileMode modeAppend = fs.modeAppend;
final fs.FileMode modeExclusive = fs.modeExclusive;
final fs.FileMode modeTemporary = fs.modeTemporary;
final fs.FileMode modeSymlink = fs.modeSymlink;
final fs.FileMode modeDevice = fs.modeDevice;
final fs.FileMode modeNamedPipe = fs.modeNamedPipe;
final fs.FileMode modeSocket = fs.modeSocket;
final fs.FileMode modeSetuid = fs.modeSetuid;
final fs.FileMode modeSetgid = fs.modeSetgid;
final fs.FileMode modeCharDevice = fs.modeCharDevice;
final fs.FileMode modeSticky = fs.modeSticky;
final fs.FileMode modeIrregular = fs.modeIrregular;
final fs.FileMode modeType = fs.modeType;
