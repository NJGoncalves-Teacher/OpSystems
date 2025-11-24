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

## Apresentação dos semáforos

Semáforos são mecanismos de sincronização fornecidos pelo sistema operativo para controlar o acesso concorrente a recursos partilhados, como uma região de memória partilhada entre processos. Em POSIX/UNIX, os semáforos permitem que vários processos cooperem definindo “regras de passagem”: antes de aceder ao recurso, o processo pede autorização ao semáforo; quando termina, devolve essa autorização. Assim, evita-se que dois processos modifiquem, ao mesmo tempo, dados que devem ser tratados de forma consistente.

No contexto da memória partilhada, os semáforos aparecem como a “peça que falta”: a memória partilhada fornece o local comum para os dados, mas não impõe qualquer ordem de acesso; os semáforos fornecem essa disciplina, garantindo exclusão mútua ou coordenação entre produtores e consumidores.

---

## Descrição conceptual

Um semáforo pode ser visto, de forma abstracta, como um contador inteiro protegido pelo sistema operativo:

* Quando um processo faz uma operação de **espera** (clássico `P`, em POSIX `sem_wait`), o semáforo é decrementado.

  * Se o valor ainda for não negativo, o processo continua.
  * Se o valor se tornaria negativo, o processo é bloqueado até outro processo “libertar” o semáforo.

* Quando um processo faz uma operação de **sinal** (clássico `V`, em POSIX `sem_post`), o semáforo é incrementado.

  * Se houver processos bloqueados à espera desse semáforo, o sistema operativo acorda um deles.

Com esta mecânica simples, há dois usos típicos na comunicação via memória partilhada:

1. **Exclusão mútua (mutex)**
   O semáforo é inicializado com o valor 1.

   * Só um processo de cada vez consegue “entrar” na secção crítica (por exemplo, ler e escrever numa estrutura em memória partilhada).
   * Quando um processo está dentro, os outros ficam bloqueados à espera do semáforo voltar a 1.

2. **Sincronização de fluxo (produtor–consumidor)**
   Dois semáforos gerem a disponibilidade de espaço e de dados:

   * Um semáforo conta quantas unidades de dados estão disponíveis para ler.
   * Outro conta quantos espaços livres há para escrever.
     O produtor espera por espaço livre antes de escrever e sinaliza dados disponíveis quando termina; o consumidor espera por dados disponíveis antes de ler e sinaliza espaço livre quando termina.

Do ponto de vista conceptual, os semáforos funcionam como sinais de trânsito ou contadores de lugares num parque de estacionamento: regulam a entrada e saída para que o recurso nunca seja usado em excesso e não ocorram colisões.

---

## Descrição da implementação com memória partilhada

Em POSIX/UNIX, a combinação “memória partilhada + semáforos” faz-se com duas famílias de primitivas POSIX:

* Para **memória partilhada**: `shm_open`, `ftruncate`, `mmap`, `munmap`, `shm_unlink` (mais `close`), nas bibliotecas associadas a `<sys/mman.h>`, `<sys/stat.h>`, `<fcntl.h>`, `<unistd.h>`.
* Para **semáforos POSIX**: funções declaradas em `<semaphore.h>`.

Na prática, segue-se o seguinte caminho:

**Semáforos nomeados**
   Os semáforos são “objetos” do sistema com um nome, tal como a memória partilhada:

   * São criados/abertos com uma função que recebe um nome e flags semelhantes a `O_CREAT` e permissões.
   * Vários processos, ao conhecerem esse nome, conseguem abrir o mesmo semáforo.
   * As operações de espera e sinal (bloquear/libertar) são realizadas com funções padrão (`sem_wait`, `sem_post`).
   * No fim, o semáforo é fechado e o seu nome pode ser removido do sistema, tal como acontece com `shm_unlink` na memória.

   Neste modelo, a memória partilhada é usada apenas para os dados, enquanto a coordenação é feita por semáforos que vivem “fora” dessa memória, mas que são igualmente partilhados via nome.

O padrão de utilização é semelhante:

* Antes de aceder à estrutura em memória partilhada, o processo faz uma operação de espera no semáforo de exclusão mútua, garantindo que mais ninguém mexe nos mesmos campos ao mesmo tempo.
* Se houver regras de fluxo produtor–consumidor, o produtor e o consumidor ainda coordenam, com outros semáforos, a ordem em que se escreve e se lê.
* Quando termina a operação na memória partilhada, o processo emite um sinal, libertando o semáforo para que outro processo possa continuar.

Esta combinação transforma a memória partilhada num mecanismo de comunicação seguro e previsível: a memória fornece o espaço físico para os dados, e os semáforos impõem a ordem de acesso e evitam condições de corrida.

## Ideia dos semáforos do System V.

---

### 1. Semáforos System V: ideia

Os semáforos System V são um dos mecanismos clássicos de IPC em UNIX.

* Vivem num **conjunto de semáforos** (semaphore set), identificado por um `int semid`.
* Cada conjunto possui um ou mais semáforos individuais (indexados por 0, 1, 2, …).
* Usam-se três chamadas principais:

1. `semget` – cria ou obtém um conjunto de semáforos.
2. `semctl` – controla/consulta/inicializa um semáforo.
3. `semop` – executa operações atómicas tipo P/V (espera/sinal) sobre um ou vários semáforos.

#### Modelo mental

