package riscv_types;

// data width parameters
parameter int XLEN = 32;  			 // register width
parameter int ILEN = 32; 			 // instruction width

// RISC-V base opcodes
typedef enum logic [6:0] {
	
	OPCODE_LUI = 7'b0110111,		// load upper immediate
	OPCODE_AUIPC = 7'b0010111, 		// add upper immediate to pc
	OPCODE_JAL    = 7'b1101111,  	// jump and Link
    OPCODE_JALR   = 7'b1100111,  	// jump and Link Register
    OPCODE_BRANCH = 7'b1100011,  	// branch Instructions
    OPCODE_LOAD   = 7'b0000011,  	// load Instructions
    OPCODE_STORE  = 7'b0100011,  	// store Instructions
    OPCODE_ARITHI = 7'b0010011,  	// arithmetic Immediate
    OPCODE_ARITH  = 7'b0110011   	// arithmetic Register
} opcode_t;


