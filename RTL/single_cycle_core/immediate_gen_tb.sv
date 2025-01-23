// - - - - - IMMEDIATE GENERATOR TESTBENCH - - - - - //
// 
// Used AI to generate a few RISC-V base instructions with immediates starting at 3 and adding three
// to the respective immediate field (based on instruction type) with each applied stimulus

`include "opcodes.svh"

module immediate_gen_tb;

    // signal declaration
    logic [6:0] i_opcode;
    logic [31:0] i_instr;
    logic [31:0] o_ext_imm;

    // integers for tracking sucessful/failed tests
    // integer

    // instantiate DUT
    immediate_gen dut(.i_opcode(i_opcode), .i_instr(i_instr), .o_ext_imm(o_ext_imm));

    // stimulus generation
    initial begin

        // create an output for the waveform viewer
        $dumpfile("dump.vcd");
        $dumpvars();

        i_opcode = 0;
        i_instr = 32'd0;
        #5

        i_opcode = I_TYPE_OPCODE;
        i_instr = 32'b00000000101000010000000010010011;
        #5

        i_opcode = S_TYPE_OPCODE;
        i_instr = 32'b00000000000100010010101000100011;
        #5

        i_opcode = B_TYPE_OPCODE;
        i_instr = 32'b00000010000100010000111101100011;
        #5

        i_opcode = U_TYPE_OPCODE;
        i_instr = 32'b00000000000000101000000010110111;
        #5

        i_opcode = J_TYPE_OPCODE;
        i_instr = 32'b00000001100100000010000011101111;
        #5
        
        $finish;
    end
endmodule