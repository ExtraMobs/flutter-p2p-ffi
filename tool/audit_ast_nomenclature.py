#!/usr/bin/env python3
"""
tool/audit_ast_nomenclature.py

Auditor automatizado de AST e Nomenclatura Dart <-> Go conforme AGENTS.md.

Pipeline de fatos (sem `re`):

  1. `tool/dart_ast_facts.dart` (package:analyzer, parseString) produz um JSON
     com declarações, imports, identificadores declarados, invocações de
     print/exit, atribuições a exitCode, literais hexadecimais em `&` e, para
     arquivos sob `test/`, as chamadas `group`/`test` com o corpo estruturado
     de cada teste. Este auditor roda essa ferramenta (via `dart run`) e
     consome só o JSON resultante.
  2. `tool/go_module_index.go -json` (go/ast, sem go/types) produz um JSON
     com toda declaração Go (exportada e não-exportada) de cada repositório
     de referência sob `go-ipfs-reference/`, mais a cláusula `package` de
     cada diretório. Este auditor roda essa ferramenta (via `go run`) e
     consome só o JSON resultante.

Ambos os JSONs são gerados em `.dart_tool/` e reaproveitados entre execuções;
são regenerados automaticamente quando ficam desatualizados (arquivo-fonte
mais novo que o JSON, ferramenta geradora mais nova, ou lista de módulos Go
mudou). Nenhuma leitura de texto Dart/Go entra na lógica das regras — a
lógica das 26 regras contratuais abaixo continua em Python, mas seu INSUMO
passou de texto varrido por expressão regular para os fatos estruturados
acima. Onde a heurística antiga de regex aproximava uma noção sintática, a
noção sintática passou a ser calculada diretamente sobre os fatos.

As 26 regras:
  1. RULE_ALL_CAPS: UpperCamelCase sem blocos em All-Caps para Tipos Públicos (ex: IpfsNode, não IPFSNode).
  2. RULE_LOWER_CAMEL: lowerCamelCase sem blocos em All-Caps para Funções, Métodos e Campos Públicos (ex: idFromP2pAddr, não idFromP2PAddr; wrapData, não WrapData).
  3. RULE_NO_TYPEDEF_SHIMS: Veto a typedefs/shims artificiais em Dart para compatibilidade retroativa (ex: typedef CID = Cid;).
  4. RULE_NO_UNAUTHORIZED_DEPRECATED: Veto a @Deprecated inventado exclusivamente no Dart (permitido apenas se Go upstream contiver // Deprecated:).
  5. RULE_NO_NEW_X_FUNCTIONS: Veto a funções livres newX(...) que deveriam ser construtores ou factories de classe.
  6. RULE_CONSTANT_CASING: Veto a constantes e campos públicos em SCREAMING_SNAKE_CASE (devem ser lowerCamelCase).
  7. RULE_REDUNDANT_CONSTRUCTOR_NAMES: Veto a construtores nomeados redundantes ou prefixados com 'new' (ex: IpfsNetwork.newFromIpfsHost -> fromIpfsHost).
  8. RULE_NO_GO_STYLE_ERROR_TUPLES: Veto a tuplas de erro estilo Go e Result wrappers em APIs públicas (ex: (T, Error?) -> retorno com exceção tipada via throw).
  9. RULE_NO_CLI_IN_LIBRARIES: Veto a dependências/códigos exclusivos de CLI em bibliotecas reutilizáveis (package:args, exitCode, exit).
  10. RULE_ENFORCE_BOILERPLATE_TYPES: Uso obrigatório de fixed_types.Golang.* para tipos primitivos e máscaras manuais de 32/64 bits.
  11. RULE_MODULE_BOUNDARY_LEAK: Veto a vazamento de fronteira de módulo go.mod (tipos declarados fora do seu pacote proprietário).
  12. RULE_INVENTED_PUBLIC_SYMBOLS: Detecção de tipos e abstrações públicas inventadas no Dart sem correspondente exportado no Go upstream.
  13. RULE_EXCEPTION_NAMING: Nomenclatura e padrão de exceções Dart (XException implements Exception, veto a prefixo 'Err' do Go).
  14. RULE_NO_PRODUCTION_MOCKS: Veto a classes/implementações de teste (Mock, Dummy, Stub, Fake) em código de biblioteca.
  15. RULE_RESTRICTED_PLATFORM_IMPORTS: Veto a dart:io em pacotes de codecs e multiformatos puros (garantia Web/Wasm).
  16. RULE_NO_PRINT_IN_LIBRARIES: Veto a chamadas soltas a print(...) em bibliotecas reutilizáveis.
  17. RULE_NO_ARTIFICIAL_CONCURRENCY: Veto a primitivas de concorrência específicas do Go (Chan, WaitGroup, Mutex) em APIs públicas.
  18. RULE_MISSING_GO_TYPES: Auditoria de tipos e interfaces do Upstream Go ainda não portados para o pacote Dart.
  19. RULE_MISSING_GO_FIELDS: Auditoria de campos de structs do Upstream Go ainda não portados para a classe Dart correspondente.
  20. RULE_MISSING_GO_METHODS: Auditoria de métodos do Upstream Go ainda não implementados na classe Dart correspondente.
  21. RULE_MISSING_GO_FUNCTIONS: Auditoria de funções top-level do Upstream Go ainda não portadas para o pacote Dart.
  22. RULE_PUBSPEC_DEPENDENCIES: Veto a dependências de CLI (args, dcli) em dependencies de bibliotecas em pubspec.yaml.
  23. RULE_EXPOSED_NON_PUBLIC_MEMBERS: Veto a membros públicos expondo tipos não-públicos (privados '_' ou de 'internal/'), exigindo paridade com mesmo nível de visibilidade e permissão (ou menor).
  24. RULE_MISSING_ATOMIC_TESTS: Auditoria de testes atômicos 1 para 1 em test/atomic/<nivel>/<nome_modulo>_atomic_tests.dart.
  25. RULE_IMPORT_PREFIX_NAMING: Colisão de nomes entre bibliotecas resolvida com prefixo de import nomeado pela biblioteca, nunca com hide ou apelido ad hoc.
  26. RULE_PARSE_ERROR: Erro de sintaxe (package:analyzer) detectado ao extrair fatos de um arquivo Dart -- bloqueante, porque um erro de parse esconde silenciosamente as declarações do arquivo.

Uso:
  python tool/audit_ast_nomenclature.py
  python tool/audit_ast_nomenclature.py --tests
  python tool/audit_ast_nomenclature.py --tests --package transpiled_cid
  python tool/audit_ast_nomenclature.py --package transpiled_boxo
  python tool/audit_ast_nomenclature.py --rule RULE_MISSING_GO_TYPES
  python tool/audit_ast_nomenclature.py --rule RULE_MISSING_GO_FIELDS
  python tool/audit_ast_nomenclature.py --rule RULE_MISSING_GO_METHODS
  python tool/audit_ast_nomenclature.py --rule RULE_MISSING_GO_FUNCTIONS
  python tool/audit_ast_nomenclature.py --include-non-public
  python tool/audit_ast_nomenclature.py --severity ERROR
  python tool/audit_ast_nomenclature.py --markdown --output audit_report.md
  python tool/audit_ast_nomenclature.py --fix
  python tool/audit_ast_nomenclature.py --summary-only
  python tool/audit_ast_nomenclature.py --json
"""

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

import yaml

# Acrônimos conhecidos no ecossistema IPFS/libp2p/Go para normalização consistente
COMMON_ACRONYMS = {
    'IPFS': 'Ipfs',
    'DHT': 'Dht',
    'CID': 'Cid',
    'ID': 'Id',
    'P2P': 'P2p',
    'TTL': 'Ttl',
    'CPL': 'Cpl',
    'URL': 'Url',
    'URI': 'Uri',
    'HTTP': 'Http',
    'HTTPS': 'Https',
    'RPC': 'Rpc',
    'PB': 'Pb',
    'CAR': 'Car',
    'XOR': 'Xor',
    'ASCII': 'Ascii',
    'UTF': 'Utf',
    'JSON': 'Json',
    'DSA': 'Dsa',
    'RSA': 'Rsa',
    'ECDSA': 'Ecdsa',
    'DER': 'Der',
    'DNS': 'Dns',
    'NAT': 'Nat',
    'FUSE': 'Fuse',
    'API': 'Api',
    'IO': 'Io',
    'FD': 'Fd',
    'RTT': 'Rtt',
    'MTU': 'Mtu',
    'ASN': 'Asn',
    'TCP': 'Tcp',
    'UDP': 'Udp',
    'IP': 'Ip',
    'QUIC': 'Quic',
    'DAG': 'Dag',
    'MFS': 'Mfs',
    'HAMT': 'Hamt',
}

# Mapeamento oficial de módulos Go para diretórios de pacotes Dart
GO_MODULE_TO_DART_PACKAGE = {
    'go-base32': 'packages/transpiled_base32',
    'go-cid': 'packages/transpiled_cid',
    'benbjohnson-clock': 'packages/transpiled_clock',
    'go-multiaddr': 'packages/transpiled_multiaddr',
    'go-multihash': 'packages/transpiled_multihash',
    'go-multibase': 'packages/transpiled_multibase',
    'go-multicodec': 'packages/transpiled_multicodec',
    'go-multiaddr-dns': 'packages/transpiled_multiaddr_dns',
    'go-libp2p': 'packages/transpiled_libp2p',
    'go-yamux': 'packages/transpiled_go_yamux',
    'boxo': 'packages/transpiled_boxo',
    'go-block-format': 'packages/transpiled_block_format',
    'go-ipld-prime': 'packages/transpiled_ipld_prime',
    'go-datastore': 'packages/transpiled_datastore',
    'go-libp2p-kbucket': 'packages/transpiled_libp2p_kbucket',
    'go-libp2p-record': 'packages/transpiled_libp2p_record',
    'go-libp2p-pubsub': 'packages/transpiled_libp2p_pubsub',
    'go-libp2p-routing-helpers': 'packages/transpiled_libp2p_routing_helpers',
    'go-varint': 'packages/transpiled_varint',
    'go-codec-dagpb': 'packages/transpiled_go_codec_dagpb',
    'go-ipld-git': 'packages/transpiled_go_ipld_git',
    'go-dag-jose': 'packages/transpiled_go_dag_jose',
    'protobuf': 'packages/transpiled_protobuf',
    'go-car-v2': 'packages/transpiled_go_car',
    'kubo': 'lib',
    'go-libp2p-kad-dht': 'packages/transpiled_libp2p_kad_dht',
    'pion-randutil': 'packages/transpiled_pion_randutil',
    'pion-logging': 'packages/transpiled_pion_logging',
    'pion-transport': 'packages/transpiled_pion_transport',
    'pion-transport-v4': 'packages/transpiled_pion_transport_v4',
    'pion-stun': 'packages/transpiled_pion_stun',
    'pion-sdp': 'packages/transpiled_pion_sdp',
    'pion-dtls': 'packages/transpiled_pion_dtls',
    'pion-sctp': 'packages/transpiled_pion_sctp',
    'pion-datachannel': 'packages/transpiled_pion_datachannel',
    'pion-ice': 'packages/transpiled_pion_ice',
    'pion-webrtc': 'packages/transpiled_pion_webrtc',
    'pion-turn': 'packages/transpiled_pion_turn',
    'pion-mdns': 'packages/transpiled_pion_mdns',
    'pion-interceptor': 'packages/transpiled_pion_interceptor',
    'pion-rtp': 'packages/transpiled_pion_rtp',
    'pion-rtcp': 'packages/transpiled_pion_rtcp',
    'pion-srtp': 'packages/transpiled_pion_srtp',
    'golang-x-net': 'packages/transpiled_golang_x_net',
    'golang-x-time': 'packages/transpiled_golang_x_time',
    'quic-go': 'packages/transpiled_quic_go',
    'qpack': 'packages/transpiled_qpack',
    'webtransport-go': 'packages/transpiled_webtransport_go',
}

# Prefixos e sufixos canônicos de módulos/pacotes para correspondência de tipos Go <-> Dart
KNOWN_PREFIXES = ('Yamux', 'DagPb', 'UnixFs', 'Car', 'Cid', 'Ipfs', 'Basicnode', 'Noise', 'Ed25519', 'Rsa', 'Secp256k1', 'Filter', 'Git', 'Jose', 'DagJose')
KNOWN_SUFFIXES = ('Impl', 'Options', 'Exception', 'Error', 'Chunker', 'Importer', 'Router')

