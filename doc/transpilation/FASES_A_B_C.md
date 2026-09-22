# Fases A, B e C — Paridade de Recursos

## 1. Como ler este documento

Este documento descreve três tarefas de programação. Cada tarefa se chama
"fase". As três fases são: Fase A, Fase B e Fase C.

As seções aparecem nesta ordem:

1. Como ler este documento (esta seção).
2. Glossário. Explica cada termo técnico usado no documento.
3. O problema que as três fases resolvem.
4. O que já foi feito antes destas três fases.
5. Fase A.
6. Fase B.
7. Fase C.
8. Em que ordem executar as três fases.
9. Como verificar que uma fase terminou.
10. Regras que valem nas três fases.

As seções 5, 6 e 7 descrevem uma fase cada uma. As três seções têm exatamente a
mesma estrutura interna, na mesma ordem:

1. O que esta fase faz.
2. Por que esta fase é necessária.
3. Arquivos que você vai criar.
4. Arquivos que você vai alterar.
5. Símbolos que você vai portar.
6. Passos.
7. Como saber que a fase terminou.
8. O que não fazer nesta fase.

Convenções de escrita usadas aqui:

- Um caminho como `lib/src/node/ipfs_node.dart` é um arquivo dentro do
  repositório.
- Um texto como `dht.go:459` significa: arquivo `dht.go`, linha 459.
- Um texto como `dht.go:459-473` significa: arquivo `dht.go`, da linha 459 até a
  linha 473.
- Toda instrução está escrita como um passo numerado, começando com um verbo.
- Quando duas coisas têm nomes parecidos, o documento repete o nome completo das
  duas, em vez de escrever "a primeira" ou "a segunda".

## 2. Glossário

Esta seção explica cada termo técnico usado no documento. Os termos estão em
ordem alfabética.

| Termo | Significado |
| --- | --- |
| **auditor** | O programa `tool/audit_ast_nomenclature.py`. O auditor lê o código Dart do repositório e reporta violações de 25 regras escritas no arquivo `AGENTS.md`. |
| **AutoNAT** | Um subsistema da libp2p. O AutoNAT descobre se o próprio nó pode ser alcançado pela internet pública. Existem duas versões: AutoNAT v1 e AutoNAT v2. |
| **ConnectionGater** | Um componente da libp2p que decide aceitar ou recusar uma conexão, olhando apenas o endereço. A resposta é sim ou não. O ConnectionGater não conta quantidade. |
| **ConnManager** | Um componente da libp2p que fecha conexões quando o número de conexões passa de um teto. O ConnManager escolhe quais conexões fechar usando prioridades. |
| **DHT** | Distributed Hash Table. A rede pela qual um nó IPFS descobre quem tem um determinado bloco de dados. |
| **fase** | Uma tarefa de programação descrita neste documento. Existem três fases neste documento: Fase A, Fase B e Fase C. |
| **libp2p** | A biblioteca de rede que o IPFS usa. A versão original é escrita em Go e se chama `go-libp2p`. |
| **módulo `go.mod`** | Uma unidade de distribuição de código Go. Um módulo contém um arquivo chamado `go.mod` na sua pasta raiz. Neste projeto, cada módulo Go vira um pacote Dart separado. |
| **par real** | Outro programa IPFS de verdade, rodando de verdade, com o qual o nó Dart se comunica. Neste projeto o par real normalmente é o daemon Kubo. |
| **portar** | Reescrever código Go em Dart, mantendo os mesmos nomes, os mesmos valores padrão e o mesmo comportamento observável. |
| **prefixo de import** | Um nome curto colocado depois da palavra `as` em uma linha `import` do Dart. Exemplo: em `import 'pacote.dart' as rate;`, o prefixo de import é `rate`. |
| **rcmgr** | Abreviação de Resource Manager. O rcmgr conta conexões, streams, memória e file descriptors, e recusa quando o número passa de um limite. O nome `rcmgr` é o nome do pacote Go, declarado na pasta `p2p/host/resource-manager`. |
| **reachability** | O estado que diz se o próprio nó pode ser alcançado pela internet pública. Tem três valores possíveis: `Public`, `Private` e `Unknown`. |
| **símbolo** | Um nome declarado no código: uma classe, uma função, um método ou uma constante. |
| **stream** | Um canal de dados dentro de uma conexão. Uma conexão pode ter várias streams ao mesmo tempo. |
| **teste atômico** | Um teste automatizado que verifica um único símbolo público. Os testes atômicos ficam na pasta `test/atomic/`. O auditor exige um teste atômico para cada símbolo público. |

## 3. O problema que as três fases resolvem

O programa Kubo, escrito em Go, protege um nó IPFS com quatro defesas. O nó Dart
deste projeto tem apenas uma dessas quatro defesas.

