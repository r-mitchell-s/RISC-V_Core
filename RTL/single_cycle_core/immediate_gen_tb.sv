// - - - - - IMMEDIATE GENERATOR TESTBENCH - - - - - //
module immediate_gen_tb;
    
    // DUT I/O signals
    logic [6:0] i_opcode;
    logic [31:0] i_instr;
    logic [31:0] o_ext_imm;
    
    // test tracking variables
    integer num_tests = 0;
    integer num_passes = 0;
    
    // DUT instantiation
    immediate_gen dut(.i_opcode(i_opcode), .i_instr(i_instr), .o_ext_imm(o_ext_imm));
    
    // test to examine whether or not the proper immediate has been generated
    task automatic check_imm;
        
        // inputs
        input [31:0] instruction;
        input [6:0] opcode;
        input [31:0] expected;
        input string inst_type;
        
        // implement
        begin
            num_tests++;
            i_instr = instruction;
            i_opcode = opcode;
            #5;
            if (o_ext_imm === expected) begin
                num_passes++;
                $display("PASS: %s - Expected: %0d, Got: %0d", inst_type, expected, o_ext_imm);
            end else begin
                $display("FAIL: %s - Expected: %0d, Got: %0d", inst_type, expected, o_ext_imm);
            end
        end
    endtask
    
    // stimulus generation
    initial begin

        // setup waveform dumping
        $dumpfile("immediate_gen.vcd");
        $dumpvars(0, immediate_gen_tb);
        $display("");

        // - - - - TEST BEGIN (Vectors generated with GPT) - - - - - // 

        // I-type Instructions
        check_imm(32'b000000000011_00001_000_00010_0000011, I_LOAD_OPCODE, 3, "I-type (LW)");
        check_imm(32'b111111111111_00001_000_00010_0010011, I_ARITH_OPCODE, -1, "I-type (ADDI negative)");
        check_imm(32'b000000000100_00001_000_00001_1100111, JALR_OPCODE, 4, "JALR (I-type)");       

        // S-type Instructions
        check_imm(32'b0000000_00010_00001_010_00100_0100011, S_TYPE_OPCODE, 4, "S-type (SW)");
        
        // B-type Instructions
        check_imm(32'b0_000000_00010_00001_000_0100_0_1100011, B_TYPE_OPCODE, 8, "B-type (BEQ)");
        
        // U-type Instructions
        check_imm(32'b00000000000000000001_00001_0110111, LUI_OPCODE, 4096, "U-type (LUI)");
        check_imm(32'b00000000000000000001_00001_0010111, AUIPC_OPCODE, 4096, "U-type (AUIPC)");
        
        // J-type Instructions
        check_imm(32'b0_0000001000_0_00000000_00001_1101111, JAL_OPCODE, 512, "J-type (JAL)");
        
        // report results
        $display("\nTest Summary:");
        $display("Passed %0d of %0d tests", num_passes, num_tests);
        if (num_passes == num_tests)
            $display("ALL TESTS PASSED!\n");
        else
            $display("SOME TESTS FAILED!\n");

        // test complete 
        $finish;
    end
endmodule