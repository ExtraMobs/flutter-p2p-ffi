# Relatório Sintético de Progresso e Cobertura da Árvore AST (Go <-> Dart)

> Documento gerado automaticamente pela ferramenta `tool/audit_ast_nomenclature.py --progress`.
> **Símbolos Dart Auditados:** 13775 | **Símbolos Go Indexados:** 60270

## 1. Visão Geral em Duas Perspectivas

### Perspectiva A: Objetivo 1 — Primeiro Download P2P por CID (Prioridade Máxima)

- **Status:** ✅ **100% Concluído (0% de Pendências Impeditivas)**
- **Marco A (Provider Conhecido):** Concluído e comprovado (`Kubo -> TCP/Noise -> Bitswap 1.2.0 -> WANT_BLOCK -> validação CID -> Blockstore`).
- **Marco B (Provider Descoberto via DHT):** Concluído e comprovado (`CID -> DHT findProviders -> AddrInfo -> conectar -> Bitswap -> Blockstore`).
- **Testes de Integração com Kubo Real:** 100% aprovados (`local_kubo_bitswap_test.dart` e `local_kubo_dht_bitswap_test.dart`).

### Perspectiva B: Cobertura Quantitativa da Árvore AST Total Upstream Go

- **Total de Símbolos Go no Escopo:** 19,798
- **Símbolos Implementados em Dart:** 3,526 (17.8%)
- **Símbolos Restantes no Ecossistema:** 16,272 (82.2%)

| Categoria de Símbolo | Total no Upstream Go | Implementado em Dart | Falta Implementar | % Concluído | % Que Falta |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Tipos (Classes / Interfaces)** | 3,011 | 693 | 2,318 | 23.0% | **77.0%** |
| **Métodos** | 9,331 | 1,581 | 7,750 | 16.9% | **83.1%** |
| **Campos de Structs** | 4,682 | 809 | 3,873 | 17.3% | **82.7%** |
| **Funções Top-Level** | 2,774 | 443 | 2,331 | 16.0% | **84.0%** |
| **TOTAL GERAL** | **19,798** | **3,526** | **16,272** | **17.8%** | **82.2%** |

## 2. Detalhamento Quantitativo por Módulo Upstream Go

