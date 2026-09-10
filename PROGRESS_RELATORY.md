# Relatório Sintético de Progresso e Cobertura da Árvore AST (Go <-> Dart)

> Documento gerado automaticamente pela ferramenta `tool/audit_ast_nomenclature.py --progress`.
> **Símbolos Dart Auditados:** 5251 | **Símbolos Go Indexados:** 33298

## 1. Visão Geral em Duas Perspectivas

### Perspectiva A: Objetivo 1 — Primeiro Download P2P por CID (Prioridade Máxima)

- **Status:** ✅ **100% Concluído (0% de Pendências Impeditivas)**
- **Marco A (Provider Conhecido):** Concluído e comprovado (`Kubo -> TCP/Noise -> Bitswap 1.2.0 -> WANT_BLOCK -> validação CID -> Blockstore`).
- **Marco B (Provider Descoberto via DHT):** Concluído e comprovado (`CID -> DHT findProviders -> AddrInfo -> conectar -> Bitswap -> Blockstore`).
- **Testes de Integração com Kubo Real:** 100% aprovados (`local_kubo_bitswap_test.dart` e `local_kubo_dht_bitswap_test.dart`).

### Perspectiva B: Cobertura Quantitativa da Árvore AST Total Upstream Go

- **Total de Símbolos Go no Escopo:** 16,376
- **Símbolos Implementados em Dart:** 1,834 (11.2%)
- **Símbolos Restantes no Ecossistema:** 14,542 (88.8%)

| Categoria de Símbolo | Total no Upstream Go | Implementado em Dart | Falta Implementar | % Concluído | % Que Falta |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Tipos (Classes / Interfaces)** | 1,663 | 318 | 1,345 | 19.1% | **80.9%** |
| **Métodos** | 8,927 | 1,056 | 7,871 | 11.8% | **88.2%** |
| **Campos de Structs** | 3,033 | 247 | 2,786 | 8.1% | **91.9%** |
| **Funções Top-Level** | 2,753 | 213 | 2,540 | 7.7% | **92.3%** |
| **TOTAL GERAL** | **16,376** | **1,834** | **14,542** | **11.2%** | **88.8%** |

## 2. Detalhamento Quantitativo por Módulo Upstream Go

| Módulo Go | Pacote Dart Correspondente | Total Símbolos | Implementados | Pendentes | % Feito | % Que Falta | Tipos (Feitos/Total) |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| `go-libp2p-routing-helpers` | `packages/transpiled_libp2p_routing_helpers` | 113 | 84 | 29 | 74.3% | **25.7%** | 10/12 |
| `go-block-format` | `packages/transpiled_block_format` | 10 | 7 | 3 | 70.0% | **30.0%** | 2/2 |
| `go-multiaddr-dns` | `packages/transpiled_multiaddr_dns` | 21 | 13 | 8 | 61.9% | **38.1%** | 3/5 |
| `go-libp2p-kbucket` | `packages/transpiled_libp2p_kbucket` | 76 | 37 | 39 | 48.7% | **51.3%** | 3/10 |
| `go-libp2p-record` | `packages/transpiled_libp2p_record` | 31 | 15 | 16 | 48.4% | **51.6%** | 4/5 |
| `go-datastore` | `packages/transpiled_datastore` | 530 | 171 | 359 | 32.3% | **67.7%** | 33/57 |
| `go-multibase` | `packages/transpiled_multibase` | 11 | 3 | 8 | 27.3% | **72.7%** | 1/2 |
| `go-multihash` | `packages/transpiled_multihash` | 67 | 14 | 53 | 20.9% | **79.1%** | 2/7 |
| `go-libp2p` | `packages/transpiled_libp2p` | 3688 | 740 | 2948 | 20.1% | **79.9%** | 139/391 |
| `go-cid` | `packages/transpiled_cid` | 99 | 15 | 84 | 15.2% | **84.8%** | 3/10 |
| `go-multiaddr` | `packages/transpiled_multiaddr` | 188 | 20 | 168 | 10.6% | **89.4%** | 4/18 |
| `go-ipld-prime` | `packages/transpiled_ipld_prime` | 3708 | 380 | 3328 | 10.2% | **89.8%** | 59/244 |
| `boxo` | `packages/transpiled_boxo` | 3052 | 287 | 2765 | 9.4% | **90.6%** | 44/350 |
| `go-multicodec` | `packages/transpiled_multicodec` | 16 | 1 | 15 | 6.2% | **93.8%** | 1/2 |
| `go-car-v2` | `packages/transpiled_go_car` | 348 | 12 | 336 | 3.4% | **96.6%** | 2/41 |
| `go-yamux` | `packages/transpiled_go_yamux` | 82 | 2 | 80 | 2.4% | **97.6%** | 2/7 |
| `go-libp2p-pubsub` | `packages/transpiled_libp2p_pubsub` | 1014 | 23 | 991 | 2.3% | **97.7%** | 4/109 |
| `kubo` | `lib` | 2666 | 10 | 2656 | 0.4% | **99.6%** | 2/326 |
| `go-libp2p-kad-dht` | `lib/src/protocols/dht` | 656 | 0 | 656 | 0.0% | **100.0%** | 0/65 |

## 3. Diretriz Arquitetural (AGENTS.md)

Conforme estipulado no `AGENTS.md`:
- Kubo, Boxo e go-libp2p são referências de comportamento e não superfícies que devam ser portadas 100% integralmente.
- Todo o volume de símbolos restantes corresponde a subsistemas opcionais ou avançados (Gateway HTTP, MFS completo, Circuit Relay v2, WebRTC, Tracing, Plugins, etc.), devendo ser portados sob demanda estrita e sem inflar o escopo do nó embutido.
