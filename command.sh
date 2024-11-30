nasm -f elf -o obj.o prog.s
gcc -no-pie -m32 -o bin obj.o