Esta é a lista das quatro defesas. A ordem é a ordem em que o Kubo as aplica
quando chega uma conexão nova.

| Número | Defesa | O que ela faz | O nó Dart tem? |
| --- | --- | --- | --- |
| 1 | `ModeAuto` da DHT | Impede que o nó sirva a DHT enquanto o AutoNAT não confirmar que o nó é alcançável pela internet pública. | Não |
| 2 | ConnectionGater | Recusa a conexão se o endereço estiver bloqueado. Responde sim ou não. | Não |
| 3 | rcmgr | Recusa a conexão se o número de conexões, streams, memória ou file descriptors passar de um limite. | Não |
| 4 | ConnManager | Fecha conexões antigas quando o número de conexões passa de um teto. | **Sim**, desde o commit `45231ad5` |

A ordem 2, 3, 4 está escrita no código Go em `upgrader/listener.go:178-203`.

O efeito de faltarem as defesas 1, 2 e 3 foi medido em rede real: o número de
conexões de entrada subiu de 240 no primeiro minuto para 658 no nono minuto, e
continuou subindo.

As três fases deste documento preparam as defesas 1, 2 e 3. As três fases **não
ligam** as defesas. Ligar as defesas é trabalho de fases posteriores, chamadas
Fase D e Fase H, que não estão descritas neste documento.

## 4. O que já foi feito antes destas três fases

Esta seção existe para você não refazer trabalho que já está pronto.

| Trabalho já concluído | Commit |
| --- | --- |
| Pacote `packages/transpiled_libp2p_kad_dht/` criado, e o porte da DHT movido para dentro dele | `11b9f78d` |
| Tipos `Addr` e `Prefix` criados em `packages/boilerplate/lib/net_netip/` | `11b9f78d` |
| Tipos `Ip` e `IpNet` criados em `packages/boilerplate/lib/net/` | `c27d2c3b` |
| Pacote `packages/transpiled_golang_x_time/` criado, com o token bucket de `golang.org/x/time/rate` | `c27d2c3b` |
| Porte de `go-libp2p/x/rate` em `packages/transpiled_libp2p/lib/src/x/rate/limiter.dart` | `8307427d` |
| Regra 25 do auditor, sobre prefixo de import | `e086ddf4`, `a67affac`, `f93d6ca2` |

Os tipos `Addr`, `Prefix`, `Ip` e `IpNet` existem porque as Fases B e C precisam
deles. Não escreva código novo para calcular máscara de sub-rede. Use esses
tipos.

## 5. Fase A — Motor de escalonamento de limites

### 5.1. O que esta fase faz

Esta fase cria um arquivo Dart novo que sabe calcular limites de recursos a
partir da memória e do número de file descriptors da máquina.

Esta fase **não liga** esses limites em nada. Depois desta fase, o programa
continua funcionando exatamente como antes. A fase apenas acrescenta a
capacidade de calcular.

### 5.2. Por que esta fase é necessária

O arquivo Dart
`packages/transpiled_libp2p/lib/src/p2p/host/resource_manager/limit.dart` já
existe e tem 308 linhas. Esse arquivo Dart corresponde ao arquivo Go `limit.go`.

Existe um segundo arquivo Go, chamado `limit_defaults.go`, com 876 linhas. Esse
segundo arquivo Go **não tem nenhum correspondente em Dart**. Esse segundo
arquivo Go contém os números padrão e a fórmula que escala os números conforme a
memória da máquina.

Sem esse segundo arquivo, o limitador Dart atual trata cinco escopos como
ilimitados. O valor usado para "ilimitado" é `1 << 60`. Os cinco escopos são:
system, transient, service, protocol e peer. Isso está no arquivo `limit.dart`,
nas linhas 236 a 269.

### 5.3. Arquivos que você vai criar

Um arquivo:

- `packages/transpiled_libp2p/lib/src/p2p/host/resource_manager/limit_defaults.dart`

### 5.4. Arquivos que você vai alterar

Um arquivo:

- `packages/transpiled_libp2p/lib/src/p2p/host/resource_manager/limit.dart` —
  apenas se houver lógica duplicada, conforme o passo 4 da seção 5.6.

### 5.5. Símbolos que você vai portar

Todos os símbolos abaixo estão no arquivo Go `limit_defaults.go`.

| Símbolo Go | Linhas no arquivo Go |
| --- | --- |
| `ScalingLimitConfig` | 25 a 63 |
| `AddServiceLimit`, `AddProtocolLimit`, `AddPeerLimit`, `AddServicePeerLimit`, `AddProtocolPeerLimit` | 65 a 114 |
| `PartialLimitConfig` | 350 a 378 |
| `ConcreteLimitConfig` | 513 a 541 |
| `Build` | 297 a 349 |
| `Apply` | 447 a 490 |
| `ToPartialLimitConfig` | 557 a 581 |
| `Scale` | 582 a 628 |
| `AutoScale` | 629 a 635 |
| `scale` | 636 a 662 |
| `DefaultLimits` | 663 a 849 |
| `infiniteBaseLimit` e `InfiniteLimits` | 851 a 875 |

