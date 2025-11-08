Um *pipe* é um conceito de ligação em fluxo entre componentes de software: permite que o resultado produzido por um elemento seja imediatamente encaminhado para outro, favorecendo a modularidade e a composição de tarefas. Na prática, este conceito manifesta-se em dois planos complementares que convém distinguir logo na introdução: a nível do *shell* (onde encadeamos programas como etapas de um mesmo processamento) e a nível do sistema operativo (onde o *pipe* é uma abstração de comunicação entre processos).

1. **Pipes no Bash**
    
    Enquanto construção do *shell*, o *pipe* é usado para encadear programas como se fossem filtros conceptuais, articulando etapas de transformação de dados numa linha de processamento coesa. Realça a ideia de composição: cada comando desempenha uma função específica e o *pipe* liga essas funções para obter um resultado final.
    
    **Operacionalidade:**
    
    Um *pipe* liga a saída padrão (stdout) de um comando à entrada padrão (stdin) do seguinte, sem ficheiros temporários. O shell cria o canal e executa os processos em paralelo; cada `|` encadeia transformações simples em fluxo.
    
    Exemplo curto e útil:
    
    ```bash
    cat access.log | grep " 404 " | cut -d' ' -f1 | sort | uniq -c | sort -nr | head
    
    ```
    
    Ideias-chave: unidirecional (produtor→consumidor), processamento *streaming*, composição de filtros. Boas práticas: cada comando faz uma tarefa; usar `tee` para “ramificar” (`cmd | tee copia.txt | outro`); ativar `set -o pipefail` em Bash para falhas propagarem no *pipeline*.
    
2. **Pipes como Comunicação entre Processos (IPC)**
    
    Enquanto mecanismo do sistema operativo, o *pipe* representa um canal simples e leve para troca de dados entre processos relacionados, estruturando a comunicação em termos de produtor e consumidor. É um recurso de sincronização e passagem de informação que pode existir de forma efémera entre processos associados ou, em variantes apropriadas, ser exposto no sistema de ficheiros para facilitar a integração entre programas distintos.
    
    **Operacionalidade:**
    
    No kernel, `pipe()` cria um *buffer* em memória com duas extremidades: leitura (`fd[0]`) e escrita (`fd[1]`). Após `fork()`, cada processo herda os descritores e pode sincronizar por bloqueio: `read()` espera por dados/EOF; `write()` bloqueia quando o *buffer* está cheio. Escrita sem leitores gera `SIGPIPE`. Transferências são atómicas até `PIPE_BUF` (tipicamente alguns KB). Fechar sempre as pontas não usadas. Há *pipes* anónimos (entre parentes próximos via `fork()`) e *named pipes* (*FIFOs*, via `mkfifo`), estes últimos visíveis no sistema de ficheiros para processos não relacionados.
    
    Exemplo mínimo em C a ligar `ls -1` a `wc -l`:
    
    ```c
    int fd[2]; pipe(fd);
    if (!fork()) {                  // filho A: produtor
      dup2(fd[1], STDOUT_FILENO);
      close(fd[0]); close(fd[1]);
      execlp("ls","ls","-1",NULL);
    }
    if (!fork()) {                  // filho B: consumidor
      dup2(fd[0], STDIN_FILENO);
      close(fd[1]); close(fd[0]);
      execlp("wc","wc","-l",NULL);
    }
    close(fd[0]); close(fd[1]);
    wait(NULL); wait(NULL);
    
    ```
    
    Essência: *pipes* implementam um canal unidirecional, eficiente e simples para *streaming* de bytes entre processos, tanto no Bash (via `|`) como diretamente com `pipe()/dup2()/exec()`.
    
    > Mais informações sobre `pipe` :
    `$ man pipe` 
    `$ man 2 pipe`
    > 
    
    > Em Unix/POSIX, **sim**: `read(2)` e `write(2)` são as operações de E/S mais “baixas” expostas ao programa no espaço de utilizador (a par de `open(2)` e `close(2)`), operando diretamente sobre **descritores de ficheiro** — e é exatamente sobre elas que os *pipes* se apoiam.
    
    Consultar ainda `read` e `write` :
    
    `$ man 2 read` 
    `$ man 2 write`
    > 

## Implementação

- Um *pipe* e um sentido
- Um *pipe* e dois sentidos
- Dois *pipes*
