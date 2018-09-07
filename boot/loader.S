%include "boot.inc"
section loader vstart=loader_base_addr

; 加载器的栈顶，栈向代码所在的相反方向生长
loader_stack_top    equ loader_base_addr

; 改为在 MBR 中直接跳转到 loader_start（偏移量 0x300）
; jmp loader_start

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

; 注意：这里的对齐地址必须固定为 0xb00 = 0x900 + 0x200
; 因为随后在内核中将会引用此地址
; 前面共有 64（0x40）个 GDT 表项（共 0x200 字节）

; 此处是内存大小存储的位置
total_mem_bytes: dd 0

selector_code       equ (1 << 3) | ti_gdt | rpl_0
selector_data       equ (2 << 3) | ti_gdt | rpl_0
selector_video      equ (3 << 3) | ti_gdt | rpl_0

gdt_ptr:
    dw  gdt_limit
    dd  gdt_base

; 与内存检测 ARDS 结构相关的存储位置
ards_buf:   times 244 db 0
ards_nr:    dw 0

loader_start:

; 打印欢迎字符串
; 通过调用函数 print_string
mov bx, prompt
mov ax, prompt_len
mov ch, cyan_black_light
mov dx, byte_per_line * 2
call print_string_m_16


; 准备开始测试内存大小
; 先打印提示信息
mov bx, mem_msg
mov ax, mem_msg_len
mov ch, green_black_light
mov dx, byte_per_line * 3
call print_string_m_16

; 尝试使用 BIOS 中断获取内存大小
; int 0x15 : 0xe820
xor ebx, ebx            ; 第一次调用 ebx 置空，后续调用 ebx 由 BIOS 管理
mov edx, 0x534d4150     ; "SMAP" = 0x534d4150
mov di, ards_buf
.e280_mem_get_loop:
    mov eax, 0xe820     ; 每次执行中断，eax 被更新为 "SMAP"
    mov ecx, 20         ; ARDS 地址描述符为 20 字节
    int 0x15
    
    jc .e280_failed_so_try_e801     ; carry = 1 意味着中断执行失败

    add di, cx          ; mov ecx, 20 后 cx = 20，此处使 di 指向下一个 ARDS 结构
    inc word [ards_nr]  ; 使计数器自增
    cmp ebx, 0          ; cf == 0 && ebx == 0 说明 ARDS 全部返回成功

jnz .e280_mem_get_loop

mov cx, [ards_nr]
mov ebx, ards_buf
xor edx, edx
.find_max_mem_area:     ; 这里断言最大那块内存系统可使用
    mov eax, [ebx]      ; ARDS::base_addr_low
    add eax, [ebx+8]    ; ARDS::length_low
    add ebx, 20
    cmp edx, eax        ; edx = max(edx, eax)
    jge .next_ards
        mov edx, eax
    .next_ards:
loop .find_max_mem_area
jmp .mem_get_ok         ; 内存容量成功取得

; int 0x15 : 0xe801
.e280_failed_so_try_e801:
mov ax, 0xe801
int 0x15
jc .e801_failed_so_try_88

; 返回值 ax = cx = 低 16MB 大小（单位：1KB）
; 返回值 bx = dx = 16MB~4GB 大小（单位：64KB）
; 先算 16MB 以下的内存
mov cx, 1024        ; (dx, ax) = ax * 1024
mul cx
; 64KB = 2^16 byte
shl edx, 16         ; edx = (dx << 16) | ax = (dx, ax)
and eax, 0xFFFF
or  edx, eax
add edx, 0x10_0000  ; ax 中总会缺少 1MB
mov esi, edx        ; 把 edx 备份到 esi
; 处理 64KB 以上的内存
xor eax, eax
mov ax, bx
mov ecx, 0x10000    ; (edx, eax) = 64KB * eax
mul ecx
; 这里断言高 32 位为 0，因为使用了 32 位地址线
add esi, eax        ; 保存的结果 esi + 乘法结果低 32 位 eax
mov edx, esi
jmp .mem_get_ok

