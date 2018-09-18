/* 打印字符属性(K：闪烁，RGB：背景，I：亮度，RGB：前景) */
green_red_blink     = 0b10100100    # 绿底红字，闪烁
blue_black_light    = 0b00001001    # 黑底蓝字，亮度加强
cyan_black_light    = 0b00001011    # 黑底青字，亮度加强
green_black_light   = 0b00001010    # 黑底绿字，亮度加强
red_black_light     = 0b00001100    # 黑底红字，亮度加强
white_black_light   = 0b00001111    # 黑底白字, 亮度加强
white_black         = 0b00000111    # 黑底白字
default_color       = white_black

/* 函数向前引用声明 */
.extern print_string_m_16
.extern set_curser_m_16
