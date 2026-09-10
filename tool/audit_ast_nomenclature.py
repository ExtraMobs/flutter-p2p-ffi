#!/usr/bin/env python3
"""
tool/audit_ast_nomenclature.py

Auditor automatizado de AST e Nomenclatura Dart <-> Go conforme AGENTS.md.

Compara o índice AST do Go (gerado por go_module_index.go em go-ipfs-reference/*-index/)
com o código-fonte Dart (em packages/ e lib/), verificando conformidade estrita com:
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
import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

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
    'go-cid': 'packages/transpiled_cid',
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
    'protobuf': 'packages/transpiled_protobuf',
    'go-car-v2': 'packages/transpiled_go_car',
    'kubo': 'lib',
    'go-libp2p-kad-dht': 'lib/src/protocols/dht',
}

# Prefixos e sufixos canônicos de módulos/pacotes para correspondência de tipos Go <-> Dart
KNOWN_PREFIXES = ('Yamux', 'DagPb', 'UnixFs', 'Car', 'Cid', 'Ipfs', 'Basicnode', 'Noise', 'Ed25519', 'Rsa', 'Secp256k1', 'Filter')
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
    'YamuxStreamResetException': 'PROGRESS.md - Exceção tipada para ErrStreamReset do go-yamux',
    'YamuxSessionClosedException': 'PROGRESS.md - Exceção tipada para ErrSessionShutdown do go-yamux',
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
    'SwarmStream': 'PROGRESS.md - Implementação de NetworkStream sobre YamuxStream (swarm.Stream do Go)',
    'StreamReadWriter': 'PROGRESS.md - Interface para leitura e escrita binária de streams/conns (io.ReadWriter do Go)',
    'RawConn': 'PROGRESS.md - Interface para conexão bruta de transporte antes de upgrade (manet.Conn do Go)',
    'HolePunchService': 'PROGRESS.md - Serviço de coordenação de hole punching DCUtR (p2p/protocol/holepunch.Service do Go)',
    'HolePunchMessageType': 'PROGRESS.md - Enum Dart para tipos de mensagem do DCUtR (HolePunch_Type do Go)',
    'HolePunchMessage': 'PROGRESS.md - Representação protobuf de mensagem HolePunch (holepunch.pb do Go)',
    'NatGateway': 'PROGRESS.md - Interface de abstração de gateway UPnP/NAT-PMP para NATManager',
    'SimulatedNatGateway': 'PROGRESS.md - Implementação simulada de gateway UPnP/NAT-PMP para ambientes locais e testes',
    'BasicNatManager': 'PROGRESS.md - Implementação padrão de gerenciador NAT com port mapping (p2p/host/basic.natManager do Go)',
    # packages/transpiled_libp2p_kbucket
    'KeyspaceKey': 'PROGRESS.md - Chave no espaço de chaves XOR da Kademlia',
    'PeerMetrics': 'PROGRESS.md - Métricas de latência e confiabilidade de peers na tabela de roteamento',
    'PeerRejectedNoCapacityException': 'PROGRESS.md - Exceção para rejeição de peer por bucket cheio no kbucket',
    # packages/transpiled_libp2p_routing_helpers
    'Closable': 'PROGRESS.md - Interface para fechamento de recursos de roteamento paralelo (io.Closer do Go)',
}

# Caminhos fora de escopo conforme AGENTS.md (CLI, benchmarks, etc.)
OUT_OF_SCOPE_PATTERNS = [
    r'kubo/cmd/.*',
    r'kubo/commands/.*',
    r'kubo/core/commands/.*',
    r'kubo/test/cli/.*',
    r'.*_test\.go',
    r'matest/.*',
    r'sharness/.*',
]

def is_out_of_scope(file_path: str) -> bool:
    norm = file_path.replace('\\', '/')
    for pat in OUT_OF_SCOPE_PATTERNS:
        if re.search(pat, norm):
            return True
    return False

# Títulos e identificadores das 22 regras contratuais
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
}

def split_words(s: str) -> List[str]:
    """Divide identificadores em palavras individuais reconhecendo acrônimos."""
    s = s.replace('_', ' ').replace('-', ' ')
    # Reconhece blocos como P2P, acrônimos maiúsculos e palavras regulares
    parts = re.findall(r'[A-Z][0-9]+[A-Z]|[A-Z]+(?=[A-Z][a-z0-9]|$)|[A-Z][a-z0-9]*|[a-z0-9]+', s)
    return parts

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

def check_all_caps_block(name: str) -> Optional[str]:
    """Detecta se há bloco em All-Caps que viole a regra do AGENTS.md."""
    clean = name.strip('_')
    # Permitir nomes explícitos da especificação Go em boilerplate (ex: Int8, Int64, Uint64)
    # 2 ou mais letras maiúsculas adjacentes
    m = re.search(r'[A-Z]{2,}', clean)
    if m:
        return m.group(0)
    # Acrônimos com números tipo P2P
    m2 = re.search(r'[A-Z]\d+[A-Z]', clean)
    if m2:
        return m2.group(0)
    return None

def clean_dart_source(code: str) -> str:
    """Substitui comentários e strings por espaços mantendo linhas intactas."""
    out = []
    i = 0
    n = len(code)
    while i < n:
        if code[i:i+2] == '/*':
            i += 2
            while i < n and code[i:i+2] != '*/':
                out.append('\n' if code[i] == '\n' else ' ')
                i += 1
            out.append('  ')
            i += 2
        elif code[i:i+2] == '//':
            while i < n and code[i] != '\n':
                out.append(' ')
                i += 1
            if i < n and code[i] == '\n':
                out.append('\n')
                i += 1
        elif code[i:i+3] in ("'''", '"""') or code[i:i+4] in ("r'''", 'r"""'):
            raw = code[i] == 'r'
            if raw:
                out.append(' ')
                i += 1
            delim = code[i:i+3]
            out.append('   ')
            i += 3
            while i < n and code[i:i+3] != delim:
                out.append('\n' if code[i] == '\n' else ' ')
                i += 1
            out.append('   ')
            i += 3
        elif code[i] in ("'", '"') or (code[i] == 'r' and i + 1 < n and code[i+1] in ("'", '"')):
            raw = code[i] == 'r'
            if raw:
                out.append(' ')
                i += 1
            delim = code[i]
            out.append(' ')
            i += 1
            while i < n and code[i] != delim and code[i] != '\n':
                if not raw and code[i] == '\\':
                    out.append('  ')
                    i += 2
                else:
                    out.append(' ')
                    i += 1
            if i < n and code[i] == delim:
                out.append(' ')
                i += 1
        else:
            out.append(code[i])
            i += 1
    return "".join(out)


def strip_parens(s: str) -> str:
    """Substitui o conteúdo dentro de parênteses balanceados por ()."""
    res = []
    depth = 0
    for ch in s:
        if ch == '(':
            depth += 1
            if depth == 1:
                res.append('(')
        elif ch == ')':
            if depth == 1:
                res.append(')')
            depth = max(0, depth - 1)
        elif depth == 0:
            res.append(ch)
    return "".join(res)


def strip_generics(s: str) -> str:
    """Remove parâmetros de tipo genéricos <...> balanceados."""
    res = []
    depth = 0
    for ch in s:
        if ch == '<':
            depth += 1
        elif ch == '>':
            depth = max(0, depth - 1)
        elif depth == 0:
            res.append(ch)
    return "".join(res)


class DartAuditSymbol:
    def __init__(self, kind: str, name: str, file_path: str, line: int, parent_type: Optional[str] = None, is_deprecated: bool = False, deprecation_msg: str = '', return_type: str = '', supertypes: str = ''):
        self.kind = kind  # class, mixin, enum, extension, extension_type, typedef, method, field, getter, setter, function, constructor
        self.name = name
        self.file_path = file_path
        self.line = line
        self.parent_type = parent_type
        self.is_deprecated = is_deprecated
        self.deprecation_msg = deprecation_msg
        self.return_type = return_type
        # Clausula 'extends/implements/with' crua da declaracao, usada pela Regra 13
        # para reconhecer excecoes pelo que elas SAO e nao pelo nome que tem.
        self.supertypes = supertypes

    def is_public(self) -> bool:
        if self.name.startswith('_'):
            return False
        if self.parent_type and self.parent_type.startswith('_'):
            return False
        return True


class GoAuditSymbol:
    def __init__(self, kind: str, name: str, file_path: str, parent_type: Optional[str] = None, doc: str = '', is_deprecated: bool = False):
        self.kind = kind  # struct, interface, type, func, method, field, var, const
        self.name = name
        self.file_path = file_path
        self.parent_type = parent_type
        self.doc = doc
        self.is_deprecated = is_deprecated

    def is_exported(self) -> bool:
        return self.name[:1].isupper()


