%include "boot.inc"
section loader vstart=loader_base_addr

; 加载器的栈顶，栈向代码所在的相反方向生长
loader_stack_top    equ loader_base_addr

jmp loader_start

gdt_base:
    dd  0x0000_0000         ; 第 1 个描述符不可用，置空
    dd  0x0000_0000
code_desc:
    dd  desc_low4
    dd  desc_code_high4
data_stack_desc:
    dd  desc_low4
    dd  desc_data_high4
video_desc:
    dd  desc_video_low4
    dd  desc_video_high4

gdt_size            equ $ - gdt_base
gdt_limit           equ gdt_size - 1
; 这里预留 60 个描述符
times 60 dq 0

selector_code       equ (1 << 3) | ti_gdt | rpl_0
selector_data       equ (2 << 3) | ti_gdt | rpl_0
selector_video      equ (3 << 3) | ti_gdt | rpl_0

gdt_ptr:
    dw  gdt_limit
    dd  gdt_base

loader_start:

; 打印欢迎字符串
; 通过调用函数 print_string
mov bx, prompt
mov ax, prompt_len
mov ch, cyan_black_light
mov dx, byte_per_line * 2
call print_string_m_16


; 准备进入保护模式
; 打开 A20
in  al, 0x92
or  al, 0b0000_0010
out 0x92, al

; 加载 GDT
lgdt [gdt_ptr]

; 调试信息
; 报告 GDT 已经加载完成
mov bx, gdt_msg
mov ax, gdt_msg_len
mov ch, cyan_black_light
mov dx, byte_per_line * 3
call print_string_m_16

; cr0 第 0 位设置为 1
mov eax, cr0
or  eax, 0x0000_0001
mov cr0, eax

; 刷新流水线
jmp dword selector_code : p_mode_start

[bits 32]
p_mode_start:

mov ax, selector_data
mov ds, ax
mov es, ax
mov ss, ax
mov esp, loader_stack_top
mov ax, selector_video
mov gs, ax

mov byte [gs:byte_per_line * 4], 'P'


; 在此自旋等待
jmp $


; 函数定义区
%include "printer.inc"


; 数据区
prompt      db  "Loader Successfully Loaded. Entering Real Mode..."
prompt_len  equ $ - prompt

gdt_msg     db  "GDT Prepared. All Segments Ready."
gdt_msg_len equ $ - gdt_msg
