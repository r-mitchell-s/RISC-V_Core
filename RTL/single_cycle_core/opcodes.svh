`ifndef OPCODES_SVH
`define OPCODES_SVH

// - - - - - OPCODE TYPES - - - - - //
parameter R_TYPE_OPCODE = 7'b0110011;
parameter I_TYPE_OPCODE = 7'b0010011;
parameter S_TYPE_OPCODE = 7'b0100011;
parameter B_TYPE_OPCODE = 7'b1100011;
parameter U_TYPE_OPCODE = LUI_OPCODE | AUIPC_OPCODE;
parameter J_TYPE_OPCODE = 7'b1101111;

// - - - - - INDIVIDUAL INSTRUCTION OPCODES - - - - - //

// U-types
parameter LUI_OPCODE = 7'b0110111;
parameter AUIPC_OPCODE = 7'b0010111;

`endif