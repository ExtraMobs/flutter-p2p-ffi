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

### G.3 — a prova voltou a rodar depois de um cast defasado

`public_wss_dial_test.dart` esteve vermelho entre o porte de `swarm.Conn`
(`769e515d`) e 2026-09-22, sem que ninguém notasse, porque a suíte de interop
não roda no `dart test` da raiz. O teste fazia `conns.first as CapableConn`, e
desde aquele porte `Swarm.connsToPeer` devolve `SwarmConn`, que implementa
`Conn` e não `CapableConn` — `type 'SwarmConn' is not a subtype of type
'CapableConn' in type cast` nos quatro bootstrappers, depois de a conexão já
ter sido estabelecida. O cast era supérfluo: `connState()` e
`remoteMultiaddr()` são de `Conn` (`core/network/conn.go:64-71`, via
`ConnStat` e `ConnMultiaddrs`), e `connsToPeer` devolve `[]network.Conn` no
upstream também. Removido o cast, a asserção original passa sem alteração.

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

### Gerenciador de conexões (`p2p/net/connmgr`)

- `BasicConnMgr` (`connmgr.go:30-55`) → `BasicConnMgr` em
  `packages/transpiled_libp2p/lib/src/p2p/net/connmgr/connmgr.dart`.
  `NewConnManager` (`:111-151`) → factory que lança; `CMInfo` (`:614-629`) →
  `CmInfo`, renomeado pela Regra 1 (acrônimos como palavras). `cmNotifee`
  (`:653`) é uma conversão de tipo do Go sem equivalente em Dart, e virou a
  classe privada `_CmNotifee` com referência de volta.

  Os três arquivos upstream são um pacote Go só, compartilhando `config`,
  `segments`, `peerInfo`, `decayer` e `decayingTag` não exportados. São uma
  biblioteca Dart só, dividida com `part`, como já faz `transpiled_pion_sdp`.
  Mantê-los como bibliotecas separadas obrigaria a tornar esses tipos públicos.

  **As cinco famílias de trava foram omitidas, os 256 shards não.** `segment.Mutex`
  (×256), `segments.bucketsMu`, `plk`, `trimMutex` e `lastTrimMu` disciplinam
  threads preemptivas; um isolate Dart não preempta dentro de código síncrono, e
  nenhuma das regiões que elas guardam tem `await`. O `bucketsMu` existe só para
  impor ordem global de aquisição e evitar deadlock ABBA em
  `SortByValueAndStreams` (`:276,289`), e some junto com o deadlock. Os buckets
  em si foram portados literalmente, indexados por `peerId.value.last`.

  **`trimMutex` + `trimCount` são a exceção, e sobreviveram.** Esse par não é
  trava, é coalescedor (`:369-381`): N chamadas concorrentes produzem um trim.
  Em Dart continua necessário por um motivo que o Go não tem — fechar conexão é
  assíncrono, e o `await` é exatamente onde um segundo `trimOpenConns` entra.
  Virou single-flight sobre o Future em voo, preservando a semântica observável;
  o contador de gerações deixou de existir e `lastTrim` permanece, porque
  `getInfo()` o lê.

  **`TrimOpenConns` passou a devolver `Future<void>`**, contra o `void` do
  upstream e o `void` que a interface `ConnManager` declarava. O Go documenta
  que ele "blocks until a trim is completed" (`core/connmgr/manager.go:53`), e
  em Dart isso se escreve com Future; com `void`, o chamador perderia tanto o
  sinal de término quanto qualquer erro.

  Outras adaptações: `background()` (`:344-367`) é goroutine e virou assinatura
  do ticker do relógio injetado, com `refCount sync.WaitGroup` e o par
  `ctx`/`cancel` colapsando no cancelamento dessa assinatura;
  `connCount atomic.Int32` virou `int`; `CheckLimit` (`:240-249`) lança
  `StateError` com a mensagem do upstream, porque não há tipo de erro nomeado
  lá para portar e inventar um público violaria a Regra 12.

  Omissão deliberada: `unregisterMemoryWatcher` (`:54`) é campo morto upstream —
  nunca atribuído, lido só defensivamente em `Close` (`:186-188`).

  **Bug do upstream reproduzido de propósito.** `getConnsToCloseEmergency:425`
  compara `len(selected) >= target` com `target` já decrementado pelo laço
  acima, de modo que a condição é quase sempre verdadeira e o segundo passo — o
  único caminho em que uma conexão protegida é fechada — quase nunca roda.
  Portar a intenção em vez do código mudaria o comportamento contra um par real.

