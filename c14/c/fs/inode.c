#include "inode.h"
#include "fs.h"
#include "file.h"
#include "global.h"
#include "debug.h"
#include "memory.h"
#include "interrupt.h"
#include "list.h"
#include "stdio-kernel.h"
#include "string.h"
#include "super_block.h"

/* 用来存储inode位置 */
struct inode_position {
    bool        two_sec;    // inode是否跨扇区
    uint32_t    sec_lba;    // inode所在的扇区号
    uint32_t    off_size;   // inode在扇区内的字节偏移量
};

/* 获取inode所在的扇区和扇区内的偏移量 */
static void inode_locate(struct partition* part, uint32_t inode_no, struct inode_position* inode_pos) {
    /* inode_table在硬盘上是连续的 */
    ASSERT(inode_no < MAX_FILES_PER_PART);
    uint32_t inode_table_lba = part->sb->inode_table_lba;

    uint32_t inode_size = sizeof(struct inode);
    uint32_t off_size = inode_no * inode_size;  // 第inode_no号I结点相对于inode_table_lba的字节偏移量
    uint32_t off_sec = off_size / SECTOR_SIZE;  // 第inode_no号I结点相对于inode_table_lba的扇区偏移量
    uint32_t off_size_in_sec = off_size % SECTOR_SIZE;  // 待查找的inode所在扇区中的起始地址

    /* 判断此i结点是否跨越2个扇区 */
    uint32_t left_in_sec = SECTOR_SIZE - off_size_in_sec;
    if (left_in_sec < inode_size) { // 若扇区内剩下的空间不足以容纳一个inode,必然是I结点跨越了2个扇区
        inode_pos->two_sec = true;
    } else { // 否则,所查找的inode未跨扇区
        inode_pos->two_sec = false;
    }
    // inode_pos->two_sec = left_in_sec < inode_size;
    inode_pos->sec_lba = inode_table_lba + off_sec;
    inode_pos->off_size = off_size_in_sec;
}
/* 将inode写入到分区part */
void inode_sysc(struct partition* part, struct inode* inode, void* io_buf) {    // io_buf是用于硬盘io的缓冲区
    uint8_t inode_no = inode->i_no;
    struct inode_position inode_pos;
    inode_locate(part, inode_no, &inode_pos);   // inode位置信息会存入inode_pos
    ASSERT(inode_pos.sec_lba <= (part->start_lba + part->sec_cnt));

    /* 硬盘中的inode中的成员inode_tag和i_open_cnts是不需要的,
     * 它们只在内存中记录链表位置和被多少进程共享 */
    struct inode pure_inode;
    memcpy(&pure_inode, inode, sizeof(struct inode));

    /* 以下inode的三个成员只存在于内存中,现在将inode同步到硬盘,清掉这三项即可 */
    pure_inode.i_open_cnts = 0;
    pure_inode.write_deny = false;
    pure_inode.inode_tag.prev = pure_inode.inode_tag.next = NULL;

    char* inode_buf = (char*)io_buf;
    if (inode_pos.two_sec) {   // 若是跨了两个扇区,就要读出两个扇区再写入两个扇区
        /* 读写硬盘是以扇区为单位,若写入的数据小于一扇区,要将原硬盘上的内容先读出来再和新数据拼成一扇区后再写入  */
        ide_read(part->my_disk, inode_pos.sec_lba, inode_buf, 2);   // inode在format中写入硬盘时是连续写入的,所以读入2块扇区
        /* 开始将待写入的inode拼入到这2个扇区中的相应位置 */
        memcpy((inode_buf + inode_pos.off_size), &pure_inode, sizeof(struct inode));
        /* 将拼接好的数据再写入磁盘 */
        ide_write(part->my_disk, inode_pos.sec_lba, inode_buf, 2);
    } else {
        ide_read(part->my_disk, inode_pos.sec_lba, inode_buf, 1);
        memcpy((inode_buf + inode_pos.off_size), &pure_inode, sizeof(struct inode));
        ide_write(part->my_disk, inode_pos.sec_lba, inode_buf, 1);
    }
}
