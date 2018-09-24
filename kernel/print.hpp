#pragma once
#include "common.hpp"

namespace video
{
// K：闪烁，RGB：背景，I：亮度，RGB：前景
class colour
{
public:
    enum Style : uint8_t
    {
        Intensive = 0x08,
        Blink     = 0x80
    };
    enum Colour : uint8_t
    {
        Red     = 0x04,
        Green   = 0x02,
        Blue    = 0x01,
        Cyan    = Blue | Green,
        Magenta = Blue | Red,
        Yellow  = Red | Green
    };
    constexpr colour() = default;
    constexpr colour(uint8_t fore, uint8_t back, bool strong = false, bool blink = false)
        : val{make_colour(fore, back, strong, blink)}
    {}
    static constexpr uint8_t make_colour(
        uint8_t fore,
        uint8_t back,
        bool strong = false,
        bool blink  = false)
    {
        uint8_t res{0};
        res |= fore;
        res |= back << 4;
        if (strong)
            res |= Intensive;
        if (blink)
            res |= Blink;
        return res;
    }
    constexpr colour fore(uint8_t c) const { return colour((val & 0xf8) | (c & 0x07)); }
    constexpr colour back(uint8_t c) const { return colour((val & 0x8f) | ((c & 0x07) << 4)); }
    constexpr colour strong() const { return colour(val | Intensive); }
    constexpr colour blink() const { return colour(val | Blink); }

    operator uint8_t() const { return val; }
    const uint8_t& raw_value() const { return val; }

private:
    constexpr colour(uint8_t value)
        : val{value}
    {}
    uint8_t val{0x07};
};

inline constexpr colour default_colour;

int get_cursor_pos();
void set_cursor_pos(int pos);
void put_char(char ch, colour col);
void put_string(const char str[], colour col);
void roll_screen(int lines = 1);

namespace raw
{
    void write_char_at(char ch, colour col, int pos);
    void handle_char(char ch, colour col, int& pos);
    void roll_screen(int lines = 1);
} // namespace raw

} // namespace video
