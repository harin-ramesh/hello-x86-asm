section .data
    pathname DD "/home/harin/working_dir/x86/file/new_text.txt"
    write_data DD "Hello World!", 0AH, 0DH, "$"

section .bss
    buffer: resb 1024

section .text

global main

main:
    mov eax, 5
    mov ebx, pathname
    mov ecx, 101o            ; Octal, file mode, here create and write
    mov edx, 700o            ; Octal, file permission
    int 80h
    
    mov ebx, eax
    mov eax, 4
    mov ecx, write_data
    mov edx, 15
    int 80h

    mov eax, 1
    mov ebx, 10
    int 80h
