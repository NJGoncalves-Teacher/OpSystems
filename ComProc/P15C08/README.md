# Message Queue (IPC em Linux/C)

Este documento introduz **filas de mensagens** (*message queues*) como mecanismo de **IPC** (*Inter-Process Communication*), compara-as com outros meios de IPC e apresenta o essencial para implementar **message queues em C** num ambiente Linux, com foco numa implementação simples.

> Em Linux existem duas famílias principais:
> - **System V Message Queues** (clássico em ambientes UNIX): `msgget`, `msgsnd`, `msgrcv`, `msgctl`
> - **POSIX Message Queues** (API POSIX, via *mqueue*): `mq_open`, `mq_send`, `mq_receive`, `mq_close`, `mq_unlink`

---

## 1) Introdução ao assunto

Uma **message queue** é uma estrutura gerida pelo kernel que permite a **troca de mensagens** entre processos (ou entre threads/processos) sem que estes tenham de partilhar memória diretamente.

Características típicas:

- **Comunicação assíncrona**: o emissor pode enviar e continuar; o recetor pode ler quando estiver pronto.
- **Buffering no kernel**: as mensagens ficam armazenadas na fila até serem lidas (ou até limites de capacidade).
- **Mensagens discretas**: ao contrário de *pipes* (fluxo de bytes), a unidade é uma “mensagem”.
- **Sincronização implícita**: leitura/escrita bloqueante por omissão; suportam modos não bloqueantes.
- **Possível prioridade/tipo**:
  - System V: seleção por **tipo** (`mtype`)
  - POSIX: mensagens com **prioridade** (inteiro)

Casos de uso frequentes:

- Arquiteturas **produtor–consumidor**.
- Processos com ritmos diferentes (ex.: ingestão de eventos vs. processamento).
- Coordenação simples de tarefas (ex.: *job queue*).

---

## 2) Comparação com outros meios de IPC

| Mecanismo | Modelo | Vantagens | Limitações / quando evitar |
|---|---|---|---|
| **Pipes / FIFOs** | Fluxo de bytes | Simples; bom para *pipeline*; integração com shell | Não há fronteiras de mensagem; 1D; tipicamente sem seleção por tipo/prioridade |
| **Message Queues** | Mensagens discretas | Mensagens com fronteiras; buffering no kernel; seleção por tipo/prioridade; bom para produtor–consumidor | Overhead do kernel; limites de tamanho/capacidade; requer limpeza (*unlink* / `msgctl`) |
| **Memória partilhada** | Região partilhada | Muito rápida (sem cópia por mensagem) | Requer sincronização explícita (mutex/semáforos); mais complexa; risco elevado de *race conditions* |
| **Sockets (Unix/TCP/UDP)** | Fluxo ou datagramas | Flexível; funciona local e remoto; bem suportado | Mais verboso; para local pode ser “pesado” face a MQ; TCP é fluxo (sem fronteiras) |
| **Semáforos / Mutexes** | Sincronização | Excelente para coordenação | Não transporta dados por si só (é controlo, não “mensagem”) |
| **Signals** | Notificação | Muito leve | Conteúdo mínimo; sem dados estruturados; propenso a complexidade em estados |

Regra prática:

- Se precisa de **mensagens discretas** com **fila/buffering**, e quer algo mais “alto nível” do que pipes, use **message queues**.
- Se precisa de **máximo desempenho** para grandes volumes de dados, prefira **memória partilhada + sincronização**.
- Se precisa de **comunicação em rede** ou interoperabilidade com outras máquinas, use **sockets**.

---

## 3) Implementar Message Queue em C (Linux)

### 3.1 System V Message Queues (recomendado para ensino “clássico” de IPC)

#### 3.1.1 Biblioteca e cabeçalhos

Inclua:

```c
#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/msg.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
```

Compilação:

```bash
gcc -O2 -Wall -Wextra mq_sysv.c -o mq_sysv
```

#### 3.1.2 Funções essenciais (implementação simples)

- `key_t ftok(const char *path, int proj_id);`  
  Gera uma *key* estável a partir de um ficheiro existente.
- `int msgget(key_t key, int msgflg);`  
  Cria/obtém a fila.
- `int msgsnd(int msqid, const void *msgp, size_t msgsz, int msgflg);`  
  Envia uma mensagem.
- `ssize_t msgrcv(int msqid, void *msgp, size_t msgsz, long msgtyp, int msgflg);`  
  Recebe uma mensagem (pode filtrar por tipo).
- `int msgctl(int msqid, int cmd, struct msqid_ds *buf);`  
  Controla a fila (ex.: remover com `IPC_RMID`).

