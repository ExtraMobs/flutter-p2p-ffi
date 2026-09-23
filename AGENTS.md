# Escopo do projeto

O objetivo deste projeto é portar para Dart apenas as bibliotecas reutilizáveis
necessárias para executar um nó IPFS embutido em aplicações Dart ou Flutter.

O foco central de implementação no nível IPFS é **estritamente o Boxo**
(`github.com/ipfs/boxo`), seguindo a orientação arquitetural de como o **Kubo**
o consome e orquestra. O Kubo serve como guia de referência de uso e integração
das APIs do Boxo, não como superfície de produto a ser portada.

**Não vamos implementar gateway local (servidor HTTP) nem CLI.**

## Objetivos do projeto

### Objetivo 1 — Primeiro download P2P por CID (Concluído)

Comprovado o download P2P de um bloco por CID interoperando com Kubo:
- **Marco A (Provider Conhecido)**: `Kubo conhecido → TCP/Noise → /ipfs/bitswap/1.2.0 → WANT_BLOCK → bloco validado pelo CID → blockstore` (100% comprovado via `local_kubo_bitswap_test.dart`).
- **Marco B (Provider Descoberto via DHT)**: `CID → DHT.findProviders → AddrInfo → conectar provider → Bitswap → validar → blockstore` (100% comprovado via `local_kubo_dht_bitswap_test.dart`).

### Objetivo 2 — Hospedagem e servimento P2P de blocos por CID (Concluído)

Comprovada a hospedagem e o servimento P2P de dados (seeding) por CID para outro nó (Kubo):

- **Marco C.1 (Provider Conhecido)**:
  `Dart local (bloco no blockstore) → TCP/Noise → /ipfs/bitswap/1.2.0 → responder WANT_BLOCK/WANT_HAVE → Kubo recebe e valida bloco` (100% comprovado via `local_kubo_serving_test.dart`).
- **Marco C.2 (Anúncio e Descoberta via DHT)**:
  `Dart anuncia CID na DHT via provide → Kubo findprovs → Kubo descobre nó Dart → conecta → Bitswap → valida bloco` (100% comprovado via `local_kubo_dht_serving_test.dart`).

### Objetivo 3 — Transpilação dos subsistemas de host e rede da libp2p e NAT Traversal (Concluído)

Implementação nativa em `packages/transpiled_libp2p/` dos subsistemas de host,
rede e NAT Traversal necessários ao nó embutido, com paridade Go, eliminando
shims e dependências externas via git:

> [!IMPORTANT]
> Este objetivo **não** portou a `go-libp2p` integralmente, e o pacote não deve
> ser tratado como fechado. A cobertura atual está em `PROGRESS_RELATORY.md`,
> que é regenerado pelo auditor; não repita o número aqui, porque ele muda a
> cada símbolo portado.
>
> O que existe hoje, depois dos Objetivos 5 e 6: transportes TCP, WebSocket,
> QUIC, WebTransport e WebRTC Direct; segurança Noise; muxer yamux; e a camada
> `discovery` com mDNS, `RoutingDiscovery` e `BackoffDiscovery`. O TLS 1.3 está
> parcialmente portado mas **deliberadamente não anunciado** (ver Marco G.2); o
> mplex foi descartado; rendezvous não foi portado.
>
> A porcentagem mede **superfície de API, não função**, e essa distinção já
> custou caro: durante um período os Objetivos 1 a 4 constavam como "100%
> comprovados" enquanto o nó estava, de fato, incomunicável com qualquer Kubo
> real, porque um TLS incompleto era anunciado à frente do Noise. Nenhum teste
> da suíte obrigatória pegou isso, porque ela exercita Dart contra Dart. Trate
> "portado" e "funciona contra peer real" como afirmações distintas, e só faça a
> segunda com um daemon Kubo de verdade na frente.

- **Marco D.1 (Transpilação dos subsistemas de host e rede de `go-libp2p`)**:
  Portar os subsistemas de host, rede e identificação (`BasicHost`, `RoutedHost`, `Network`, `Swarm`, `Identify`, `IdentifyPush`, `connmgr`), substituindo a dependência externa `ipfs_libp2p` e mantendo conformidade com as regras do auditor AST e 100% de cobertura de testes atômicos (100% concluído para esse escopo).
- **Marco D.2 (NAT Traversal — AutoNAT e Circuit Relay v2)**:
  Implementar detecção autônoma de reachability (`AutoNAT` v1/v2), cliente `Circuit Relay v2` (`/libp2p/circuit/relay/0.2.0/stop` com handshake `RESERVE`) e gerenciamento autônomo de reservas (`AutoRelay`), publicando endereços `/p2p-circuit` no Swarm e na DHT (100% concluído).
- **Marco D.3 (Otimizações de Acesso — Hole Punching DCUtR e UPnP)**:
  Implementar `/libp2p/dcutr` para sincronização de abertura de portas NAT (direct connection upgrade) e `NATManager` (UPnP / NAT-PMP) para abertura automática de portas em roteadores locais (100% concluído).
- **Marco D.4 (Validação Global WAN Ponta a Ponta)**:
  Comprovar alcance e consumo P2P a partir de nós externos na internet pública (100% comprovado via `check.ipfs.network` oficial discando diretamente para `/ip4/203.0.113.47/tcp/4002` do nó Dart na WAN e recuperando blocos via Bitswap).

### Objetivo 4 — Descoberta Global Autônoma na DHT (Concluído)

Concluída a transição do estado "parcialmente público" (onde o nó já era diretamente discável e servia blocos via WAN, mas ainda dependia de encaminhamento de anúncio para a descoberta cega) para "totalmente público e autônomo", com o ciclo completo de Kademlia Content Routing na Amino DHT implementado e comprovado em rede real. A muleta de encaminhamento de anúncio (`Process.run('ipfs', ['routing', 'provide', ...])` em `bin/host_payload.dart`) foi removida:

- **Marco E.1 (Busca Iterativa Kademlia e Roteamento XOR)**:
  Caminhamento iterativo Kademlia em `DhtClient.getClosestPeers(Uint8List key)`, sobre a mensagem `FIND_NODE` codificada por `encodeFindNode`, com cálculo de distância métrica XOR nos K-buckets, concorrência $\alpha=3$, término $\beta=3$, fase de follow-up e convergência para os 20 nós mais próximos da chave na rede pública Amino DHT (100% concluído).
- **Marco E.2 (Anúncio Autônomo Global na DHT — `provide` iterativo)**:
  `DhtClient.provide(Cid cid, AddrInfo provider)` reescrito sobre `getClosestPeers(cid.multihash)`: descobre autonomamente os 20 nós mais próximos do hash na Amino DHT e envia a mensagem protobuf `ADD_PROVIDER` com os endereços WAN reais (`/ip4/.../tcp/4002`) para esses 20 nós, sem varrer as conexões abertas no swarm e sem intermediação de daemon externo; os `bootstrapPeers` permanecem apenas como fallback (100% concluído).
- **Marco E.3 (Descoberta Cega Pública Comprovada em Gateways HTTPS)**:
  `bloco inédito de Random.secure() → putRawBlock apenas no blockstore Dart → node.provide(cid) → getClosestPeers → ADD_PROVIDER aos 20 mais próximos → gateway HTTPS público recupera os bytes só pelo CID` (100% comprovado via `dht_public_discovery_network_test.dart`, marcado `@Tags(['network'])` e executado com `dart test --preset network`). CID `QmNM7y6W1DqmTtkJGxLUDQ7bFehpsC59rjc8xesekKHrv6` servido por `https://ipfs.io/ipfs/QmNM7y6W1DqmTtkJGxLUDQ7bFehpsC59rjc8xesekKHrv6?format=raw` em 72s, a partir do nó `12D3KooWDsMmX7axDC6HTTXUNe4upxEvFbNQjmE2FToVVbBzUK6f` anunciado em `/ip4/203.0.113.47/tcp/4002`, sem multiaddr prévio nem `swarm connect` manual. Confirmação independente: já com o nó Dart offline, o daemon Kubo local respondeu `ipfs routing findprovs <cid>` com exatamente esse PeerId, provando que os `ADD_PROVIDER` ficaram armazenados na própria Amino DHT pública (100% comprovado).

