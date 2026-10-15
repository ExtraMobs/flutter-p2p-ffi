# O protocolo do serviço (ipfs_ffi 0.9.0)

O `ipfs_ffi` roda o kubo **só** num processo separado, o `ipfs_host` (o Go deste
pacote compilado como executável). Um panic não tratado do kubo derruba esse
processo, nunca o app: o app recebe `IpfsServiceException` e relança o serviço. O
app não carrega Go; carrega só a `ipfs_shm` (C), o lado dele do canal.

Este documento é o contrato entre os dois lados. O gerador (`go/gen`) emite o Go do
host e o Dart do app a partir dele; o que é escrito à mão segue as mesmas regras.

## Canal

- Região de memória compartilhada com dois anéis SPSC (layout em
  `go/shmring/ring.go`): anel 0 = pedidos (app → host), anel 1 = respostas e eventos
  (host → app). Linux/Android: `memfd` passado por `SCM_RIGHTS` no Unix socket;
  Windows: `CreateFileMapping` com nome aleatório + dois named pipes de um sentido.
- O socket/pipe só serve de aperto de mão, sininho (acordar o lado que dorme) e
  detecção de queda (fecha quando o processo morre). Espera: gira um pouco, depois
  dorme no sininho.
- Cada mensagem vai em um ou mais quadros `[u32 continua][pedaço]`; a que não cabe
  num quadro é partida e remontada (um produtor por vez em cada anel).

## Mensagens

Tudo em little-endian.

- **Pedido**: `u32 id`, `u32 função`, `u8 modo`, argumentos. Modo: `0` síncrona
  (o app bloqueia esperando), `1` assíncrona (`Future`), `2` stream.
- **Resposta/evento**: `u32 id`, `u8 tipo`, dados. Tipo: `0` valor, `1` item (de
  stream ou de sink), `2` fim, `3` erro (dados = a mensagem em UTF-8).
- Uma chamada responde com um `valor` ou um `erro`; um stream com `item`s e então
  `fim` ou `erro`. Os sinks de uma chamada (abaixo) recebem `item`s e `fim`/`erro`
  com o id do sink, **antes** da resposta da chamada.
- O `id` é do app (contador da isolate). Pedidos sem resposta usam id 0.

## Funções

| id | função | argumentos → resposta |
|---|---|---|
| 0 | Noop | — → valor vazio |
| 1 | Sleep (teste) | `u32 ms` → valor vazio depois de ms |
| 2 | Echo (teste) | bytes → os mesmos bytes |
| 3 | Free | `u32 n`, n × `i64` handles → sem resposta (id 0) |
| 4 | Hello | `u64` hash da tabela → valor vazio, ou erro se o host foi gerado de outra tabela |
| 16 | context.Background | — → `i64` ctx |
| 17 | context.WithCancel | `i64` pai → `i64` ctx, `i64` cancel |
| 18 | context.WithTimeout | `i64` pai, `i64` ns → `i64` ctx, `i64` cancel |
| 19 | context.WithDeadline | `i64` pai, `i64` Unix ns → `i64` ctx, `i64` cancel |
| 20 | context.CancelFunc (chamar) | `i64` cancel → vazio |
| 21 | context.Context.Err | `i64` ctx → `kError` (`u8` presente + string) |
| 24 | teste: PanicInGoroutine | — → vazio; o host cai logo depois |
| 25 | teste: PanicInChanFunc | modo stream: `item` `i64` 1, depois `erro` com o panic |
| 26 | teste: PanicInSink | `u32` sink → vazio; o sink recebe `item` `i64` 1 e depois `erro` com o panic |
| 32 | dag put | `i64` CoreAPI, `i64` ctx, `kBytes` dados, string input-codec, string store-codec, string hash, bool pin, bool allow-big-block → `u8` presente + string CID |
| 33 | dag get | `i64` CoreAPI, `i64` ctx, string path, string output-codec → `kBytes` |
| 34 | dag export | `i64` IpfsNode, `i64` ctx, string path, bool local-only, string arquivo (`''` = devolve os bytes) → `kBytes` (vazio quando grava no arquivo) |
| 35 | dag import | `i64` IpfsNode, `i64` ctx, `kSlice` de string arquivos, `kBytes` CAR (`-1` = usa os arquivos), bool pin-roots, bool allow-big-block → `i32 n` raízes × (string CID, string erro do pin), `i64` blocos, `i64` bytes |
| 40 | config.Profiles | — → `i32 n` × string (nomes em ordem) |
| 41 | config.Profile.Transform | string nome, string JSON do config → string JSON do config transformado |
| ≥ 64 | as geradas | id = 64 + posição na lista das funções expostas em ordem de chave (`assignIDs` em `go/gen/main.go`) |