### 5.6. Passos

1. Abra o arquivo
   `go-ipfs-reference/libp2p-index/p2p_host_resource-manager.md`. Esse arquivo é
   o índice AST. Ele lista todos os símbolos do pacote Go e diz quem usa cada
   um. Leia esse arquivo antes de abrir qualquer arquivo `.go`.
2. Abra o arquivo Go
   `go-ipfs-reference/go-libp2p/p2p/host/resource-manager/limit_defaults.go`.
3. Crie o arquivo Dart
   `packages/transpiled_libp2p/lib/src/p2p/host/resource_manager/limit_defaults.dart`
   e escreva nele os símbolos listados na seção 5.5.
4. Verifique se a lógica de `LimitVal.Build` (linhas 164 a 176 do arquivo Go) e
   de `LimitVal64.Build` (linhas 246 a 259 do arquivo Go) já existe no arquivo
   Dart `limit.dart`, no método `_build`, linhas 189 a 217. Se já existir,
   **chame o código existente**. Não escreva uma segunda cópia da mesma lógica.
5. Crie o arquivo de teste
   `test/atomic/nivel_1/limit_defaults_atomic_tests.dart`.
6. Escreva um teste atômico para cada símbolo público que você criou no passo 3.
7. Execute o procedimento de verificação descrito na seção 9 deste documento.

### 5.7. Como saber que a fase terminou

A Fase A terminou quando as três afirmações abaixo forem verdadeiras ao mesmo
tempo.

1. O comando `python tool/audit_ast_nomenclature.py --tests --severity ERROR`
   termina com a mensagem `NENHUMA INCONSISTÊNCIA ENCONTRADA`.
2. O comando `dart test -j 1` na raiz do repositório termina sem nenhuma falha.
3. O teste atômico que você escreveu confere os números exatos abaixo,
   produzidos pela chamada `DefaultLimits.scale(1 << 30, 256)`:

| Campo do escopo System | Valor esperado |
| --- | --- |
| `ConnsInbound` | 64 |
| `Conns` | 128 |
| `StreamsInbound` | 1024 |
| `Memory` | 128 MiB |
| `FD` | 256 |

Esta fase **não precisa** de um par real. Os cálculos da Fase A são aritmética
pura. Um teste atômico basta.

### 5.8. O que não fazer nesta fase

1. Não altere o arquivo
   `packages/transpiled_libp2p/lib/src/p2p/net/swarm/swarm.dart`.
2. Não altere o arquivo
   `packages/transpiled_libp2p/lib/src/p2p/transport/basic_upgrader.dart`.
3. Não altere o arquivo `lib/src/node/ipfs_node.dart`.
4. Não troque o `NullResourceManager` por outro objeto em lugar nenhum. Trocar o
   `NullResourceManager` é trabalho da Fase D.
5. Não porte os arquivos Go `metrics.go` (168 linhas), `stats.go` (436 linhas) e
   `trace.go` (698 linhas). Esses três arquivos contêm telemetria. O projeto não
   expõe telemetria.

## 6. Fase B — ConnectionGater e o seu chamador

### 6.1. O que esta fase faz

Esta fase faz duas coisas:

1. Cria a classe `BasicConnectionGater`, que decide aceitar ou recusar uma
   conexão olhando o endereço.
2. Faz o código de aceitação de conexões chamar essa classe.

A segunda coisa é mais importante que a primeira. Hoje **não existe nenhuma
chamada** ao ConnectionGater no caminho que aceita conexões.

### 6.2. Por que esta fase é necessária

O contrato do ConnectionGater já existe em Dart, no arquivo
`packages/transpiled_libp2p/lib/src/core/connmgr/gater.dart`, com 32 linhas.
Esse arquivo declara a interface e nada mais.

Faltam duas coisas:

1. A classe concreta que implementa a interface.
2. A chamada. Os arquivos `basic_upgrader.dart` e `tcp_transport.dart` não têm
   sequer um campo para guardar um ConnectionGater.

No Go, a chamada acontece em `upgrader/listener.go`, linhas 185 a 202, e a ordem
é esta:

1. Primeiro o ConnectionGater decide sim ou não.
2. Depois o rcmgr conta e decide.

Essa ordem existe porque a checagem do ConnectionGater é barata e a do rcmgr é
cara.

### 6.3. Arquivos que você vai criar

Um arquivo:

- `packages/transpiled_libp2p/lib/src/p2p/net/conngater/conngater.dart`

### 6.4. Arquivos que você vai alterar

Dois arquivos:

