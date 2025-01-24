// - - - - - IMMEDIATE GENERATOR - - - - - //
`include "opcodes.svh"

module immediate_gen (
    input logic [6:0] i_opcode,
    input logic [31:0] i_instr,
    output logic [31:0] o_ext_imm
);

    always @(*) begin
        case (i_opcode)

            // I-type immediate handling
            I_LOAD_OPCODE, I_ARITH_OPCODE, I_SHIFT_OPCODE, JALR_OPCODE: 
                o_ext_imm = {{20{i_instr[31]}}, {i_instr[31:20]}}; 

            // S-type immediate handling
            S_TYPE_OPCODE: 
                o_ext_imm = {{20{i_instr[31]}}, {i_instr[31:25]}, {i_instr[11:7]}};
            
            // B-type immediate handling
            B_TYPE_OPCODE: 
                o_ext_imm = {{20{i_instr[31]}}, {i_instr[7]}, {i_instr[30:25], i_instr[11:8]}, {1'b0}};
            
            // U-type immediate handling
            LUI_OPCODE, AUIPC_OPCODE: 
                o_ext_imm = {{i_instr[31:12]}, {12'd0}};

            // J-type immediate handling
            JAL_OPCODE: 
                o_ext_imm = {{11{i_instr[31]}}, {i_instr[31]}, {i_instr[19:12]}, {i_instr[20]}, {i_instr[30:21]}, {1'b0}};
            
            // default to no extension
            default: o_ext_imm = 32'd0;
        endcase
    end
endmodule