O hash da tabela (FNV-1a 64 de `"id chave\n"` por função gerada) vai no `Hello`
logo depois de conectar: app e host têm de vir do mesmo gerador.

## Codificação dos valores

Argumentos em ordem (o receptor de um método primeiro; variáveis de pacote não têm
argumentos), resultados em ordem sem o `error` final (que vira resposta de erro).
Tipos nomeados sobre básicos (enums do kubo) vão como o básico. Por tipo do modelo
(`go/gen/model.go`):

| kind | bytes |
|---|---|
| bool | `u8` (0/1) |
| inteiros (todos os tamanhos e sinais) | `i64` |
| float | `f64` |
| string | `u32 n` + UTF-8 |
| `kBytes` (`[]byte`) | `i32 n` + bytes; `-1` = nil |
| `kValue` (CID, path, peer ID, multiaddr, ipns.Name) | `u8 presente` + string (a forma de texto do Go) |
| `kValue` `time.Time` | `u8 presente` + `i64` Unix em nanossegundos |
| `kValue` `config.Config` | `u8 presente` + string com o JSON do próprio kubo (o formato do arquivo `config`, que é o dado em si) |
| `kHandle`, `kCtx` | `i64` handle; `0` = nil |
| `kDTO` | `u8 presente` + os campos que atravessam, na ordem de `tinfo.fields` |
| `kSnap` | `u8 presente` + cada getter na ordem de `tinfo.gets`; getter com erro = o valor seguido de um `kError` |
| `kError` (erro dentro de um valor) | `u8 presente` + string |
| `kSlice` | `i32 n` + elementos; `-1` = nil |
| `kMap` | `i32 n` + pares: chave (string; se `tinfo.mkey`, a string do tipo-valor, **sem** byte de presença) + valor |
| `kOpts` (opções funcionais, variádicas) | `i32 n` + cada opção: `u32` índice do construtor em `tinfo.ctors` + os parâmetros dele |
| `io.Reader` em parâmetro | `u8 0` + `kBytes`, ou `u8 1` + `i64` handle |
| `kWriter` (`io.Writer`) | não atravessa (o host usa `io.Discard`) |
| `kChanSend` dentro de uma opção (sink, ex. `options.Unixfs.Events`) | `u32` id do sink (registrado pelo app); os itens vão como eventos `item` com esse id, e o sink termina com `fim`/`erro` antes da resposta da chamada |
| `kChanSend` como parâmetro da própria função (ex. `PinAPI.Ls`) | não atravessa: a função é chamada no modo stream e cada valor que o Go põe no canal é um `item` (como `kChanRecv`) |
| `kChanRecv` (`<-chan T` no resultado) | a função é chamada no modo stream; cada valor do canal é um `item` |

**Handles**: o host guarda os objetos numa tabela (`i64` a partir de 1); o app os
solta com `Free` (em lote, pelo `Finalizer`). Um handle só vale na vida do serviço
em que nasceu: depois de um reinício, usá-lo dá `IpfsServiceException`.