- `decayer` e `decayingTag` (`decay.go:32-52,288-299`) → `_Decayer` e
  `_DecayingTag`, privados como no upstream; `DecayerCfg` (`:57-60`) e
  `DefaultResolution` (`:16`) → `DecayerCfg` e `defaultResolution`, públicos.

  O `process()` upstream é uma goroutine com `select` de cinco vias sobre um
  tique e três canais de comando (`bumpTagCh`, `removeTagCh`, `closeTagCh`,
  buffer 128 cada). Os canais existem para tirar trabalho da thread do chamador
  e não bloquear em lock de segment; sem threads e sem locks, os comandos são
  aplicados de forma síncrona e os canais desaparecem. Só o tique sobrevive,
  como assinatura do ticker.

  **Mudança observável a registrar:** `Bump` e `Remove` do upstream falham por
  dois motivos, tag fechada *ou* fila cheia (`:322-326`, `:339-343`). Só o
  primeiro resta aqui, e virou `StateError`.

  Uma divergência de runtime que exigiu guarda: `NewDecayer` chega em
  `time.NewTicker(cfg.Resolution)` (`:157`), que entra em panic com intervalo
  não positivo. O `Timer.periodic` do Dart, em vez disso, giraria quente, então
  o panic foi reproduzido como `ArgumentError`.

  Armadilha preservada: `cfg.clock` e `cfg.decayer.Clock` são independentes e
  `NewConnManager` não propaga um para o outro (`:76-78`).

- **Fiação do manager (chamadores).** `BasicHost.NewHost`
  (`p2p/host/basic/basic_host.go:275-281`) → construtor de `BasicHost` em
  `packages/transpiled_libp2p/lib/src/p2p/host/basic/basic_host.dart`:
  `n.Notify(h.cmgr.Notifee())` só roda quando `opts.ConnManager != nil`, e a
  porta Dart preserva isso testando o parâmetro, não o campo — que já caiu no
  `NullConnMgr`. `BasicHost.Close` (`:639-641`) → `close()`, com
  `_connManager.close()` antes do `_network.close()`.
  `kubo/config/init.go:79-93` (`DefaultConnMgr{High,Low}Water`,
  `DefaultConnMgrGracePeriod`, `DefaultConnMgrSilencePeriod`) →
  `BasicConnMgr(32, 96, [withGracePeriod(20s), withSilencePeriod(10s)])` em
  `lib/src/node/ipfs_node.dart`.

  Do lado do bitswap, `impl.TagPeer`/`UntagPeer`/`Protect`/`Unprotect`
  (`boxo/bitswap/network/bsnet/ipfs_impl.go:529-555`) → os métodos homônimos de
  `IpfsNetwork`, delegando a `_host.connManager`. Isso exigiu `connManager` na
  interface `P2pHost` (`packages/transpiled_boxo/.../network/interface.dart`),
  contraparte de `host.Host.ConnManager()`
  (`go-libp2p/core/host/host.go:60`) — `P2pHost` é a abstração estreita que
  este porte usa no lugar de `host.Host`. Em
  `bitswap/client/internal/peermanager/peerwantmanager.dart`,
  `BroadcastControl.host` deixou de ser `dynamic` e passou a `Host?`, e
  `skipBroadcast` (`peerwantmanager.go:282-292`) voltou a consultar
  `connMgr.isProtected(peerID, peering.ConnmgrTag)`. `peering.ConnmgrTag`
  (`boxo/peering/peering.go:26`) é constante privada local, porque
  `boxo/peering` não tem porte e criá-lo seria subsistema novo.