### Objetivo 5 — Interoperabilidade Plena de Rede (Concluído e Comprovado - Marcos F.1 a F.7)

Os Objetivos 1 a 4 provaram que o nó **consome** e **publica** na rede: baixa,
serve e anuncia blocos por CID, de forma autônoma e comprovada na internet
pública. Este objetivo fecha o ciclo restante: tornar o nó um **participante
completo** da rede, e não apenas um cliente dela.

O diagnóstico que motiva o objetivo, verificado no código: o nó registrava **um
único** handler de stream, o do Bitswap. Ele consultava a DHT mas não a servia,
não mantinha tabela de roteamento viva, não descobria o próprio endereço público
nem peers locais, e perdia todo o estado de rede a cada reinício.

- **Marco F.1 (Tabela de Roteamento Kademlia em Runtime)**:
  Implementar `DhtRoutingTable` — consumindo o pacote
  `packages/transpiled_libp2p_kbucket` (`table.dart`, `bucket.dart`,
  `table_refresh.dart`). K-buckets vivos, população a partir das conexões e
  do `Identify`, e refresh periódico de buckets. (100% concluído).
- **Marco F.2 (Servidor DHT — handler de `/ipfs/kad/1.0.0`)**:
  Registrar handlers de stream para `/ipfs/kad/1.0.0` e `/ipfs/lan/kad/1.0.0`,
  respondendo `FIND_NODE`, `GET_PROVIDERS`, `ADD_PROVIDER` e `PING` a partir da
  tabela do F.1, e armazenando `ADD_PROVIDER` de terceiros num provider store com TTL.
  (100% concluído).
- **Marco F.3 (Descoberta do Próprio Endereço — `ObservedAddrManager`)**:
  Portar o coletor de endereços observados do `Identify`, coletando o que os peers
  reportam de volta e alimentando `BasicHost.addrs`. (100% concluído).
- **Marco F.4 (Descoberta Local — mDNS)**:
  Portar `p2p/discovery/mdns` para descoberta de nós na LAN. (100% concluído).
- **Marco F.5 (Persistência e Republicação)**:
  Reprovide automático dentro da biblioteca e peerstore persistente em datastore
  (`pstoreds`), com fechamento sem bloqueio no shutdown. (100% concluído).
- **Marco F.6 (Camada `discovery` — implementações)**:
  Implementar `RoutingDiscovery` e `BackoffDiscovery` sobre as interfaces de
  `packages/transpiled_libp2p/lib/src/core/discovery/`. (100% concluído).
- **Marco F.7 (Validação de Interoperabilidade Plena)**:
  Comprovar que um Kubo real reconhece o nó Dart como par completo de rede:
  aparece na tabela de roteamento do Kubo, responde consultas DHT vindas de
  terceiros com servimento de blocos via Bitswap, e é descoberto por mDNS na LAN
  (100% comprovado via `local_kubo_network_participation_test.dart` contra daemon
  Kubo real, além da prova WAN prévia em Amino DHT).

> [!NOTE]
> Ampliar a matriz de transporte e segurança — QUIC, WebSocket, WebTransport,
> WebRTC, TLS e mplex — **não** faz parte deste objetivo: é o **Objetivo 6**,
> logo abaixo. Os dois eixos são disjuntos — o Objetivo 5 mexe em DHT, identify,
> discovery e persistência, sem encostar no caminho de dial/listen/upgrade, que é
> onde transporte mora — e podem ser tocados em qualquer ordem.

### Objetivo 6 — Ampliação da Matriz de Transporte e Segurança (G.1, G.2 e G.3 concluídos; G.4 comprovado contra Kubo nas duas direções mas sem o critério de navegador; G.5 e G.7 pendentes; G.6 descartado)

Enquanto o Objetivo 5 trata de **como** o nó participa da rede, este trata de
**quantos peers ele consegue alcançar**.

O diagnóstico original: o nó falava uma única combinação, `TCP + Noise + yamux`,
e dos **8 endereços de swarm** que um Kubo publica discava apenas os dois
`/tcp/`. Os transportes `quic-v1`, `quic-v1/webtransport` e `webrtc-direct`, em
IPv4 e IPv6, eram invisíveis, e nós de navegador (Helia sobre WebTransport ou
WebRTC) eram inalcançáveis por completo.

Os transportes desse diagnóstico foram portados e estão registrados no Swarm do
nó. O alcance efetivo, porém, é uma afirmação separada, e só vale contra um
peer real: hoje `local_kubo_transport_matrix_test.dart` recupera bloco por
`/tcp`, `/quic-v1` e `/quic-v1/webtransport`, e falha em `/webrtc-direct`. É
isso que o Marco G.7 mede — ver o aviso sobre `canDial()` lá embaixo antes de
dar o marco por fechado.

> [!IMPORTANT]
> **O bloqueio arquitetural do QUIC deixou de existir e isso muda a viabilidade
> deste objetivo.** A tentativa anterior de portar QUIC foi arquivada porque o
> `Swarm`/`BasicUpgrader` da dependência de terceiros `ipfs_libp2p` rodava
> negociação de segurança (Noise) e de muxer incondicionalmente sobre qualquer
> transporte, sem exceção para transportes autossegurados e automultiplexados —
> e aquela dependência não era editável neste repositório. O Marco D.1 eliminou
> essa dependência: o `BasicUpgrader` agora é código nosso, em
> `packages/transpiled_libp2p/lib/src/p2p/transport/basic_upgrader.dart`.
> Permitir que um transporte declare que dispensa upgrade de segurança e de
> muxer é pré-requisito do Marco G.1 e não depende mais de terceiros.
>
> A análise original citada pelo `PROGRESS.md` estava em
> `doc/specs/QUIC_TRANSPORT_RFC.md`, que **não existe mais** — o diretório
> `doc/specs/` foi removido. Trate a análise como perdida e refaça-a.

> [!IMPORTANT]
> **Mapa de dependência deste objetivo — leia antes de escolher um marco.**
> A ordem em que os marcos foram numerados não é a ordem em que podem ser
> feitos, e tratá-los como independentes já produziu marcos declarados
> concluídos sem alcance nenhum.
>
> ```
> TLS 1.3 transpilado (G.2)
> ├── G.1  QUIC ................... CONCLUÍDO (discagem e entrada)
> │   └── G.4  WebTransport ....... Kubo nas duas direções; falta navegador
> ├── G.7  Validação da matriz .... depende de G.5
> └── (o próprio /tls/1.0.0)
>
> DTLS (não portado)
> └── G.5  WebRTC Direct .......... depende DIRETO
>
> G.3  WebSocket /wss ............. CONCLUÍDO (peer público real)
> ```
>
> **G.1 depende de G.2 porque o handshake do QUIC *é* um handshake TLS 1.3**
> carregado em CRYPTO frames, e as chaves derivadas dele são as que protegem os
> pacotes. Não existe "QUIC sem TLS". G.4 é HTTP/3 sobre QUIC, então herda a
> dependência; G.7 não pode comprovar a matriz enquanto dois dos transportes
> dela não falarem o protocolo real.
>
> **G.5 não depende de TLS, e sim de DTLS** — o `certhash` do multiaddr é o
> fingerprint do certificado DTLS. A pilha Pion portada tem `sctp`, `stun`,
> `sdp`, `transport`, `logging` e `randutil`, mas **não tem `dtls`**, então o
> G.5 tem uma lacuna própria do mesmo tamanho. O vocabulário de mensagens de
> handshake do `transpiled_crypto_tls` ajuda em parte, mas records,
> retransmissão e cookie exchange do DTLS são próprios.
>
> **G.3 é independente**: o transporte WebSocket faz `/wss` com
> `SecurityContext` do `dart:io`, isto é, o TLS da plataforma, e não o
> transpilado.
>
> Nada nos Objetivos 1 a 5 depende disto. DHT, discovery, persistência, Bitswap
> e o servidor DHT são agnósticos de transporte — é por isso que o nó hospeda e
> serve por CID hoje, com Noise sozinho.
>
> Ordem executável do que resta: **DTLS e o G.5**, que é a única frente grande
> ainda aberta, e **G.7** por último. O critério de navegador do G.4 (um nó
> Helia discando o nó Dart) pode ser exercitado a qualquer momento, e não
> depende do G.5.

