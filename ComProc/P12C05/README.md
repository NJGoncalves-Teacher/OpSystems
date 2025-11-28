# Utilização de Sinais na Interface da Linha de Comandos

Nos sistemas POSIX/UNIX, os **sinais** constituem um dos mecanismos fundamentais de comunicação assíncrona entre o utilizador, o sistema operativo e os processos em execução. Um sinal é uma notificação enviada a um processo para indicar que ocorreu um determinado evento: interrupção pelo utilizador, pedido de terminação, violação de memória, expiração de temporizador, entre outros. Os sinais permitem ao utilizador controlar a execução de programas através da linha de comandos, bem como permitem aos programas reagir a eventos inesperados.

## Sinais mais comuns

Alguns dos sinais mais frequentemente utilizados na interface da linha de comandos são:

- **SIGINT (2)** – Interrupção de um processo, normalmente enviada com `Ctrl+C`, conduzindo à terminação imediata.
- **SIGTSTP (20)** – Suspensão temporária de um processo, enviada com `Ctrl+Z`. O processo fica parado, mantendo o estado em memória.
- **SIGCONT (18)** – Retoma da execução de um processo previamente suspenso.
- **SIGTERM (15)** – Pedido de terminação "limpa". É o sinal padrão enviado pelo comando `kill`.
- **SIGKILL (9)** – Terminação forçada e imediata, um sinal que não pode ser capturado ou ignorado pelo processo.

## Controlo de Processos na Linha de Comandos

A interação com sinais ocorre naturalmente na operação quotidiana de um terminal.

### Interromper um processo

Quando um programa está em execução:

```sh
$ ./programa
^C
```

A combinação ```Ctrl+C``` envia **SIGINT**, causando a sua terminação.

### Suspender e retomar processos

Suspender:
```sh
$ ./programa
^Z
[1]+  Stopped   ./programa
```

O processo recebe **SIGTSTP**. Para retomar:

```sh
$ fg %1
```

O shell envia **SIGCONT**, permitindo a continuação da execução.

### Terminar processos com ```kill```

Execução em background:

```sh
$ ./programa &
[1] 5321
```

Terminar de forma limpa:

```sh
$ kill 5321
```

Se o processo não terminar:

```sh
$ kill -9 5321
```

Isto envia **SIGKILL** e força a terminação imediata.

## Comando `kill`

O comando `kill` é uma ferramenta essencial para o controlo de processos em sistemas POSIX/UNIX. A sua função central consiste em **enviar sinais** a processos identificados pelos respetivos Process IDs (PIDs). Apesar do nome sugerir apenas a eliminação de processos, o `kill` é muito mais versátil: permite suspender, retomar, notificar ou terminar processos de forma controlada.

### Alcance do comando `kill`

O alcance do comando depende das permissões do utilizador:

- O utilizador pode enviar sinais **a qualquer processo que lhe pertença**;
- Para enviar sinais a processos de outros utilizadores, são necessárias permissões elevadas (root);
- O `kill` pode atuar sobre **processos individuais**, **grupos de processos** (PGIDs) ou **sessões**.

Não é possível terminar ou suspender diretamente processos do kernel.

### Envio de sinais a um processo

A forma mais simples envia o sinal **SIGTERM (15)**, um pedido de terminação limpa:

```sh
kill PID
```

O processo tem oportunidade de libertar recursos e encerrar de forma ordenada.

### Especificar sinais

O utilizador pode enviar sinais distintos consoante o comportamento pretendido:

```sh
kill -SIGINT PID     # Interrupção equivalente a Ctrl+C
kill -SIGTSTP PID    # Suspensão equivalente a Ctrl+Z
kill -SIGCONT PID    # Retoma a execução
kill -SIGKILL PID    # Terminação imediata e forçada
```

Também é possível indicar o número do sinal:

```sh
kill -9 PID          # SIGKILL
kill -15 PID         # SIGTERM
```

# Uso de Sinais em Comunicações IPC (Inter-Process Communication)

Este documento apresenta o papel dos **sinais** em comunicações entre processos (IPC) em sistemas POSIX/UNIX, descreve os requisitos para o seu uso correto e inclui um programa ilustrativo em C que demonstra a integração entre sinais e pipes.

---

## 1. Papel dos sinais nas comunicações IPC

Em POSIX/UNIX, os **sinais** permitem comunicação assíncrona entre processos, servindo como notificações de eventos relevantes. No contexto de IPC, os sinais são usados para:

- Notificar um processo de que ocorreu um evento (por exemplo, dados disponíveis, término de operação, encerramento solicitado).
- Sincronizar processos em paralelo ou cooperativos.
- Coordenar estados entre processos que usam outros mecanismos de IPC (memória partilhada, pipes, filas de mensagens, sockets, etc.).

