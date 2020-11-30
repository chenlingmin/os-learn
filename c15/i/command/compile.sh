####  此脚本应该在command目录下执行

if [[ ! -d "../lib" || ! -d "../build" ]];then
   echo "dependent dir don\`t exist!"
   cwd=$(pwd)
   cwd=${cwd##*/}
   cwd=${cwd%/}
   if [[ $cwd != "command" ]];then
      echo -e "you\`d better in command dir\n"
   fi
   exit
fi

BIN="cat"
CFLAGS="-m32 -Wall -c -fno-builtin -W -Wstrict-prototypes \
      -Wmissing-prototypes -Wsystem-headers"
LIBS="-I ../lib/ -I ../lib/kernel/ -I ../lib/user/ -I \
      ../kernel/ -I ../device/ -I ../thread/ -I \
      ../userprog/ -I ../fs/ -I ../shell/"
OBJS="../build/string.o ../build/syscall.o \
      ../build/stdio.o ../build/assert.o start.o"
DD_IN=$BIN
DD_OUT="../../..//hd60M.img"

nasm -f elf ./start.S -o ./start.o
x86_64-elf-ar rcs simple_crt.a $OBJS start.o
x86_64-elf-gcc $CFLAGS $LIBS -o $BIN".o" $BIN".c"
x86_64-elf-ld -melf_i386 $BIN".o" simple_crt.a -o $BIN
SEC_CNT=$(ls -l $BIN|awk '{printf("%d", ($5+511)/512)}')

if [[ -f $BIN ]];then
   dd if=./$DD_IN of=$DD_OUT bs=512 \
   count=$SEC_CNT seek=300 conv=notrunc
fi


##########   以上核心就是下面这五条命令   ##########
#nasm -f elf ./start.S -o ./start.o
#x86_64-elf-ar rcs simple_crt.a ../build/string.o ../build/syscall.o ../build/stdio.o ../build/assert.o ./start.o
#x86_64-elf-gcc -m32  -Wall -c -fno-builtin -W -Wstrict-prototypes -Wmissing-prototypes -Wsystem-headers -I ../lib/ -I ../lib/user -I ../fs prog_arg.c -o prog_arg.o
#x86_64-elf-ld -melf_i386 prog_arg.o simple_crt.a -o prog_arg
#dd if=prog_arg of=../../../hd60M.img bs=512 count=11 seek=300 conv=notrunc

