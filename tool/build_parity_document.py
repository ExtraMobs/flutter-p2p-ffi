#!/usr/bin/env python3
"""
tool/build_parity_document.py

Gera o documento exaustivo VALIDACAO_SIMBOLOS_PARIDADE.md na raiz do repositório,
tabelando literalmente cada símbolo AST Go que será portado 1:1 para o Dart,
com seu nome previamente adaptado segundo o AGENTS.md e o requisito mandatório
de boilerplate (packages/boilerplate/) para cada caso.
"""

import os
import re
from pathlib import Path
from typing import Dict, List, Tuple

ACRONYMS = {
    'IPFS': 'Ipfs', 'DHT': 'Dht', 'CID': 'Cid', 'ID': 'Id', 'P2P': 'P2p',
    'TTL': 'Ttl', 'CPL': 'Cpl', 'URL': 'Url', 'URI': 'Uri', 'HTTP': 'Http',
    'HTTPS': 'Https', 'RPC': 'Rpc', 'PB': 'Pb', 'CAR': 'Car', 'XOR': 'Xor',
    'ASCII': 'Ascii', 'UTF': 'Utf', 'JSON': 'Json', 'DSA': 'Dsa', 'RSA': 'Rsa',
    'ECDSA': 'Ecdsa', 'DER': 'Der', 'DNS': 'Dns', 'NAT': 'Nat', 'FUSE': 'Fuse',
    'API': 'Api', 'IO': 'Io', 'FD': 'Fd', 'RTT': 'Rtt', 'MTU': 'Mtu',
    'ASN': 'Asn', 'TCP': 'Tcp', 'UDP': 'Udp', 'IP': 'Ip', 'QUIC': 'Quic',
    'DAG': 'Dag', 'MFS': 'Mfs', 'HAMT': 'Hamt', 'DTLS': 'Dtls', 'SCTP': 'Sctp',
    'ICE': 'Ice', 'STUN': 'Stun', 'SRTP': 'Srtp', 'SDP': 'Sdp', 'DCEP': 'Dcep',
    'CBOR': 'Cbor', 'JOSE': 'Jose', 'GIT': 'Git', 'TSN': 'Tsn', 'SSN': 'Ssn',
    'ACK': 'Ack', 'SACK': 'Sack', 'PTO': 'Pto', 'CWND': 'Cwnd',
    'TLS': 'Tls', 'AES': 'Aes', 'GCM': 'Gcm', 'SHA': 'Sha', 'HMAC': 'Hmac',
    'HKDF': 'Hkdf', 'PSK': 'Psk', 'CCM': 'Ccm', 'ECN': 'Ecn', 'UPNP': 'Upnp',
    'PMP': 'Pmp', 'WAN': 'Wan', 'LAN': 'Lan', 'UID': 'Uid', 'GID': 'Gid',
    'ALPN': 'Alpn', 'SNI': 'Sni', 'DCID': 'Dcid', 'SCID': 'Scid', 'ECC': 'Ecc'
}

def normalize_acronyms(text: str) -> str:
    res = text
    # Word-level replacement
    for k, v in ACRONYMS.items():
        res = re.sub(r'(?<![A-Za-z0-9])' + k + r'(?![A-Za-z0-9])', v, res)
    # Embedded replacement for common multi-acronym patterns
    for k, v in ACRONYMS.items():
        res = res.replace(k, v)
    return res

def to_upper_camel(name: str) -> str:
    if not name:
        return ''
    norm = normalize_acronyms(name)
    if norm.startswith('Err') and len(norm) > 3 and norm[3].isupper():
        return norm[3:] + 'Exception'
    if norm and norm[0].islower():
        norm = norm[0].upper() + norm[1:]
    return norm

def to_lower_camel(name: str) -> str:
    if not name:
        return ''
    # Tratamento de prefixo Err
    if name.startswith('Err') and len(name) > 3 and name[3].isupper():
        norm = normalize_acronyms(name[3:])
        return norm[0].lower() + norm[1:] + 'Exception'
    
    # Se o nome todo for acrônimo conhecido (ex: MTU, ECC, PSK, ID, IP)
    if name.upper() in ACRONYMS:
        return name.lower()
        
    norm = normalize_acronyms(name)
    if norm and len(norm) > 1 and norm[0].isupper() and norm[1].islower():
        return norm[0].lower() + norm[1:]
    elif norm:
        return norm[0].lower() + norm[1:]
    return norm

