#include <fstream>
#include <iostream>
#include <string>

#define red(x) "\033[31;1m" x "\033[0m"
#define err red("error")

int main(int argc, char* argv[])
{
    if (argc < 3)
    {
        std::cerr << err ": No input file or no output file specified." << std::endl;
        std::cout << "Usage: sign_mbr <in> <out>" << std::endl;
        return 1;
    }

    std::string file_in_name{argv[1]};
    std::string file_out_name{argv[2]};
    std::cout << "Trying to sign file \"" << file_in_name << "\" as a boot sector." << std::endl;

    std::ifstream in{file_in_name, std::ios::in | std::ios::binary};
    std::ofstream out{file_out_name, std::ios::out | std::ios::binary};

    int cnt{0};
    auto c = in.get();
    while (!in.eof())
    {
        ++cnt;
        if (cnt > 510)
        {
            std::cerr << err ": input file is too large." << std::endl;
            return 1;
        }
        out.put(c);
        c = in.get();
    }

    std::cout << "File size: " << cnt << " bytes. ";

    for (; cnt < 510; ++cnt)
        out.put(0);

    out.put(0x55);
    out.put(0xaa);

    std::cout << "Succeeded!" << std::endl;

    return 0;
}
