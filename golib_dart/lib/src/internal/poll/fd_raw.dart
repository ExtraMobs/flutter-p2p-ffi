part of 'fd.dart';

/// `FD.RawRead`/`FD.RawWrite` (`internal/poll/fd_unix.go`) e as chamadas
/// sem espera que o `f` delas faz (`read(2)`/`write(2)` num fd não
/// bloqueante): o que o `SyscallConn` de uma conexão do `dart:io` oferece
/// pelo descritor virtual. Usam o mesmo [RawSocket] e as mesmas travas de
/// [Fd.read]/[Fd.write], então convivem com eles sem perder nem trocar
/// bytes de ordem.
extension FdRaw on Fd {
  /// O `read(2)` de um fd não bloqueante: os bytes lidos (até [len]), vazio
  /// no EOF, `null` sem dado (o `EAGAIN`). Lança o sentinela de fechado ou
  /// o erro do socket. Não olha prazo (a syscall não olha).
  ///
  /// O fim de leitura vem antes, como em [Fd.read]. No linux o socket é lido
  /// mesmo sem o evento de leitura (o dado já no kernel sai, como no
  /// `read(2)`; ler sem dado devolve `null` sem efeito, conferido no Dart
  /// 3.13.5). ⚠️ O EOF antes do evento `readClosed` também volta `null`: dá
  /// `EAGAIN` até o evento chegar. Fora do linux, só com a prontidão.
  Uint8List? readNow(int len) {
    if (_fdmu.isClosed) throw errClosing(isFile: _isFile);
    if (_pd.readClosed) return Uint8List(0);
    if (_pd.readable || Platform.isLinux) {
      final data = _socket.read(len);
      if (data != null && data.isNotEmpty) {
        if (_socket.available() == 0) _pd.drained();
        return data;
      }
      _pd.readable = false;
    }
    final error = _pd.ioError;
    if (error != null) throw error;
    // O par encerrou por completo (`closed` sem `readClosed`): EOF.
    if (_pd.evicted) return Uint8List(0);
    return null;
  }

  /// O `write(2)` de um fd não bloqueante: quanto o socket aceitou de
  /// [data] (0 é o `EAGAIN`). Lança o sentinela de fechado, o erro do
  /// socket, ou [StateError] se o par já encerrou (o `EPIPE`).
  int writeNow(Uint8List data) {
    if (_fdmu.isClosed) throw errClosing(isFile: _isFile);
    final error = _pd.ioError;
    if (error != null) throw error;
    if (_pd.evicted) throw StateError('broken pipe');
    return _socket.write(data);
  }

  /// `FD.RawRead`: trava de leitura e `prepareRead` (fechado ou prazo
  /// vencido falham antes do `f`), depois `f` até devolver `true`, com a
  /// espera de leitura (`pd.waitRead`) entre as tentativas.
  Future<void> rawRead(bool Function() f) => _raw(f, read: true);

  /// `FD.RawWrite`: idem na escrita.
  Future<void> rawWrite(bool Function() f) => _raw(f, read: false);

  Future<void> _raw(bool Function() f, {required bool read}) async {
    if (!await _fdmu.rwlock(read)) throw errClosing(isFile: _isFile);
    try {
      _rawPrepare(read);
      while (!f()) {
        if (_pd.evicted) {
          // Nada mais acorda a espera: o `f` verá o EOF/erro na próxima
          // chamada. Um evento (não microtask) para não travar o laço.
          await Future<void>.delayed(Duration.zero);
        } else {
          await (read ? _pd.waitRead() : _pd.waitWrite());
        }
        _rawPrepare(read);
      }
    } finally {
      _fdmu.rwunlock(read);
    }
  }

  /// `prepareRead`/`prepareWrite` e o retorno do `waitRead`/`waitWrite`:
  /// o erro do socket não sai daqui (o `f` o vê na syscall).
  void _rawPrepare(bool read) {
    if (_fdmu.isClosed) throw errClosing(isFile: _isFile);
    if (read ? _pd.readExpired : _pd.writeExpired) {
      throw const DeadlineExceededException();
    }
  }
}
