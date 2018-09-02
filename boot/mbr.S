section mbr vstart=0x7c00

; Pre: cs = 0
; 即清除 ax/ds/es/ss/fs 寄存器的内容
mov ax, cs
mov ds, ax
mov es, ax
mov ss, ax
mov fs, ax

mov sp, 0x7c00

; 将 gs 寄存器设置为显存的地址
mov ax, 0xb800
mov gs, ax


; 清空屏幕，即上卷全部行
; int 0x10 : 0x06 上卷窗口
mov ax, 0x0600      ; ax = (ah = 0x06 功能号, al = 0 上卷行数，表示全部)
mov bx, 0x0700      ; bx = (bh = 0x07 上卷行属性, bl = 0)
; VGA 模式下屏幕尺寸为 25 行，80 列
mov cx, 0           ; cx = (ch, cl) = (0, 0) 左上角坐标
mov dx, 0x184f      ; dx = (dh, dl) = (24, 79) 右下角坐标
int 0x10


; 获取光标位置
; int 0x10 : 0x03 查询光标位置
mov ah, 3           ; ah = 0x03 功能号
mov bh, 0           ; bh = 0 要查询的页号
int 0x10
; 返回值 (ch, cl) = 光标行区间，忽略
; 返回值 (dh, dl) = 光标行列坐标


; 打印欢迎字符串
; 通过调用函数 print_string
mov bx, prompt
mov ax, prompt_len
mov ch, blue_black_light
xor dx, dx
call print_string


; 程序自旋等待
jmp $


; 函数定义区
; 直接访问显存来打印欢迎字符串
print_string:
    ; 参数 bx = 字符串地址
    ; 参数 ax = 字符串长度
    ; 参数 ch = 字符属性
    ; 参数 dx = 起始写入的相对位置
    ; Pre: gs = 显存段地址 && 字符串长度 >= 1
    xor si, si
    mov di, dx
    write_byte:
        mov cl, byte [bx+si]
        mov byte [gs:di], cl        ; 写入字符本身
        inc di
        mov byte [gs:di], ch        ; 写入字符属性
        inc di
        inc si
    cmp ax, si
    jne write_byte
    ret
    ; 没有返回值


; 数据区
prompt      db  "Hello, MBR World!"
prompt_len  equ $ - prompt          ; 字符串的结尾不包含一个 0

; 打印字符属性(K：闪烁，RGB：背景，I：亮度，RGB：前景)
green_red_blink     equ 0b10100100  ; 绿底红字，闪烁
blue_black_light    equ 0b00001001  ; 黑底蓝字，亮度加强

; MBR 签名 0xaa55
times (510 - ($ - $$)) db 0         ; 填充 0 直到 510 字节
db 0x55, 0xaa
