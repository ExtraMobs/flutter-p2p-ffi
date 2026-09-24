#!/usr/bin/env python3
"""
tool/generate_parity_tables.py
Gera o documento VALIDACAO_SIMBOLOS_PARIDADE.md contendo a tabela literal de símbolos AST 1:1
mapeados para seus nomes previamente adaptados em Dart, com reforço mandatório de boilerplate.
"""

import os
import re
from pathlib import Path

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
    'FD': 'Fd', 'FDS': 'Fds', 'ALPN': 'Alpn', 'SNI': 'Sni', 'DCID': 'Dcid',
    'SCID': 'Scid'
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
        # Regra 13: ErrX -> XException
        return norm[3:] + 'Exception'
    if norm and norm[0].islower():
        norm = norm[0].upper() + norm[1:]
    return norm

def to_lower_camel(name: str) -> str:
    if not name:
        return ''
    if name.startswith('Err') and len(name) > 3 and name[3].isupper():
        # Regra 13: ErrX -> xException
        norm = normalize_acronyms(name[3:])
        return norm[0].lower() + norm[1:] + 'Exception'
    norm = normalize_acronyms(name)
    return norm[0].lower() + norm[1:]

def adapt_symbol(kind: str, name: str, parent: str = None) -> tuple:
    """
    Retorna: (dart_name, rules_applied, boilerplate_req)
    """
    rules = []
    bp = "N/A"
    
    # Detecção de tipo boilerplate
    lower_n = name.lower()
    if 'uint64' in lower_n or 'seq' in lower_n or 'tsn' in lower_n or 'offset' in lower_n or 'bytes' in lower_n or 'size' in lower_n or 'length' in lower_n:
        bp = "Golang.Uint64 (`fixed_types`)"
    elif 'uint32' in lower_n or 'ssn' in lower_n or 'streamid' in lower_n or 'id' in lower_n:
        bp = "Golang.Uint32 (`fixed_types`)"
    elif 'uint16' in lower_n or 'port' in lower_n:
        bp = "Golang.Uint16 (`fixed_types`)"
    elif 'uint8' in lower_n or 'byte' in lower_n or 'chunktype' in lower_n:
        bp = "Golang.Byte (`fixed_types`)"
    elif 'int64' in lower_n or 'duration' in lower_n or 'time' in lower_n:
        bp = "Golang.Int64 (`fixed_types`)"
    elif 'int32' in lower_n or 'int' in lower_n:
        bp = "Golang.Int32 (`fixed_types`)"
    elif 'prefix' in lower_n or 'mask' in lower_n:
        bp = "netip.Prefix (`net_netip`)"
    elif 'ip' in lower_n or 'addr' in lower_n:
        bp = "net.Ip (`net`) / netip.Addr (`net_netip`)"
    elif 'fd' in lower_n or 'socket' in lower_n:
        bp = "internal_poll.Fd (`internal_poll`)"

    if kind in ('struct', 'interface', 'type'):
        if name.startswith('Err'):
            dart_name = to_upper_camel(name)
            rules.append("Regra 13 (Exception naming)")
        else:
            dart_name = to_upper_camel(name)
            rules.append("Regra 1 (UpperCamelCase)")
    elif kind == 'func':
        if name.startswith('New') and len(name) > 3 and name[3].isupper():
            target_class = to_upper_camel(name[3:])
            dart_name = f"{target_class}() [construtor] / {to_lower_camel(name)}()"
            rules.append("Regra 5 (No newX, construtor/factory)")
        else:
            dart_name = to_lower_camel(name) + "()"
            rules.append("Regra 2 (lowerCamelCase)")
        rules.append("Regra 8 (No error tuples)")
    elif kind == 'method':
        dart_name = to_lower_camel(name) + "()"
        rules.append("Regra 2 (lowerCamelCase)")
        rules.append("Regra 8 (No error tuples)")
    elif kind == 'field':
        dart_name = to_lower_camel(name)
        rules.append("Regra 2 (lowerCamelCase)")
    elif kind in ('const', 'var'):
        if name.isupper() or '_' in name:
            dart_name = to_lower_camel(name)
            rules.append("Regra 6 (Const lowerCamelCase)")
        elif name.startswith('Err'):
            dart_name = to_lower_camel(name)
            rules.append("Regra 13 (Exception naming)")
        else:
            dart_name = to_lower_camel(name)
            rules.append("Regra 6 (Const lowerCamelCase)")
    else:
        dart_name = to_lower_camel(name)
        rules.append("Regra 2")

    return dart_name, ", ".join(rules), bp

def parse_index_file(filepath: Path):
    """
    Retorna lista de dicts com símbolos do arquivo markdown de índice.
    """
    symbols = []
    file_pattern = re.compile(r'^##\s+`([^`]+)`')
    type_pattern = re.compile(r'^###\s+(struct|interface|type)\s+`([^`]+)`')
    member_pattern = re.compile(r'^-\s+\*\*([A-Za-z0-9_]+)\*\*\s+\((method|field)\)(?:\s+\s+(.*))?')
    func_pattern = re.compile(r'^###\s+func\s+`([^`]+)`(?:\s+\s+(.*))?|^###\s+top-level\s+`([^`]+)`\s+\(function\)')
    func_item_pattern = re.compile(r'^-\s+\*\*([A-Za-z0-9_]+)\*\*\s+\(function\)(?:\s+\s+(.*))?')
    var_pattern = re.compile(r'^###\s+(var|const)\s+`([^`]+)`')

    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()

    current_file = filepath.name
    current_type = None

    for line in lines:
        line_s = line.strip()
        m_file = file_pattern.match(line_s)
        if m_file:
            current_file = m_file.group(1)
            current_type = None
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

print("Parser module ready.")