- `Option` (`options.go:21`) é `func(*config) error` sobre um `config` não
  exportado. Dart não expressa typedef público sobre tipo privado sem vazá-lo
  (Regra 23), então virou uma classe opaca que embrulha a função.
  `DecayerConfig`, `WithClock`, `WithGracePeriod` e `WithSilencePeriod`
  (`:24-63`) seguem funções livres, com os mesmos nomes em lowerCamelCase.

### Conexão de nível swarm e relógio injetável

Pré-requisitos do `BasicConnMgr`, portados antes dele.

- `clock.Clock` / `clock.New` / `clock.Mock` (`clock.go:18-35,75-88`,
  benbjohnson/clock @ `96c602ca`, v1.3.5) → `Clock`, `Clock()` (factory) e
  `Mock` em `packages/transpiled_clock/lib/src/clock.dart`. `Ticker` e `Timer`
  idem. Pacote próprio por fronteira de `go.mod` (Regra 11).

  Omissões deliberadas: `WithDeadline`/`WithTimeout` (`clock.go:28-29`,
  `context.go`), porque este porte não modela `context.Context` e nenhum
  consumidor os usa; e `type Duration = time.Duration` (`clock.go:11`), porque
  `Duration` é nativo em Dart. `internalTimer`/`internalTicker`
  (`clock.go:319,386`) são um idioma de Go — conversão de struct para um
  segundo tipo nomeado só para trocar o method set — sem equivalente em Dart:
  `Timer` e `Ticker` implementam o contrato privado `_ClockTimer` direto.
  `gosched()` (`clock.go:410`), que dorme 1 ms para ceder a outras goroutines,
  virou um `await Future.delayed(Duration.zero)`, que drena a fila de
  microtasks — é o que faz um `StreamController` entregar aos ouvintes antes de
  o mock avançar de novo. Isso torna `Mock.add`/`Mock.set` assíncronos, ao
  contrário do upstream.

  Armadilha preservada: `cfg.clock` e `cfg.decayer.Clock` são independentes no
  upstream e `NewConnManager` não propaga um para o outro (`decay.go:76-78`).

  **Não** foi unificado com o `Clock`/`RealClock` de
  `p2p/host/peerstore/pstoreds/options.dart`: aquele é porte de uma interface
  própria e não exportada do go-libp2p (`pstoreds/addr_book.go:153-165`), de
  outro módulo. Fundir os dois seria violação de fronteira (Regra 11).

- `swarm.Conn` (`p2p/net/swarm/swarm_conn.go:25-38`, go-libp2p) → `SwarmConn`
  em `packages/transpiled_libp2p/lib/src/p2p/net/swarm/swarm_conn.dart`.
  Renomeado porque `Conn` já nomeia o `network.Conn` que a classe implementa;
  registrado em `DOCUMENTED_ADAPTATIONS` do auditor, como o `SwarmStream` já
  estava. `ErrConnClosed` (`swarm_conn.go:20`) → `ConnClosedException`.
  `doClose` (`:73-110`) → `_doClose`, com a guarda de `closeOnce` virando um
  booleano. `As(target)` (`core/network/conn.go:103`) omitido: é escape de
  reflexão do Go, sem equivalente e sem chamador.

- `network.Conn` (`core/network/conn.go:64-104`) → `Conn`
  (`core/network/network.dart`), que era **uma interface vazia**. A causa era
  estrutural, não um esquecimento: `transport.CapableConn`
  (`core/transport/transport.go:28-36`) não é um `network.Conn` no upstream, e
  como o `swarm.Conn` nunca havia sido portado, não sobrava nada para `Conn`
  declarar. Com o porte, `RawConn` e `CapableConn` deixaram de declarar
  `implements Conn`.

- `network.MuxedStream` (`core/network/mux.go:33-71`) → `MuxedStream`, separado
  de `NetworkStream` (`core/network/stream.go:44-73`). Consequência direta do
  item anterior: `CapableConn.openStream`/`acceptStream` passaram a devolver
  `MuxedStream`, e a identidade de nível libp2p (id, protocolo, stat, scope,
  conexão dona) ficou só no `SwarmStream`, que agora envolve um `MuxedStream`
  em vez de um `YamuxStream` — como o `swarm.Stream` do Go envolve um
  `network.MuxedStream`.