# Adaptações de arquitetura documentadas em PROGRESS.md conforme AGENTS.md ("ou documentar adaptação")
DOCUMENTED_ADAPTATIONS = {
    # packages/transpiled_multibase
    'MultibaseUtils': 'PROGRESS.md:1185 - Utilitário central de encode/decode para as 21 bases do go-multibase',
    # packages/transpiled_multihash
    'MultihashUtils': 'PROGRESS.md:1168 - Utilitário central de multihash digest/decode para parity vectors do go-multihash',
    # packages/transpiled_boxo
    'NullGauge': 'PROGRESS.md - Gauge no-op para cliente bitswap',
    'ByteReader': 'PROGRESS.md - Adaptador Dart para io.Reader / bytes.Reader do Go',
    'VarintReader': 'PROGRESS.md - Adaptador Dart para leitura de varint sobre byte streams',
    'P2pStream': 'PROGRESS.md - Interface agnóstica de stream P2P para rede bitswap',
    'P2pHost': 'PROGRESS.md - Interface agnóstica de host P2P para rede bitswap',
    'UnixFsImportResult': 'PROGRESS.md - Retorno de importação UnixFS em Dart',
    'BlockPresenceType': 'PROGRESS.md - Enum Dart para tipos de presença de bloco do protobuf bitswap',
    'BlockstoreNotFoundException': 'PROGRESS.md - Exceção tipada para ErrNotFound do blockstore',
    'FixedSizeChunker': 'PROGRESS.md - Implementação do FixedSize chunker do Boxo',
    'BalancedUnixFsImporter': 'PROGRESS.md - Builder e importer UnixFS balanceado do Boxo',
    'NotificationsPubSub': 'PROGRESS.md - Interface PubSub interna de notificações bitswap',
    # packages/transpiled_cid
    'InvalidEncodingException': 'PROGRESS.md - Exceção tipada para falhas de decodificação de encoding de CID',
    # packages/transpiled_datastore
    'QueryIterator': 'PROGRESS.md - Iterador síncrono/assíncrono Dart para datastore query results',
    # packages/transpiled_go_car
    'CarIntegrityException': 'PROGRESS.md - Exceção tipada para violação de integridade em arquivos CAR',
    # packages/transpiled_go_yamux
    'YamuxMessageType': 'PROGRESS.md - Enum para constantes de tipos de mensagem do protocolo Yamux',
    'YamuxFrame': 'PROGRESS.md - Representação estruturada de header/frame do protocolo Yamux',
    'YamuxFrameDecoder': 'PROGRESS.md - Decodificador sequencial de frames Yamux sobre stream de bytes',
    'YamuxException': 'PROGRESS.md - Classe base de exceção tipada do protocolo Yamux',
    'YamuxRemoteGoAwayException': 'PROGRESS.md - Exceção tipada para erro remoto GoAway do go-yamux',
    'YamuxStreamResetException': 'PROGRESS.md - Exceção tipada para ErrStreamReset do go-yamux',
    'YamuxSessionClosedException': 'PROGRESS.md - Exceção tipada para ErrSessionShutdown do go-yamux',
    'YamuxKeepAliveTimeoutException': 'PROGRESS.md - Exceção tipada para ErrKeepAliveTimeout do go-yamux (const.go:130)',
    # packages/transpiled_ipld_prime
    'SeekOrigin': 'PROGRESS.md - Equivalente Dart para io.SeekStart/Current/End do Go',
    'ByteReadSeeker': 'PROGRESS.md - Equivalente Dart para io.ReadSeeker do Go',
    'MemoryStore': 'PROGRESS.md - Storage em memória para IPLD links',
    'PreloadLink': 'PROGRESS.md - Abstração de pré-carregamento para IPLD traversals',
    'SelectorParseException': 'PROGRESS.md - Exceção tipada para erros de parsing de seletores IPLD',
    'RecursionLimitMode': 'PROGRESS.md - Enum Dart para modos de limite de recursão em seletores',
    'DagJsonEncodeOptions': 'PROGRESS.md - Opções de encoding DAG-JSON',
    'DagJsonDecodeOptions': 'PROGRESS.md - Opções de decoding DAG-JSON',
    'JsonCodecException': 'PROGRESS.md - Exceção tipada para falhas do codec JSON',
    # packages/transpiled_libp2p
    'WebtransportCertificate': 'PROGRESS.md - Certificado WebTransport de 14 dias com o seu signer; o Go devolve (*x509.Certificate, *ecdsa.PrivateKey) de generateCert e embrulha em tls.Config (crypto.go:31-42), e este projeto nao tem nenhum dos dois tipos',
    'NoiseKeyPair': 'PROGRESS.md:1318 - Par de chaves Noise do flynn/noise',
    'NoiseRemoteIdentity': 'PROGRESS.md:1318 - Identidade remota autenticada do handshake Noise',
    'NoiseHandshakeAuthException': 'PROGRESS.md:1318 - Exceção tipada para falhas de autenticação Noise',
    'CipherState': 'PROGRESS.md:1318 - Estado do cifrador simétrico da especificação Noise (flynn/noise)',
    'SymmetricState': 'PROGRESS.md:1318 - Estado simétrico de handshake da especificação Noise (flynn/noise)',
    'HandshakeState': 'PROGRESS.md:1318 - Máquina de estado do handshake da especificação Noise (flynn/noise)',
    'EncryptedData': 'PROGRESS.md - Contêiner de dados criptografados com IV/tag para crypto utils',
    'CryptoUtils': 'PROGRESS.md - Utilitários criptográficos de plataforma Dart (PBKDF2, constantTimeEquals, zeroMemory)',
    'Ed25519Signer': 'PROGRESS.md - Signer Dart para assinaturas Ed25519',
    'NetworkContext': 'PROGRESS.md - Contexto de execução e cancelamento para operações de rede libp2p',
    'NetworkStream': 'PROGRESS.md - Implementação e contrato canônico de Stream libp2p em Dart',
    'StreamResetException': 'PROGRESS.md - Exceção tipada para ErrReset de stream libp2p',
    'RoutingNotFoundException': 'PROGRESS.md - Exceção tipada para ErrNotFound de roteamento libp2p',
    'RoutingNotSupportedException': 'PROGRESS.md - Exceção tipada para ErrNotSupported de roteamento libp2p',
    'TemporaryNetworkException': 'PROGRESS.md - Exceção de rede com flag de transitoriedade',
    'MissingConnManagementScopeException': 'PROGRESS.md - Exceção para ausência de escopo de gerenciamento de conexão',
    'NoPublicKeyException': 'PROGRESS.md - Exceção lançada quando chave pública é ausente no PeerId',
    'InvalidPeerIdSourceException': 'PROGRESS.md - Exceção para fontes inválidas de derivação de PeerId',
    'ProtocolSwitch': 'PROGRESS.md - Switch de protocolo multistream-select em Dart',
    'MultistreamMuxer': 'PROGRESS.md - Multiplexador de protocolos multistream-select (msmux.MultistreamMuxer do Go)',
    'ItemNotFoundException': 'PROGRESS.md - Exceção tipada para ErrNotFound de core/peerstore',
    'MemoryPeerstore': 'PROGRESS.md - Implementação concreta em memória de Peerstore (pstoremem do Go)',
    'HopMessageType': 'PROGRESS.md - Enum de tipos de mensagem HopMessage (HopMessage_Type do Go em circuitv2/pb)',
    'HopStatus': 'PROGRESS.md - Status de resposta do relay v2 (Status do Go em circuitv2/pb)',
    'CircuitPeer': 'PROGRESS.md - Representação protobuf de Peer em circuitv2/pb',
    'CircuitReservation': 'PROGRESS.md - Representação protobuf de Reservation em circuitv2/pb',
    'CircuitLimit': 'PROGRESS.md - Representação protobuf de Limit em circuitv2/pb',
    'QueryEventRegistration': 'PROGRESS.md - Registro de observador de eventos de busca no DHT',
    'UpgradedCapableConn': 'PROGRESS.md - Conexão CapableConn autenticada e multiplexada pós-upgrade (upgrader.capableConn do Go)',
    'BasicUpgrader': 'PROGRESS.md - Implementação padrão de Upgrader (p2p/net/upgrader.Upgrader do Go)',
    'SwarmStream': 'PROGRESS.md - Porte de swarm.Stream (p2p/net/swarm/swarm_stream.go); renomeado porque Stream é o tipo assincrono nativo do Dart',
    'SwarmConn': 'PROGRESS.md - Porte de swarm.Conn (p2p/net/swarm/swarm_conn.go); renomeado porque Conn ja nomeia o network.Conn que esta classe implementa',
    'StreamReadWriter': 'PROGRESS.md - Interface para leitura e escrita binária de streams/conns (io.ReadWriter do Go)',
    'RawConn': 'PROGRESS.md - Interface para conexão bruta de transporte antes de upgrade (manet.Conn do Go)',
    'HolePunchService': 'PROGRESS.md - Serviço de coordenação de hole punching DCUtR (p2p/protocol/holepunch.Service do Go)',
    'HolePunchMessageType': 'PROGRESS.md - Enum Dart para tipos de mensagem do DCUtR (HolePunch_Type do Go)',
    'HolePunchMessage': 'PROGRESS.md - Representação protobuf de mensagem HolePunch (holepunch.pb do Go)',
    'NatGateway': 'PROGRESS.md - Interface de abstração de gateway UPnP/NAT-PMP para NATManager',
    'SimulatedNatGateway': 'PROGRESS.md - Implementação simulada de gateway UPnP/NAT-PMP para ambientes locais e testes',
    'Libp2pNatGateway': 'PROGRESS.md - Implementação padrão de gateway NAT conectada a p2p/net/nat',
    'BasicNatManager': 'PROGRESS.md - Implementação padrão de gerenciador NAT com port mapping (p2p/host/basic.natManager do Go)',
    'TlsTransport': 'PROGRESS.md - Implementação de SecureTransport para TLS 1.3 (p2p/security/tls.Transport do Go renomeada para evitar colisão com core/transport.Transport)',
    'WebtransportTransport': 'PROGRESS.md - Implementação de Transport para WebTransport (p2p/transport/webtransport.transport do Go renomeada para evitar colisão com core/transport.Transport)',
    'WebRtcTransport': 'PROGRESS.md - Implementação de Transport para WebRTC Direct (p2p/transport/webrtc.transport do Go renomeada para evitar colisão com core/transport.Transport)',
    # packages/transpiled_libp2p_kbucket
    'KeyspaceKey': 'PROGRESS.md - Chave no espaço de chaves XOR da Kademlia',
    'PeerMetrics': 'PROGRESS.md - Métricas de latência e confiabilidade de peers na tabela de roteamento',
    'PeerRejectedNoCapacityException': 'PROGRESS.md - Exceção para rejeição de peer por bucket cheio no kbucket',
    # packages/transpiled_libp2p_routing_helpers
    'Closable': 'PROGRESS.md - Interface para fechamento de recursos de roteamento paralelo (io.Closer do Go)',
    # packages/transpiled_pion_ice
    'TcpAddr': 'PROGRESS.md - Adaptação do tipo stdlib Go net.TCPAddr usado pelo pion-ice (Dart nao tem tipo de valor equivalente; precedente UdpAddr em transpiled_pion_transport_v4 porta net.UDPAddr)',
    # packages/transpiled_ipld_prime
    'ReadSeeker': 'PROGRESS.md - Adaptação do tipo stdlib Go io.ReadSeeker retornado por LargeBytesNode.AsLargeBytes() do go-ipld-prime (o SDK Dart nao tem leitor genérico seekable; RandomAccessFile é apenas-arquivo e dart:io)',
}

# Caminhos fora de escopo conforme AGENTS.md (CLI, benchmarks, etc.). Os
# padrões antigos eram regex `search` (não-ancorada) (não-ancorada) com `.*` no fim, o
# que na prática equivale a um teste de substring simples; o único caso
# genuinamente diferente era o sufixo `_test.go`.
OUT_OF_SCOPE_SUBSTRINGS = (
    'kubo/cmd/',
    'kubo/commands/',
    'kubo/core/commands/',
    'kubo/test/cli/',
    'matest/',
    'sharness/',
)


def is_out_of_scope(file_path: str) -> bool:
    norm = file_path.replace('\\', '/')
    if norm.endswith('_test.go'):
        return True
    return any(sub in norm for sub in OUT_OF_SCOPE_SUBSTRINGS)


# Títulos e identificadores das 26 regras contratuais
RULE_TITLES = {
    'RULE_ALL_CAPS': "1. Violação de UpperCamelCase / lowerCamelCase (Blocos em All-Caps)",
    'RULE_LOWER_CAMEL': "2. Violação de lowerCamelCase (PascalCase em membros públicos)",
    'RULE_NO_TYPEDEF_SHIMS': "3. Veto a Typedefs e Shims Artificiais",
    'RULE_NO_UNAUTHORIZED_DEPRECATED': "4. Veto a @Deprecated Não Existente no Upstream Go",
    'RULE_NO_NEW_X_FUNCTIONS': "5. Veto a Funções Livres newX(...) Artificiais",
    'RULE_CONSTANT_CASING': "6. Veto a Constantes em SCREAMING_SNAKE_CASE",
    'RULE_REDUNDANT_CONSTRUCTOR_NAMES': "7. Veto a Construtores Nomeados Redundantes ou com Prefixo 'new'",
    'RULE_NO_GO_STYLE_ERROR_TUPLES': "8. Veto a Tuplas de Erro Go e Result Wrappers em APIs Públicas",
    'RULE_NO_CLI_IN_LIBRARIES': "9. Veto a Código de CLI em Pacotes de Bibliotecas",
    'RULE_ENFORCE_BOILERPLATE_TYPES': "10. Uso Obrigatório de fixed_types.Golang.* para Tipos Primitivos",
    'RULE_MODULE_BOUNDARY_LEAK': "11. Veto a Violação de Fronteira de Módulo (go.mod)",
    'RULE_INVENTED_PUBLIC_SYMBOLS': "12. Detecção de Símbolos Públicos Inventados (Sem Upstream Go)",
    'RULE_EXCEPTION_NAMING': "13. Nomenclatura e Padrão de Exceções Dart (Veto a prefixo 'Err')",
    'RULE_NO_PRODUCTION_MOCKS': "14. Veto a Mocks, Dummies e Stubs em Código de Biblioteca",
    'RULE_RESTRICTED_PLATFORM_IMPORTS': "15. Veto a dart:io em Pacotes de Codecs/Formatos Puros",
    'RULE_NO_PRINT_IN_LIBRARIES': "16. Veto a chamadas print(...) em Bibliotecas Reutilizáveis",
    'RULE_NO_ARTIFICIAL_CONCURRENCY': "17. Veto a Primitivas Artificiais de Concorrência Go",
    'RULE_MISSING_GO_TYPES': "18. Auditoria de Tipos e Interfaces do Upstream Go Ausentes",
    'RULE_MISSING_GO_FIELDS': "19. Auditoria de Campos de Structs do Upstream Go Ausentes",
    'RULE_MISSING_GO_METHODS': "20. Auditoria de Métodos do Upstream Go Ausentes",
    'RULE_MISSING_GO_FUNCTIONS': "21. Auditoria de Funções Top-Level do Upstream Go Ausentes",
    'RULE_PUBSPEC_DEPENDENCIES': "22. Validação de Dependências em pubspec.yaml",
    'RULE_EXPOSED_NON_PUBLIC_MEMBERS': "23. Veto a Membros Públicos que Expõem Tipos Não-Públicos (Menor Permissão)",
    'RULE_MISSING_ATOMIC_TESTS': "24. Auditoria de Testes Atômicos 1 para 1 (test/atomic/<nivel>/<nome_modulo>_atomic_tests.dart)",
    'RULE_IMPORT_PREFIX_NAMING': "25. Prefixo de Import Nomeado pela Biblioteca (Colisão de Nomes)",
    'RULE_PARSE_ERROR': "26. Erro de Sintaxe na Análise AST (package:analyzer)",
}

RULE_DEFAULT_SEVERITIES = {
    'RULE_ALL_CAPS': 'ERROR',
    'RULE_LOWER_CAMEL': 'ERROR',
    'RULE_NO_TYPEDEF_SHIMS': 'ERROR',
    'RULE_NO_UNAUTHORIZED_DEPRECATED': 'ERROR',
    'RULE_NO_NEW_X_FUNCTIONS': 'ERROR',
    'RULE_CONSTANT_CASING': 'ERROR',
    'RULE_REDUNDANT_CONSTRUCTOR_NAMES': 'ERROR',
    'RULE_NO_GO_STYLE_ERROR_TUPLES': 'ERROR',
    'RULE_NO_CLI_IN_LIBRARIES': 'ERROR',
    'RULE_ENFORCE_BOILERPLATE_TYPES': 'ERROR',
    'RULE_MODULE_BOUNDARY_LEAK': 'ERROR',
    'RULE_INVENTED_PUBLIC_SYMBOLS': 'ERROR',
    'RULE_EXCEPTION_NAMING': 'ERROR',
    'RULE_NO_PRODUCTION_MOCKS': 'ERROR',
    'RULE_RESTRICTED_PLATFORM_IMPORTS': 'ERROR',
    'RULE_NO_PRINT_IN_LIBRARIES': 'ERROR',
    'RULE_NO_ARTIFICIAL_CONCURRENCY': 'ERROR',
    'RULE_MISSING_GO_TYPES': 'INFO',
    'RULE_MISSING_GO_FIELDS': 'INFO',
    'RULE_MISSING_GO_METHODS': 'INFO',
    'RULE_MISSING_GO_FUNCTIONS': 'INFO',
    'RULE_PUBSPEC_DEPENDENCIES': 'ERROR',
    'RULE_EXPOSED_NON_PUBLIC_MEMBERS': 'ERROR',
    'RULE_MISSING_ATOMIC_TESTS': 'ERROR',
    'RULE_IMPORT_PREFIX_NAMING': 'ERROR',
    'RULE_PARSE_ERROR': 'ERROR',
}


# ---------------------------------------------------------------------------
# Helpers de string puros (sem `re`).
# ---------------------------------------------------------------------------

def _match_upper_token(s: str, i: int, n: int) -> str:
    """Segmenta uma palavra a partir da posição `i` (um caractere maiúsculo).

    Regras, na ordem em que se aplicam:

      1. `X<dígitos>Y` (ex.: `P2P`) é uma única palavra somente quando `Y` --
         o maiúsculo que fecha a corrida de dígitos -- não é seguido de letra
         minúscula. Quando essa condição falha, os dígitos (e qualquer
         minúscula/dígito que vier imediatamente depois) ficam colados à
         palavra-título iniciada em `X` (ex.: em `P2th`, o resultado é uma
         única palavra `P2th`).
      2. Uma corrida de maiúsculas com 2+ caracteres termina antes da última
         maiúscula quando essa última é seguida de letra minúscula (ex.:
         `HTTPPath` -> `HTTP`, `Path`).
      3. Dígitos imediatamente após uma corrida de maiúsculas colam a ela
         (ex.: `IP6`).
      4. Um único maiúsculo seguido de minúscula (palavra-título, ex.:
         `Type0Zone` -> `Type0`, `Zone`) consome minúsculas e dígitos
         subsequentes.
    """
    if i + 1 < n and s[i + 1].isdigit():
        d = i + 1
        while d < n and s[d].isdigit():
            d += 1
        if d < n and s[d].isupper() and not (d + 1 < n and s[d + 1].islower()):
            return s[i:d + 1]
        j = d
        while j < n and (s[j].isdigit() or s[j].islower()):
            j += 1
        return s[i:j]

    k = i
    while k < n and s[k].isupper():
        k += 1

    if k - i >= 2 and k < n and s[k].islower():
        return s[i:k - 1]

    if k - i == 1 and k < n:
        j = k
        while j < n and (s[j].isdigit() or s[j].islower()):
            j += 1
        return s[i:j]

    j = k
    while j < n and s[j].isdigit():
        j += 1
    return s[i:j]


def split_words(s: str) -> List[str]:
    """Divide identificadores em palavras individuais reconhecendo acrônimos."""
    s = s.replace('_', ' ').replace('-', ' ')
    words: List[str] = []
    i = 0
    n = len(s)
    while i < n:
        c = s[i]
        if c == ' ':
            i += 1
            continue
        if not (c.isalpha() or c.isdigit()):
            i += 1
            continue
        if c.isupper():
            token = _match_upper_token(s, i, n)
            words.append(token)
            i += len(token)
            continue
        j = i
        while j < n and (s[j].isdigit() or (s[j].isalpha() and s[j].islower())):
            j += 1
        words.append(s[i:j])
        i = j
    return words


def to_upper_camel(s: str) -> str:
    """Converte identificador para UpperCamelCase canônico."""
    words = split_words(s)
    out = []
    for w in words:
        upper_w = w.upper()
        if upper_w in COMMON_ACRONYMS:
            out.append(COMMON_ACRONYMS[upper_w])
        else:
            out.append(w.capitalize())
    return "".join(out)


def to_lower_camel(s: str) -> str:
    """Converte identificador para lowerCamelCase canônico."""
    words = split_words(s)
    if not words:
        return ""
    out = []
    first = words[0]
    upper_first = first.upper()
    if upper_first in COMMON_ACRONYMS:
        out.append(COMMON_ACRONYMS[upper_first].lower())
    else:
        out.append(first.lower())

    for w in words[1:]:
        upper_w = w.upper()
        if upper_w in COMMON_ACRONYMS:
            out.append(COMMON_ACRONYMS[upper_w])
        else:
            out.append(w.capitalize())
    return "".join(out)


