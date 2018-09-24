#include "print.hpp"

constexpr unsigned selector_video = 0x18;
constexpr unsigned screen_width   = 80;
constexpr unsigned screen_height  = 25;
constexpr unsigned tab_width      = 4;

constexpr unsigned screen_max_pos = screen_height * screen_width;

int video::get_cursor_pos()
{
    int pos{0};
    asm(R"(
        mov $0x3d4, %%dx
        mov $0x0e, %%al
        out %%al, %%dx
        mov $0x3d5, %%dx
        in  %%dx, %%al
        mov %%al, %%ah

        mov $0x3d4, %%dx
        mov $0x0f, %%al
        out %%al, %%dx
        mov $0x3d5, %%dx
        in  %%dx, %%al
    )"
        : "=a"(pos)::"dx");
    return pos;
}

void video::set_cursor_pos(int pos)
{
    asm(R"(
        mov $0x3d4, %%dx
        mov $0x0e, %%al
        out %%al, %%dx
        mov $0x3d5, %%dx
        mov %%bh, %%al
        out %%al, %%dx
        mov %%al, %%ah

        mov $0x3d4, %%dx
        mov $0x0f, %%al
        out %%al, %%dx
        mov $0x3d5, %%dx
        mov %%bl, %%al
        out %%al, %%dx
    )"
        :
        : "b"(pos)
        : "dx");
}

void video::raw::write_char_at(char ch, colour col, int pos)
{
    asm(R"(
        mov %[selector_video], %%ax
        mov %%ax, %%gs
        shl $1, %%bx
        mov %[ch], %%al
        mov %%al, %%gs:(%%bx)
        inc %%bx
        mov %[col], %%al
        mov %%al, %%gs:(%%bx)
    )"
        :
        : "b"(pos), [selector_video] "i"(selector_video), [ch] "m"(ch), [col] "m"(col.raw_value())
        : "ax");
}

void video::raw::handle_char(char ch, colour col, int& pos)
{
    int newpos{0};
    if (ch == '\n')
        newpos = (pos / screen_width + 1) * screen_width;
    else if (ch == '\t')
        newpos = (pos / tab_width + 1) * tab_width;
    else if (ch == '\r')
        pos = (pos / screen_width) * screen_width;
    else if (ch == '\b')
    {
        --pos;
        write_char_at('\0', default_colour, pos);
        return;
    }
    else
    {
        write_char_at(ch, col, pos);
        ++pos;
        if (pos >= screen_max_pos)
        {
            raw::roll_screen();
            pos -= screen_width;
        }
        return;
    }

    for (; pos < newpos; ++pos)
        write_char_at('\0', default_colour, pos);
    if (pos >= screen_max_pos)
    {
        raw::roll_screen();
        pos -= screen_width;
    }
}

void video::put_char(char ch, colour col)
{
    auto pos = get_cursor_pos();
    raw::handle_char(ch, col, pos);
    set_cursor_pos(pos);
}

void video::put_string(const char str[], colour col)
{
    auto pos = get_cursor_pos();
    while (*str != '\0')
    {
        raw::handle_char(*str, col, pos);
        ++str;
    }
    set_cursor_pos(pos);
}

void video::roll_screen(int lines /* = 1 */)
{
    raw::roll_screen(lines);
    auto pos = get_cursor_pos();
    pos -= lines * screen_width;
    set_cursor_pos(pos);
}

void video::raw::roll_screen(int lines /* = 1 */)
{
    if (screen_height < lines) return;
    int count = (screen_height - lines) * screen_width * 2 / 4;

    unsigned* dst = reinterpret_cast<unsigned*>(0xc00b8000);
    unsigned* src = dst + lines * screen_width * 2 / 4;

    for (; count != 0; --count, ++dst, ++src)
        *dst = *src;

    for (count = lines * screen_width * 2 / 4; count != 0; --count, ++dst)
        *dst = '\0';
}