- `Upgrader.Upgrade` (`core/transport/transport.go:168`) recebe um
  `manet.Conn`, não um `network.Conn` → `Upgrader.upgrade` passou de
  `Conn` para `RawConn`. Isso eliminou `_GenericRawConn`, um shim de 55 linhas
  em `basic_upgrader.dart` que existia só para adaptar um `Conn` qualquer a
  `RawConn`.

- `network.Conn.CloseWithError` (`core/network/conn.go:75`) e
  `network.MuxedConn.CloseWithError` (`core/network/mux.go:20`) →
  `closeWithError` em `Conn` e `CapableConn`. Dos cinco transportes, só o QUIC
  entrega o código ao par: `QuicConn.close([errorCode])`
  (`packages/transpiled_quic_go/lib/src/connection.dart:375-389`) emite
  `ConnectionCloseFrame` com `isApplicationError: true`. Yamux/TCP, WebSocket,
  WebRTC e WebTransport degradam para `close()`, que é o que o contrato
  upstream manda (`conn.go:72-74`). No WebTransport a limitação é do porte, não
  do protocolo: `Session.close()`
  (`packages/transpiled_webtransport_go/lib/src/session.dart:149-161`) não
  aceita código para repassar.

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

### Fronteira de módulo do kad-dht e tipos de rede do stdlib

- **`packages/transpiled_libp2p_kad_dht/` criado.** O porte de
  `go-libp2p-kad-dht` (módulo próprio, `10e0adf9` no `UPSTREAM_LOCK.md`) vivia
  em `lib/src/protocols/dht/` e `lib/src/routing/`, contra a regra de fronteira
  de `go.mod`. `dht_message.dart`, `dht_provider_manager.dart`,
  `dht_server.dart`, `query_peerset.dart` e `dht_provider_finder.dart` foram
  movidos com `git mv`; em `lib/` ficou só a integração do nó.

  Uma coisa **não** foi mecânica, e é registro obrigatório: o adaptador
  `Libp2pRouter` (`lib/src/network/libp2p_host.dart`) é símbolo inventado neste
  repositório e é glue compartilhada com o Bitswap, então não podia entrar num
  pacote transpilado nem ser importado de `lib/` por ele — a dependência seria
  circular. Dentro do pacote ele deu lugar a `Host` direto, que é a forma do
  upstream: `IpfsDHT` guarda `host.Host` (`dht.go:105`), não um adaptador.
  `DhtClient` e `DhtServer` passaram a receber `host:` em vez de `router:`, e os
  três usos do adaptador viraram funções privadas por arquivo:
  `_addrsFor` (Go inlina `dht.host.Peerstore().Addrs(p)`, `handlers.go:80-96`),
  `_connect` e `_maybeAddAddrs` (`maybeAddAddrs`, `dht.go:958-964`).

  **Divergência deliberada, a fechar depois:** `_maybeAddAddrs` ainda não tem os
  dois guards do upstream — pular peers já conectados (`hasValidConnectedness`,
  "we have better ones") e `dht.filterAddrs`. Portá-los muda comportamento de
  DHT e não cabia no mesmo commit de uma movimentação de arquivos.

  `Libp2pRouter` continua em `lib/` porque o `BitswapClient` o usa, e seus
  testes atômicos seguem em `test/atomic/nivel_2/lib_atomic_tests.dart`.

