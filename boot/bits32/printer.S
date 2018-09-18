.code32
.global print_string_m_32
.global set_curser_m_32

vga_width  = 80

print_string_m_32:
    /* 函数 print_string（32位） 
    * 参数 ebx = 字符串地址
    * 参数 eax = 字符串长度
    * 参数 ch = 字符属性
    * 参数 edx = 起始写入的相对位置
    * Pre: gs = 显存段地址 && 字符串长度 >= 1
    */
    xor %esi, %esi
    .write_byte:
        mov (%ebx, %esi), %cl
        mov %cl, %gs:(%edx)      # 写入字符本身
        inc %edx
        mov %ch, %gs:(%edx)
        inc %edx
        inc %esi
    cmp %eax, %esi
    jne .write_byte
    ret
    /* 没有返回值 */

set_curser_m_32:
    /* 函数 set_curser（32位） 
    * 参数 bx = (bh, bl) = (行位置, 列位置)
    */
    mov %bx, %cx
    and $0xff, %cx
    mov $vga_width, %al
    mul %cl                 # ax = $vga_width * bl
    mov %bx, %cx
    shr $8, %cx             # cx = (0, bh)
    add %ax, %cx            # cx = ax + cx

    mov $0x3d4, %dx
    mov $0x0f, %al
    out %al, %dx

    mov $0x3d5, %dx
    mov %cl, %al
    out %al, %dx

    mov $0x3d4, %dx
    mov $0x0e, %al
    out %al, %dx

    mov $0x3d5, %dx
    mov %ch, %al
    out %al, %dx

    ret
    /* 没有返回值 */
