# Progresso da transpilação kubo/go-libp2p/boxo → dart_ipfs

Este arquivo registra **estado atual, rastreamento Go → Dart e decisões de
transpilação**. Ele não guarda diário de sessão nem contagens de teste de uma
data: números de cobertura e de conformidade vêm dos relatórios gerados.

| Onde procurar | O quê |
| --- | --- |
| `AGENTS.md` | Escopo, regras de porte, as 24 regras do auditor e o portão de conclusão |
| `doc/transpilation/UPSTREAM_LOCK.md` | Revisão Go autoritativa de cada módulo |
| `PROGRESS_RELATORY.md` (`--progress`) | Cobertura por módulo, em números |
| `audit_report.md` (`--markdown`) | Apontamentos do auditor, símbolo a símbolo |
| Este arquivo | O que está comprovado, contra o quê, e o que ainda não está |

Regra de leitura: **"portado" e "funciona contra par real" são afirmações
distintas.** Uma matriz de `canDial()` ou uma troca em loopback entre dois nós
Dart não comprova alcance — os dois lados compartilham os mesmos defeitos e se
entendem por causa deles. Prova é daemon externo, handshake real e bytes
validados pelo CID.

## Estado por objetivo

| Objetivo | Estado | Prova |
| --- | --- | --- |
| 1 — Download P2P por CID (A, B) | Concluído | `local_kubo_bitswap_test.dart`, `local_kubo_dht_bitswap_test.dart` |
| 2 — Hospedagem e servimento por CID (C.1, C.2) | Concluído | `local_kubo_serving_test.dart`, `local_kubo_dht_serving_test.dart` |
| 3 — Host, rede e NAT traversal (D.1–D.4) | Concluído | `check.ipfs.network` discando `/ip4/203.0.113.47/tcp/4002` |
| 4 — Descoberta global autônoma na DHT (E.1–E.3) | Concluído | `dht_public_discovery_network_test.dart` (`--preset network`) |
| 5 — Interoperabilidade plena de rede (F.1–F.7) | Concluído | `local_kubo_network_participation_test.dart` |
| 6 — Matriz de transporte e segurança (G.1–G.7) | **Aberto** | ver abaixo |

O Objetivo 3 não portou a `go-libp2p` integralmente, e `transpiled_libp2p` não
deve ser tratado como pacote fechado — a porcentagem em `PROGRESS_RELATORY.md`
mede superfície de API, não função.

## Objetivo 6 — o que está comprovado e o que não está

Dependências entre marcos (a numeração não é a ordem executável):

```
TLS 1.3 (G.2) ──┬── G.1 QUIC ── G.4 WebTransport ──┐
                └── o próprio /tls/1.0.0           ├── G.7 matriz
DTLS (não portado) ── G.5 WebRTC Direct ───────────┘
G.3 WebSocket — independente (usa o TLS do dart:io)
```

| Marco | Discagem | Entrada (listen) | Observação |
| --- | --- | --- | --- |
| G.1 QUIC | **comprovada** contra Kubo 0.43.0 (`local_kubo_quic_test.dart`) | **não comprovada** | o mesmo `QuicServer` atende `/quic-v1` e WebTransport |
| G.2 TLS 1.3 | **comprovada** | **comprovada** | `local_kubo_tls_handshake_test.dart`; `/tls/1.0.0` volta à lista de segurança padrão |
| G.3 WebSocket | `/ws` entre nós Dart | listener implementado | **critério do marco não atendido**: falta discar um peer público que anuncie `/wss` |
| G.4 WebTransport | **comprovada** (`local_kubo_webtransport_quic_test.dart`) | protocolo real, **não comprovada** | critério do marco (navegador Helia) não atendido |
| G.5 WebRTC Direct | não | não | bloqueado por DTLS, que não está portado |
| G.6 mplex | descartado | — | depreciado na libp2p, removido dos padrões do Kubo |
| G.7 matriz | — | — | `local_kubo_transport_matrix_test.dart` **falha de propósito** |