- **Marco G.1 (QUIC — `/udp/<porta>/quic-v1`)**:
  Formato de fio QUIC real (RFC 9000 e RFC 9001) implementado com Long Header
  (Initial e Handshake), números de pacote codificados por varint, proteção
  AEAD de payload via AES-128-GCM e proteção de cabeçalho via AES-ECB. Handshake
  TLS 1.3 completo integrado via CRYPTO frames negociando ALPN `libp2p`,
  parâmetros de transporte QUIC e certificado libp2p. Suporte a frames STREAM,
  ACK, RESET_STREAM, STOP_SENDING e NEW_CONNECTION_ID. A **discagem** está 100%
  comprovada contra daemon Kubo 0.43.0 real, com abertura de stream por
  multistream-select, Bitswap 1.2.0 e recuperação/validação de blocos por CID
  (`local_kubo_quic_test.dart`).

  A direção de **entrada** também está 100% comprovada: um Kubo 0.43.0 real
  disca o nó Dart em `/quic-v1`, completa o handshake, abre stream e baixa um
  bloco por Bitswap validando o CID (`local_kubo_quic_inbound_test.dart`), sem
  que o nó Dart disque o Kubo em momento algum. **Marco concluído.** As duas
  causas do bloqueio anterior — transcript TLS hasheando um fragmento do
  ClientHello, e ausência do transport parameter
  `original_destination_connection_id` — estão registradas em
  `doc/transpilation/PROGRESS.md`, junto com o que ainda falta no emissor
  (recuperação de perda: PTO e retransmissão de flight).
- **Marco G.2 (Segurança TLS 1.3 — `/tls/1.0.0`)**:
  **Fundação de metade deste objetivo**: habilita o `/tls/1.0.0` negociado por
  multistream-select à frente do Noise, com máquinas de estado do handshake TLS 1.3
  portadas e interoperabilidade 100% comprovada em ambas as direções contra daemon
  Kubo real (discar e aceitar conexões via `local_kubo_tls_handshake_test.dart`).
  Reativado na lista de segurança padrão do nó com conformidade total ao
  `DefaultSecurity` do go-libp2p. (100% concluído e comprovado).
- **Marco G.3 (WebSocket — `/ws` e `/wss`)**:
  O transporte mais barato de acrescentar sobre a base TCP já existente, e o que
  destrava peers de infraestrutura e ambientes com egresso restrito a HTTP(S).
  Critério: conexão com um peer público que anuncie `/wss`.

  **Marco concluído.** `public_wss_dial_test.dart` (preset `network`) resolve
  em runtime os registros TXT `_dnsaddr.bootstrap.libp2p.io`, filtra os
  endereços com `/wss` e disca de verdade um bootstrapper público da libp2p,
  exigindo que o swarm registre uma conexão viva cujo transporte seja
  `websocket` e cujo multiaddr remoto ainda carregue o `/wss`. Nenhum
  `canDial()`, nenhum loopback entre dois nós Dart.
- **Marco G.4 (WebTransport — `/quic-v1/webtransport`)** — metade concluída:
  Depende do G.1, por rodar sobre HTTP/3 sobre QUIC, e usa o componente
  `certhash` do multiaddr para fixação de certificado no navegador. Critério:
  um nó Helia rodando em navegador conecta no nó Dart e baixa um bloco.

  A **discagem** está comprovada contra Kubo real: QUIC com ALPN `h3`,
  certificado fixado por `certhash`, Extended CONNECT em
  `/.well-known/libp2p-webtransport?type=noise` e Noise com early data
  `webtransport_certhashes`, com bloco recuperado por Bitswap e CID validado
  (`test/interop/test/local_kubo_webtransport_quic_test.dart`). A **entrada**
  também está comprovada contra Kubo real
  (`local_kubo_webtransport_inbound_test.dart`), depois de portar o
  certificado determinístico de 14 dias (`crypto.go:48-96`), o cert manager
  (`cert_manager.go`) e as quatro checagens de `verifyRawCerts` — o listener
  apresentava o certificado de identidade libp2p, válido por um século, que um
  par Go recusa de saída.

  O marco, ainda assim, **continua aberto**: seu critério é um nó Helia em
  navegador, e nenhum navegador foi exercitado. Detalhes em
  `doc/transpilation/PROGRESS.md`.
- **Marco G.5 (WebRTC Direct — `/udp/<porta>/webrtc-direct`)**:
  Alcance de navegador sem servidor de sinalização, também via `certhash` — que
  aqui é o fingerprint do **certificado DTLS**. Independe do G.2, mas **depende
  de DTLS**, que não está portado: a pilha Pion transpilada tem `sctp`, `stun`,
  `sdp`, `transport`, `logging` e `randutil`, e nenhum `dtls`. Portar DTLS é
  trabalho da mesma ordem de grandeza do G.2; o vocabulário de mensagens de
  handshake do `transpiled_crypto_tls` é reaproveitável em parte, mas os
  records, a retransmissão e o cookie exchange do DTLS são próprios.
  Critério: mesmo do G.4, por WebRTC. Framing próprio entre dois nós Dart não
  comprova o marco.
- **Marco G.6 (Muxer mplex — `/mplex/6.7.0`)**:
  Prioridade baixa e possivelmente descartável: o mplex está depreciado na
  libp2p em favor do yamux, e o Kubo o removeu dos padrões. Só entra se algum
  peer real que interesse ainda exigir.
- **Marco G.7 (Validação da Matriz Completa)**:
  Comprovar que o nó Dart **disca de fato** os endereços que um Kubo real
  publica — estabelecendo conexão, abrindo stream e recuperando um bloco por
  Bitswap em cada transporte — e que um nó em navegador o alcança.

  > [!WARNING]
  > **`canDial()` não comprova este marco.** É um predicado que inspeciona a
  > string do multiaddr e responde se aquele transporte se candidata a discá-lo:
  > não abre socket, não faz handshake e não troca byte algum. Uma matriz de
  > `expect(transport.canDial(...), isTrue)` cobrindo os 8 formatos de endereço
  > passa com o transporte inteiramente quebrado — e foi exatamente o que
  > aconteceu. O `QuicTransport` respondia `canDial` para `/ip6/.../quic-v1` e,
  > ao discar de verdade, derrubava o processo inteiro com `SocketException`,
  > porque vinculava o socket sempre em IPv4. Trocas em loopback entre dois nós
  > Dart também não comprovam nada aqui: os dois lados compartilham os mesmos
  > defeitos e se entendem justamente por isso.
  >
  > Critério de aceite, e nada menos: um daemon Kubo real em execução; iterar
  > sobre a lista efetiva de `Addresses.Swarm` dele; e, para **cada** endereço,
  > conectar, abrir stream e recuperar um bloco por Bitswap validando o CID. O
  > teste pertence ao preset `interop`, e precisa **falhar** quando o transporte
  > falhar — um teste que passa com o daemon desligado não está validando nada.

Todo agente que atuar no projeto deve seguir a ordem e os critérios das checklists dos Objetivos no topo de `doc/transpilation/PROGRESS.md`. Trabalho que não destrava nem valida essas checklists fica atrás delas, salvo correção necessária para manter a suíte verde ou instrução explícita do usuário. Gateway HTTP local e interfaces CLI estão expressamente fora do escopo do projeto.

