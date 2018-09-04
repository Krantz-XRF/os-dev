; 加载器、内核的地址信息
loader_base_addr        equ 0x900       ; 启动代码加载的目标地址
loader_start_sector     equ 0x2         ; LBA 地址：0 磁头 0 柱面 2 扇区

; 显示设备参数
byte_per_line           equ 160         ; 显示器每行字节数

; GDT 属性
desc_g_4k               equ 1 << 23         ; G 位（23），控制段粒度为 4K
desc_d_32               equ 1 << 22         ; D/B 位（22），设置指令、数据为 32 位
desc_l                  equ 0               ; L 位（21），指示 64 位代码段，不使用
desc_avl                equ 0               ; AVL位（20），硬件不使用这一位，置空

desc_limit_code2        equ 0b1111 << 16    ; 段界限字段（19~16 位）
desc_limit_data2        equ desc_limit_code2
desc_limit_video2       equ 0

desc_p                  equ 1 << 15         ; P 位（15），指示段存在于内存中

desc_dpl_0              equ 0 << 13         ; DPL 字段（14~13位），特权级别
desc_dpl_1              equ 1 << 13
desc_dpl_2              equ 2 << 13
desc_dpl_3              equ 3 << 13

desc_s_code             equ 1 << 12         ; S 位（12），指示是否是系统段
desc_s_data             equ desc_s_code
desc_s_sys              equ 0

; TYPE 字段（11~8），标记段属性 = (X, _, _, A)
; eXecutable 可执行；Accessed 已访问
; 访问标记由 CPU 设置，表示 CPU 是否访问过该段
; X = 1 代码段 => TYPE = (X, C, R, A)
;   Readable 可读；Conforming 一致性代码段
;   一致性标记表示作为转移的目标段时，服从转移前的特权级别
; X = 0 数据段 => TYPE = (X, W, E, A)
;   Writable 可写；Extend 扩展方向
;   扩展方向：0 表示向高地址扩展；1 表示向低地址扩展
desc_type_code          equ 0b1000 << 8     ; X
desc_type_data          equ 0b0010 << 8     ; E

; 描述符高 4 字节
; 这里省略了全部段基址位，因为使用平坦模式，它们都是 0
; 31~24 -> 段基址 31~24, 7~0 ~ 段基址 23~16
desc_high4_general      equ desc_g_4k | desc_d_32 | desc_l | desc_avl | desc_p | desc_dpl_0
desc_code_high4         equ desc_high4_general | desc_limit_code2 | desc_s_code | desc_type_code
desc_data_high4         equ desc_high4_general | desc_limit_data2 | desc_s_data | desc_type_data
desc_video_high4        equ desc_high4_general | desc_limit_video2 | desc_s_data | desc_type_data | 0xb

; 描述符低 4 字节
; 31~16 位：段基址 15~0
; 15~0 位：段界限 15~0
desc_low4               equ 0x0000_FFFF
desc_video_low4         equ 0x8000_0007     ; 段基址 0xb8000，段界限 7 * 4k = 0xbffff - 0xb8000

; 选择子属性
rpl_0                   equ 0               ; RPL 字段（1~0），请求特权级
rpl_1                   equ 1
rpl_2                   equ 2
rpl_3                   equ 3
ti_gdt                  equ 000b            ; TI 位（2），段描述符在 GDT 还是 LDT 中
ti_idt                  equ 100b
