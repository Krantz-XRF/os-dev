; 公共函数
; 直接访问显存来打印欢迎字符串
[bits 16]
print_string_m_16:
    ; 参数 bx = 字符串地址
    ; 参数 ax = 字符串长度
    ; 参数 ch = 字符属性
    ; 参数 dx = 起始写入的相对位置
    ; Pre: gs = 显存段地址 && 字符串长度 >= 1
    xor si, si
    mov di, dx
    .write_byte:
        mov cl, byte [bx+si]
        mov byte [gs:di], cl        ; 写入字符本身
        inc di
        mov byte [gs:di], ch        ; 写入字符属性
        inc di
        inc si
    cmp ax, si
    jne .write_byte
    ret
    ; 没有返回值

; 打印字符属性(K：闪烁，RGB：背景，I：亮度，RGB：前景)
green_red_blink     equ 0b10100100  ; 绿底红字，闪烁
blue_black_light    equ 0b00001001  ; 黑底蓝字，亮度加强
cyan_black_light    equ 0b00001011  ; 黑底青色字，亮度加强