## Diante de um problema ou impasse, consulte o repositório de referência

**Sempre que houver um problema, um impasse lógico, comportamental ou de
arquitetura, um defeito a diagnosticar ou uma decisão de desenho a tomar — em
ABSOLUTAMENTE QUALQUER subsistema do projeto (rede, blockstore, datastore,
bitswap, DHT, unixfs, IPLD, repo, serialização, buffers, concorrência, etc.), e
NÃO APENAS em questões de rede —, a resposta se deriva lendo o Go em
`go-ipfs-reference/` — nunca especulando, improvisando ou inspecionando apenas
o que já existe em Dart.** Esta regra vale para análise, diagnóstico, algoritmos,
fluxos de controle e planejamento, e não apenas para o momento de escrever
código portado, que a seção "Rastrear chamadas antes de implementar" já cobre.

A razão é estrutural, não estilística. Este porte é incompleto por definição.
Um inventário do que ele tem **não pode** revelar o que falta nele: subsistemas
e comportamentos inteiros que o upstream considera obrigatórios ficam invisíveis
simplesmente porque nada no Dart os referencia. Perguntar "o que está faltando
aqui ou como resolver essa lógica?" olhando apenas para cá devolve, na melhor
das hipóteses, a lista do que já foi escrito e quebrou — nunca a do que nunca
existiu ou de como o algoritmo upstream realmente opera.

Na prática isso significa abrir o Go primeiro e deixar que a lógica de negócio,
o grafo de chamadas e a fiação de opções do upstream determinem o formato da
resposta para qualquer impasse. Para saber que subsistemas um nó real executa,
leia como o Kubo constrói o seu host (`kubo/core/node/groups.go`,
`kubo/core/node/libp2p/`), em vez de ler o nó Dart e perguntar o que parece
ausente. Para saber como um algoritmo, cache ou estrutura de dados opera, leia
o pacote correspondente em `go-ipfs-reference/`.

Dois episódios reais deste repositório mostram o custo de inverter a ordem:

- A pergunta "o que falta para aguentar ser um servidor DHT?" foi respondida
  primeiro a partir do Dart, e produziu uma lista que começava no
  `ResourceManager` e no `ConnManager`. Lida a partir do Go, a primeira defesa
  do desenho é outra e vinha antes de qualquer limite: o `ModeAuto`
  (`go-libp2p-kad-dht/dht_options.go:28`), pelo qual um nó **só assume o papel
  de servidor quando o AutoNAT confirma alcançabilidade pública**. Na rede
  pública a maioria dos nós nunca vira servidor, e é por isso que o Go pode ter
  limites generosos. Essa camada era invisível do lado Dart, porque aqui não
  havia nada que se parecesse com ela.
- A mesma leitura expôs que `p2p/host/autonat/autonat.dart` tem **69 linhas**
  contra **1849** do `p2p/host/autonat` upstream, que nada sonda par algum e
  que `setReachability` não tem chamador — o que contradiz a alegação do
  Marco D.2. Nenhuma inspeção do Dart levantaria isso, porque o arquivo existe,
  compila, tem teste e parece pronto.

Comparar tamanho de módulo contra o upstream (`wc -l` do pacote Go de produção
contra o arquivo Dart correspondente) é um teste barato e desproporcionalmente
informativo quando se suspeita de um subsistema.

Citar o Go para justificar uma conclusão a que se chegou pelo lado Dart **não
é** o mesmo que derivar a conclusão do Go. A ordem importa e é esta: ler o
upstream, entender o desenho, e só então mapear para o que existe aqui.

## Estratégia de execução: delegar a multi-agentes de nível mínimo

Sempre que possível, o trabalho de transpilação e de revisão deve ser
**delegado a subagentes**, e cada subagente deve rodar no **menor nível de
modelo capaz de executar a tarefa**. O objetivo é duplo: paralelizar para
agilizar, e economizar tokens do contexto principal, que deve ser reservado
para julgamento e verificação.

1. **Paralelize por arquivo, nunca por tarefa sobreposta.** Dois agentes jamais
   podem receber o mesmo arquivo — suas edições se sobrescrevem. Divida o
   trabalho em escopos de arquivo disjuntos e dispare os agentes na mesma
   mensagem para que rodem simultaneamente.
2. **Escolha o menor modelo que resolve.** Use `haiku` para trabalho mecânico ou
   de localização (buscar símbolos na árvore, conferir se um doc bate com fatos
   já apurados, rodar uma sequência de verificação definida, aplicar renomeações
   determinísticas). Reserve `sonnet` para o que exige raciocínio real
   (decidir o desenho de um port, diagnosticar causa raiz, avaliar fidelidade
   semântica ao Go). Não use o modelo maior por padrão.
3. **O prompt carrega toda a verdade.** Um subagente novo não herda contexto
   nenhum. Passe números exatos, caminhos de arquivo e linhas, o que já foi
   descartado e por quê. Prompt curto e vago produz trabalho genérico e, pior,
   detalhes inventados que parecem plausíveis.
4. **O que não se delega é o julgamento.** Decidir o que deve mudar e conferir o
   que voltou continuam no contexto principal. O relatório de um subagente
   descreve o que ele pretendeu fazer; o diff é o que ele fez de fato, e é o
   diff que vale — confira antes de dar a tarefa por concluída.

## Fora do escopo

Estão expressamente fora do escopo do projeto:

1. **CLI (Linha de Comando)**:
   Ignore qualquer pacote, arquivo ou teste cuja única finalidade seja CLI,
   incluindo:
   - `kubo/cmd/**`;
   - `kubo/commands/**`;
   - `kubo/core/commands/**`;
   - `kubo/test/cli/**`;
   - parsing de comandos e flags;
   - prompts, help, completion e formatação de terminal;
   - exit codes, PID files e gerenciamento de processo exclusivo da CLI.

   Esses itens não devem ser portados, auditados nem contabilizados como lacunas.
   O `bin/ipfs.dart` existente não é alvo de paridade com a CLI do Kubo. Ele pode
   permanecer como ferramenta auxiliar de desenvolvimento e diagnóstico, mas não
   deve orientar a arquitetura ou o escopo da transpilação.

2. **Gateway HTTP Local e Servidor RPC**:
   - **Servidor de Gateway HTTP local** (ex.: `boxo/gateway`, endpoints `/ipfs/<cid>`
     ou `/ipns/<nome>` servidos via HTTP local, ou `corehttp`). O nó opera de forma
     puramente P2P sobre as camadas de transporte e Bitswap.
   - **Servidor RPC HTTP** (endpoints `/api/v0/`).

O foco de implementação permanece na transpilação do **Boxo** (e na base de rede
libp2p e multiformats necessária para suportá-lo), seguindo a orientação de como o
**Kubo** consome e orquestra o Boxo. O Kubo é apenas um guia de orquestração interna,
não um produto a ser reproduzido. Ciclo de vida `create`/`start`/`stop`, configuração,
rede, armazenamento e protocolos P2P reutilizáveis são componentes de biblioteca
que permanecem no escopo.

Antes de trabalhar na transpilação, leia
`doc/transpilation/PROGRESS.md`.

## Dependências do ecossistema IPFS

Dê prioridade aos ports Dart internos já auditados contra o módulo Go
correspondente. O módulo Go upstream fixado em
`doc/transpilation/UPSTREAM_LOCK.md` continua sendo a fonte autoritativa de
fidelidade. Ports internos ainda não auditados e ports Dart externos servem
apenas como pistas até serem confirmados contra esse upstream.

Cada módulo Go reutilizável portado deve permanecer em um pacote Dart próprio,
respeitando sua fronteira de `go.mod`. Esses pacotes ficam em
`packages/transpiled_<nome_do_modulo>/`; somente a integração do nó embutido
fica no pacote raiz, sob `lib/`.

