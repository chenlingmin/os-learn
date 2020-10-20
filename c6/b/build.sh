nasm -I boot/include/ -o boot/mbr.bin     boot/mbr.s && \
nasm -I boot/include/ -o boot/loader.bin boot/loader.s && \
nasm -f elf -o lib/kernel/print.o lib/kernel/print.s && \
x86_64-elf-gcc -m32 -I lib/kernel -I lib -c -o kernel/main.o kernel/main.c && \
x86_64-elf-ld -melf_i386 -Ttext 0xc0001500 -e main -o kernel/kernel.bin kernel/main.o lib/kernel/print.o && \
dd if=boot/mbr.bin       of=../../hd60M.img bs=512 count=1          conv=notrunc && \
dd if=boot/loader.bin    of=../../hd60M.img bs=512 count=4   seek=2 conv=notrunc && \
dd if=kernel/kernel.bin  of=../../hd60M.img bs=512 count=200 seek=9 conv=notrunc && \
bochs