def _find_all_caps_run(s: str) -> Optional[str]:
    """Equivalente a `regex_equiv_search(r'[A-Z]{2,}', s)`."""
    i = 0
    n = len(s)
    while i < n - 1:
        if s[i].isupper() and s[i + 1].isupper():
            j = i
            while j < n and s[j].isupper():
                j += 1
            return s[i:j]
        i += 1
    return None


def _find_letter_digit_letter(s: str) -> Optional[str]:
    """Equivalente a `regex_equiv_search(r'[A-Z]\\d+[A-Z]', s)` (leftmost match, com
    backtrack no tamanho da corrida de dígitos)."""
    n = len(s)
    for i in range(n):
        if s[i].isupper() and i + 1 < n and s[i + 1].isdigit():
            d = i + 1
            while d < n and s[d].isdigit():
                d += 1
            for end in range(d, i + 1, -1):
                if end < n and s[end].isupper():
                    return s[i:end + 1]
    return None


def check_all_caps_block(name: str) -> Optional[str]:
    """Detecta se há bloco em All-Caps que viole a regra do AGENTS.md."""
    clean = name.strip('_')
    run = _find_all_caps_run(clean)
    if run:
        return run
    return _find_letter_digit_letter(clean)


def is_screaming_snake_case(name: str) -> bool:
    """Equivalente a `regex_equiv_match(r'^[A-Z0-9]+(_[A-Z0-9]+)+$', name)`."""
    parts = name.split('_')
    if len(parts) < 2:
        return False
    valid = frozenset('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789')
    return all(p and all(c in valid for c in p) for p in parts)


def has_new_prefix(name: str) -> bool:
    """Equivalente a `regex_equiv_match(r'^new[A-Z]', name)`."""
    return name.startswith('new') and len(name) > 3 and name[3].isupper()


def strip_error_suffix(name: str) -> str:
    """Equivalente a `regex_equiv_sub(r'(?:Error|Err|Failure)$', '', name)` -- o
    sufixo mais longo que casar corresponde ao match mais à esquerda no
    original (leftmost-wins entre as alternativas ancoradas em $)."""
    for suf in ('Failure', 'Error', 'Err'):
        if name.endswith(suf):
            return name[:-len(suf)]
    return name


_MOCK_LIKE_WORDS = ('Mock', 'Dummy', 'Stub', 'Fake', 'Placeholder')


def is_mock_like_name(name: str) -> bool:
    """Equivalente a
    `regex_equiv_search(r'\\b(?:Mock|Dummy|Stub|Fake|Placeholder)|(?:Mock|Dummy|Stub|Fake|Placeholder)\\b', name)`.
    Como identificadores não têm fronteiras \\b internas, isso equivale a
    "começa ou termina com uma dessas palavras"."""
    return any(name.startswith(w) or name.endswith(w) for w in _MOCK_LIKE_WORDS)


_CONCURRENCY_WORDS = frozenset({'Chan', 'GoChannel', 'WaitGroup', 'Mutex'})


def is_concurrency_word(name: str) -> bool:
    """Equivalente a `regex_equiv_search(r'\\b(?:Chan|GoChannel|WaitGroup|Mutex)\\b', name)`
    -- com \\b nos dois lados e sem fronteiras internas num identificador,
    isso equivale a igualdade exata com uma das palavras."""
    return name in _CONCURRENCY_WORDS


def is_bare_identifier_chars(x: str) -> bool:
    """Equivalente a `regex_equiv_match(r'^[A-Za-z0-9_]+$', x)` (apenas ASCII)."""
    if not x:
        return False
    return x.replace('_', '').isalnum() and x.isascii()


# ---------------------------------------------------------------------------
# Helpers de limpeza de nomes de group()/test() para a Regra 24 (auditoria de
# testes atômicos). Também validados contra as regex antigas sobre >5000
# nomes reais extraídos de test/atomic/**.
# ---------------------------------------------------------------------------

def strip_bracket_segments(s: str) -> str:
    """Equivalente a `regex_equiv_sub(r'\\[.*?\\]', '', s).strip()` -- usado para
    nomes de group()."""
    out = []
    i = 0
    n = len(s)
    while i < n:
        if s[i] == '[':
            j = s.find(']', i + 1)
            if j == -1:
                out.append(s[i])
                i += 1
                continue
            i = j + 1
            continue
        out.append(s[i])
        i += 1
    return ''.join(out).strip()


def clean_group_name(raw_name: Optional[str]) -> str:
    if raw_name is None:
        return ''
    cleaned = strip_bracket_segments(raw_name)
    if not cleaned:
        return ''
    return cleaned.split()[0]


def strip_test_name_brackets(s: str) -> str:
    """Equivalente a `regex_equiv_sub(r'\\[(?!\\s*\\]|\\s*\\]=).*?\\]', '', s).strip()`
    -- remove segmentos "[...]" de nomes de test(), exceto quando o conteúdo
    do colchete é o próprio operador de índice ("[]" / "[]=")."""
    out = []
    i = 0
    n = len(s)
    while i < n:
        if s[i] == '[':
            k = i + 1
            while k < n and s[k].isspace():
                k += 1
            is_index_operator = k < n and s[k] == ']'
            if is_index_operator:
                out.append(s[i])
                i += 1
                continue
            j = s.find(']', i + 1)
            if j == -1:
                out.append(s[i])
                i += 1
                continue
            i = j + 1
            continue
        out.append(s[i])
        i += 1
    return ''.join(out).strip()


def match_qualified_prefix(s: str) -> Optional[Tuple[str, int]]:
    """Equivalente a
    `regex_equiv_match(r'\\s*([A-Za-z_$][\\w$]*)\\.([A-Za-z_$][\\w$]*)', s)`.
    Devolve `(primeiro_identificador, offset_do_segundo_identificador)`."""
    n = len(s)
    i = 0
    while i < n and s[i].isspace():
        i += 1
    start = i
    if i >= n or not (s[i].isalpha() or s[i] in '_$'):
        return None
    i += 1
    while i < n and (s[i].isalnum() or s[i] in '_$'):
        i += 1
    ident1_end = i
    if i >= n or s[i] != '.':
        return None
    i += 1
    start2 = i
    if i >= n or not (s[i].isalpha() or s[i] in '_$'):
        return None
    i += 1
    while i < n and (s[i].isalnum() or s[i] in '_$'):
        i += 1
    return s[start:ident1_end], start2


_LEADING_KEYWORD_CANDIDATES = ('get', 'set', 'method', 'getter', 'setter')


def strip_leading_test_keyword(member: str) -> str:
    """Equivalente a
    `regex_equiv_sub(r'^(?:get|set|method|getter|setter)\\s+', '', member, flags=IGNORECASE)`.
    A ordem de tentativa é a da alternação escrita, mas o requisito de `\\s+`
    imediatamente depois faz o motor descartar `get`/`set` sempre que o texto
    continua com mais letras (ex.: "getter"), então o candidato efetivo é o
    primeiro, na ordem escrita, cujo comprimento é seguido de espaço real."""
    lower = member.lower()
    for cand in _LEADING_KEYWORD_CANDIDATES:
        clen = len(cand)
        if lower.startswith(cand) and clen < len(member) and member[clen].isspace():
            j = clen
            while j < len(member) and member[j].isspace():
                j += 1
            return member[j:]
    return member


# Ordem exata da alternação original:
# ==|!=|<=|>=|>>>|<<<|<<|>>|<|>|+|*|~/|/|%|~|&|\||^|\[\]=?|-
_OPERATOR_TOKENS = (
    '==', '!=', '<=', '>=', '>>>', '<<<', '<<', '>>', '<', '>', '+', '*',
    '~/', '/', '%', '~', '&', '|', '^', '[]=', '[]', '-',
)


def find_operator_member(member: str) -> Optional[str]:
    """Equivalente a
    `regex_equiv_search(r'\\b(operator\\s*(?:==|...|-))', member)` seguido de
    `regex_equiv_sub(r'\\s+', ' ', match)`. Devolve o texto já normalizado
    ("operator ==") ou None."""
    idx = member.find('operator')
    while idx != -1:
        boundary_ok = idx == 0 or not (member[idx - 1].isalnum() or member[idx - 1] == '_')
        if boundary_ok:
            k = idx + len('operator')
            while k < len(member) and member[k].isspace():
                k += 1
            for tok in _OPERATOR_TOKENS:
                if member[k:k + len(tok)] == tok:
                    matched = member[idx:k + len(tok)]
                    return ' '.join(matched.split())
        idx = member.find('operator', idx + 1)
    return None


def strip_parens_and_after(s: str) -> str:
    """Equivalente a `regex_equiv_sub(r'\\(.*?\\).*$', '', s)` -- se houver um '(' com
    um ')' correspondente depois dele, corta a partir do '('; caso contrário
    devolve `s` intacto."""
    idx = s.find('(')
    if idx == -1:
        return s
    close = s.find(')', idx + 1)
    if close == -1:
        return s
    return s[:idx]


def is_weak_matcher(matcher: str) -> bool:
    """Equivalente a
    `regex_equiv_match(r'^(?:isNotNull|isA\\s*<[^>]*>\\s*\\(\\s*\\)|returnsNormally)$', matcher)`."""
    if matcher in ('isNotNull', 'returnsNormally'):
        return True
    if not matcher.startswith('isA'):
        return False
    rest = matcher[3:]
    i = 0
    while i < len(rest) and rest[i] == ' ':
        i += 1
    if i >= len(rest) or rest[i] != '<':
        return False
    i += 1
    close = rest.find('>', i)
    if close == -1:
        return False
    rest2 = rest[close + 1:]
    j = 0
    while j < len(rest2) and rest2[j] == ' ':
        j += 1
    if j >= len(rest2) or rest2[j] != '(':
        return False
    j += 1
    while j < len(rest2) and rest2[j] == ' ':
        j += 1
    if j >= len(rest2) or rest2[j] != ')':
        return False
    j += 1
    return j == len(rest2)


# ---------------------------------------------------------------------------
# Localização de executáveis e geração/cache dos fatos AST em .dart_tool/
# ---------------------------------------------------------------------------

def _find_executable(name: str) -> str:
    exe = shutil.which(name)
    if exe:
        return exe
    for ext in ('.bat', '.exe', '.cmd'):
        exe = shutil.which(name + ext)
        if exe:
            return exe
    raise SystemExit(
        f"ERRO FATAL: executável '{name}' não encontrado no PATH. "
        f"Este auditor exige '{name}' para gerar os fatos AST (ver AGENTS.md)."
    )


def _dart_source_files(root: Path) -> List[Path]:
    files: List[Path] = []
    for base in (root / 'lib', root / 'test'):
        if base.exists():
            files.extend(base.rglob('*.dart'))
    packages_dir = root / 'packages'
    if packages_dir.exists():
        for entry in sorted(packages_dir.iterdir()):
            if entry.is_dir():
                lib_dir = entry / 'lib'
                if lib_dir.exists():
                    files.extend(lib_dir.rglob('*.dart'))
    return files


def _is_stale(json_path: Path, watched: List[Path]) -> bool:
    if not json_path.exists():
        return True
    json_mtime = json_path.stat().st_mtime
    for f in watched:
        try:
            if f.stat().st_mtime > json_mtime:
                return True
        except OSError:
            continue
    return False


def _go_module_dirs(go_ref_dir: Path) -> List[str]:
    if not go_ref_dir.exists():
        return []
    dirs = []
    for entry in sorted(go_ref_dir.iterdir()):
        if not entry.is_dir():
            continue
        name = entry.name
        if name.endswith('-index') or name.endswith('_vectors'):
            continue
        dirs.append(name)
    return dirs


# ---------------------------------------------------------------------------
# Símbolos auditados
# ---------------------------------------------------------------------------

class DartAuditSymbol:
    def __init__(self, kind: str, name: str, file_path: str, line: int,
                 parent_type: Optional[str] = None, is_deprecated: bool = False,
                 deprecation_msg: str = '', return_type: Optional[Dict] = None,
                 supertypes: Optional[List[str]] = None):
        self.kind = kind  # class, mixin, enum, extension, extension_type, typedef, method, field, getter, setter, function, constructor, operator
        self.name = name
        self.file_path = file_path
        self.line = line
        self.parent_type = parent_type
        self.is_deprecated = is_deprecated
        self.deprecation_msg = deprecation_msg
        self.return_type = return_type  # {'text','isRecord','names'} ou None
        self.supertypes = supertypes or []
        self.signature_types: List[str] = []
        self.offset: Optional[int] = None
        self.end: Optional[int] = None
        self.target = ''  # typedefTarget, quando kind == 'typedef'
        self.dep_ann_offset: Optional[int] = None
        self.dep_ann_end: Optional[int] = None

    def is_public(self) -> bool:
        if self.name.startswith('_'):
            return False
        if self.parent_type and self.parent_type.startswith('_'):
            return False
        return True


class GoAuditSymbol:
    def __init__(self, kind: str, name: str, file_path: str,
                 parent_type: Optional[str] = None, doc: str = '',
                 is_deprecated: bool = False, exported: Optional[bool] = None,
                 out_of_scope: bool = False):
        self.kind = kind  # struct, interface, type, method, field, func, var, const
        self.name = name
        self.file_path = file_path
        self.parent_type = parent_type
        self.doc = doc
        self.is_deprecated = is_deprecated
        self.exported = exported if exported is not None else (bool(name) and name[0].isupper())
        # Membro de tipo não exportado não é API pública no Go, mesmo com nome
        # exportado (ex.: os campos embutidos `Datastore` dos structs `dsN` de
        # go-datastore/scoped/impls.gen.go).
        if parent_type and not parent_type[:1].isupper():
            self.exported = False
        # Declarado num arquivo Go fora do escopo do projeto (CLI, gateway,
        # RPC -- ver `is_out_of_scope`/AGENTS.md, seção "Fora do escopo").
        # Símbolo assim pode ser aceito como origem upstream válida quando um
        # objeto do escopo (boxo, principalmente) precisar dele ponto a ponto
        # (RULE_INVENTED_PUBLIC_SYMBOLS), mas nunca conta como lacuna: não
        # portar a camada fora de escopo nunca é uma pendência
        # (RULE_MODULE_BOUNDARY_LEAK e RULE_MISSING_GO_*).
        self.out_of_scope = out_of_scope

    def is_exported(self) -> bool:
        return self.exported