Notas críticas:

- A estrutura de mensagem **tem de começar** com `long mtype;`.
- Em `msgsnd/msgrcv`, o parâmetro `msgsz` **não inclui** o `mtype`.

#### 3.1.3 Exemplo (um único programa com modo send/recv)

Guarde como `mq_sysv.c`:

```c
#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/msg.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define TEXTO_MAX 256

typedef struct {
    long mtype;               // obrigatório (>= 1)
    char mtext[TEXTO_MAX];    // payload
} mensagem_t;

static int obter_fila(void) {
    // O ficheiro tem de existir. Pode usar /tmp como referência simples.
    const char *path = "/tmp";
    key_t key = ftok(path, 'Q');
    if (key == (key_t)-1) {
        perror("ftok");
        return -1;
    }

    int msqid = msgget(key, IPC_CREAT | 0600); // cria se não existir
    if (msqid == -1) {
        perror("msgget");
        return -1;
    }
    return msqid;
}

static int enviar(int msqid, long tipo, const char *texto) {
    mensagem_t msg;
    msg.mtype = tipo;
    snprintf(msg.mtext, sizeof(msg.mtext), "%s", texto);

    // msgsz NÃO inclui o mtype
    if (msgsnd(msqid, &msg, sizeof(msg.mtext), 0) == -1) {
        perror("msgsnd");
        return -1;
    }
    return 0;
}

static int receber(int msqid, long tipo) {
    mensagem_t msg;
    memset(&msg, 0, sizeof(msg));

    ssize_t n = msgrcv(msqid, &msg, sizeof(msg.mtext), tipo, 0);
    if (n == -1) {
        perror("msgrcv");
        return -1;
    }

    printf("Recebido (tipo=%ld, %zd bytes): %s\n", msg.mtype, n, msg.mtext);
    return 0;
}

static int remover_fila(int msqid) {
    if (msgctl(msqid, IPC_RMID, NULL) == -1) {
        perror("msgctl(IPC_RMID)");
        return -1;
    }
    return 0;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr,
            "Uso:\n"
            "  %s send <tipo> <texto>\n"
            "  %s recv <tipo>\n"
            "  %s rm\n", argv[0], argv[0], argv[0]);
        return 1;
    }

    int msqid = obter_fila();
    if (msqid == -1) return 1;

    if (strcmp(argv[1], "send") == 0) {
        if (argc < 4) {
            fprintf(stderr, "Faltam argumentos para send\n");
            return 1;
        }
        long tipo = strtol(argv[2], NULL, 10);
        return enviar(msqid, tipo, argv[3]) == 0 ? 0 : 1;

    } else if (strcmp(argv[1], "recv") == 0) {
        if (argc < 3) {
            fprintf(stderr, "Faltam argumentos para recv\n");
            return 1;
        }
        long tipo = strtol(argv[2], NULL, 10);
        return receber(msqid, tipo) == 0 ? 0 : 1;

    } else if (strcmp(argv[1], "rm") == 0) {
        return remover_fila(msqid) == 0 ? 0 : 1;

    } else {
        fprintf(stderr, "Modo desconhecido: %s\n", argv[1]);
        return 1;
    }
}
```

Compilar e testar (em dois terminais):

```bash
gcc -O2 -Wall -Wextra mq_sysv.c -o mq_sysv

# Terminal A (recetor)
./mq_sysv recv 1

# Terminal B (emissor)
./mq_sysv send 1 "Olá via System V MQ"
```

Limpeza da fila:

```bash
./mq_sysv rm
```

Diagnóstico útil:

```bash
ipcs -q        # listar filas System V
ipcrm -q <id>  # remover uma fila pelo id (alternativa)
```

---

### 3.2 POSIX Message Queues (mqueue)

As filas POSIX são identificadas por **nome** (tipo caminho, ex.: `/minha_fila`), e existem em sistemas de ficheiros virtuais (tipicamente `mqueuefs`, frequentemente montado em `/dev/mqueue`).

#### 3.2.1 Biblioteca e cabeçalhos

Inclua:

```c
#include <mqueue.h>
#include <fcntl.h>      // O_CREAT, O_RDONLY, O_WRONLY
#include <sys/stat.h>   // modo (permissões)
#include <stdio.h>
#include <string.h>
#include <errno.h>
```

Compilação (frequente):

```bash
gcc -O2 -Wall -Wextra mq_posix.c -o mq_posix -lrt
```

> Nota: em algumas distribuições recentes, `-lrt` pode já não ser necessário, mas é comum em ambientes de ensino e mantém compatibilidade.

