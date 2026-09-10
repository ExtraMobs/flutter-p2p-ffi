# Fontes Go de referência

Este arquivo fixa as revisões usadas como autoridade de comportamento. Atualizações
dos clones só podem alterar esta tabela junto com a revalidação dos ports afetados.

| Clone local | Módulo Go | Revisão | Fonte |
|---|---|---|---|
| `go-varint` (cache Go, v0.1.0) | `github.com/multiformats/go-varint` | `23576a8fddd196d6bc3b82014ae91d198e47d734` | <https://github.com/multiformats/go-varint.git> |
| `go-cid` | `github.com/ipfs/go-cid` | `707ffd0177069183ed529f6799b3c2e1d67372c5` | <https://github.com/ipfs/go-cid.git> |
| `go-multiaddr` | `github.com/multiformats/go-multiaddr` | `7fae00adf671d9d4b931e591f2357a261567fee5` | <https://github.com/multiformats/go-multiaddr.git> |
| `go-multihash` | `github.com/multiformats/go-multihash` | `b29af1cd12049b4d5fa9a81b0cb0b4a04703fa27` | <https://github.com/multiformats/go-multihash.git> |
| `go-multibase` | `github.com/multiformats/go-multibase` | `e78390d81626c10f14be96ab51cbbcb90074bc86` | <https://github.com/multiformats/go-multibase.git> |
| `go-multicodec` | `github.com/multiformats/go-multicodec` | `4da139829f52342a125a4b869c2ef1ad4ba6342d` | <https://github.com/multiformats/go-multicodec.git> |
| `go-multiaddr-dns` | `github.com/multiformats/go-multiaddr-dns` | `5e4803a34bcb9abae48f018944dcfcbe6b8b1b2f` | <https://github.com/multiformats/go-multiaddr-dns.git> |
| `go-libp2p` | `github.com/libp2p/go-libp2p` | `e20bb60ffc4b4ee33640e5fe8f45fccce893cecd` | <https://github.com/libp2p/go-libp2p.git> |
| `go-yamux` | `github.com/libp2p/go-yamux/v5` | `86999c64954b3109d08aac4d6dc94afa6fbfa302` | <https://github.com/libp2p/go-yamux.git> |
| `kubo` | `github.com/ipfs/kubo` | `d0fdc246db494877e7fa08a72933c8daa5c3f0e8` | <https://github.com/ipfs/kubo.git> |
| `boxo` | `github.com/ipfs/boxo` | `25b1db8931508bb069eb6e67243b34d353cbe845` | <https://github.com/ipfs/boxo.git> |
| `go-codec-dagpb` (cache Go, v1.7.0) | `github.com/ipld/go-codec-dagpb` | `0e35d310d23f0f2ae7eda4c17262d012f67bbf31` | <https://github.com/ipld/go-codec-dagpb.git> |
| `protobuf` (cache Go, v1.36.11) | `google.golang.org/protobuf` | `96a179180f0ad6bba9b1e7b6e38d0affb0168e9a` | <https://go.googlesource.com/protobuf> |
| `go-block-format` | `github.com/ipfs/go-block-format` | `190a5a4ed6ae45c01b8ec9e380893d16c6eefe84` | <https://github.com/ipfs/go-block-format.git> |
| `go-ipld-prime` | `github.com/ipld/go-ipld-prime` | `ab9fe751f33fca77e7b8c4f7bb3dee40f6974313` | <https://github.com/ipld/go-ipld-prime.git> |
| `go-unixfsnode` | `github.com/ipfs/go-unixfsnode` | `4a71cacb869d29b428bc5f817872e0c0dbeab669` | <https://github.com/ipfs/go-unixfsnode.git> |
| `go-car-v2` | `github.com/ipld/go-car/v2` | `a95c3df95441327b750cc8bfcc74062d6ed3c702` | <https://github.com/ipld/go-car.git> |
| `go-libp2p-kad-dht` | `github.com/libp2p/go-libp2p-kad-dht` | `10e0adf9859ef86ba08d8493d8313869a2e83d8a` | <https://github.com/libp2p/go-libp2p-kad-dht.git> |
| `go-libp2p-pubsub` | `github.com/libp2p/go-libp2p-pubsub` | `892d7aaf6b8952c1ebfb540901b9a5656615d949` | <https://github.com/libp2p/go-libp2p-pubsub.git> |
| `go-datastore` | `github.com/ipfs/go-datastore` | `3556410774ac30eb58d5a801db74f2f80f4205b2` | <https://github.com/ipfs/go-datastore.git> |
| `go-libp2p-kbucket` | `github.com/libp2p/go-libp2p-kbucket` | `33968bdd5b757d33b0c667c71bddb92a91f528af` | <https://github.com/libp2p/go-libp2p-kbucket.git> |
| `go-libp2p-record` | `github.com/libp2p/go-libp2p-record` | `24a25767ab0bae0d74df408199f554ce42977892` | <https://github.com/libp2p/go-libp2p-record.git> |
| `go-libp2p-routing-helpers` | `github.com/libp2p/go-libp2p-routing-helpers` | `246b1c6f74307b0847842d72f2208b69d2b13790` | <https://github.com/libp2p/go-libp2p-routing-helpers.git> |

Os clones correspondentes ficam em `go-ipfs-reference/<clone local>`, na raiz
deste checkout, e os índices AST em `go-ipfs-reference/<clone local>-index`.
Duas exceções de nomenclatura: o índice de `go-libp2p` é `libp2p-index` e o de
`go-multiaddr-dns` é `multiaddr-dns-index`. Os clones `go-block-format`,
`go-car-v2`, `go-unixfsnode` e `go-yamux` ainda não têm índice AST gerado. As
entradas marcadas "(cache Go, ...)" vêm do module cache do Go e não têm clone
local em `go-ipfs-reference/`.