; int 0x15 : 0x88
.e801_failed_so_try_88:
mov ah, 0x88
int 0x15
; 返回值 ax = 内存容量（单位：KB）
jc .error_halt
and eax, 0xFFFF

mov cx, 1024        ; (dx, ax) = ax * 1024
mul cx
shl edx, 16         ; edx = (dx, ax)
or  edx, eax
add edx, 0x10_0000  ; 补回最初的 1MB
jmp .mem_get_ok

.error_halt:
; 打印失败信息
mov bx, failure
mov ax, failure_len
mov ch, red_black_light
mov dx, byte_per_line * 4
call print_string_m_16

jmp $


; 成功测试内存大小
.mem_get_ok:
mov [total_mem_bytes], edx
; 打印提示信息
mov bx, success
mov ax, success_len
mov ch, green_black_light
mov dx, byte_per_line * 4
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
mov dx, byte_per_line * 5
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

mov byte [gs:byte_per_line * 6], 'P'


; 准备开启分页
; 创建页目录表，初始化页内存映射
call setup_page

; 更新 GDT 中的地址，使之指向内核的虚拟地址
sgdt [gdt_ptr]
mov ebx, [gdt_ptr + 2]  ; ebx = gdt_base_addr
or  dword [ebx + 3 * 8 + 4], 0xc000_0000    ; 第 3 个描述符，高 4 字节
add dword [gdt_ptr + 2], 0xc000_0000
; 更新栈指针
add esp, 0xc000_0000

; 页目录地址赋值给 cr3
mov eax, page_dir_table_pos
mov cr3, eax

; 打开 cr0 的 PG 位（31 位）
mov eax, cr0
or  eax, (1 << 31)
mov cr0, eax

; 重新加载 GDT
lgdt [gdt_ptr]

; 写入 V 指示成功开启分页，使用虚拟地址
mov byte [gs:byte_per_line * 6 + 2], 'V'


; 在此自旋等待
jmp $


; 函数定义区
%include "printer.inc"


[bits 32]
; 创建页目录和页表
setup_page:
; 页目录占用的空间需要清空
mov ecx, 4096
mov esi, 0
.clear_page_dir:
    mov byte [page_dir_table_pos + esi], 0
    inc esi
loop .clear_page_dir

; 创建页目录表项（PDE，Page Directory Entry）
.create_pde:
mov eax, page_dir_table_pos
add eax, 0x1000     ; eax = 第一个页表的位置
mov ebx, eax        ; 为 .create_pte 准备，ebx 为基址
or  eax, pg_us_u | pg_rw_w | pg_p
; 0xc000_0000~0xffff_ffff 的虚拟地址空间属于内核
mov [page_dir_table_pos + 0x0], eax
mov [page_dir_table_pos + 0xc00], eax
; 0x0~0xbfff_ffff 的虚拟地址空间属于用户进程
; 设置最后一个目录表项为目录表本身的位置
sub eax, 0x1000     ; eax = 目录表本身的位置
mov [page_dir_table_pos + 4092], eax

; 下面创建页目录表项
mov ecx, 256        ; 1M / (4k/页) = 256页
mov esi, 0
mov edx, pg_us_u | pg_rw_w | pg_p
.create_pte:
    mov [ebx + esi * 4], edx
    add edx, 4096
    inc esi
loop .create_pte

; 创建内核的其他页表的 PDE
mov eax, page_dir_table_pos
add eax, 0x2000
or  eax, pg_us_u | pg_rw_w | pg_p
mov ebx, page_dir_table_pos
mov ecx, 254
mov esi, 769
.create_kernel_pde:
    mov [ebx + esi * 4], eax
    inc esi
    add eax, 0x1000
loop .create_kernel_pde
ret


; 数据区
prompt      db  "Loader Successfully Loaded. Entering Real Mode..."
prompt_len  equ $ - prompt

gdt_msg     db  "GDT Prepared. All Segments Ready."
gdt_msg_len equ $ - gdt_msg

mem_msg     db  "Testing Memory..."
mem_msg_len equ $ - mem_msg

failure     db  "Failed."
failure_len equ $ - failure

success     db  "Succeeded."
success_len equ $ - success
