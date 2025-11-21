# Comunicação entre processos via memória partilhada (POSIX/UNIX)

Quando dois processos precisam de comunicar, é comum pensar em mecanismos como pipes ou sockets, onde as mensagens são trocadas através do sistema operativo. No entanto, há situações em que é mais eficiente partilhar diretamente dados em memória, sobretudo quando o volume de informação é grande ou o acesso tem de ser muito rápido. A memória partilhada surge precisamente como resposta a esta necessidade: permite que vários processos, em sistemas POSIX/UNIX, vejam e manipulem a mesma região de memória, reduzindo cópias e overhead. Nesta introdução, o objetivo não é construir um sistema robusto de produção, mas sim perceber o conceito básico e as suas implicações, sem ainda recorrer a semáforos ou outras primitivas de sincronização.

## Ideia Central

Em condições normais, cada processo tem o seu próprio espaço de endereços, isolado dos restantes, o que garante segurança e independência. A memória partilhada é uma exceção controlada a este isolamento: o sistema operativo cria uma região especial de memória e mapeia-a simultaneamente em dois ou mais processos. Cada processo obtém um ponteiro para essa região e passa a poder ler e escrever nela como se se tratasse de memória sua. Na prática, isto funciona como um “quadro branco” comum: tudo o que um processo escreve nessa zona torna-se imediatamente visível aos outros que a partilham. A eficiência resulta do facto de os dados não serem copiados entre processos, mas apenas acedidos diretamente em RAM.

## Exemplo conceptual

Um exemplo simples é o padrão produtor–consumidor com um único produtor e um único consumidor. Imagina-se uma pequena estrutura em memória partilhada que funciona como uma “caixa” com um campo de estado e um campo de dados. O produtor só escreve na caixa quando esta está marcada como vazia, coloca aí a mensagem e, no fim, assinala que a caixa está cheia. O consumidor, por sua vez, espera até ver que a caixa está cheia, lê a mensagem e volta a marcar a caixa como vazia. Esta disciplina cria uma alternância de acessos: primeiro escreve o produtor, depois lê o consumidor, e assim sucessivamente. Conceitualmente, isto mostra como dois processos podem coordenar-se apenas com variáveis em memória partilhada, sem recorrer a canais de comunicação adicionais.

## Cuidados (sem semáforos)

Ao dispensar semáforos e outros mecanismos de sincronização, aceitamos limitações importantes e temos de ser muito conservadores no desenho do protocolo. Em primeiro lugar, é crucial restringir o cenário: um único produtor e um único consumidor, com regras claras sobre quem escreve e quem lê em cada momento, para reduzir a probabilidade de condições de corrida. Em segundo lugar, a coordenação é frequentemente implementada com espera ativa, em que um processo fica a testar repetidamente um campo de estado até este mudar, o que consome CPU e não é escalável. Em terceiro lugar, a falta de proteção torna o sistema vulnerável a estados inconsistentes: se um processo morrer a meio de uma atualização, o outro pode ficar bloqueado ou ler dados incompletos. Finalmente, é necessário cuidar do layout dos dados (estruturas simples, sem ponteiros para memória privada), das permissões de acesso e da limpeza dos recursos, para evitar fugas de memória partilhada e problemas de segurança.

## Funções a usar

### Memória partilhada System V (para referência)

Se quiseres também mencionar a API “clássica” de System V IPC:

1. Cabeçalhos

``` #include <sys/ipc.h> ``` 

``` #include <sys/shm.h> ``` 

2. Funções principais

``` int shmget(key_t key, size_t size, int shmflg); ``` – cria ou obtém um segmento de memória partilhada.

``` void *shmat(int shmid, const void *shmaddr, int shmflg); ``` – anexa (mapeia) o segmento ao espaço de endereços do processo.

``` int shmdt(const void *shmaddr); ``` – desanexa o segmento.

``` int shmctl(int shmid, int cmd, struct shmid_ds *buf); ``` – controla/consulta/remover o segmento (IPC_RMID, etc.).

## Mensagem final

A comunicação entre processos via memória partilhada oferece grandes vantagens de desempenho, ao permitir que vários processos acedam de forma direta e rápida a dados comuns, como se trabalhassem num mesmo “quadro branco” em RAM. No entanto, essa potência vem acompanhada de riscos: sem mecanismos de sincronização adequados, é fácil cair em condições de corrida, bloqueios ou incoerências de dados. Nesta fase introdutória, o uso de exemplos simples, sem semáforos, é útil para fixar a ideia central e perceber intuitivamente como a memória partilhada funciona. Ao mesmo tempo, estas limitações servem de motivação natural para, mais à frente, introduzir semáforos, mutexes e variáveis de condição, que tornam possível o uso de memória partilhada de forma segura e robusta em sistemas reais.

## Nota
Deve utilizar os comandos ``` ipcs ``` e ``` ipcrm ``` para remover blocos não libertados devido ao funcionamento incorreto dos programas.
