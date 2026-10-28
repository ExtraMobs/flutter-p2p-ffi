# Aprendendo p2p_ffi, uma pergunta de cada vez

[English](../README.md) · **Português** · [Español](../es/README.md)

Um curso para quem programa em Dart e nunca usou IPFS. Cada lição é um
arquivo executável que responde uma pergunta, diz do que precisa (as lições
anteriores e, tecnicamente, quais peças têm de existir por baixo), executa os
erros comuns de propósito para mostrar o erro real, e termina com a próxima
pergunta que ela levanta. Leia na ordem, ou vá direto à pergunta que você tem.

```bash
dart run tool/build.dart windows   # ou linux; uma vez, compila o p2p_host
dart run example/pt/01_dart_and_go.dart
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

### Parte B · o nó kubo, em disco (a seguir)

| # | Pergunta |
|---|---|
| 07 | O que é um repositório, e por que `init`? |
| 08 | O que o nó monta para mim? |
| 09 | Por que os meus blocos somem? (pins e GC) |
| 10 | Como trabalho com pastas que mudam? (MFS) |
| 11 | Como dou um nome fixo a algo que muda? (chaves e IPNS) |
| 12 | Como uso os comandos `ipfs` que já conheço? |

### Parte C · a rede (em breve)

| # | Pergunta |
|---|---|
| 13 | Quem sou eu na rede? (chaves, peer ID, multiaddr, transportes) |
| 14 | Como dois peers conversam? (conectar, ping, um protocolo meu, mDNS) |
| 15 | Como acho quem tem um conteúdo? (DHT) |
| 16 | O que o boxo precisa para baixar um CID? |
| 17 | Como entro na rede IPFS pública? |
| 18 | Como mando mensagens em tempo real? (pubsub) |

### Parte D · usar a ponte direito (em breve)

| # | Pergunta |
|---|---|
| 19 | Como ponho prazo e cancelo? Que erros podem vir? |
| 20 | Quando preciso liberar memória? (handles) |
| 21 | Como o Go chama o meu código Dart? (callbacks) |

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
