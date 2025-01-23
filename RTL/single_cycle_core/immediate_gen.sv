// - - - - - IMMEDIATE GENERATOR - - - - - //
`include "opcodes.svh"

module immediate_gen (
    input logic [6:0] i_opcode,
    input logic [31:0] i_instr,
    output logic [31:0] o_ext_imm
);

    always @(*) begin
        case (i_opcode)
            I_TYPE_OPCODE: o_ext_imm = {{20{i_instr[31]}}, {i_instr[31:20]}}; 
            S_TYPE_OPCODE: o_ext_imm = {{20{i_instr[31]}}, {i_instr[31:25]}, {i_instr[11:7]}};
            B_TYPE_OPCODE: o_ext_imm = {{20{i_instr[31]}}, {i_instr[7]}, {i_instr[30:25], i_instr[11:8]}, {1'b0}};
            U_TYPE_OPCODE: o_ext_imm = {{i_instr[31:12]}, {12'd0}};
            J_TYPE_OPCODE: o_ext_imm = {{12{i_instr[31]}}, {i_instr[19:12]}, {i_instr[20]}, {i_instr[30:21]}, {1'b0}};
            default: o_ext_imm = 32'd0;
        endcase
    end
endmodule