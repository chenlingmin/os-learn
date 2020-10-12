;主引导程序
;------------------------------------------------------------------
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
    mov cx, 0               ;左上角: (0, 0)
    mov dx, 0x184f          ;右下角: (80, 25)

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

    jmp $

    message db "1 MBR"
    times 510-($-$$) db 0
    db 0x55, 0xaa