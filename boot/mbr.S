section mbr vstart=0x7c00

; Pre: cs = 0
; 即清除 ax/ds/es/ss/fs 寄存器的内容
mov ax, cs
mov ds, ax
mov es, ax
mov ss, ax
mov fs, ax

mov sp, 0x7c00


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
int 0x10            ; 返回值 (ch, cl) = 光标行区间，忽略
                    ; 返回值 (dh, dl) = 光标行列坐标


; 打印欢迎字符串
; int 0x10 : 0x13 打印字符串到指定位置
mov ax, prompt
mov bp, ax          ; es:bp = 要打印的字符串
mov cx, prompt_len  ; cx = 不包括结尾 0 的字符串长度
mov ax, 0x1301      ; ax = (ah = 0x13 功能号, al = 0x01 显示字符串，光标随之移动)
mov bx, 0x0002      ; bx = (bh = 0 页号, bl = 2 字符黑底绿字)
int 0x10


; 程序自旋等待
jmp $


; 数据区
prompt      db  "Hello, MBR World!"
prompt_len  equ $ - prompt - 1      ; 这里的长度计算要减去结尾的 0

; MBR 签名 0xaa55
times (510 - ($ - $$)) db 0             ; 填充 0 直到 510 字节
db 0x55, 0xaa
