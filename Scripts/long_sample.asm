# Comprehensive RV32I Test Program
# Tests all instruction types in the base integer instruction set
# Uses byte offsets instead of labels for branches/jumps

# === I-TYPE IMMEDIATE INSTRUCTIONS ===
addi x1, x0, 100        # x1 = 100
addi x2, x0, -50        # x2 = -50  
addi x3, x1, 25         # x3 = x1 + 25 = 125

slti x4, x1, 200        # x4 = (100 < 200) ? 1 : 0 = 1
slti x5, x1, 50         # x5 = (100 < 50) ? 1 : 0 = 0
sltiu x6, x2, 100       # x6 = (-50 < 100) unsigned ? 1 : 0

andi x7, x1, 15         # x7 = x1 & 15
ori x8, x1, 7           # x8 = x1 | 7
xori x9, x1, 255        # x9 = x1 ^ 255

# === I-TYPE SHIFT INSTRUCTIONS ===
slli x10, x1, 2         # x10 = x1 << 2
srli x11, x1, 1         # x11 = x1 >> 1 (logical)
srai x12, x2, 2         # x12 = x2 >> 2 (arithmetic, sign-extended)

# === R-TYPE ARITHMETIC INSTRUCTIONS ===
add x13, x1, x3         # x13 = x1 + x3
sub x14, x3, x1         # x14 = x3 - x1

# === R-TYPE LOGICAL INSTRUCTIONS ===
and x15, x1, x3         # x15 = x1 & x3
or x16, x1, x3          # x16 = x1 | x3
xor x17, x1, x3         # x17 = x1 ^ x3

# === R-TYPE SHIFT INSTRUCTIONS ===
addi x18, x0, 3         # Shift amount in register
sll x19, x1, x18        # x19 = x1 << x18
srl x20, x1, x18        # x20 = x1 >> x18 (logical)
sra x21, x2, x18        # x21 = x2 >> x18 (arithmetic)

# === R-TYPE COMPARISON INSTRUCTIONS ===
slt x22, x1, x3         # x22 = (x1 < x3) ? 1 : 0
slt x23, x3, x1         # x23 = (x3 < x1) ? 1 : 0
sltu x24, x1, x2        # x24 = (x1 < x2) unsigned comparison

# === U-TYPE INSTRUCTIONS ===
lui x25, 12345        # x25 = 0x12345000
auipc x26, 1000       # x26 = PC + 0x1000000

# === MEMORY INSTRUCTIONS (LOADS) ===
lw x27, 0(x1)           # Load word from address in x1
lh x28, 4(x1)           # Load halfword from x1+4
lb x29, 8(x1)           # Load byte from x1+8
lbu x30, 12(x1)         # Load byte unsigned from x1+12
lhu x31, 16(x1)         # Load halfword unsigned from x1+16

# === MEMORY INSTRUCTIONS (STORES) ===
sw x1, 20(x0)           # Store word x1 to address 20
sh x2, 24(x0)           # Store halfword x2 to address 24
sb x3, 28(x0)           # Store byte x3 to address 28

# === BRANCH INSTRUCTIONS ===
beq x1, x1, 4           # Branch forward 4 bytes (skip next instruction)
addi x4, x0, 999        # This should be skipped

bne x1, x2, 4           # Branch forward 4 bytes if x1 != x2
addi x5, x0, 888        # This should be skipped

blt x2, x1, 4           # Branch forward 4 bytes if x2 < x1 (signed)
addi x6, x0, 777        # This should be skipped

bge x1, x2, 4           # Branch forward 4 bytes if x1 >= x2 (signed)
addi x7, x0, 666        # This should be skipped

bltu x1, x3, 4          # Branch forward 4 bytes if x1 < x3 (unsigned)
addi x8, x0, 555        # This should be skipped

bgeu x3, x1, 4          # Branch forward 4 bytes if x3 >= x1 (unsigned)
addi x9, x0, 444        # This should be skipped

# === JUMP INSTRUCTIONS ===
jal x1, 8               # Jump forward 8 bytes, save return address in x1
addi x10, x0, 333       # This should be skipped
addi x11, x0, 42        # Jump target: do some work
addi x12, x0, 84        # More work

# === JALR INSTRUCTION ===
jalr x0, x1, 0          # Jump to address in x1 (return from function)

# === INFINITE LOOP (END OF PROGRAM) ===
beq x0, x0, 0           # Branch to self (infinite loop)
