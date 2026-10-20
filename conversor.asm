extern readTextFile
extern writeTextFile
extern utoa3

section .rodata
msg_erro: db "Introduza tres parametros como esperado!", 0
msg_erro_len: equ $-msg_erro
SYS_WRITE equ 1
SYS_EXIT equ 60

section .data
total_bytes_num: dq 0
ascii_char_num: dq 0
utf8_2_char_num: dq 0
utf8_3_char_num: dq 0
utf8_4_char_num: dq 0

section .bss
e_buffer: resb 1000
e_ascii_buffer: resb 1000
e_full_ascii_converted: resb 1000
e_contagens: resb 20

section .text
global _start
; nasm -f elf64 -g -F dwarf conversor.asm => COMPILAR
; ld conversor.o Biblioteca.o -o conversor => LIGAR
; ./conversor lusiadas1.txt ficheiroContagens.txt ficheiroASCII.txt => EX. EXECUCAO
_start:
    ; obter argc (4)
    mov rcx, [rsp]
    cmp rcx, 4
    jl erro ; erro argumentos insuficientes

    ; endereços dos argumentos: [rsp+16] 1o argumento ; [rsp+24] 2o argumento ; [rsp+32] 3o argumento
    lea rbp, [rsp+16] ; load endereço nome do ficheiro a ler

    ; ________________________________________ FASE 1 _________________________________________________

    ; READ TEXT FILE _____________
    ; preparacao dos argumentos
    mov rdi, [rbp] ; endereço de memoria para string (nome do ficheiro a ler)
    lea rsi, e_buffer ; endereço do bugger para guardar bytes lidos

    ; chamada de funcao 
    call readTextFile ; RESULTADO: quantidade de bytes lidos no texto (numero) ___________

    mov rcx, rax ; guardar resultado em rcx e outra variavel
    mov [total_bytes_num], rax 

    ; zerar registos p/ contadores
    xor r8, r8
    xor r9, r9
    xor r10, r10
    xor r11, r11

    ; ponteiros
    ; rsi: endereço buffer texto (fase 1)
    lea rsi, e_buffer
    ; rdx: endereço buffer extra texto ascii (fase 2)
    lea rdx, e_ascii_buffer
    ; r12: endereço buffer texto completo convertido p/ascii (fase 3)
    xor r12, r12
    lea r12, e_full_ascii_converted

    ; analisar todos os bytes lidos e contar ocorrencias!
    _while:
        cmp rcx, 0 ; rcx => tem quantidade de bytes lidos
        jle _loopend ; sair do loop quando todos os bytes foram analisados
        
        mov al, [rsi] ; 1o byte
        ; ascii
        test al, 10000000b
        jz _asciinc
        ; utf 2
        mov bl, al
        and bl, 11100000b
        cmp bl, 11000000b
        je _utf2inc
        ; utf 3 
        mov bl, al
        and bl, 11110000b
        cmp bl, 11100000b
        je _utf3inc
        ; utf 4
        mov bl, al
        and bl, 11111000b
        cmp bl, 11110000b
        je _utf4inc
        ; caso nada seja encontrado avançar no loop igualmente
        inc rsi 
        dec rcx
        jmp _while
        _asciinc:
            inc r8

            ; FASE 2_____________
            mov al, [rsi] ; copiar o byte atual para o buffer exclusivo ascii
            mov [rdx], al 
            inc rdx ; pointer ascii +1
            ;___________________

            ; FASE 3_____________
            mov [r12], al ; copiar byte atual (ja em al) para o buffer conversao (=)
            inc r12 ; pointer ascii converted +1
            ;____________________

            inc rsi ; pointer +1
            dec rcx ; -1 byte
            jmp _while ; voltar ao loop
        _utf2inc:
            inc r9

            ; FASE 3_____________
            ; conversao de utf8-2 p/ ascii 
            ; caracter atual: 2 bytes (byte 1: controlo, byte 2: codificacao)
            mov al, [rsi+1] ; copiar para al o byte de codificacao

            ; CONVERSOR 
            ; á, à, ã, â  => a
            cmp al, 10100001b ; á
            je _convert_a
            cmp al, 10100000b ; à
            je _convert_a
            cmp al, 10100011b ; ã
            je _convert_a
            cmp al, 10100001b ; â
            je _convert_a

            ; Á, À, Ã, Â => A
            cmp al, 10000001b ; Á
            je _convert_A
            cmp al, 10000000b ; À
            je _convert_A
            cmp al, 10000011b ; Ã
            je _convert_A
            cmp al, 10100010b ; Â
            je _convert_A

            ; é, ê => e
            cmp al, 10101001b ; é
            je _convert_e
            cmp al, 10101010b ; ê
            je _convert_e

            ; É, Ê => E
            cmp al, 10001001b ; É
            je _convert_E
            cmp al, 10001010b ; Ê
            je _convert_E

            ; í => i
            cmp al, 10101101b 
            je _convert_i

            ; Í => I
            cmp al, 10001101b 
            je _convert_I

            ; ó, õ => o
            cmp al, 10110011b ; ó
            je _convert_o
            cmp al, 10110101b ; õ
            je _convert_o

            ; Ó, Õ => O
            cmp al, 10010011b ; Ó
            je _convert_O
            cmp al, 10010101b ; Õ
            je _convert_O

            ; ú => u 
            cmp al, 10111010b 
            je _convert_u

            ; Ú => U
            cmp al, 10011010b 
            je _convert_U
            
            ; ç => c
            cmp al, 10100111b
            je _convert_c

            ; Ç => C
            cmp al, 10000111b
            je _convert_C

            ; controlo (sem matches?)
            jmp _convert_end_no_match ; skip caracter desconhecido

            ; minusculas
            _convert_a:
                mov byte [r12], 'a' ; auto traducao NASM p/ binario
                jmp _convert_end
            _convert_e:
                mov byte [r12], 'e' 
                jmp _convert_end
            _convert_i:
                mov byte [r12], 'i' 
                jmp _convert_end
            _convert_o:
                mov byte [r12], 'o' 
                jmp _convert_end
            _convert_u:
                mov byte [r12], 'u' 
                jmp _convert_end
            _convert_c:
                mov byte [r12], 'c' 
                jmp _convert_end

            ; MAIUSCULAS
            _convert_A:
                mov byte [r12], 'A' 
                jmp _convert_end
            _convert_E:
                mov byte [r12], 'E' 
                jmp _convert_end
            _convert_I:
                mov byte [r12], 'I' 
                jmp _convert_end
            _convert_O:
                mov byte [r12], 'O' 
                jmp _convert_end
            _convert_U:
                mov byte [r12], 'U' 
                jmp _convert_end
            _convert_C:
                mov byte [r12], 'C' 
                jmp _convert_end
            
            _convert_end:
                inc r12 ; pointer ascii converted +1
                ;____________________
            _convert_end_no_match: 
                add rsi, 2
                sub rcx, 2
                jmp _while
        _utf3inc:
            inc r10
            add rsi, 3
            sub rcx, 3
            jmp _while
        _utf4inc:
            inc r11
            add rsi, 4
            sub rcx, 4
            jmp _while
    _loopend:
    ; mover os numeros totais de ocorrencias nos registos para as variaveis
    mov [ascii_char_num], r8
    mov [utf8_2_char_num], r9
    mov [utf8_3_char_num], r10
    mov [utf8_4_char_num], r11
    
    
    ; converter os valores e guarda los no endereço com as contagens
    ; (conversao feita ja com newline!)
    lea rsi, e_contagens
    mov rdi, [total_bytes_num]
    call utoa3

    ; add rsi, 4 
    mov rdi, [ascii_char_num]
    call utoa3

    ; add rsi, 4
    mov rdi, [utf8_2_char_num]
    call utoa3

    ; add rsi, 4
    mov rdi, [utf8_3_char_num]
    call utoa3

    ; add rsi, 4
    mov rdi, [utf8_4_char_num]
    call utoa3

        
    ; escrever um novo ficheiro c/ contagens
    lea rbp, [rsp+24] ; segundo arg (nome do ficheiro p/ escrever)
    mov rdi, [rbp]
    mov rsi, e_contagens ; valores em ASCII p/ escrever
    mov rdx, 20 ; bytes a serem escritos (5 numeros de 3(valor)+1(espaço) bytes!)

    call writeTextFile

    ; ________________________________________ FASE 2 _________________________________________________

    ; escrever um novo ficheiro apenas c/ ocorrencias ascii
    lea rbp, [rsp+32] ; terceiro arg (nome do ficheiro p/ escrever)
    mov rdi, [rbp]
    mov rsi, e_ascii_buffer ; buffer c/ ocorrencias ASCII
    mov rdx, [ascii_char_num] ; n de ocorrencias ASCII = n bytes a escrever

    call writeTextFile

    ; ________________________________________ FASE 3_________________________________________________

    ; escrever um novo ficheiro convertido p/ caracteres ascii
    lea rbp, [rsp+32] ; terceiro arg (nome do ficheiro p/ escrever) - OVERWRITE DA FASE 2
    mov rdi, [rbp]
    mov rsi, e_full_ascii_converted ; buffer c/ ocorrencias de conversao ASCII
    mov rdx, r12 ; total de bytes a escrever = pos final ponteiro (r12) - tamanho do buffer
    sub rdx, e_full_ascii_converted

    call writeTextFile ; overwrite ficheiro fase 2

    jmp fim

erro:
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, msg_erro
    mov rdx, msg_erro_len
    syscall
fim:
    mov rax, SYS_EXIT
    xor rdi, rdi
    syscall 