`ifndef OPCODES_SVH
`define OPCODES_SVH

// - - - - - R-TYPE OPCODES - - - - - //
parameter R_TYPE_OPCODE = 7'b0110011;   

// - - - - - I-TYPE OPCODES - - - - - //
parameter I_LOAD_OPCODE = 7'b0000011;
parameter I_ARITH_OPCODE = 7'b0010011;
parameter I_SHIFT_OPCODE = 7'b0010011;
parameter JALR_OPCODE = 7'b1100111;

// - - - - - S-TYPE OPCODES - - - - - //
parameter S_TYPE_OPCODE = 7'b0100011;                          

// - - - - - B-TYPE OPCODES - - - - - //
parameter B_TYPE_OPCODE = 7'b1100011;          

// - - - - - U-TYPE OPCODES - - - - - // 
parameter LUI_OPCODE = 7'b0110111;
parameter AUIPC_OPCODE = 7'b0010111;

// - - - - - J-TYPE OPCODES - - - - - //
parameter JAL_OPCODE = 7'b1101111;

`endif