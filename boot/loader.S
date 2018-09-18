.code16
.include "boot.inc"
.include "bits16/printer.inc"
.include "bits32/printer.inc"
.include "bits32/read_disk.inc"

.global loader_start

/* 加载器的栈顶，栈向代码所在的相反方向生长 */
loader_stack_top    = loader_base_addr

/* 在 MBR 中直接跳转到 loader_start（偏移量 0x300） */

gdt_base:
    .long  0x00000000         # 第 1 个描述符不可用，置空
    .long  0x00000000
code_desc:
    .long  desc_low4
    .long  desc_code_high4
data_stack_desc:
    .long  desc_low4
    .long  desc_data_high4
video_desc:
    .long  desc_video_low4
    .long  desc_video_high4
gdt_end:
gdt_size    = gdt_end - gdt_base
gdt_limit   = gdt_size - 1
/* 这里预留 60 个描述符 */
.rept 60
    .quad 0
.endr

/* 注意：这里的对齐地址必须固定为 0xb00 = 0x900 + 0x200 */
/* 因为随后在内核中将会引用此地址 */
/* 前面共有 64（0x40）个 GDT 表项（共 0x200 字节） */

/* 此处是内存大小存储的位置 */
total_mem_bytes:
    .long 0

selector_code   = (1 << 3) | ti_gdt | rpl_0
selector_data   = (2 << 3) | ti_gdt | rpl_0
selector_video  = (3 << 3) | ti_gdt | rpl_0

gdt_ptr:
    .word  gdt_limit
    .long  gdt_base

/* 与内存检测 ARDS 结构相关的存储位置 */
ards_buf:
    .rept 244
        .byte 0
    .endr
ards_nr:
    .word 0

loader_start:

/* 打印欢迎字符串 */
/* 通过调用函数 print_string */
mov $prompt, %bx
mov $prompt_len, %ax
mov $blue_black_light, %ch
mov $byte_per_line * 2, %dx
call print_string_m_16

# 准备开始测试内存大小
# 先打印提示信息
movw $mem_msg, %bx
movw $mem_msg_len, %ax
movb $green_black_light, %ch
movw $byte_per_line * 3, %dx
call print_string_m_16

/* 设置光标位置 */
mov $0x0004, %bx
call set_curser_m_16

# 尝试使用 BIOS 中断获取内存大小
# int 0x15 : 0xe820
xorl %ebx,%ebx          # 第一次调用 ebx 置空，后续调用 ebx 由 BIOS 管理
movl $0x534d4150, %edx  # "SMAP" = 0x534d4150
movw $ards_buf, %di
loader_start.e280_mem_get_loop: 
    movl $0xe820, %eax  # 每次执行中断，eax 被更新为 "SMAP"
    movl $20, %ecx      # ARDS 地址描述符为 20 字节
    int $0x15

    jc loader_start.e280_failed_so_try_e801 # carry = 1 意味着中断执行失败

    addw %cx, %di       # mov ecx, 20 后 cx = 20，此处使 di 指向下一个 ARDS 结构
    incw ards_nr        # 使计数器自增
    cmpl $0, %ebx       # cf == 0 && ebx == 0 说明 ARDS 全部返回成功

jnz loader_start.e280_mem_get_loop

movw ards_nr, %cx
movl $ards_buf, %ebx
xorl %edx,%edx
loader_start.find_max_mem_area:  # 这里断言最大那块内存系统可使用
    movl (%ebx), %eax   # ARDS::base_addr_low
    addl 8(%ebx), %eax  # ARDS::length_low
    addl $20, %ebx
    cmpl %eax, %edx     # edx = max(edx, eax)
    jge loader_start.next_ards
        movl %eax,%edx
    loader_start.next_ards: 
loop loader_start.find_max_mem_area
jmp loader_start.mem_get_ok # 内存容量成功取得

# int 0x15 : 0xe801
loader_start.e280_failed_so_try_e801: 
movw $0xe801, %ax
int $0x15
jc loader_start.e801_failed_so_try_88