- `packages/transpiled_libp2p/lib/src/p2p/transport/basic_upgrader.dart`
- `packages/transpiled_libp2p/lib/src/p2p/transport/tcp_transport.dart`

### 6.5. Símbolos que você vai portar

Todos os símbolos abaixo estão no arquivo Go `p2p/net/conngater/conngater.go`,
que tem 352 linhas.

| Símbolo Go | Linhas no arquivo Go |
| --- | --- |
| `BasicConnectionGater` | 24 a 45 |
| `NewBasicConnectionGater` | 46 a 63 |
| `loadRules` | 64 a 125 |
| `BlockPeer`, `UnblockPeer`, `ListBlockedPeers` | 126 a 174 |
| `BlockAddr`, `UnblockAddr`, `ListBlockedAddrs` | 175 a 225 |
| `BlockSubnet`, `UnblockSubnet`, `ListBlockedSubnets` | 226 a 276 |
| Os cinco métodos `Intercept...` | 277 a 352 |

Em Dart, `NewBasicConnectionGater` vira o construtor da classe
`BasicConnectionGater`. Não crie uma função solta chamada
`newBasicConnectionGater`. A regra 5 do auditor proíbe funções soltas com nome
começando em `new`.

### 6.6. Passos

1. Abra o arquivo `go-ipfs-reference/libp2p-index/p2p_net_conngater.md`. Esse
   arquivo é o índice AST do pacote. Leia esse arquivo antes de abrir o arquivo
   `.go`.
2. Abra o arquivo Go
   `go-ipfs-reference/go-libp2p/p2p/net/conngater/conngater.go`.
3. Crie o arquivo Dart
   `packages/transpiled_libp2p/lib/src/p2p/net/conngater/conngater.dart` e
   escreva nele os símbolos listados na seção 6.5.
4. Use os tipos `Ip` e `IpNet` do pacote `boilerplate`, importando
   `package:boilerplate/net/golang.dart`. Leia a seção 6.9 antes de escolher
   entre `Ip` e `Addr`.
5. Para guardar as regras em disco, use o pacote `transpiled_datastore`. O
   arquivo `pstoreds/peerstore.dart` já usa esse pacote e serve de exemplo.
6. Abra o arquivo
   `packages/transpiled_libp2p/lib/src/p2p/transport/basic_upgrader.dart`.
7. Acrescente ao `BasicUpgrader` um parâmetro novo, opcional, chamado `gater`,
   do tipo `ConnectionGater?`.
8. Localize a linha 455 do arquivo `basic_upgrader.dart`. Nessa linha existe a
   chamada `_resourceManager.openConnection(...)`.
9. Acrescente uma chamada a `gater.interceptAccept(...)` **imediatamente antes**
   da chamada `_resourceManager.openConnection(...)`. Se o `gater` for nulo, não
   chame nada e siga em frente.
10. Se `interceptAccept` devolver falso, feche a conexão e não continue a
    negociação.
11. Abra o arquivo
    `packages/transpiled_libp2p/lib/src/p2p/transport/tcp_transport.dart` e faça
    o `TcpTransport` repassar o `gater` ao `BasicUpgrader`.
12. Crie o arquivo de teste
    `test/atomic/nivel_2/libp2p_conngater_atomic_tests.dart`.
13. Escreva um teste atômico para cada símbolo público que você criou no passo
    3.
14. Execute o procedimento de verificação descrito na seção 9 deste documento.

### 6.7. Como saber que a fase terminou

A Fase B terminou quando as quatro afirmações abaixo forem verdadeiras ao mesmo
tempo.

1. O comando `python tool/audit_ast_nomenclature.py --tests --severity ERROR`
   termina com a mensagem `NENHUMA INCONSISTÊNCIA ENCONTRADA`.
2. O comando `dart test -j 1` na raiz do repositório termina sem nenhuma falha.
3. Existe um teste atômico que cria um `BasicConnectionGater`, chama `blockAddr`
   com um endereço, e depois verifica que `interceptAccept` devolve falso para
   esse mesmo endereço.
4. Existe um teste contra par real que faz o seguinte: sobe um daemon Kubo
   local, bloqueia o endereço IP desse daemon Kubo, e verifica que a conexão
   vinda desse daemon Kubo é recusada.

A afirmação 4 é obrigatória. Um teste atômico sozinho **não** comprova esta
fase, porque um teste atômico não prova que a chamada foi ligada ao caminho real
de aceitação de conexões.

### 6.8. O que não fazer nesta fase

1. Não bloqueie nenhum endereço por padrão. O comportamento padrão é aceitar
   tudo. Se esta fase mudar o comportamento padrão, os testes de
   interoperabilidade vão quebrar.
2. Não altere o arquivo `lib/src/node/ipfs_node.dart`.
3. Não ligue o rcmgr. Ligar o rcmgr é trabalho da Fase D.

