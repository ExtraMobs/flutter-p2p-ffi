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
| 6 — Matriz de transporte e segurança (G.1–G.7) | **Aberto** (G.1, G.2 e G.3 fechados; G.4 metade; G.5 e G.7 abertos) | ver abaixo |

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
| G.1 QUIC | **comprovada** contra Kubo 0.43.0 (`local_kubo_quic_test.dart`) | **comprovada** contra Kubo 0.43.0 (`local_kubo_quic_inbound_test.dart`) | **marco fechado**; o mesmo `QuicServer` atende `/quic-v1` e WebTransport |
| G.2 TLS 1.3 | **comprovada** | **comprovada** | `local_kubo_tls_handshake_test.dart`; `/tls/1.0.0` volta à lista de segurança padrão |
| G.3 WebSocket | **comprovada** contra bootstrapper público da libp2p (`public_wss_dial_test.dart`) | listener implementado | **marco fechado**; sem porte pendente, o que faltava era a prova |
| G.4 WebTransport | **comprovada** (`local_kubo_webtransport_quic_test.dart`) | **comprovada** contra Kubo 0.43.0 (`local_kubo_webtransport_inbound_test.dart`) | ainda **aberto**: o critério do marco é um navegador Helia, que não foi exercitado |
| G.5 WebRTC Direct | não | não | bloqueado por DTLS, que não está portado |
| G.6 mplex | descartado | — | depreciado na libp2p, removido dos padrões do Kubo |
| G.7 matriz | — | — | `local_kubo_transport_matrix_test.dart` **falha de propósito** |

### G.1 / G.4 — a direção de entrada, fechada contra Kubo real

Um Kubo 0.43.0 real disca o nó Dart em `/quic-v1` e em `/quic-v1/webtransport`,
completa o handshake, abre stream por multistream-select e baixa um bloco por
Bitswap validando o CID. As provas são `local_kubo_quic_inbound_test.dart` e
`local_kubo_webtransport_inbound_test.dart`, ambas no preset `interop`. Nos
dois o nó Dart **apenas escuta** — não disca o Kubo em momento algum, para que
uma conexão de saída não mascare a falha da de entrada.

**O diagnóstico anterior registrado aqui estava errado, e vale dizer por quê.**
Esta seção afirmava que a causa estava localizada na falta de reconhecimento de
Initial repetido e na ausência de recuperação de perda. Essas lacunas eram
reais e foram corrigidas (abaixo), mas **não eram o bloqueio**. As duas causas
de fato eram outras, e ambas ficam invisíveis em loopback Dart-contra-Dart,
porque os dois lados compartilhavam o mesmo defeito:

1. **O transcript TLS hasheava um fragmento do ClientHello.**
   `server_handshake.dart` remontava a mensagem por offset (`_CryptoAssembly`)
   e então escrevia no transcript o `data` do **primeiro CRYPTO frame do
   último pacote Initial**, em vez da mensagem remontada. Com um ClientHello
   que cabe num pacote os dois são a mesma coisa; com o ClientHello real do Go
   1.24+, que é partido, não são. Todo segredo derivado desse transcript
   diverge do que o cliente calcula, então o par não consegue desproteger o
   pacote Handshake do servidor, nunca vê EncryptedExtensions..Finished e por
   isso **nunca manda o segundo flight** — exatamente o sintoma que estava
   documentado como "o cliente não chega a mandar o segundo flight". Go hasheia
   a mensagem inteira: `crypto/tls`'s `readHandshake` devolve uma mensagem
   completa e `handshake_server_tls13.go:66-105` escreve aquilo no transcript.
2. **Faltava o transport parameter `original_destination_connection_id`.**
   A RFC 9000 s. 7.3 o torna obrigatório para servidor, e o Kubo recusava com
   `TRANSPORT_PARAMETER_ERROR (local): missing original_destination_connection_id`.
   O suporte já existia em `transport_parameters.dart` (marshal sob
   `isServer`); o servidor simplesmente nunca preenchia o campo.

Corrigidas as duas, o QUIC de entrada passou. E, como previsto, **o mesmo
conserto destravou o WebTransport**, que roda sobre o mesmo `QuicServer` — o
erro seguinte do Kubo já foi outro, do certificado, tratado abaixo.

**Lacunas de ACK, corrigidas na mesma passagem.** Eram reais, mesmo não sendo o
bloqueio, e um enlace com perda as exporia:

- Initial repetido caía num `continue`: não era aberto, não era contabilizado e
  não era ACKado. O quic-go não tem caso especial nenhum para isso — o pacote
  vai direto para a conexão (`transport.go:584-587`) e só é descartado se o
  *número de pacote* repetir (`connection.go:1366-1383`). Agora o servidor
  decifra, registra e ACKa.