### G.1 / G.4 — onde a direção de entrada para hoje

O servidor QUIC deixou de fabricar identidade a partir do IP: deriva
`clientHandshakeTrafficSecret`, desprotege os pacotes Handshake do cliente, lê
o `Certificate`, confere o `Finished` em tempo constante e só então produz a
conexão, com `PeerId` vindo de `pubKeyFromCertChain`. Ele também percorre todos
os pacotes coalescidos de um datagrama (RFC 9000 §12.2), sem o que o Handshake
do cliente nunca era visto.

Três defeitos foram corrigidos contra Kubo real, cada um confirmado pela
mensagem de erro do próprio Kubo mudar — nenhum era detectável em loopback:

1. O servidor escolhia `keyShares.firstOrNull`, que no Go 1.24+ é
   `X25519MLKEM768` (0x11ec). O share passou a ser selecionado pelo grupo
   (0x001d); sem ele, o handshake é abandonado com erro explícito, porque
   `HelloRetryRequest` (RFC 8446 §4.1.4) não está portado.
2. O ClientHello real não cabe num Initial e chega partido, um CRYPTO frame por
   pacote, cada um no seu offset (RFC 9000 §19.6). `_CryptoAssembly` remonta por
   offset antes de parsear.
3. ALPN era enviado no ServerHello. A RFC 8446 §4.1.3 só permite ali
   `key_share`, `pre_shared_key` e `supported_versions`; o resto vai em
   `EncryptedExtensions`.

**Estado após as três correções:** o Kubo aceita o ServerHello e para em
`context deadline exceeded`, sem que o servidor Dart registre erro — o cliente
não chega a mandar o segundo flight. Suspeitas, em ordem: tamanho do datagrama
coalescido; ausência de ACK para o segundo Initial do cliente (`_dispatch`
ignora Initials repetidos quando já existe handshake pendente); proteção de
cabeçalho e numeração de pacote no nível Handshake.

O servidor WebTransport encadeia QUIC → HTTP/3 Extended CONNECT → Noise
responder e não usa mais os pacotes inventados `0x57`/`0x58`/`0x59`. Falta
portar o certificado determinístico (`crypto.go:generateCert`, ECDSA derivada
por HKDF, validade de 14 dias); `_verifyRawCerts` confere só o hash, sem as
checagens de RSA e de validade máxima que o Go faz.

### G.5 — o que falta é DTLS, não WebRTC

O `certhash` do multiaddr WebRTC Direct é o fingerprint do certificado **DTLS**.
A cadeia que importa é ICE → DTLS → SCTP → DataChannel. A pilha Pion portada
tem `sctp` (parcial), `stun`, `sdp`, `transport`, `transport_v4`, `logging` e
`randutil`, e **não tem `dtls`**. O `WebRtcTransport` está registrado no Swarm,
mas o handshake atual é framing inventado sobre UDP em claro: nenhum par real
fala isso. Os módulos de mídia (`rtp`, `rtcp`, `srtp`, `interceptor`) ficaram
deliberadamente fora, porque `/webrtc-direct` usa apenas data channels.

### G.7 — a matriz

`local_kubo_transport_matrix_test.dart` sobe um Kubo real, lê a lista efetiva de
`Addresses.Swarm` e exige, para cada endereço, conectar, abrir stream e
recuperar um bloco por Bitswap validando o CID. Hoje passa em `/tcp`,
`/quic-v1` e `/quic-v1/webtransport`, e falha em `/webrtc-direct` com
`TimeoutException` no handshake. Ele **deve** continuar vermelho enquanto o G.5
estiver aberto; fazê-lo passar sem DTLS exigiria enfraquecer exatamente a
asserção que o torna útil.

## Rastreamento Go → Dart

Registro exigido pelo `AGENTS.md` (`chamador Go → símbolo chamado →
módulo/revisão → símbolo/pacote Dart`). As revisões estão em `UPSTREAM_LOCK.md`.

### Roteamento e DHT