### 6.9. Aviso importante sobre tipos de endereço

Existem dois tipos de endereço IP no pacote `boilerplate`, e eles **não são
intercambiáveis**.

| Tipo | Import | Comportamento de `contains` |
| --- | --- | --- |
| `Ip` e `IpNet` | `package:boilerplate/net/golang.dart` | `10.0.0.0/8` **contém** `::ffff:10.1.2.3` |
| `Addr` e `Prefix` | `package:boilerplate/net_netip/golang.dart` | `10.0.0.0/8` **não contém** `::ffff:10.1.2.3` |

A Fase B usa `Ip` e `IpNet`, porque o arquivo Go `conngater.go` usa o tipo Go
`net.IP`, que tem o primeiro comportamento.

A Fase D vai usar `Addr` e `Prefix`, porque o arquivo Go `conn_limiter.go` usa o
tipo Go `netip.Addr`, que tem o segundo comportamento.

Se você usar o tipo errado, o código vai compilar e os testes podem passar, mas
o comportamento vai divergir do Go em endereços IPv4 mapeados em IPv6.

## 7. Fase C — AutoNAT versão 1, lado cliente

### 7.1. O que esta fase faz

Esta fase faz o nó Dart descobrir sozinho se ele pode ser alcançado pela
internet pública, e anunciar essa descoberta para o resto do programa.

O anúncio acontece através de um evento chamado `EvtLocalReachabilityChanged`.

### 7.2. Por que esta fase é necessária

O evento `EvtLocalReachabilityChanged` já existe no código Dart, no arquivo
`packages/transpiled_libp2p/lib/src/core/event/reachability.dart`, linhas 9 a
13.

Duas partes do programa já escutam esse evento:

1. `packages/transpiled_libp2p_kad_dht/lib/src/dht_server.dart`, linha 133.
2. `packages/transpiled_libp2p/lib/src/p2p/host/autorelay/autorelay.dart`,
   linhas 63 a 65.

**Nenhuma parte do programa emite esse evento.** A classe que deveria emitir se
chama `AmbientAutoNat`, está no arquivo
`packages/transpiled_libp2p/lib/src/p2p/host/autonat/autonat.dart`, e tem 69
linhas. Essa classe nunca é criada em código de produção. O método
`setReachability` dessa classe só é chamado dentro de um teste.

O resultado é este: a reachability do nó Dart fica no valor `Unknown` para
sempre.

### 7.3. Aviso: a versão 2 do AutoNAT não serve para esta fase

Existem dois protocolos AutoNAT no `go-libp2p`, e só um deles resolve o problema
descrito na seção 7.2.

| Protocolo | Pasta no Go | Emite `EvtLocalReachabilityChanged`? |
| --- | --- | --- |
| AutoNAT v1 | `p2p/host/autonat` | **Sim**, em `autonat.go:152` |
| AutoNAT v2 | `p2p/protocol/autonatv2` | **Não.** Zero ocorrências no pacote inteiro |

O AutoNAT v2 verifica um endereço específico quando outro subsistema pede. O
AutoNAT v2 nunca decide nem publica a reachability do próprio nó.

Portanto: **porte o AutoNAT v1.** Não porte o AutoNAT v2 nesta fase. O programa
Kubo ativa o AutoNAT v2 em `nat.go:29`, mas isso não muda a conclusão acima.

### 7.4. Arquivos que você vai criar

Sete arquivos, todos dentro da pasta
`packages/transpiled_libp2p/lib/src/p2p/host/autonat/`:

1. `client.dart`
2. `dialpolicy.dart`
3. `interface.dart`
4. `notify.dart`
5. `options.dart`
6. `proto.dart`
7. Testes: `test/atomic/nivel_2/libp2p_autonat_atomic_tests.dart`

### 7.5. Arquivos que você vai alterar

Dois arquivos:

- `packages/transpiled_libp2p/lib/src/p2p/host/autonat/autonat.dart` — hoje tem
  69 linhas e vai crescer muito.
- `lib/src/node/ipfs_node.dart` — apenas os passos 8, 9 e 10 da seção 7.7.

### 7.6. Símbolos que você vai portar

Todos os arquivos Go abaixo estão na pasta
`go-ipfs-reference/go-libp2p/p2p/host/autonat/`.

| Arquivo Go | Linhas | O que você vai portar dele |
| --- | --- | --- |
| `autonat.go` | 455 | A classe `AmbientAutoNAT`. O construtor `New`, a partir da linha 68. O laço de fundo. O contador `confidence` e a constante `maxConfidence`, que vale 3, na linha 24. A emissão do evento, na linha 152. |
| `client.go` | 129 | `NewAutoNATClient` e `DialBack`. |
| `dialpolicy.go` | 95 | `skipDial` e `skipPeer`. |
| `options.go` | 155 | Apenas as opções que o código portado realmente usa. |
| `proto.go` | 39 | As mensagens `DIAL` e `DIAL_RESPONSE`. |
| `notify.go` | 30 | `Connected` e `Disconnected`. |
| `interface.go` | 31 | O contrato. |