| Módulo Go | Pacote Dart Correspondente | Total Símbolos | Implementados | Pendentes | % Feito | % Que Falta | Tipos (Feitos/Total) |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| `pion-datachannel` | `packages/transpiled_pion_datachannel` | 44 | 44 | 0 | 100.0% | **0.0%** | 9/9 |
| `pion-randutil` | `packages/transpiled_pion_randutil` | 8 | 8 | 0 | 100.0% | **0.0%** | 1/1 |
| `golang-x-time` | `packages/transpiled_golang_x_time` | 29 | 28 | 1 | 96.6% | **3.4%** | 4/4 |
| `pion-sctp` | `packages/transpiled_pion_sctp` | 52 | 49 | 3 | 94.2% | **5.8%** | 5/5 |
| `qpack` | `packages/transpiled_qpack` | 12 | 11 | 1 | 91.7% | **8.3%** | 3/4 |
| `benbjohnson-clock` | `packages/transpiled_clock` | 38 | 32 | 6 | 84.2% | **15.8%** | 4/5 |
| `pion-logging` | `packages/transpiled_pion_logging` | 42 | 33 | 9 | 78.6% | **21.4%** | 5/5 |
| `go-libp2p-routing-helpers` | `packages/transpiled_libp2p_routing_helpers` | 85 | 65 | 20 | 76.5% | **23.5%** | 10/12 |
| `go-block-format` | `packages/transpiled_block_format` | 14 | 10 | 4 | 71.4% | **28.6%** | 2/2 |
| `pion-dtls` | `packages/transpiled_pion_dtls` | 681 | 484 | 197 | 71.1% | **28.9%** | 80/114 |
| `pion-sdp` | `packages/transpiled_pion_sdp` | 138 | 94 | 44 | 68.1% | **31.9%** | 23/23 |
| `go-base32` | `packages/transpiled_base32` | 15 | 10 | 5 | 66.7% | **33.3%** | 1/2 |
| `go-multiaddr-dns` | `packages/transpiled_multiaddr_dns` | 21 | 13 | 8 | 61.9% | **38.1%** | 3/5 |
| `pion-stun` | `packages/transpiled_pion_stun` | 272 | 164 | 108 | 60.3% | **39.7%** | 35/47 |
| `go-libp2p-record` | `packages/transpiled_libp2p_record` | 28 | 15 | 13 | 53.6% | **46.4%** | 4/5 |
| `pion-ice` | `packages/transpiled_pion_ice` | 361 | 175 | 186 | 48.5% | **51.5%** | 22/51 |
| `go-libp2p-kbucket` | `packages/transpiled_libp2p_kbucket` | 71 | 34 | 37 | 47.9% | **52.1%** | 3/10 |
| `go-datastore` | `packages/transpiled_datastore` | 342 | 162 | 180 | 47.4% | **52.6%** | 33/55 |
| `go-libp2p` | `packages/transpiled_libp2p` | 2800 | 1026 | 1774 | 36.6% | **63.4%** | 204/404 |
| `go-multibase` | `packages/transpiled_multibase` | 9 | 3 | 6 | 33.3% | **66.7%** | 1/2 |
| `go-multihash` | `packages/transpiled_multihash` | 49 | 14 | 35 | 28.6% | **71.4%** | 2/7 |
| `golang-x-net` | `packages/transpiled_golang_x_net` | 669 | 149 | 520 | 22.3% | **77.7%** | 30/117 |
| `go-ipld-prime` | `packages/transpiled_ipld_prime` | 1712 | 345 | 1367 | 20.2% | **79.8%** | 84/288 |
| `go-multicodec` | `packages/transpiled_multicodec` | 5 | 1 | 4 | 20.0% | **80.0%** | 1/1 |
| `go-multiaddr` | `packages/transpiled_multiaddr` | 161 | 30 | 131 | 18.6% | **81.4%** | 4/19 |
| `go-cid` | `packages/transpiled_cid` | 92 | 15 | 77 | 16.3% | **83.7%** | 3/10 |
| `boxo` | `packages/transpiled_boxo` | 2505 | 285 | 2220 | 11.4% | **88.6%** | 52/357 |
| `pion-transport-v4` | `packages/transpiled_pion_transport_v4` | 244 | 24 | 220 | 9.8% | **90.2%** | 7/49 |
| `webtransport-go` | `packages/transpiled_webtransport_go` | 75 | 7 | 68 | 9.3% | **90.7%** | 3/12 |
| `go-yamux` | `packages/transpiled_go_yamux` | 69 | 6 | 63 | 8.7% | **91.3%** | 2/7 |
| `quic-go` | `packages/transpiled_quic_go` | 1668 | 81 | 1587 | 4.9% | **95.1%** | 33/328 |
| `go-car-v2` | `packages/transpiled_go_car` | 349 | 12 | 337 | 3.4% | **96.6%** | 2/51 |
| `go-dag-jose` | `packages/transpiled_go_dag_jose` | 610 | 19 | 591 | 3.1% | **96.9%** | 3/51 |
| `go-libp2p-kad-dht` | `packages/transpiled_libp2p_kad_dht` | 599 | 17 | 582 | 2.8% | **97.2%** | 4/67 |
| `go-ipld-git` | `packages/transpiled_go_ipld_git` | 399 | 11 | 388 | 2.8% | **97.2%** | 1/32 |
| `pion-transport` | `packages/transpiled_pion_transport` | 219 | 6 | 213 | 2.7% | **97.3%** | 1/43 |
| `go-libp2p-pubsub` | `packages/transpiled_libp2p_pubsub` | 870 | 23 | 847 | 2.6% | **97.4%** | 4/114 |
| `kubo` | `lib` | 1700 | 21 | 1679 | 1.2% | **98.8%** | 5/256 |
| `pion-interceptor` | `packages/transpiled_pion_interceptor` | 442 | 0 | 442 | 0.0% | **100.0%** | 0/100 |
| `pion-mdns` | `packages/transpiled_pion_mdns` | 13 | 0 | 13 | 0.0% | **100.0%** | 0/2 |
| `pion-rtcp` | `packages/transpiled_pion_rtcp` | 336 | 0 | 336 | 0.0% | **100.0%** | 0/51 |
| `pion-rtp` | `packages/transpiled_pion_rtp` | 345 | 0 | 345 | 0.0% | **100.0%** | 0/55 |
| `pion-srtp` | `packages/transpiled_pion_srtp` | 84 | 0 | 84 | 0.0% | **100.0%** | 0/13 |
| `pion-turn` | `packages/transpiled_pion_turn` | 319 | 0 | 319 | 0.0% | **100.0%** | 0/51 |
| `pion-webrtc` | `packages/transpiled_pion_webrtc` | 1202 | 0 | 1202 | 0.0% | **100.0%** | 0/165 |

## 3. Diretriz Arquitetural (AGENTS.md)

Conforme estipulado no `AGENTS.md`:
- Kubo, Boxo e go-libp2p são referências de comportamento e não superfícies que devam ser portadas 100% integralmente.
- Todo o volume de símbolos restantes corresponde a subsistemas opcionais ou avançados (Gateway HTTP, MFS completo, Circuit Relay v2, WebRTC, Tracing, Plugins, etc.), devendo ser portados sob demanda estrita e sem inflar o escopo do nó embutido.