def adapt_symbol(kind: str, name: str, parent: str = None) -> Tuple[str, str, str]:
    rules = []
    bp = "Dart nativo (`int`/`String`/`bool`)"
    
    # Detecção precisa de boilerplate usando regex
    lower_n = name.lower()
    
    # 1. Boilerplate de rede / netip
    if re.search(r'\b(prefix|subnet|cidr|netmask)\b', lower_n):
        bp = "`netip.Prefix` (`package:boilerplate/net_netip/golang.dart`)"
    elif re.search(r'\b(netip|ipaddr)\b', lower_n):
        bp = "`netip.Addr` (`package:boilerplate/net_netip/golang.dart`)"
    elif re.search(r'\b(ip|ipnet|ipaddress|localip|remoteip)\b', lower_n):
        bp = "`net.Ip` / `net.IpNet` (`package:boilerplate/net/golang.dart`)"
    elif re.search(r'\b(multiaddr|maddr|addrs)\b', lower_n):
        bp = "`Multiaddr` (`package:transpiled_multiaddr/multiaddr.dart`)"
    elif re.search(r'\b(addr)\b', lower_n) and not re.search(r'payload|header', lower_n):
        bp = "`net.Ip` / `netip.Addr` (`boilerplate/net` ou `net_netip`)"
    # 2. Boilerplate de descritores / poll
    elif re.search(r'\b(fd|socket|rawsocket|filedescriptor)\b', lower_n):
        bp = "`internal_poll.Fd` (`package:boilerplate/internal_poll/golang.dart`)"
    # 3. Boilerplate numérico fixed_types
    elif re.search(r'\b(uint64|tsn|cumulativetsn|offset|seqnum|bytes|filesize|blocksize)\b', lower_n):
        bp = "`Golang.Uint64` (`package:boilerplate/fixed_types/golang.dart`)"
    elif re.search(r'\b(uint32|ssn|streamid|packetnumber|arwnd|vrf|checksum|crc32c)\b', lower_n):
        bp = "`Golang.Uint32` (`package:boilerplate/fixed_types/golang.dart`)"
    elif re.search(r'\b(uint16|port|sid|stream_id|chunklength)\b', lower_n):
        bp = "`Golang.Uint16` (`package:boilerplate/fixed_types/golang.dart`)"
    elif re.search(r'\b(uint8|byte|chunktype|flags|tos)\b', lower_n):
        bp = "`Golang.Byte` (`package:boilerplate/fixed_types/golang.dart`)"
    elif re.search(r'\b(int64|duration|nanoseconds|timestamp|rtt|timeout)\b', lower_n):
        bp = "`Golang.Int64` (`package:boilerplate/fixed_types/golang.dart`)"
    elif re.search(r'\b(int32|count|errno)\b', lower_n):
        bp = "`Golang.Int32` (`package:boilerplate/fixed_types/golang.dart`)"

    # Formatação de nome
    if kind in ('struct', 'interface', 'type'):
        if name.startswith('Err'):
            dart_name = f"`{to_upper_camel(name)}`"
            rules.append("Regra 13 (Exception naming)")
        else:
            dart_name = f"`{to_upper_camel(name)}`"
            rules.append("Regra 1 (UpperCamelCase)")
    elif kind == 'func':
        if name.startswith('New') and len(name) > 3 and name[3].isupper():
            target_class = to_upper_camel(name[3:])
            dart_name = f"`{target_class}()` [construtor]"
            rules.append("Regra 5 (No newX, construtor/factory)")
        else:
            clean_name = name.split('.')[-1]
            dart_name = f"`{to_lower_camel(clean_name)}()`"
            rules.append("Regra 2 (lowerCamelCase)")
        rules.append("Regra 8 (No error tuples)")
    elif kind == 'method':
        clean_name = name.split('.')[-1]
        dart_name = f"`{to_lower_camel(clean_name)}()`"
        rules.append("Regra 2 (lowerCamelCase)")
        rules.append("Regra 8 (No error tuples)")
    elif kind == 'field':
        clean_name = name.split('.')[-1]
        dart_name = f"`{to_lower_camel(clean_name)}`"
        rules.append("Regra 2 (lowerCamelCase)")
    elif kind in ('const', 'var'):
        clean_name = name.split('.')[-1]
        if clean_name.isupper() or '_' in clean_name:
            dart_name = f"`{to_lower_camel(clean_name)}`"
            rules.append("Regra 6 (Const lowerCamelCase)")
        elif clean_name.startswith('Err'):
            dart_name = f"`{to_lower_camel(clean_name)}`"
            rules.append("Regra 13 (Exception naming)")
        else:
            dart_name = f"`{to_lower_camel(clean_name)}`"
            rules.append("Regra 6 (Const lowerCamelCase)")
    else:
        dart_name = f"`{to_lower_camel(name)}`"
        rules.append("Regra 2")

    return dart_name, ", ".join(rules), bp