## Ordem obrigatória: transpilar antes de adaptar

### Tipos primitivos Go compartilhados

Use `packages/boilerplate/`, módulo lógico `fixed_types.Golang.<tipo>`, para
centralizar a representação em bytes e a semântica dos tipos primitivos Go.
Em Dart, importe `package:boilerplate/fixed_types/golang.dart` com prefixo
`Golang`; namespaces de tipos aninhados não existem na linguagem Dart.
O caminho e o prefixo representam o schema solicitado, sem factories dinâmicas
que eliminem a checagem estática dos tipos.

Antes de duplicar máscaras, limites, overflow, shifts ou conversões numéricas
em um port, use o tipo correspondente já validado nesse módulo. Se faltar,
implemente e teste sua semântica ali primeiro, pela especificação Go e vetores
executados em Go. Não atribua fidelidade a tipos ainda não implementados.
O objetivo desse pacote de tipagem simulada como no Golang é reduzir
drasticamente as verificações de limites e comportamentos dentro dessa
transpilação, garantindo que o próprio tipo encapsule as regras da linguagem Go
(overflow módulo 2^N, truncamento, shifts, divisão/resto e extensão de sinal).
Overflow permitido e conversões truncantes Go não devem virar exceções de
faixa arbitrárias. Preserve também divisão, resto, sinal e zero value.
Conversões para tipos Dart devem ser explícitas e não perder precisão.

Essa camada de adaptação não corresponde a um go.mod upstream e é exceção
deliberada ao prefixo `transpiled_`. Ela não absorve codecs nem regras IPFS.
Validações de dados não confiáveis, limites de protocolo e segurança continuam
nos módulos responsáveis. Migre os consumidores com testes de paridade;
não remova verificações apenas porque existe um wrapper de tipo.
É expressamente proibido implementar subsistemas novos sem aviso e
aprovação prévia do mantenedor.

### Rastrear chamadas antes de implementar

Antes de portar, corrigir ou adaptar qualquer função, todo agente deve:

1. consultar o índice AST Go produzido pela ferramenta do projeto (localização
   e uso em `doc/transpilation/PROGRESS.md`) para localizar o símbolo upstream
   e identificar as funções e métodos chamados por ele;
2. resolver cada chamada relevante ao fluxo em análise até sua declaração,
   pacote e módulo proprietário (`go.mod`), conferindo a revisão em
   `UPSTREAM_LOCK.md`. Use imports e aliases; quando o índice sintático não
   resolver métodos, interfaces ou nomes ambíguos, use `gopls`/`go/types` e
   confirme no código. Não invente um destino para chamadas dinâmicas;
3. procurar o símbolo Go correspondente nos índices, notas de paridade e
   pacotes Dart existentes. Reutilize o port auditado; se ainda não estiver
   auditado, confira-o contra o upstream antes de reutilizar ou corrigir;
4. preservar a delegação: se a função Go chama outra função para realizar uma
   operação, a função Dart deve chamar o port correspondente, não copiar ou
   reimplementar a operação dentro do chamador. Uma dependência ausente deve
   ser portada no pacote da sua própria fronteira de `go.mod`, nunca embutida
   no pacote consumidor. Avise o mantenedor antes de implementar subsistema
   novo;
5. registrar em `PROGRESS.md` o rastreamento relevante
   `chamador Go → símbolo chamado → módulo/revisão → símbolo/pacote Dart`,
   indicando reutilização, lacunas e ambiguidades ainda não resolvidas.

O índice AST é ponto de partida, não prova isolada de resolução semântica ou
paridade. Se estiver indisponível ou desatualizado, registre essa condição e
use as declarações upstream e resolução semântica como alternativa verificável.
Qualquer fusão de funções ou eliminação de uma delegação exige justificativa
concreta de incompatibilidade Dart, conforme as regras de preservação da API.

Ao encontrar uma lacuna, limite ou defeito em código Dart correspondente a
Kubo, Boxo ou go-libp2p, siga obrigatoriamente esta ordem:

1. localize o símbolo e o fluxo autoritativos no módulo Go fixado em
   `doc/transpilation/UPSTREAM_LOCK.md`;
2. transpile para o pacote Dart da mesma fronteira de `go.mod`, preservando
   contrato, defaults, lifecycle, limites e erros observáveis;
3. comprove a paridade com vetores ou testes derivados do upstream;
4. somente depois adapte ao runtime ou ao sistema de tipos do Dart, no menor
   ponto necessário e com justificativa concreta documentada em
   `doc/transpilation/PROGRESS.md`.

Não trate placeholders, defaults arbitrários ou APIs originais de ports Dart
externos como equivalentes ao Go sem auditoria. Overrides que apenas elevem ou
desativem limites para fazer um teste passar são diagnósticos temporários, não
soluções finais; o comportamento upstream deve ser portado primeiro. Quando
uma adaptação temporária for indispensável para investigar, marque-a
explicitamente, mantenha-a fora do resultado final e registre o critério de
remoção.

## Preservação da API durante a transpilação

Para toda API pública reutilizável do upstream, preserve o nome conceitual, a
responsabilidade, os valores padrão e o comportamento observável. Adapte
somente o necessário às convenções e ao sistema de tipos do Dart:

- tipos públicos usam `UpperCamelCase` e funções, métodos e campos públicos
  usam `lowerCamelCase`, tratando acrônimos como palavras comuns (ex.: `Cid`,
  `IpfsNode`, `IpfsConfig`, `DhtClient`, `idFromP2pAddr`), sem blocos em All-Caps;
- constantes públicas usam `lowerCamelCase` (ex.: `maxBlockSize`, `defaultTimeout`),
  sendo proibido o uso de `SCREAMING_SNAKE_CASE`;
- proibido criar `typedef`s, aliases ou shims artificiais em Dart para acomodar
  compatibilidade retroativa ou nomes legados (ex.: `typedef CID = Cid;`,
  `typedef MultihashInfo = DecodedMultihash;`). Consumidores devem ser migrados
  na raiz para os tipos canônicos. Exceções são apenas os tipos primitivos da
  especificação Go em `packages/boilerplate/` ou type aliases declarados no
  próprio repositório upstream Go;
- a anotação `@Deprecated` só é permitida se o símbolo correspondente no
  upstream Go estiver explicitamente marcado com `// Deprecated:`. É proibido
  manter símbolos deprecados inventados exclusivamente no Dart;
- construtores `NewX` do Go viram construtores ou factories Dart quando isso
  preservar o contrato, sem criar funções `newX` artificiais e sem prefixar
  construtores nomeados com `new` redundante (ex.: usar `IpfsNetwork.fromIpfsHost`,
  não `IpfsNetwork.newFromIpfsHost`);
- retornos `(valor, error)` viram retorno do valor com exceção tipada, sendo
  vedado retornar tuplas de erro Go `(T?, Exception?)` ou wrappers `Result<T, E>`
  em APIs públicas de biblioteca;
- variádicos, canais, goroutines e `context.Context` usam o equivalente Dart
  mais próximo (`List<T>`, `Stream`, `Future`, cancelamento), somente quando o
  comportamento exigir;
- símbolos internos do Go não precisam virar API pública Dart. Classes ou funções
  auxiliares não existentes no Go upstream devem ser privadas (prefixo `_`) para
  evitar expansão arbitrária de API pública.

Toda renomeação não mecânica, fusão, remoção ou mudança de assinatura pública
deve ser registrada em `doc/transpilation/PROGRESS.md` junto ao símbolo Go
correspondente. Não substitua uma API pública upstream por uma abstração
original sem justificar uma incompatibilidade concreta.

Cada port deve manter uma checklist verificável de símbolos públicos Go → Dart
nas notas do pacote em `PROGRESS.md`, incluindo omissões deliberadas e suas
razões. Paridade exige preservar também wire format, ordenação, defaults e
erros observáveis relevantes; sem essa auditoria, use no máximo o status
`portado sem teste de paridade`.

