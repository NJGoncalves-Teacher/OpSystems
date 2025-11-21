# Comunicação entre processos via memória partilhada (POSIX/UNIX)

Este projeto introduce, de forma simples, o conceito de **comunicação entre processos via memória partilhada** em sistemas POSIX/UNIX, **sem recorrer a semáforos** ou outros mecanismos de sincronização avançados. A ideia é perceber o modelo base: vários processos a aceder à mesma região de memória, como se fosse um “quadro branco” comum.

> ⚠️ Importante: o foco é pedagógico. As soluções apresentadas **não são adequadas para sistemas concorrentes reais**, precisamente por não usarem semáforos/mutexes.

---

## 1. Enquadramento

Num sistema POSIX/UNIX, cada processo tem, em princípio, o seu próprio espaço de endereços: o que um processo escreve na sua memória não é visível aos outros.

A **memória partilhada** é uma exceção controlada: o sistema operativo cria uma região de memória e mapeia-a em dois (ou mais) processos. Cada processo obtém um ponteiro para essa região e passa a poder ler e escrever nela como se fosse memória “normal”.

---

## 2. Ideia geral da comunicação via memória partilhada

De forma abstrata, a comunicação faz-se em quatro passos:

1. **Criação do segmento partilhado**  
   Um processo (ou mais) pede ao sistema operativo uma região de memória partilhada, identificada por um nome/ID.

2. **Mapeamento nos processos**  
   Cada processo interessado mapeia essa região no seu espaço de endereços. No final, todos têm um ponteiro para a mesma zona de memória física.

3. **Troca de dados**  
   Os processos combinam um **protocolo simples**: quem escreve, quem lê, em que ordem, que campos significam o quê. Passam a ler/escrever na memória partilhada como em variáveis normais.

4. **Limpeza**  
   Quando deixam de precisar, desmapeiam a memória e pedem ao sistema operativo para remover o objeto de memória partilhada, libertando recursos.

Comparação rápida com outros mecanismos:

- **Mais rápido** do que pipes ou sockets, porque não há cópia explícita de buffers entre kernel e user space a cada comunicação.
- **Mais perigoso** se não houver disciplina: não há qualquer sincronização automática; os processos podem interferir uns com os outros.

---

## 3. Modelo de exemplo: produtor / consumidor

Para uma primeira abordagem (sem semáforos), usa-se muitas vezes o modelo **1 produtor + 1 consumidor**, ambos ligados a uma pequena estrutura em memória partilhada, por exemplo:

```c
struct caixa {
    int ready;      // 0 = vazio, 1 = cheio
    char dados[256];
};

