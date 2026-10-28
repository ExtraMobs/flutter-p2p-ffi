# Aprendendo p2p_ffi, uma pergunta de cada vez

[English](../en_us/README.md) · **Português** · [Español](../es/README.md)

Um curso para quem programa em Dart e nunca usou IPFS. Cada lição é um
arquivo executável que responde uma pergunta, diz do que precisa (as lições
anteriores e, tecnicamente, quais peças têm de existir por baixo), executa os
erros comuns de propósito para mostrar o erro real, e termina com a próxima
pergunta que ela levanta. Leia na ordem, ou vá direto à pergunta que você tem.

```bash
dart run tool/build.dart windows   # ou linux; uma vez, compila o p2p_host
dart run example/pt_br/01_dart_and_go.dart
```

As lições escrevem com `say()` (em [`lesson.dart`](lesson.dart)): cada linha
vai para o log do `dart:developer`, com o nome do arquivo da lição (filtrável
no DevTools e no console de depuração da IDE), e para o terminal.

Os nomes de arquivos e identificadores ficam em inglês, iguais nas três
línguas; só os comentários e a saída são traduzidos.

## A pilha, de baixo para cima

Cada lição acrescenta uma camada; cada camada precisa das que estão abaixo.

```
 o seu app (Dart)
   │  P2pService: o processo p2p_host, por memória compartilhada ...... 01
   ▼
 CID: o nome de alguns bytes, calculado a partir deles ................. 02
 datastore → blockstore: onde os blocos ficam guardados ................ 03
 exchange: onde buscar um bloco que não está aqui (offline / bitswap) .. 04, 16
 blockservice = blockstore + exchange
 DAGService: blocos como nós com links; chunker + importer: arquivos .. 03-04
 CAR: um DAG num arquivo só ............................................ 05-06
 repositório + nó (kubo): a pilha pronta, em disco ..................... 07-12
 host libp2p: identidade, endereços, conexões .......................... 13-14
 roteamento (DHT): quem tem um CID, onde está um peer .................. 15
 bitswap sobre o host + roteamento: buscar um CID de outros ............ 16
```

## As perguntas

### Parte A · conteúdo, sem nó

| # | Pergunta | Lição |
|---|---|---|
| 01 | Como o Dart conversa com o Go? Onde o código Go roda? | [`01_dart_and_go.dart`](01_dart_and_go.dart) |
| 02 | O que é um CID, e por que posso confiar no que volta para ele? | [`02_what_is_a_cid.dart`](02_what_is_a_cid.dart) |
| 03 | Como um arquivo vira blocos? Por que o mesmo arquivo ganha outro CID em outro lugar? | [`03_file_to_blocks.dart`](03_file_to_blocks.dart) |
| 04 | Como leio de volta? E se faltar um bloco? | [`04_blocks_to_file.dart`](04_blocks_to_file.dart) |
| 05 | Como levo blocos sem rede? (arquivos CAR) | [`05_car_files.dart`](05_car_files.dart) |
| 06 | CARv1 ou v2, o índice, raízes, uma parte, juntar? | [`06_car_more.dart`](06_car_more.dart) |

### Parte B · o nó kubo, em disco

| # | Pergunta | Lição |
|---|---|---|
| 07 | O que é um repositório, e por que `init`? | [`07_repo_and_init.dart`](07_repo_and_init.dart) |
| 08 | O que o nó monta para mim? | [`08_the_node.dart`](08_the_node.dart) |
| 09 | Por que os meus blocos somem? (pins e GC) | [`09_pins_and_gc.dart`](09_pins_and_gc.dart) |
| 10 | Como trabalho com pastas que mudam? (MFS) | [`10_mfs.dart`](10_mfs.dart) |
| 11 | Como dou um nome fixo a algo que muda? (chaves e IPNS) | [`11_ipns_and_keys.dart`](11_ipns_and_keys.dart) |
| 12 | Como uso os comandos `ipfs` que já conheço? | [`12_ipfs_commands.dart`](12_ipfs_commands.dart) |

### Parte C · a rede

| # | Pergunta | Lição |
|---|---|---|
| 13 | Quem sou eu na rede? (chaves, peer ID, multiaddr, transportes) | [`13_who_am_i.dart`](13_who_am_i.dart) |
| 14 | Como dois peers conversam? (conectar, ping, um protocolo meu, mDNS) | [`14_two_peers_talk.dart`](14_two_peers_talk.dart) |
| 15 | Como acho quem tem um conteúdo? (DHT) | [`15_find_on_the_dht.dart`](15_find_on_the_dht.dart) |
| 16 | O que o boxo precisa para baixar um CID? | [`16_fetch_a_cid.dart`](16_fetch_a_cid.dart) |
| 17 | Como entro na rede IPFS pública? (precisa de internet) | [`17_public_network.dart`](17_public_network.dart) |
| 18 | Como mando mensagens em tempo real? (pubsub) | [`18_pubsub.dart`](18_pubsub.dart) |

### Parte D · usar a ponte direito

| # | Pergunta | Lição |
|---|---|---|
| 19 | Como ponho prazo e cancelo? Que erros podem vir? | [`19_deadlines_and_errors.dart`](19_deadlines_and_errors.dart) |
| 20 | Quando preciso liberar memória? (handles) | [`20_handles_and_memory.dart`](20_handles_and_memory.dart) |
| 21 | Como o Go chama o meu código Dart? (callbacks) | [`21_callbacks.dart`](21_callbacks.dart) |

## Respostas rápidas

- **"O meu CID é diferente do que outra ferramenta deu."** O CID depende de
  como o arquivo foi cortado e embrulhado (tamanho do pedaço, CIDv0 ou v1,
  folhas raw): lição 03, passo 4.
- **"Dois CIDs parecem diferentes mas dão nome à mesma coisa."** Bases de texto
  diferentes, ou v0 e v1: compare com `equals()`, lição 02.
- **"`block was not found locally (offline)`."** O bloco não está no
  blockstore e o exchange não consegue buscá-lo: lição 04.
- **"O meu CAR tem os blocos mas não a raiz."** Ele foi gravado a partir do
  `allKeysChan()`, que perde o codec: lição 05, erros comuns.
- **"Nada aparece no terminal com `dev.log`."** O `dart run` não imprime o log
  do `dart:developer`; as lições também imprimem (veja `say()` acima).
- **"O `init` não mudou o meu repositório."** `init` numa pasta que já é
  repositório não faz nada: lição 07, erros comuns.
- **"O meu arquivo sumiu do nó."** Nada o fixava e o GC rodou: lição 09.
- **"Quero um endereço que sempre mostre a versão mais nova."** IPNS:
  lição 11.
- **"O meu download nunca termina."** Ninguém conectado tem o conteúdo e
  ninguém o anunciou, ou o nó não tem roteamento: lições 16 e 17; ponha um
  prazo: lição 19.
- **"O p2p_host não para de crescer."** Handles deixados ao Finalizer num
  laço: lição 20.
- **"Dois hosts escutam na mesma porta sem erro."** O libp2p reaproveita
  portas de propósito (para atravessar NAT): lição 13.