- **`boilerplate/net_netip/` — `netip.Addr` e `netip.Prefix`.** `conn_limiter.go`
  (10 usos), `conn_rate_limiter.go` (2), `conngater.go` (11) e `dialpolicy.go`
  (1) fazem aritmética de prefixo de sub-rede; sem um tipo comum cada um
  reimplementaria máscara de `/56` e `/48` à mão, que é o que a Regra 10 proíbe.
  `net/netip` é stdlib e não pertence a nenhum `go.mod` transpilado, então mora
  em `boilerplate`, pelo mesmo critério já usado por `internal_poll/`.

  Adaptação registrada: o Go guarda `uint128` + discriminador de zona `z`,
  mantendo IPv4 em forma 4-em-6 e distinguindo por `z4`. Este porte guarda os 4
  ou 16 bytes de origem — é a mesma distinção que `AddrFromSlice` já faz por
  tamanho (`netip.go:349-356`) — o que torna as comparações mascaradas
  byte-a-byte em vez de exigir aritmética de 128 bits. Zonas (`%eth0`) não são
  representadas: nenhum chamador daqui as analisa, e `Prefix.Contains` rejeita
  endereço com zona de saída (`netip.go:1429`). Parse e formatação delegam a
  `InternetAddress` do `dart:io`, que `boilerplate` já usa em `internal_poll/`.

  Os vetores dos testes atômicos (`test/atomic/nivel_1/`
  `boilerplate_netip_atomic_tests.dart`) foram **executados em Go 1.25.7**, não
  deduzidos: incluem `p4.Contains(a6) == false`, `p4.Contains(::ffff:127.0.0.1)
  == false`, `Addr.Prefix` mascarando `1.2.3.4/24 -> 1.2.3.0/24` e
  `2001:db8::1/56 -> 2001:db8::/56`, e `zero.Prefix(8)` devolvendo prefixo
  inválido **sem** erro (`netip.go:683-684`).

### Limitador de taxa (`golang.org/x/time/rate`) e `net.IP`

- **`packages/transpiled_golang_x_time/` criado**, portando `rate.go` (427
  linhas) e `sometimes.go`. Foi preciso porque `go-libp2p/x/rate/limiter.go`
  — dependência do `conn_rate_limiter.go` do rcmgr — importa
  `golang.org/x/time/rate`, que é módulo `go.mod` próprio e não estava clonado.
  Revisão travada no `UPSTREAM_LOCK.md` em **v0.15.0** / `812b343c8714`, que é
  o que `go-libp2p/go.mod:66` fixa; o clone tinha vindo no tip do master, mais
  novo, e foi recuado para a tag.

  Portados: `Limit` (classe real — `type Limit float64` é *defined type* com
  método próprio, não alias), `Limit.inf`, `every`, `infDuration`, `Limiter`
  (`NewLimiter` → construtor, `allow`/`allowN`, `reserve`/`reserveN`,
  `wait`/`waitN`, `setLimit(At)`, `setBurst(At)`, `tokensAt`), `Reservation` e
  `Sometimes`.

  **Renomeação não mecânica, registrada como o `AGENTS.md` exige:**
  `Sometimes.Do` → `Sometimes.run`, porque `do` é palavra reservada do Dart.

  **Adaptação de unidade de tempo, e um defeito que ela evitou.**
  `time.Duration` do Go conta nanossegundos e `Duration` do Dart conta
  microssegundos. `InfDuration = time.Duration(math.MaxInt64)` **não** pode ser
  copiado como o mesmo inteiro bruto reinterpretado em microssegundos: daria
  ~292.471 anos em vez dos ~292 anos reais, estourando o alcance do `DateTime`
  (~273.790 anos) e produzindo `RangeError` em `DateTime.add`. O porte
  converte a unidade de verdade (`(2^63-1) ~/ 1000`), preservando a magnitude,
  e o cap de overflow de `durationFromTokens` (`rate.go:412-415`) usa esse
  mesmo limiar. O valor só é usado como sentinela de "espera infinita", nunca
  decomposto de volta em tokens.

  Omissões deliberadas: `sync.Mutex` de `Limiter` (`rate.go:58`) e de
  `Sometimes` (`sometimes.go:27`), pelo mesmo motivo já registrado no
  `BasicConnMgr` — nenhuma região guardada tem `await`. O `context.Context` de
  `WaitN` virou `deadline` e `cancellation` explícitos; a checagem síncrona
  inicial do Go passa a ocorrer depois de um turno de microtask, porque um
  `Future` não é inspecionável de forma síncrona.