## Auditoria automatizada de AST, nomenclatura e fronteiras

Para garantir fidelidade contínua e prevenir regressões sintáticas ou de API, todo
agente deve validar seu código contra o auditor AST do projeto:
`tool/audit_ast_nomenclature.py`.

A ferramenta compara o índice AST do Go (`go-ipfs-reference/*-index/`) e as
definições de tipos upstream com as declarações Dart em `packages/` e `lib/`,
auditando automaticamente as 25 regras contratuais:

1. **`RULE_ALL_CAPS`**: Tipos públicos em `UpperCamelCase` e membros/funções em
   `lowerCamelCase`, tratando acrônimos como palavras comuns (ex.: `Cid`, `IpfsNode`,
   `DhtClient`, `idFromP2pAddr`), sem blocos em All-Caps.
2. **`RULE_LOWER_CAMEL`**: Membros, métodos e funções públicas devem usar
   estritamente `lowerCamelCase`, nunca `PascalCase`.
3. **`RULE_NO_TYPEDEF_SHIMS`**: Veto a `typedef`s e shims artificiais em Dart para
   compatibilidade retroativa, exceto os tipos primitivos em `packages/boilerplate/`
   ou type aliases declarados no próprio repositório upstream Go.
4. **`RULE_NO_UNAUTHORIZED_DEPRECATED`**: Veto a anotações `@Deprecated` inventadas
   em Dart sem a anotação `// Deprecated:` correspondente no Go upstream.
5. **`RULE_NO_NEW_X_FUNCTIONS`**: Veto a funções livres `newX(...)` que deveriam
   ser construtores ou factories de classe.
6. **`RULE_CONSTANT_CASING`**: Veto a constantes públicas em `SCREAMING_SNAKE_CASE`
   (ex.: `MAX_PACKET_SIZE`). No Dart oficial e no projeto, devem ser `lowerCamelCase`
   (`maxPacketSize`).
7. **`RULE_REDUNDANT_CONSTRUCTOR_NAMES`**: Veto a construtores nomeados prefixados
   com `new` ou repetindo o nome da classe (ex.: `IpfsNetwork.newFromIpfsHost` ➔
   `IpfsNetwork.fromIpfsHost`; `Blockstore.newBlockstore` ➔ `Blockstore`).
8. **`RULE_NO_GO_STYLE_ERROR_TUPLES`**: Veto a retornos públicos de tuplas com erro
   `(T?, Exception?)` ou wrappers `Result<T, E>`. Retornos `(valor, error)` do Go
   devem virar retorno direto do valor com exceção tipada via `throw`.
9. **`RULE_NO_CLI_IN_LIBRARIES`**: Veto a dependências e códigos de CLI em bibliotecas
   reutilizáveis `packages/transpiled_*` (`package:args/*`, `exitCode`, chamadas `exit()`).
10. **`RULE_ENFORCE_BOILERPLATE_TYPES`**: Uso obrigatório de `fixed_types.Golang.*`
    para centralizar semântica de tipos primitivos Go e máscaras manuais de 32/64 bits.
11. **`RULE_MODULE_BOUNDARY_LEAK`**: Veto a violação de fronteira de módulo `go.mod`,
    impedindo que um pacote declare tipos que pertencem a outro módulo upstream com
    pacote dedicado próprio.
12. **`RULE_INVENTED_PUBLIC_SYMBOLS`**: Alerta sobre tipos e abstrações públicas
    criadas em Dart sem símbolo exportado correspondente no upstream Go, orientando
    torná-los privados (`_Nome`) ou documentar sua necessidade.
13. **`RULE_EXCEPTION_NAMING`**: Nomenclatura e padrão de exceções Dart. O gatilho
    é **estrutural**: toda classe pública que declara `implements Exception` (ou
    herda de uma exceção) precisa usar o sufixo `Exception`. O prefixo legado `Err`
    do Go segue vetado à parte, porque uma classe pode carregar o idioma do Go sem
    declarar a interface (ex.: `ErrTooShort` ➔ `TooShortException`;
    `ConnError` ➔ `ConnException`).

    Esta regra vale em **qualquer pasta, `packages/boilerplate/` incluído**. A
    isenção que boilerplate tem em outras regras existe porque elas medem paridade
    com o upstream Go, e boilerplate não tem upstream; esta mede idioma de Dart, e
    boilerplate é justamente onde o código deve ser Dart idiomático em vez de Go
    traduzido. Para que a Regra 12 não brigue com esta, os candidatos de casamento
    com o Go incluem tanto o valor sentinela `ErrX` quanto o tipo `XError` quando o
    nome Dart termina em `Exception`.
14. **`RULE_NO_PRODUCTION_MOCKS`**: Veto a classes e implementações de teste
    (`Mock*`, `Dummy*`, `Stub*`, `Fake*`) no código de produção em `lib/`, devendo
    residir estritamente sob `test/`.
15. **`RULE_RESTRICTED_PLATFORM_IMPORTS`**: Veto a importação de `dart:io` em pacotes
    de codecs e multiformatos puros (`cid`, `multihash`, `multibase`, etc.),
    garantindo compatibilidade universal Web/Wasm.
16. **`RULE_NO_PRINT_IN_LIBRARIES`**: Veto a chamadas soltas a `print(...)` em pacotes
    de bibliotecas reutilizáveis.
17. **`RULE_NO_ARTIFICIAL_CONCURRENCY`**: Veto a primitivas de concorrência específicas
    do Go (`Chan`, `WaitGroup`, `Mutex`) em APIs públicas, exigindo as primitivas
    idiomáticas Dart (`Stream`, `Future`, `Completer`).
18. **`RULE_MISSING_GO_TYPES`**: Auditoria de tipos e interfaces do Upstream Go
    ainda não portados para o pacote Dart correspondente.
19. **`RULE_MISSING_GO_FIELDS`**: Auditoria de campos de structs do Upstream Go
    ainda não declarados na classe Dart correspondente.
20. **`RULE_MISSING_GO_METHODS`**: Auditoria de métodos do Upstream Go ainda não
    implementados na classe Dart correspondente.
21. **`RULE_MISSING_GO_FUNCTIONS`**: Auditoria de funções top-level do Upstream Go
    ainda não portadas para o pacote Dart correspondente.
22. **`RULE_PUBSPEC_DEPENDENCIES`**: Veto a dependências exclusivas de CLI (`args`, `dcli`)
    em `dependencies` de pacotes de bibliotecas reutilizáveis sob `packages/`,
    garantindo que utilitários de console residam estritamente sob `dev_dependencies`
    ou na raiz.
23. **`RULE_EXPOSED_NON_PUBLIC_MEMBERS`**: Veto a membros públicos que expõem
    tipos não-públicos (privados `_` ou de pacotes `internal/`), exigindo paridade
    estrita com o mesmo nível de visibilidade e permissão do Upstream Go, ou menor
    se não for possível. Membros públicos devem retornar interfaces públicas ou
    serem tornados privados (`_`) caso sejam detalhes internos de implementação.
24. **`RULE_MISSING_ATOMIC_TESTS`**: Auditoria de testes atômicos 1 para 1
    (`test/atomic/<nivel>/<nome_modulo>_atomic_tests.dart`), exigindo que cada função,
    método, getter, setter e operador público possua um teste atômico correspondente.
    A ausência de teste é apontada como erro bloqueante (`ERROR`).
