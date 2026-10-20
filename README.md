# ACUtA
Analisador e conversor (português) UTF8 para ASCII em Assembly x86-64 

Projeto realizado no âmbito da cadeira de Arquitetura de Sistemas Computacionais (FCUL, LEI, 2025/26)

- Assembly x86 de 64 bits, usando a notação Intel, para o nasm

- Ficheiros fornecidos pelo enunciado original estão em /apoio

- Objetivos de Aprendizagem/Tópicos: manipulação direta de memória, buffers e pointers, operações bitwise (para parsing de UTF-8/ASCII), gestão da pilha/stack na leitura de argumentos e convenções de preparação de registers (calling conventions).

## Compilar & Linking

```bash
nasm -f elf64 conversor.asm -o conversor.o
gcc conversor.o Biblioteca.o -o programa # linking com funções de apoio fornecidas
```

## Execução 
```bash
$ ./conversor <ficheiroUTF8.txt> <ficheiroContagens.txt> <ficheiroASCII.txt> 
```

---

## Enunciado Original

### 1. Introdução

A codificação UTF8 é habitualmente usada em ficheiros de texto de forma a permitir a escrita de caracteres que não fazem parte do padrão ASCII.

O UTF8 representa todos os caracteres que fazem parte do padrão ASCII diretamente com a mesma codificação de 1 byte.

Os caracteres que não fazem parte do padrão ASCII são representados com múltiplos bytes, existindo as seguintes codificações:
* **2 bytes:** 1 byte de controlo + 1 byte com a codificação do caractere
* **3 bytes:** 1 byte de controlo + 2 bytes com a codificação do caractere
* **4 bytes:** 1 byte de controlo + 3 bytes com a codificação do caractere

Este byte de controlo é uma combinação de bits que não existe no padrão ASCII. Assim é possível analisar um texto caractere a caractere e descobrir todas as ocorrências de caracteres ASCII e também codificações específicas do UTF8 com 2, 3 ou 4 bytes. No caso das codificações específicas do UTF8, a chave desta procura está nos caracteres de controlo usados para indicar cada uma das formas de codificação.

O byte de controlo para cada codificação específica do UTF8 é, respetivamente:
* `110? ????`
* `1110 ????`
* `1111 0???`

Neste byte de controlo, o `?` significa que o bit dessa posição pode ter qualquer valor e por isso não deve ser considerado.

É objetivo deste trabalho o tratamento de textos em UTF8. A primeira parte do tratamento centra-se principalmente na contagem de ocorrências das 4 formas acima mencionadas: ASCII e UTF8 de 2, 3 e 4 bytes. A segunda parte do tratamento consiste na troca de caracteres portugueses pelo caractere ASCII mais próximo (por exemplo `ã` → `a`), portanto outros caracteres específicos do UTF8 não serão trocados.

**1.1 Caracteres portugueses**

Os caracteres portugueses não-acentuados são representados em ASCII. Já os acentuados são representados por codificações de 2 bytes. Os caracteres minúsculos portugueses acentuados estão listados na figura do enunciado e agrupados de acordo com o tipo de acentuação. A terceira coluna não é relevante para este trabalho porque mostra os códigos a usar num teclado com uma secção numérica. Os caracteres maiúsculos, não representados nesta tabela, devem também ser considerados.

Os códigos UTF8 destes caracteres podem ser consultados na tabela disponível em: https://www.utf8-chartable.de/  
Por exemplo, o caractere `ã` é representado por `0xc3a3`.

---

### 2. Objetivos

Os objetivos deste trabalho estão organizados por fase de concretização, existindo uma cotação para cada uma das fases. As fases são:
1. Contagem de ocorrências e total de bytes
2. Filtragem de caracteres específicos do UTF8
3. Conversão de caracteres portugueses específicos do UTF8 para a codificação ASCII mais próxima

**2.1 Fase 1**
Pretende-se nesta fase, numa única análise ao texto, contar simultaneamente:
* O número total de bytes do texto
* O número de caracteres ASCII
* O número de caracteres específicos do UTF8 codificados com 2 bytes
* O número de caracteres específicos do UTF8 codificados com 3 bytes
* O número de caracteres específicos do UTF8 codificados com 4 bytes

**2.2 Fase 2**
Pretende-se nesta fase construir um segundo texto onde apenas constam, na mesma ordem, as ocorrências de caracteres ASCII. Desta forma, todas as ocorrências de codificações específicas do UTF8 são suprimidas.

**2.3 Fase 3**
Pretende-se nesta fase construir um segundo texto onde constam, na mesma ordem, as ocorrências de caracteres ASCII e onde todos os caracteres portugueses específicos do UTF8 são convertidos para os caracteres ASCII mais próximos. Ocorrências de outros caracteres específicos do UTF8 são suprimidas.

---

### 3. Implementação

Este trabalho deve ser realizado em Assembly x86 de 64 bits, usando a notação Intel, para o `nasm`.

O programa vai receber os nomes dos ficheiros de entrada e de saída pela linha de comando. Um exemplo da linha de comando para o executável do aluno `fc12345` será:

```bash
$ ./fc12345 <ficheiroUTF8.txt> <ficheiroContagens.txt> <ficheiroASCII.txt>
```

* **Primeiro argumento:** nome do ficheiro de entrada codificado em UTF8.
* **Segundo argumento:** nome do ficheiro de saída com as contagens (fase 1 dos objetivos).
* **Terceiro argumento:** nome do ficheiro de saída que apenas usa a codificação ASCII (fases 2 e 3).

