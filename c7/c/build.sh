if [ ! -d "build" ]; then
  mkdir build
fi
nasm -I boot/include/ -o build/mbr.bin     boot/mbr.s && \
nasm -I boot/include/ -o build/loader.bin  boot/loader.s && \
nasm -f elf -o build/print.o lib/kernel/print.s && \
nasm -f elf -o build/kernel.o kernel/kernel.s && \
x86_64-elf-gcc -m32 -I lib/kernel -I lib/ -c -o build/timer.o device/timer.c && \
x86_64-elf-gcc -m32 -I lib/kernel -I lib/ -I kernel/ -c -fno-builtin -o build/main.o kernel/main.c && \
x86_64-elf-gcc -m32 -I lib/kernel -I lib/ -I kernel/ -c -fno-builtin -o build/init.o kernel/init.c && \
x86_64-elf-gcc -m32 -I lib/kernel -I lib/ -I kernel/ -c -fno-builtin -o build/interrupt.o kernel/interrupt.c && \
x86_64-elf-ld -melf_i386 -Ttext 0xc0001500 -e main -o build/kernel.bin build/main.o build/init.o build/interrupt.o build/print.o build/kernel.o build/timer.o && \
dd if=build/mbr.bin       of=../../hd60M.img bs=512 count=1          conv=notrunc && \
dd if=build/loader.bin    of=../../hd60M.img bs=512 count=4   seek=2 conv=notrunc && \
dd if=build/kernel.bin    of=../../hd60M.img bs=512 count=200 seek=9 conv=notrunc && \
bochs
