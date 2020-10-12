nasm -o mbr.bin mbr.s && \
dd if=mbr.bin of=hd60M.img bs=512 count=1 conv=notrunc && \
bochs