.code32
.global read_disk_m_32

/* 这个函数与 16 位版本几乎完全相同，唯一区别在于使用了 %ebx 代替 %bx 增大寻址空间 */

read_disk_m_32:
    /* 函数 read_disk（32位）
    * 参数 eax = LBA 扇区号
    * 参数 ebx = 数据写入的目的地址
    * 参数 cx = 读入的扇区数 */
    mov %eax, %esi
    mov %cx, %di
    /* 备份 eax 和 cx */

    /* (1) 设置读取的扇区数目 */
    mov $0x01f2, %dx
    mov %cl, %al
    out %al, %dx
    /* 恢复 eax 的值 */
    mov %esi, %eax

    /* (2) 按顺序将 LBA 地址存入 0x01f3 ~ 0x01f6 */
    /* LBA 7~0 位写入端口 1f3h */
    mov $0x01f3, %dx
    out %al, %dx
    /* LBA 15～8 位写入端口 1f4h */
    mov $8, %cl
    shr %cl, %eax
    mov $0x01f4, %dx
    out %al, %dx
    /* LBA 23~16 位写入端口 1f5h */
    shr %cl, %eax
    mov $0x01f5, %dx
    out %al, %dx
    /* LBA 剩余位加上标志信息写入端口 1f6h */
    shr %cl, %eax
    and $0x0f, %al  # 取出 27~24 位
    or  $0xe0, %al  # 设置 31~28 位为标志 0b1110 表示 LBA 模式
    mov $0x01f6, %dx
    out %al, %dx

    /* (3) 向 1f7h 写入读取命令 */
    mov $0x01f7, %dx
    mov $0x20, %al
    out %al, %dx

    /* (4) 检测磁盘状态 */
    .not_ready:
        nop
        in  %dx, %al
        and $0x88, %al  # 仅保留第 4 位（就绪）和第 8 位（硬盘忙）
    cmp $0x08, %al
    jnz .not_ready

    /* (5) 从 1f0h 端口读入数据 */
    /* 先求出读取次数 = (di 扇区数) * (512 字节/扇区) / (2 字节/次) = 256 * di (次) */
    mov %di, %ax        # di = 备份的 cx 寄存器的值 = 要读取的扇区数
    mov $256, %dx
    mul %dx             # mul dx 即 ax = al * dx，这里断言高 16 位为 0，因为要读的扇区数很少
    mov %ax, %cx        # 乘法结果存入 cx
    mov $0x1f0, %dx
    .continue_to_read:
        in  %dx, %ax    # 读取 2 个字节到 ax
        mov %ax, (%ebx) # 写入目的内存地址
        add $2, %ebx    # 目的地址向前移动
    loop .continue_to_read
    ret
