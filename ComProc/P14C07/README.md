# Threads (Linux/C)

Este documento introduz o conceito de *threads* (fios de execução), compara-o com o de *processos* e mostra como implementar threads em C num ambiente Linux, com o mínimo necessário para exemplos simples.

---

## 1) Introdução ao assunto

Uma **thread** é uma unidade de execução dentro de um programa. Um mesmo processo pode conter **uma ou várias threads**, que correm “em paralelo” (em múltiplos núcleos) ou de forma concorrente (intercaladas no tempo) num único núcleo.

Ideias-chave:

- **O processo** é, tipicamente, a unidade de *isolamento* e de *recursos* (espaço de endereçamento, descritores de ficheiros, etc.).
- **A thread** é, tipicamente, a unidade de *execução* (contador de programa, registos, pilha/stack).
- Threads dentro do mesmo processo **partilham memória e recursos**, o que facilita comunicação, mas aumenta o risco de *condições de corrida* (*race conditions*).

---

## 2) Comparação entre threads e processos

### 2.1 Semelhanças
- Ambos permitem **concorrência** (várias tarefas “ao mesmo tempo” do ponto de vista do programa).
- Ambos são geridos pelo sistema operativo (escalonamento, estados de execução, etc.).

### 2.2 Diferenças práticas

| Aspeto | Processos | Threads |
|---|---|---|
| Memória | Espaços de endereçamento separados (isolamento forte) | Partilham o mesmo espaço de endereçamento do processo |
| Comunicação | Tipicamente via IPC (pipes, sockets, memória partilhada, etc.) | Tipicamente via variáveis partilhadas (necessita sincronização) |
| Custo de criação | Mais elevado | Mais baixo |
| Troca de contexto | Mais pesada | Mais leve |
| Robustez | Falha num processo não derruba necessariamente os outros | Falha numa thread pode comprometer o processo inteiro |
| Segurança/isolamento | Melhor isolamento | Menor isolamento (partilha total de memória) |

Quando preferir cada um (regra prática):

- **Threads**: tarefas cooperativas dentro do mesmo programa (ex.: servidor com *worker threads*, paralelismo em cálculo, pipeline de I/O).
- **Processos**: necessidade de isolamento, segurança e tolerância a falhas (ex.: serviços separados, *sandboxing*, *multi-process architecture*).

---

## 3) Implementar Threads em C para ambiente Linux (POSIX Threads)

Em Linux, a API mais comum é **POSIX Threads (pthreads)**.

### 3.1 Biblioteca e cabeçalhos

- Cabeçalho: `#include <pthread.h>`
- Ligação/compilação (GCC):
  - `gcc -O2 -Wall -Wextra -pthread programa.c -o programa`

> Nota: a opção `-pthread` trata de flags de compilação e de ligação adequadas (recomendada).

---

### 3.2 Funções “mínimas” para uma implementação simples

Abaixo está um conjunto de funções suficientes para criar e coordenar threads em exemplos básicos:

- `pthread_create(...)`  
  Cria uma nova thread que executa uma função.
- `pthread_join(...)`  
  Espera pela conclusão de uma thread (sincronização simples).
- `pthread_exit(...)`  
  Termina a thread atual (ou o processo, dependendo do contexto).
- `pthread_self()`  
  Obtém o identificador da thread atual.
- `pthread_detach(...)` *(opcional)*  
  Marca uma thread como “detached” (dispensa `join`).

Se existir partilha de dados mutáveis, é comum acrescentar sincronização:

- `pthread_mutex_init(...)`, `pthread_mutex_lock(...)`, `pthread_mutex_unlock(...)`, `pthread_mutex_destroy(...)`  
  Exclusão mútua (mutex) para proteger secções críticas.
- `pthread_cond_init(...)`, `pthread_cond_wait(...)`, `pthread_cond_signal(...)`, ... *(opcional)*  
  Condições para coordenação mais fina (produtor/consumidor, etc.).

---

### 3.3 Exemplo completo: criação e `join`

Guarde como `threads_exemplo.c`:

```c
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>

typedef struct {
    int id;
    long iteracoes;
} tarefa_t;

void* rotina_thread(void* arg) {
    tarefa_t* t = (tarefa_t*)arg;

    // Trabalho “simples” para exemplo
    long soma = 0;
    for (long i = 0; i < t->iteracoes; i++) {
        soma += i;
    }

    printf("Thread %d terminou: soma=%ld\n", t->id, soma);

    // Se quisermos devolver um resultado, alocamos dinamicamente
    long* resultado = malloc(sizeof(long));
    if (!resultado) {
        // Em caso de erro, terminar a thread
        pthread_exit(NULL);
    }
    *resultado = soma;

    return (void*)resultado; // será recolhido no pthread_join
}

int main(void) {
    const int N = 2;
    pthread_t th[N];
    tarefa_t tarefas[N];

    // Criar threads
    for (int i = 0; i < N; i++) {
        tarefas[i].id = i + 1;
        tarefas[i].iteracoes = 1000000L * (i + 1);

        int rc = pthread_create(&th[i], NULL, rotina_thread, &tarefas[i]);
        if (rc != 0) {
            fprintf(stderr, "Erro em pthread_create (thread %d)\n", i + 1);
            return 1;
        }
    }

    // Esperar e recolher resultados
    for (int i = 0; i < N; i++) {
        void* ret = NULL;
        int rc = pthread_join(th[i], &ret);
        if (rc != 0) {
            fprintf(stderr, "Erro em pthread_join (thread %d)\n", i + 1);
            return 1;
        }

        long* resultado = (long*)ret;
        if (resultado) {
            printf("Main recebeu resultado da thread %d: %ld\n", i + 1, *resultado);
            free(resultado);
        } else {
            printf("Main recebeu NULL da thread %d\n", i + 1);
        }
    }

    return 0;
}
```

Compilar e executar:

```bash
gcc -O2 -Wall -Wextra -pthread threads_exemplo.c -o threads_exemplo
./threads_exemplo
```

---

## 4) Notas importantes (para evitar erros comuns)

- **Dados partilhados**: duas threads a escrever na mesma variável sem coordenação podem produzir resultados errados (*data race*).
- **Endereço de variáveis locais**: cuidado ao passar para a thread o endereço de variáveis que saem de âmbito; use estruturas persistentes (ex.: array no `main`) ou alocação dinâmica.
- **Ordem de execução**: sem sincronização, a ordem dos `printf` e das operações é **não determinística**.
- **`join` vs `detach`**: se fizer `detach`, não deve fazer `join` nessa thread.

---

## 5) Checklist rápido (exemplo simples)

1. `#include <pthread.h>`
2. Definir a função da thread: `void* f(void* arg)`
3. Criar: `pthread_create(&tid, NULL, f, arg)`
4. Esperar: `pthread_join(tid, &ret)`
5. Compilar: `gcc -pthread ...`


