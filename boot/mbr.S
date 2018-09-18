/* 代码重定位的首地址将会在链接时被指定为 0x7c00 */
/* 这里指定使用 16 位代码生成 */
.code16

/* 所有的配置信息存储在 boot.inc 中 */
.include "boot.inc"

/* 外部函数信息 */
.include "bits16/printer.inc"
.include "bits16/read_disk.inc"

.global _bootstart

_bootstart:

/* 清空相关寄存器 */
mov %cs, %ax
mov %ax, %ds
mov %ax, %es
mov %ax, %ss
mov %ax, %fs

mov $0x7c00, %sp

/* 清空屏幕，即上卷全部行 */
/* int 0x10 : 0x06 上卷窗口 */
mov $0x0600, %ax    # ax = (ah = 0x06 功能号, al = 0 上卷行数，表示全部)
mov $0x0700, %bx    # bx = (bh = 0x07 上卷行属性, bl = 0)
/* VGA 模式下屏幕尺寸为 25 行，80 列 */
mov $0, %cx         # cx = (ch, cl) = (0, 0) 左上角坐标
mov $0x184f, %dx    # dx = (dh, dl) = (24, 79) 右下角坐标
int $0x10

/* 将 gs 寄存器设置为显存的地址 */
mov $0xb800, %ax
mov %ax, %gs

/* 打印字符串 */
mov $loaded, %bx
mov $loaded_len, %ax
mov $default_color, %ch
xor %dx, %dx
call print_string_m_16

/* 设置光标位置 */
mov $0x0001, %bx
call set_curser_m_16

/* 加载磁盘内容 */
mov $loader_start_sector, %eax  # 起始扇区 LBA 地址
mov $loader_base_addr, %bx      # 写入地址
mov $4, %cx                     # 这里先只读入 4 个扇区
call read_disk_m_16


/* 打印读取成功字符串 */
/* 通过调用函数 print_string */
mov $disk, %bx
mov $disk_len, %ax
mov $default_color, %ch
mov $byte_per_line, %dx
call print_string_m_16

/* 设置光标位置 */
mov $0x0002, %bx
call set_curser_m_16

/* 直接跳转到 Loader 的第一条指令处 */
jmp loader_base_addr + 0x300


/* 以下为数据和全局函数区域 */
loaded:
    .ascii "Boot Sector Successfully Loaded."
loaded_end:
loaded_len  = loaded_end - loaded

disk:
    .ascii "Disk Visit Succeeded, Preparing Loader..."
disk_end:
disk_len    = disk_end - disk

/* 结尾的启动区签名由 helper/sign_mbr 完成 */