Soma: aproximadamente 934 linhas de Go.

O arquivo `.proto` do AutoNAT v1 declara **uma única** mensagem, em sintaxe
proto2. Você não precisa do programa `protoc`. A pasta
`packages/transpiled_libp2p/lib/src/p2p/protocol/circuitv2/pb/` contém um
exemplo de mensagem escrita à mão. Use essa pasta como modelo.

A interface `Notifiee`, citada no arquivo `notify.go`, já existe em Dart, no
arquivo `packages/transpiled_libp2p/lib/src/core/network/network.dart`, linha
547. Use a interface existente.

### 7.7. Passos

1. Abra o arquivo `go-ipfs-reference/libp2p-index/p2p_host_autonat.md`. Esse
   arquivo é o índice AST do pacote. Leia esse arquivo antes de abrir qualquer
   arquivo `.go`.
2. Porte o arquivo `proto.go` para `proto.dart`. Comece por ele, porque os
   outros arquivos dependem das mensagens.
3. Porte o arquivo `dialpolicy.go` para `dialpolicy.dart`.
4. Porte o arquivo `client.go` para `client.dart`.
5. Porte o arquivo `interface.go` para `interface.dart` e o arquivo `notify.go`
   para `notify.dart`.
6. Porte o arquivo `options.go` para `options.dart`.
7. Reescreva o arquivo `autonat.dart`, que hoje tem 69 linhas, com a classe
   `AmbientAutoNat` completa.
8. Abra o arquivo `lib/src/node/ipfs_node.dart`.
9. Crie um objeto `AmbientAutoNat` de verdade nesse arquivo, registre esse
   objeto como `Notifiee` do `Swarm`, e passe esse objeto ao `BasicHost` pelo
   parâmetro `autoNat`.
10. Confirme que o `BasicHost` fecha o `AmbientAutoNat` no método `close()`. O
    arquivo `basic_host.dart` já tem essa chamada nas linhas 62, 91 e 244.
    Nenhuma infraestrutura nova é necessária.
11. Crie o arquivo de teste
    `test/atomic/nivel_2/libp2p_autonat_atomic_tests.dart`.
12. Escreva um teste atômico para cada símbolo público que você criou.
13. Escreva o teste contra par real descrito no item 3 da seção 7.8.
14. Execute o procedimento de verificação descrito na seção 9 deste documento.

### 7.8. Como saber que a fase terminou

A Fase C terminou quando as quatro afirmações abaixo forem verdadeiras ao mesmo
tempo.

1. O comando `python tool/audit_ast_nomenclature.py --tests --severity ERROR`
   termina com a mensagem `NENHUMA INCONSISTÊNCIA ENCONTRADA`.
2. O comando `dart test -j 1` na raiz do repositório termina sem nenhuma falha.
3. Existe um teste contra par real que faz o seguinte: sobe um daemon Kubo local
   que responde a pedidos de dial-back, conecta o nó Dart a esse daemon Kubo, e
   verifica que o nó Dart emite o evento `EvtLocalReachabilityChanged` com o
   valor `Public` quando o dial-back funciona, e com o valor `Private` quando o
   dial-back falha.
4. Existem testes atômicos que verificam `skipDial`, `skipPeer` e a saturação do
   contador `confidence` no valor 3.

A afirmação 3 é obrigatória, e a razão é esta: o código Dart atual emite o
evento sem sondar ninguém. Um teste que apenas verifique se o evento foi emitido
passaria tanto com o código antigo quanto com o código novo. Só um par real
distingue os dois.

### 7.9. O que não fazer nesta fase

1. **Não troque o valor padrão do `DhtServer`.** O arquivo
   `packages/transpiled_libp2p_kad_dht/lib/src/dht_server.dart` tem, na linha
   59, o valor padrão `ModeOpt.autoServer`. Deixe esse valor como está. Trocar
   esse valor para `ModeOpt.auto` é trabalho da Fase H, que não está descrita
   neste documento.
2. Não porte o arquivo Go `svc.go`, que tem 300 linhas. Esse arquivo contém o
   lado que responde a pedidos de dial-back de outros nós. Esse lado não decide
   a reachability do próprio nó.
3. Não porte o AutoNAT v2, pela razão explicada na seção 7.3.
4. Não porte o arquivo `metrics.go`.

### 7.10. Por que a máquina de modos da DHT já está pronta

Esta seção existe para evitar trabalho duplicado.

O arquivo `packages/transpiled_libp2p_kad_dht/lib/src/dht_server.dart` já
contém, portados e corretos:

