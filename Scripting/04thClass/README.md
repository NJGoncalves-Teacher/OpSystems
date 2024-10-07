# Expressões Aritméticas

Uma **expressão aritmética** é uma combinação de operandos (valores ou variáveis) e operadores (como `+`, `-`, `*`, `/`, etc.) que o computador pode avaliar para produzir um resultado numérico. Em outras palavras, uma expressão aritmética executa operações matemáticas como soma, subtração, multiplicação, divisão, entre outras.

No contexto de programação e scripts de shell, como no **bash**, expressões aritméticas permitem que você manipule valores numéricos diretamente no código para resolver problemas e tomar decisões.

## Execução

A expressão só por si não é entendida pela *shell*. Para tal terá que ser *expandida*, *i.e.*, identificada e decomposta para ser executada 

O *Bash* é capaz de realizar as operações aritméticas básicas de quatro formas, todas elas limitadas a números inteiros:

- Comando interno: `let expressão`
- Comando composto: `(( expressão ))`
- Expansão aritmética: `$(( expressão ))`  ou `$[ expressão ]` (`bash`)
- Com valores definidos como inteiros: `declare -i nome`

Além disso, no interior dos colchetes (`[...]`) do índice de um vetor indexado, os valores são tratados como inteiros pelo Bash, o que nos permite realizar operações aritméticas com eles. Isso, por exemplo, seria perfeitamente válido:

```
vetor[n++]
```

Também podes recorremo-nos aos comandos `expr` e `bc` que também serão abordados.

## **Operadores aritméticos**

| **Operador** | **Descrição** |
| --- | --- |
| `+` | Soma |
| `-` | Subtração |
| `*` | Multiplicação |
| `/` | Divisão |
| `%` | Módulo (resto) |
| `**` | Potenciação (exponenciação) |

## **Operadores de atribuição**

| **Operador** | **Descrição** |
| --- | --- |
| `nome=valor` | Atribui um valor a "nome" |
| `nome+=valor` | Soma um valor ao valor atual em "nome" |
| `nome-=valor` | Subtrai um valor do valor atual em "nome" |
| `nome*=valor` | Multiplica o valor atual em "nome" por outro valor |
| `nome/=valor` | Divide o valor atual em "nome" por outro valor |
| `nome%=valor` | Substitui o valor atual em "nome" pelo resto da divisão por outro valor |
| `nome++` | Pós-incremento: retorna o valor atual em "nome" e soma 1 |
| `nome--` | Pós-decremento: retorna o valor atual em "nome" e subtrai 1 |
| `++nome` | Pré-incremento: atribui a "nome" o seu valor atual mais 1 |
| `--nome` | Pré-decremento: atribui a "nome" o seu valor atual menos 1 |

## **Precedência**

Quanto à ordem de precedência (quem é executado primeiro),os operadores aritméticos seguem as mesmas regras da matemática:

- As operações são efetuadas da esqueda para a direita;
- Primeiro efetua-se o que está entre parêntesis;
- Depois as exponenciações;
- Depois as multiplicações, divisões e módulos;
- Por último, as somas e subtrações.
