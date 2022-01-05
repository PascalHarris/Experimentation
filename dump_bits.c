#include <stdio.h>

void dumpbits(char byte) {
    char finalhash[13]={'\0'};
    char hexval[16] = {'0', '1', '2', '3', '4', '5', '6',
        '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'};
    unsigned char mask_table[] = { 0x01, 0x02, 0x04,
        0x08, 0x10, 0x20, 0x40, 0x80 };
    
    finalhash[0] = hexval[((byte >> 4) & 0xF)];
    finalhash[1] = hexval[byte & 0x0F];
    finalhash[2] = ' ';
    for (int iterator=0;iterator<8;iterator++) {
        if (( byte & mask_table[iterator] ) != 0x00) {
            finalhash[3+iterator]='1';
        } else {
            finalhash[3+iterator]='0';
        }
    }
    printf("%s ",finalhash);
}

int main(int argc, char *argv[]) {
    dumpbits('c');
}