- `IpfsDHT.GetClosestPeers` (`lookup.go`, go-libp2p-kad-dht) →
  `DhtClient.getClosestPeers` em `lib/src/routing/dht_provider_finder.dart`;
  `Message_FIND_NODE` → `encodeFindNode` em
  `lib/src/protocols/dht/dht_message.dart`. O motor Kademlia genérico é `_walk`
  (α=3, β=3, fase de follow-up, 20 nós mais próximos); `_lookup` é um wrapper
  fino, e o `lookupCheck` do Go está dobrado dentro do `_walk`.
- `DhtClient.provide` usa `getClosestPeers(cid.multihash)`, com `bootstrapPeers`
  apenas como fallback. A muleta que delegava o anúncio a um daemon externo via
  `Process.run` foi removida.
- Servidor DHT (F.2): `handlers.go` — `handleFindPeer:133`,
  `handleGetProviders:176`, `handleAddProvider:238`, `handlePing:127` →
  `lib/src/protocols/dht/dht_server.dart` e `dht_provider_manager.dart`.
  `DhtRequest.fromBytes` e `frameDhtMessage` são símbolos novos.
- Tabela de roteamento (F.1): consome `packages/transpiled_libp2p_kbucket`,
  populada por `nearestPeers` com `bootstrapPeers` como fallback.
- Limites: `tempAddrTtl = 2min`, `maxPeerRecordSize = 8 KiB`,
  `dhtMessageSizeMax = 4 MiB` (validado em `DhtResponse.fromBytes`),
  `lookupTimeout = 60s`, `timeout = 10s`, cancelamento por `stream.reset()`.

### Host, descoberta e persistência

- `go-libp2p config.NewNode` → `observedaddrs.NewManager/Start/Close` →
  `observedaddrs/manager.dart` (F.3), com `activationThresh = 4`. O event bus é
  compartilhado entre Swarm, `BasicHost` e o manager.
- `Kubo SetupDiscovery` → `mdns.NewMdnsService/Start`, e
  `discoveryHandler.HandlePeerFound` → `Host.Connect` → lifecycle do nó e
  `_NodeDiscoveryHandler` (F.4). `NetworkConfig.mdnsEnabled` representa
  `Discovery.MDNS.Enabled`, ligado por padrão.
- `zeroconf client.sendQuery` / `Server.multicastResponse` → seleção explícita
  por interface: enviar só na rota padrão falhava em máquina com VPN. O SDK Dart
  lança `UnimplementedError` em `multicastInterface`, então usa-se
  `setRawOption` com `RawSocketOption.IPv4MulticastInterface`. Windows usa
  `reuseAddress` sem o `reusePort` não suportado.
- `BuildCfg.Repo` → `Repo.Config/Datastore/Close` → contrato `Repo` do runtime
  raiz. A configuração do repo prevalece sobre a efêmera; o datastore pertence
  ao repo e é fechado depois dos serviços e do peerstore.
- `Identity.DecodePrivateKey` → `base64.StdEncoding.DecodeString` →
  `crypto.UnmarshalPrivateKey` → `Identity.decodePrivateKey`. A validação
  anterior ao SDK bloqueia as extensões Dart (Base64 URL, percent escapes,
  padding ausente); CR/LF são aceitos como no Go.
- `node.PrivateKey` → `peer.IDFromPrivateKey` → repo sem identidade ou com
  identidade incompatível falha, em vez de criar outra silenciosamente.
- `pstoreds` (F.5): `peerToKey`, `dsPeerMetadata.Get/Put`, `addrsRecord.flush` e
  `dsAddrBook.ClearAddrs` usam `base32.RawStdEncoding` → módulo
  `github.com/multiformats/go-base32` → `packages/transpiled_base32`.

### Segurança e transporte

- `core/sec.SecureConn`, `SecureTransport` e `ErrPeerIDMismatch` → contratos
  canônicos e `PeerIdMismatchException`. O `BasicUpgrader` aceita a lista de
  segurança correspondente à do construtor Go, negocia seus IDs e respeita a
  seleção antecipada de yamux.