25. **`RULE_IMPORT_PREFIX_NAMING`**: Colisão de nomes entre bibliotecas se
    resolve com **prefixo de import nomeado pela biblioteca**, nunca com um
    apelido curto ad hoc nem com `hide`. O porte mantém os nomes do upstream, e
    o mesmo nome aparece em mais de um módulo Go — `Limit` e `Limiter` existem
    ao mesmo tempo em `golang.org/x/time/rate`, em `go-libp2p/x/rate` e em
    `go-libp2p/p2p/host/resource-manager` —, então o ponto de uso precisa dizer
    de onde cada símbolo veio.

    Prefixo aceito: o nome do pacote (`transpiled_golang_x_time`) ou o mesmo
    nome sem o prefixo `transpiled_` (`golang_x_time`). Para
    `packages/boilerplate/`, `Golang` também vale, porque é o que os esquemas
    `fixed_types.Golang.<tipo>` já exigem.

    **Import interno (`package:<pkg>/src/...`) segue o pacote Go, não o pacote
    Dart.** Cada biblioteca sob `src/` corresponde a um pacote Go distinto, e é
    o nome dele que separa os símbolos — exatamente como o Go faz ao qualificar
    (`rate.Limit` contra `Limit`). Usar aqui o nome do pacote Dart faria várias
    bibliotecas diferentes disputarem o mesmo prefixo. O auditor lê a cláusula
    `package` do diretório Go correspondente, porque o diretório não basta: o Go
    chama de `rcmgr` o pacote em `resource-manager` e de `basichost` o que está
    em `basic`.

    `hide` é apontado em dois casos: colisão **entre pacotes Dart distintos**, e
    colisão **dentro do mesmo pacote** entre o barril e uma biblioteca interna —
    esta última resolvida com o prefixo do pacote Go. Quando o nome que fica vem
    de um arquivo local do próprio pacote, `hide` continua correto e a regra não
    se aplica.

    **Quando o prefixo exigido sombreia um identificador do arquivo** — uma
    variável, um campo ou um método homônimo —, o auditor aponta e a saída é a
    forma longa com sufixo `_package`: `transpiled_datastore_package` para
    prefixo de pacote Dart, `rate_package` para prefixo de pacote Go. Nenhum
    identificador Dart usa esse sufixo, então a colisão desaparece sem
    abandonar o nome do upstream. Em Dart o prefixo de import divide o espaço
    de nomes com variáveis e métodos, e o sombreamento pode passar despercebido
    quando prefixo e identificador ficam em escopos distintos: o arquivo
    compila, e só quebra quando alguém aproxima os dois.

    **Ao renomear um prefixo, renomeie primeiro o identificador local.**
    Enquanto o prefixo antigo ainda está no lugar, `nome` só pode ser a
    variável; depois da troca, os dois viram o mesmo token e não há como
    separá-los por regex.

    O auditor mantém, por arquivo, o mapa `prefixo → biblioteca`, exposto por
    `resolve_prefixed_reference`, de modo que uma referência `foo.Bar` seja
    atribuída ao pacote certo em vez de confundida com uma declaração local.

### Nível de visibilidade, permissão e tipos não-públicos

Ao portar e adaptar código onde membros públicos interagem com tipos não-públicos
(privados `unexported` ou pacotes `internal/` do Go), todo agente deve seguir o
**Princípio do Menor Privilégio e Paridade de Permissão**:

1. **Paridade com a Menor Permissão Possível:** Se um membro público da biblioteca
   precisa expor um objeto que no Go era um tipo interno, o tipo Dart deve conceder
   estritamente o mesmo nível de visibilidade e permissão do Upstream Go, ou menor
   se não for possível (ex.: interface somente-leitura ou `unmodifiable`). É vedado
   expor classes concretas mutáveis internas com campos desprotegidos.
2. **Veto a Tipos Privados em Assinaturas Públicas (`library_private_types_in_public_api`):**
   Membros públicos (métodos, getters, setters, campos) de classes públicas nunca devem
   ter tipo de retorno ou parâmetros com prefixo `_` (ex.: `_Scope get scope`,
   `_RecallWantlist bcstWants`).
3. **Mapeamento Caso a Caso dos Cenários Conhecidos:**
   - **Cenário A: Getters/Métodos de Interfaces Públicas (ex.: `ResourceManager` em `transpiled_libp2p`):**
     Getters como `systemScope`, `transientScope`, `peers`, `protocols` e `services`
     devem ser tipados com suas interfaces públicas canônicas (`Scope`, `PeerScope`,
     `ProtocolScope`, `ServiceScope`), e **nunca** com as classes de implementação
     privadas (`_Scope`, `_PeerScope`).
   - **Cenário B: Campos Internos de Classes de Submódulos (ex.: `MessageQueue` em `transpiled_boxo`):**
     Campos de classes internas que armazenam estado auxiliar (ex.: `bcstWants`,
     `peerWants`, `pending`, `sent`) devem ser tornados privados (`_bcstWants`,
     `_peerWants`, `_pending`, `_sent`), eliminando a exposição indevida.
   - **Cenário C: Estruturas Auxiliares Expostas Transitivamente (ex.: `ExploreRecursiveEdge` em `transpiled_ipld_prime`):**
     Promover a classe para pública (`ExploreRecursiveEdge`) ou expor apenas a
     interface necessária com campos imutáveis/somente-leitura.
4. **Fidelidade Integral da Implementação Não-Pública:**
   Tudo o que for acessado ou exposto através de métodos não-públicos (ou da cadeia
   interna de execução de métodos públicos) **deve ser implementado com estrita
   fidelidade ao upstream Golang**. O fato de um membro, tipo ou método ser privado
   (`_` em Dart, `unexported` ou `internal/` no Go) afeta estritamente sua visibilidade
   e escopo de acesso, **sendo expressamente proibido degradar a lógica interna**,
   criar simplificações arbitrárias, stubs parciais ou mocks em código de produção.
   Toda a cadeia de chamadas internas, estados, limites e algoritmos subjacentes
   deve reproduzir fielmente a implementação do módulo Go correspondente.

### Diretrizes para Testes Atômicos 1 para 1 (Regra 24)

Todo código público portado ou adaptado deve possuir cobertura de testes atômicos 1 para 1 sob a pasta `test/atomic/<nivel>/<nome_modulo>_atomic_tests.dart`.

A pasta padrão é `test/`, inclusive para os testes atômicos. O `dart_test.yaml`
inclui `*_test.dart` e `*_atomic_tests.dart` na descoberta de `dart test`;
o auditor usa exclusivamente `test/atomic/` para a regra 24.

1. **Definição Autônoma do Nível pelo Agente:**
   O agente ou desenvolvedor que implementar o teste é o responsável por definir em qual nível o teste deve residir, conforme os requisitos de ambiente da função/classe:
   - **`test/atomic/nivel_1/` (Puro / Unitário):** Funções puras, codecs, parsing, algoritmos em memória e manipulação de bytes sem dependências externas ou I/O.
   - **`test/atomic/nivel_2/` (Emulação Local / Memória):** Datastores em memória, tabelas de roteamento (Kademlia buckets), multiplexadores e trocas locais sem daemons externos.
   - **`test/atomic/nivel_3/` (Integração Real / Daemon Ativo):** Fluxos que exigem sockets de rede reais, handshakes criptográficos completos ou o daemon do Kubo ativo na máquina.

2. **Veto a Stubs, Placeholders e Esqueletos Vazios:**
   É expressamente proibido criar testes com corpos vazios, apenas comentários `// TODO`, ou meras chamadas a `fail()`. O auditor AST inspeciona o corpo da closure do teste e rejeita qualquer teste que não contenha asserções reais (`expect(...)`, `expectLater(...)`, `assert(...)`, `throwsA(...)`). Testes em formato de stub não computam como testados e continuam gerando erro bloqueante (`ERROR`).

3. **Múltiplos Testes por Símbolo (Caminho Feliz, Erros e Bordas):**
   Para símbolos que executam ações ou possuem ramificações lógicas, é permitido e fortemente incentivado escrever múltiplos testes (ex.: sucesso, falha com exceção tipada, valores-limite). A convenção obrigatória para manter a resolução AST de múltiplos testes é prefixar o teste com o nome do método ou membro:
   ```dart
   group('Classe [Atomic Audit]', () {
     test('metodo() - caso de sucesso com entrada válida', () {
       final obj = Classe();
       expect(obj.metodo('valido'), isTrue);
     });

     test('metodo() - lança FormatException quando entrada é vazia', () {
       final obj = Classe();
       expect(() => obj.metodo(''), throwsA(isA<FormatException>()));
     });
   });
   ```

