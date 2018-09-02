%include "boot.inc"
section loader vstart=loader_base_addr

; 打印欢迎字符串
; 通过调用函数 print_string
mov bx, prompt
mov ax, prompt_len
mov ch, cyan_black_light
mov dx, 320
call print_string


; 在此自旋等待
dead_loop:
    hlt
    jmp dead_loop


; 函数定义区
%include "printer.inc"


; 数据区
prompt      db  "Loader Successfully Loaded. Halt."
prompt_len  equ $ - prompt
