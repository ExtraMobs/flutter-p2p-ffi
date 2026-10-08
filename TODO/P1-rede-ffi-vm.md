# Rede pelo `dart:ffi` na VM e correções do shim `net` (D10)

**Decidido pelo dono em 2026-10-07**: F1 a F5 como recomendado abaixo
(F4 e F5 com o texto do dono; F1–F3 "aceito tudo, implemente o que puder").
Este artefato é o plano de execução; cada etapa entregue sai daqui no
commit que a fecha, e o artefato é apagado quando a última sair.

Prova do F4 (Go 1.26.5, `GOOS=js GOARCH=wasm`, rodado com
`node $GOROOT/lib/wasm/wasm_exec_node.js`):

```
dial tcp: dial tcp 127.0.0.1:1: address 127.0.0.1:1: connect: Connection refused
listen tcp: true <nil>
unixgram: <nil>
control: dial tcp 127.0.0.1:1: socket: Operation not supported on transport endpoint
ip4: listen ip4:icmp 127.0.0.1: socket: Operation not supported on transport endpoint
lookup: <nil>
```

## Andamento

- 2026-10-07 no `main`: E0 (shim `syscall` com `Errno`, `IPConn`/`ResolveIPAddr`
  sem socket, regra `.node.out` no e2e), E1 (`sysffi/`, poller, ponte; ainda
  sem uso pelo `net`) e S1–S5. Audit 192/1112 (`grpc/internal/resolver/dns/
  internal` verde); `pion/transport/*/stdnet` passou a ser emitido e caiu em
  `dart-invalido` (ver `P1-construcao-dart-invalido-audit.md`).
- 2026-10-08: E2–E7 integrados (um só `socket()` do Go para TCP com
  `Control`, UDP, Unix e IP bruto). Falta: `Read`/`Write` do `RawConn`
  sobre TCP do `dart:io` (ver E2) e o E8.

O Go/js simula a rede em memória (`Listen` e `unixgram` funcionam), por isso
não serve de oráculo para o Node: daí o F5.

Plano revisado adversarialmente em 2026-10-07 sobre a main 76fbf4e. Fontes: Go 1.26.5 (`$GOROOT/src/net`, `syscall`, `internal/poll`), Dart SDK
3.13.5, Node v22.22.0, módulos do corpus em `/root/go/pkg/mod`.

## 0. Decisões (todas tomadas em 2026-10-07)

| # | Decisão | Recomendação |
|---|---|---|
| F1 | Exceção ao AGENTS.md ("`dart:ffi` não é usado") | permitir `dart:ffi` num diretório neutro, `golib_dart/lib/src/sysffi/`, alcançado **só** por libraries escolhidas por `if (dart.library.ffi)`. Serve à rede, ao shim `syscall`, ao `x/sys/unix` do D5 e ao `Fd()` do D3. Provado: com o import condicional, dart2js e dart2wasm escolhem o stub; com import direto, os dois recusam. Atualizar `AGENTS.md` (Convenções) e `docs/mapping-spec.md` § "Plataformas". |
| F2 | UDP da VM no linux nasce no FFI | sim, mas pelo motivo certo: o `dart:io` já dá `SO_BROADCAST`, multicast e dual stack; o que só o FFI dá é `IPV6_V6ONLY=1` antes do `bind`, `Control` antes do `bind`, cmsg no `recvmsg` (`ReadMsgUDP`/`WriteMsgUDP` com oob) e fd real para `SyscallConn`, que é o que o quic-go exige. |
| F3 | Plataformas do FFI | linux primeiro (o `GOOS` do build); macOS depois, com teste numa máquina macOS (o namespace abstrato e o `eventfd` são só do linux). Windows: sem FFI. |
| F4 | `Control`/`SyscallConn` fora da VM (Node) | **decidido (dono, 2026-10-07): falha como o Go em js/wasm**: dial com `Control`/`ControlContext` dá `OpError{dial, ..., SyscallError("socket", ENOTSUP)}` (texto do linux: `socket: operation not supported`), listen ignora o `Control`, opções de socket dão `ENOPROTOOPT`. Conferido com `GOOS=js GOARCH=wasm` do Go 1.26.5: `dial tcp 127.0.0.1:1: socket: Operation not supported on transport endpoint` (o Go/js usa a tabela de errno do js; o shim usa a do linux, como no resto). Consequência: o dial do gRPC no Node falha. |
| F5 | Testes do que falha no Node/navegador | **decidido (dono, 2026-10-07): a falha tem de ser previsível, como nos testes do Go.** O Go/js não serve de oráculo (simula uma rede em memória: `Listen` e `unixgram` funcionam lá). Mecanismo: o e2e continua comparando a VM byte a byte com o `go run`; JS e Wasm comparam com `<caso>.node.out` versionado, e o harness exige que toda linha que difira do `go run` seja o erro Go de "não suportado" da mesma operação (`operation not supported`/`protocol not available`), então a divergência é sempre a falha prevista e nunca outra coisa. |