- WebTransport: `transport.go` (`tlsConf.NextProtos`, ALPN `h3`) →
  `quicgo.dial(nextProtos: ['h3'])`; `crypto.go:verifyRawCerts` →
  `_verifyRawCerts`; `transport.go:upgrade` → `_upgrade`, com early data
  `webtransport_certhashes`. As streams libp2p são as streams da sessão, sem
  yamux no meio. O `Dialer` HTTP/3 vive em `packages/transpiled_webtransport_go`.
- `Config.EnableDatagrams` (`connection.go:351`) → parâmetro `enableDatagrams`
  de `dial`; `wire.MaxDatagramSize` → `maxDatagramSize = 16383`. Sem isso o Kubo
  fecha a conexão com `application error 0x109: missing QUIC Datagram support`.

### Circuit Relay v2 e hole punching

- `client.Reserve` → `record.ConsumeEnvelope` → `peer.IDFromPublicKey` /
  `record.RegisterType` → `reservation.dart`. O `reserve()` fala com o relay de
  verdade, com enquadramento delimitado por varint lido do stream, e valida o
  voucher assinado (relay, host e expiração). O codec do `ReservationVoucher` e
  o `HopMessage.unmarshal` (campos `peer` e `limit`) foram corrigidos contra
  `voucher.proto`.
- DCUtR: o receptor calcula e sincroniza RTT em `holepunch.dart`.

### Formatos e codecs

- `go-cid.CidFromBytes` → `mh.MHFromBytes` → `readMultihashFromBuf` ↔
  `Cid.fromBytes` → `mhFromBytes` → `_readMultihashFromBuf`.
- `Boxo.DecodeProtobuf/unmarshal` → `dagpb.DecodeBytes` → `decodeBytes`
  (`go-codec-dagpb`), chamado por `DagPbNode.fromBytes`; `Boxo.marshalImmutable`
  → `dagpb.AppendEncode` → `appendEncode`, chamado por `DagPbNode.toBytes`. A
  fronteira seguinte, `go-codec-dagpb → protobuf/encoding/protowire`, motivou
  `packages/transpiled_protobuf/lib/protowire.dart`.
- Bitswap: `MessageQueue.maxMessageSize = 2 MiB`, `messageSizeMax = 4 MiB`,
  frame vazio byte-exato `[0x02, 0x0a, 0x00]`.
  `lib/src/protocols/bitswap/bitswap_message.dart` delega a `transpiled_boxo`.

## Notas de paridade por pacote

As contagens estão em `PROGRESS_RELATORY.md`; aqui ficam as decisões e as
lacunas que um número não mostra.