- **`boilerplate/net/` — `Ip` e `IpNet`**, separados de `net_netip/` porque a
  semântica diverge onde importa. `net.IP` dobra o endereço IPv4 mapeado na
  forma IPv4 antes de imprimir e de comparar, então `10.0.0.0/8` **contém**
  `::ffff:10.1.2.3`; `netip.Prefix.Contains` recusa o mesmo par, porque os
  comprimentos de bit diferem. `conngater.go` depende do primeiro
  comportamento, `conn_limiter.go` do segundo — um único tipo deixaria um dos
  dois sutilmente errado.

  Adaptação registrada: `net.ParseCIDR` devolve `(IP, *IPNet, error)`;
  `IpNet.tryParseCidr` devolve só a rede, porque a Regra 8 veta tuplas de erro
  em API pública. O endereço que o Go devolve primeiro é `Ip.tryParse` do
  trecho antes da barra.

  Vetores executados em Go 1.25.7, não deduzidos: `net.ParseIP("127.0.0.1")`
  com **16** bytes, `ParseIP("::ffff:127.0.0.1").String() == "127.0.0.1"`,
  `ParseCIDR("10.0.0.0/8")` com endereço e máscara de **4** bytes,
  `n4.Contains(::ffff:10.1.2.3) == true` e `net.IP(nil).String() == "<nil>"`.

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
| `transpiled_libp2p` (connmgr) | `BasicConnMgr`, decayer e options portados sobre os 256 shards do upstream, com as travas omitidas e o coalescedor de trim preservado (ver rastreamento). Ainda **não ligado** ao `BasicHost` nem ao `IpfsNode`: sem isso o teto de conexões não vale. |
| `transpiled_clock` | Porte de `benbjohnson/clock` v1.3.5, pré-requisito do `BasicConnMgr`, que injeta `clock.Clock` em todo `Now()` e `Ticker()`. `Clock`, `Mock`, `Timer` e `Ticker` portados; `WithDeadline`/`WithTimeout` e o alias `Duration` omitidos (ver rastreamento). `Mock.add`/`Mock.set` são assíncronos porque o `gosched()` do upstream virou cessão à fila de microtasks. |
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

