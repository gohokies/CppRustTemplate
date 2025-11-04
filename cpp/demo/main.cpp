#include <iostream>
#include <string>
#include <stdint.h>

extern "C" {
    uint64_t add(uint64_t a, uint64_t b);
}

int main()
{    
    std::cout << "Nice to meet you! " << add(3,4) << std::endl;    
    return 0;
}