| Pacote Dart | Estado qualitativo e lacunas |
| --- | --- |
| `transpiled_cid` | Paridade comprovada em v0/v1, decode, `fromBytes`, `encode` e `Prefix`. `Defined()`/`Undef` omitidos: Dart usa exceção em vez de zero value. |
| `transpiled_multiaddr` | Reescrito do zero — a dependência anterior tinha dois defeitos reais de wire em quic-v1/sni. 37 protocolos, todos os transcoders, parsing IPv4/IPv6 próprio sem `dart:io`. `FilterAddrs`/`Match` e `net` omitidos por falta de chamador. |
| `transpiled_multihash` | Apenas o subconjunto de `Sum()` em uso: identity, sha1, md5, sha2-256/512, dbl-sha2-256, sha3-*, keccak-*. Blake2/Blake3, shake, murmur3 e as variantes sha2-224/384/512-* estão deferidos. O registro dinâmico de hashers não foi replicado. |
| `transpiled_multibase` | Reescrito do zero. As 21 codificações reais despacham corretamente; `base8`, `base10` e `base45` não são implementados **no próprio upstream**, que só declara as constantes. |
| `transpiled_multicodec` | Tabela de 603 entradas extraída mecanicamente do fonte Go, substituindo uma tabela manual que havia divergido. |
| `transpiled_multiaddr_dns` | Portado ponta a ponta, incluindo cliente DNS RFC 1035 próprio. Foi o gatilho da transpilação: sem resolver `/dnsaddr/`, o nó ficava em zero peers. |
| `transpiled_boxo` | Bitswap (client, message, network, wantlist) com paridade comprovada. A prova cobre as fatias exercitadas pelo download e pelo servimento, não a superfície do módulo. `blockstore` parcial; `chunker` e `unixfs` portados sem teste de paridade formal. |
| `transpiled_ipld_prime` | Núcleo com paridade (`datamodel`, `linking`, `codec/json`, `codec/raw`, `multicodec`, `node/basicnode`, `fluent`, `storage`, `traversal`, `selector`). **`codec/dagcbor` é implementação original não auditada** e está em uso — risco real. Em `node/basicnode`, mixins viraram herança e builders/assemblers foram fundidos, preservando o contrato observável. |
| `transpiled_datastore` | `(root)`, `query` e a conformance suite `dstest` com paridade comprovada. Consumido por `lib/src/repo`, `lib/src/blockstore` e `transpiled_boxo`. |
| `transpiled_libp2p_kbucket` | Paridade comprovada, com dois defeitos reais do port corrigidos: o gerador de prefix map hasheava 6 bytes em vez de 34, e `~origMask` não tinha máscara de 8 bits. `peerdiversity` fora de escopo (depende de `go-cidranger` e `go-libp2p-asn-util`, não clonados). |
| `transpiled_libp2p_record` | Paridade comprovada (`Validator`, `SplitKey`, `PublicKeyValidator`, `MakePutRecord`). Consumido por `transpiled_libp2p_routing_helpers`; o servidor DHT do nó ainda não valida registros por ele. |
| `transpiled_libp2p_routing_helpers` | Paridade comprovada em `Bootstrap`, `NullRouter`, `LimitedValueStore`, `Compose`, `Parallel`/`Tiered`, `Composable*` e `ProvideManyRouter`. |
| `transpiled_libp2p_pubsub` | O GossipSub em `lib/src/protocols/pubsub/` é implementação original **não auditada**. Do módulo Go só foram portados subpacotes autocontidos: `timecache` (paridade comprovada) e `partialmessages/bitmap` (divergência de `Set` documentada). |
| `transpiled_go_yamux` | Portado sem teste de paridade. RTT/ping keepalive, write coalescing, pooling de buffers e memory manager externo seguem omitidos até haver consumidor. |
| `transpiled_protobuf` | `AppendString` e `ConsumeString` omitidos enquanto strings Go com UTF-8 inválido não forem preservadas. Grupos e campos `fixed` não portados. |
| `transpiled_crypto_tls` | `go-stdlib` **não tem índice AST e não pode ter** com a ferramenta atual (`go_module_index.exe` entra em panic na raiz `module std`). As regras 18–21 não medem o que falta; os 100% reportados valem só para a regra 24. |
| `transpiled_pion_logging` | Portado integralmente. `LogLevel.Set/Get`, `WithXLogger` e `Lshortfile` omitidos deliberadamente. |
| `transpiled_pion_sctp` | Parcial: `util`, `chunktype`, `chunkheader`, a interface `chunk` e CRC32C. Chunks concretos, parâmetros, filas, timers e `association.go` inteiro não portados. O overflow `uint16` em `length - chunkHeaderSize` precisa ser preservado. |
| `packages/boilerplate` | `internal_poll.Fd` e `FdMutex` estão portados e testados, **mas sem chamador de produção**: `_TcpRawConn` em `tcp_transport.dart` ainda usa o paliativo `_serialized`. Plugá-los muda o caminho de escrita de toda conexão TCP e exige decisão do mantenedor. |

O módulo `kubo` é guia de orquestração, não superfície de paridade: só o
lifecycle consumido (`BuildCfg`, `NewNode`, `Close`, `Repo`) está portado.
`Host`, `Routing`, `Permanent`, `DisableEncryptedConnections` e os hooks
`fx.Lifecycle` permanecem omissões deliberadas — o contêiner Fx não é portado,
apenas a finalidade dos hooks (`shutdown.CloseWithCtx`).