Sem dependências novas: nada de `package:ffi`.

## 1. Arquitetura (na VM, com F1)

### 1.1 `golib_dart/lib/src/sysffi/`
- `libc.dart`: `@Native` resolvido do processo (JIT e AOT): `socket`,
  `bind`, `connect`, `listen`, `accept4`, `sendto`, `recvfrom`, `sendmsg`,
  `recvmsg`, `getsockname`, `getpeername`, `setsockopt`, `getsockopt`,
  `shutdown`, `close`, `unlink`, `link`, `rename`, `fcntl` (VarArgs),
  `poll`, `eventfd`, `getpid`, `getifaddrs`.
- **errno, regra estrutural**: toda chamada que precisa de errno é leaf e
  pega o ponteiro antes (`p = errnoLocation(); r = f(); e = r<0 ? p.value : 0`
  num bloco síncrono, sem alocação no meio). Medido: 0 erros com ponteiro
  prévio; 1 em 1,1M sem ele; 32 com alocação no meio. Não leaf só o `poll`
  (bloqueia; só trata `EINTR`) e o `close` (bloqueia com `SO_LINGER > 0`).
- `alloc.dart`: alocador sobre `calloc`/`free` da libc; buffers diretos com
  `TypedData.address` nas chamadas leaf.
- `structs_linux.dart`: `sockaddr_un`, `sockaddr_in`, `sockaddr_in6`,
  `msghdr`, `iovec`, `cmsghdr`, `pollfd`, `ifaddrs`.

### 1.2 Poller (`lib/src/net/sys/ffi/poller.dart`)
- Um isolate auxiliar **por isolate que usa a rede** (os estáticos são por
  isolate), com `poll` sobre `eventfd` + interesses, em fatias de 250 ms
  (um `poll(-1)` impede a VM de encerrar).
- `waitRead` e `waitWrite`; prazos pelo `Deadline` atual no isolate
  principal, dentro do `heldIo` do detector de deadlock.
- Medido (eco unixgram, AOT): p50 48 µs, p99 160 µs. Um dup importado no
  `dart:io` por espera dá 140/652 µs; polling por timer, 2 ms.
- `Close` síncrono (é versão dupla no g2d): marca fechado, acorda quem
  espera com `ErrClosed`, e o `close(2)` só acontece depois do ack do
  poller. `NativeFinalizer` fecha fd esquecido.
- `connect` não bloqueante (`POLLOUT` + `SO_ERROR`, prazo e cancelamento
  pelo `ctx`) e laço de `accept4` sobre o poller.

### 1.3 Ponte para o `dart:io` (`lib/src/net/sys/ffi/bridge.dart`)
- Só **conexões de fluxo**: o `ResourceHandle` tem `toRawSocket`, mas não
  `toRawServerSocket`, e `toRawDatagramSocket` não funciona na VM. Um TCP
  conectado no FFI (dial com `Control`/`LocalAddr` de reuseport, ou aceito
  por um listener do FFI) é passado ao `dart:io` por SCM_RIGHTS num par Unix
  abstrato privado, e daí segue o caminho atual (`_IoTcpConn`, `PollDesc`).
- Segurança: conferir `SO_PEERCRED` (pid igual ao `getpid()`) antes de
  enviar fds; outro processo poderia conectar primeiro no nome abstrato.
- Listeners do FFI (`ListenConfig.Control`, reuseport) ficam no FFI, com o
  laço de `accept4`; cada conexão aceita é importada.

### 1.4 `SyscallConn` por dono do fd
- Socket do FFI: `Control`, `Read` e `Write` reais.
- Socket do `dart:io`: `Control` via `setRawOption`/`getRawOption` (já
  usados em `io_tcp.dart`); `Read`/`Write` (TCP e Unix de fluxo) são o
  `FD.RawRead`/`RawWrite` sobre o `Fd` da conexão, e o `syscall.Read`/
  `Write` do `f` lê/escreve no mesmo `RawSocket` sem esperar (não num dup:
  o estado do `dart:io` fica coerente). Feito (fixture `netrawread`).

## 2. Lado do g2d (faltava na v1)

- Shim `syscall` em `STDLIB_SHIMS`; `syscall.RawConn` e `syscall.Conn` em
  `SHIM_INTERFACES`; `syscall.Errno` como nomeado de shim (igualdade por
  valor dentro de interface, como `time.Duration`).
- `RawConn.Read/Write` suspendem: entram em `ASYNC_IFACE_METHODS`
  (`dualio.py`), com o callback `f` síncrono.