- **Servidor DHT auto-hospedado: comprovado, e ainda sem teto de conexões.**
  Um terceiro recupera o bloco pelo CID, com o nó Dart na ponta:

  ```
  ipfs-check: ConnectionError "", ConnectionMaddrs ["/ip4/203.0.113.47/tcp/4002"],
              ProviderRecordFromPeerInDHT true,
              DataAvailableOverBitswap {Found: true, Responded: true, 879 ms}
  trustless-gateway.link/ipfs/<cid>?format=raw -> HTTP 200 com o payload
  ```

  O segundo é recuperação **cega**: só o CID, sem multiaddr. É a primeira vez
  que a cadeia inteira fecha ponta a ponta.

  Quatro defeitos tiveram de cair para isso, e a ordem em que apareceram é
  instrutiva, porque cada conserto revelou o seguinte:

  1. **Accept serial** (`upgrader/listener.go`) — negociação em série sem
     timeout travava o nó em minutos. Ver o commit `1e5c08cc`.
  2. **`_sendFrame` do yamux** — erro de escrita escapava para a zona raiz;
     Go faz log e `exitErr` (`go-yamux/session.go:545-567`).
  3. **`IOSink` do `dart:io`** — `Socket.add` é fire-and-forget e o
     `SocketException` do par que reseta nasce dentro da subscription interna
     do sink, chegando ao root zone por `_RootZone.runUnaryGuarded`. Não passa
     por `Socket.done`, então observar `done` não resolve. `_TcpRawConn` foi
     reescrito sobre `RawSocket`, cujo `write` devolve `(n, err)` ao chamador
     como o `net.Conn.Write` do Go, com laço de escrita parcial e
     backpressure explícitos.
  4. **Keepalive ausente** — `enableKeepAlive` e `keepAliveInterval` eram
     campos só validados, sem `Timer` nenhum no pacote: uma sessão cujo par
     sumiu em silêncio nunca era ceifada. Portados `startKeepalive`
     (`session.go:446-473`), `Ping`, e o deadline de escrita
     `connectionWriteTimeout` que o `sendLoop` aplica na conexão
     (`session.go:583-590`).

  O item 4 introduziu um quinto defeito antes de funcionar, e vale registrar:
  com o deadline de escrita o yamux passou a **abandonar** o `await`, deixando
  o `_TcpRawConn` estacionado num completer de escrita sem ouvinte. Completá-lo
  com erro na morte do socket virou erro assíncrono não tratado — a mesma
  classe de falha que o item 3 acabara de eliminar. O completer passou a ser
  concluído normalmente, e o laço de escrita reconfere `isClosed` ao acordar,
  lançando de dentro da cadeia do chamador, onde há tratador.

  **O que falta:** não há teto de conexões. Medido com tudo acima em pé, o
  número de sockets de entrada sobe de forma monótona — 240 no primeiro minuto,
  658 no nono — e o keepalive apenas reduz a inclinação. Quem estabiliza isso
  no Kubo é o `BasicConnMgr`, podando de 96 para 32 com 20 s de carência
  (`config/init.go:80-92`). O `ResourceManager` não substitui: o piso do
  próprio Kubo para conexões de entrada é 800 (`config/init.go:100`).

  O `p2p/net/connmgr/` está portado, com os dois pré-requisitos que o tornaram
  possível — o relógio injetável (`packages/transpiled_clock`) e o `SwarmConn`
  —, e **a fiação está feita**. Os três pontos de enganche que faltavam:

  1. `packages/transpiled_libp2p/lib/src/p2p/host/basic/basic_host.dart` — o
     construtor registra `_network.notify(connManager.notifiee())` quando um
     manager é fornecido, como `basic_host.go:275-281`, que só assina o notifee
     do manager recebido e nunca o do `NullConnMgr` de fallback. `close()`
     chama `_connManager.close()` **antes** de derrubar o swarm, na ordem de
     `basic_host.go:639-641`, para que o trim de fundo pare antes de as
     conexões sumirem debaixo dele.
  2. `lib/src/node/ipfs_node.dart` — constrói `BasicConnMgr(32, 96)` com
     `withGracePeriod(20s)` e `withSilencePeriod(10s)`, os defaults do Kubo
     (`kubo/config/init.go:79-93`), e o passa ao `BasicHost`. O grace do Kubo é
     **menor** que o default de 1 min do go-libp2p, e por isso é explícito.
  3. `packages/transpiled_boxo/.../bsnet/ipfs_impl.dart` — `tagPeer`,
     `untagPeer`, `protect` e `unprotect` delegam a `_host.connManager`, como
     `ipfs_impl.go:529-555`. A checagem `nil` que o Go faz sobre `bsnet.host`
     não tem contraparte: o campo Dart é não-anulável. Para isso, `P2pHost`
     ganhou `ConnManager get connManager`, contraparte de
     `host.Host.ConnManager()` (`core/host/host.go:60`); o `BroadcastControl`
     em `peerwantmanager.dart` deixou de tipar `host` como `dynamic` e a
     checagem de peering comentada voltou a existir, com
     `peering.ConnmgrTag` (`boxo/peering/peering.go:26`) declarado localmente
     porque `boxo/peering` não tem porte.

  **Duas coisas continuam valendo, e a distinção importa.** A primeira é que o
  caminho vivo do nó não passa por `bsnet`: `lib/src/protocols/bitswap/` tem
  cliente próprio sobre `Libp2pRouter`, e nada em `lib/` chama `tagPeer` ou
  `protect`. O manager portanto poda por carência e recência, sem os pesos que
  no Go vêm do `sessionpeermanager`
  (`bitswap/client/internal/sessionpeermanager/sessionpeermanager.go:65`) e sem
  a proteção de peering que o Kubo aplica aos peers configurados. Peers de
  bootstrap e da tabela de roteamento não têm, hoje, nenhuma proteção contra o
  trim.

  A segunda é o **critério de aceite**, que nada disto satisfaz: subir o nó
  contra a rede e medir que a contagem de sockets de entrada estabiliza perto
  da faixa 32–96, em vez de seguir a curva 240→658 registrada acima. Teste
  atômico verde não comprova este item — ele é sobre comportamento em rede
  real, pela mesma distinção entre "portado" e "funciona contra par real" que o
  `AGENTS.md` cobra. A fiação sai de "não existe" para "existe e não foi
  medida".

  A sobrevida medida hoje é de dezenas de minutos, não de dias, e não existe
  teste de soak no repositório que meça isso continuamente.

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