Estes nomes de ficheiros podem ser copiados para variáveis globais para simplificar a sua utilização, ou podem ser apenas mantidos na pilha (*stack*) para otimizar a utilização da memória.

Com o nome do ficheiro de entrada em UTF8 já é possível ler o seu conteúdo para a memória. A leitura do conteúdo de um ficheiro para memória será feita através de uma operação do sistema operativo. O tamanho máximo do ficheiro será de 999 bytes. Para simplificar este procedimento, é oferecida uma função com o nome de `readTextFile`, que será explicada mais à frente.

Com o conteúdo do ficheiro em memória já é possível efetuar as contagens e conversões. No final, as escritas das contagens para um ficheiro e também do texto em ASCII para um outro ficheiro serão efetuadas com o suporte de uma função de escrita com o nome de `writeTextFile`.

**3.1 Biblioteca de funções**

Como suporte ao projeto é fornecida uma biblioteca de funções na forma de um módulo objeto (`.o`). As funções oferecidas, os seus parâmetros de entrada e o seu resultado são os seguintes:

```nasm
;--------------------------------------------------------------------
; readTextFile
; Objetivo: Ler um ficheiro de texto (TXT) para a memória
; Entradas :
; RDI - Endereço de memória para string, terminada por 0, com o nome do ficheiro a ler
; RSI - Endereço do buffer (espaço de memória) que guardará os bytes lidos
; Saida :
; RAX - quantidade de bytes lidos do ficheiro para o buffer na memória
; Destrói: RDI, RSI, RAX e RDX
;--------------------------------------------------------------------

;--------------------------------------------------------------------
; writeTextFile
; Objetivo: Escrever o conteúdo do buffer com o texto de saída para um ficheiro TXT
; Entradas :
; RDI - Endereço de memória para a string, terminada por 0, com o nome do ficheiro a escrever
; RSI - Endereço do buffer que contém os bytes do texto a serem escritos
; RDX - Quantidade de bytes do buffer para escrever no ficheiro
; Saida : Nada
; Destrói: RDI, RSI, RAX e RDX
;--------------------------------------------------------------------

;--------------------------------------------------------------------
; utoa3
; Objetivo: Converter um número natural para o formato ASCII, com 3 algarismos terminado
; por mudança de linha, que será escrito no buffer (total de 4 caracteres)
; Entradas :
; RDI - número a converter
; RSI - Endereço do buffer onde será escrito o valor codificado em ASCII + newline
; Saída :
; RAX = RSI (buffer)
;--------------------------------------------------------------------
```

Exemplo de utilização de função de leitura de um ficheiro, usando a biblioteca de suporte:

```nasm
...
extern readTextFile
e: db "ficheiroentrada.txt",0
eb: resb 1000
...
mov rdi, e
mov rsi, eb
call readTextFile
...
```

De notar que, para simplificar, neste exemplo o nome do ficheiro está definido numa variável. Para o projeto este nome será recebido pela pilha como o primeiro parâmetro de entrada.

A função de escrita pode ser utilizada de forma muito similar. As diferenças são que agora o ficheiro indicado será usado para escrever o conteúdo pretendido da memória do programa e é necessário indicar o número de bytes a escrever no terceiro parâmetro da função (`RDX`).

No caso da função `utoa3`, o número natural convertido para ASCII será escrito no *buffer* e serão adicionados zeros à esquerda de forma que este ocupe sempre 3 caracteres. A seguir ao valor será ainda adicionado o caractere de mudança de linha (`newline`).

De modo a se poder usar as funções da biblioteca no código do programa a desenvolver é necessário ligar (*link*) o programa com a biblioteca disponibilizada na forma de módulo objeto. As instruções para este procedimento foram explicadas na secção final do Fascículo de Introdução às funções.

O módulo objeto da biblioteca (`Biblioteca.o`), um ficheiro de entrada de exemplo (`lusiadas1.txt`) e as respetivas saídas que dão resposta às 3 fases (`contadores1.txt`, `lusiadas1fase2.txt` e `lusiadas1fase3.txt`) estão incluídos no ficheiro comprimido `apoio_projeto.tar.gz`.

---

### 4. Avaliação e Regras de Output

O projeto é individual. A avaliação das 3 fases será de acordo com a seguinte distribuição:
* **Fase 1:** até 10 valores
* **Fase 2:** até 4 valores
* **Fase 3:** até 6 valores

**Requisitos Técnicos (Ordem e Formato)**
* Os parâmetros de entrada do programa devem seguir a ordem definida neste enunciado.
* O conteúdo do ficheiro de contagem deve seguir o formato usado no respetivo ficheiro de teste:
  * Cada valor é escrito numa linha separada;
  * Não existem linhas em branco antes dos valores ou entre os valores;
  * Cada valor é escrito como um conjunto de 3 algarismos terminados pela mudança de linha (`newline`);
  * Os cinco valores devem ser escritos na ordem definida na secção de objetivos.

---

### 5. Ambiente de desenvolvimento

Este projeto pode ser realizado com qualquer um dos seguintes ambientes Linux (Ubuntu):
* **CLI**, com qualquer editor de texto e execução por linha de comandos de `nasm`, `ld` e `gdb`
* **SASM**, usando o `SASM.conf` fornecido e colocando a biblioteca em `/tmp`
* **VSCode**, configurando as extensões e os ficheiros `launch.json` e `tasks.json`
