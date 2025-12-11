Segue um texto que pode usar como introdução em apontamentos ou num README sobre IPC com sockets, enquadrado num sistema tipo System V/POSIX:

---

### Comunicação entre processos (IPC) com Sockets em sistemas System V

Num sistema operativo multitarefa, os processos não vivem isolados: precisam muitas vezes de trocar dados, coordenar trabalho e reagir a pedidos de outros programas. A este conjunto de mecanismos chamamos *Inter-Process Communication* (IPC). Existem várias famílias de mecanismos IPC (pipes, filas de mensagens, memória partilhada, semáforos), mas os **sockets** destacam-se por permitirem comunicação tanto entre processos no mesmo sistema como entre máquinas diferentes ligadas em rede.

Em sistemas do tipo **System V / POSIX** (como as distribuições Linux modernas), a interface de sockets está totalmente integrada no kernel e nas bibliotecas de sistema. Isto significa que o mesmo código em C para sockets compila, em princípio, em qualquer sistema compatível, tornando os exemplos facilmente portáveis.

---

### O que é um socket?

Um *socket* pode ser visto como um “ponto terminal” de comunicação, análogo a um descritor de ficheiro, mas orientado para comunicação entre processos. Cada socket é identificado por:

* Um **domínio** (por exemplo, `AF_INET` para IPv4, `AF_INET6` para IPv6, ou `AF_UNIX` para comunicação local no mesmo sistema);
* Um **tipo** (por exemplo, `SOCK_STREAM` para canais orientados à ligação, tipo TCP; `SOCK_DGRAM` para datagramas, tipo UDP);
* Um **protocolo** concreto (na maioria dos casos, 0, deixando o sistema escolher o protocolo “natural” para o tipo de socket).

Em aplicações C, um socket é apenas um inteiro (um descritor), usado depois com chamadas de sistema como `read()`, `write()`, `send()`, `recv()`, tal como acontece com ficheiros. Isto facilita a integração com o resto do código: o mesmo modelo de I/O serve para ficheiros, pipes e sockets.

---

### Modelo cliente/servidor

A programação com sockets segue tipicamente o modelo **cliente/servidor**:

* O **servidor** fica à escuta num endereço (IP/porto ou caminho de socket UNIX), à espera que clientes se liguem.
* O **cliente** inicia a ligação ao servidor e, a partir do momento em que a ligação é estabelecida, ambos podem trocar dados de forma bidirecional.

No lado do servidor (domínio Internet, por exemplo `AF_INET`), os passos típicos são:

1. **Criação do socket**

   ```c
   int sockfd = socket(AF_INET, SOCK_STREAM, 0);
   ```

2. **Associação (bind) a um endereço e porto**
   Preenche-se uma estrutura `struct sockaddr_in` com o endereço IP e o porto, e chama-se `bind()`.

3. **Colocar o socket em modo de escuta**

   ```c
   listen(sockfd, backlog);
   ```

   Aqui define-se também o tamanho da fila de ligações pendentes (`backlog`).

4. **Aceitar ligações de clientes**

   ```c
   int clientfd = accept(sockfd, (struct sockaddr *)&cliaddr, &clilen);
   ```

   Cada chamada a `accept()` cria um novo descritor (`clientfd`) dedicado à comunicação com um cliente específico.

5. **Troca de dados e encerramento**
   Com `clientfd`, o servidor usa `read()/write()` ou `recv()/send()` para comunicar. No final, fecha o descritor com `close(clientfd)` e, quando termina o serviço, também o `sockfd`.

No lado do cliente, a sequência é mais simples:

1. **Criação do socket**: `socket(AF_INET, SOCK_STREAM, 0);`
2. **Preenchimento da estrutura de endereço do servidor** (`struct sockaddr_in` com IP e porto);
3. **Estabelecer a ligação**:

   ```c
   connect(sockfd, (struct sockaddr *)&servaddr, sizeof(servaddr));
   ```
4. **Troca de dados** com `read()/write()` ou `recv()/send()`;
5. **Encerramento** com `close(sockfd)` quando não for mais necessário.

Esta mesma lógica aplica-se a sockets de domínio UNIX (`AF_UNIX`), usados quando a comunicação ocorre apenas entre processos na mesma máquina, dispensando o uso de IP/portos e usando, em alternativa, um caminho no sistema de ficheiros.

---

### Sockets e System V: enquadramento face a outros mecanismos IPC

Historicamente, o Unix System V introduziu um conjunto de mecanismos IPC próprios (conhecidos como **System V IPC**): filas de mensagens (`msgget`, `msgsnd`, `msgrcv`), memória partilhada (`shmget`, `shmat`, `shmdt`) e semáforos (`semget`, `semop`, `semctl`). Estes mecanismos são pensados sobretudo para comunicação e sincronização **dentro do mesmo sistema**, com forte integração no kernel e controlo de permissões ao estilo de ficheiros.

Os **sockets**, embora originalmente associados ao Unix BSD, foram acabando por ser integrados em praticamente todas as variantes Unix (incluindo System V) e hoje fazem parte do conjunto de interfaces normalizadas POSIX. Na prática:

* Em **System V/POSIX**, o programador tem duas grandes “famílias” de IPC:

  * Mecanismos **System V IPC** (filas, memória partilhada, semáforos), tipicamente usados para cooperação eficiente dentro da mesma máquina;
  * **Sockets** (Internet ou UNIX) para comunicação local ou em rede, permitindo construir serviços distribuídos, servidores TCP/UDP, etc.

Numa disciplina de IPC, é comum começar por pipes e System V IPC para ilustrar a comunicação em memória partilhada e por passagem de mensagens, e depois introduzir os **sockets** como ferramenta de comunicação mais geral, capaz de ultrapassar as fronteiras do próprio sistema operativo (máquinas distintas ligadas por rede).

---

### Implementação prática em ambiente System V / POSIX

Do ponto de vista prático, em sistemas do tipo System V/POSIX:

* Incluem-se cabeçalhos como:

  ```c
  #include <sys/types.h>
  #include <sys/socket.h>
  #include <netinet/in.h>
  #include <arpa/inet.h>
  #include <unistd.h>
  ```
* Compila-se com o compilador standard (`gcc`, por exemplo):

  ```bash
  gcc servidor.c -o servidor
  gcc cliente.c  -o cliente
  ```
* Os programas podem ser testados no mesmo computador (cliente e servidor no mesmo host) ou em máquinas diferentes na mesma rede, bastando ajustar o endereço IP e garantir que o porto está acessível.

Ao combinar os conceitos de **IPC** e a interface de **sockets**, o aluno ganha uma visão unificada da comunicação entre processos, capaz de abranger desde simples troca de mensagens entre dois processos locais até à implementação de serviços de rede completos baseados em cliente/servidor, num ambiente compatível com System V e POSIX.