- O tipo `ModeOpt`, com os valores `auto`, `client`, `server` e `autoServer`.
- O método `_handleLocalReachabilityChangedEvent`, que traduz o valor da
  reachability em "servir" ou "não servir".
- Os métodos `_moveToServerMode` e `_moveToClientMode`.
- A assinatura do evento `EvtLocalReachabilityChanged` no barramento de eventos.

Você não precisa escrever nada disso. A Fase C fornece apenas o emissor do
evento.

## 8. Em que ordem executar as três fases

### 8.1. As três fases podem ser feitas ao mesmo tempo

A Fase A, a Fase B e a Fase C alteram arquivos diferentes. Nenhuma das três
fases lê ou escreve um arquivo que outra fase também escreve, com uma exceção
descrita na seção 8.2.

| Fase | Arquivos que ela escreve |
| --- | --- |
| Fase A | `resource_manager/limit_defaults.dart` e `resource_manager/limit.dart` |
| Fase B | `p2p/net/conngater/conngater.dart`, `basic_upgrader.dart`, `tcp_transport.dart` |
| Fase C | tudo dentro de `p2p/host/autonat/`, e depois `lib/src/node/ipfs_node.dart` |

### 8.2. A única restrição

O arquivo `lib/src/node/ipfs_node.dart` é escrito apenas pela Fase C, nos passos
8, 9 e 10 da seção 7.7.

Se você dividir o trabalho entre várias pessoas ou vários agentes, **apenas uma
delas pode escrever `lib/src/node/ipfs_node.dart`**. Duas pessoas escrevendo o
mesmo arquivo ao mesmo tempo sobrescrevem o trabalho uma da outra.

### 8.3. Ordem recomendada quando houver uma pessoa só

1. Fase A.
2. Fase B.
3. Fase C.

Essa ordem vai da menor para a maior. A Fase A tem risco zero, porque não liga
nada. A Fase C é a maior, com aproximadamente 934 linhas de Go.

### 8.4. Relação com a Fase D

A Fase D liga o rcmgr de verdade. A Fase D não está descrita neste documento.

A Fase D depende da Fase A, porque a Fase A cria os limites que a Fase D vai
usar.

A Fase D **não depende** da Fase C do ponto de vista de compilação. Nenhum
arquivo da Fase D importa um símbolo da Fase C.

Mesmo assim, faça a Fase C antes da Fase D. A razão é esta: se você ligar os
limites duros antes de o nó saber decidir se deve servir a DHT, e algo quebrar,
existirão duas causas possíveis ao mesmo tempo, e será difícil saber qual das
duas causou a quebra.

## 9. Como verificar que uma fase terminou

Execute os comandos abaixo na ordem em que aparecem. Execute todos, mesmo que um
deles pareça desnecessário.

Todos os comandos rodam a partir da pasta raiz do repositório, exceto onde
estiver escrito o contrário.

### 9.1. Os comandos, na ordem

```
dart format lib bin test packages
python tool/audit_ast_nomenclature.py --tests --severity ERROR
python tool/audit_ast_nomenclature.py --tests
dart test -j 1
for d in packages/*/; do (cd "$d" && dart test -j 1); done
dart test --preset network -j 1
cd test/interop && dart test -j 1
python tool/audit_ast_nomenclature.py --progress
python tool/audit_ast_nomenclature.py --markdown --output audit_report.md
```

### 9.2. O que cada comando faz e o que esperar

| Comando | O que ele faz | Resultado esperado |
| --- | --- | --- |
| `dart format ...` | Formata o código. | Termina sem erro. Rode este comando **primeiro**, nunca por último. |
| `audit... --severity ERROR` | Roda as 25 regras e mostra só os erros. | A mensagem `NENHUMA INCONSISTÊNCIA ENCONTRADA`. |
| `audit... --tests` | Mostra também avisos e notas de cobertura. | Leia a saída. Resolva o que pertencer à sua fase. |
| `dart test -j 1` | Roda os testes do pacote raiz. | `+4141 ~19: All other tests passed!` ou número maior. |
| o laço `for d in packages/*/` | Roda os testes de cada pacote. | Nenhuma linha contendo `Some tests failed`. |
| `dart test --preset network -j 1` | Roda os testes que usam internet de verdade. | Nenhuma falha. |
| `cd test/interop && dart test -j 1` | Roda os testes contra um daemon Kubo de verdade. | Ver a seção 9.3. |
| `audit... --progress` | Regera o arquivo `PROGRESS_RELATORY.md`. | Termina sem erro. |
| `audit... --markdown ...` | Regera o arquivo `audit_report.md`. | Termina sem erro. |

### 9.3. Uma falha esperada nos testes de interoperabilidade

O teste `test/interop/test/local_kubo_transport_matrix_test.dart` **falha de
propósito**, no endereço `/webrtc-direct`.

