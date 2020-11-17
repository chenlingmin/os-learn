#include "dir.h"
#include "stdint.h"
#include "inode.h"
#include "file.h"
#include "fs.h"
#include "stdio-kernel.h"
#include "global.h"
#include "debug.h"
#include "memory.h"
#include "string.h"
#include "interrupt.h"
#include "super_block.h"

struct dir root_dir;    // 根目录

/* 打开根目录 */
void open_root_dir(struct partition* part) {
    root_dir.inode = inode_open(part, part->sb->root_inode_no);
    root_dir.dir_pos = 0;
}

/* 在分区part上打开i结点为inode_no的目录并返回目录指针 */
struct dir* dir_open(struct partition* part, uint32_t inode_no) {
    struct dir* pdir = (struct dir*)sys_malloc(sizeof(struct dir));
    pdir->inode = inode_open(part, inode_no);
    pdir->dir_pos = 0;
    return pdir;
}

/* 在part分区内的pdir目录内寻找名为name的文件或目录,
 * 找到后返回true并将其目录项存入dir_e,否则返回false */
bool search_dir_entry(
    struct partition* part, struct dir* pdir,
    const char* name, struct dir_entry* dir_e) {
    uint32_t block_cnt = 140;   // 12个直接块+128个一级间接块=140块

    /* 12个直接块大小+128个间接块,共560字节 */
    uint32_t* all_blocks = (uint32_t*)sys_malloc(48 + 512);
    if (all_blocks == NULL) {
        printk("search_dir_entry: sys_malloc for all_blocks failed");
        return false;
    }

    uint32_t block_idx = 0;
    while (block_idx < 12) {
        all_blocks[block_idx] = pdir->inode->i_sectors[block_idx];
        block_idx++;
    }
    block_idx = 0;
    if (pdir->inode->i_sectors[12] != 0) {  // 若含有一级间接块表
        ide_read(part->my_disk, pdir->inode->i_sectors[12], all_blocks + 12, 1);
    }
    /* 至此,all_blocks存储的是该文件或目录的所有扇区地址 */

    /* 写目录项的时候已保证目录项不跨扇区,
     * 这样读目录项时容易处理, 只申请容纳1个扇区的内存 */
    uint8_t* buf = (uint8_t*)sys_malloc(SECTOR_SIZE);
    struct dir_entry* p_de = (struct dir_entry*)buf;    // p_de为指向目录项的指针,值为buf起始地址
    uint32_t dir_entry_size = part->sb->dir_entry_size;
    uint32_t dir_entry_cnt = SECTOR_SIZE / dir_entry_size;  // 1扇区内可容纳的目录项个数

    /* 开始在所有块中查找目录项 */
    while (block_idx < block_cnt) {
        /* 块地址为0时表示该块中无数据,继续在其它块中找 */
        if (all_blocks[block_idx] == 0) {
            block_idx++;
            continue;
        }
        ide_read(part->my_disk, all_blocks[block_idx], buf, 1);

        uint32_t dir_entry_idx = 0;
        /* 遍历扇区中所有目录项 */
        while (dir_entry_idx < dir_entry_cnt) {
            /* 若找到了,就直接复制整个目录项 */
            if (!strcmp(p_de->filename, name)) {
                memcpy(dir_e, p_de, dir_entry_size);
                sys_free(buf);
                sys_free(all_blocks);
                return true;
            }
            dir_entry_idx++;
            p_de++;
        }
        block_idx++;
        p_de = (struct dir_entry*)buf;  // 此时p_de已经指向扇区内最后一个完整目录项了,需要恢复p_de指向为buf
        memset(buf, 0, SECTOR_SIZE);
    }
    sys_free(buf);
    sys_free(all_blocks);
    return false;
}

