Em muitos programas, dois módulos ou processos distintos precisam trocar dados. Uma opção é usar pipes, que vivem apenas em memória e desaparecem quando os processos terminam. Outra opção, mais simples de visualizar, é usar ficheiros temporários: o programa escreve dados num ficheiro “descartável”, lê esses dados mais tarde ou deixa outro processo lê-los e, no fim, apaga o ficheiro.

O ficheiro temporário funciona como uma “área de estacionamento” de dados: não queremos que fique guardado para sempre, só serve para passar informação de A para B, ou para guardar resultados intermédios.

Os ficheiros temporários são ficheiros “reais” que vivem no disco, tipicamente numa pasta especial do sistema, como `/tmp` em Unix. Isso significa que os dados passam a ser armazenados de forma persistente enquanto o programa corre, mesmo com muita atividade em memória. Ao contrário de estruturas puramente em RAM, estes ficheiros podem sobreviver a um crash momentâneo de um processo até serem explicitamente removidos ou o sistema os limpar.

Para evitar que dois programas escolham o mesmo nome e estraguem os dados um do outro, os ficheiros temporários têm, em geral, **nomes gerados automaticamente**. Funções da biblioteca (como `tmpfile()` ou `mkstemp()` em C) tratam de gerar nomes únicos, muitas vezes com partes aleatórias, reduzindo o risco de colisões. Para o programador, isto é conveniente: basta pedir um ficheiro temporário e confiar que o sistema se encarrega de lhe atribuir um nome seguro.

Por fim, estes ficheiros têm vocação de ser **descartáveis**: são apagados no fim do programa ou logo que deixam de ser necessários. Podem ser usados apenas dentro de um único processo, para guardar resultados intermédios entre funções ou fases de cálculo, ou servir de canal simples de comunicação entre processos diferentes, em que um escreve e outro lê o mesmo ficheiro. Em qualquer dos casos, a ideia central é a mesma: usar o disco como zona de armazenamento e não como arquivo permanente.

Em C, o programador não cria estes ficheiros “à mão”: usa um conjunto de funções da biblioteca padrão e do POSIX que geram nomes seguros, abrem ficheiros e, em alguns casos, até os apagam automaticamente quando os fechamos.

## Comunicação em C usando ficheiros temporários

Na perspetiva da programação em C, a comunicação por meio de ficheiros temporários consiste em utilizar o sistema de ficheiros como canal de transmissão de dados entre diferentes partes de um programa ou entre processos distintos. Tipicamente, um **processo produtor** cria um ficheiro temporário, escreve nele a informação (usando funções de E/S como `fprintf`, `fwrite` ou `write`) e passa o respetivo caminho ao **processo consumidor**, que o abre em modo de leitura e extrai os dados com `fscanf`, `fread` ou `read`. Num cenário mais simples, o mesmo processo cria o ficheiro, escreve resultados intermédios, faz `rewind` ou `fseek` para o início e lê novamente o que precisa, apagando o ficheiro no fim. Em todos os casos, o ficheiro temporário funciona como um “buffer em disco” gerido pelo programador, construído com funções próprias para criação segura (como `tmpfile()` ou `mkstemp()`) combinadas com as rotinas normais de leitura e escrita em C.

## Funções em C que podes apresentar (Só se mencionará **mkstemp()**)

### mkstemp()

Função POSIX, mais robusta:
* Protótipo: int mkstemp(char *template);
*  Recebe uma template do tipo "./tmpfileXXXXXX":
 * Os X são substituídos pelo sistema por caracteres aleatórios, gerando um nome único.
* Devolve um descritor de ficheiro aberto para leitura/escrita.
* É a forma recomendada em Unix para criar ficheiros temporários com um nome.

Fluxo típico:
1. Declarar uma template:
   ``` char template[] = "/tmp/meutmpXXXXXX"; ```
2. Chamar ``` mkstemp(template); ```
3. Usar o descritor com ``` write/read ``` ou convertê-lo para ``` FILE* ``` com ``` fdopen ```.
4. No fim, fechar e apagar o ficheiro com ``` close/fclose ``` e ``` remove ``` ou ``` unlink ```.

## Funções de apoio na leitura/escrita

* **Modo “baixo nível” (POSIX)**:
 * ``` read ```, ``` write ``` (sobre o descritor devolvido por ``` mkstemp ```)
 * ``` lseek ```
 * ``` close ```
 * ``` unlink ``` ou ``` remove ``` para apagar o ficheiro.
