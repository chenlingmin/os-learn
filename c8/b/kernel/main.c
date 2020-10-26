#include "print.h"
#include "init.h"
#include "debug.h"
void main(void) {
   put_str("I am kernel\n");
   init_all();
   ASSERT(1==2);
//   asm volatile("sti");         // 为演示中断处理，在此临时开启中断
   while(1);
   return 0;
}