def parse_index_file(filepath: Path) -> List[Dict]:
    symbols = []
    file_pattern = re.compile(r'^##\s+`([^`]+)`')
    type_pattern = re.compile(r'^###\s+(struct|interface|type)\s+`([^`]+)`')
    member_pattern = re.compile(r'^-\s+\*\*([A-Za-z0-9_.]+)\*\*\s+\((method|field)\)(?:\s+—\s+(.*))?')
    func_pattern = re.compile(r'^###\s+func\s+`([^`]+)`(?:\s+—\s+(.*))?|^###\s+top-level\s+`([^`]+)`\s+\(function\)')
    func_item_pattern = re.compile(r'^-\s+\*\*([A-Za-z0-9_.]+)\*\*\s+\(function\)(?:\s+—\s+(.*))?')
    var_pattern = re.compile(r'^###\s+(var|const)\s+`([^`]+)`')

    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()

    current_file = filepath.stem
    current_type = None

    for line in lines:
        line_s = line.strip()
        m_file = file_pattern.match(line_s)
        if m_file:
            current_file = m_file.group(1)
            current_type = None
            continue

        if any(p in current_file.lower() for p in ['_test.go', '/test/', 'mock', 'example', 'cmd/']):
            continue

        m_type = type_pattern.match(line_s)
        if m_type:
            current_type = m_type.group(2)
            symbols.append({
                'kind': m_type.group(1),
                'name': current_type,
                'file': current_file,
                'parent': None
            })
            continue

        m_member = member_pattern.match(line_s)
        if m_member and current_type:
            symbols.append({
                'kind': m_member.group(2),
                'name': m_member.group(1),
                'file': current_file,
                'parent': current_type
            })
            continue

        m_func = func_pattern.match(line_s)
        if m_func:
            current_type = None
            name = m_func.group(1) or m_func.group(3)
            symbols.append({
                'kind': 'func',
                'name': name,
                'file': current_file,
                'parent': None
            })
            continue

        m_func_item = func_item_pattern.match(line_s)
        if m_func_item:
            name = m_func_item.group(1)
            symbols.append({
                'kind': 'func',
                'name': name,
                'file': current_file,
                'parent': None
            })
            continue

        m_var = var_pattern.match(line_s)
        if m_var:
            current_type = None
            symbols.append({
                'kind': m_var.group(1),
                'name': m_var.group(2),
                'file': current_file,
                'parent': None
            })
            continue

    return symbols

def render_table(symbols: List[Dict], max_rows: int = 350) -> str:
    out = [
        "| Símbolo AST Go | Tipo Go | Escopo / Pai | Símbolo Dart Adaptado 1:1 | Regras AGENTS.md | Boilerplate Mandatório (Regra 10) |",
        "| :--- | :--- | :--- | :--- | :--- | :--- |"
    ]
    seen = set()
    count = 0
    for s in symbols:
        key = (s['kind'], s['name'], s['parent'])
        if key in seen:
            continue
        seen.add(key)
        dart_name, rules, bp = adapt_symbol(s['kind'], s['name'], s['parent'])
        parent_str = f"`{s['parent']}`" if s['parent'] else "*(top-level)*"
        kind_str = s['kind']
        go_name = f"`{s['name']}`"
        out.append(f"| {go_name} | `{kind_str}` | {parent_str} | **{dart_name}** | {rules} | {bp} |")
        count += 1
        if count >= max_rows:
            break
    return "\n".join(out)