- O único ACK que saía era `AckFrame(largestAcked: <último>, firstAckRange: 0)`,
  que reconhecia apenas o Initial que completou o ClientHello; o primeiro,
  que carregava o começo da mensagem, nunca era reconhecido. Um
  `_ReceivedPacketTracker` (porte reduzido do `receivedPacketTracker` de
  `internal/ackhandler/received_packet_tracker.go:15-16, 30-49`) agora
  acompanha o espaço de números de pacote e emite ranges da RFC 9000 s. 19.3.
- Os pacotes Handshake do cliente — que carregam Certificate, CertificateVerify
  e Finished — **não eram ACKados de forma alguma**. Agora são, imediatamente,
  como manda o comentário do próprio `receivedPacketTracker` (a decimação por
  `max_ack_delay` vale só para AppData, `:78-134`).
- O servidor não enviava `HANDSHAKE_DONE`. Agora envia ao completar
  (RFC 9001 s. 4.1.2), que é o que permite ao par descartar as chaves de
  Handshake e parar de retransmitir aquele flight.

**Um efeito colateral que custou uma rodada de depuração, registrado para quem
mexer aqui depois:** o Source Connection ID do servidor era sorteado só quando
o ClientHello completava. Assim que passou a existir um ACK-only Initial
emitido *antes* disso, o servidor mandava dois SCIDs diferentes na mesma
conexão, e a RFC 9000 s. 7.2 manda o cliente adotar o primeiro e abandonar a
conexão quando um posterior discorda — o handshake, que tinha acabado de
passar, voltou a falhar. O ID passou a nascer junto do espaço Initial, que é
onde o quic-go o escolhe (`transport.go`, `handleInitialImpl`), antes de
qualquer envio.

**O que continua fora:** não há recuperação de perda do lado emissor em
`packages/transpiled_quic_go/lib/src/connection.dart` — sem rastreamento de
pacotes em voo, sem PTO e sem retransmissão de flight. O handshake de entrada
não depende disso para funcionar (o par retransmite o que se perde, e agora é
ACKado), mas um enlace ruim com perda no sentido servidor→cliente não tem
recuperação nenhuma. As referências Go para quando isso for portado continuam
mapeadas abaixo, em "QUIC, direção de entrada (G.1)".

### G.4 — o certificado que faltava

Destravado o QUIC de entrada, o Kubo passou a recusar o WebTransport com uma
mensagem específica e correta:

```
CRYPTO_ERROR 0x12a (local): cert must not be valid for longer than 14 days
(NotBefore: 2026-09-21 ..., NotAfter: 2126-08-28 ..., Length: 876001h0m0s)
```

O listener WebTransport apresentava o **certificado de identidade libp2p**, que
tem validade de ~100 anos por desenho (`certValidityPeriod`,
`p2p/security/tls/crypto.dart:49`). O go-libp2p usa para WebTransport um
certificado **separado, determinístico e de 14 dias**, porque ali o par não
valida cadeia nenhuma: ele fixa a folha pelo SHA-256 anunciado no `/certhash/`,
e a especificação W3C limita por quanto tempo um certificado fixado assim pode
valer.

Portados, em dois arquivos novos:

- `webtransport/crypto.dart` — `generateCert` e as **quatro** checagens de
  `verifyRawCerts` (hash da folha, veto a RSA, validade ≤ 14 dias, janela
  temporal). Antes só o hash era conferido.
- `webtransport/cert_manager.dart` — o bucketing de `getCurrentBucketStartTime`,
  o offset por chave, a rotação com sobreposição de duas folgas de relógio, e o
  anúncio de até três certhashes (retirado, atual e próximo).

`webtransport.dart` passou a consumir o cert manager, e `addCertHashes` — que
hasheava `privKey.raw()`, a chave privada crua, produzindo um `/certhash/` que
jamais bateria com o certificado do handshake — passou a seguir
`transport.go:436-441`.

**O que continua fora:** o critério do marco G.4 é um nó Helia **em navegador**
discando o nó Dart. Isso não foi exercitado, e o marco permanece aberto. O que
está comprovado é a interoperabilidade com Kubo nas duas direções.

### G.3 — a prova contra peer público

`public_wss_dial_test.dart` (preset `network`) resolve em runtime os registros
TXT `_dnsaddr.bootstrap.libp2p.io`, filtra os endereços que carregam `/wss` e
disca de verdade, exigindo que o swarm registre uma conexão viva cujo
transporte seja `websocket` e cujo multiaddr remoto ainda carregue o `/wss`.
Nenhum `canDial()`, nenhum loopback entre dois nós Dart. O teste falha quando
nenhum candidato responde, em vez de ser pulado.

