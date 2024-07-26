/* 下面是一些宏 */

.macro SAVE_REGS_EL2
    // 将 x0 和 x1 压栈
    sub     sp, sp, 16
    stp     x0, x1, [sp]
    ldr     x0, =regs

    // 保存寄存器到特定地址
    stp     x2, x3,   [x0,  2 * 8]
    stp     x4, x5,   [x0,  4 * 8]
    stp     x6, x7,   [x0,  6 * 8]
    stp     x8, x9,   [x0,  8 * 8]
    stp     x10, x11, [x0, 10 * 8]
    stp     x12, x13, [x0, 12 * 8]
    stp     x14, x15, [x0, 14 * 8]
    stp     x16, x17, [x0, 16 * 8]
    stp     x18, x19, [x0, 18 * 8]
    stp     x20, x21, [x0, 20 * 8]
    stp     x22, x23, [x0, 22 * 8]
    stp     x24, x25, [x0, 24 * 8]
    stp     x26, x27, [x0, 26 * 8]
    stp     x28, x29, [x0, 28 * 8]
    stp     x30, xzr, [x0, 30 * 8]

    mrs     x10, elr_el2
    mrs     x11, spsr_el2
    stp     x10, x11, [x0, 32 * 8]

    // 恢复 x0 和 x1 并将它们保存到正确的区域
    ldp     x0, x1, [sp]
    add     sp, sp, 16
    stp     x0, x1, [x0, 0]    // 保存 x0 和 x1 到基地址处

    bl      __vm_out
.endm

.macro EXCEPTION_ITEMS, kind, source
.p2align 7
    SAVE_REGS_EL2
    ldr     x0, =regs
    mov     x1, \kind
    mov     x2, \source
    b      __vmexit
.endm

/* 下面是准备暴露的接口 */
.global __vmon
.global __vmoff
.global __vmlaunch
.global __vmresume

// 外部根据具体虚拟机功能实现
.extern __vm_in
.extern __vm_out

// extern __vmexit(uint64_t * data, uint8_t kind, uint8_t source) 
// data: regs -> spsr_el2 -> elr_el2
.extern __vmexit  /* 接口：虚拟机发生中断退出时调用 */


/* 下面是私有符号 */
.local vbar_el2_base


/* ***************************** */
/* ***   具体函数实现  *** */
/* ***************************** */

/* 保存原来的vbar_el2，重新设置vbar_el2异常向量基址 */
/* TODO: 处理权限不够问题 */
.section .text
__vmon:
    mrs     x1,       vbar_el2
    ldr     vbar,     x1
    adrp    x1,       :got:vbar_el2_base
    ldr     x1,       [x1,:got_lo12:vbar_el2_base]
    msr     vbar_el2, x1

/* 恢复原来的vbar_el2 */
__vmoff:
    mov     vbar, x1
    msr     vbar_el2, x1


/* 
 * 虚拟机第一次启动，载入 el1 相关寄存器
 * eret 进入虚拟机
 * 
 * 调用之前在栈上放置：
 * 31 个寄存器
 * elr_el2 guest 入口
 * spsr_el2 跳到el1h
*/
__vmlaunch:
    bl      __vm_in

    sub     sp, sp, 16
    stp     x0, x1, [sp]
    ldr     x0, =regs
    
    ldp     x10, x11, [x0, 32 * 8]
    msr     elr_el2, x10
    msr     spsr_el2, x11

    ldr     x30,      [x0, 30 * 8]
    ldp     x28, x29, [x0, 28 * 8]
    ldp     x26, x27, [x0, 26 * 8]
    ldp     x24, x25, [x0, 24 * 8]
    ldp     x22, x23, [x0, 22 * 8]
    ldp     x20, x21, [x0, 20 * 8]
    ldp     x18, x19, [x0, 18 * 8]
    ldp     x16, x17, [x0, 16 * 8]
    ldp     x14, x15, [x0, 14 * 8]
    ldp     x12, x13, [x0, 12 * 8]
    ldp     x10, x11, [x0, 10 * 8]
    ldp     x8, x9,   [x0,  8 * 8]
    ldp     x6, x7,   [x0,  6 * 8]
    ldp     x4, x5,   [x0,  4 * 8]
    ldp     x2, x3,   [x0,  2 * 8]
    ldp     x0, x1,   [x0,  2 * 0]
    add     sp, sp,   34 * 8 

    // 恢复 x0 和 x1 并将它们保存到正确的区域
    ldp     x0, x1, [sp]
    add     sp, sp, 16

    eret


__vmresume:
    b __vmlaunch
    /* Can not reach here */
    b    .

.section.text
.p2align 11  /* 2K */
vbar_el2_base:
    // current EL, with SP_EL0
    EXCEPTION_ITEMS 0 0
    EXCEPTION_ITEMS 1 0
    EXCEPTION_ITEMS 2 0
    EXCEPTION_ITEMS 3 0
    // current EL, with SP_ELx
    EXCEPTION_ITEMS 0 1
    EXCEPTION_ITEMS 1 1
    EXCEPTION_ITEMS 2 1
    EXCEPTION_ITEMS 3 1
    // lower EL, aarch64  比当前等级更低一级
    EXCEPTION_ITEMS 0 2
    EXCEPTION_ITEMS 1 2
    EXCEPTION_ITEMS 2 2
    EXCEPTION_ITEMS 3 2
    // lower EL, aarch32
    EXCEPTION_ITEMS 0 3
    EXCEPTION_ITEMS 1 3
    EXCEPTION_ITEMS 2 3
    EXCEPTION_ITEMS 3 3



/* 其实可以把 上下文都保存到这里来 */
/* 涉及到多核的话就double */
/* 进一步简化操作 */
.section .data.__armvt

vbar:
    .quad  0x0000

/* 要保证他们的顺序是 regs -> spsr_el2 -> elr_el2 */
regs:
    .skip 0x8 * 31   /* regs */

spsr_el2:
    .quad  0x0000

elr_el2:
    .auad  0x0000