# 返回值 ax = cx = 低 16MB 大小（单位：1KB）
# 返回值 bx = dx = 16MB~4GB 大小（单位：64KB）
# 先算 16MB 以下的内存
movw $1024, %cx     # (dx, ax) = ax * 1024
mulw %cx
# 64KB = 2^16 byte
shll $16, %edx      # edx = (dx << 16) | ax = (dx, ax)
andl $0xFFFF,%eax
orl %eax,%edx
addl $0x100000, %edx    # ax 中总会缺少 1MB
movl %edx, %esi         # 把 edx 备份到 esi
# 处理 64KB 以上的内存
xorl %eax, %eax
movw %bx, %ax
movl $0x10000, %ecx # (edx, eax) = 64KB * eax
mull %ecx
# 这里断言高 32 位为 0，因为使用了 32 位地址线
addl %eax, %esi     # 保存的结果 esi + 乘法结果低 32 位 eax
movl %esi, %edx
jmp loader_start.mem_get_ok

# int 0x15 : 0x88
loader_start.e801_failed_so_try_88: 
movb $0x88, %ah
int $0x15
# 返回值 ax = 内存容量（单位：KB）
jc loader_start.error_halt
andl $0xFFFF, %eax

movw $1024, %cx     # (dx, ax) = ax * 1024
mulw %cx
shll $16, %edx      # edx = (dx, ax)
orl %eax, %edx
addl $0x100000, %edx    # 补回最初的 1MB
jmp loader_start.mem_get_ok

loader_start.error_halt: 
# 打印失败信息
movw $failure, %bx
movw $failure_len, %ax
movb $red_black_light, %ch
movw $byte_per_line * 4, %dx
call print_string_m_16

/* 设置光标位置 */
mov $0x0005, %bx
call set_curser_m_16

loader_start.deadloop:
    jmp loader_start.deadloop

# 成功测试内存大小
loader_start.mem_get_ok: 
movl %edx, total_mem_bytes
# 打印提示信息
movw $success, %bx
movw $success_len, %ax
movb $green_black_light, %ch
movw $byte_per_line * 4, %dx
call print_string_m_16

/* 设置光标位置 */
mov $0x0005, %bx
call set_curser_m_16


# 准备进入保护模式
# 打开 A20
inb  $0x92, %al
orb  $0b00000010, %al
outb %al, $0x92

# 加载 GDT
lgdt gdt_ptr

# 调试信息
# 报告 GDT 已经加载完成
movw $gdt_msg, %bx
movw $gdt_msg_len, %ax
movb $blue_black_light, %ch
movw $byte_per_line * 5, %dx
call print_string_m_16

/* 设置光标位置 */
mov $0x0006, %bx
call set_curser_m_16

# cr0 第 0 位设置为 1
movl %cr0, %eax
orl  $0x00000001, %eax
movl %eax, %cr0

# 刷新流水线
ljmp $selector_code, $p_mode_start

.code32
p_mode_start: 

movw $selector_data, %ax
movw %ax,%ds
movw %ax,%es
movw %ax,%ss
movl $loader_stack_top, %esp
movw $selector_video, %ax
movw %ax,%gs

# 报告已经进入保护模式
movl $pmode_msg, %ebx
movl $pmode_msg_len, %eax
movb $default_color, %ch
movl $byte_per_line * 6, %edx
call print_string_m_32

# 加载内核到内存指定位置
mov $kernel_start_sector, %eax
mov $kernel_base_addr, %ebx
mov $200, %ecx
call read_disk_m_32


# 准备开启分页
# 创建页目录表，初始化页内存映射
call setup_page

# 更新 GDT 中的地址，使之指向内核的虚拟地址
sgdt gdt_ptr
mov  gdt_ptr + 2, %ebx
orl  $0xc0000000, 28(%ebx)  # 28 = 3 * 8 + 4
addl $0xc0000000, gdt_ptr + 2
# 更新栈指针
addl $0xc0000000, %esp

# 页目录地址赋值给 cr3
movl $page_dir_table_pos, %eax
movl %eax, %cr3

# 打开 cr0 的 PG 位（31 位）
movl %cr0, %eax
orl  $1 << 31, %eax
movl %eax, %cr0

# 重新加载 GDT
lgdt gdt_ptr


# 报告已经成功开启分页，使用虚拟地址
movl $vaddr_msg, %ebx
movl $vaddr_msg_len, %eax
movb $default_color, %ch
movl $byte_per_line * 7, %edx
call print_string_m_32

/* 设置光标位置 */
mov $0x0008, %bx
call set_curser_m_32


/* 再次刷新流水线 */
ljmp $selector_code, $enter_kernel

enter_kernel:
call init_kernel
mov $0xc009f000, %esp
jmp kernel_entry_point


.deadloop:
    jmp .deadloop


