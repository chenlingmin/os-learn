    %include "boot.inc"
    section loader vstart=LOADER_BASE_ADDR
    LOADER_STACK_TOP equ LOADER_BASE_ADDR

;构建gdt及其内部的描述符
    GDT_BASE:           dd 0x00000000
                        dd 0x00000000

    CODE_DESC:          dd 0x0000FFFF
                        dd DESC_CODE_HIGH4

    DATA_STACK_DESC:    dd 0x0000FFFF
                        dd DESC_DATA_HIGH4

    VIDEO_DESC:         dd 0x80000007       ;limit=(0xbffff-0xb8000)/4k=0x7
                        dd DESC_VIDEO_HIGH4 ;此时dpl已经改为0

    GDT_SIZE            equ $ - GDT_BASE
    GDT_LIMIT           equ GDT_SIZE - 1
    times 60 dq 0                           ;预留60个描述符的slot

    SELECTOR_CODE       equ (0x00001<<3) + TI_GDT + RPL0
    SELECTOR_DATA       equ (0x00002<<3) + TI_GDT + RPL0
    SELECTOR_VIDEO      equ (0x00003<<3) + TI_GDT + RPL0

    ; total_mem_bytes用于保存内存容量,以字节为单位,此位置比较好记。
    ; 当前偏移loader.bin文件头0x200字节,loader.bin的加载地址是0x900,
    ; 故total_mem_bytes内存中的地址是0xb00.将来在内核中咱们会引用此地址
    total_mem_bytes dd 0

    ;以下是定义gdt 的指针
    gdt_ptr dw GDT_LIMIT
            dd GDT_BASE

    ;人工对齐:total_mem_bytes4字节+gdt_ptr6字节+ards_buf244字节+ards_nr2,共256字节
    ards_buf times 244 db 0
    ards_nr dw 0		                    ;用于记录ards结构体数量


    loader_start:

;------- int 15h eax=0x0000E820, edx=0x534D4150 获取内存布局 --------

    xor ebx, ebx                            ;第一次调用，ebx清零
    mov edx, 0x534d4150                     ;edx只赋值一次，循环体中不会改变
    mov di, ards_buf                        ;ards缓冲区
.e820_mem_get_loop:
    mov eax, 0x0000e820                     ;执行int 0x15后，eax值会变成0x534d4150,所以每次需要赋值子功能号
    mov ecx, 20                             ;ards地址范围描述符结构大小是20字节
    int 0x15
    jc .e820_failed_so_try_e801             ;若cf位为1则有错误发生，尝试0xe801子功能
    add di, cx                              ;使di增加20字节指向缓冲区中新的ARDS结构位置
    inc word [ards_nr]                      ;记录ards数量
    cmp ebx, 0                              ;若ebx为0且cf不为1,这说明ards全部返回，当前已是最后一个
    jnz .e820_mem_get_loop

;在所有的ards结构中，找出(base_add_low + length_low)的最大值，即内存的容量。
    mov cx, [ards_nr]                       ;遍历每一个ARDS结构体,循环次数是ARDS的数量
    mov ebx, ards_buf
    xor edx, edx                            ;edx为最大的内存容量,在此先清0
.find_max_mem_area:                         ;无须判断type是否为1,最大的内存块一定是可被使用
    mov eax, [ebx]                          ;base_add_low
    add eax, [ebx+8]                        ;length_low
    add ebx, 20                             ;指向下一个ards
    cmp edx, eax                            ;冒泡排序，找出最大,edx寄存器始终是最大的内存容量
    jge .next_ards
    mov edx, eax                            ;edx为总内存的大小
.next_ards:
    loop .find_max_mem_area
    jmp .mem_get_ok

;------  int 15h ax = E801h 获取内存大小,最大支持4G  ------
; 返回后, ax cx 值一样,以KB为单位,bx dx值一样,以64KB为单位
; 在ax和cx寄存器中为低16M,在bx和dx寄存器中为16MB到4G。
.e820_failed_so_try_e801:
    mov ax, 0xe801
    int 0x15
    jc .e801_failed_so_try88                ;若当前e801方法失败,就尝试0x88方法

;1 先算出低15M的内存，ax和cx中是以KB为单位的内存数量，将其转换为以byte为单位
    mov cx, 0x400                           ;cx和ax一样，cx用作乘数
    mul cx
    shl edx, 16
    and eax, 0x0000FFFF
    or  edx, eax
    add edx, 0x00100000                     ;ax只是15MB,故要加上1MB
    mov esi, edx                            ;先把低15MB的内存容量存入esi寄存器备份

;2 再将16MB以上的内存转换为byte为单位,寄存器bx和dx中是以64KB为单位的内存数量
    xor eax, eax
    mov ax, bx
    mov ecx, 0x00010000                     ;0x10000十进制的64KB
    mul ecx                                 ;32位乘法,默认的被乘数是eax,积为64位,高32位存入edx,低32位存入eax.
    add esi, eax                            ;由于此方法只能测出4G以内的内存,故32位eax足够了,edx肯定为0,只加eax便可
    mov edx, esi                            ;edx为总内存大小
    jmp .mem_get_ok

;-----------------  int 15h ah = 0x88 获取内存大小,只能获取64M之内  ----------
.e801_failed_so_try88:
    ;int 15后，ax存入的是以kb为单位的内存容量
    mov ah, 0x88
    int 0x15
    jc .error_hlt
    and eax, 0x0000FFFF

    ;16位乘法，被乘数是ax,积为32位.积的高16位在dx中，积的低16位在ax中
    mov cx, 0x400                           ;0x400等于1024,将ax中的内存容量换为以byte为单位
    mul cx
    shl edx, 16                             ;把dx移到高16位
    or  edx, eax                            ;把积的低16位组合到edx,为32位的积
    add edx, 0x00100000                     ;0x88子功能只会返回1MB以上的内存,故实际内存大小要加上1MB

.mem_get_ok:
    mov [total_mem_bytes], edx              ;将内存换为byte单位后存入total_mem_bytes处。

;----------------------------------------   准备进入保护模式   ------------------------------------------
									;1 打开A20
									;2 加载gdt
									;3 将cr0的pe位置1

    ;-----------------  打开A20  ----------------
    in  al, 0x92
    or  al, 0000_0010B
    out 0x92, al

    ;-----------------  加载GDT  ----------------
    lgdt [gdt_ptr]

    ;-----------------  cr0第0位置1  ----------------
    mov eax, cr0
    or  eax, 0x00000001
    mov cr0, eax

    jmp SELECTOR_CODE:p_mode_start      ;刷新流水线

.error_hlt:
    hlt

[bits 32]
p_mode_start:
    mov ax, SELECTOR_DATA
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, LOADER_STACK_TOP
    mov ax, SELECTOR_VIDEO
    mov gs, ax

    mov byte [gs:160], 'P'

    jmp $