Essa falha é esperada e correta. Ela acontece porque o protocolo DTLS ainda não
foi portado.

Portanto:

- Uma falha, e apenas essa falha: o resultado está correto.
- Qualquer outra falha: é uma regressão causada pelo seu trabalho. Corrija antes
  de continuar.

### 9.4. Uma mensagem de erro que você pode ignorar

Neste ambiente Windows, o comando `dart test` às vezes termina com a mensagem
`PathExistsException` e um código de saída diferente de zero, **depois** de ter
escrito `All other tests passed!`.

Essa mensagem vem do cache interno do executor de testes, não do seu código. Se
a linha `All other tests passed!` apareceu, os testes passaram.

### 9.5. Depois de verificar

1. Escreva no arquivo `doc/transpilation/PROGRESS.md` o rastreamento da sua
   fase, no formato: nome do chamador Go, nome do símbolo chamado, módulo e
   revisão, nome do símbolo Dart e pacote Dart.
2. Escreva no mesmo arquivo qualquer divergência deliberada entre o código Go e
   o código Dart, junto com a razão da divergência.

## 10. Regras que valem nas três fases

### 10.1. Leia o índice AST antes do arquivo `.go`

Para cada pacote Go que você for portar, existe um arquivo de índice na pasta
`go-ipfs-reference/<módulo>-index/`.

Exemplo: o pacote Go `x/rate` tem o índice
`go-ipfs-reference/libp2p-index/x_rate.md`.

O índice contém três informações que economizam tempo:

1. A lista completa dos símbolos do pacote.
2. A lista de identificadores que cada função chama.
3. A lista chamada "referenced by", que diz quais outros pacotes usam cada
   símbolo.

A terceira informação é a mais útil: ela diz se um símbolo é usado por algo que
este projeto já portou. Se ninguém usa o símbolo, talvez ele não precise ser
portado.

O índice é gerado sem análise de tipos. Um nome usado por várias declarações
aparece em todas elas. Use o índice para saber onde olhar, e confirme o detalhe
no arquivo `.go`.

### 10.2. Prefixo de import (Regra 25 do auditor)

Quando dois pacotes declaram um símbolo com o mesmo nome, resolva na linha de
`import`, com um prefixo. **Não** renomeie o símbolo, e **não** use `hide`.

Qual prefixo usar:

| Situação | Prefixo | Exemplo |
| --- | --- | --- |
| Import de outro pacote Dart | o nome da biblioteca | `as golang_x_time` |
| Import interno, com `/src/` no caminho | o nome do pacote Go | `as rate`, `as rcmgr` |
| O prefixo escolhido tem o mesmo nome de uma variável ou método do arquivo | o mesmo nome, mais o sufixo `_package` | `as raw_package` |

### 10.3. Ordem obrigatória ao renomear um prefixo

Se você precisar trocar um prefixo de import existente, siga esta ordem. A ordem
inversa não funciona.

1. Renomeie primeiro a variável ou o método que tem o nome conflitante.
2. Troque o prefixo depois.

A razão: enquanto o prefixo antigo ainda estiver no arquivo, o nome conflitante
só pode se referir à variável. Depois da troca, o prefixo e a variável passam a
ter o mesmo nome, e nenhuma busca por texto consegue separar os dois.

### 10.4. Use os tipos do pacote `boilerplate`

Não escreva código novo para:

- calcular máscara de sub-rede;
- comparar prefixos de rede;
- converter endereço IP entre formatos;
- reproduzir estouro de inteiro do Go.

Esses cálculos já existem em `packages/boilerplate/`. A regra 10 do auditor
proíbe reimplementar.

### 10.5. Todo símbolo público novo nasce com teste atômico

A regra 24 do auditor exige um teste atômico para cada função, método, getter,
setter e operador público.

O teste precisa ter asserção de verdade. O auditor recusa:

- teste com corpo vazio;
- teste que só tem comentário;
- teste que só chama `fail()`.

O nome do teste precisa começar com o nome do símbolo, assim:
`test('apply() - descrição do caso', ...)`.

Escolha a pasta conforme o que o teste precisa para rodar:

| Pasta | Use quando o teste |
| --- | --- |
| `test/atomic/nivel_1/` | só faz cálculo, sem rede e sem disco |
| `test/atomic/nivel_2/` | usa objetos em memória, sem daemon externo |
| `test/atomic/nivel_3/` | precisa de socket de rede real ou do daemon Kubo |

### 10.6. Gere os valores esperados executando Go

Quando um teste precisar de um valor esperado, produza esse valor executando o
código Go, e não o deduzindo de cabeça.

O programa Go está instalado nesta máquina. O código Go de referência está em
`go-ipfs-reference/`.

Escreva no comentário do teste que o valor veio da execução em Go, e escreva a
versão do Go usada.