def build_document():
    doc = []
    doc.append("# Validação de Símbolos AST para Transpilação 1:1 e Diretrizes de Paridade")
    doc.append("")
    doc.append("> **Documento Normativo e Inventário Literal de Símbolos** conforme [AGENTS.md](file:///B:/Syncthing/Desenvolvimento/Projetos/Pessoal/dart%20IPFS/AGENTS.md).")
    doc.append("> Cada símbolo AST aqui tabelado foi extraído diretamente dos índices AST das árvores Go de referência em `go-ipfs-reference/*-index/` e mapeado com sua nomenclatura adaptada e seu requisito estrito de tipagem/boilerplate.")
    doc.append("")
    doc.append("---")
    doc.append("")
    doc.append("## 1. Princípios de Transpilação 1:1 e Diretrizes Invioláveis")
    doc.append("")
    doc.append("1. **Paridade Estrita 1:1**: A implementação Dart deve espelhar fielmente a lógica, estruturas, constantes, métodos e tratamento de erro do Go. É expressamente vedado simplificar algoritmos, omitir campos ou relaxar limites para contornar falhas.")
    doc.append("2. **Veto à Degradação de Código Interno**: Tipos internos (`unexported` ou pacotes `internal/`) tornam-se privados em Dart (prefixo `_`), mas **sua lógica deve ser portada com 100% de integridade** (sem stubs parciais ou mocks em produção).")
    doc.append("3. **Respeito às Fronteiras de `go.mod` (Regra 11)**: Cada módulo Go upstream reside em um pacote dedicado sob `packages/transpiled_<modulo>/`.")
    doc.append("4. **Auditoria AST e Testes Atômicos (Regras 18-24)**: Todo símbolo público nasce acompanhado de teste atômico 1:1 sob `test/atomic/<nivel>/`.")
    doc.append("")
    doc.append("---")
    doc.append("")
    doc.append("## 2. Reforço Mandatório da Regra do `packages/boilerplate/` (Regra 10)")
    doc.append("")
    doc.append("> [!CAUTION]")
    doc.append("> **É EXPRESSAMENTE PROIBIDO REINVENTAR FUNÇÕES JÁ EXISTENTES EM `packages/boilerplate/`**.")
    doc.append("> A Regra 10 (`RULE_ENFORCE_BOILERPLATE_TYPES`) é erro bloqueante no auditor AST. Toda manipulação de primitivos Go, estouro de inteiros, aritmética de bits, máscaras de rede, conversão de endereços IP ou descritores **DEVE OBRIGATORIAMENTE** consumir os módulos centralizados do boilerplate.")
    doc.append("")
    doc.append("### Catálogo de Uso Obrigatório:")
    doc.append("")
    doc.append("| Módulo Boilerplate | Caminho de Importação | Tipos Fornecidos | Finalidade / Semântica Go Preservada |")
    doc.append("| :--- | :--- | :--- | :--- |")
    doc.append("| **Tipos Primitivos Go** | `package:boilerplate/fixed_types/golang.dart` | `Golang.Byte`, `Golang.Rune`, `Golang.String`,<br>`Golang.Int8` a `Golang.Int64`,<br>`Golang.Uint8` a `Golang.Uint64`, `Golang.Uintptr`,<br>`Golang.Float32`, `Golang.Float64`,<br>`Golang.Complex64`, `Golang.Complex128` | Encapsula estouro modular $2^N$, truncamento, shifts aritméticos/lógicos, divisão/resto e zero values da especificação Go. Veto a `val & 0xFF` avulso. |")
    doc.append("| **Rede Estilo Go (`net.IP`)** | `package:boilerplate/net/golang.dart` | `Ip`, `IpNet` | Representação de 4 ou 16 bytes; preserva a propriedade de que `10.0.0.0/8` contém `::ffff:10.1.2.3` (dobra IPv4 em IPv6). Usado pelo ConnectionGater. |")
    doc.append("| **Prefixos de Rede (`net/netip`)** | `package:boilerplate/net_netip/golang.dart` | `Addr`, `Prefix` | Comparações mascaradas estritas sem conversão automática entre famílias de IP. Usado pelo ConnLimiter do rcmgr. |")
    doc.append("| **Descritores e Poll (`internal/poll`)** | `package:boilerplate/internal_poll/golang.dart` | `Fd`, `FdMutex`, `ErrNetClosing` | Máquina de estados de fechamento/leitura concorrente de sockets do runtime Go. |")
    doc.append("")
    doc.append("---")
    doc.append("")
    doc.append("## 3. Tabelas Literais de Símbolos AST 1:1 por Subsistema")
    doc.append("")

    # 1. Pion DTLS
    doc.append("### 3.1. Pion DTLS (`github.com/pion/dtls/v3`) — Marco G.5 (WebRTC Direct)")
    doc.append("*Destino Dart:* `packages/transpiled_pion_dtls/`")
    doc.append("*Origem Go:* `go-ipfs-reference/pion-dtls/`")
    doc.append("")
    dtls_syms = []
    dtls_index = Path('go-ipfs-reference/pion-dtls-index')
    if dtls_index.exists():
        for f in sorted(dtls_index.glob('*.md')):
            dtls_syms.extend(parse_index_file(f))
    doc.append(render_table(dtls_syms, max_rows=300))
    doc.append("")

    # 2. Pion SCTP Runtime
    doc.append("### 3.2. Pion SCTP Runtime (`github.com/pion/sctp`) — Marco G.5")
    doc.append("*Destino Dart:* `packages/transpiled_pion_sctp/` (Runtime pendente: `association.go`, `stream.go`, filas e timers)")
    doc.append("*Origem Go:* `go-ipfs-reference/pion-sctp/`")
    doc.append("")
    sctp_syms = []
    sctp_root = Path('go-ipfs-reference/pion-sctp-index/(root).md')
    if sctp_root.exists():
        sctp_syms.extend(parse_index_file(sctp_root))
    doc.append(render_table(sctp_syms, max_rows=200))
    doc.append("")

    # 3. Pion ICE Lite
    doc.append("### 3.3. Pion ICE Lite (`github.com/pion/ice/v4`) — Marco G.5")
    doc.append("*Destino Dart:* `packages/transpiled_pion_ice/` (Modo ICE lite com host candidates e UDP mux)")
    doc.append("*Origem Go:* `go-ipfs-reference/pion-ice/`")
    doc.append("")
    ice_syms = []
    ice_index = Path('go-ipfs-reference/pion-ice-index')
    if ice_index.exists():
        for f in sorted(ice_index.glob('*.md')):
            ice_syms.extend(parse_index_file(f))
    doc.append(render_table(ice_syms, max_rows=150))
    doc.append("")

    # 4. Pion DataChannel
    doc.append("### 3.4. Pion DataChannel (`github.com/pion/datachannel`) — Marco G.5")
    doc.append("*Destino Dart:* `packages/transpiled_pion_datachannel/` (DCEP framing e canais SCTP)")
    doc.append("*Origem Go:* `go-ipfs-reference/pion-datachannel/`")
    doc.append("")
    dc_syms = []
    dc_index = Path('go-ipfs-reference/pion-datachannel-index')
    if dc_index.exists():
        for f in sorted(dc_index.glob('*.md')):
            dc_syms.extend(parse_index_file(f))
    doc.append(render_table(dc_syms, max_rows=100))
    doc.append("")

    # 5. libp2p WebRTC Transport
    doc.append("### 3.5. libp2p WebRTC Transport (`go-libp2p/p2p/transport/webrtc`) — Marco G.5")
    doc.append("*Destino Dart:* `packages/transpiled_libp2p/lib/src/p2p/transport/webrtc/`")
    doc.append("*Origem Go:* `go-ipfs-reference/go-libp2p/p2p/transport/webrtc/`")
    doc.append("")
    webrtc_syms = []
    libp2p_index = Path('go-ipfs-reference/libp2p-index')
    for name in ['p2p_transport_webrtc.md', 'p2p_transport_webrtc_pb.md', 'p2p_transport_webrtc_udpmux.md']:
        f = libp2p_index / name
        if f.exists():
            webrtc_syms.extend(parse_index_file(f))
    doc.append(render_table(webrtc_syms, max_rows=120))
    doc.append("")

    # 6. Resource Manager (rcmgr)
    doc.append("### 3.6. Resource Manager (`go-libp2p/p2p/host/resource-manager`) — Fase D")
    doc.append("*Destino Dart:* `packages/transpiled_libp2p/lib/src/p2p/host/resource_manager/`")
    doc.append("*Origem Go:* `go-ipfs-reference/go-libp2p/p2p/host/resource-manager/`")
    doc.append("")
    rcmgr_syms = []
    f_rcmgr = libp2p_index / 'p2p_host_resource-manager.md'
    if f_rcmgr.exists():
        rcmgr_syms.extend(parse_index_file(f_rcmgr))
    doc.append(render_table(rcmgr_syms, max_rows=150))
    doc.append("")

    # 7. IPLD Codecs: DAG-CBOR & CBOR
    doc.append("### 3.7. Codecs IPLD: DAG-CBOR & CBOR (`go-ipld-prime/codec/dagcbor`)")
    doc.append("*Destino Dart:* `packages/transpiled_ipld_prime/lib/src/codec/dagcbor/`, `cbor/`")
    doc.append("*Origem Go:* `go-ipfs-reference/go-ipld-prime/codec/`")
    doc.append("")
    ipld_syms = []
    ipld_index = Path('go-ipfs-reference/go-ipld-prime-index')
    for name in ['codec_dagcbor.md', 'codec_cbor.md']:
        f = ipld_index / name
        if f.exists():
            ipld_syms.extend(parse_index_file(f))
    doc.append(render_table(ipld_syms, max_rows=100))
    doc.append("")

    # 8. Codecs IPLD: DAG-JOSE & IPLD-GIT
    doc.append("### 3.8. Codecs IPLD: DAG-JOSE & IPLD-GIT")
    doc.append("*Destino Dart:* `packages/transpiled_go_dag_jose/`, `packages/transpiled_go_ipld_git/`")
    doc.append("")
    ext_codecs = []
    for idx_dir in [Path('go-ipfs-reference/go-dag-jose-index'), Path('go-ipfs-reference/go-ipld-git-index')]:
        if idx_dir.exists():
            for f in sorted(idx_dir.glob('*.md')):
                ext_codecs.extend(parse_index_file(f))
    doc.append(render_table(ext_codecs, max_rows=120))
    doc.append("")

    # 9. QUIC Emissor: Loss Recovery & AckHandler
    doc.append("### 3.9. QUIC Loss Recovery (`quic-go/internal/ackhandler`)")
    doc.append("*Destino Dart:* `packages/transpiled_quic_go/lib/src/` (SentPacketHandler, PTO e retransmissão de flight)")
    doc.append("*Origem Go:* `go-ipfs-reference/quic-go/internal/ackhandler/`")
    doc.append("")
    quic_syms = []
    q_index = Path('go-ipfs-reference/quic-go-index/internal_ackhandler.md')
    if q_index.exists():
        quic_syms.extend(parse_index_file(q_index))
    doc.append(render_table(quic_syms, max_rows=120))
    doc.append("")

    # 10. Boxo Blockstore & Reprovider
    doc.append("### 3.10. Boxo Blockstore & Reprovider (`boxo/blockstore`, `boxo/provider`)")
    doc.append("*Destino Dart:* `packages/transpiled_boxo/lib/src/blockstore/`, `lib/src/node/`")
    doc.append("*Origem Go:* `go-ipfs-reference/boxo/`")
    doc.append("")
    boxo_syms = []
    boxo_index = Path('go-ipfs-reference/boxo-index')
    for name in ['blockstore.md', 'provider.md']:
        f = boxo_index / name
        if f.exists():
            boxo_syms.extend(parse_index_file(f))
    doc.append(render_table(boxo_syms, max_rows=120))
    doc.append("")

    doc.append("---")
    doc.append("")
    doc.append("## 4. Portão Obrigatório de Conclusão")
    doc.append("")
    doc.append("Antes de concluir qualquer porte dos símbolos acima, execute rigorosamente a sequência:")
    doc.append("```bash")
    doc.append("dart format lib bin test packages")
    doc.append("python tool/audit_ast_nomenclature.py --tests --severity ERROR")
    doc.append("dart test -j 1")
    doc.append("for d in packages/*/; do (cd \"$d\" && dart test -j 1); done")
    doc.append("python tool/audit_ast_nomenclature.py --progress")
    doc.append("python tool/audit_ast_nomenclature.py --markdown --output audit_report.md")
    doc.append("```")
    doc.append("")

    target_file = Path("VALIDACAO_SIMBOLOS_PARIDADE.md")
    with open(target_file, "w", encoding="utf-8") as f:
        f.write("\n".join(doc))
    print(f"Documento gerado com sucesso: {target_file} ({os.path.getsize(target_file)} bytes)")

if __name__ == '__main__':
    build_document()