/* 函数定义区 */
.code32
/* 创建页目录和页表 */
setup_page: 
# 页目录占用的空间需要清空
movl $4096,%ecx
movl $0,%esi
setup_page.clear_page_dir: 
    movb $0, page_dir_table_pos(%esi)
    incl %esi
loop setup_page.clear_page_dir

# 创建页目录表项（PDE，Page Directory Entry）
setup_page.create_pde: 
movl $page_dir_table_pos, %eax
addl $0x1000,%eax   # eax = 第一个页表的位置
movl %eax,%ebx      # 为 .create_pte 准备，ebx 为基址
or  $pg_us_u | pg_rw_w | pg_p, %eax
# 0xc000_0000~0xffff_ffff 的虚拟地址空间属于内核
mov %eax, page_dir_table_pos + 0x0
mov %eax, page_dir_table_pos + 0xc00
# 0x0~0xbfff_ffff 的虚拟地址空间属于用户进程
# 设置最后一个目录表项为目录表本身的位置
subl $0x1000,%eax   # eax = 目录表本身的位置
mov %eax, page_dir_table_pos + 4092

# 下面创建页目录表项
movl $256,%ecx      # 1M / (4k/页) = 256页
movl $0,%esi
mov $pg_us_u | pg_rw_w | pg_p, %edx
setup_page.create_pte: 
    movl %edx,(%ebx,%esi,4)
    addl $4096,%edx
    incl %esi
loop setup_page.create_pte

# 创建内核的其他页表的 PDE
movl $page_dir_table_pos, %eax
addl $0x2000,%eax
or  $pg_us_u | pg_rw_w | pg_p, %eax
movl $page_dir_table_pos, %ebx
movl $254,%ecx
movl $769,%esi
setup_page.create_kernel_pde: 
    movl %eax,(%ebx,%esi,4)
    incl %esi
    addl $0x1000,%eax
loop setup_page.create_kernel_pde
ret

/* 初始化内核 */
init_kernel:
xor %eax, %eax
xor %ebx, %ebx
xor %ecx, %ecx
xor %edx, %edx

mov kernel_base_addr + 42, %dx  # e_phentsize = Program Header 大小
mov kernel_base_addr + 28, %ebx # e_phoff = Program Header 尺寸
add $kernel_base_addr, %ebx     # 相对地址计算绝对地址
mov kernel_base_addr + 44, %cx  # e_phnum = Program Header 总数量

.each_segment:
    cmp $pt_null, 0(%ebx)
    je .ptnull
        pushl 16(%ebx)      # p_filesz 作为函数参数 size :: Int
        mov 4(%ebx), %eax   # p_offset
        add $kernel_base_addr, %eax
        pushl %eax          # 作为函数参数 src :: Addr
        pushl 8(%ebx)       # p_vaddr 作为函数参数 dst :: Addr
        call mem_copy
        add $12, %esp       # 平衡栈
    .ptnull:
    add %edx, %ebx          # ebx += e_phentsize 指向下一个 section
loop .each_segment
ret

/* 拷贝内存数据 */
mem_copy:
cld                 # 设置 movsb 时 esi 和 edi 都自动自增
pushl %ebp
mov %esp, %ebp
push %ecx

mov 8(%ebp), %edi   # edi = dst
mov 12(%ebp), %esi  # esi = src
mov 16(%ebp), %ecx  # ecx = size
rep movsb           # 逐字节从 %ds : %esi 指示的地址复制到 %es : %edi 处

pop %ecx
pop %ebp
ret


/* 数据区 */
prompt:
    .ascii "Loader Successfully Loaded. Initialising..."
prompt_end:
prompt_len  = prompt_end - prompt

gdt_msg:
    .ascii "GDT Prepared. All Segments Ready."
gdt_msg_end:
gdt_msg_len = gdt_msg_end - gdt_msg

mem_msg:
    .ascii "Testing Memory..."
mem_msg_end:
mem_msg_len = mem_msg_end - mem_msg

failure:
    .ascii "Failed."
failure_end:
failure_len = failure_end - failure

success:
    .ascii "Succeeded."
success_end:
success_len = success_end - success

pmode_msg:
    .ascii "Protected Mode Entered."
pmode_msg_end:
pmode_msg_len = pmode_msg_end - pmode_msg

vaddr_msg:
    .ascii "Using Virtual Address."
vaddr_msg_end:
vaddr_msg_len = vaddr_msg_end - vaddr_msg
