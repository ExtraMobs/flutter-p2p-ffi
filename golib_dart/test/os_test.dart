import 'package:golib_dart/errors.dart' as errors;
import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:golib_dart/io/fs.dart' as fs;
import 'package:golib_dart/os.dart' as os;
import 'package:test/test.dart';

Golang.String s(String v) => Golang.String.fromDart(v);

void main() {
  test('FileMode.String como o Go', () {
    expect(fs.FileMode(420).string().toString(), '-rw-r--r--');
    expect(fs.FileMode(511).string().toString(), '-rwxrwxrwx');
    expect(fs.FileMode(0x80000000 + 493).string().toString(), 'drwxr-xr-x');
    expect(fs.FileMode(0x80000000 + 493).isDir(), isTrue);
    expect(fs.FileMode(0x80000000 + 493).isRegular(), isFalse);
    expect(fs.FileMode(420).isRegular(), isTrue);
    expect(fs.FileMode(0x80000000 + 493).type().toInt(), 0x80000000);
    expect(fs.FileMode(0x80000000 + 493).perm().toInt(), 493);
    expect(fs.FileMode(0).string().toString(), '----------');
  });

  test('erros sentinela e IsNotExist/IsExist/IsPermission', () {
    expect(os.errNotExist.error().toString(), 'file does not exist');
    expect(os.errExist.error().toString(), 'file already exists');
    expect(os.errPermission.error().toString(), 'permission denied');
    expect(os.errClosed.error().toString(), 'file already closed');
    expect(os.errInvalid.error().toString(), 'invalid argument');
    expect(os.errDeadlineExceeded.error().toString(), 'i/o timeout');
    final pe = fs.PathError(op: s('open'), path: s('/x'), err: os.errNotExist);
    expect(pe.error().toString(), 'open /x: file does not exist');
    expect(os.isNotExist(pe), isTrue);
    expect(os.isNotExist(os.errNotExist), isTrue);
    expect(os.isExist(pe), isFalse);
    expect(os.isPermission(os.errPermission), isTrue);
    expect(os.isNotExist(null), isFalse);
    expect(errors.is$(pe, os.errNotExist), isTrue);
    expect(os.isTimeout(os.errDeadlineExceeded), isTrue);
    expect(os.isTimeout(pe), isFalse);
  });

  test('Getenv de variável inexistente', () {
    final k = s('G2D_VARIAVEL_QUE_NAO_EXISTE');
    expect(os.getenv(k).toString(), '');
    expect(os.lookupEnv(k).$2, isFalse);
  });

  test('File: Close duas vezes, escrita depois de fechar, Stdin', () {
    final f = os.stdin;
    final (n, err) = f.writeString(s('x'));
    expect(n.toInt(), 0);
    expect(err!.error().toString(), 'write /dev/stdin: bad file descriptor');
    expect(os.stdout.name().toString(), '/dev/stdout');
    expect(os.stderr.fd().toInt(), 2);
  });
}