A primeira execução falhou de forma instrutiva, e o motivo vale registro: o
teste resolvia DNS até o IP, e um `/wss` discado para `/ip4/...` não tem
hostname para virar SNI nem cabeçalho `Host`, então o terminador TLS
compartilhado do outro lado fecha a conexão (`EOF reading multistream varint`).
O go-libp2p preserva o nome ordenando sua cadeia de resolvers de modo que o
`Resolve` do próprio transporte — que copia o nome DNS para um componente
`/sni/` (`websocket.go:180-214`) — rode **antes** da etapa DNS→IP:
`dnsAddrResolver`, `skipResolver`, `tptResolver`, `dnsResolver`, nessa ordem
(`p2p/net/swarm/swarm_dial.go:383-446`).

**Lacuna conhecida, deliberadamente não fechada agora:** o `Swarm.dialPeer`
deste porte não roda cadeia de resolvers alguma — entrega o endereço direto ao
transporte, e `WebsocketTransport.resolve` (que existe, portado) **não tem
nenhum chamador**. A interface `transport.Resolver`
(`core/transport/transport.go:88-90`) também não está portada. Aqui isso não
muda nada observável, porque `_maDial` lê o hostname do próprio componente
`/dns*/` e o usa como host de conexão; passa a importar no dia em que o swarm
resolver DNS por conta própria antes de discar.

### G.5 — o que falta é DTLS, não WebRTC

O `certhash` do multiaddr WebRTC Direct é o fingerprint do certificado **DTLS**.
A cadeia que importa é ICE → DTLS → SCTP → DataChannel. A pilha Pion portada
tem `sctp` (wire completo, runtime ausente), `stun`, `sdp`, `transport`,
`transport_v4`, `logging` e `randutil`, e **não tem `dtls`** nem `ice` nem
`datachannel`. O `WebRtcTransport` está registrado no Swarm, mas o handshake
atual é framing inventado sobre UDP em claro: nenhum par real fala isso. Os
módulos de mídia (`rtp`, `rtcp`, `srtp`, `interceptor`) ficaram deliberadamente
fora, porque `/webrtc-direct` usa apenas data channels.

Dimensão medida do que falta, em linhas de Go de produção (`*.go` fora de
teste, `examples/` e `e2e/`):

| Subsistema | Módulo Go | Falta portar |
| --- | --- | --- |
| `pion-sctp` | 8.245 | ≈4.850 — `association.go` (2.960), `stream.go` (514), `reassembly_queue.go` (383), `rtx_timer.go` (257), e as demais filas e timers |
| `pion-dtls` | 15.163 | ≈12.570 — o núcleo; ≈2.595 são dispensáveis (ver abaixo) |
| `pion-datachannel` | 716 | tudo (DCEP) |
| `pion-ice` | 9.434 | ≈6.100 — ≈2.107 dispensáveis (ver abaixo) |
| `pion-webrtc` | 22.602 | a cola; boa parte é mídia, fora de escopo |
| `go-libp2p/p2p/transport/webrtc` | 3.252 | tudo; o transporte Dart atual é descartável |

Da ordem de **27.500 linhas** sem contar a fatia aproveitável do `pion-webrtc`
— a maior frente isolada que resta no projeto, comparável ou maior que todo o
TLS 1.3 do G.2.

Dispensável, verificado no código e não suposto: em `pion-dtls`, o
`listener.go` e seu `internal/net/udp` (o libp2p chama `dtls.Client`/
`dtls.Server` direto sobre o `net.Conn` que o ICE já demultiplexou), o
Connection ID da RFC 9146, as mensagens `*_13` (código morto), e as suítes PSK,
CCM e `ECDHE_RSA_*` — nenhum dos dois lados tem certificado RSA, porque o
libp2p gera ECDSA P-256 em `webrtc/cert.go:105`. Em `pion-ice`, o ICE sobre
TCP, o relay TURN, o mDNS, o mapeamento de IP externo e o parsing de URL de
STUN: o `/webrtc-direct` usa só host candidates entregues por um UDP mux
próprio do libp2p (`webrtc/udpmux/mux.go`), em modo ICE lite
(`webrtc/listener.go:205-221`). **Não** é dispensável a extensão `use_srtp`,
apesar de não haver mídia: `pion-webrtc/dtlstransport.go:326` seta
`SRTPProtectionProfiles` incondicionalmente, então ela precisa ser negociada no
wire para interoperar com nó Go.

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

### Objetivo 6 — símbolos portados na passagem que fechou G.1, G.3 e a entrada do G.4

