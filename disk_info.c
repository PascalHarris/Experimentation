#include <stdio.h>
#include <sys/statvfs.h>

typedef struct _diskInfo
{
    unsigned long size;
    unsigned long used;
    unsigned long free;
    unsigned long blockSize;
    unsigned long blocks;
} diskInfo;

diskInfo diskUsage(char * path,unsigned int function)
{
    struct statvfs buf;
    diskInfo disk;
    unsigned long freeblks;
    int ret;
    
    ret = statvfs(path,&buf);
    disk.blockSize = buf.f_frsize;
    disk.blocks = buf.f_blocks;
    freeblks = buf.f_bfree;
    disk.size = disk.blockSize * disk.blocks;
    disk.free = disk.blockSize * freeblks;
    disk.used = disk.size - disk.free;
    
    return disk;
}

int main(int argc, char *argv[]) {
    diskInfo test = diskUsage("/", 9);
    printf("%ld/%ld",test.used,test.size);
}