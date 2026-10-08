# `syscall.Read` no fd virtual do TCP só lê depois do evento de leitura

- **Prioridade:** P2 · **Área:** shim (`internal/poll`, `net`)
- **Depende de:** —

## Problema

No TCP do `dart:io`, o `syscall.Read` do descritor virtual do `SyscallConn`
(`golib_dart/lib/src/internal/poll/fd_raw.dart`, `readNow`) só toca no
`RawSocket` se o `RawSocketEvent.read` já chegou (`_pd.readable`); antes
disso dá `EAGAIN` mesmo com dado no kernel. O `read(2)` do Go lê o que está
lá. O comentário dizia que ler sem o evento "envenena" o socket; no linux,
com o Dart 3.13.5, não envenena:

```text
$ dart run bin/exp.dart        (RawSocket par; o leitor desliga os eventos de leitura ao receber um, como o PollDesc)
1 dry read: null avail=0                    (sem dado: null, nenhum evento de erro)
  events: [RawSocketEvent.write]
2 read before event: [1, 2, 3] avail=0      (dado no kernel, evento ainda não tratado)
  events: []
3 later data: events=[RawSocketEvent.read] avail=2 read=[4, 5]   (eventos seguem normais)
4 read before event again: [6]
  events: []
5 read at EOF before event: null avail=0    (EOF antes do evento: indistinguível do EAGAIN)
  events: [RawSocketEvent.readClosed]
6 read after: null
  events: [RawSocketEvent.readClosed]
```

## Prova

`tests/golden/netrawreadnow/netrawreadnow.go` (o par escreve, uma espera
ocupada segura o laço de eventos, e o `syscall.Read` vem em seguida):

```text
$ GOTOOLCHAIN=go1.26.5 go run netrawreadnow.go
syscallconn: <nil>
control: 5 "hello" <nil> <nil>
one-shot: 5 "world" <nil> false
vazio: -1 resource temporarily unavailable <nil>
parcial: 4 "abcd" <nil> <nil> / resto: 6 "efghij" <nil>

$ dart run lib/netrawreadnow.dart
syscallconn: <nil>
control: -1 "" resource temporarily unavailable <nil>
one-shot: -1 "" resource temporarily unavailable false
vazio: -1 resource temporarily unavailable <nil>
parcial: -1 "" resource temporarily unavailable <nil> / resto: 16 "helloworldabcdef" <nil>
```

## Critério de pronto

- `readNow` tenta o `RawSocket.read` mesmo sem o evento (no linux); o EOF
  antes do evento continua ⚠️ (o `read` devolve `null` como no `EAGAIN`).
  Fixture `netrawreadnow` idêntica ao `go run` na VM (Node: F5).
