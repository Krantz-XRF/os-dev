section mbr vstart=0x7c00

%include "boot.inc"

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
mov bx, success
mov ax, success_len
mov ch, blue_black_light
xor dx, dx
call print_string_m_16


; 加载磁盘内容
mov eax, loader_start_sector    ; 起始扇区 LBA 地址
mov bx, loader_base_addr        ; 写入地址
mov cx, 4                       ; 这里先只读入 4 个扇区
call read_disk_m_16


; 打印读取成功字符串
; 通过调用函数 print_string
mov bx, disk
mov ax, disk_len
mov ch, blue_black_light
mov dx, byte_per_line
call print_string_m_16


jmp loader_base_addr


; 函数定义区
; 打印消息到屏幕
%include "printer.inc"


; 读取硬盘的 n 个扇区（在 16 位模式下）
read_disk_m_16:
    ; 参数 eax = LBA 扇区号
    ; 参数 bx = 数据写入的目的地址
    ; 参数 cx = 读入的扇区数
    mov esi, eax
    mov di, cx      ; 备份 eax 和 cx

    ; (1) 设置读取的扇区数目
    mov dx, 0x01f2
    mov al, cl
    out dx, al
    ; 从 esi 中恢复 eax
    mov eax, esi

    ; (2) 按顺序将 LBA 地址存入 0x01f3 ~ 0x01f6
    ; LBA 7~0 位写入端口 1f3h
    mov dx, 0x01f3
    out dx, al
    ; LBA 15～8 位写入端口 1f4h
    mov cl, 8
    shr eax, cl
    mov dx, 0x01f4
    out dx, al
    ; LBA 23~16 位写入端口 1f5h
    shr eax, cl
    mov dx, 0x01f5
    out dx, al
    ; LBA 剩余位加上标志信息写入端口 1f6h
    shr eax, cl
    and al, 0x0f    ; 取出 27~24 位
    or  al, 0xe0    ; 设置 31~28 位为标志 0b1110 表示 LBA 模式
    mov dx, 0x01f6
    out dx, al

    ; (3) 向 1f7h 中写入读取命令
    mov dx, 0x01f7
    mov al, 0x20
    out dx, al

    ; (4) 检测磁盘状态
    .not_ready:
        nop
        in  al, dx
        and al, 0x88    ; 仅保留第 4 位（就绪）和第 8 位（硬盘忙）
    cmp al, 0x08
    jnz .not_ready

    ; (5) 从 1f0h 端口读入数据
    ; 先求出读取次数 = (di 扇区数) * (512 字节/扇区) / (2 字节/次) = 256 * di (次)
    mov ax, di      ; di = 备份的 cx 寄存器的值 = 要读取的扇区数
    mov dx, 256
    mul dx          ; mul dx 即 ax = al * dx，这里断言高 16 位为 0，因为要读的扇区数很少
    mov cx, ax      ; 乘法结果存入 cx
    mov dx, 0x1f0
    .continue_to_read:
        in  ax, dx      ; 读取 2 个字节到 ax
        mov [bx], ax    ; 写入目的内存地址
        add bx, 2       ; 目的地址向前移动
    loop .continue_to_read
    ret


; 数据区
success     db  "MBR Successfully Loaded."
success_len equ $ - success          ; 字符串的结尾不包含一个 0

disk        db  "Disk Visit Succeeded, Preparing Loader..."
disk_len    equ $ - disk

; MBR 签名 0xaa55
times (510 - ($ - $$)) db 0         ; 填充 0 直到 510 字节
db 0x55, 0xaa