* Valor inicial do semáforo:

  * `1` → exclusão mútua (mutex): só um processo entra na secção crítica de cada vez.
  * `0` → sincronização (esperar que algo aconteça).

* Operações:

  * **P (wait)**: `semop` com `sem_op = -1`.

    * Se o valor do semáforo for > 0, decrementa e segue.
    * Se for 0, o processo bloqueia até alguém fazer V.
  * **V (signal)**: `semop` com `sem_op = +1`.

    * Incrementa o semáforo e, se houver alguém bloqueado, desperta um processo.

---

### Exemplo simples: contador em memória partilhada

Exemplo clássico:

* Um segmento de **memória partilhada System V** com um inteiro.
* Um **semáforo System V** para garantir exclusão mútua.
* O processo pai faz `fork()`, pai e filho incrementam o contador várias vezes.
* O semáforo evita que se pisem os pés.

#### Ideia do fluxo

1. Criar segmento de memória partilhada (`shmget`) e obter um ponteiro (`shmat`).
2. Criar conjunto de semáforos (`semget`) com 1 semáforo.
3. Inicializar esse semáforo com valor 1 (`semctl` + `SETVAL`).
4. `fork()`:

   * Pai e filho entram num ciclo de incrementos.
   * Cada incremento:

     1. `P` (espera) → entra em secção crítica.
     2. Lê `*shared`, incrementa, volta a escrever.
     3. `V` (sinal) → sai da secção crítica.
5. Pai espera pelo filho, imprime valor final.
6. Limpa recursos (desanexa e remove shm, destrói semáforo).

#### Código de exemplo (C)

```c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <sys/sem.h>
#include <sys/wait.h>

/* union semun não é declarada pelo padrão em alguns sistemas */
union semun {
    int              val;
    struct semid_ds *buf;
    unsigned short  *array;
};

/* Operação P (wait) */
void sem_P(int semid) {
    struct sembuf op;
    op.sem_num = 0;   // índice do semáforo no conjunto
    op.sem_op  = -1;  // P: tenta decrementar
    op.sem_flg = 0;   // bloqueia se não puder

    if (semop(semid, &op, 1) == -1) {
        perror("semop P");
        exit(1);
    }
}

/* Operação V (signal) */
void sem_V(int semid) {
    struct sembuf op;
    op.sem_num = 0;
    op.sem_op  = +1;  // V: incrementa
    op.sem_flg = 0;

    if (semop(semid, &op, 1) == -1) {
        perror("semop V");
        exit(1);
    }
}

int main(void) {
    key_t key_shm  = 0x1234;  // chave para memória partilhada
    key_t key_sem  = 0x5678;  // chave para semáforo
    int shmid, semid;
    int *shared;
    union semun arg;

    /* 1. Criar memória partilhada com 1 inteiro */
    shmid = shmget(key_shm, sizeof(int), IPC_CREAT | 0666);
    if (shmid == -1) {
        perror("shmget");
        exit(1);
    }

    shared = (int *) shmat(shmid, NULL, 0);
    if (shared == (void *) -1) {
        perror("shmat");
        exit(1);
    }

    *shared = 0;  // contador inicial

    /* 2. Criar conjunto de 1 semáforo */
    semid = semget(key_sem, 1, IPC_CREAT | 0666);
    if (semid == -1) {
        perror("semget");
        exit(1);
    }

    /* 3. Inicializar semáforo a 1 (mutex) */
    arg.val = 1;
    if (semctl(semid, 0, SETVAL, arg) == -1) {
        perror("semctl SETVAL");
        exit(1);
    }

    pid_t pid = fork();
    if (pid == -1) {
        perror("fork");
        exit(1);
    }

    int i;
    if (pid == 0) {
        /* Processo filho */
        for (i = 0; i < 10; i++) {
            sem_P(semid);          // entra na secção crítica
            int tmp = *shared;
            tmp++;
            usleep(10000);         // simular trabalho
            *shared = tmp;
            sem_V(semid);          // sai da secção crítica
        }
        shmdt(shared);
        exit(0);
    } else {
        /* Processo pai */
        for (i = 0; i < 10; i++) {
            sem_P(semid);
            int tmp = *shared;
            tmp++;
            usleep(10000);
            *shared = tmp;
            sem_V(semid);
        }

        /* Esperar pelo filho */
        wait(NULL);

        printf("Valor final do contador: %d\n", *shared);

        /* Limpeza */
        shmdt(shared);
        shmctl(shmid, IPC_RMID, NULL);      // remove segmento de memória
        semctl(semid, 0, IPC_RMID, arg);    // remove conjunto de semáforos
    }

    return 0;
}
```

#### Como explicar isto aos alunos

* **Mostra o problema**: sem semáforo, pai e filho poderiam ler o mesmo valor e escrever ambos `+1`, “perdendo” incrementos.
* **Mostra a solução**:

  * Antes de mexer no contador partilhado → `P(sem)` → garantia de exclusão mútua.
  * Depois de mexer → `V(sem)` → outro processo pode entrar.
* **Sublinha o papel do kernel**:

  * `semop` é atómico: o kernel garante que o teste e o decremento/incremento do semáforo acontecem como uma só operação.
* **Mensagem final**: System V semáforos são mais verbosos que os POSIX, mas continuam muito usados em contextos legados; o padrão `semget` + `semctl` + `semop` é sempre o mesmo.