Rastreamento `chamador Go → símbolo chamado → módulo/revisão → símbolo/pacote
Dart`, como o `AGENTS.md` exige. Revisões em `UPSTREAM_LOCK.md`.

**QUIC, direção de entrada (G.1)** — `packages/transpiled_quic_go/lib/src/server_handshake.dart`:

- Transcript do ClientHello remontado →
  `go-stdlib/src/crypto/tls/handshake_server_tls13.go:66-105` (`handshake`,
  que hasheia a mensagem devolvida por `readHandshake`) → o construtor de
  `HandshakeTranscript` em `_handleClientInitial` passou a escrever
  `helloBytes` (a saída de `_CryptoAssembly.completeMessage`).
- `original_destination_connection_id` →
  RFC 9000 s. 7.3 e `quic-go/connection.go` (`newConnection`, que o preenche a
  partir do DCID do primeiro Initial) →
  `TransportParameters.originalDestinationConnectionId`, já existente em
  `transport_parameters.dart`, agora preenchido pelo servidor.
- `receivedPacketTracker` →
  `quic-go/internal/ackhandler/received_packet_tracker.go:15-16, 30-49` →
  `_ReceivedPacketTracker` (privado; não existe símbolo exportado no Go, e o
  porte cobre só o que o handshake precisa: sem contadores ECN e sem reuso de
  `wire.AckFrame`).
- `IsFrameTypeAckEliciting` → `quic-go/internal/ackhandler/ack_eliciting.go:5-16`
  → predicado embutido em `_handleClientHandshake` (tudo que não é ACK nem
  PADDING elicita ACK).
- Ausência de caso especial para Initial repetido →
  `quic-go/transport.go:584-587` e `connection.go:1366-1383` →
  `_acknowledgeInitial`, que decifra, registra e ACKa em vez de descartar.
- `HandshakeDoneFrame` na conclusão do servidor → RFC 9001 s. 4.1.2 e
  `quic-go/connection.go` (`handleHandshakeComplete`) → `_completeInbound`
  envia `HandshakeDoneFrame`, que já existia em `frames.dart:177-181`.
- Escolha do Source Connection ID antes de qualquer envio →
  `quic-go/transport.go` (`handleInitialImpl`) e RFC 9000 s. 7.2 →
  `_InitialSpace.serverConnectionId`, final, sorteado na criação do espaço.

**WebTransport (G.4)** — `packages/transpiled_libp2p/lib/src/p2p/transport/webtransport/`:

- `getTLSConf` (`webtransport/crypto.go:31-42`) e `generateCert` (`:48-96`) →
  `crypto.dart`'s `generateCert`, devolvendo `WebtransportCertificate` (DER +
  signer + janela). Adaptação registrada: o Go devolve
  `(*x509.Certificate, *ecdsa.PrivateKey)` e embrulha em `tls.Config`, e este
  projeto não tem nenhum dos dois tipos; o tipo está na allowlist
  `DOCUMENTED_ADAPTATIONS` do auditor.
- `newDeterministicReader` (`crypto.go:148-150`) → `_DeterministicReader`
  (HKDF-SHA256 em fluxo, RFC 5869). A string `info` preserva o typo
  `"determinisitic cert"` do upstream (`crypto.go:28`), que é byte de fio.
- `verifyRawCerts` (`crypto.go:107-146`) → `crypto.dart`'s `verifyRawCerts`,
  com as quatro checagens; `_verifyRawCerts` em `webtransport.dart` virou um
  desembrulho de multihash que delega a ela.
- `ErrCertHashMismatch` (`crypto.go:98-104`) → `CertHashMismatchException`
  (Regra 13 do auditor).
- `certValidity` (`transport.go:41`), `clockSkewAllowance` e
  `validityMinusTwoSkew` (`cert_manager.go:22-23`) → constantes homônimas em
  `cert_manager.dart`.
- `getCurrentBucketStartTime` (`cert_manager.go:82-85`) →
  `currentBucketStartTime`.
- `certManager` (`cert_manager.go:48-61`), `newCertManager`/`init` (`:63-71`,
  `:87-108`), `rollConfig` (`:110-125`), `background` (`:127-154`) →
  `CertManager` (público por falta de visibilidade de pacote no Dart, como já
  se fez com `keyToCertificate`; fora da API exportada em
  `transpiled_libp2p.dart`).
- `AddCertHashes` (`transport.go:436-441`) →
  `WebtransportTransport.addCertHashes`, que antes hasheava `privKey.raw()`.

  Três métodos do Go ficam sem contraparte de mesmo nome, e o auditor os
  aponta como INFO na Regra 20: `GetConfig` devolve um `tls.Config`, que não
  existe aqui, e vira o getter `current`; `SerializedCertHashes` vira
  `certHashes`, sem o envelope multihash (os chamadores querem digest cru, e o
  único ponto que precisa de envelope o monta); e `cacheAddrComponent` fica no
  transporte, porque seu auxiliar `addrComponentForCert` mora no arquivo de
  multiaddr, que importa o do cert manager.