#### 3.2.2 Funções essenciais (implementação simples)

- `mqd_t mq_open(const char *name, int oflag, ...);`  
  Cria/abre a fila por nome.
- `int mq_send(mqd_t mqdes, const char *msg_ptr, size_t msg_len, unsigned msg_prio);`  
  Envia mensagem com prioridade.
- `ssize_t mq_receive(mqd_t mqdes, char *msg_ptr, size_t msg_len, unsigned *msg_prio);`  
  Recebe mensagem.
- `int mq_close(mqd_t mqdes);`  
  Fecha descritor.
- `int mq_unlink(const char *name);`  
  Remove a fila (limpeza).

#### 3.2.3 Exemplo mínimo (send/recv)

Guarde como `mq_posix.c`:

```c
#include <mqueue.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>

#define NOME_FILA "/fila_exemplo"
#define TAM_MSG   256

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr,
            "Uso:\n"
            "  %s send <texto>\n"
            "  %s recv\n"
            "  %s rm\n", argv[0], argv[0], argv[0]);
        return 1;
    }

    if (strcmp(argv[1], "rm") == 0) {
        if (mq_unlink(NOME_FILA) == -1) {
            perror("mq_unlink");
            return 1;
        }
        return 0;
    }

    struct mq_attr attr;
    memset(&attr, 0, sizeof(attr));
    attr.mq_maxmsg = 10;      // nº máximo de mensagens na fila
    attr.mq_msgsize = TAM_MSG;

    if (strcmp(argv[1], "send") == 0) {
        if (argc < 3) {
            fprintf(stderr, "Falta texto\n");
            return 1;
        }

        mqd_t mq = mq_open(NOME_FILA, O_CREAT | O_WRONLY, 0600, &attr);
        if (mq == (mqd_t)-1) {
            perror("mq_open(send)");
            return 1;
        }

        if (mq_send(mq, argv[2], strlen(argv[2]) + 1, 0) == -1) {
            perror("mq_send");
            mq_close(mq);
            return 1;
        }

        mq_close(mq);
        return 0;

    } else if (strcmp(argv[1], "recv") == 0) {
        mqd_t mq = mq_open(NOME_FILA, O_CREAT | O_RDONLY, 0600, &attr);
        if (mq == (mqd_t)-1) {
            perror("mq_open(recv)");
            return 1;
        }

        char buf[TAM_MSG];
        unsigned prio = 0;

        ssize_t n = mq_receive(mq, buf, sizeof(buf), &prio);
        if (n == -1) {
            perror("mq_receive");
            mq_close(mq);
            return 1;
        }

        printf("Recebido (%zd bytes, prio=%u): %s\n", n, prio, buf);
        mq_close(mq);
        return 0;

    } else {
        fprintf(stderr, "Modo desconhecido: %s\n", argv[1]);
        return 1;
    }
}
```

Compilar e testar (dois terminais):

```bash
gcc -O2 -Wall -Wextra mq_posix.c -o mq_posix -lrt

# Terminal A
./mq_posix recv

# Terminal B
./mq_posix send "Olá via POSIX MQ"
```

Limpeza:

```bash
./mq_posix rm
```

---

## 4) Boas práticas e armadilhas comuns

- **Limpeza explícita**:
  - System V: `msgctl(msqid, IPC_RMID, ...)`
  - POSIX: `mq_unlink("/nome")`
- **Capacidade e bloqueio**:
  - Se a fila estiver cheia, `send` bloqueia (ou falha com modo não bloqueante).
  - Se a fila estiver vazia, `recv` bloqueia (ou falha com modo não bloqueante).
- **Tamanho das mensagens**:
  - System V: limite por implementação; respeitar `msgsz` e não exceder.
  - POSIX: `mq_msgsize` define tamanho máximo.
- **Versões e portabilidade**:
  - System V é muito comum em UNIX clássicos.
  - POSIX MQ é padronizado e integra bem com prioridades e nomes.

---

## 5) Checklist rápido (implementação simples)

### System V
1. `key = ftok(...)`
2. `msqid = msgget(key, IPC_CREAT | 0600)`
3. `msgsnd(msqid, &msg, sizeof(msg.mtext), 0)`
4. `msgrcv(msqid, &msg, sizeof(msg.mtext), tipo, 0)`
5. `msgctl(msqid, IPC_RMID, NULL)`

### POSIX
1. `mq = mq_open("/nome", O_CREAT|..., 0600, &attr)`
2. `mq_send(mq, buffer, len, prio)`
3. `mq_receive(mq, buffer, size, &prio)`
4. `mq_close(mq)`
5. `mq_unlink("/nome")`