### Portão obrigatório de conclusão: auditoria AST com testes

A auditoria AST **não é recomendação, é portão de conclusão**. Nenhuma
alteração de código ou transpilação pode ser dada por concluída — e o agente
não pode dizer ao usuário que "está bom", "está verde" ou "está pronto" — antes
de executar o auditor **incluindo a auditoria de testes** e **resolver tudo o
que ele apontar**. Relatar pendência do auditor como aceitável, ou deixá-la
para depois, equivale a não ter concluído a tarefa.

A sequência mínima obrigatória antes de finalizar é:

1. `dart format lib bin test packages`
   — **obrigatório antes de qualquer commit, sem exceção.** Roda primeiro na
   sequência, e não por último: formatar depois de auditar invalidaria em
   silêncio os relatórios recém-gerados do passo 5. Ver a seção
   "Formatação obrigatória antes de commitar" logo abaixo.
2. `python tool/audit_ast_nomenclature.py --tests --severity ERROR`
   — precisa terminar em `NENHUMA INCONSISTÊNCIA ENCONTRADA` e sair com código 0.
3. `python tool/audit_ast_nomenclature.py --tests`
   — reveja também os avisos e notas de cobertura; resolva o que for do escopo
   da alteração em curso em vez de acumular dívida silenciosa.
4. Rodar a suíte completa conforme a seção "Suíte verde é a linha de base,
   independente de autoria" (raiz, cada pacote em `packages/*/`, presets
   `interop` e `network`), corrigindo qualquer falha encontrada.
5. Regenerar os relatórios versionados que o próprio auditor produz, porque
   eles ficam obsoletos em silêncio a cada símbolo adicionado ou alterado:
   - `python tool/audit_ast_nomenclature.py --progress` → `PROGRESS_RELATORY.md`
   - `python tool/audit_ast_nomenclature.py --markdown --output audit_report.md`

   Esses dois nomes são os **únicos** destinos versionados desses relatórios.
   O `--output` aceita qualquer caminho, e usar outro nome cria uma cópia que
   ninguém regenera e que passa a mentir na sessão seguinte — foi exatamente o
   que aconteceu com um `errors_report.md`, byte a byte idêntico ao
   `audit_report.md`, sem nenhuma referência no repositório e defasado em
   centenas de símbolos até ser removido em 2026-09-09. Ao gerar um relatório
   ad hoc para inspeção pontual, escreva fora da árvore versionada.
6. Registrar em `doc/transpilation/PROGRESS.md` o rastreamento e as decisões da
   alteração, conforme já exigido acima.

#### Formatação obrigatória antes de commitar

**Nenhum commit pode ser feito sem rodar `dart format` antes.** Não é
preferência de estilo nem passo cosmético opcional: é requisito de commit, no
mesmo nível do auditor AST e da suíte verde.

```
dart format lib bin test packages
```

A razão é específica deste repositório. O código nasce transpilado do Go em
lotes grandes e repetitivos, muitas vezes por vários subagentes em paralelo.
Sem um passo de formatação obrigatório, cada lote carrega o espaçamento e as
quebras de linha que o seu autor por acaso produziu, e o diff resultante mistura
mudança semântica real com ruído de formatação — o que dificulta a revisão e
esconde defeitos.

Rode-o **no início** da sequência de conclusão, não no fim: formatar depois de
gerar `PROGRESS_RELATORY.md` e `audit_report.md` deixaria esses relatórios
defasados em relação à árvore já no mesmo commit.

**Sempre confira as regras que governam os testes antes de escrever ou ajustar
qualquer teste.** Releia a seção "Diretrizes para Testes Atômicos 1 para 1
(Regra 24)" deste arquivo em vez de confiar na memória: ela define a pasta e o
nível corretos, como o auditor associa teste e símbolo (nome do `test(...)` e do
`group(...)`) e o que ele rejeita (teste vazio, stub ou apenas `fail()`). Todo
símbolo público novo — função, método, getter, setter ou operador — nasce com
seu teste atômico correspondente; a ausência é erro bloqueante.

#### Comandos de verificação

Além da sequência obrigatória acima, estes comandos ajudam a isolar problemas
durante o trabalho:

- **Resumo quantitativo global:**
  `python tool/audit_ast_nomenclature.py --summary-only`
- **Auditoria detalhada do pacote alterado:**
  `python tool/audit_ast_nomenclature.py --package <nome_do_pacote>`
- **Auditoria de testes atômicos 1 para 1:**
  `python tool/audit_ast_nomenclature.py --tests`
- **Auditoria de testes atômicos por pacote:**
  `python tool/audit_ast_nomenclature.py --tests --package <nome_do_pacote>`
- **Auditoria por regra específica:**
  `python tool/audit_ast_nomenclature.py --rule <NOME_DA_REGRA>`
- **Auditoria de cobertura incluindo símbolos não-públicos (privados/internos):**
  `python tool/audit_ast_nomenclature.py --include-non-public`
- **Filtrar por severidade (ERROR, WARNING, INFO):**
  `python tool/audit_ast_nomenclature.py --severity ERROR`
- **Exportar relatório completo em Markdown:**
  `python tool/audit_ast_nomenclature.py --markdown --output audit_report.md`
- **Atualizar relatório sintético de progresso da AST (`PROGRESS_RELATORY.md`):**
  `python tool/audit_ast_nomenclature.py --progress`
- **Correção automática mecânica determinística:**
  `python tool/audit_ast_nomenclature.py --fix`
- **Saída estruturada em JSON (integração e CI):**
  `python tool/audit_ast_nomenclature.py --json`

### Suíte verde é a linha de base, independente de autoria

Todo teste que falhar ou que deixar de compilar deve ser corrigido pelo agente
que o encontrar, **independente de quem introduziu a quebra**. Constatar que a
falha é anterior à tarefa em curso, que veio de outro refactor pendente na
branch ou que pertence a outra frente de trabalho serve para localizar a causa
raiz — nunca para deixar a falha de pé, nem para devolver a decisão ao usuário
na forma de "quer que eu corrija?".

A distinção que importa é outra: **reparar** um teste para que volte a compilar
e executar restaura a intenção que o autor já tinha, e é feito de forma
autônoma; **alterar o que um teste que funciona afirma** muda essa intenção, e
aí sim o usuário deve ser consultado antes.

Ao diagnosticar a causa raiz, prefira corrigir onde todos os chamadores passam.
Em colisão de nomes entre dois módulos Go transpilados (por exemplo `Client`,
que existe tanto no bitswap do `transpiled_boxo` quanto no circuitv2 do
`transpiled_libp2p`), os nomes das bibliotecas estão corretos e devem
permanecer fiéis ao upstream: quem se ajusta é o ponto de importação, com
`hide` ou prefixo, como já é feito em `lib/src/node/ipfs_node.dart`.

#### A suíte completa não é só `dart test`

`dart test` na raiz cobre apenas o pacote raiz. Os pacotes transpilados têm
suítes próprias que **não** são executadas por ele, e `melos` pode não estar
disponível no PATH da máquina. Antes de declarar a suíte verde, execute:

- **Pacote raiz:** `dart test`
- **Cada pacote transpilado:**
  `for d in packages/*/; do (cd "$d" && dart test); done`
  (ou `melos run test`, quando o `melos` estiver instalado)
- **Interoperabilidade com Kubo real:** `dart test --preset interop`
- **Testes que exigem rede real:** `dart test --preset network`

Os testes marcados com as tags `p0`, `p1`, `helia` e `network` são pulados por
padrão. Um resultado "All tests passed" com contagem de pulados (`~N`) não é
prova de suíte verde: rode os presets correspondentes antes de afirmar que
está tudo passando.