**Divergências deliberadas do certificado, nenhuma observável por um par.**
Um par confere o certificado contra o `/certhash/` que o **próprio nó**
publicou, de modo que a derivação nunca é comparada entre implementações; o que
precisa valer, e vale, é a propriedade observável — mesma chave de host e mesma
janela dão o mesmo certificado, então um reinício preserva o `/certhash/` que
um par possa ter em cache.

1. O Go deriva a chave P-256 do seed de 192 bits com `filippo.io/keygen`, que
   **não está na árvore upstream fixada**; o porte expande o mesmo seed com
   HKDF-SHA256 e faz rejection sampling em `[1, n)`, que é o método de
   "geração por teste de candidatos" da FIPS 186-5 A.2.1 que o próprio
   `keygen` documenta seguir.
2. O Go obtém assinatura determinística passando fonte de aleatoriedade nula
   para `ecdsa.Sign` (`deterministicSigner`, `crypto.go:161-175`); o porte usa
   RFC 6979, a construção padrão para a mesma propriedade.
3. A codificação ASN.1 segue a RFC 5280 direto, e não `crypto/x509`, que está
   **fora do checkout esparso** de `go-stdlib` (ver `UPSTREAM_LOCK.md`). O
   template codificado é o do upstream, campo a campo (`crypto.go:66-75`).

**WebSocket (G.3)** — nada foi portado: o transporte já estava completo, e o
que faltava era a prova. Ver a seção "G.3 — a prova contra peer público" acima,
inclusive a lacuna do `tptResolver` que continua aberta.

### Objetivo 6 — símbolos Go localizados, ainda não portados

O que resta. Caminhos relativos a `go-ipfs-reference/`, revisões em
`UPSTREAM_LOCK.md`: é o mapa de onde buscar a autoridade de comportamento.

**QUIC, recuperação de perda do lado emissor** — destino Dart
`packages/transpiled_quic_go/lib/src/{server_handshake,connection}.dart`:

- ACK imediato em Initial/Handshake e decimação só em AppData →
  `quic-go/internal/ackhandler/received_packet_tracker.go:30-49` e `:78-134`
  (`ReceivedPacket`, `appDataReceivedPacketTracker.shouldQueueACK`);
  `GetAckFrame` em `:51-72`; `MaxAckDelay = 25ms` em
  `quic-go/internal/protocol/params.go:150`.
- Frames que elicitam ACK → `quic-go/internal/ackhandler/ack_eliciting.go:5-16`
  (`IsFrameTypeAckEliciting`).
- Limite anti-amplificação 3x e validação de endereço →
  `quic-go/internal/ackhandler/sent_packet_handler.go:25, 224-263, 1034-1039`
  (`amplificationFactor`, `ReceivedBytes`, `isAmplificationLimited`).
- Coalescência ao enviar e padding de 1200 B só quando o Initial é
  ack-eliciting → `quic-go/packet_packer.go:333-421` (`PackCoalescedPacket`) e
  `:318-328` (`initialPaddingLen`); `MinInitialPacketSize` em
  `quic-go/internal/protocol/protocol.go:119`.
- Split do datagrama recebido → `quic-go/connection.go:1052-1168`
  (`handleOnePacket`).
- Packet number truncado → `quic-go/internal/protocol/packet_number.go:24-39`
  (`DecodePacketNumber`); header protection, máscara de 4 bits em Long e 5 em
  Short → `quic-go/internal/handshake/header_protector.go:67-80`.
- Handshake servidor TLS 1.3 e o instante em que cada chave passa a valer →
  `go-stdlib/src/crypto/tls/handshake_server_tls13.go:66-105` (`handshake`),
  `:730-832` (`sendServerParameters`, chaves em 769-780 e EE em 827),
  `:838-904` (`sendServerCertificate`), `:906-941` (`sendServerFinished`),
  `:1047-1162` (`readClientCertificate`, `readClientFinished`); read secret
  1-RTT só após o Finished do cliente, em `go-stdlib/src/crypto/tls/conn.go:1591-1597`.
- Ponte CRYPTO ↔ `crypto/tls` →
  `quic-go/internal/handshake/crypto_setup.go:224-246, 456, 498, 556`.
- PeerId da cadeia de certificados no listener →
  `go-libp2p/p2p/transport/quic/listener.go:115-148` e
  `go-libp2p/p2p/security/tls/crypto.go:157` (`PubKeyFromCertChain`).