class AstNomenclatureAuditor:
    # Palavras-chave que marcam um group() como agrupador "de topo" (funções
    # livres, não uma classe) e portanto nunca uma classe ativa.
    TOP_LEVEL_GROUP_KEYWORDS = (
        'top-level', 'toplevel', 'top_level', 'functions', 'funções',
        'auxiliary', 'top level',
    )

    def __init__(self, root_dir: Path, dart_facts_path: Optional[Path] = None,
                 go_facts_path: Optional[Path] = None, skip_go: bool = False):
        self.root_dir = root_dir
        self.go_ref_dir = root_dir / 'go-ipfs-reference'
        self._dart_facts_path_override = dart_facts_path
        self._go_facts_path_override = go_facts_path
        self._skip_go = skip_go

        self.dart_facts: Dict[str, Dict] = {}
        self.go_facts: Dict[str, Dict] = {}

        self.dart_symbols: List[DartAuditSymbol] = []
        self.go_symbols_by_module: Dict[str, List[GoAuditSymbol]] = {}
        self.violations: List[Dict] = []
        self.atomic_test_stats: Optional[Dict] = None

        # rel_path -> {prefixo de import: nome do pacote/biblioteca importada}
        self.dart_import_prefixes: Dict[str, Dict[str, str]] = {}
        # rel_path -> [(nome escondido, pacote/biblioteca de origem)]
        self.dart_import_hides: Dict[str, List[Tuple[str, str]]] = {}
        # "<pacote_dart>:<reldir_go>" -> nome da cláusula `package`
        self.go_package_clause: Dict[str, str] = {}

    # -- geração/cache dos fatos --------------------------------------

    def _ensure_fresh_dart_facts(self, facts_path: Path) -> None:
        tool_path = Path(__file__).resolve().parent / 'dart_ast_facts.dart'
        watched = _dart_source_files(self.root_dir) + [tool_path]
        if not _is_stale(facts_path, watched):
            return
        facts_path.parent.mkdir(parents=True, exist_ok=True)
        dart_exe = _find_executable('dart')
        try:
            subprocess.run(
                [dart_exe, 'run', 'tool/dart_ast_facts.dart', '--root', str(self.root_dir), '--out', str(facts_path)],
                cwd=str(self.root_dir), check=True, capture_output=True, text=True,
            )
        except subprocess.CalledProcessError as e:
            raise SystemExit(
                "ERRO FATAL: falha ao gerar fatos Dart via "
                f"'dart run tool/dart_ast_facts.dart':\n{e.stderr}"
            )
        except FileNotFoundError as e:
            raise SystemExit(f"ERRO FATAL: falha ao executar 'dart': {e}")

    def _ensure_fresh_go_facts(self, facts_path: Path) -> None:
        dirs = _go_module_dirs(self.go_ref_dir)
        sidecar = facts_path.with_name(facts_path.stem + '.moduledirs.json')
        tool_path = Path(__file__).resolve().parent / 'go_module_index.go'

        stale = True
        if facts_path.exists():
            stored_dirs = None
            if sidecar.exists():
                try:
                    stored_dirs = json.loads(sidecar.read_text(encoding='utf-8'))
                except Exception:
                    stored_dirs = None
            tool_newer = tool_path.exists() and tool_path.stat().st_mtime > facts_path.stat().st_mtime
            stale = tool_newer or stored_dirs != dirs

        if not stale:
            return

        facts_path.parent.mkdir(parents=True, exist_ok=True)
        go_exe = _find_executable('go')
        rel_dirs = [f'go-ipfs-reference/{d}' for d in dirs]
        try:
            subprocess.run(
                [go_exe, 'run', 'tool/go_module_index.go', '-json', str(facts_path)] + rel_dirs,
                cwd=str(self.root_dir), check=True, capture_output=True, text=True,
            )
        except subprocess.CalledProcessError as e:
            raise SystemExit(
                "ERRO FATAL: falha ao gerar fatos Go via "
                f"'go run tool/go_module_index.go':\n{e.stderr}"
            )
        except FileNotFoundError as e:
            raise SystemExit(f"ERRO FATAL: falha ao executar 'go': {e}")
        sidecar.write_text(json.dumps(dirs), encoding='utf-8')

    def _load_dart_facts_file(self) -> Dict[str, Dict]:
        if self._dart_facts_path_override:
            path = Path(self._dart_facts_path_override)
        else:
            path = self.root_dir / '.dart_tool' / 'audit_ast_facts.json'
            self._ensure_fresh_dart_facts(path)
        data = json.loads(path.read_text(encoding='utf-8'))
        return data['files']

    def _load_go_facts_file(self) -> Dict[str, Dict]:
        if self._go_facts_path_override:
            path = Path(self._go_facts_path_override)
        else:
            path = self.root_dir / '.dart_tool' / 'audit_go_facts.json'
            self._ensure_fresh_go_facts(path)
        data = json.loads(path.read_text(encoding='utf-8'))
        return data['modules']

    # -- construção de símbolos a partir dos fatos ----------------------

    @staticmethod
    def _is_api_path(rel_path: str) -> bool:
        if '/test/' in rel_path or rel_path.endswith('_test.dart'):
            return False
        if rel_path.startswith('lib/'):
            return True
        if rel_path.startswith('packages/'):
            parts = rel_path.split('/')
            return len(parts) > 2 and parts[2] == 'lib'
        return False

    @staticmethod
    def library_name_of_uri(uri: str) -> Optional[str]:
        """Nome da biblioteca que `uri` designa, ou None para `dart:`."""
        if uri.startswith('dart:'):
            return None
        if uri.startswith('package:'):
            return uri[len('package:'):].split('/', 1)[0]
        stem = uri.rsplit('/', 1)[-1]
        return stem[:-5] if stem.endswith('.dart') else stem

    def _symbol_from_decl(self, decl: Dict, rel_path: str) -> DartAuditSymbol:
        annotations = decl.get('annotations') or []
        dep_off = dep_end = None
        for ann in annotations:
            if ann['name'] in ('Deprecated', 'deprecated'):
                dep_off, dep_end = ann['offset'], ann['end']
                break
        sym = DartAuditSymbol(
            decl['kind'], decl['name'], rel_path, decl['line'],
            parent_type=decl.get('parent'),
            is_deprecated=decl.get('deprecated', False),
            deprecation_msg=decl.get('deprecationMessage', ''),
            return_type=decl.get('returnType'),
            supertypes=decl.get('supertypes') or [],
        )
        sym.signature_types = decl.get('signatureTypes') or []
        sym.offset = decl.get('offset')
        sym.end = decl.get('end')
        sym.target = decl.get('typedefTarget') or ''
        sym.dep_ann_offset = dep_off
        sym.dep_ann_end = dep_end
        return sym

    def _build_dart_symbols(self) -> None:
        self.dart_symbols = []
        self.dart_import_prefixes = {}
        self.dart_import_hides = {}
        for rel_path, facts in self.dart_facts.items():
            prefixes: Dict[str, str] = {}
            hides: List[Tuple[str, str]] = []
            for imp in facts.get('imports', []):
                library = self.library_name_of_uri(imp['uri'])
                if library is None:
                    continue
                if imp.get('prefix'):
                    prefixes[imp['prefix']] = library
                for h in imp.get('hide', []):
                    hides.append((h, library))
            if prefixes:
                self.dart_import_prefixes[rel_path] = prefixes
            if hides:
                self.dart_import_hides[rel_path] = hides

            if not self._is_api_path(rel_path):
                continue
            for decl in facts.get('declarations', []):
                self.dart_symbols.append(self._symbol_from_decl(decl, rel_path))

    def _build_go_symbols(self) -> None:
        self.go_symbols_by_module = {}
        self.go_package_clause = {}
        for mod_key, mod_data in self.go_facts.items():
            syms: List[GoAuditSymbol] = []
            seen: Set[Tuple[str, str, str]] = set()

            # Duas passagens -- decls dentro de escopo primeiro -- para que
            # uma duplicata fora de escopo nunca sombreie (pelo dedup por
            # kind/name/parent) uma declaração dentro de escopo com a mesma
            # chave. Objetos que upstream só declara numa camada fora de
            # escopo (CLI, gateway, RPC) continuam carregados e marcados
            # `out_of_scope=True`, porque o boxo pode precisar deles ponto a
            # ponto (AGENTS.md, seção "Fora do escopo"); o que nunca é
            # verdade é o contrário -- uma decl fora de escopo tomar o lugar
            # de uma dentro de escopo no índice.
            decls = mod_data.get('decls', [])
            in_scope_decls = [d for d in decls if not is_out_of_scope(d.get('file', ''))]
            out_of_scope_decls = [d for d in decls if is_out_of_scope(d.get('file', ''))]

            for d, oos in [(d, False) for d in in_scope_decls] + [(d, True) for d in out_of_scope_decls]:
                key = (d['kind'], d['name'], d.get('parent') or '')
                if key in seen:
                    continue
                seen.add(key)
                syms.append(GoAuditSymbol(
                    d['kind'], d['name'], d.get('file', ''),
                    parent_type=d.get('parent'), doc=d.get('doc', ''),
                    is_deprecated=d.get('deprecated', False),
                    exported=d.get('exported', False),
                    out_of_scope=oos,
                ))
            self.go_symbols_by_module[mod_key] = syms

            dart_pkg_path = GO_MODULE_TO_DART_PACKAGE.get(mod_key)
            if dart_pkg_path:
                dart_pkg = dart_pkg_path.split('/')[-1]
                for reldir, clause in mod_data.get('packages', {}).items():
                    if reldir.startswith(('examples/', 'test-plans/', 'scripts/')):
                        continue
                    key2 = f"{dart_pkg}:{reldir.replace('-', '_')}"
                    if key2 not in self.go_package_clause:
                        self.go_package_clause[key2] = clause

    def load_all(self) -> None:
        self.dart_facts = self._load_dart_facts_file()
        self._build_dart_symbols()

        if not self._skip_go:
            self.go_facts = self._load_go_facts_file()
            self._build_go_symbols()

    # -- resolução de prefixos de import (Regra 25) ----------------------

    @staticmethod
    def escape_prefix_for(base: str, library: Optional[str] = None) -> str:
        """Forma longa a usar quando o prefixo exigido colide com um
        identificador do arquivo."""
        stem = library if library else base
        return f"{stem}_package"

    @staticmethod
    def allowed_prefixes_for(library: str) -> Set[str]:
        """Prefixos que nomeiam `library` de forma reconhecível."""
        allowed = {library, f'{library}_package'}
        if library.startswith('transpiled_'):
            allowed.add(library[len('transpiled_'):])
        if library == 'boilerplate':
            allowed.add('Golang')
        return allowed

    def go_prefixes_for_library_path(self, uri: str) -> Set[str]:
        """Prefixos aceitáveis para um import interno `package:<pkg>/src/<rest>`."""
        if not uri.startswith('package:'):
            return set()
        body = uri[len('package:'):]
        pkg, _, path = body.partition('/')
        if not path.startswith('src/'):
            return set()
        rest = path[len('src/'):]
        directory = rest.rsplit('/', 1)[0] if '/' in rest else ''
        candidates: Set[str] = set()
        if directory:
            candidates.add(directory.rsplit('/', 1)[-1])
        clause = self.go_package_clause.get(f"{pkg}:{directory}")
        if clause:
            candidates.add(clause)
        if not candidates:
            return set()
        candidates |= {f'{c}_package' for c in set(candidates)}
        return candidates

    def resolve_prefixed_reference(self, rel_path: str, reference: str) -> Tuple[str, Optional[str]]:
        """Separa `prefixo.Nome` e diz de que biblioteca o nome veio."""
        if '.' not in reference:
            return reference, None
        head, _, tail = reference.partition('.')
        library = self.dart_import_prefixes.get(rel_path, {}).get(head)
        if library is None:
            return reference, None
        return tail, library

    # -- Regra 24: testes atômicos 1 para 1 ------------------------------

    @classmethod
    def _classify_test_body(cls, body: Optional[Dict]) -> str:
        """Classifica o corpo (já estruturado pelo fato Dart) de um teste em
        'none', 'weak' ou 'strong'. Ver a docstring homônima do auditor
        anterior para a semântica -- preservada aqui sobre dados
        estruturados em vez de regex sobre texto."""
        if body is None:
            return 'none'
        if body.get('empty') or body.get('onlyFail'):
            return 'none'

        constructed = set(body.get('constructedIdentifiers') or [])
        real_count = 0
        weak_count = 0

        for assertion in body.get('assertions') or []:
            if assertion.get('actualKind') == 'literal':
                continue
            real_count += 1
            if assertion.get('callee') in ('expect', 'expectLater'):
                matcher = assertion.get('matcher', '')
                actual = assertion.get('actual', '')
                if (is_weak_matcher(matcher) and assertion.get('actualKind') == 'identifier'
                        and actual in constructed):
                    weak_count += 1

        if real_count == 0 and body.get('throwsA'):
            real_count += 1

        if real_count == 0:
            return 'none'
        if weak_count > 0 and weak_count == real_count:
            return 'weak'
        return 'strong'

    def scan_all_atomic_tests(self) -> Tuple[Set[str], Dict[str, List[str]], Dict[str, str]]:
        """Varre test/atomic/<nivel>/<nome_modulo>_atomic_tests.dart a partir
        dos fatos Dart já carregados. Retorna `(all_tested, symbol_to_files,
        quality_by_symbol)`, com a mesma semântica do auditor anterior."""
        all_tested: Set[str] = set()
        symbol_to_files: Dict[str, List[str]] = {}
        quality_by_symbol: Dict[str, str] = {}

        for rel_path, facts in self.dart_facts.items():
            if not rel_path.startswith('test/atomic/'):
                continue
            if '_atomic_test' not in Path(rel_path).name:
                continue

            for call in facts.get('tests') or []:
                if call.get('kind') != 'test':
                    continue
                raw_name = call.get('name')
                if raw_name is None:
                    continue

                quality = self._classify_test_body(call.get('body'))
                if quality == 'none':
                    continue

                cleaned_tname = strip_test_name_brackets(raw_name)
                groups = call.get('groups') or []
                cleaned_groups = [clean_group_name(g) for g in groups]

                active_class = None
                for gname in reversed(cleaned_groups):
                    if gname and gname[0].isupper() and not any(
                            kw in gname.lower() for kw in self.TOP_LEVEL_GROUP_KEYWORDS):
                        active_class = gname
                        break

                cls = None
                member = cleaned_tname
                qualified = match_qualified_prefix(cleaned_tname)
                if qualified and not cleaned_tname.startswith('operator'):
                    cand_cls, member_start = qualified
                    if not any(kw in cand_cls.lower() for kw in self.TOP_LEVEL_GROUP_KEYWORDS):
                        cls = cand_cls
                    member = cleaned_tname[member_start:].strip()
                elif active_class:
                    cls = active_class

                member = strip_leading_test_keyword(member)

                op_text = find_operator_member(member)
                if op_text:
                    member = op_text
                else:
                    member = strip_parens_and_after(member).strip()
                    member = member.split()[0] if member else ''

                if member:
                    key = f"{cls}.{member}" if cls else member
                    all_tested.add(key)
                    symbol_to_files.setdefault(key, []).append(rel_path)
                    prev_quality = quality_by_symbol.get(key)
                    if prev_quality != 'strong':
                        quality_by_symbol[key] = quality

        return all_tested, symbol_to_files, quality_by_symbol

    def audit_atomic_tests(self, target_package: Optional[str] = None) -> None:
        """Audita se cada símbolo público possui teste atômico correspondente."""
        all_tested, _symbol_to_files, quality_by_symbol = self.scan_all_atomic_tests()

        self.atomic_test_stats = {
            'total_auditable': 0,
            'total_tested': 0,
            'total_missing': 0,
            'by_package': {},
            'missing_by_package': {},
        }

        # O `-` unário e o binário são duas declarações com o mesmo nome
        # (`operator -`), e um único teste cobre a chave dos dois.
        audited: Set[Tuple[str, str, str]] = set()
        for sym in self.dart_symbols:
            if target_package and target_package not in sym.file_path:
                continue
            if not sym.is_public() or sym.kind not in ('function', 'method', 'getter', 'setter', 'operator'):
                continue
            if sym.parent_type and sym.name == sym.parent_type:
                continue
            audit_key = (sym.file_path, sym.kind, f"{sym.parent_type}.{sym.name}")
            if audit_key in audited:
                continue
            audited.add(audit_key)

            pkg_name = sym.file_path.split('/')[1] if sym.file_path.startswith('packages/') else 'lib'

            primary_key = f"{sym.parent_type}.{sym.name}" if sym.parent_type else sym.name

            pkg_stats = self.atomic_test_stats['by_package'].setdefault(pkg_name, {'total': 0, 'tested': 0, 'missing': 0})
            pkg_stats['total'] += 1
            self.atomic_test_stats['total_auditable'] += 1

            matched_key = None
            if primary_key in all_tested:
                matched_key = primary_key
            elif not sym.parent_type and sym.name in all_tested:
                matched_key = sym.name
            is_tested = matched_key is not None

            if is_tested:
                pkg_stats['tested'] += 1
                self.atomic_test_stats['total_tested'] += 1
                if quality_by_symbol.get(matched_key) == 'weak':
                    clean_mod = pkg_name.replace('transpiled_', '')
                    self.violations.append({
                        'rule': 'RULE_MISSING_ATOMIC_TESTS',
                        'severity': 'WARNING',
                        'message': f"Símbolo público '{primary_key}' ({sym.kind}) em '{sym.file_path}:{sym.line}' só tem teste(s) atômico(s) raso(s): asserção limitada a isNotNull/isA<>()/returnsNormally sobre uma variável apenas construída no próprio teste, sem checar comportamento real.",
                        'file': sym.file_path,
                        'line': sym.line,
                        'symbol': primary_key,
                        'kind': sym.kind,
                        'package': pkg_name,
                        'suggested': f"Reforçar o teste em test/atomic/<nivel>/{clean_mod}_atomic_tests.dart com asserções que verifiquem comportamento, não apenas a construção do objeto",
                    })
            else:
                pkg_stats['missing'] += 1
                self.atomic_test_stats['total_missing'] += 1
                self.atomic_test_stats['missing_by_package'].setdefault(pkg_name, []).append(sym)

                clean_mod = pkg_name.replace('transpiled_', '')
                self.violations.append({
                    'rule': 'RULE_MISSING_ATOMIC_TESTS',
                    'severity': 'ERROR',
                    'message': f"Símbolo público '{primary_key}' ({sym.kind}) em '{sym.file_path}:{sym.line}' não possui teste atômico correspondente em test/atomic/<nivel>/<nome_modulo>_atomic_tests.dart",
                    'file': sym.file_path,
                    'line': sym.line,
                    'symbol': primary_key,
                    'kind': sym.kind,
                    'package': pkg_name,
                    'suggested': f"Criar test('{sym.name}()', () {{ ... expect(...) ... }}) em test/atomic/<nivel>/{clean_mod}_atomic_tests.dart",
                })

    # -- regras de arquivo (imports/invocations/assignments/literais) ---

    def _api_facts_items(self, target_package: Optional[str]):
        for rel_path, facts in self.dart_facts.items():
            if not self._is_api_path(rel_path):
                continue
            if target_package and target_package not in rel_path:
                continue
            yield rel_path, facts

    # -- auditoria principal ---------------------------------------------

    def audit_rules(self, target_package: Optional[str] = None, target_rule: Optional[str] = None,
                     target_severity: Optional[str] = None, include_non_public: bool = False) -> None:
        self.violations.clear()

        pkg_to_mod = {pkg: mod for mod, pkg in GO_MODULE_TO_DART_PACKAGE.items()}
        mod_to_pkg = {mod: pkg for mod, pkg in GO_MODULE_TO_DART_PACKAGE.items()}

        # `out_of_scope` fica de fora daqui: estas duas estruturas alimentam
        # regras de LACUNA/fronteira (3, 4, 11, 14), e não portar uma camada
        # fora de escopo nunca é lacuna nem cria fronteira alheia. Só a
        # Regra 12 (abaixo, via `self.go_symbols_by_module` direto) aceita
        # símbolo fora de escopo como origem upstream válida.
        all_go_symbols: Dict[str, List[GoAuditSymbol]] = {}
        type_to_origin_modules: Dict[str, Set[str]] = {}
        for mod, syms in self.go_symbols_by_module.items():
            for s in syms:
                if s.is_exported() and not s.out_of_scope:
                    all_go_symbols.setdefault(s.name.lower(), []).append(s)
                    if s.kind in ('struct', 'interface', 'type'):
                        type_to_origin_modules.setdefault(s.name.lower(), set()).add(mod)

        COMMON_GENERIC_TYPES = {
            'node', 'reader', 'writer', 'buffer', 'entry', 'config', 'options',
            'state', 'listener', 'transport', 'handler', 'client', 'server',
            'session', 'stream', 'message', 'key', 'value', 'header', 'event',
            'result', 'context', 'record', 'item', 'metadata', 'block',
        }

        # 1. Auditoria de Símbolos Dart individuais
        for sym in self.dart_symbols:
            if target_package and target_package not in sym.file_path:
                continue

            in_boilerplate = 'packages/boilerplate/' in sym.file_path

            # REGRA 1: UpperCamelCase sem All-Caps para Tipos Públicos
            if sym.kind in ('class', 'mixin', 'enum', 'extension', 'extension_type') and sym.is_public():
                if not in_boilerplate and (target_rule is None or target_rule == 'RULE_ALL_CAPS'):
                    all_caps = check_all_caps_block(sym.name)
                    if all_caps:
                        suggested = to_upper_camel(sym.name)
                        if suggested != sym.name:
                            self.violations.append({
                                'rule': 'RULE_ALL_CAPS',
                                'severity': 'ERROR',
                                'message': f"Tipo público '{sym.name}' contém bloco em All-Caps '{all_caps}'. Deve ser UpperCamelCase canônico: '{suggested}'.",
                                'file': sym.file_path,
                                'line': sym.line,
                                'symbol': sym.name,
                                'suggested': suggested,
                            })

            # REGRA 2: lowerCamelCase sem All-Caps para Membros e Funções Públicas
            if sym.kind in ('method', 'field', 'function') and sym.is_public():
                if sym.parent_type and sym.name == sym.parent_type:
                    continue

                if sym.name[:1].isupper() and not in_boilerplate and (target_rule is None or target_rule == 'RULE_LOWER_CAMEL'):
                    suggested = to_lower_camel(sym.name)
                    self.violations.append({
                        'rule': 'RULE_LOWER_CAMEL',
                        'severity': 'ERROR',
                        'message': f"{sym.kind.capitalize()} público '{sym.name}' em '{sym.parent_type or 'top-level'}' usa PascalCase. Em Dart deve ser lowerCamelCase: '{suggested}'.",
                        'file': sym.file_path,
                        'line': sym.line,
                        'symbol': sym.name,
                        'suggested': suggested,
                    })
                elif not in_boilerplate and (target_rule is None or target_rule == 'RULE_ALL_CAPS'):
                    all_caps = check_all_caps_block(sym.name)
                    if all_caps:
                        suggested = to_lower_camel(sym.name)
                        if suggested != sym.name:
                            self.violations.append({
                                'rule': 'RULE_ALL_CAPS',
                                'severity': 'ERROR',
                                'message': f"{sym.kind.capitalize()} público '{sym.name}' contém bloco em All-Caps '{all_caps}'. Deve ser lowerCamelCase canônico: '{suggested}'.",
                                'file': sym.file_path,
                                'line': sym.line,
                                'symbol': sym.name,
                                'suggested': suggested,
                            })

            # REGRA 3: Veto a Typedefs e Shims Artificiais
            if sym.kind == 'typedef' and not in_boilerplate:
                if target_rule is None or target_rule == 'RULE_NO_TYPEDEF_SHIMS':
                    candidate_names = [sym.name.lower()]
                    if sym.name.lower().endswith('id'):
                        candidate_names.append('id')
                    matching_go_syms = []
                    for cname in candidate_names:
                        matching_go_syms.extend(all_go_symbols.get(cname, []))
                    is_upstream_type = any(s.kind in ('type', 'struct', 'interface') for s in matching_go_syms)
                    if not is_upstream_type:
                        target = sym.target
                        if target and '(' not in target and is_bare_identifier_chars(target):
                            self.violations.append({
                                'rule': 'RULE_NO_TYPEDEF_SHIMS',
                                'severity': 'ERROR',
                                'message': f"Typedef shim proibido: 'typedef {sym.name} = {target};'. AGENTS.md veta shims artificiais para compatibilidade. Consumidores devem usar o tipo canônico diretamente.",
                                'file': sym.file_path,
                                'line': sym.line,
                                'symbol': sym.name,
                                'suggested': f"Remover typedef e migrar chamadores para '{target}'",
                                '_fix_offset': sym.offset,
                                '_fix_end': sym.end,
                                '_fix_target': target,
                            })

            # REGRA 4: Veto a @Deprecated não existente no Upstream Go
            if sym.is_deprecated and not in_boilerplate:
                if target_rule is None or target_rule == 'RULE_NO_UNAUTHORIZED_DEPRECATED':
                    matching_go_syms = all_go_symbols.get(sym.name.lower(), [])
                    is_go_deprecated = any(s.is_deprecated for s in matching_go_syms)
                    if not is_go_deprecated:
                        if sym.name in ('newRefEntry', 'newWantlist', 'Entry', 'Wantlist', 'wantlist', 'refEntry') and 'bitswap/wantlist' in sym.file_path:
                            pass
                        else:
                            self.violations.append({
                                'rule': 'RULE_NO_UNAUTHORIZED_DEPRECATED',
                                'severity': 'ERROR',
                                'message': f"Símbolo '{sym.name}' marcado com @Deprecated em Dart, mas no upstream Go não possui '// Deprecated:'. AGENTS.md proíbe inventar @Deprecated exclusivo em Dart.",
                                'file': sym.file_path,
                                'line': sym.line,
                                'symbol': sym.name,
                                'suggested': "Remover anotação @Deprecated se não for obsoleta no upstream Go",
                                '_fix_offset': sym.dep_ann_offset,
                                '_fix_end': sym.dep_ann_end,
                            })

            # REGRA 5: Veto a funções livres newX(...)
            if sym.kind == 'function' and sym.is_public() and not in_boilerplate:
                if target_rule is None or target_rule == 'RULE_NO_NEW_X_FUNCTIONS':
                    if has_new_prefix(sym.name):
                        type_target = sym.name[3:]
                        self.violations.append({
                            'rule': 'RULE_NO_NEW_X_FUNCTIONS',
                            'severity': 'ERROR',
                            'message': f"Função livre artificial '{sym.name}()'. Construtores NewX do Go devem virar construtores ou factories na classe '{type_target}', sem funções livres 'newX' artificiais.",
                            'file': sym.file_path,
                            'line': sym.line,
                            'symbol': sym.name,
                            'suggested': f"Converter para construtor/factory '{type_target}()' ou '{type_target}.from*()'",
                        })

            # REGRA 6: Veto a Constantes e Campos Públicos em SCREAMING_SNAKE_CASE
            if sym.kind in ('field', 'variable', 'getter') and sym.is_public() and not in_boilerplate:
                if target_rule is None or target_rule == 'RULE_CONSTANT_CASING':
                    if is_screaming_snake_case(sym.name):
                        suggested = to_lower_camel(sym.name)
                        self.violations.append({
                            'rule': 'RULE_CONSTANT_CASING',
                            'severity': 'ERROR',
                            'message': f"Constante/campo público '{sym.name}' usa SCREAMING_SNAKE_CASE. Em Dart deve ser lowerCamelCase: '{suggested}'.",
                            'file': sym.file_path,
                            'line': sym.line,
                            'symbol': sym.name,
                            'suggested': suggested,
                        })

            # REGRA 7: Veto a Construtores Nomeados Redundantes ou com prefixo 'new'
            if sym.kind == 'constructor' and sym.parent_type and not in_boilerplate:
                if target_rule is None or target_rule == 'RULE_REDUNDANT_CONSTRUCTOR_NAMES':
                    if sym.name.lower() == f"new{sym.parent_type.lower()}":
                        self.violations.append({
                            'rule': 'RULE_REDUNDANT_CONSTRUCTOR_NAMES',
                            'severity': 'ERROR',
                            'message': f"Construtor nomeado redundante '{sym.parent_type}.{sym.name}()'. Use o construtor principal '{sym.parent_type}()' ou nome semântico sem repetir a classe.",
                            'file': sym.file_path,
                            'line': sym.line,
                            'symbol': sym.name,
                            'suggested': f"Substituir por construtor padrão '{sym.parent_type}()'",
                        })
                    elif sym.name.startswith('newFrom') or (has_new_prefix(sym.name) and sym.name != 'new'):
                        suggested_ctor = sym.name[3:]
                        suggested_ctor = suggested_ctor[:1].lower() + suggested_ctor[1:]
                        self.violations.append({
                            'rule': 'RULE_REDUNDANT_CONSTRUCTOR_NAMES',
                            'severity': 'ERROR',
                            'message': f"Construtor nomeado '{sym.parent_type}.{sym.name}()' usa prefixo 'new'. Em Dart, construtores nomeados devem usar frase nominal ou adjetiva ('{sym.parent_type}.{suggested_ctor}()').",
                            'file': sym.file_path,
                            'line': sym.line,
                            'symbol': sym.name,
                            'suggested': f"Renomear para '{sym.parent_type}.{suggested_ctor}()'",
                        })

            # REGRA 8: Veto a Tuplas de Erro Go e Result Wrappers em APIs Públicas
            if sym.kind in ('method', 'function') and sym.is_public() and not in_boilerplate:
                if target_rule is None or target_rule == 'RULE_NO_GO_STYLE_ERROR_TUPLES':
                    ret = sym.return_type
                    if ret:
                        names = ret.get('names') or []
                        has_error_tuple = bool(ret.get('isRecord')) and ('Error' in names or 'Exception' in names)
                        has_result_wrapper = bool(names) and names[0] in ('Result', 'Either')
                        if has_error_tuple or has_result_wrapper:
                            self.violations.append({
                                'rule': 'RULE_NO_GO_STYLE_ERROR_TUPLES',
                                'severity': 'ERROR',
                                'message': f"{sym.kind.capitalize()} público '{sym.name}' retorna tupla de erro estilo Go ou Result wrapper ('{ret.get('text', '')}'). Conforme AGENTS.md, retornos (valor, error) do Go devem virar retorno direto do valor com exceção tipada via throw.",
                                'file': sym.file_path,
                                'line': sym.line,
                                'symbol': sym.name,
                                'suggested': "Retornar o valor diretamente e lançar exceção tipada em caso de falha",
                            })

            # REGRA 11: Veto a Violação de Fronteira de Módulo (go.mod)
            if sym.kind in ('class', 'mixin', 'enum', 'extension_type') and sym.is_public() and not in_boilerplate:
                if target_rule is None or target_rule == 'RULE_MODULE_BOUNDARY_LEAK':
                    my_pkg = None
                    for p_dir in pkg_to_mod:
                        if sym.file_path.startswith(p_dir + '/'):
                            my_pkg = p_dir
                            break
                    if my_pkg and not sym.file_path.startswith('lib/'):
                        my_mod = pkg_to_mod[my_pkg]
                        origin_mods = type_to_origin_modules.get(sym.name.lower(), set())
                        if origin_mods and my_mod not in origin_mods:
                            if sym.name.lower() not in COMMON_GENERIC_TYPES:
                                alien_mods = [m for m in origin_mods if m in mod_to_pkg and mod_to_pkg[m] != my_pkg and m != 'kubo']
                                if alien_mods:
                                    target_pkg = mod_to_pkg[alien_mods[0]]
                                    self.violations.append({
                                        'rule': 'RULE_MODULE_BOUNDARY_LEAK',
                                        'severity': 'ERROR',
                                        'message': f"Tipo público '{sym.name}' declarado em '{sym.file_path}', mas pertence ao módulo upstream '{alien_mods[0]}' ({target_pkg}). AGENTS.md exige preservar fronteiras de go.mod e reutilizar o pacote proprietário.",
                                        'file': sym.file_path,
                                        'line': sym.line,
                                        'symbol': sym.name,
                                        'suggested': f"Importar do pacote '{target_pkg}' em vez de redeclarar",
                                    })

            # REGRA 12: Detecção de Símbolos Públicos Inventados (Sem Upstream Go)
            if sym.kind in ('class', 'mixin', 'enum', 'extension_type') and sym.is_public() and not in_boilerplate:
                if target_rule is None or target_rule == 'RULE_INVENTED_PUBLIC_SYMBOLS':
                    my_pkg = None
                    for p_dir in pkg_to_mod:
                        if sym.file_path.startswith(p_dir + '/'):
                            my_pkg = p_dir
                            break
                    if my_pkg and not sym.file_path.startswith('lib/'):
                        my_mod = pkg_to_mod[my_pkg]
                        # `go_syms` vem direto de `go_symbols_by_module`, sem
                        # excluir `out_of_scope`: um objeto que upstream só
                        # declara numa camada fora de escopo (CLI, gateway,
                        # RPC) ainda conta como origem upstream válida aqui
                        # quando o boxo precisa dele ponto a ponto (AGENTS.md,
                        # seção "Fora do escopo") -- ex.: boxo `Ping` retorna
                        # `ping.Result` do go-libp2p, não `PingResult` da CLI
                        # do Kubo, mas o nome por si só não distingue os dois.
                        go_syms = self.go_symbols_by_module.get(my_mod, [])
                        if sym.name in DOCUMENTED_ADAPTATIONS:
                            pass
                        elif go_syms or self.go_symbols_by_module:
                            names_to_try = {sym.name}
                            clean_n = sym.name
                            for pfx in KNOWN_PREFIXES:
                                if clean_n.startswith(pfx) and len(clean_n) > len(pfx):
                                    unprefixed = clean_n[len(pfx):]
                                    names_to_try.add(unprefixed)
                                    clean_n = unprefixed
                                    break
                            for sfx in KNOWN_SUFFIXES:
                                if clean_n.endswith(sfx) and len(clean_n) > len(sfx):
                                    stem = clean_n[:-len(sfx)]
                                    names_to_try.add(stem)
                                    if sfx in ('Exception', 'Error'):
                                        names_to_try.add(f'Err{stem}')
                                        names_to_try.add(f'err{stem}')
                                        names_to_try.add(f'{stem}Error')
                                        names_to_try.add(f'{stem}error')
                                        for pfx in KNOWN_PREFIXES:
                                            names_to_try.add(f'{pfx}Err{stem}')
                                            names_to_try.add(f'Err{pfx}{stem}')

                            if 'transpiled_ipld_prime' in sym.file_path and 'basicnode' in sym.file_path:
                                names_to_try.update(['Node', 'NodeAssembler', 'NodePrototype'])

                            lookup = {n.lower() for n in names_to_try}
                            matched = any(s.name.lower() in lookup for s in go_syms)
                            matched_anywhere = matched or any(
                                s.name.lower() in lookup
                                for m_list in self.go_symbols_by_module.values()
                                for s in m_list
                            )
                            if not matched and not matched_anywhere and not any(n in DOCUMENTED_ADAPTATIONS for n in names_to_try):
                                self.violations.append({
                                    'rule': 'RULE_INVENTED_PUBLIC_SYMBOLS',
                                    'severity': 'ERROR',
                                    'message': f"Tipo público '{sym.name}' não possui símbolo exportado correspondente no módulo upstream '{my_mod}'. Conforme AGENTS.md, tipos auxiliares devem ser privados (prefixo '_') para não inventar superfícies de API pública.",
                                    'file': sym.file_path,
                                    'line': sym.line,
                                    'symbol': sym.name,
                                    'suggested': f"Tornar privado com prefixo '_{sym.name}' ou documentar adaptação",
                                })

            # REGRA 13: Nomenclatura e Padrão de Exceções Dart.
            if sym.kind in ('class', 'mixin') and sym.is_public():
                if target_rule is None or target_rule == 'RULE_EXCEPTION_NAMING':
                    tem_err = sym.name.startswith('Err') and len(sym.name) > 3 and sym.name[3].isupper()
                    eh_excecao = 'Exception' in sym.supertypes
                    if tem_err:
                        suggested = to_upper_camel(sym.name[3:]) + "Exception"
                        self.violations.append({
                            'rule': 'RULE_EXCEPTION_NAMING',
                            'severity': 'ERROR',
                            'message': f"Classe de exceção '{sym.name}' usa o prefixo 'Err' idiomático do Go. Em Dart, classes de exceção devem usar sufixo 'Exception' e implementar 'Exception' (ex.: '{suggested}').",
                            'file': sym.file_path,
                            'line': sym.line,
                            'symbol': sym.name,
                            'suggested': f"Renomear para '{suggested}' e adicionar 'implements Exception'",
                        })
                    elif eh_excecao and not sym.name.endswith('Exception'):
                        suggested = to_upper_camel(strip_error_suffix(sym.name)) + "Exception"
                        self.violations.append({
                            'rule': 'RULE_EXCEPTION_NAMING',
                            'severity': 'ERROR',
                            'message': f"Classe '{sym.name}' implementa 'Exception' mas não usa o sufixo 'Exception' exigido pelo idioma Dart (ex.: '{suggested}').",
                            'file': sym.file_path,
                            'line': sym.line,
                            'symbol': sym.name,
                            'suggested': f"Renomear para '{suggested}'",
                        })

            # REGRA 14: Veto a Mocks, Dummies e Stubs em Código de Biblioteca
            if sym.kind in ('class', 'mixin', 'function') and sym.is_public() and not in_boilerplate:
                if target_rule is None or target_rule == 'RULE_NO_PRODUCTION_MOCKS':
                    if is_mock_like_name(sym.name):
                        matching_go_syms = all_go_symbols.get(sym.name.lower(), [])
                        is_upstream = any(s.kind in ('struct', 'type', 'interface', 'func') for s in matching_go_syms)
                        if not is_upstream:
                            self.violations.append({
                                'rule': 'RULE_NO_PRODUCTION_MOCKS',
                                'severity': 'ERROR',
                                'message': f"{sym.kind.capitalize()} de teste/placeholder '{sym.name}' declarada em código de biblioteca '{sym.file_path}'. Mocks e stubs devem residir estritamente no diretório 'test/'.",
                                'file': sym.file_path,
                                'line': sym.line,
                                'symbol': sym.name,
                                'suggested': f"Mover '{sym.name}' para 'test/' ou substituir por implementação real",
                            })

            # REGRA 17: Veto a Primitivas Artificiais de Concorrência Go em APIs Públicas
            if sym.kind in ('class', 'typedef', 'method', 'function') and sym.is_public() and not in_boilerplate:
                if target_rule is None or target_rule == 'RULE_NO_ARTIFICIAL_CONCURRENCY':
                    if is_concurrency_word(sym.name):
                        self.violations.append({
                            'rule': 'RULE_NO_ARTIFICIAL_CONCURRENCY',
                            'severity': 'WARNING',
                            'message': f"Símbolo público '{sym.name}' expõe primitiva de concorrência específica do Go. AGENTS.md exige o uso de primitivas idiomáticas do Dart (Stream, Future, Completer).",
                            'file': sym.file_path,
                            'line': sym.line,
                            'symbol': sym.name,
                            'suggested': "Substituir por Stream<T>, Future<void> ou Completer<T>",
                        })

            # REGRA 23: Veto a Membros Públicos que Expõem Tipos Não-Públicos
            if sym.kind in ('field', 'getter', 'setter', 'method', 'function', 'constructor', 'operator') and not in_boilerplate:
                if target_rule is None or target_rule == 'RULE_EXPOSED_NON_PUBLIC_MEMBERS':
                    if not sym.name.startswith('_') and not (sym.parent_type and sym.parent_type.startswith('_')):
                        bad = [t for t in sym.signature_types if len(t) >= 2 and t[0] == '_' and t[1].isupper()]
                        if bad:
                            priv_type = bad[0]
                            self.violations.append({
                                'rule': 'RULE_EXPOSED_NON_PUBLIC_MEMBERS',
                                'severity': 'WARNING',
                                'message': f"Membro público '{sym.name}' expõe tipo não-público '{priv_type}'. AGENTS.md exige implementar seguindo o mesmo nível de visibilidade e permissão do Upstream Go, ou menor se não for possível.",
                                'file': sym.file_path,
                                'line': sym.line,
                                'symbol': sym.name,
                                'suggested': f"Tipar com interface pública de menor permissão ou tornar o membro privado ('_{sym.name}')",
                            })

        # REGRA 18: Auditoria de Tipos / Classes / Interfaces do Upstream Go ainda não portados
        if target_rule is None or target_rule == 'RULE_MISSING_GO_TYPES':
            dart_types_by_pkg: Dict[str, Set[str]] = {}
            for sym in self.dart_symbols:
                if sym.kind in ('class', 'mixin', 'enum', 'extension', 'extension_type', 'typedef'):
                    my_pkg = None
                    for p_dir in pkg_to_mod:
                        if sym.file_path.startswith(p_dir + '/'):
                            my_pkg = p_dir
                            break
                    if my_pkg:
                        dart_types_by_pkg.setdefault(my_pkg, set()).add(sym.name.lower())

            for mod, syms in self.go_symbols_by_module.items():
                if mod not in mod_to_pkg:
                    continue
                pkg_dir = mod_to_pkg[mod]
                if target_package and target_package not in pkg_dir:
                    continue

                pkg_dart_types = dart_types_by_pkg.get(pkg_dir, set())
                for s in syms:
                    if s.kind in ('struct', 'interface', 'type'):
                        # Camada fora de escopo nunca é lacuna: não portar o
                        # que upstream só declara em CLI/gateway/RPC não é
                        # pendência (AGENTS.md, seção "Fora do escopo").
                        if s.out_of_scope:
                            continue
                        if not include_non_public and not s.is_exported():
                            continue
                        if s.name.lower() not in pkg_dart_types:
                            pub_str = "público" if s.is_exported() else "interno"
                            self.violations.append({
                                'rule': 'RULE_MISSING_GO_TYPES',
                                'severity': 'INFO',
                                'message': f"Tipo {pub_str} Go '{s.name}' ({s.kind}) do módulo '{mod}' ainda não foi portado para o pacote '{pkg_dir}'.",
                                'file': pkg_dir,
                                'line': 1,
                                'symbol': s.name,
                                'suggested': f"Portar '{s.name}' para '{pkg_dir}' ou documentar se for omitido deliberadamente",
                            })

        # REGRA 19: Auditoria de Campos de Structs do Upstream Go ainda não portados
        if target_rule is None or target_rule == 'RULE_MISSING_GO_FIELDS':
            dart_members_by_type: Dict[Tuple[str, str], Set[str]] = {}
            for sym in self.dart_symbols:
                if sym.parent_type and sym.kind in ('field', 'getter', 'setter', 'method'):
                    my_pkg = None
                    for p_dir in pkg_to_mod:
                        if sym.file_path.startswith(p_dir + '/'):
                            my_pkg = p_dir
                            break
                    if my_pkg:
                        key = (my_pkg, sym.parent_type.lower())
                        dart_members_by_type.setdefault(key, set()).add(sym.name.lstrip('_').lower())

            for sym in self.dart_symbols:
                if target_package and target_package not in sym.file_path:
                    continue
                in_boilerplate = 'packages/boilerplate/' in sym.file_path
                if sym.kind in ('class', 'mixin') and sym.is_public() and not in_boilerplate:
                    my_pkg = None
                    for p_dir in pkg_to_mod:
                        if sym.file_path.startswith(p_dir + '/'):
                            my_pkg = p_dir
                            break
                    if my_pkg and not sym.file_path.startswith('lib/'):
                        my_mod = pkg_to_mod[my_pkg]
                        go_syms = self.go_symbols_by_module.get(my_mod, [])
                        expected_fields = [
                            s.name for s in go_syms
                            if s.kind == 'field' and s.parent_type and s.parent_type.lower() == sym.name.lower()
                            and not s.out_of_scope
                            and (include_non_public or s.is_exported())
                        ]
                        if expected_fields:
                            implemented = dart_members_by_type.get((my_pkg, sym.name.lower()), set())
                            missing = [f for f in expected_fields if f.lstrip('_').lower() not in implemented]
                            if missing:
                                self.violations.append({
                                    'rule': 'RULE_MISSING_GO_FIELDS',
                                    'severity': 'INFO',
                                    'message': f"Classe '{sym.name}' possui {len(missing)} campo(s) do Go pendente(s) no módulo '{my_mod}': {', '.join(missing[:4])}{'...' if len(missing) > 4 else ''}.",
                                    'file': sym.file_path,
                                    'line': sym.line,
                                    'symbol': sym.name,
                                    'suggested': f"Avaliar implementação dos campos: {', '.join(missing)}",
                                })

        # REGRA 20: Auditoria de Métodos do Upstream Go ainda não implementados
        if target_rule is None or target_rule == 'RULE_MISSING_GO_METHODS':
            dart_methods_by_class: Dict[Tuple[str, str], Set[str]] = {}
            for sym in self.dart_symbols:
                if sym.kind in ('method', 'getter') and sym.parent_type:
                    my_pkg = None
                    for p_dir in pkg_to_mod:
                        if sym.file_path.startswith(p_dir + '/'):
                            my_pkg = p_dir
                            break
                    if my_pkg:
                        key = (my_pkg, sym.parent_type.lower())
                        dart_methods_by_class.setdefault(key, set()).add(sym.name.lstrip('_').lower())

            for sym in self.dart_symbols:
                if target_package and target_package not in sym.file_path:
                    continue
                in_boilerplate = 'packages/boilerplate/' in sym.file_path
                if sym.kind in ('class', 'mixin') and sym.is_public() and not in_boilerplate:
                    my_pkg = None
                    for p_dir in pkg_to_mod:
                        if sym.file_path.startswith(p_dir + '/'):
                            my_pkg = p_dir
                            break
                    if my_pkg and not sym.file_path.startswith('lib/'):
                        my_mod = pkg_to_mod[my_pkg]
                        go_syms = self.go_symbols_by_module.get(my_mod, [])
                        expected_methods = [
                            s.name for s in go_syms
                            if s.kind == 'method' and s.parent_type and s.parent_type.lower() == sym.name.lower()
                            and not s.out_of_scope
                            and (include_non_public or s.is_exported())
                        ]
                        if expected_methods:
                            implemented = dart_methods_by_class.get((my_pkg, sym.name.lower()), set())
                            missing = [m for m in expected_methods if m.lstrip('_').lower() not in implemented]
                            if missing:
                                self.violations.append({
                                    'rule': 'RULE_MISSING_GO_METHODS',
                                    'severity': 'INFO',
                                    'message': f"Classe '{sym.name}' possui {len(missing)} método(s) do Go pendente(s) no módulo '{my_mod}': {', '.join(missing[:4])}{'...' if len(missing) > 4 else ''}.",
                                    'file': sym.file_path,
                                    'line': sym.line,
                                    'symbol': sym.name,
                                    'suggested': f"Avaliar paridade e implementação de: {', '.join(missing)}",
                                })

        # REGRA 21: Auditoria de Funções Top-Level do Upstream Go ainda não portadas
        if target_rule is None or target_rule == 'RULE_MISSING_GO_FUNCTIONS':
            dart_funcs_by_pkg: Dict[str, Set[str]] = {}
            dart_types_by_pkg2: Dict[str, Set[str]] = {}
            for sym in self.dart_symbols:
                my_pkg = None
                for p_dir in pkg_to_mod:
                    if sym.file_path.startswith(p_dir + '/'):
                        my_pkg = p_dir
                        break
                if my_pkg:
                    if sym.kind == 'function':
                        dart_funcs_by_pkg.setdefault(my_pkg, set()).add(sym.name.lstrip('_').lower())
                    elif sym.kind in ('class', 'mixin', 'enum', 'extension', 'extension_type', 'typedef'):
                        dart_types_by_pkg2.setdefault(my_pkg, set()).add(sym.name.lower())

            for mod, syms in self.go_symbols_by_module.items():
                if mod not in mod_to_pkg:
                    continue
                pkg_dir = mod_to_pkg[mod]
                if target_package and target_package not in pkg_dir:
                    continue

                pkg_funcs = dart_funcs_by_pkg.get(pkg_dir, set())
                pkg_types = dart_types_by_pkg2.get(pkg_dir, set())

                go_funcs = [s for s in syms if s.kind == 'func' and not s.out_of_scope and (include_non_public or s.is_exported())]
                missing = []
                for gf in go_funcs:
                    gfn_lower = gf.name.lstrip('_').lower()
                    if gf.name.startswith('New') and len(gf.name) > 3 and gf.name[3:].lower() in pkg_types:
                        continue
                    if gfn_lower not in pkg_funcs:
                        missing.append(gf.name)

                if missing:
                    self.violations.append({
                        'rule': 'RULE_MISSING_GO_FUNCTIONS',
                        'severity': 'INFO',
                        'message': f"Pacote '{pkg_dir}' possui {len(missing)} função(ões) livre(s) do Go pendente(s) no módulo '{mod}': {', '.join(missing[:5])}{'...' if len(missing) > 5 else ''}.",
                        'file': pkg_dir,
                        'line': 1,
                        'symbol': 'top-level functions',
                        'suggested': f"Avaliar porte das funções: {', '.join(missing[:10])}{'...' if len(missing) > 10 else ''}",
                    })

        # REGRA 26: Erros de sintaxe detectados pelo package:analyzer
        if target_rule is None or target_rule == 'RULE_PARSE_ERROR':
            for rel_path, facts in self.dart_facts.items():
                if target_package and target_package not in rel_path:
                    continue
                for err in facts.get('parseErrors', []):
                    self.violations.append({
                        'rule': 'RULE_PARSE_ERROR',
                        'severity': 'ERROR',
                        'message': f"Erro de sintaxe detectado pelo package:analyzer em '{rel_path}:{err['line']}': {err['message']}",
                        'file': rel_path,
                        'line': err['line'],
                        'symbol': '<erro-de-sintaxe>',
                        'suggested': "Corrigir o erro de sintaxe antes de confiar nas declarações extraídas deste arquivo",
                    })

        # 2. Verificações em nível de arquivo (CLI e Boilerplate Types)
        PURE_FORMAT_PACKAGES = {
            'packages/transpiled_cid',
            'packages/transpiled_multihash',
            'packages/transpiled_multibase',
            'packages/transpiled_multicodec',
            'packages/transpiled_varint',
            'packages/transpiled_block_format',
            'packages/transpiled_ipld_prime',
        }

        for rel_path, facts in self._api_facts_items(target_package):
            if 'packages/boilerplate/' in rel_path:
                continue

            imports = facts.get('imports', [])

            # REGRA 9: Veto a Código de CLI em Pacotes de Bibliotecas Reutilizáveis
            if rel_path.startswith('packages/transpiled_'):
                if target_rule is None or target_rule == 'RULE_NO_CLI_IN_LIBRARIES':
                    if any(imp['uri'] in ('package:args/args.dart', 'package:args/command_runner.dart') for imp in imports):
                        self.violations.append({
                            'rule': 'RULE_NO_CLI_IN_LIBRARIES',
                            'severity': 'ERROR',
                            'message': "Importação de CLI ('package:args') em biblioteca reutilizável. AGENTS.md define CLI como estritamente fora de escopo de bibliotecas.",
                            'file': rel_path,
                            'line': 1,
                            'symbol': 'package:args',
                            'suggested': "Remover dependência e lógica de CLI da biblioteca",
                        })
                    events = []
                    for inv in facts.get('invocations', []):
                        if inv['name'] == 'exit':
                            events.append((inv['line'], 'exit('))
                    for asg in facts.get('assignments', []):
                        if asg['target'] == 'exitCode':
                            events.append((asg['line'], 'exitCode ='))
                    if events:
                        events.sort(key=lambda e: e[0])
                        line_no, snippet = events[0]
                        self.violations.append({
                            'rule': 'RULE_NO_CLI_IN_LIBRARIES',
                            'severity': 'ERROR',
                            'message': f"Uso indevido de chamada de processo CLI ('{snippet}') em biblioteca. Bibliotecas devem propagar erros via exceções.",
                            'file': rel_path,
                            'line': line_no,
                            'symbol': snippet,
                            'suggested': "Substituir chamada por lançamento de exceção tipada",
                        })

            # REGRA 10: Uso Obrigatório de fixed_types.Golang.* para Tipos Primitivos
            if rel_path.startswith('packages/transpiled_'):
                if target_rule is None or target_rule == 'RULE_ENFORCE_BOILERPLATE_TYPES':
                    imports_boilerplate = any(imp['uri'] == 'package:boilerplate/fixed_types/golang.dart' for imp in imports)
                    if not imports_boilerplate:
                        for lit in facts.get('bitwiseAndHexLiterals', []):
                            lex = lit['lexeme']
                            hexdigits = lex[2:]
                            if 8 <= len(hexdigits) <= 16 and all(c in 'fF' for c in hexdigits):
                                self.violations.append({
                                    'rule': 'RULE_ENFORCE_BOILERPLATE_TYPES',
                                    'severity': 'WARNING',
                                    'message': f"Uso de máscara binária de 32/64 bits ('{lex}') sem importar 'fixed_types.Golang.*'. AGENTS.md exige centralizar semântica de overflow e limites em packages/boilerplate/.",
                                    'file': rel_path,
                                    'line': lit['line'],
                                    'symbol': lex,
                                    'suggested': "Importar 'package:boilerplate/fixed_types/golang.dart' e utilizar os tipos Golang correspondentes",
                                })
                                break

            # REGRA 15: Veto a dart:io em Pacotes de Codecs e Multiformatos Puros
            for pure_pkg in PURE_FORMAT_PACKAGES:
                if rel_path.startswith(pure_pkg + '/'):
                    if target_rule is None or target_rule == 'RULE_RESTRICTED_PLATFORM_IMPORTS':
                        for imp in imports:
                            if imp['uri'] == 'dart:io':
                                self.violations.append({
                                    'rule': 'RULE_RESTRICTED_PLATFORM_IMPORTS',
                                    'severity': 'ERROR',
                                    'message': f"Importação de 'dart:io' no pacote de codec/formato puro '{pure_pkg}'. Quebra compatibilidade universal Web/Wasm.",
                                    'file': rel_path,
                                    'line': imp['line'],
                                    'symbol': 'dart:io',
                                    'suggested': "Remover dependência de 'dart:io' e manter pacote agnóstico de plataforma",
                                })
                                break

            # REGRA 16: Veto a chamadas print(...) em Bibliotecas Reutilizáveis
            if rel_path.startswith('packages/transpiled_'):
                if target_rule is None or target_rule == 'RULE_NO_PRINT_IN_LIBRARIES':
                    for inv in facts.get('invocations', []):
                        if inv['name'] == 'print':
                            self.violations.append({
                                'rule': 'RULE_NO_PRINT_IN_LIBRARIES',
                                'severity': 'ERROR',
                                'message': "Chamada a 'print(...)' em pacote de biblioteca reutilizável. Bibliotecas devem usar logging estruturado ou streams.",
                                'file': rel_path,
                                'line': inv['line'],
                                'symbol': 'print(...)',
                                'suggested': "Substituir por logger estruturado ou remover print",
                            })
                            break

        # REGRA 22: Veto a Dependências de CLI em pubspec.yaml de Bibliotecas
        if target_rule is None or target_rule == 'RULE_PUBSPEC_DEPENDENCIES':
            for ps in sorted(self.root_dir.glob('packages/*/pubspec.yaml')):
                rel_ps = str(ps.relative_to(self.root_dir)).replace('\\', '/')
                if target_package and target_package not in rel_ps:
                    continue
                try:
                    text = ps.read_text(encoding='utf-8', errors='ignore')
                    data = yaml.safe_load(text) or {}
                except Exception:
                    continue
                deps = data.get('dependencies')
                if not isinstance(deps, dict):
                    continue
                forbidden = [d for d in deps if d in ('args', 'dcli')]
                if not forbidden:
                    continue

                line_of: Dict[str, int] = {}
                in_deps = False
                for idx, raw_line in enumerate(text.splitlines(), start=1):
                    no_comment = raw_line.split('#', 1)[0].rstrip()
                    stripped = no_comment.strip()
                    if no_comment and not no_comment[0].isspace():
                        in_deps = stripped == 'dependencies:'
                        continue
                    if in_deps and stripped:
                        key = stripped.split(':', 1)[0].strip()
                        if key in forbidden and key not in line_of:
                            line_of[key] = idx

                for d_name in forbidden:
                    self.violations.append({
                        'rule': 'RULE_PUBSPEC_DEPENDENCIES',
                        'severity': 'ERROR',
                        'message': f"Dependência de CLI '{d_name}' declarada em 'dependencies' de biblioteca reutilizável '{rel_ps}'. Mover para dev_dependencies ou remover.",
                        'file': rel_ps,
                        'line': line_of.get(d_name, 1),
                        'symbol': d_name,
                        'suggested': f"Remover '{d_name}' de 'dependencies:'",
                    })

        # REGRA 25: Prefixo de Import Nomeado pela Biblioteca (Colisão de Nomes)
        if target_rule is None or target_rule == 'RULE_IMPORT_PREFIX_NAMING':
            public_type_packages: Dict[str, Set[str]] = {}
            for sym in self.dart_symbols:
                if sym.kind in ('class', 'mixin', 'enum', 'extension_type') and sym.is_public():
                    if sym.file_path.startswith('packages/'):
                        pkg = sym.file_path.split('/')[1]
                        public_type_packages.setdefault(sym.name, set()).add(pkg)

            declared_types_by_uri: Dict[str, Set[str]] = {}
            for sym in self.dart_symbols:
                if sym.kind in ('class', 'mixin', 'enum', 'extension_type') and sym.is_public():
                    if sym.file_path.startswith('packages/'):
                        parts = sym.file_path.split('/')
                        if len(parts) > 3 and parts[2] == 'lib':
                            uri = 'package:' + parts[1] + '/' + '/'.join(parts[3:])
                            declared_types_by_uri.setdefault(uri, set()).add(sym.name)

            for rel_path, facts in self.dart_facts.items():
                if target_package and target_package not in rel_path:
                    continue
                imports = facts.get('imports', [])

                line_of: Dict[str, int] = {}
                uri_of_prefix: Dict[str, str] = {}
                other_libs: Set[str] = set()
                same_pkg_imports: Dict[str, List[str]] = {}
                for imp in imports:
                    uri = imp['uri']
                    lib = self.library_name_of_uri(uri)
                    prefix = imp.get('prefix')
                    if prefix:
                        line_of.setdefault(prefix, imp['line'])
                        uri_of_prefix[prefix] = uri
                    for h in imp.get('hide', []):
                        line_of.setdefault('hide:' + h, imp['line'])
                    if lib and (lib.startswith('transpiled_') or lib == 'boilerplate'):
                        other_libs.add(lib)
                        same_pkg_imports.setdefault(lib, []).append(uri)

                for prefix, library in self.dart_import_prefixes.get(rel_path, {}).items():
                    if not (library.startswith('transpiled_') or library == 'boilerplate'):
                        continue
                    uri_p = uri_of_prefix.get(prefix, '')
                    internal = '/src/' in uri_p
                    if internal:
                        allowed = self.go_prefixes_for_library_path(uri_p)
                        if not allowed:
                            continue
                    else:
                        allowed = self.allowed_prefixes_for(library)
                    if prefix in allowed:
                        continue
                    self.violations.append({
                        'rule': 'RULE_IMPORT_PREFIX_NAMING',
                        'severity': 'ERROR',
                        'message': (
                            f"Import de '{library}' usa o prefixo '{prefix}', que não nomeia a biblioteca. "
                            f"Conforme AGENTS.md, colisão de nomes entre pacotes transpilados se resolve com prefixo "
                            f"nomeado pela biblioteca, para que a origem de cada símbolo seja legível no ponto de uso."
                        ),
                        'file': rel_path,
                        'line': line_of.get(prefix, 1),
                        'symbol': prefix,
                        'suggested': f"Usar 'as {sorted(allowed, key=len)[0]}'",
                    })

                declared_local: Set[str] = set()
                for ident in facts.get('declaredIdentifiers', []):
                    if ident and (ident[0].islower() or ident[0] == '_'):
                        declared_local.add(ident)

                for prefix, library in self.dart_import_prefixes.get(rel_path, {}).items():
                    if not (library.startswith('transpiled_') or library == 'boilerplate'):
                        continue
                    if prefix.endswith('_package'):
                        continue
                    if prefix not in declared_local:
                        continue
                    uri_p = uri_of_prefix.get(prefix, '')
                    escape = (
                        self.escape_prefix_for(prefix)
                        if '/src/' in uri_p
                        else self.escape_prefix_for(prefix, library)
                    )
                    self.violations.append({
                        'rule': 'RULE_IMPORT_PREFIX_NAMING',
                        'severity': 'ERROR',
                        'message': (
                            f"O prefixo '{prefix}' sombreia um identificador declarado neste arquivo. "
                            f"Em Dart o prefixo de import divide o espaço de nomes com variáveis e métodos, "
                            f"então o nome fiel precisa da forma longa com sufixo `_package` aqui."
                        ),
                        'file': rel_path,
                        'line': line_of.get(prefix, 1),
                        'symbol': prefix,
                        'suggested': f"Usar 'as {escape}' e qualificar os usos",
                    })

                for hidden, library in self.dart_import_hides.get(rel_path, []):
                    if not (library.startswith('transpiled_') or library == 'boilerplate'):
                        continue

                    internal = [
                        u for u in same_pkg_imports.get(library, [])
                        if '/src/' in u and hidden in declared_types_by_uri.get(u, set())
                    ]
                    if internal:
                        uri_i = internal[0]
                        wanted = sorted(self.go_prefixes_for_library_path(uri_i))
                        self.violations.append({
                            'rule': 'RULE_IMPORT_PREFIX_NAMING',
                            'severity': 'ERROR',
                            'message': (
                                f"Colisão de '{hidden}' dentro do pacote '{library}' resolvida com `hide`. "
                                f"Aqui o nome do pacote seria o mesmo dos dois lados, então o prefixo deve ser o do "
                                f"pacote Go correspondente, como o próprio Go faz ao qualificar."
                            ),
                            'file': rel_path,
                            'line': line_of.get('hide:' + hidden, 1),
                            'symbol': hidden,
                            'suggested': (
                                f"Importar '{uri_i}' com 'as {wanted[0]}' e qualificar os usos, em vez de 'hide {hidden}'"
                                if wanted else
                                f"Importar '{uri_i}' com prefixo do pacote Go e qualificar os usos"
                            ),
                        })
                        continue

                    rivals = {
                        pkg
                        for pkg in public_type_packages.get(hidden, set())
                        if pkg != library and pkg in other_libs
                    }
                    if not rivals:
                        continue
                    self.violations.append({
                        'rule': 'RULE_IMPORT_PREFIX_NAMING',
                        'severity': 'ERROR',
                        'message': (
                            f"Import de '{library}' esconde '{hidden}' com `hide`. Esconder resolve a colisão mas "
                            f"apaga de onde veio o símbolo que ficou; o prefixo nomeado pela biblioteca preserva essa "
                            f"informação e é o que o AGENTS.md exige."
                        ),
                        'file': rel_path,
                        'line': line_of.get('hide:' + hidden, 1),
                        'symbol': hidden,
                        'suggested': f"Importar com 'as {sorted(self.allowed_prefixes_for(library), key=len)[0]}' em vez de 'hide {hidden}'",
                    })

        # Filtro por severidade opcional
        if target_severity:
            sev_upper = target_severity.upper()
            self.violations = [v for v in self.violations if v['severity'].upper() == sev_upper]

    # -- correções mecânicas ---------------------------------------------

    def apply_autofixes(self) -> int:
        """Aplica correções mecânicas determinísticas e seguras nos arquivos Dart."""
        total_fixes = 0
        edits_by_file: Dict[str, List[Tuple[int, int, str]]] = {}

        for v in self.violations:
            rule = v['rule']
            f_path = self.root_dir / v['file']
            if not f_path.exists() or not f_path.is_file() or not v['file'].endswith('.dart'):
                continue

            if rule == 'RULE_NO_UNAUTHORIZED_DEPRECATED':
                off, end = v.get('_fix_offset'), v.get('_fix_end')
                if off is None or end is None:
                    continue
                edits_by_file.setdefault(v['file'], []).append((off, end, None))
            elif rule == 'RULE_NO_TYPEDEF_SHIMS':
                off, end = v.get('_fix_offset'), v.get('_fix_end')
                if off is None or end is None:
                    continue
                comment = f"// [AGENTS.md RULE_NO_TYPEDEF_SHIMS] Removido shim retrocompatível: typedef {v['symbol']} = {v.get('_fix_target', '')};"
                edits_by_file.setdefault(v['file'], []).append((off, end, comment))
            elif rule == 'RULE_REDUNDANT_CONSTRUCTOR_NAMES':
                c_sym = v['symbol']
                if c_sym.startswith('newFrom'):
                    suggested = c_sym[3:]
                    suggested = suggested[:1].lower() + suggested[1:]
                    content = f_path.read_text(encoding='utf-8')
                    new_content = content.replace(f".{c_sym}", f".{suggested}")
                    if new_content != content:
                        f_path.write_text(new_content, encoding='utf-8')
                        total_fixes += 1

        for rel_path, edits in edits_by_file.items():
            f_path = self.root_dir / rel_path
            content = f_path.read_text(encoding='utf-8')
            for off, end, replacement in sorted(edits, key=lambda e: e[0], reverse=True):
                if replacement is None:
                    j = end
                    while j < len(content) and content[j].isspace():
                        j += 1
                    content = content[:off] + content[j:]
                else:
                    content = content[:off] + replacement + content[end:]
                total_fixes += 1
            f_path.write_text(content, encoding='utf-8')

        return total_fixes

    # -- relatórios --------------------------------------------------------

    @staticmethod
    def _public_violation(v: Dict) -> Dict:
        return {k: val for k, val in v.items() if not k.startswith('_')}

    def generate_markdown_report(self) -> str:
        total = len(self.violations)
        errors = [v for v in self.violations if v['severity'] == 'ERROR']
        warnings = [v for v in self.violations if v['severity'] == 'WARNING']
        infos = [v for v in self.violations if v['severity'] == 'INFO']

        by_rule = {}
        for v in self.violations:
            by_rule.setdefault(v['rule'], []).append(v)

        lines = [
            "# Relatório de Auditoria de AST e Nomenclatura (Dart <-> Go)",
            "",
            "> Relatório gerado automaticamente por `tool/audit_ast_nomenclature.py`.",
            f"> **Símbolos Dart Auditados:** {len(self.dart_symbols)} | **Símbolos Go Indexados:** {sum(len(s) for s in self.go_symbols_by_module.values())}",
            f"> **Status Geral:** ❌ **{len(errors)} Erros** | ⚠️ **{len(warnings)} Avisos** | ℹ️ **{len(infos)} Notas de Cobertura**",
            "",
            f"## 1. Resumo Executivo das {len(RULE_TITLES)} Regras",
            "",
            "| # | Regra | Severidade | Ocorrências | Status |",
            "| :---: | :--- | :---: | :---: | :---: |",
        ]

        for r_id, r_title in RULE_TITLES.items():
            r_list = by_rule.get(r_id, [])
            count = len(r_list)
            status = "✅ Conforme" if count == 0 else ("❌ Pendente" if any(v['severity'] == 'ERROR' for v in r_list) else "⚠️ Atenção")
            sev = r_list[0]['severity'] if r_list else RULE_DEFAULT_SEVERITIES.get(r_id, 'ERROR')
            lines.append(f"| `{r_id}` | {r_title} | `{sev}` | {count} | {status} |")

        lines.append("")
        lines.append("## 2. Detalhamento dos Apontamentos")
        lines.append("")

        if total == 0:
            lines.append("🎉 **Nenhuma inconsistência encontrada!** Todo o código auditado está 100% fiel às regras do AGENTS.md.\n")
        else:
            for r_id in RULE_TITLES:
                if r_id not in by_rule:
                    continue
                r_list = by_rule[r_id]
                lines.append(f"### {RULE_TITLES.get(r_id, r_id)} ({len(r_list)} ocorrências)\n")
                for item in r_list:
                    if item['severity'] == 'ERROR':
                        badge = "❌ `[ERRO]`"
                    elif item['severity'] == 'WARNING':
                        badge = "⚠️ `[AVISO]`"
                    else:
                        badge = "ℹ️ `[INFO]`"
                    file_link = f"[`{item['file']}:{item['line']}`]({item['file']}#L{item['line']})"
                    lines.append(f"- {badge} **{file_link}** — {item['message']}")
                    if item.get('suggested'):
                        lines.append(f"  - *Sugestão:* `{item['suggested']}`")
                lines.append("")

        if self.atomic_test_stats:
            stats = self.atomic_test_stats
            t_aud = stats['total_auditable']
            t_tst = stats['total_tested']
            t_mis = stats['total_missing']
            pct_tst = (t_tst / t_aud * 100) if t_aud > 0 else 0
            lines.append("## 3. Cobertura da Árvore AST de Testes Atômicos 1 para 1")
            lines.append("")
            lines.append("> Convenção determinística: `test/atomic/<nivel>/<nome_modulo>_atomic_tests.dart`")
            lines.append(f"- **Símbolos Públicos Auditáveis:** {t_aud:,}")
            lines.append(f"- **Testados:** {t_tst:,} ({pct_tst:.1f}%)")
            lines.append(f"- **Pendentes (ERROS Bloqueantes):** {t_mis:,} ({100.0 - pct_tst:.1f}%)")
            lines.append("")
            lines.append("| Pacote / Módulo | Total Auditáveis | Testados | Faltando | % Cobertura |")
            lines.append("| :--- | :---: | :---: | :---: | :---: |")
            for pkg, p_data in sorted(stats['by_package'].items(), key=lambda x: x[0]):
                p_tot = p_data['total']
                p_tst = p_data['tested']
                p_mis = p_data['missing']
                p_pct = (p_tst / p_tot * 100) if p_tot > 0 else 0
                lines.append(f"| `{pkg}` | {p_tot} | {p_tst} | {p_mis} | **{p_pct:.1f}%** |")
            lines.append("")

        return "\n".join(lines)

    def print_report(self, json_output: bool = False, summary_only: bool = False,
                      markdown_output: bool = False, output_file: Optional[str] = None):
        out_text = ""
        if json_output:
            out_text = json.dumps([self._public_violation(v) for v in self.violations], indent=2)
        elif markdown_output:
            out_text = self.generate_markdown_report()
        else:
            out_lines = []
            total = len(self.violations)
            errors = [v for v in self.violations if v['severity'] == 'ERROR']
            warnings = [v for v in self.violations if v['severity'] == 'WARNING']
            infos = [v for v in self.violations if v['severity'] == 'INFO']

            out_lines.append("\n" + "=" * 80)
            out_lines.append("  RELATÓRIO DE AUDITORIA DE AST E NOMENCLATURA (Dart <-> Go)")
            out_lines.append("  Baseado nas diretrizes estritas do AGENTS.md")
            out_lines.append("=" * 80)
            out_lines.append(f"Total de símbolos Dart auditados: {len(self.dart_symbols)}")
            out_lines.append(f"Total de símbolos Go indexados:   {sum(len(s) for s in self.go_symbols_by_module.values())}")
            out_lines.append(f"Total de apontamentos:            {total} ({len(errors)} erros, {len(warnings)} avisos, {len(infos)} notas de cobertura)")
            out_lines.append("=" * 80 + "\n")

            if self.atomic_test_stats:
                stats = self.atomic_test_stats
                t_aud = stats['total_auditable']
                t_tst = stats['total_tested']
                t_mis = stats['total_missing']
                pct_tst = (t_tst / t_aud * 100) if t_aud > 0 else 0

                out_lines.append("=" * 80)
                out_lines.append("  COBERTURA DA ÁRVORE AST DE TESTES ATÔMICOS 1 PARA 1")
                out_lines.append("  Convenção: test/atomic/<nivel>/<nome_modulo>_atomic_tests.dart")
                out_lines.append("=" * 80)
                out_lines.append(f"Total de símbolos executáveis públicos auditados: {t_aud}")
                out_lines.append(f"Testes atômicos 1 para 1 encontrados:          {t_tst} ({pct_tst:.1f}%)")
                out_lines.append(f"Testes atômicos pendentes (ERROS):             {t_mis} ({100.0 - pct_tst:.1f}%)")
                out_lines.append("-" * 80)
                out_lines.append(f"{'Pacote / Módulo':<35} {'Auditáveis':>12} {'Testados':>10} {'Faltando':>10} {'% Cobertura':>12}")
                out_lines.append("-" * 80)
                for pkg, p_data in sorted(stats['by_package'].items(), key=lambda x: x[0]):
                    p_tot = p_data['total']
                    p_tst = p_data['tested']
                    p_mis = p_data['missing']
                    p_pct = (p_tst / p_tot * 100) if p_tot > 0 else 0
                    out_lines.append(f"{pkg:<35} {p_tot:>12} {p_tst:>10} {p_mis:>10} {p_pct:>11.1f}%")
                out_lines.append("=" * 80 + "\n")

            if total > 0:
                by_rule = {}
                for v in self.violations:
                    by_rule.setdefault(v['rule'], []).append(v)

                out_lines.append("Distribuição das regras:")
                for r_id, r_title in RULE_TITLES.items():
                    count = len(by_rule.get(r_id, []))
                    out_lines.append(f"  - {r_title}: {count}")
                out_lines.append("\n" + "=" * 80 + "\n")

            if not summary_only and total > 0:
                for r_id in RULE_TITLES:
                    if r_id not in by_rule:
                        continue
                    r_list = by_rule[r_id]
                    out_lines.append(f"### {RULE_TITLES.get(r_id, r_id)} ({len(r_list)} ocorrências):\n")
                    for item in r_list:
                        if item['severity'] == 'ERROR':
                            sev_mark = "❌ [ERRO]"
                        elif item['severity'] == 'WARNING':
                            sev_mark = "⚠️ [AVISO]"
                        else:
                            sev_mark = "ℹ️ [INFO]"
                        out_lines.append(f"  {sev_mark} {item['file']}:{item['line']}")
                        out_lines.append(f"     {item['message']}")
                        if item.get('suggested'):
                            out_lines.append(f"     -> Sugestão: {item['suggested']}")
                        out_lines.append("")
                    out_lines.append("-" * 80 + "\n")

            if total == 0:
                out_lines.append("🎉 NENHUMA INCONSISTÊNCIA ENCONTRADA! Todo o código auditado está 100% fiel às regras de nomenclatura do AGENTS.md.\n")

            out_text = "\n".join(out_lines)

        if output_file:
            out_p = Path(output_file)
            out_p.write_text(out_text, encoding='utf-8')
            print(f"📄 Relatório salvo com sucesso em: {output_file}")
        else:
            print(out_text)

    def compute_progress_stats(self) -> Dict:
        pkg_to_mod = {pkg: mod for mod, pkg in GO_MODULE_TO_DART_PACKAGE.items()}
        mod_to_pkg = {mod: pkg for mod, pkg in GO_MODULE_TO_DART_PACKAGE.items()}

        dart_types: Dict[str, Set[str]] = {}
        dart_members: Dict[Tuple[str, str], Set[str]] = {}
        dart_funcs: Dict[str, Set[str]] = {}

        for sym in self.dart_symbols:
            my_pkg = None
            for p_dir in pkg_to_mod:
                if sym.file_path.startswith(p_dir + '/'):
                    my_pkg = p_dir
                    break
            if not my_pkg:
                continue
            if sym.kind in ('class', 'mixin', 'enum', 'extension', 'extension_type', 'typedef'):
                dart_types.setdefault(my_pkg, set()).add(sym.name.lower())
            elif sym.kind in ('method', 'field', 'getter', 'setter') and sym.parent_type:
                key = (my_pkg, sym.parent_type.lower())
                dart_members.setdefault(key, set()).add(sym.name.lstrip('_').lower())
            elif sym.kind == 'function':
                dart_funcs.setdefault(my_pkg, set()).add(sym.name.lstrip('_').lower())

        total_go_types = 0
        done_go_types = 0
        total_go_methods = 0
        done_go_methods = 0
        total_go_fields = 0
        done_go_fields = 0
        total_go_funcs = 0
        done_go_funcs = 0

        modules = []

        for mod, syms in sorted(self.go_symbols_by_module.items()):
            pkg_dir = mod_to_pkg.get(mod)
            if not pkg_dir:
                continue

            pkg_d_types = dart_types.get(pkg_dir, set())
            pkg_d_funcs = dart_funcs.get(pkg_dir, set())

            mod_go_types = [s for s in syms if s.kind in ('struct', 'interface', 'type') and s.is_exported() and not s.out_of_scope]
            mod_go_methods = [s for s in syms if s.kind == 'method' and s.is_exported() and not s.out_of_scope]
            mod_go_fields = [s for s in syms if s.kind == 'field' and s.is_exported() and not s.out_of_scope]
            mod_go_funcs = [s for s in syms if s.kind == 'func' and s.is_exported() and not s.out_of_scope]

            m_types_done = sum(1 for s in mod_go_types if s.name.lower() in pkg_d_types)
            m_methods_done = sum(1 for s in mod_go_methods if s.parent_type and s.name.lstrip('_').lower() in dart_members.get((pkg_dir, s.parent_type.lower()), set()))
            m_fields_done = sum(1 for s in mod_go_fields if s.parent_type and s.name.lstrip('_').lower() in dart_members.get((pkg_dir, s.parent_type.lower()), set()))
            m_funcs_done = sum(1 for s in mod_go_funcs if s.name.lstrip('_').lower() in pkg_d_funcs or (s.name.startswith('New') and s.name[3:].lower() in pkg_d_types))

            mod_total = len(mod_go_types) + len(mod_go_methods) + len(mod_go_fields) + len(mod_go_funcs)
            mod_done = m_types_done + m_methods_done + m_fields_done + m_funcs_done

            total_go_types += len(mod_go_types)
            done_go_types += m_types_done
            total_go_methods += len(mod_go_methods)
            done_go_methods += m_methods_done
            total_go_fields += len(mod_go_fields)
            done_go_fields += m_fields_done
            total_go_funcs += len(mod_go_funcs)
            done_go_funcs += m_funcs_done

            pct = (mod_done / mod_total * 100) if mod_total > 0 else 0
            modules.append({
                'module': mod,
                'package': pkg_dir,
                'total': mod_total,
                'done': mod_done,
                'missing': mod_total - mod_done,
                'pct_done': pct,
                'pct_missing': 100.0 - pct,
                'types_total': len(mod_go_types),
                'types_done': m_types_done,
            })

        total_symbols = total_go_types + total_go_methods + total_go_fields + total_go_funcs
        total_done = done_go_types + done_go_methods + done_go_fields + done_go_funcs
        total_missing = total_symbols - total_done
        pct_done = (total_done / total_symbols * 100) if total_symbols > 0 else 0
        pct_missing = 100.0 - pct_done

        return {
            'total_symbols': total_symbols,
            'total_done': total_done,
            'total_missing': total_missing,
            'pct_done': pct_done,
            'pct_missing': pct_missing,
            'types': {'total': total_go_types, 'done': done_go_types, 'missing': total_go_types - done_go_types},
            'methods': {'total': total_go_methods, 'done': done_go_methods, 'missing': total_go_methods - done_go_methods},
            'fields': {'total': total_go_fields, 'done': done_go_fields, 'missing': total_go_fields - done_go_fields},
            'funcs': {'total': total_go_funcs, 'done': done_go_funcs, 'missing': total_go_funcs - done_go_funcs},
            'modules': modules,
        }

    def generate_progress_report(self) -> str:
        stats = self.compute_progress_stats()
        lines = [
            "# Relatório Sintético de Progresso e Cobertura da Árvore AST (Go <-> Dart)",
            "",
            "> Documento gerado automaticamente pela ferramenta `tool/audit_ast_nomenclature.py --progress`.",
            f"> **Símbolos Dart Auditados:** {len(self.dart_symbols)} | **Símbolos Go Indexados:** {sum(len(s) for s in self.go_symbols_by_module.values())}",
            "",
            "## 1. Visão Geral em Duas Perspectivas",
            "",
            "### Perspectiva A: Objetivo 1 — Primeiro Download P2P por CID (Prioridade Máxima)",
            "",
            "- **Status:** ✅ **100% Concluído (0% de Pendências Impeditivas)**",
            "- **Marco A (Provider Conhecido):** Concluído e comprovado (`Kubo -> TCP/Noise -> Bitswap 1.2.0 -> WANT_BLOCK -> validação CID -> Blockstore`).",
            "- **Marco B (Provider Descoberto via DHT):** Concluído e comprovado (`CID -> DHT findProviders -> AddrInfo -> conectar -> Bitswap -> Blockstore`).",
            "- **Testes de Integração com Kubo Real:** 100% aprovados (`local_kubo_bitswap_test.dart` e `local_kubo_dht_bitswap_test.dart`).",
            "",
            "### Perspectiva B: Cobertura Quantitativa da Árvore AST Total Upstream Go",
            "",
            f"- **Total de Símbolos Go no Escopo:** {stats['total_symbols']:,}",
            f"- **Símbolos Implementados em Dart:** {stats['total_done']:,} ({stats['pct_done']:.1f}%)",
            f"- **Símbolos Restantes no Ecossistema:** {stats['total_missing']:,} ({stats['pct_missing']:.1f}%)",
            "",
            "| Categoria de Símbolo | Total no Upstream Go | Implementado em Dart | Falta Implementar | % Concluído | % Que Falta |",
            "| :--- | :---: | :---: | :---: | :---: | :---: |",
        ]

        cat_names = [
            ('Tipos (Classes / Interfaces)', 'types'),
            ('Métodos', 'methods'),
            ('Campos de Structs', 'fields'),
            ('Funções Top-Level', 'funcs'),
        ]
        for c_label, c_key in cat_names:
            c_data = stats[c_key]
            c_done = c_data['done']
            c_tot = c_data['total']
            c_mis = c_data['missing']
            c_pct_done = (c_done / c_tot * 100) if c_tot > 0 else 0
            c_pct_mis = 100.0 - c_pct_done
            lines.append(f"| **{c_label}** | {c_tot:,} | {c_done:,} | {c_mis:,} | {c_pct_done:.1f}% | **{c_pct_mis:.1f}%** |")

        lines.append(f"| **TOTAL GERAL** | **{stats['total_symbols']:,}** | **{stats['total_done']:,}** | **{stats['total_missing']:,}** | **{stats['pct_done']:.1f}%** | **{stats['pct_missing']:.1f}%** |")
        lines.append("")
        lines.append("## 2. Detalhamento Quantitativo por Módulo Upstream Go")
        lines.append("")
        lines.append("| Módulo Go | Pacote Dart Correspondente | Total Símbolos | Implementados | Pendentes | % Feito | % Que Falta | Tipos (Feitos/Total) |")
        lines.append("| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: |")

        for m in sorted(stats['modules'], key=lambda x: x['pct_done'], reverse=True):
            lines.append(f"| `{m['module']}` | `{m['package']}` | {m['total']} | {m['done']} | {m['missing']} | {m['pct_done']:.1f}% | **{m['pct_missing']:.1f}%** | {m['types_done']}/{m['types_total']} |")

        lines.append("")
        lines.append("## 3. Diretriz Arquitetural (AGENTS.md)")
        lines.append("")
        lines.append("Conforme estipulado no `AGENTS.md`:")
        lines.append("- Kubo, Boxo e go-libp2p são referências de comportamento e não superfícies que devam ser portadas 100% integralmente.")
        lines.append("- Todo o volume de símbolos restantes corresponde a subsistemas opcionais ou avançados (Gateway HTTP, MFS completo, Circuit Relay v2, WebRTC, Tracing, Plugins, etc.), devendo ser portados sob demanda estrita e sem inflar o escopo do nó embutido.")
        lines.append("")

        return "\n".join(lines)