Importante: sinais **não transportam dados estruturados**; servem como gatilho (“interruptor”) enquanto os dados reais circulam por outro canal.

---

## 2. Requisitos para usar sinais em IPC

### 2.1. Conhecimento dos PIDs

Para enviar sinais, os processos têm de conhecer os **PIDs** envolvidos:

- O pai conhece o PID do filho via `fork()`.
- O filho obtém o PID do pai via `getppid()`.
- Processos não relacionados podem trocar PIDs por pipe, ficheiro, socket, etc.

### 2.2. Instalar handlers de sinal

Para reagir a sinais, é necessário instalar manipuladores (handlers) com `signal()` ou `sigaction()`. Estes handlers definem o comportamento do processo ao receber determinado sinal.

`sigaction()` é a abordagem recomendada por ser mais robusta.

### 2.3. Máscaras de sinais e sincronização

Processos concorrentes devem usar máscaras e operações atómicas:

- `sigprocmask()` — bloquear sinais enquanto se altera estado sensível.
- `sigsuspend()` — esperar de forma atómica por um sinal.
- Evitar condições de corrida típicas entre chegada de sinal e bloqueio do processo.

### 2.4. Funções seguras dentro de handlers

Dentro de um handler só devem ser usadas funções **async-signal-safe**, como:

- `write()`, `_exit()`, `signal()` e algumas operações sobre `sigaction`.

Funções como `printf()`, `malloc()`, `free()` ou outras não reentrantes **não podem** ser usadas diretamente num handler.

### 2.5. Limitações

- Sinais podem “colapsar”: múltiplos sinais iguais podem ser registados apenas uma vez.
- Se for necessário contar eventos, usar **sinais de tempo real** (POSIX RT signals) ou outro mecanismo de IPC.
- Sinais apenas transportam o tipo de evento, nunca dados.
- Não adequados para IPC onde seja necessário fluxo garantido, buffers ou estruturas de dados.

---

## 3. Programa ilustrativo: sincronização pai-filho com SIGUSR1

Este exemplo demonstra:

- Uso de **pipe** como canal de dados;
- Uso de **SIGUSR1** como mecanismo de notificação assíncrona;
- Sincronização entre pai e filho.

### Código completo

```c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <string.h>
#include <sys/wait.h>

volatile sig_atomic_t pronto = 0;  // flag alterada pelo handler

void trata_sigusr1(int sig) {
    (void)sig;      // evitar warning de parâmetro não usado
    pronto = 1;     // sinaliza ao processo principal que há dados prontos
}

int main(void) {
    int fd[2];      // fd[0] leitura, fd[1] escrita
    pid_t pid_filho;

    if (pipe(fd) == -1) {
        perror("pipe");
        exit(EXIT_FAILURE);
    }

    /* Instalar handler para SIGUSR1 no processo pai usando signal() */
    if (signal(SIGUSR1, trata_sigusr1) == SIG_ERR) {
        perror("signal");
        exit(EXIT_FAILURE);
    }

    pid_filho = fork();
    if (pid_filho < 0) {
        perror("fork");
        exit(EXIT_FAILURE);
    }

    if (pid_filho == 0) {
        /* --- Código do FILHO --- */
        close(fd[0]);   // filho não lê do pipe

        // Simular algum trabalho
        sleep(2);

        const char *msg = "Dados preparados pelo processo filho.\n";
        if (write(fd[1], msg, strlen(msg)) == -1) {
            perror("write filho");
            // mesmo em erro, prossegue para notificar o pai
        }

        // Notificar o pai que os dados estão prontos
        pid_t pid_pai = getppid();
        if (kill(pid_pai, SIGUSR1) == -1) {
            perror("kill filho");
        }

        close(fd[1]);
        _exit(EXIT_SUCCESS);

    } else {
        /* --- Código do PAI --- */
        close(fd[1]);   // pai não escreve no pipe

        printf("Pai: à espera de notificação do filho (SIGUSR1)...\n");

        /* Espera por sinais até a flag ser colocada a 1 pelo handler */
        while (!pronto) {
            pause();    // suspende até chegar um sinal
        }

        printf("Pai: recebi SIGUSR1, vou ler do pipe.\n");

        char buffer[256];
        ssize_t n = read(fd[0], buffer, sizeof(buffer) - 1);
        if (n == -1) {
            perror("read pai");
        } else if (n == 0) {
            printf("Pai: pipe fechado sem dados.\n");
        } else {
            buffer[n] = '\0';
            printf("Pai: li do pipe: %s", buffer);
        }

        close(fd[0]);

        // Esperar que o filho termine
        wait(NULL);
        printf("Pai: filho terminou, a sair.\n");

        return 0;
    }
}
```