**WebTransport (G.4)** — destino Dart
`packages/transpiled_libp2p/lib/src/p2p/transport/webtransport/webtransport.dart`:

- Certificado determinístico → `go-libp2p/p2p/transport/webtransport/crypto.go:48-96`
  (`generateCert`), info `"determinisitic cert"` em `:29`, salt em `:54-56`,
  reader em `:148-150`, seed ECDSA P-256 em `:78-86`, signer em `:161-175`;
  `certValidity = 14 dias` em `webtransport/transport.go:41`.
- `verifyRawCerts` com as quatro checagens (hash do leaf, veto a RSA, validade
  ≤ 14 dias, janela temporal) → `webtransport/crypto.go:107-146`. O Dart em
  `webtransport.dart:571` confere só o hash.
- Rotação com até três certhashes anunciados em paralelo e 1h de skew →
  `webtransport/cert_manager.go:19-23, 44-58, 89-155, 182-219`.
- Early data `webtransport_certhashes` → `webtransport/listener.go:269-304` e
  `webtransport/noise_early_data.go:12-36`. A extensão **não** é assinada: viaja
  no payload Noise cifrado, e a assinatura cobre só a chave estática
  (`go-libp2p/p2p/security/noise/handshake.go:219-244, 249-286`).
- SETTINGS e Extended CONNECT do servidor → `quic-go/http3/server.go:456-461`,
  `webtransport-go/server.go:38-63` (`ConfigureHTTP3Server`) e `:374-436`
  (`Server.Upgrade`, com timeout de 5s esperando as SETTINGS do cliente);
  `:protocol` em `quic-go/http3/headers.go:96, 231-263, 294-299`.

**WebSocket (G.3)** — nada a portar; referências de conferência em
`go-libp2p/p2p/transport/websocket/`: `websocket.go:243-285` (`maDial`, SNI →
`ServerName` e Host header, `NetDial` discando o IP já resolvido),
`addrs.go:133-175` (`parseWebsocketMultiaddr`, `/wss` → `/tls/ws`),
`websocket.go:180-214` (`Resolve`), `conn.go:39-64, 126-135` (mensagem sempre
binária, uma por `Write`) e `conn.go:17-19, 110-114, 144-153` (close 1000/1005
como EOF, fechamento gracioso em 100ms). O pacote **não** tem `crypto.go` nem
`cert_manager.go`: o TLS do listener é o `tls.Config` injetado.

**WebRTC Direct (G.5)**:

- Flights DTLS → `pion-dtls/flight.go`, `flighthandler.go` e
  `flight0handler.go`…`flight6handler.go` (9 estados; cliente e servidor no
  mesmo arquivo, com branch por `state.isClient`); laço em
  `pion-dtls/handshaker.go`.
- Retransmissão: intervalo inicial de 1s (`pion-dtls/conn.go:31`), backoff
  dobrando com teto de 60s (`handshaker.go:288, 337, 339-340`).
- Record layer → `pion-dtls/pkg/protocol/recordlayer/`; fragmentação de
  mensagem de handshake → `pion-dtls/fragment_buffer.go`.
- Cookie exchange → `pion-dtls/flight2handler.go:44-49`,
  `pkg/protocol/handshake/message_hello_verify_request.go`,
  `pkg/protocol/extension/cookie.go`.
- Suítes default → `pion-dtls/cipher_suite.go:167` (`defaultCipherSuites`); só
  as três ECDSA são alcançáveis.
- Certificado determinístico ECDSA P-256 →
  `go-libp2p/p2p/transport/webrtc/cert.go:105`; o fingerprint que vira certhash
  **não** é o do pion, e sim `webrtc/fingerprint.go:20, 43`
  (`parseFingerprint`, `encodeDTLSFingerprint`).
- UDP mux próprio do libp2p, que demultiplexa por ufrag lido do USERNAME do
  STUN → `go-libp2p/p2p/transport/webrtc/udpmux/mux.go`, uso em
  `webrtc/listener.go:97`; ICE lite e papel DTLS de servidor em `:205-221`.
- Sem sinalização: as duas SDPs são fabricadas localmente →
  `webrtc/transport.go:389` (`createServerSDP`) e `webrtc/listener.go:233-236`
  (`createClientSDP`). Os fingerprints são amarrados no prólogo Noise
  (`webrtc/transport.go:509, 530-538`).
- Canal 0 do handshake Noise é `negotiated=true` e não passa por DCEP →
  `webrtc/transport.go:53-62, 602`. Um data channel SCTP por stream libp2p →
  `webrtc/connection.go:184`.
