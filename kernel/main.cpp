#include "print.hpp"

int main()
{
    video::put_string(
        "[KERNEL]:\tHello, Kernel!\n",
        video::colour().fore(video::colour::Cyan));

    while (true)
        ;
    return 0;
}
