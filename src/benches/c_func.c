#include "C:\\Users\\Administrator\\OneDrive\\krul\\src\\benches\\c_func.h"
#include <stdint.h>

bool diff(const int16_t* p1, const int16_t* p2, int count) {
    int count64 = count / 4;                    // number of four x 16-bit ints in uint64_t
    if (count64) {
        uint64_t* p1_64 = p1;        // cast to 64-bit pointers
        uint64_t* p2_64 = p2;
        while (count64--)                       // loop through all 64-bit blocks
            if (*p1_64++ != *p2_64++)
                return true;                    // found a difference
        p1 = p1_64;                   // cast back to 16-bit pointer for residue
        p2 = p2_64;
    }

    int count16 = count % 4;                    // residue
    if (count16) {
        while (count16--)                       // loop through last 16-bit blocks
            if (*p1++ != *p2++)
                return true;                    // found a difference
    }
    return false;                               // found no single difference
}