- Framing protobuf dos streams (FIN, STOP_SENDING, RESET, FIN_ACK) →
  `webrtc/pb/message.proto`; limites em `webrtc/stream.go:17-43`
  (`maxSendMessageSize = 16384`, `maxReceiveMessageSize = 257 KiB`,
  `maxFINACKWait = 10s`), leitura delimitada por varint em `:111`.
- ICE efetivamente exercitado: só `gatherCandidatesLocalUDPMux`
  (`pion-ice/gather.go:324`), mais `agent.go`, `candidate_base.go`,
  `selection.go`, `udp_mux.go` e `udp_muxed_conn.go`.

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
| `transpiled_pion_sctp` | **Wire completo, runtime ausente.** 42 arquivos e 4.625 linhas cobrem todos os chunks concretos, todos os parâmetros, as error causes, `packet.dart`, `util` e CRC32C. O que falta é o motor: `association.go` (2.960 linhas), `stream.go`, as filas (`pending`, `payload`, `control`, `receive_payload`, `reassembly`) e os timers (`rtx_timer`, `ack_timer`) — ≈4.850 linhas de Go. O overflow `uint16` em `length - chunkHeaderSize` precisa ser preservado. |
| `packages/boilerplate` | `internal_poll.Fd` e `FdMutex` estão portados e testados, **mas sem chamador de produção**: `_TcpRawConn` em `tcp_transport.dart` ainda usa o paliativo `_serialized`. Plugá-los muda o caminho de escrita de toda conexão TCP e exige decisão do mantenedor. |

O módulo `kubo` é guia de orquestração, não superfície de paridade: só o
lifecycle consumido (`BuildCfg`, `NewNode`, `Close`, `Repo`) está portado.
`Host`, `Routing`, `Permanent`, `DisableEncryptedConnections` e os hooks
`fx.Lifecycle` permanecem omissões deliberadas — o contêiner Fx não é portado,
apenas a finalidade dos hooks (`shutdown.CloseWithCtx`).

## Lacunas conhecidas ainda abertas

- **O caminho de entrada travava o nó inteiro depois de alguns minutos na rede
  pública. Corrigido; a validação em rede real ainda não fechou.**
  `_TcpListener.accept()` executava o upgrade completo — multistream-select,
  Noise/TLS e yamux — dentro da própria chamada, e `Swarm._startAcceptLoop` a
  chamava **em série**. Um único par que abrisse TCP sem falar nada bloqueava a
  fila para sempre, porque não havia timeout de accept; os sockets seguintes se
  acumulavam num `List` sem limite, e o `catch (_)` do laço engolia o erro.

  Comprovado em rede real antes do conserto: um nó recém-iniciado aceitava o
  dial de um Kubo local pelo loopback; quarenta minutos depois, com ~200
  sockets TCP estabelecidos vindos da DHT pública, o **mesmo** dial falhava com
  `failed to negotiate security protocol: context deadline exceeded`. Nesse
  estado o nó seguia anunciado e descoberto — o provider record na DHT,
  `trustless-gateway.link` achando os providers — e respondia
  `none were reachable`.

  O conserto porta `p2p/net/upgrader/listener.go`: os transportes deixaram de
  negociar dentro do `accept()` e passaram a entregar um `GatedMaListener` a
  `Upgrader.upgradeGatedMaListener`, que negocia em paralelo, com
  `_defaultAcceptTimeout` de 15 s cobrindo negociação **e** entrega, fila de
  entrega limitada a `acceptQueueLength` (16) e falha logada em vez de
  propagada. Atinge TCP e WebSocket; **QUIC nunca foi atingido**, porque
  `QuicServer.handleDatagram` já processa handshakes de forma assíncrona.

  A prova está em
  `test/atomic/nivel_2/libp2p_upgrader_listener_atomic_tests.dart`: oito pares
  que conectam e não falam nada, seguidos de um dial legítimo. Contra o código
  anterior o teste falha com `TimeoutException`; contra o porte, passa —
  verificado com a árvore antiga, não deduzido.

  **O que ainda falta:** a validação ponta a ponta em rede pública não fechou.
  Reiniciado com o conserto, o nó chegou a **784 sockets externos** em cinco
  minutos (o antigo nunca passava disso enfileirado sem negociar) e então
  **morreu**, pela lacuna do yamux logo abaixo.

