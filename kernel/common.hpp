#pragma once

inline namespace common
{
using uint8_t  = unsigned char;
using uint16_t = unsigned short;
using uint32_t = unsigned int;
using uint64_t = unsigned long long;

using int8_t  = char;
using int16_t = short;
using int32_t = int;
using int64_t = long long;

using size_t    = uint32_t;
using ptrdiff_t = int32_t;

template<typename T>
class span
{
public:
    constexpr span(T* bs, size_t len)
        : base{bs}
        , length{len}
    {}

    T* begin() { return base; }
    T* end() { return base + length; }
    const T* begin() const { return base; }
    const T* end() const { return base + length; }

private:
    T* base;
    size_t length;
};
} // namespace common
