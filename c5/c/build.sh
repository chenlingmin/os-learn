nasm -I include/ -o mbr.bin    mbr.s && \
nasm -I include/ -o loader.bin loader.s && \
x86_64-elf-gcc -c -o kernel/main.o kernel/main.c && \
x86_64-elf-ld kernel/main.o -Ttext 0xc0001500 -e main -o kernel/kernel.bin && \
dd if=mbr.bin            of=../../hd60M.img bs=512 count=1          conv=notrunc && \
dd if=loader.bin         of=../../hd60M.img bs=512 count=4   seek=2 conv=notrunc && \
dd if=kernel/kernel.bin  of=../../hd60M.img bs=512 count=200 seek=9 conv=notrunc && \
bochs