- **Sobreviver como servidor DHT: três das quatro camadas do go-libp2p
  portadas, e o nó ainda cai.** Derivado do upstream, um nó que serve DHT na
  rede pública se defende em quatro camadas, nesta ordem:

  | Camada | Go | Estado aqui |
  | --- | --- | --- |
  | 0. Só servir quando se deve | `ModeAuto` + `EvtLocalReachabilityChanged` (`dht_options.go:28`, `subscriber_notifee.go:102-126`, `dht.go:788-843`) | **portada, em `ModeOpt.autoServer`** (ver abaixo) |
  | 1. Disciplina por stream | `dhtStreamIdleTimeout` de 1 min (`dht_net.go:20,43`), leitura limitada a `MessageSizeMax` 4 MB | **portada** (o teto de leitura já existia em `dhtMessageSizeMax`) |
  | 2. Admissão no host | `rcmgr.OpenConnection` no listener gated (`upgrader/listener.go:195-210`) e `BasicConnMgr` podando 96→32 (`config/init.go:80-92`) | rcmgr **ligado**, connmgr **não portado** |
  | 3. Contenção de erro | `send()` converte erro de escrita em fim de sessão (`go-yamux/session.go:545-567`) | **portada**, e insuficiente (ver abaixo) |

  **Camada 0 não pode ficar completa.** O padrão do Kubo é `ModeAuto`: serve
  só quando o AutoNAT reporta endereço público. Este porte não tem AutoNAT que
  mereça o nome — `p2p/host/autonat/autonat.dart` tem **69 linhas** contra
  **1849** do `p2p/host/autonat` upstream, nada sonda par algum e
  `setReachability` não tem chamador. Sob alcançabilidade permanentemente
  desconhecida a semântica do Go faz `ModeAutoServer` servir e `ModeAuto` não
  (`subscriber_notifee.go:108-113`), então o default aqui é `autoServer`: é
  exatamente o comportamento de hoje, escrito no vocabulário do upstream em
  vez de fixado no código. Portar AutoNAT de verdade transforma isso numa
  mudança de uma palavra. **A alegação do Marco D.2 de "detecção autônoma de
  reachability (AutoNAT v1/v2)" a 100% não se sustenta perante o código.**

  **Camada 2 está pela metade, e a metade que falta é a que importa.** O
  `ResourceManagerImpl` existe e agora é consultado no accept, mas o piso do
  próprio Kubo para conexões de entrada é `DefaultResourceMgrMinInboundConns =
  800` (`config/init.go:100`): as ~780 conexões que derrubaram este nó estavam
  **dentro** do que o Kubo permitiria. Quem reduz carga lá é o `BasicConnMgr`,
  podando de 96 para 32 com 20 s de carência — e dele só as interfaces estão
  portadas (`core/connmgr/`), não a implementação. Além disso o escopo aberto
  aqui cobre só a negociação, porque `Upgrade` não recebe escopo e
  `CapableConn` não expõe gancho de fechamento; segurar um escopo que ninguém
  libera viraria catraca e estrangularia o listener.

  **Camada 3 revelou um terceiro defeito, específico do `dart:io`.** O
  `YamuxSession._sendFrame` foi corrigido (erro de escrita fecha a sessão, e o
  tail deixou de ficar envenenado), e `_TcpRawConn`/`_WebsocketConn` passaram a
  observar `Socket.done`. Não basta: o `SocketException` de um par que reseta é
  lançado **dentro da subscription interna do `IOSink`**, e chega ao root zone
  por `_RootZone.runUnaryGuarded` — `done` não é o canal por onde ele passa.
  Medido: com as correções o nó passou de morrer em menos de um minuto para
  sobreviver três, com 653 sockets, e então caiu pela mesma exceção.

  A saída fiel é deixar de escrever pelo `IOSink`: `RawSocket.write` devolve o
  erro ao chamador de forma síncrona, que é a semântica de `net.Conn.Write` do
  Go. Isso é uma reescrita do `_TcpRawConn` (buffer e backpressure próprios) e
  não foi feita.

- **Sem recuperação de perda no emissor QUIC.**
  `packages/transpiled_quic_go/lib/src/connection.dart` não rastreia pacotes em
  voo, não tem PTO e não retransmite flight. O handshake de entrada funciona
  sem isso porque o par retransmite o que se perde e agora é reconhecido, mas
  perda no sentido servidor→cliente não tem recuperação nenhuma.
- **O `Swarm` não roda cadeia de resolvers.** `dialPeer` entrega o endereço
  direto ao transporte;
  `WebsocketTransport.resolve` está portado e **não tem chamador**, e a
  interface `transport.Resolver` (`core/transport/transport.go:88-90`) não está
  portada. Hoje não muda nada observável — `_maDial` lê o hostname do
  componente `/dns*/` —, mas fecha a porta para o swarm resolver DNS por conta
  própria.
- **Critério de navegador do G.4 não exercitado.** A interoperabilidade
  WebTransport está comprovada nas duas direções contra Kubo; nenhum nó Helia
  em navegador discou o nó Dart.
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
