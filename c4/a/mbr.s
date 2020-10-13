;主引导程序
;------------------------------------------------------------------
%include "boot.inc"
SECTION MBR vstart=0x7c00
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov sp, 0x7c00
    mov ax, 0xb800
    mov gs, ax

; 清屏 利用0x06号功能，上卷全部行，则可清屏。
;------------------------------------------------------------------
;INT 0x10   功能号:0x06	   功能描述:上卷窗口
;------------------------------------------------------------------
;输入：
;AH 功能号= 0x06
;AL = 上卷的行数(如果为0,表示全部)
;BH = 上卷行属性
;(CL,CH) = 窗口左上角的(X,Y)位置
;(DL,DH) = 窗口右下角的(X,Y)位置
;无返回值：

    mov ax, 0x0600
    mov bx, 0x0700
    mov cx, 0                       ;左上角: (0, 0)
    mov dx, 0x184f                  ;右下角: (80, 25)

    int 0x10


    ;输出背景色绿色，前景色红色，并且跳动的字符串"1 MBR"
    mov byte [gs:0x00], '1'
    mov byte [gs:0x01], 0xA4

    mov byte [gs:0x02], ' '
    mov byte [gs:0x03], 0xA4

    mov byte [gs:0x04], 'M'
    mov byte [gs:0x05], 0xA4

    mov byte [gs:0x06], 'B'
    mov byte [gs:0x07], 0xA4

    mov byte [gs:0x08], 'R'
    mov byte [gs:0x09], 0xA4

    mov eax, LOADER_START_SECTOR    ;起始扇区的LBA地址
    mov bx, LOADER_BASE_ADDR        ;写入的地址
    mov cx, 4                       ;待读入的扇区数
    call rd_disk_m_16               ;读取程序的起始部分

    jmp LOADER_BASE_ADDR

;------------------------------------------------------------------
;功能：读取硬盘n个扇区
rd_disk_m_16:
;------------------------------------------------------------------
                                    ;eax=LBA扇区号
                                    ;ebx=将数据写入的内存地址
                                    ;ecx=读入的扇区数量
    mov esi, eax                    ;备份eax
    mov di, cx                      ;备份cx

;读写硬盘:
;第一步：设置要读取的扇区数
    mov dx, 0x1f2
    mov al, cl
    out dx, al

    mov eax, esi                    ;恢复ax

;第二步：将LBA地址存入0x1f3 ~ 0x1f6

    ;LBA地址的7~0位写入端口0x1f3
    mov dx, 0x1f3
    out dx, al

    ;LBA地址的15~8位写入端口0x1f4
    mov cl, 8
    shr eax, cl
    mov dx, 0x1f4
    out dx, al

    ;LBA地址的23~16位写入端口0x1f5
    shr eax, cl
    mov dx, 0x1f5
    out dx, al

    shr eax, cl
    and al, 0x0f                    ;LBA第24~27位
    or  al, 0xe0                    ;设置7~4位为1110，表示LBA模式
    mov dx, 0x1f6
    out dx, al

;第三步：向0x1f7端口写入读命令， 0x20
    mov dx, 0x1f7
    mov al, 0x20
    out dx, al

;第四步：检测硬盘状态
.not_ready:
    nop
    in  al, dx
    and al, 0x88
    cmp al, 0x08
    jnz .not_ready

;第五步：从0x1f0端口读取数据
    mov ax, di
    mov dx, 256
    mul dx
    mov cx, ax                      ;di为要读取的扇区数，一个扇区512byte,每次读取1word
                                    ;共需di*512/2次
    mov dx, 0x1f0
.go_on_read:
    in ax, dx
    mov [bx], ax
    add bx, 2
    loop .go_on_read
    ret

    times 510-($-$$) db 0
    db 0x55, 0xaa