## Lacunas conhecidas ainda abertas

- **Reprovide após reinício e após 24h não comprovados.** `_providedCids` segue
  em memória: falta `blockstore.AllKeysChan` → `AllKeysChanWithErr` →
  `datastore.Query(KeysOnly)` → `dshelp.BinaryFromDsKey`.
- **Metadados do peerstore em JSON**, não `encoding/gob`. O record protobuf/TTL,
  o `addr_book_gc.go` (GC em background) e o cache do address book continuam
  fora. A API síncrona do peerstore não pode devolver o erro de um `Future` no
  mesmo call frame: a fila preserva a primeira falha e a propaga em `flush` e em
  `Pstoreds.close`, o que corrige perda silenciosa mas **não comprova paridade
  de timing de erro**.
- **mDNS só IPv4**, sem probing nem goodbye. `zeroconf` não foi portado como
  módulo (dependeria de `miekg/dns`); há um codec DNS mínimo privado dentro do
  pacote libp2p, e essa **dívida estrutural continua de pé**.
- **`EvtNATDeviceTypeChanged` não portado**; o filtro de diversidade da tabela
  de roteamento também não.
- **Chunker/importer**: `maxLinks == 1` com múltiplos chunks nunca foi testado;
  a conversão `int64 → uint32` do construtor e o tratamento de tamanho zero ou
  negativo não têm paridade completa; `strconv.NumError` não tem equivalente
  Dart; cancelamento externo durante leitura pendente e falhas do próprio
  cleanup não têm paridade comprovada.
- **CAR v1**: `CarHeader.version` é `int` Dart e não cobre o domínio `uint64`.
- **Blockstore**: `Provider`, `DeleteBlock`, enumeração, wrappers de validação e
  de GC e cancelamento por contexto estão fora, sem alegação de paridade.
- **DAG-PB**: links ordenados por bytes UTF-8 (não UTF-16); preservar strings Go
  com UTF-8 inválido continua pendente; `DagPbLink` standalone ainda usa o codec
  protobuf legado. `Int64.toIntExact()` é fronteira temporária para `Tsize`, até
  o datamodel IPLD migrar para `Uint64`.

## Lições de porte reutilizáveis

- Todo `~` (complemento de bits) portado do Go precisa da máscara de largura
  correspondente logo depois (`& 0xFF` para 8 bits, e assim por diante).
- Variável top-level em Dart é lazy: importar o arquivo não a executa. O que no
  Go estava em `init()` precisa ir para o construtor, senão o registro
  automático nunca acontece.
- Colisão de nomes entre módulos Go transpilados (por exemplo `Client`, no
  bitswap do `transpiled_boxo` e no circuitv2 do `transpiled_libp2p`) se resolve
  no **ponto de importação**, com `hide` ou prefixo. Os nomes das bibliotecas
  permanecem fiéis ao upstream.
- Neste ambiente Windows/Git-Bash, `dart test` sem `-j 1` é instável no
  reporter. Não é defeito do código.
- Um `catch (_) {}` num handler de handshake torna falha de protocolo
  indistinguível de "ninguém discou", e foi o que escondeu por completo a
  quebra do servidor QUIC de entrada.

## Como auditar

A sequência obrigatória antes de dar qualquer trabalho por concluído está em
`AGENTS.md`, seção "Portão obrigatório de conclusão". Em resumo:
`dart format lib bin test packages` →
`python tool/audit_ast_nomenclature.py --tests --severity ERROR` (precisa sair
em 0) → `--tests` sem filtro → suíte completa (raiz, cada `packages/*/`, e os
presets `interop` e `network`) → regeneração de `PROGRESS_RELATORY.md`
(`--progress`) e `audit_report.md` (`--markdown --output audit_report.md`) →
registro aqui do rastreamento e das decisões.

`dart test` na raiz cobre apenas o pacote raiz, e as tags `p0`, `p1`, `helia` e
`network` são puladas por padrão: "All tests passed" com contagem de pulados não
é prova de suíte verde.