- Campos de função em struct do shim: `Dialer.Control`/`ControlContext` e
  `ListenConfig.Control` são síncronos; `Resolver.Dial` precisa suspender
  (o certmagic chama `DialContext` dentro dele) e pede uma regra de cor no
  estilo do D7 (campo func de shim com cor própria).
- `NET_SUSPENDING` já lista `ListenUnixgram`, `LookupSRV/MX/NS/CNAME/Addr`,
  `ResolveIPAddr` e os métodos de `IPConn`/`UnixConn`; o que entrar além
  disso vai junto, com `python -m g2d shims`.

## 3. Etapas

Nenhuma etapa de FFI muda o número de verdes sozinha: o maior uso real é o
QUIC (UDP + `SyscallConn` + oob), que também depende do D5 (`x/sys/unix`,
`x/net/ipv4` com `recvmmsg`) e do `crypto/tls`. O ganho imediato está no E0.

### E0. Superfície sem FFI e infraestrutura (primeiro passo; não depende de F1–F4)
1. **e2e por plataforma (F5)**: `tests/test_golden.py` aceita
   `<caso>.node.out` opcional; teste do mecanismo; regra no `AGENTS.md`.
   Só entra se o dono aprovar o F5; sem ele, o resto do E0 anda igual.
2. **Shim `syscall`** em `golib_dart/lib/syscall.dart` + partes
   `lib/src/syscall/{errno.dart, consts_linux_amd64.dart, rawconn.dart}`:
   `Errno` numérico com a numeração do linux em toda plataforma (`Error`,
   `Is`, `Timeout`, `Temporary` do `syscall_unix.go`, textos do
   `zerrors_linux_amd64.go`); constantes `E*`, `AF_*`, `SOCK_*`, `SOL_*`,
   `SO_*`, `IPPROTO_*`, `TCP_*`, `MSG_*`, `SCM_*`; interfaces `RawConn` e
   `Conn`. Nenhuma função que faça syscall ainda. O `_Errno` privado do
   `net` (`src/net/errno.dart`, códigos em string) migra para ele, e a
   tabela `sys/io_errno.dart` passa a produzir o número.
3. **`net.IPConn` e `ResolveIPAddr`** sem socket bruto: o tipo (para o type
   switch do manet e o `stdnet` do pion), `ResolveIPAddr` com o resolver do
   sistema, `ListenIP`/`DialIP` com o erro de hoje.
4. **TODO**: artefato `P0-design-ffi-vm.md` com F1–F5, linhas no §1 do
   `TODO/README.md`, e as seções "Pendências da rede" do D3/D5 apontando
   para ele (hoje apontam para este arquivo fora do repo).

Fixtures (saída idêntica nas três plataformas): `syscallerrno`
(`errors.Is(err, syscall.ECONNREFUSED)`, cadeia `*OpError` →
`*SyscallError` → `Errno`, `Errno(11).Error()`/`Timeout()`/`Temporary()`,
`==` com constante) e `netipconn` (`ResolveIPAddr` com literais e erros,
type switch com `case *net.IPConn`).

Pronto quando: suíte inteira verde; goldens de `nettcp`, `netudp`,
`netunix`, `netlinger` iguais byte a byte; audit regerado com
`shim-simbolo:net.IPConn` (9 ocorrências / 6 pacotes / 2 na fronteira) e
`net.resolveIPAddr` (4/4/2) sumindo, e `shim-ausente:syscall` (44 pacotes,
6 na fronteira) virando códigos por símbolo; medir se o `pion/transport`
`stdnet` v3/v4 fica verde (hipótese).

Riscos: `Errno` como nomeado sobre `uintptr` no g2d; a troca do `_Errno`
mudar texto de erro de fixtures existentes (os goldens acusam).

### E1. Base FFI (com F1)
`sysffi/` (§1.1), poller (§1.2), ponte (§1.3). Testes em
`golib_dart/test/net_ffi_test.dart`: errno sob GC, prazos, `Close` acordando
a espera, a VM encerrando com o poller vivo, um build AOT
(`dart compile exe`), e compilação JS/Wasm de uma entrada que importa o
`net` sem puxar `dart:ffi`.

### E2. `Control`, `ControlContext`, `SyscallConn` — feito
Entregue (fixtures `netcontrol`, `syscallsock`; `docs/mapping-spec.md` §
Rede). Unix e IP bruto com `Control` e `SyscallConn` (fd real) vieram
na integração com o E3–E7 (fixture `netunixcontrol`).
`SyscallConn` de socket do `dart:io` (TCP, Unix de fluxo): `Read`/`Write`
são o `FD.RawRead`/`RawWrite` (`internal/poll/fd_raw.dart`) e o
`syscall.Read`/`Write` do descritor virtual lê/escreve no `RawSocket` sem
esperar (`EAGAIN`, 0 no EOF): o readyreader do gRPC funciona na VM
(fixture `netrawread`, igual ao `go run`). ⚠️ O `syscall.Read` virtual só
vê o que o `RawSocket` anunciou (antes do evento de leitura dá `EAGAIN`
mesmo com dado no kernel; o `raw.Read` espera o evento). UDP do `dart:io`
(fora do linux) e Node seguem com `operation not supported` (F4/F5).