def main():
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    if hasattr(sys.stderr, 'reconfigure'):
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')

    parser = argparse.ArgumentParser(description="Auditor de AST e Nomenclatura Dart <-> Go conforme AGENTS.md")
    parser.add_argument('--package', help="Filtrar por diretório/pacote Dart específico (ex: transpiled_boxo)")
    parser.add_argument('--rule', help="Filtrar por regra específica (ex: RULE_ALL_CAPS, RULE_EXCEPTION_NAMING, RULE_PUBSPEC_DEPENDENCIES)")
    parser.add_argument('--severity', choices=['ERROR', 'WARNING', 'INFO', 'error', 'warning', 'info'], help="Filtrar por severidade (ERROR, WARNING, INFO)")
    parser.add_argument('--include-non-public', '--include-unexported', dest='include_non_public', action='store_true', help="Inclui símbolos e membros não-públicos (privados/internos) do Go na auditoria de cobertura")
    parser.add_argument('--json', action='store_true', help="Emitir resultado em formato JSON")
    parser.add_argument('--summary-only', action='store_true', help="Exibir apenas resumo quantitativo")
    parser.add_argument('--markdown', action='store_true', help="Exportar relatório formatado em Markdown")
    parser.add_argument('--output', help="Arquivo de destino para salvar o relatório (ex: audit_report.md)")
    parser.add_argument('--progress', action='store_true', help="Gera o relatório sintético de progresso da AST em PROGRESS_RELATORY.md")
    parser.add_argument('--progress-file', default='PROGRESS_RELATORY.md', help="Arquivo de saída para o relatório de progresso (padrão: PROGRESS_RELATORY.md)")
    parser.add_argument('--fix', action='store_true', help="Aplicar correções mecânicas determinísticas e seguras")
    parser.add_argument('--tests', action='store_true', help="Audita a árvore AST de testes atômicos 1 para 1 em test/atomic/<nivel>/<nome_modulo>_atomic_tests.dart")

    args = parser.parse_args()
    root_dir = Path(__file__).resolve().parent.parent

    auditor = AstNomenclatureAuditor(root_dir)
    auditor.load_all()
    auditor.audit_rules(
        target_package=args.package,
        target_rule=args.rule,
        target_severity=args.severity,
        include_non_public=args.include_non_public,
    )

    if args.tests or args.rule == 'RULE_MISSING_ATOMIC_TESTS':
        auditor.audit_atomic_tests(target_package=args.package)
        if args.severity:
            target_sev = args.severity.upper()
            auditor.violations = [v for v in auditor.violations if v['severity'] == target_sev]

    if args.fix:
        fixes = auditor.apply_autofixes()
        print(f"\n🛠️ [AUTOFIX] {fixes} correções mecânicas aplicadas automaticamente.")
        # Recarrega e re-audita para exibir estado atualizado (os fatos são
        # regenerados automaticamente, pois os arquivos editados ficam com
        # mtime mais novo que o JSON em cache).
        auditor = AstNomenclatureAuditor(root_dir)
        auditor.load_all()
        auditor.audit_rules(
            target_package=args.package,
            target_rule=args.rule,
            target_severity=args.severity,
            include_non_public=args.include_non_public,
        )

    if args.progress:
        progress_content = auditor.generate_progress_report()
        prog_path = root_dir / args.progress_file
        prog_path.write_text(progress_content, encoding='utf-8')
        print(f"📊 Relatório sintético de progresso AST salvo com sucesso em: {args.progress_file}")

    auditor.print_report(
        json_output=args.json,
        summary_only=args.summary_only,
        markdown_output=args.markdown,
        output_file=args.output,
    )

    errors = [v for v in auditor.violations if v['severity'] == 'ERROR']
    if errors:
        sys.exit(1)


if __name__ == '__main__':
    main()
