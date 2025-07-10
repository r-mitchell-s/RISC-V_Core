# Very simple RV32I program - good for initial testing
# Only uses basic R-type and I-type instructions

# Load some immediate values
addi x1, x0, 10
addi x2, x0, 20

# Basic arithmetic
add x3, x1, x2
sub x4, x2, x1

# More immediates
addi x5, x3, 5
addi x6, x4, -3

# Basic logical operations
and x7, x1, x2
or x8, x1, x2

# Simple shifts
slli x9, x1, 2
srli x10, x2, 1