### E3–E7 — feitos
Entregues: `unixgram` (E3), `unixpacket` (E4), extras de Unix (E5:
autobind, `laddr` nomeado, `SetUnlinkOnClose(false)`, `ReadMsgUnix`/
`WriteMsgUnix` com oob, `syscall.UnixRights`/`ParseSocketControlMessage`/
`ParseUnixRights`), IP bruto (E6) e UDP no FFI (E7), todos sobre um só
`socket()` do Go (`_goSocket`, `src/net/control.dart`) e um só `netFD`
(`FfiSock`, `src/net/sys/ffi/sock.dart`); fixtures `netunixgram`,
`netunixpacket`, `netunixmsg`, `netiprawsock`, `netudpffi`. Detalhes e
limites em `docs/mapping-spec.md` § Rede. ⚠️ O sandbox não tem IPv6: dual
stack e `V6ONLY` ainda precisam de teste numa máquina com IPv6 (o
`favoriteAddrFamily` mede a pilha como o Go). `ListenMulticastUDP` e
`FileConn`/`FileListener` (D3) seguem fora.

### E8. macOS
Layouts (`sin_len`, `sun_path` de 104, `cmsghdr` alinhado a 4, `__error()`),
`getifaddrs` com `AF_LINK`, ponte por caminho em diretório 0700 e `pipe` no
lugar do `eventfd`. Linger/keepalive no macOS não precisam de FFI (só as
constantes no `setRawOption`).

## 4. Correções sem FFI

| # | Item | Observação |
|---|---|---|
| S2 | `Resolver.Dial` + `PreferGo` | não é shim puro: com `CGO_ENABLED=0`, um `Resolver` com `Dial` faz **todo** lookup dele passar pelo cliente DNS do Go (A/AAAA, hosts, search, ndots); é portar o `goLookupIP` sobre o `exchange` que já existe (`sys/dns_client.dart`) e a regra de cor do campo `Dial` (§2). Vem antes do S1, porque o e2e hermético do S1 usa um servidor DNS falso no próprio programa, alcançado por `Resolver.Dial`. |
| S1 | `LookupSRV`/`MX`/`NS`/`CNAME`/`Addr` | nomes com ponto final; SRV por prioridade e embaralhado por peso; MX embaralhado e ordenado; `LookupCNAME` como o Go (consulta A/AAAA via `goLookupIPCNAMEOrder`, não o tipo CNAME); PTR lê `/etc/hosts` antes. No Node, por cima de `dns.resolve*` com essas regras. |
| S3 | `/etc/services` | `readServices` do Go; o arquivo vence a tabela embutida. |
| S4 | `KeepAliveConfig`/`SetKeepAliveConfig` | expor o `_setKeepAliveConfig` que já existe (`conn.dart:258`). |
| S5 | `Dialer.FallbackDelay` | `dialParallel`/`dialSerial` do Go (só rede `tcp`, 300 ms, primário = família do primeiro endereço). |

`conn.dart` (605 linhas), `dial.dart` (497) e `unix.dart` (396) já passam
do limite de ~300: o código novo entra em partes novas (`control.dart`,
`dial_parallel.dart`, `unixgram.dart`...).

## 5. O que continua sem solução

- **Node** (sem FFI nativo): `unixgram`, `unixpacket`, IP bruto,
  `laddr` nomeado e oob no Unix (E3–E7 feitos na VM linux; fixtures com
  `.node.out`) e `SyscallConn.Read/Write` dão o erro do Go; intervalo e contagem do
  keepalive e linger > 0 seguem aceitos e ignorados, e `CloseRead` só passa
  a dar EOF (como está hoje no `mapping-spec`). QUIC não roda no Node em
  nenhuma escolha (o quic-go falha se não conseguir `DF` nem `SyscallConn`).
- **Navegador**: sem rede (D4). **Windows**: sem FFI.

## 6. Execução

E0 primeiro (sem decisão pendente além do F5 para o item 1). Depois, com F1:
E1, e então E2–E7, feitos (`docs/mapping-spec.md` § "Rede (D4)"). `FileConn`/`FileListener` (D3)
continuam fora. As
worktrees em paralelo mexem nos mesmos arquivos (`sys_io.dart`, `sys.dart`,
lista de partes do `net.dart`, `shim_symbols.json`): cada arquivo tem um
dono por rodada, ou as etapas vão em série. Integração numa branch só,
suíte inteira e audit, e push direto na main.
