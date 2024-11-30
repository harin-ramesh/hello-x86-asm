section .data
    file_path DD "/home/harin/working_dir/x86/seek/text.txt"

section .bss
    buffer: resb 10

section .text
global main

main:
    mov eax, 5
    mov ebx, file_path
    mov ecx, 0
    int 80h

    mov ebx, eax
    mov ecx, 20
    mov edx, 0
    mov eax, 19
    int 80h

    mov eax, 3 ; this is the file descriptor, we are just gussing the file descriptor here
    mov ecx, buffer
    mov edx, 10
    int 80h

    mov eax, 1
    mov ebx, 20
    int 80h