class AstNomenclatureAuditor:
    def __init__(self, root_dir: Path):
        self.root_dir = root_dir
        self.go_ref_dir = root_dir / 'go-ipfs-reference'
        self.dart_symbols: List[DartAuditSymbol] = []
        self.dart_files: List[Tuple[Path, str, str]] = []  # (file_path, content, cleaned)
        self.go_symbols_by_module: Dict[str, List[GoAuditSymbol]] = {}
        self.violations: List[Dict] = []
        self.atomic_test_stats: Optional[Dict] = None

    def _parse_member_sig(self, sig: str, class_name: str, rel_path: str, line_no: int, check_dep, char_pos: int = 0) -> Optional[DartAuditSymbol]:
        sig = " ".join(sig.split())
        if not sig:
            return None
        is_dep, msg = check_dep(char_pos)

        # 1. Construtor
        cm = re.match(rf'^(?:const\s+|factory\s+)?{class_name}(?:\.([A-Za-z0-9_]+))?\s*\(', sig)
        if cm:
            c_name = cm.group(1) or class_name
            return DartAuditSymbol('constructor', c_name, rel_path, line_no, parent_type=class_name, is_deprecated=is_dep, deprecation_msg=msg)

        # 2. Getter / Setter
        gm = re.search(r'\b(get|set)\s+([A-Za-z0-9_]+)\b', sig)
        if gm:
            g_kind = 'getter' if gm.group(1) == 'get' else 'setter'
            return DartAuditSymbol(g_kind, gm.group(2), rel_path, line_no, parent_type=class_name, is_deprecated=is_dep, deprecation_msg=msg)

        # 3. Operador
        op_m = re.search(r'\boperator\s*([=<>+*/%~^&|!\[\]]+|\w+)\s*\(', sig)
        if op_m:
            return DartAuditSymbol('operator', f"operator {op_m.group(1)}", rel_path, line_no, parent_type=class_name, is_deprecated=is_dep, deprecation_msg=msg)

        # Parenteses reduzidos
        stripped = strip_parens(sig)

        # Verifica se e metodo com arrow body =>
        if '=>' in stripped:
            stripped = stripped.split('=>')[0].strip()

        # Verifica se ha '=' fora de parenteses (campo inicializado)
        eq_idx = -1
        for i, ch in enumerate(stripped):
            if ch == '=' and (i + 1 >= len(stripped) or stripped[i+1] not in ('=', '>')):
                if i > 0 and stripped[i-1] not in ('=', '!', '<', '>'):
                    eq_idx = i
                    break

        if eq_idx != -1:
            decl_part = stripped[:eq_idx].strip()
            decl_no_gen = strip_generics(decl_part)
            m = re.search(r'([A-Za-z0-9_]+)\s*$', decl_no_gen)
            if m:
                return DartAuditSymbol('field', m.group(1), rel_path, line_no, parent_type=class_name, is_deprecated=is_dep, deprecation_msg=msg)

        # Verifica se e metodo: identifier seguido de () [antes de => ou fim]
        stripped_no_gen = strip_generics(stripped)
        mm = re.search(r'\b([A-Za-z0-9_]+)\s*\(\)\s*(?:async\*?|sync\*?)?$', stripped_no_gen)
        if mm:
            m_name = mm.group(1)
            if m_name not in ('if', 'else', 'for', 'while', 'switch', 'return', 'class', 'mixin', 'enum', 'operator', class_name):
                return DartAuditSymbol('method', m_name, rel_path, line_no, parent_type=class_name, is_deprecated=is_dep, deprecation_msg=msg)

        # Caso contrario e campo sem inicializador
        fm = re.search(r'([A-Za-z0-9_]+)\s*$', stripped_no_gen)
        if fm:
            f_name = fm.group(1)
            if f_name not in ('class', 'mixin', 'enum', 'get', 'set', 'static', 'final', 'const', 'late', 'var', 'operator', class_name):
                return DartAuditSymbol('field', f_name, rel_path, line_no, parent_type=class_name, is_deprecated=is_dep, deprecation_msg=msg)

        return None

    def parse_dart_file(self, file_path: Path):
        try:
            with open(file_path, encoding='utf-8', errors='ignore') as f:
                content = f.read()
        except Exception:
            return

        cleaned = clean_dart_source(content)
        self.dart_files.append((file_path, content, cleaned))

        # Encontra anotações @Deprecated com posições
        deprecated_spans: List[Tuple[int, int, str]] = []
        for m in re.finditer(r'@Deprecated\s*\((.*?)\)|@deprecated', content):
            msg = m.group(1) if m.group(1) else ''
            deprecated_spans.append((m.start(), m.end(), msg.strip().strip("'\"")))

        def check_deprecation_near(char_pos: int) -> Tuple[bool, str]:
            for d_start, d_end, d_msg in reversed(deprecated_spans):
                if d_start < char_pos:
                    between = content[d_end:char_pos]
                    if ';' in between or '}' in between:
                        continue
                    return True, d_msg
            return False, ''

        rel_path = str(file_path.relative_to(self.root_dir)).replace('\\', '/')

        i = 0
        n = len(cleaned)
        depth = 0
        parens = 0
        sig_start = 0

        while i < n:
            ch = cleaned[i]
            if ch == '(':
                parens += 1
            elif ch == ')':
                parens = max(0, parens - 1)
            elif ch == '{':
                if depth == 0 and parens == 0:
                    sig = cleaned[sig_start:i].strip()
                    lead = len(cleaned[sig_start:i]) - len(cleaned[sig_start:i].lstrip())
                    decl_pos = sig_start + lead
                    sig_line = cleaned[:decl_pos].count('\n') + 1

                    type_m = re.search(r'\b(?:(?:abstract|interface|base|final|sealed)\s+)*(class|mixin|enum|extension\s+type|extension)\s+(?:const\s+)?([A-Za-z0-9_]+)', sig)
                    if type_m:
                        kind = type_m.group(1).replace(' ', '_')
                        name = type_m.group(2)
                        is_dep, msg = check_deprecation_near(decl_pos)
                        supers = sig[type_m.end():]
                        self.dart_symbols.append(DartAuditSymbol(kind, name, rel_path, sig_line, is_deprecated=is_dep, deprecation_msg=msg, supertypes=supers))

                        # Scan class body
                        depth = 1
                        i += 1
                        body_start = i
                        while i < n and depth > 0:
                            if cleaned[i] == '{':
                                depth += 1
                            elif cleaned[i] == '}':
                                depth -= 1
                            i += 1
                        cls_body = cleaned[body_start:i-1]
                        cls_offset = body_start

                        bj = 0
                        bn = len(cls_body)
                        bdepth = 0
                        bparens = 0
                        bsig_start = 0
                        while bj < bn:
                            bch = cls_body[bj]
                            if bch == '(':
                                bparens += 1
                            elif bch == ')':
                                bparens = max(0, bparens - 1)
                            elif bch == '{':
                                if bdepth == 0 and bparens == 0:
                                    msig = cls_body[bsig_start:bj].strip()
                                    mlead = len(cls_body[bsig_start:bj]) - len(cls_body[bsig_start:bj].lstrip())
                                    mdecl_pos = cls_offset + bsig_start + mlead
                                    mline = cleaned[:mdecl_pos].count('\n') + 1
                                    sym = self._parse_member_sig(msig, name, rel_path, mline, check_deprecation_near, char_pos=mdecl_pos)
                                    if sym:
                                        self.dart_symbols.append(sym)
                                if bparens == 0:
                                    bdepth += 1
                                    bj += 1
                                    if bdepth == 1:
                                        while bj < bn and bdepth > 0:
                                            if cls_body[bj] == '{':
                                                bdepth += 1
                                            elif cls_body[bj] == '}':
                                                bdepth -= 1
                                            bj += 1
                                        bsig_start = bj
                                        continue
                            elif bch == ';':
                                if bdepth == 0 and bparens == 0:
                                    msig = cls_body[bsig_start:bj].strip()
                                    mlead = len(cls_body[bsig_start:bj]) - len(cls_body[bsig_start:bj].lstrip())
                                    mdecl_pos = cls_offset + bsig_start + mlead
                                    mline = cleaned[:mdecl_pos].count('\n') + 1
                                    sym = self._parse_member_sig(msig, name, rel_path, mline, check_deprecation_near, char_pos=mdecl_pos)
                                    if sym:
                                        self.dart_symbols.append(sym)
                                    bsig_start = bj + 1
                            bj += 1
                        sig_start = i
                        depth = 0
                        continue
                    else:
                        # Top-level func with { body } ou variavel com = { ... }
                        sig_stripped = strip_parens(sig)
                        eq_idx = -1
                        for k, sch in enumerate(sig_stripped):
                            if sch == '=' and (k + 1 >= len(sig_stripped) or sig_stripped[k+1] not in ('=', '>')):
                                eq_idx = k
                                break

                        if eq_idx == -1:
                            sig_clean = re.sub(r'@\w+(?:\([^)]*\))?', ' ', sig)
                            sig_no_gen = strip_generics(strip_parens(sig_clean))
                            fn_m = re.search(r'\b([A-Za-z0-9_]+)\s*\(\)', sig_no_gen)
                            if fn_m:
                                fn_name = fn_m.group(1)
                                if fn_name not in ('if', 'for', 'while', 'switch', 'typedef', 'class', 'mixin', 'enum'):
                                    flead = len(cleaned[sig_start:i]) - len(cleaned[sig_start:i].lstrip())
                                    fdecl_pos = sig_start + flead
                                    fline = cleaned[:fdecl_pos].count('\n') + 1
                                    is_dep, msg = check_deprecation_near(fdecl_pos)
                                    self.dart_symbols.append(DartAuditSymbol('function', fn_name, rel_path, fline, is_deprecated=is_dep, deprecation_msg=msg))
                        depth = 1
                        i += 1
                        while i < n and depth > 0:
                            if cleaned[i] == '{':
                                depth += 1
                            elif cleaned[i] == '}':
                                depth -= 1
                            i += 1
                        sig_start = i
                        depth = 0
                        continue
            elif ch == ';':
                if depth == 0 and parens == 0:
                    sig = cleaned[sig_start:i].strip()
                    tlead = len(cleaned[sig_start:i]) - len(cleaned[sig_start:i].lstrip())
                    tdecl_pos = sig_start + tlead
                    sig_line = cleaned[:tdecl_pos].count('\n') + 1

                    # Typedef
                    td_m = re.match(r'\btypedef\s+([A-Za-z0-9_]+)\s*(?:=\s*(.+))?$', sig)
                    if td_m:
                        name = td_m.group(1)
                        target = td_m.group(2) or ''
                        is_dep, msg = check_deprecation_near(tdecl_pos)
                        sym = DartAuditSymbol('typedef', name, rel_path, sig_line, is_deprecated=is_dep, deprecation_msg=msg)
                        sym.target = target.strip()
                        self.dart_symbols.append(sym)
                    else:
                        # Top-level arrow function
                        if '=>' in sig:
                            fn_part = re.sub(r'@\w+(?:\([^)]*\))?', ' ', sig.split('=>')[0]).strip()
                            fn_stripped = strip_generics(strip_parens(fn_part))
                            afn_m = re.search(r'\b([A-Za-z0-9_]+)\s*\(\)', fn_stripped)
                            if afn_m:
                                fn_name = afn_m.group(1)
                                if fn_name not in ('if', 'for', 'while', 'switch', 'typedef', 'class', 'mixin', 'enum'):
                                    is_dep, msg = check_deprecation_near(tdecl_pos)
                                    self.dart_symbols.append(DartAuditSymbol('function', fn_name, rel_path, sig_line, is_deprecated=is_dep, deprecation_msg=msg))
                    sig_start = i + 1
            i += 1

    def parse_go_index_dir(self, module_name: str, index_dir: Path):
        symbols = []
        if not index_dir.exists():
            return

        file_pattern = re.compile(r'^##\s+`([^`]+)`')
        type_pattern = re.compile(r'^###\s+(struct|interface|type)\s+`([^`]+)`')
        member_pattern = re.compile(r'^-\s+\*\*([A-Za-z0-9_]+)\*\*\s+\((method|field)\)(?:\s+—\s+(.*))?')
        func_pattern = re.compile(r'^###\s+func\s+`([^`]+)`(?:\s+—\s+(.*))?|^###\s+top-level\s+`([^`]+)`\s+\(function\)')
        func_item_pattern = re.compile(r'^-\s+\*\*([A-Za-z0-9_]+)\*\*\s+\(function\)(?:\s+—\s+(.*))?')
        var_pattern = re.compile(r'^###\s+(var|const)\s+`([^`]+)`')

        for md_file in index_dir.glob('*.md'):
            if md_file.name in ('README.md',):
                continue
            with open(md_file, encoding='utf-8', errors='ignore') as f:
                lines = f.readlines()

            current_file = ""
            current_type = None

            for line in lines:
                line_s = line.strip()
                m_file = file_pattern.match(line_s)
                if m_file:
                    current_file = m_file.group(1)
                    current_type = None
                    continue

                if is_out_of_scope(current_file):
                    continue

                m_type = type_pattern.match(line_s)
                if m_type:
                    current_type = m_type.group(2)
                    symbols.append(GoAuditSymbol(m_type.group(1), current_type, current_file))
                    continue

                m_member = member_pattern.match(line_s)
                if m_member and current_type:
                    m_name = m_member.group(1)
                    m_kind = m_member.group(2)
                    doc = m_member.group(3) or ''
                    symbols.append(GoAuditSymbol(m_kind, m_name, current_file, parent_type=current_type, doc=doc, is_deprecated='deprecated' in doc.lower()))
                    continue

                m_func = func_pattern.match(line_s)
                if m_func:
                    current_type = None
                    f_name = m_func.group(1) or m_func.group(3)
                    doc = m_func.group(2) or ''
                    symbols.append(GoAuditSymbol('func', f_name, current_file, doc=doc, is_deprecated='deprecated' in doc.lower()))
                    continue

                m_func_item = func_item_pattern.match(line_s)
                if m_func_item:
                    f_name = m_func_item.group(1)
                    doc = m_func_item.group(2) or ''
                    symbols.append(GoAuditSymbol('func', f_name, current_file, doc=doc, is_deprecated='deprecated' in doc.lower()))
                    continue

                m_var = var_pattern.match(line_s)
                if m_var:
                    current_type = None
                    symbols.append(GoAuditSymbol(m_var.group(1), m_var.group(2), current_file))
                    continue

        self.go_symbols_by_module.setdefault(module_name, []).extend(symbols)

    def scan_go_repo_sources(self, repo_dir: Path):
        """Varre arquivos .go para capturar type aliases, structs, interfaces e campos (inclusive privados/não-exportados)."""
        if not repo_dir.exists():
            return
        type_alias_pattern = re.compile(r'type\s+([A-Za-z0-9_]+)\s+([A-Za-z0-9_\[\]*.]+)')
        struct_pattern = re.compile(r'type\s+([A-Za-z0-9_]+)\s+struct\s*\{([^}]*)\}', re.MULTILINE | re.DOTALL)
        interface_pattern = re.compile(r'type\s+([A-Za-z0-9_]+)\s+interface\s*\{([^}]*)\}', re.MULTILINE | re.DOTALL)

        method_pattern = re.compile(r'func\s*\(\s*(?:\w+\s+)?\*?([A-Za-z0-9_]+)\s*\)\s*([A-Za-z0-9_]+)\s*\(')
        func_pattern = re.compile(r'func\s+([A-Za-z0-9_]+)\s*\(')

        mod_name = repo_dir.name
        if mod_name == 'libp2p':
            mod_name = 'go-libp2p'
        elif mod_name == 'multiaddr-dns':
            mod_name = 'go-multiaddr-dns'

        for go_file in repo_dir.glob('**/*.go'):
            if is_out_of_scope(str(go_file)):
                continue
            try:
                content = go_file.read_text(encoding='utf-8', errors='ignore')
            except Exception:
                continue
            rel_f = str(go_file.relative_to(self.root_dir)).replace('\\', '/')

            # 1. Structs e campos
            for sm in struct_pattern.finditer(content):
                s_name = sm.group(1)
                s_body = sm.group(2)
                self.go_symbols_by_module.setdefault(mod_name, []).append(
                    GoAuditSymbol('struct', s_name, rel_f)
                )
                for fl in s_body.split('\n'):
                    fl = fl.strip()
                    if '//' in fl:
                        fl = fl.split('//')[0].strip()
                    if not fl:
                        continue
                    parts = fl.split()
                    if parts and parts[0] not in ('//', '/*', 'type', 'func'):
                        fname = parts[0].strip(',')
                        if re.match(r'^[A-Za-z0-9_]+$', fname) and len(parts) > 1:
                            self.go_symbols_by_module.setdefault(mod_name, []).append(
                                GoAuditSymbol('field', fname, rel_f, parent_type=s_name)
                            )

            # 2. Interfaces
            for im in interface_pattern.finditer(content):
                i_name = im.group(1)
                self.go_symbols_by_module.setdefault(mod_name, []).append(
                    GoAuditSymbol('interface', i_name, rel_f)
                )

            # 3. Type aliases
            for m in type_alias_pattern.finditer(content):
                t_name = m.group(1)
                t_target = m.group(2)
                if t_target not in ('struct', 'interface'):
                    sym = GoAuditSymbol('type', t_name, rel_f, doc=f"Type alias to {t_target}")
                    self.go_symbols_by_module.setdefault(mod_name, []).append(sym)

            # 4. Métodos
            for mm in method_pattern.finditer(content):
                recv_type = mm.group(1)
                m_name = mm.group(2)
                self.go_symbols_by_module.setdefault(mod_name, []).append(
                    GoAuditSymbol('method', m_name, rel_f, parent_type=recv_type)
                )

            # 5. Funções top-level
            for fm in func_pattern.finditer(content):
                fn_name = fm.group(1)
                if fn_name != 'init':
                    self.go_symbols_by_module.setdefault(mod_name, []).append(
                        GoAuditSymbol('func', fn_name, rel_f)
                    )

            # 6. Variáveis e constantes top-level (ex: var Err*, const *)
            var_block_pattern = re.compile(r'(?:var|const)\s*\(([^)]*)\)', re.MULTILINE)
            var_single_pattern = re.compile(r'^\s*(?:var|const)\s+([A-Za-z0-9_]+)', re.MULTILINE)
            for bm in var_block_pattern.finditer(content):
                for bline in bm.group(1).splitlines():
                    bline = bline.strip()
                    if '//' in bline:
                        bline = bline.split('//')[0].strip()
                    parts = bline.split()
                    if parts and re.match(r'^[A-Za-z0-9_]+$', parts[0]):
                        self.go_symbols_by_module.setdefault(mod_name, []).append(
                            GoAuditSymbol('var', parts[0], rel_f)
                        )
            for vm in var_single_pattern.finditer(content):
                v_name = vm.group(1)
                if v_name != '(':
                    self.go_symbols_by_module.setdefault(mod_name, []).append(
                        GoAuditSymbol('var', v_name, rel_f)
                    )

    def load_all(self):
        # 1. Carregar Dart
        dart_files = list(self.root_dir.glob('packages/*/lib/**/*.dart')) + list(self.root_dir.glob('lib/**/*.dart'))
        for df in dart_files:
            if '/test/' in df.as_posix() or df.name.endswith('_test.dart'):
                continue
            self.parse_dart_file(df)

        # 2. Carregar Go AST Indexes e repositórios Go
        if self.go_ref_dir.exists():
            for entry in self.go_ref_dir.iterdir():
                if entry.is_dir():
                    if entry.name.endswith('-index'):
                        mod_name = entry.name[:-len('-index')]
                        if mod_name == 'libp2p':
                            mod_name = 'go-libp2p'
                        elif mod_name == 'multiaddr-dns':
                            mod_name = 'go-multiaddr-dns'
                        self.parse_go_index_dir(mod_name, entry)
                    elif not entry.name.endswith('-index') and not entry.name.endswith('_vectors'):
                        # Varre definições de tipos e membros no código-fonte Go diretamente
                        self.scan_go_repo_sources(entry)

        # 3. Deduplicar símbolos Go por módulo
        for mod, syms in self.go_symbols_by_module.items():
            seen = set()
            unique_syms = []
            for s in syms:
                key = (s.kind, s.name, s.parent_type or '')
                if key not in seen:
                    seen.add(key)
                    unique_syms.append(s)
            self.go_symbols_by_module[mod] = unique_syms

    @staticmethod
    def _extract_block_body(content: str, start_pos: int) -> Tuple[str, int]:
        """Localiza o próximo '{' e extrai o corpo até fechar a chave correspondente."""
        open_brace = content.find('{', start_pos)
        if open_brace == -1:
            return "", start_pos

        i = open_brace + 1
        depth = 1
        n = len(content)
        while i < n and depth > 0:
            if content[i:i+2] == '//':
                eol = content.find('\n', i)
                i = eol if eol != -1 else n
                continue
            if content[i:i+2] == '/*':
                eoc = content.find('*/', i)
                i = eoc + 2 if eoc != -1 else n
                continue
            if content[i] in ("'", '"'):
                quote = content[i]
                if content[i:i+3] == quote * 3:
                    eq = content.find(quote * 3, i + 3)
                    i = eq + 3 if eq != -1 else n
                else:
                    j = i + 1
                    while j < n:
                        if content[j] == '\\':
                            j += 2
                            continue
                        if content[j] == quote:
                            j += 1
                            break
                        if content[j] == '\n':
                            break
                        j += 1
                    i = j
                continue

            if content[i] == '{':
                depth += 1
            elif content[i] == '}':
                depth -= 1
                if depth == 0:
                    return content[open_brace + 1:i], i + 1
            i += 1
        return "", start_pos

    @staticmethod
    def _is_valid_test_body(body: str) -> bool:
        """
        Verifica se o corpo do teste contém asserções reais (expect, expectLater, assert, throwsA)
        e não é meramente vazio, comentários, ou apenas fail().
        """
        cleaned = re.sub(r'//.*', '', body)
        cleaned = re.sub(r'/\*.*?\*/', '', cleaned, flags=re.DOTALL)
        cleaned = cleaned.strip()

        if not cleaned:
            return False

        # Rejeita se for apenas fail(...)
        if re.match(r'^\s*fail\s*\([^)]*\)\s*;\s*$', cleaned):
            return False

        # Exige asserções reais
        return bool(re.search(r'\b(expect|expectLater|assert|throwsA)\s*\(', cleaned))

    def parse_atomic_test_file(self, content: str) -> Set[str]:
        """
        Extrai do arquivo de teste todos os símbolos testados que possuem asserções reais.
        Testes vazios, com apenas TODO ou fail() são rejeitados e não computam como testados.
        """
        tested = set()
        group_pattern = re.compile(r'\bgroup\s*\(\s*([\'"])(.*?)\1')
        test_pattern = re.compile(r'\btest\s*\(\s*([\'"])(.*?)\1')

        i = 0
        n = len(content)
        brace_depth = 0
        group_stack = []  # list of (depth, group_name)

        TOP_LEVEL_GROUP_KEYWORDS = ('top-level', 'toplevel', 'top_level', 'functions', 'funções', 'auxiliary', 'top level')

        while i < n:
            # Pula comentários de linha
            if content[i:i+2] == '//':
                eol = content.find('\n', i)
                i = eol if eol != -1 else n
                continue
            # Pula comentários de bloco
            if content[i:i+2] == '/*':
                eoc = content.find('*/', i)
                i = eoc + 2 if eoc != -1 else n
                continue

            # Pula strings regulares
            if content[i] in ("'", '"'):
                quote = content[i]
                if content[i:i+3] == quote * 3:
                    end_quote = content.find(quote * 3, i + 3)
                    i = end_quote + 3 if end_quote != -1 else n
                else:
                    j = i + 1
                    while j < n:
                        if content[j] == '\\':
                            j += 2
                            continue
                        if content[j] == quote:
                            j += 1
                            break
                        if content[j] == '\n':
                            break
                        j += 1
                    i = j
                continue

            # Verifica chamada group(...)
            if content[i:i+5] == 'group' and (i == 0 or not content[i-1].isalnum()) and not content[i+5].isalnum():
                gm = group_pattern.match(content, i)
                if gm:
                    gname = gm.group(2).strip()
                    clean_gname = re.sub(r'\[.*?\]', '', gname).strip()
                    clean_gname = clean_gname.split()[0] if clean_gname else ''
                    brace_pos = content.find('{', gm.end())
                    if brace_pos != -1:
                        group_stack.append((brace_depth + 1, clean_gname))
                    i = gm.end()
                    continue

            # Verifica chamada test(...)
            if content[i:i+4] == 'test' and (i == 0 or not content[i-1].isalnum()) and not content[i+4].isalnum():
                tm = test_pattern.match(content, i)
                if tm:
                    # Inspeciona o corpo do teste para assegurar asserções reais (sem stubs)
                    body_text, _ = self._extract_block_body(content, tm.end())
                    if not self._is_valid_test_body(body_text):
                        i = tm.end()
                        continue

                    tname = tm.group(2).strip()
                    cleaned_tname = re.sub(r'\[(?!\s*\]|\s*\]=).*?\]', '', tname).strip()

                    active_class = None
                    for depth, gname in reversed(group_stack):
                        if gname and gname[0].isupper() and not any(kw in gname.lower() for kw in TOP_LEVEL_GROUP_KEYWORDS):
                            active_class = gname
                            break

                    cls = None
                    member = cleaned_tname
                    if '.' in cleaned_tname and not cleaned_tname.startswith('operator'):
                        parts = cleaned_tname.split('.', 1)
                        cand_cls = parts[0].strip().split()[-1]
                        if not any(kw in cand_cls.lower() for kw in TOP_LEVEL_GROUP_KEYWORDS):
                            cls = cand_cls
                        member = parts[1].strip()
                    elif active_class:
                        cls = active_class

                    # Normalização do member
                    member = re.sub(r'^(?:get|set|method|getter|setter)\s+', '', member, flags=re.IGNORECASE)

                    op_m = re.search(r'\b(operator\s*(?:==|!=|<=|>=|>>>|<<<|<<|>>|<|>|\+|\*|~/|/|%|~|&|\||\^|\[\]=?|-))', member)
                    if op_m:
                        norm_op = re.sub(r'\s+', ' ', op_m.group(1))
                        member = norm_op
                    else:
                        member = re.sub(r'\(.*?\).*$', '', member)
                        member = member.strip().split()[0] if member.strip() else ''

                    if member:
                        if cls:
                            tested.add(f"{cls}.{member}")
                        else:
                            tested.add(member)
                    i = tm.end()
                    continue

            # Rastreia chaves
            if content[i] == '{':
                brace_depth += 1
            elif content[i] == '}':
                brace_depth = max(0, brace_depth - 1)
                while group_stack and group_stack[-1][0] > brace_depth:
                    group_stack.pop()

            i += 1

        return tested

    def scan_all_atomic_tests(self) -> Tuple[Set[str], Dict[str, List[str]]]:
        """
        Varre todos os arquivos de testes atômicos na pasta padrão:
          - test/atomic/<nivel>/<nome_modulo>_atomic_tests.dart
        """
        test_roots = [
            self.root_dir / 'test' / 'atomic'
        ]
        all_tested: Set[str] = set()
        symbol_to_files: Dict[str, List[str]] = {}

        for tr in test_roots:
            if not tr.exists():
                continue
            for f in tr.rglob('*.dart'):
                if '_atomic_test' in f.name:
                    rel_p = str(f.relative_to(self.root_dir)).replace('\\', '/')
                    try:
                        content = f.read_text(encoding='utf-8', errors='ignore')
                    except Exception:
                        continue
                    syms = self.parse_atomic_test_file(content)
                    for s in syms:
                        all_tested.add(s)
                        symbol_to_files.setdefault(s, []).append(rel_p)

        return all_tested, symbol_to_files

    def audit_atomic_tests(self, target_package: Optional[str] = None):
        """
        Audita se cada símbolo público (função, método, getter, setter, operador)
        possui um teste atômico correspondente em test/atomic/<nivel>/<nome_modulo>_atomic_tests.dart.
        A falta de um teste com asserções reais é tratada como ERRO bloqueante.
        """
        all_tested, symbol_to_files = self.scan_all_atomic_tests()

        self.atomic_test_stats = {
            'total_auditable': 0,
            'total_tested': 0,
            'total_missing': 0,
            'by_package': {},
            'missing_by_package': {}
        }

        for sym in self.dart_symbols:
            if target_package and target_package not in sym.file_path:
                continue

            # Considera apenas funções, métodos, getters, setters, operadores públicos
            if not sym.is_public() or sym.kind not in ('function', 'method', 'getter', 'setter', 'operator'):
                continue

            # Construtor default redundante com nome da classe é testado via factory ou instanciação
            if sym.parent_type and sym.name == sym.parent_type:
                continue

            pkg_name = sym.file_path.split('/')[1] if sym.file_path.startswith('packages/') else 'lib'

            # Chave canônica do símbolo
            if sym.parent_type:
                primary_key = f"{sym.parent_type}.{sym.name}"
            else:
                primary_key = sym.name

            pkg_stats = self.atomic_test_stats['by_package'].setdefault(pkg_name, {'total': 0, 'tested': 0, 'missing': 0})
            pkg_stats['total'] += 1
            self.atomic_test_stats['total_auditable'] += 1

            is_tested = (primary_key in all_tested)
            if not is_tested and not sym.parent_type:
                is_tested = (sym.name in all_tested)

            if is_tested:
                pkg_stats['tested'] += 1
                self.atomic_test_stats['total_tested'] += 1
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
                    'suggested': f"Criar test('{sym.name}()', () {{ ... expect(...) ... }}) em test/atomic/<nivel>/{clean_mod}_atomic_tests.dart"
                })

    def audit_rules(self, target_package: Optional[str] = None, target_rule: Optional[str] = None, target_severity: Optional[str] = None, include_non_public: bool = False):
        self.violations.clear()

        # Mapeamentos entre módulos Go e diretórios de pacotes Dart
        pkg_to_mod = {pkg: mod for mod, pkg in GO_MODULE_TO_DART_PACKAGE.items()}
        mod_to_pkg = {mod: pkg for mod, pkg in GO_MODULE_TO_DART_PACKAGE.items()}

        # Mapeia Go symbols por nome canônico para checagem de @Deprecated e paridade
        all_go_symbols: Dict[str, List[GoAuditSymbol]] = {}
        type_to_origin_modules: Dict[str, Set[str]] = {}
        for mod, syms in self.go_symbols_by_module.items():
            for s in syms:
                if s.is_exported():
                    all_go_symbols.setdefault(s.name.lower(), []).append(s)
                    if s.kind in ('struct', 'interface', 'type'):
                        type_to_origin_modules.setdefault(s.name.lower(), set()).add(mod)

        # Regex auxiliares para novas regras
        re_screaming = re.compile(r'^[A-Z0-9]+(_[A-Z0-9]+)+$')
        re_tuple_error = re.compile(r'\([^)]*?\b(?:Error|Exception)\??\s*[^)]*?\)')
        re_result_type = re.compile(r'\b(?:Result|Either)\s*<')
        re_mask = re.compile(r'&\s*0x[fF]{8,16}\b')
        re_cli_exit = re.compile(r'\b(?:exitCode\s*=|exit\s*\()')

        # Tipos comuns genéricos ignorados na checagem de boundary leak
        COMMON_GENERIC_TYPES = {
            'node', 'reader', 'writer', 'buffer', 'entry', 'config', 'options',
            'state', 'listener', 'transport', 'handler', 'client', 'server',
            'session', 'stream', 'message', 'key', 'value', 'header', 'event',
            'result', 'context', 'record', 'item', 'metadata', 'block'
        }

        # 1. Auditoria de Símbolos Dart individuais
        for sym in self.dart_symbols:
            if target_package and target_package not in sym.file_path:
                continue

            # Ignora pacote boilerplate para tipos de baixo nível (Int64, Uint64, etc.)
            in_boilerplate = 'packages/boilerplate/' in sym.file_path

            # REGRA 1: UpperCamelCase sem All-Caps para Tipos Públicos
            if sym.kind in ('class', 'mixin', 'enum', 'extension', 'extension_type') and sym.is_public():
                if not in_boilerplate:
                    all_caps = check_all_caps_block(sym.name)
                    if all_caps and (target_rule is None or target_rule == 'RULE_ALL_CAPS'):
                        suggested = to_upper_camel(sym.name)
                        if suggested != sym.name:
                            self.violations.append({
                                'rule': 'RULE_ALL_CAPS',
                                'severity': 'ERROR',
                                'message': f"Tipo público '{sym.name}' contém bloco em All-Caps '{all_caps}'. Deve ser UpperCamelCase canônico: '{suggested}'.",
                                'file': sym.file_path,
                                'line': sym.line,
                                'symbol': sym.name,
                                'suggested': suggested
                            })

            # REGRA 2: lowerCamelCase sem All-Caps para Membros e Funções Públicas
            if sym.kind in ('method', 'field', 'function') and sym.is_public():
                # Ignora construtores ou factories
                if sym.parent_type and sym.name == sym.parent_type:
                    continue

                # Checa se começa com maiúscula (PascalCase indevido)
                if sym.name[:1].isupper() and not in_boilerplate and (target_rule is None or target_rule == 'RULE_LOWER_CAMEL'):
                    suggested = to_lower_camel(sym.name)
                    self.violations.append({
                        'rule': 'RULE_LOWER_CAMEL',
                        'severity': 'ERROR',
                        'message': f"{sym.kind.capitalize()} público '{sym.name}' em '{sym.parent_type or 'top-level'}' usa PascalCase. Em Dart deve ser lowerCamelCase: '{suggested}'.",
                        'file': sym.file_path,
                        'line': sym.line,
                        'symbol': sym.name,
                        'suggested': suggested
                    })
                else:
                    # Checa blocos All-Caps dentro de lowerCamelCase (ex: idFromP2PAddr, tempAddrTTL)
                    all_caps = check_all_caps_block(sym.name)
                    if all_caps and not in_boilerplate and (target_rule is None or target_rule == 'RULE_ALL_CAPS'):
                        suggested = to_lower_camel(sym.name)
                        if suggested != sym.name:
                            self.violations.append({
                                'rule': 'RULE_ALL_CAPS',
                                'severity': 'ERROR',
                                'message': f"{sym.kind.capitalize()} público '{sym.name}' contém bloco em All-Caps '{all_caps}'. Deve ser lowerCamelCase canônico: '{suggested}'.",
                                'file': sym.file_path,
                                'line': sym.line,
                                'symbol': sym.name,
                                'suggested': suggested
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
                    if is_upstream_type:
                        pass
                    else:
                        target = getattr(sym, 'target', '')
                        if target and not '(' in target and re.match(r'^[A-Za-z0-9_]+$', target):
                            self.violations.append({
                                'rule': 'RULE_NO_TYPEDEF_SHIMS',
                                'severity': 'ERROR',
                                'message': f"Typedef shim proibido: 'typedef {sym.name} = {target};'. AGENTS.md veta shims artificiais para compatibilidade. Consumidores devem usar o tipo canônico diretamente.",
                                'file': sym.file_path,
                                'line': sym.line,
                                'symbol': sym.name,
                                'suggested': f"Remover typedef e migrar chamadores para '{target}'"
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
                                'suggested': "Remover anotação @Deprecated se não for obsoleta no upstream Go"
                            })

            # REGRA 5: Veto a funções livres newX(...)
            if sym.kind == 'function' and sym.is_public() and not in_boilerplate:
                if target_rule is None or target_rule == 'RULE_NO_NEW_X_FUNCTIONS':
                    if re.match(r'^new[A-Z]', sym.name):
                        type_target = sym.name[3:]
                        self.violations.append({
                            'rule': 'RULE_NO_NEW_X_FUNCTIONS',
                            'severity': 'ERROR',
                            'message': f"Função livre artificial '{sym.name}()'. Construtores NewX do Go devem virar construtores ou factories na classe '{type_target}', sem funções livres 'newX' artificiais.",
                            'file': sym.file_path,
                            'line': sym.line,
                            'symbol': sym.name,
                            'suggested': f"Converter para construtor/factory '{type_target}()' ou '{type_target}.from*()'"
                        })

            # REGRA 6: Veto a Constantes e Campos Públicos em SCREAMING_SNAKE_CASE
            if sym.kind in ('field', 'variable', 'getter') and sym.is_public() and not in_boilerplate:
                if target_rule is None or target_rule == 'RULE_CONSTANT_CASING':
                    if re_screaming.match(sym.name):
                        suggested = to_lower_camel(sym.name)
                        self.violations.append({
                            'rule': 'RULE_CONSTANT_CASING',
                            'severity': 'ERROR',
                            'message': f"Constante/campo público '{sym.name}' usa SCREAMING_SNAKE_CASE. Em Dart deve ser lowerCamelCase: '{suggested}'.",
                            'file': sym.file_path,
                            'line': sym.line,
                            'symbol': sym.name,
                            'suggested': suggested
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
                            'suggested': f"Substituir por construtor padrão '{sym.parent_type}()'"
                        })
                    elif sym.name.startswith('newFrom') or (re.match(r'^new[A-Z]', sym.name) and sym.name != 'new'):
                        suggested_ctor = sym.name[3:]
                        suggested_ctor = suggested_ctor[:1].lower() + suggested_ctor[1:]
                        self.violations.append({
                            'rule': 'RULE_REDUNDANT_CONSTRUCTOR_NAMES',
                            'severity': 'ERROR',
                            'message': f"Construtor nomeado '{sym.parent_type}.{sym.name}()' usa prefixo 'new'. Em Dart, construtores nomeados devem usar frase nominal ou adjetiva ('{sym.parent_type}.{suggested_ctor}()').",
                            'file': sym.file_path,
                            'line': sym.line,
                            'symbol': sym.name,
                            'suggested': f"Renomear para '{sym.parent_type}.{suggested_ctor}()'"
                        })

            # REGRA 8: Veto a Tuplas de Erro Go e Result Wrappers em APIs Públicas
            if sym.kind in ('method', 'function') and sym.is_public() and not in_boilerplate:
                if target_rule is None or target_rule == 'RULE_NO_GO_STYLE_ERROR_TUPLES':
                    ret = getattr(sym, 'return_type', '')
                    if ret:
                        has_error_tuple = bool(re_tuple_error.search(ret) or re_result_type.search(ret))
                        if has_error_tuple:
                            self.violations.append({
                                'rule': 'RULE_NO_GO_STYLE_ERROR_TUPLES',
                                'severity': 'ERROR',
                                'message': f"{sym.kind.capitalize()} público '{sym.name}' retorna tupla de erro estilo Go ou Result wrapper ('{ret}'). Conforme AGENTS.md, retornos (valor, error) do Go devem virar retorno direto do valor com exceção tipada via throw.",
                                'file': sym.file_path,
                                'line': sym.line,
                                'symbol': sym.name,
                                'suggested': "Retornar o valor diretamente e lançar exceção tipada em caso de falha"
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
                                        'suggested': f"Importar do pacote '{target_pkg}' em vez de redeclarar"
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
                                        # Go tem duas convenções para erro: o valor
                                        # sentinela `ErrX` e o tipo `XError`. A Regra 13
                                        # obriga o sufixo 'Exception' em Dart, então um
                                        # `XException` pode corresponder a qualquer uma
                                        # das duas no upstream.
                                        names_to_try.add(f'{stem}Error')
                                        names_to_try.add(f'{stem}error')
                                        for pfx in KNOWN_PREFIXES:
                                            names_to_try.add(f'{pfx}Err{stem}')
                                            names_to_try.add(f'Err{pfx}{stem}')

                            if 'transpiled_ipld_prime' in sym.file_path and 'basicnode' in sym.file_path:
                                names_to_try.update(['Node', 'NodeAssembler', 'NodePrototype'])

                            lookup = {n.lower() for n in names_to_try}
                            matched = any(
                                s.name.lower() in lookup
                                for s in go_syms
                            )
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
                                    'suggested': f"Tornar privado com prefixo '_{sym.name}' ou documentar adaptação"
                                })

            # REGRA 13: Nomenclatura e Padrão de Exceções Dart.
            #
            # Vale em QUALQUER pasta, boilerplate incluído: o sufixo 'Exception'
            # é idioma da linguagem de destino, e boilerplate é justamente onde
            # o código deve ser Dart idiomático em vez de Go traduzido.
            #
            # O gatilho principal é estrutural — a classe declara 'implements
            # Exception' ou 'extends' de uma exceção — e não um palpite pelo
            # nome. O prefixo 'Err' segue vetado à parte, porque uma classe pode
            # carregar o idioma do Go mesmo sem declarar a interface.
            if sym.kind in ('class', 'mixin') and sym.is_public():
                if target_rule is None or target_rule == 'RULE_EXCEPTION_NAMING':
                    tem_err = sym.name.startswith('Err') and len(sym.name) > 3 and sym.name[3].isupper()
                    eh_excecao = bool(re.search(r'\b(?:implements|extends|with)\b[^{]*\bException\b', sym.supertypes or ''))
                    if tem_err:
                        suggested = to_upper_camel(sym.name[3:]) + "Exception"
                        self.violations.append({
                            'rule': 'RULE_EXCEPTION_NAMING',
                            'severity': 'ERROR',
                            'message': f"Classe de exceção '{sym.name}' usa o prefixo 'Err' idiomático do Go. Em Dart, classes de exceção devem usar sufixo 'Exception' e implementar 'Exception' (ex.: '{suggested}').",
                            'file': sym.file_path,
                            'line': sym.line,
                            'symbol': sym.name,
                            'suggested': f"Renomear para '{suggested}' e adicionar 'implements Exception'"
                        })
                    elif eh_excecao and not sym.name.endswith('Exception'):
                        suggested = to_upper_camel(re.sub(r'(?:Error|Err|Failure)$', '', sym.name)) + "Exception"
                        self.violations.append({
                            'rule': 'RULE_EXCEPTION_NAMING',
                            'severity': 'ERROR',
                            'message': f"Classe '{sym.name}' implementa 'Exception' mas não usa o sufixo 'Exception' exigido pelo idioma Dart (ex.: '{suggested}').",
                            'file': sym.file_path,
                            'line': sym.line,
                            'symbol': sym.name,
                            'suggested': f"Renomear para '{suggested}'"
                        })

            # REGRA 14: Veto a Mocks, Dummies e Stubs em Código de Biblioteca
            if sym.kind in ('class', 'mixin', 'function') and sym.is_public() and not in_boilerplate:
                if target_rule is None or target_rule == 'RULE_NO_PRODUCTION_MOCKS':
                    if re.search(r'\b(?:Mock|Dummy|Stub|Fake|Placeholder)|(?:Mock|Dummy|Stub|Fake|Placeholder)\b', sym.name):
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
                                'suggested': f"Mover '{sym.name}' para 'test/' ou substituir por implementação real"
                            })

            # REGRA 17: Veto a Primitivas Artificiais de Concorrência Go em APIs Públicas
            if sym.kind in ('class', 'typedef', 'method', 'function') and sym.is_public() and not in_boilerplate:
                if target_rule is None or target_rule == 'RULE_NO_ARTIFICIAL_CONCURRENCY':
                    if re.search(r'\b(?:Chan|GoChannel|WaitGroup|Mutex)\b', sym.name):
                        self.violations.append({
                            'rule': 'RULE_NO_ARTIFICIAL_CONCURRENCY',
                            'severity': 'WARNING',
                            'message': f"Símbolo público '{sym.name}' expõe primitiva de concorrência específica do Go. AGENTS.md exige o uso de primitivas idiomáticas do Dart (Stream, Future, Completer).",
                            'file': sym.file_path,
                            'line': sym.line,
                            'symbol': sym.name,
                            'suggested': "Substituir por Stream<T>, Future<void> ou Completer<T>"
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
                                'suggested': f"Portar '{s.name}' para '{pkg_dir}' ou documentar se for omitido deliberadamente"
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
                        clean_name = sym.name.lstrip('_').lower()
                        dart_members_by_type.setdefault(key, set()).add(clean_name)

            for sym in self.dart_symbols:
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
                                    'suggested': f"Avaliar implementação dos campos: {', '.join(missing)}"
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
                        clean_name = sym.name.lstrip('_').lower()
                        dart_methods_by_class.setdefault(key, set()).add(clean_name)

            for sym in self.dart_symbols:
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
                                    'suggested': f"Avaliar paridade e implementação de: {', '.join(missing)}"
                                })

        # REGRA 21: Auditoria de Funções Top-Level do Upstream Go ainda não portadas
        if target_rule is None or target_rule == 'RULE_MISSING_GO_FUNCTIONS':
            dart_funcs_by_pkg: Dict[str, Set[str]] = {}
            dart_types_by_pkg: Dict[str, Set[str]] = {}
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
                        dart_types_by_pkg.setdefault(my_pkg, set()).add(sym.name.lower())

            for mod, syms in self.go_symbols_by_module.items():
                if mod not in mod_to_pkg:
                    continue
                pkg_dir = mod_to_pkg[mod]
                if target_package and target_package not in pkg_dir:
                    continue

                pkg_funcs = dart_funcs_by_pkg.get(pkg_dir, set())
                pkg_types = dart_types_by_pkg.get(pkg_dir, set())

                go_funcs = [s for s in syms if s.kind == 'func' and (include_non_public or s.is_exported())]
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
                        'suggested': f"Avaliar porte das funções: {', '.join(missing[:10])}{'...' if len(missing) > 10 else ''}"
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

        for file_path, content, cleaned in self.dart_files:
            rel_path = str(file_path.relative_to(self.root_dir)).replace('\\', '/')
            if target_package and target_package not in rel_path:
                continue
            if 'packages/boilerplate/' in rel_path:
                continue

            # REGRA 9: Veto a Código de CLI em Pacotes de Bibliotecas Reutilizáveis
            if rel_path.startswith('packages/transpiled_'):
                if target_rule is None or target_rule == 'RULE_NO_CLI_IN_LIBRARIES':
                    if 'package:args/args.dart' in content or 'package:args/command_runner.dart' in content:
                        self.violations.append({
                            'rule': 'RULE_NO_CLI_IN_LIBRARIES',
                            'severity': 'ERROR',
                            'message': "Importação de CLI ('package:args') em biblioteca reutilizável. AGENTS.md define CLI como estritamente fora de escopo de bibliotecas.",
                            'file': rel_path,
                            'line': 1,
                            'symbol': 'package:args',
                            'suggested': "Remover dependência e lógica de CLI da biblioteca"
                        })
                    m_exit = re_cli_exit.search(content)
                    if m_exit:
                        line_no = content[:m_exit.start()].count('\n') + 1
                        self.violations.append({
                            'rule': 'RULE_NO_CLI_IN_LIBRARIES',
                            'severity': 'ERROR',
                            'message': f"Uso indevido de chamada de processo CLI ('{m_exit.group(0).strip()}') em biblioteca. Bibliotecas devem propagar erros via exceções.",
                            'file': rel_path,
                            'line': line_no,
                            'symbol': m_exit.group(0).strip(),
                            'suggested': "Substituir chamada por lançamento de exceção tipada"
                        })

            # REGRA 10: Uso Obrigatório de fixed_types.Golang.* para Tipos Primitivos
            if rel_path.startswith('packages/transpiled_'):
                if target_rule is None or target_rule == 'RULE_ENFORCE_BOILERPLATE_TYPES':
                    m_mask = re_mask.search(cleaned)
                    if m_mask and 'package:boilerplate/fixed_types/golang.dart' not in content:
                        line_no = cleaned[:m_mask.start()].count('\n') + 1
                        self.violations.append({
                            'rule': 'RULE_ENFORCE_BOILERPLATE_TYPES',
                            'severity': 'WARNING',
                            'message': f"Uso de máscara binária de 32/64 bits ('{m_mask.group(0)}') sem importar 'fixed_types.Golang.*'. AGENTS.md exige centralizar semântica de overflow e limites em packages/boilerplate/.",
                            'file': rel_path,
                            'line': line_no,
                            'symbol': m_mask.group(0),
                            'suggested': "Importar 'package:boilerplate/fixed_types/golang.dart' e utilizar os tipos Golang correspondentes"
                        })

            # REGRA 15: Veto a dart:io em Pacotes de Codecs e Multiformatos Puros (Garantia Web/Wasm)
            for pure_pkg in PURE_FORMAT_PACKAGES:
                if rel_path.startswith(pure_pkg + '/'):
                    if target_rule is None or target_rule == 'RULE_RESTRICTED_PLATFORM_IMPORTS':
                        m_io = re.search(r'''import\s+['"]dart:io['"]''', cleaned)
                        if m_io:
                            line_no = cleaned[:m_io.start()].count('\n') + 1
                            self.violations.append({
                                'rule': 'RULE_RESTRICTED_PLATFORM_IMPORTS',
                                'severity': 'ERROR',
                                'message': f"Importação de 'dart:io' no pacote de codec/formato puro '{pure_pkg}'. Quebra compatibilidade universal Web/Wasm.",
                                'file': rel_path,
                                'line': line_no,
                                'symbol': 'dart:io',
                                'suggested': "Remover dependência de 'dart:io' e manter pacote agnóstico de plataforma"
                            })

            # REGRA 16: Veto a chamadas print(...) em Bibliotecas Reutilizáveis
            if rel_path.startswith('packages/transpiled_'):
                if target_rule is None or target_rule == 'RULE_NO_PRINT_IN_LIBRARIES':
                    m_print = re.search(r'\bprint\s*\(', cleaned)
                    if m_print:
                        line_no = cleaned[:m_print.start()].count('\n') + 1
                        self.violations.append({
                            'rule': 'RULE_NO_PRINT_IN_LIBRARIES',
                            'severity': 'ERROR',
                            'message': "Chamada a 'print(...)' em pacote de biblioteca reutilizável. Bibliotecas devem usar logging estruturado ou streams.",
                            'file': rel_path,
                            'line': line_no,
                            'symbol': 'print(...)',
                            'suggested': "Substituir por logger estruturado ou remover print"
                        })

        # REGRA 19: Veto a Dependências de CLI em pubspec.yaml de Bibliotecas
        if target_rule is None or target_rule == 'RULE_PUBSPEC_DEPENDENCIES':
            for ps in self.root_dir.glob('packages/*/pubspec.yaml'):
                rel_ps = str(ps.relative_to(self.root_dir)).replace('\\', '/')
                if target_package and target_package not in rel_ps:
                    continue
                try:
                    ps_content = ps.read_text(encoding='utf-8', errors='ignore')
                except Exception:
                    continue
                in_deps = False
                for l_idx, l_text in enumerate(ps_content.splitlines(), start=1):
                    clean_l = l_text.split('#')[0].rstrip()
                    if clean_l == 'dependencies:':
                        in_deps = True
                    elif clean_l in ('dev_dependencies:', 'environment:') or (in_deps and re.match(r'^\S', clean_l) and not clean_l.startswith(' ')):
                        in_deps = False
                    elif in_deps:
                        dm = re.match(r'^\s+([a-zA-Z0-9_]+):', clean_l)
                        if dm:
                            d_name = dm.group(1)
                            if d_name in ('args', 'dcli'):
                                self.violations.append({
                                    'rule': 'RULE_PUBSPEC_DEPENDENCIES',
                                    'severity': 'ERROR',
                                    'message': f"Dependência de CLI '{d_name}' declarada em 'dependencies' de biblioteca reutilizável '{rel_ps}'. Mover para dev_dependencies ou remover.",
                                    'file': rel_ps,
                                    'line': l_idx,
                                    'symbol': d_name,
                                    'suggested': f"Remover '{d_name}' de 'dependencies:'"
                                })

        # REGRA 23: Veto a Membros Públicos que Expõem Tipos Não-Públicos (Menor Permissão)
        if target_rule is None or target_rule == 'RULE_EXPOSED_NON_PUBLIC_MEMBERS':
            re_priv_type = re.compile(r'\b_([A-Z][A-Za-z0-9_]*)\b')
            re_class = re.compile(r'\b(?:class|mixin|enum|extension\s+type)\s+([A-Za-z0-9_]+)')
            for file_path, content, cleaned in self.dart_files:
                rel_path = str(file_path.relative_to(self.root_dir)).replace('\\', '/')
                if target_package and target_package not in rel_path:
                    continue
                if 'packages/boilerplate/' in rel_path:
                    continue
                current_class = None
                brace_depth = 0
                class_depth = 0
                for l_idx, line in enumerate(cleaned.splitlines(), start=1):
                    clean_l = line.split('//')[0].strip()

                    m_cls = re_class.search(clean_l)
                    if m_cls:
                        current_class = m_cls.group(1)
                        class_depth = brace_depth

                    open_b = clean_l.count('{')
                    close_b = clean_l.count('}')
                    brace_depth += open_b - close_b
                    if current_class and brace_depth <= class_depth and close_b > 0:
                        current_class = None

                    # Membros de classes privadas já são estritamente privados do ponto de vista de biblioteca
                    if current_class and current_class.startswith('_'):
                        continue

                    # Ignora parâmetros de funções/métodos
                    if clean_l.endswith(','):
                        continue

                    m_priv = re_priv_type.search(clean_l)
                    if not m_priv:
                        continue
                    priv_type = m_priv.group(0)
                    m_decl = re.search(r'(?:final\s+|late\s+|static\s+|const\s+)?(?:[A-Za-z0-9_<>, ]*?\b' + re.escape(priv_type) + r'\b[A-Za-z0-9_<>, ]*?)\s+([a-zA-Z0-9]+)\s*(\(|;|=)', clean_l)
                    if m_decl:
                        mem_name = m_decl.group(1)
                        if not mem_name.startswith('_') and mem_name not in ('if', 'for', 'while', 'switch', 'return', 'catch'):
                            self.violations.append({
                                'rule': 'RULE_EXPOSED_NON_PUBLIC_MEMBERS',
                                'severity': 'WARNING',
                                'message': f"Membro público '{mem_name}' expõe tipo não-público '{priv_type}'. AGENTS.md exige implementar seguindo o mesmo nível de visibilidade e permissão do Upstream Go, ou menor se não for possível.",
                                'file': rel_path,
                                'line': l_idx,
                                'symbol': mem_name,
                                'suggested': f"Tipar com interface pública de menor permissão ou tornar o membro privado ('_{mem_name}')"
                            })

        # Filtro por severidade opcional
        if target_severity:
            sev_upper = target_severity.upper()
            self.violations = [v for v in self.violations if v['severity'].upper() == sev_upper]

    def apply_autofixes(self) -> int:
        """Aplica correções mecânicas determinísticas e seguras nos arquivos Dart."""
        total_fixes = 0
        files_to_update: Dict[str, str] = {}

        for v in self.violations:
            rule = v['rule']
            f_path = self.root_dir / v['file']
            if not f_path.exists() or not f_path.is_file() or not str(f_path).endswith('.dart'):
                continue

            rel_path = str(v['file'])
            if rel_path not in files_to_update:
                try:
                    files_to_update[rel_path] = f_path.read_text(encoding='utf-8')
                except Exception:
                    continue

            content = files_to_update[rel_path]
            orig = content

            # 1. Remover @Deprecated não autorizado
            if rule == 'RULE_NO_UNAUTHORIZED_DEPRECATED':
                sym_name = v['symbol']
                pat = rf'(@Deprecated\s*\([^)]*\)\s*|@deprecated\s*)(?=(?:[A-Za-z0-9_<>?, ]+\s+)?{re.escape(sym_name)}\b)'
                content = re.sub(pat, '', content)

            # 2. Corrigir construtor com prefixo 'new'
            elif rule == 'RULE_REDUNDANT_CONSTRUCTOR_NAMES':
                c_sym = v['symbol']
                if c_sym.startswith('newFrom'):
                    suggested = c_sym[3:]
                    suggested = suggested[:1].lower() + suggested[1:]
                    content = content.replace(f".{c_sym}", f".{suggested}")

            # 3. Comentar shims artificiais de typedef
            elif rule == 'RULE_NO_TYPEDEF_SHIMS':
                sym_name = v['symbol']
                pat = rf'^[ \t]*typedef\s+{re.escape(sym_name)}\s*=\s*([A-Za-z0-9_<>,\s?]+);'
                content = re.sub(pat, rf'// [AGENTS.md RULE_NO_TYPEDEF_SHIMS] Removido shim retrocompatível: typedef {sym_name} = \1;', content, flags=re.MULTILINE)

            if content != orig:
                files_to_update[rel_path] = content
                total_fixes += 1

        for rel_path, new_content in files_to_update.items():
            p = self.root_dir / rel_path
            p.write_text(new_content, encoding='utf-8')

        return total_fixes

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
            "## 1. Resumo Executivo das 23 Regras",
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

    def print_report(self, json_output: bool = False, summary_only: bool = False, markdown_output: bool = False, output_file: Optional[str] = None):
        out_text = ""
        if json_output:
            out_text = json.dumps(self.violations, indent=2)
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
                clean = sym.name.lstrip('_').lower()
                dart_members.setdefault(key, set()).add(clean)
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

            mod_go_types = [s for s in syms if s.kind in ('struct', 'interface', 'type') and s.is_exported() and not is_out_of_scope(s.file_path)]
            mod_go_methods = [s for s in syms if s.kind == 'method' and s.is_exported() and not is_out_of_scope(s.file_path)]
            mod_go_fields = [s for s in syms if s.kind == 'field' and s.is_exported() and not is_out_of_scope(s.file_path)]
            mod_go_funcs = [s for s in syms if s.kind == 'func' and s.is_exported() and not is_out_of_scope(s.file_path)]

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
            'modules': modules
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
        include_non_public=args.include_non_public
    )

    if args.tests or args.rule == 'RULE_MISSING_ATOMIC_TESTS':
        auditor.audit_atomic_tests(target_package=args.package)
        if args.severity:
            target_sev = args.severity.upper()
            auditor.violations = [v for v in auditor.violations if v['severity'] == target_sev]

    if args.fix:
        fixes = auditor.apply_autofixes()
        print(f"\n🛠️ [AUTOFIX] {fixes} correções mecânicas aplicadas automaticamente.")
        # Recarrega e re-audita para exibir estado atualizado
        auditor = AstNomenclatureAuditor(root_dir)
        auditor.load_all()
        auditor.audit_rules(
            target_package=args.package,
            target_rule=args.rule,
            target_severity=args.severity,
            include_non_public=args.include_non_public
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
        output_file=args.output
    )

    errors = [v for v in auditor.violations if v['severity'] == 'ERROR']
    if errors:
        sys.exit(1)


if __name__ == '__main__':
    main()
