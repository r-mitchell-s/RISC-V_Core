// - - - - - UVM TESTBENCH FOR DECODE UNIT OF RISC-V CORE - - - - - //

import uvm_pkg::*;
`include "uvm_macros.svh"

// - - - - - TRANSACTION - - - - - //
class decode_transaction extends uvm_sequence_item;

    // decode inputs
    rand logic [31:0] instr;

    // outputs
    logic [4:0]   rs1;
    logic [4:0]   rs2;
    logic [4:0]   rd;
    logic [6:0]   op;
    logic [2:0]   funct3;
    logic [6:0]   funct7;
    logic         r_type_instr;
    logic         i_type_instr;
    logic         s_type_instr;
    logic         b_type_instr;
    logic         u_type_instr;
    logic         j_type_instr;
    logic [31:0]  instr_imm;

    // constraints
    constraint valid_opcode {
        instr[6:0] inside {R_TYPE, I_TYPE0, I_TYPE1, I_TYPE2, S_TYPE, B_TYPE, U_TYPE0, U_TYPE1, J_TYPE};
    }

    constraint valid_registers {
        (instr[6:0] == R_TYPE) -> (instr[24:20] <= 31 && instr[19:15] <= 31 && instr[11:7] <= 31);
        (instr[6:0] == I_TYPE0 || instr[6:0] == I_TYPE1 || instr[6:0] == I_TYPE2) -> (instr[19:15] <= 31 && instr[11:7] <= 31);
        (instr[6:0] == S_TYPE) -> (instr[24:20] <= 31 && instr[19:15] <= 31);
        (instr[6:0] == B_TYPE) -> (instr[24:20] <= 31 && instr[19:15] <= 31);
        (instr[6:0] == U_TYPE0 || instr[6:0] == U_TYPE1) -> (instr[11:7] <= 31);
        (instr[6:0] == J_TYPE) -> (instr[11:7] <= 31);
    }

    constraint valid_funct3 {
        (instr[6:0] == I_TYPE1) -> (instr[14:12] inside {0,1,2,4,5});
        (instr[6:0] == I_TYPE2) -> (instr[14:12] == 0);
        (instr[6:0] == S_TYPE) -> (instr[14:12] inside {[0:2]});
        (instr[6:0] == B_TYPE) -> (instr[14:12] inside {0,1,4,5,6,7});
    }

    constraint valid_funct7 {
        (instr[6:0] == R_TYPE && instr[14:12] == 0) -> (instr[31:25] inside {0, 32});
        (instr[6:0] == R_TYPE && instr[14:12] != 0) -> (instr[31:25] == 0);
    }

    // field macros
    `uvm_object_utils_begin(decode_transaction)
        `uvm_field_int(instr, UVM_ALL_ON)
        `uvm_field_int(rs1, UVM_ALL_ON)
        `uvm_field_int(rs2, UVM_ALL_ON)
        `uvm_field_int(rd, UVM_ALL_ON)
        `uvm_field_int(op, UVM_ALL_ON)
        `uvm_field_int(funct3, UVM_ALL_ON)
        `uvm_field_int(funct7, UVM_ALL_ON)
        `uvm_field_int(r_type_instr, UVM_ALL_ON)
        `uvm_field_int(i_type_instr, UVM_ALL_ON)
        `uvm_field_int(s_type_instr, UVM_ALL_ON)
        `uvm_field_int(b_type_instr, UVM_ALL_ON)
        `uvm_field_int(u_type_instr, UVM_ALL_ON)
        `uvm_field_int(j_type_instr, UVM_ALL_ON)
        `uvm_field_int(instr_imm, UVM_ALL_ON)
    `uvm_object_utils_end

    // constructor
    function new(string name = "decode_transaction");
        super.new(name);
    endfunction

endclass

// - - - - - SEQUENCER - - - - - //
class decode_sequencer extends uvm_sequencer #(decode_transaction);
    `uvm_component_utils(decode_sequencer)

    // constructor
    function new(string name = "decode_sequencer", uvm_component parent);
        super.new(name, parent);
    endfunction
endclass

// - - - - - INTERFACE - - - - - //
interface decode_if(input logic clk);
        
    // decode inputs
    logic [31:0] instr_i;

    // outputs
    logic [4:0]   rs1_o;
    logic [4:0]   rs2_o;
    logic [4:0]   rd_o;
    logic [6:0]   op_o;
    logic [2:0]   funct3_o;
    logic [6:0]   funct7_o;
    logic         r_type_instr_o;
    logic         i_type_instr_o;
    logic         s_type_instr_o;
    logic         b_type_instr_o;
    logic         u_type_instr_o;
    logic         j_type_instr_o;
    logic [31:0]  instr_imm_o;

endinterface

// - - - - - DRIVER - - - - - // 
class decode_driver extends uvm_driver #(decode_transaction);
    `uvm_component_utils(decode_driver)

    // interface for the driver to connect to the sequencer
    virtual decode_if vif;

    // constructor - create the driver
    function new(string name = "decode_driver", uvm_component parent);
        super.new(name, parent);
    endfunction

    // build phase actually instantiates the driver
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // error handling if no interface is detected
        if (!uvm_config_db#(virtual decode_if)::get(this,"","vif", vif))
            `uvm_fatal("DRIVER", "Virtual interface not found.");
    endfunction

    // run phase is the task that governs the drivers continuous behavior
    task run_phase(uvm_phase phase);
        
        // instantiate a transaction
        decode_transaction req;

        // continually get transactions from sequencer, drive them, and then let thesequencer your done
        forever begin
            seq_item_port.get_next_item(req);
            drive_transaction(req);
            seq_item_port.item_done();
        end
    endtask

    task drive_transaction(decode_transaction req);
        @(posedge vif.clk);
        vif.instr_i <= req.instr;
    endtask
endclass

// - - - - - MONITOR - - - - - // 
class decode_monitor extends uvm_monitor;
    `uvm_component_utils(decode_monitor)

    // declare pointer to interface
    virtual decode_if vif;

    // analysis port for accepting transactions from DUT
    uvm_analysis_port #(decode_transaction) ap;

    // constructor
    function new(string name = "decode_monitor", uvm_component parent);
        super.new(name, parent);
    endfunction
    
    // build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual decode_if)::get(this, "", "vif", vif))
            `uvm_fatal("MONITOR", "Virtual interface not found!")
        ap = new("ap", this);
    endfunction

    // run phase
    task run_phase(uvm_phase phase);
        
        // declare pointer to the decode transaction
        decode_transaction tr;

        // generate and populate the transaction
        forever begin
            @(posedge vif.clk);
            tr = decode_transaction::type_id::create("tr");
            tr.instr = vif.instr_i;
            
            // capture DUT outputs
            tr.rs1 = vif.rs1_o;
            tr.rs2 = vif.rs2_o;
            tr.rd = vif.rd_o;
            tr.op = vif.op_o;
            tr.funct3 = vif.funct3_o;
            tr.funct7 = vif.funct7_o;
            tr.r_type_instr = vif.r_type_instr_o;
            tr.i_type_instr = vif.i_type_instr_o;
            tr.s_type_instr = vif.s_type_instr_o;
            tr.b_type_instr = vif.b_type_instr_o;
            tr.u_type_instr = vif.u_type_instr_o;
            tr.j_type_instr = vif.j_type_instr_o;
            tr.instr_imm = vif.instr_imm_o;

            // report the transaction info
            `uvm_info("MONITOR", $sformatf("Transaction generated: Instr: %h, rs1: %d, rs2: %d, opcode: %b, rd: %d, funct3: %b, funct7: %b, r_type: %b, i_type: %b, s_type: %b, b_type: %b, u_type: %b, j_type: %b, immediate: %h", tr.instr, tr.rs1, tr.rs2, tr.rd, tr.op, tr.funct3, tr.funct7, tr.r_type_instr, tr.i_type_instr, tr.s_type_instr, tr.b_type_instr, tr.u_type_instr, tr.j_type_instr, tr.instr_imm), UVM_LOW)

            // write the observed transaction to the scoreboard
            ap.write(tr);
        end
    endtask
endclass

// - - - - - AGENT - - - - - //
class decode_agent extends uvm_agent;
    `uvm_component_utils(decode_agent)

    // constructor
    function new(string name = "decode_agent", uvm_component parent);
        super.new(name, parent);
    endfunction

    // component handles
    decode_driver drv;
    decode_monitor mon;
    decode_sequencer sqr;

    // build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = decode_driver::type_id::create("drv", this);
        if (get_is_active == UVM_ACTIVE) begin
            sqr = decode_sequencer::type_id::create("seq", this);
            mon = decode_monitor::type_id::create("mon", this);
        end
    endfunction

    // connect phase
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active == UVM_ACTIVE) begin
            drv.seq_item_port.connect(sqr.seq_item_export);
        end
    endfunction
endclass

// - - - - - SCOREBOARD - - - - - //
class decode_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(decode_scoreboard)

    // variables for tracking test cases
    int test_count;
    int error_count;

    // golden results
    logic [4:0] golden_rs1;
    logic [4:0] golden_rs2;
    logic [4:0] golden_rd;
    logic [6:0] golden_op;
    logic [2:0] golden_funct3;
    logic [6:0] golden_funct7;
    logic golden_r_type_instr;
    logic golden_s_type_instr;
    logic golden_i_type_instr;
    logic golden_b_type_instr;
    logic golden_u_type_instr;
    logic golden_j_type_instr;
    logic [31:0] golden_instr_imm;

    // analysis import declaration
    uvm_analysis_imp #(decode_transaction, decode_scoreboard) ap_imp;

    // constructor
    function new(string name = "decode_scoreboard", uvm_component parent);
        super.new(name, parent);
    endfunction

    // build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap_imp = new("ap_imp", this);

        // initialize the golden model variables
        golden_rs1 = 0;
        golden_rs2 = 0;
        golden_rd = 0;
        golden_op = 0;
        golden_funct3 = 0;
        golden_funct7 = 0;
        golden_r_type_instr = 0;
        golden_i_type_instr = 0;
        golden_s_type_instr = 0;
        golden_b_type_instr = 0;
        golden_u_type_instr = 0;
        golden_j_type_instr = 0;
        golden_instr_imm = 0;
        
        // test stats
        test_count = 0;
        error_count = 0;

    endfunction

    // write for evaluating golden model
    function void write(decode_transaction tr);
        test_count++;

        // given the input transaction, find golden result
        case (tr.instr[6:0])
            7'h33: begin
                golden_rs1 = tr.instr[19:15];
                golden_rs2 = tr.instr[24:20]; 
                golden_rd = tr.instr[11:7];
                golden_op = tr.instr[6:0];
                golden_funct3 = tr.instr[14:12];
                golden_funct7 = tr.instr[31:25];
                golden_r_type_instr = 1'b1;
                golden_i_type_instr = 1'b0;
                golden_s_type_instr = 1'b0;
                golden_b_type_instr = 1'b0;
                golden_u_type_instr = 1'b0;
                golden_j_type_instr = 1'b0;
                golden_instr_imm = 32'h0;
            end

            7'h3: begin
                golden_rs1 = tr.instr[19:15];
                golden_rs2= tr.instr[24:20];
                golden_rd = tr.instr[11:7];
                golden_op = tr.instr[6:0];
                golden_funct3 = tr.instr[14:12];
                golden_funct7 = tr.instr[31:25];
                golden_r_type_instr = 1'b0;
                golden_i_type_instr = 1'b1;
                golden_s_type_instr = 1'b0;
                golden_b_type_instr = 1'b0;
                golden_u_type_instr = 1'b0;
                golden_j_type_instr = 1'b0;
                golden_instr_imm = {{20{tr.instr[31]}}, tr.instr[31:20]};
            end

            7'h13: begin
                golden_rs1 = tr.instr[19:15];
                golden_rs2= tr.instr[24:20];
                golden_rd = tr.instr[11:7];
                golden_op = tr.instr[6:0];
                golden_funct3 = tr.instr[14:12];
                golden_funct7 = tr.instr[31:25];
                golden_r_type_instr = 1'b0;
                golden_i_type_instr = 1'b1;
                golden_s_type_instr = 1'b0;
                golden_b_type_instr = 1'b0;
                golden_u_type_instr = 1'b0;
                golden_j_type_instr = 1'b0;
                golden_instr_imm = {{20{tr.instr[31]}}, tr.instr[31:20]};
            end
            
            7'h67: begin
                golden_rs1 = tr.instr[19:15];
                golden_rs2= tr.instr[24:20];
                golden_rd = tr.instr[11:7];
                golden_op = tr.instr[6:0];
                golden_funct3 = tr.instr[14:12];
                golden_funct7 = tr.instr[31:25];
                golden_r_type_instr = 1'b0;
                golden_i_type_instr = 1'b1;
                golden_s_type_instr = 1'b0;
                golden_b_type_instr = 1'b0;
                golden_u_type_instr = 1'b0;
                golden_j_type_instr = 1'b0;
                golden_instr_imm = {{20{tr.instr[31]}}, tr.instr[31:20]};
            end

            7'h23: begin
                golden_rs1 = tr.instr[19:15];
                golden_rs2 = tr.instr[24:20];
                golden_rd = tr.instr[11:7]; 
                golden_op = tr.instr[6:0];
                golden_funct3 = tr.instr[14:12];
                golden_funct7 = tr.instr[31:25];
                golden_r_type_instr = 1'b0;
                golden_i_type_instr = 1'b0;
                golden_s_type_instr = 1'b1;
                golden_b_type_instr = 1'b0;
                golden_u_type_instr = 1'b0;
                golden_j_type_instr = 1'b0;
                golden_instr_imm = {{20{tr.instr[31]}}, tr.instr[31:25], tr.instr[11:7]};
            end

            7'h63: begin
                golden_rs1 = tr.instr[19:15];
                golden_rs2 = tr.instr[24:20];
                golden_rd = tr.instr[11:7];
                golden_op = tr.instr[6:0];
                golden_funct3 = tr.instr[14:12];
                golden_funct7 = tr.instr[31:25];
                golden_r_type_instr = 1'b0;
                golden_i_type_instr = 1'b0;
                golden_s_type_instr = 1'b0;
                golden_b_type_instr = 1'b1;
                golden_u_type_instr = 1'b0;
                golden_j_type_instr = 1'b0;
                golden_instr_imm = {{19{tr.instr[31]}}, tr.instr[31], tr.instr[7], tr.instr[30:25], tr.instr[11:8], 1'b0};
            end

            7'h37: begin
                golden_rs1 = tr.instr[19:15];
                golden_rs2= tr.instr[24:20];
                golden_rd = tr.instr[11:7];
                golden_op = tr.instr[6:0];
                golden_funct3 = tr.instr[14:12];
                golden_funct7 = tr.instr[31:25];
                golden_r_type_instr = 1'b0;
                golden_i_type_instr = 1'b0;
                golden_s_type_instr = 1'b0;
                golden_b_type_instr = 1'b0;
                golden_u_type_instr = 1'b1;
                golden_j_type_instr = 1'b0;
                golden_instr_imm = {tr.instr[31:12], 12'h000};
            end

            7'h17: begin
                golden_rs1 = tr.instr[19:15];
                golden_rs2= tr.instr[24:20];
                golden_rd = tr.instr[11:7];
                golden_op = tr.instr[6:0];
                golden_funct3 = tr.instr[14:12];
                golden_funct7 = tr.instr[31:25];
                golden_r_type_instr = 1'b0;
                golden_i_type_instr = 1'b0;
                golden_s_type_instr = 1'b0;
                golden_b_type_instr = 1'b0;
                golden_u_type_instr = 1'b1;
                golden_j_type_instr = 1'b0;
                golden_instr_imm = {tr.instr[31:12], 12'h000};
            end

            7'h6f: begin
                golden_rs1 = tr.instr[19:15];
                golden_rs2= tr.instr[24:20];
                golden_rd = tr.instr[11:7];
                golden_op = tr.instr[6:0];
                golden_funct3 = tr.instr[14:12];
                golden_funct7 = tr.instr[31:25];
                golden_r_type_instr = 1'b0;
                golden_i_type_instr = 1'b0;
                golden_s_type_instr = 1'b0;
                golden_b_type_instr = 1'b0;
                golden_u_type_instr = 1'b0;
                golden_j_type_instr = 1'b1;
                golden_instr_imm = {{11{tr.instr[31]}}, tr.instr[31], tr.instr[19:12], tr.instr[20], tr.instr[30:21], 1'b0};
            end

            default: begin
                `uvm_error("SCOREBOARD", $sformatf("Invalid opcode: %h", tr.instr[6:0]))
            end
        endcase

        check_dut(tr);
    endfunction

    // helper for checking DUT against the golden model
    function void check_dut(decode_transaction tr);
        int flag = 0;

        if (tr.rs1 != golden_rs1) begin
            `uvm_error("SCOREBOARD", $sformatf("ERROR: DUT RS1 (%h) does not equal golden RS1 (%h)", tr.rs1, golden_rs1))
            flag = 1;
        end

        if (tr.rs2 != golden_rs2) begin
            `uvm_error("SCOREBOARD", $sformatf("ERROR: DUT RS2 (%h) does not equal golden RS2 (%h)", tr.rs2, golden_rs2))
            flag = 1;
        end

        if (tr.rd != golden_rd) begin
            `uvm_error("SCOREBOARD", $sformatf("ERROR: DUT RD (%h) does not equal golden RD (%h)", tr.rd, golden_rd))
            flag = 1;
        end

        if (tr.op != golden_op) begin
            `uvm_error("SCOREBOARD", $sformatf("ERROR: DUT OPCODE (%h) does not equal golden OPCODE (%h)", tr.op, golden_op))
            flag = 1;
        end

        if (tr.funct3 != golden_funct3) begin
            `uvm_error("SCOREBOARD", $sformatf("ERROR: DUT FUNCT3 (%h) does not equal golden FUNCT3 (%h)", tr.funct3, golden_funct3))
            flag = 1;
        end

        if (tr.funct7 != golden_funct7) begin
            `uvm_error("SCOREBOARD", $sformatf("ERROR: DUT FUNCT7 (%h) does not equal golden FUNCT7 (%h)", tr.funct7, golden_funct7))
            flag = 1;
        end   

        if (tr.r_type_instr != golden_r_type_instr) begin
            `uvm_error("SCOREBOARD", $sformatf("ERROR: DUT R_TYPE_INSTR (%h) does not equal golden R_TYPE_INSTR (%h)", tr.r_type_instr, golden_r_type_instr))
            flag = 1;
        end  

        if (tr.i_type_instr != golden_i_type_instr) begin
            `uvm_error("SCOREBOARD", $sformatf("ERROR: DUT I_TYPE_INSTR (%h) does not equal golden I_TYPE_INSTR (%h)", tr.i_type_instr, golden_i_type_instr))
            flag = 1;
        end  

        if (tr.s_type_instr != golden_s_type_instr) begin
            `uvm_error("SCOREBOARD", $sformatf("ERROR: DUT S_TYPE_INSTR (%h) does not equal golden S_TYPE_INSTR (%h)", tr.s_type_instr, golden_s_type_instr))
            flag = 1;
        end  

        if (tr.b_type_instr != golden_b_type_instr) begin
            `uvm_error("SCOREBOARD", $sformatf("ERROR: DUT B_TYPE_INSTR (%h) does not equal golden B_TYPE_INSTR (%h)", tr.b_type_instr, golden_b_type_instr))
            flag = 1;
        end  

        if (tr.u_type_instr != golden_u_type_instr) begin
            `uvm_error("SCOREBOARD", $sformatf("ERROR: DUT U_TYPE_INSTR (%h) does not equal golden U_TYPE_INSTR (%h)", tr.u_type_instr, golden_u_type_instr))
            flag = 1;
        end  

        if (tr.j_type_instr != golden_j_type_instr) begin
            `uvm_error("SCOREBOARD", $sformatf("ERROR: DUT J_TYPE_INSTR (%h) does not equal golden J_TYPE_INSTR (%h)", tr.j_type_instr, golden_j_type_instr))
            flag = 1;
        end  

        if (tr.instr_imm != golden_instr_imm) begin
            `uvm_error("SCOREBOARD", $sformatf("ERROR: DUT IMMEDIATE (%h) does not equal golden IMMEDIATE (%h)", tr.instr_imm, golden_instr_imm))
            flag = 1;
        end 

        if (flag) begin
            error_count++;
        end
    endfunction

    // report phase
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        // display the test and error stats
        `uvm_info("SCOREBOARD", $sformatf("=== TEST COMPLETE: FINAL RESULTS ==="), UVM_LOW)
        `uvm_info("SCOREBOARD", $sformatf("Total test cases: %d", test_count), UVM_LOW)
        `uvm_info("SCOREBOARD", $sformatf("Final error count: %d", error_count), UVM_LOW)

        // display final test message
        if (error_count == 0) begin
            `uvm_info("SCOREBOARD", $sformatf("=== TEST PASSED! ==="), UVM_LOW)
        end else begin
            `uvm_error("SCOREBOARD", "=== TEST FAILED! ===")
        end
    endfunction
endclass

// - - - - - COVERAGE - - - - - //
class decode_coverage extends uvm_subscriber #(decode_transaction);
    `uvm_component_utils(decode_coverage)

    // covergroups
    covergroup decode_covergroup with function sample(decode_transaction tr);
        
        // basic opcode coverage
        cp_opcode: coverpoint tr.instr[6:0] {
            bins r_type  = {R_TYPE};
            bins i_load = {I_TYPE0};
            bins i_arith = {I_TYPE1};
            bins i_jalr = {I_TYPE2};
            bins s_type  = {S_TYPE};
            bins b_type  = {B_TYPE};
            bins u_lui = {U_TYPE0};
            bins u_auipc = {U_TYPE1};
            bins j_type  = {J_TYPE};
        }
        
        // funct3 coverage
        cp_funct3: coverpoint tr.instr[14:12] {
            bins r_type_funct3[] = {[0:7]} iff (tr.instr[6:0] == R_TYPE);
            bins i_load_funct3[] = {0,1,2,4,5} iff (tr.instr[6:0] == I_TYPE0);
            bins i_arith_funct3[] = {[0:7]} iff (tr.instr[6:0] == I_TYPE1);
            bins i_jalr_funct3[] = {0} iff (tr.instr[6:0] == I_TYPE2);
            bins s_type_funct3[] = {[0:2]} iff (tr.instr[6:0] == S_TYPE);
            bins b_type_funct3[] = {0,1,4,5,6,7} iff (tr.instr[6:0] == B_TYPE);
        }

        // funct7 coverage
        cp_funct7: coverpoint tr.instr[31:25] iff (tr.instr[6:0] == R_TYPE) {
            bins std = {7'h00};
            bins alt = {7'h20};
        }

        // immediate coverage
        cp_immediate: coverpoint tr.instr[31:20] iff (tr.instr[6:0] inside {I_TYPE0, I_TYPE1, I_TYPE2}) {
            bins zero = {12'h000};
            bins neg_one = {12'hFFF};
            bins max = {7'h7FF};
            bins min = {7'h800};
        }

        // cross coverage
        cx_opcode_funct3: cross cp_opcode, cp_funct3;

    endgroup

    // constructor
    function new(string name = "decode_coverage", uvm_component parent);
        super.new(name, parent);
        decode_covergroup = new();
        decode_covergroup.start();
    endfunction

    // write function
    function void write(decode_transaction t);
        decode_covergroup.sample(t);
    endfunction

    // report phase
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COVERAGE", $sformatf("=== COVERAGE REPORT ==="), UVM_LOW)
        `uvm_info("COVERAGE", $sformatf("Total Decode Unit Coverage: %.2f%%", decode_covergroup.get_inst_coverage()), UVM_LOW)
        `uvm_info("COVERAGE", $sformatf("Opcode Coverage: %.2f%%", decode_covergroup.cp_opcode.get_inst_coverage()), UVM_LOW)
        `uvm_info("COVERAGE", $sformatf("Funct3 Value Coverage: %.2f%%", decode_covergroup.cp_funct3.get_inst_coverage()), UVM_LOW)
        `uvm_info("COVERAGE", $sformatf("Funct7 Value Coverage: %.2f%%", decode_covergroup.cp_funct7.get_inst_coverage()), UVM_LOW)
        `uvm_info("COVERAGE", $sformatf("Immediate Value Coverage: %.2f%%", decode_covergroup.cp_immediate.get_inst_coverage()), UVM_LOW)
        `uvm_info("COVERAGE", $sformatf("Opcode and Funct3 Cross-Coverage: %.2f%%", decode_covergroup.cx_opcode_funct3.get_inst_coverage()), UVM_LOW)
    endfunction
endclass

// - - - - - ENVIRONMENT - - - - - //
class decode_env extends uvm_env;
    `uvm_component_utils(decode_env)

    // declare components
    decode_agent agent;
    decode_scoreboard sb;
    decode_coverage cov;

    // constructor
    function new(string name = "decode_env", uvm_component parent);
        super.new(name, parent);
    endfunction

    // build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = decode_agent::type_id::create("agent", this);
        sb = decode_scoreboard::type_id::create("sb", this);
        cov = decode_coverage::type_id::create("cov", this);
    endfunction

    // connect phase
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.mon.ap.connect(sb.ap_imp);
        agent.mon.ap.connect(cov.analysis_export);
    endfunction
endclass

// - - - - - SEQUENCE - - - - - //
class decode_sequence extends uvm_sequence;
    `uvm_object_utils(decode_sequence)

    // constructor
    function new(string name = "decode_sequence");
        super.new(name);
    endfunction

    // sequence functional block
    task body();

        // declare pointer to transaction class
        decode_transaction req;

        // start the sequence of 1000 transactions
        repeat(1000) begin
            req = decode_transaction::type_id::create("req");
            start_item(req);

            // randomize the transaction before driving to DUT
            if (!req.randomize()) begin
                `uvm_error("SEQUENCE", $sformatf("Randomization failed!"))
            end

            // send transaction to the driver
            finish_item(req);
        end
    endtask
endclass

// - - - - - TEST - - - - -//
class decode_test extends uvm_test;
    `uvm_component_utils(decode_test)

    // environment class pointer declaration
    decode_env env;

    // constructor
    function new(string name = "decode_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    // build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = decode_env::type_id::create("env", this);
    endfunction

    // run phase
    task run_phase(uvm_phase phase);
        decode_sequence seq;

        // run simulation for test duration
        phase.raise_objection(this);

        // create amd start test seq
        seq = decode_sequence::type_id::create("seq");
        seq.start(env.agent.sqr);
        #10;

        // end the simulation
        phase.drop_objection(this);
    endtask
endclass

// - - - - - TOP - - - - - // 
module tb_decode_top;

    // clk generation
    logic clk = 0;
    always #5 clk = ~clk;

    // instantiate the interface
    decode_if decode_if_instance(.clk(clk));

    // instantiate the DUT
    decode DUT(
        .instr_i(decode_if_instance.instr_i),
        .rs1_o(decode_if_instance.rs1_o),
        .rs2_o(decode_if_instance.rs2_o),
        .rd_o(decode_if_instance.rd_o),
        .op_o(decode_if_instance.op_o),
        .funct3_o(decode_if_instance.funct3_o),
        .funct7_o(decode_if_instance.funct7_o),
        .r_type_instr_o(decode_if_instance.r_type_instr_o),
        .i_type_instr_o(decode_if_instance.i_type_instr_o),
        .s_type_instr_o(decode_if_instance.s_type_instr_o),
        .b_type_instr_o(decode_if_instance.b_type_instr_o),
        .u_type_instr_o(decode_if_instance.u_type_instr_o),
        .j_type_instr_o(decode_if_instance.j_type_instr_o),
        .instr_imm_o(decode_if_instance.instr_imm_o)
    );

    // dumpfile creation
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0,tb_decode_top);
    end

    // uvm testbench
    initial begin
        uvm_config_db#(virtual decode_if)::set(null, "*", "vif", decode_if_instance);
        run_test("decode_test");
    end
endmodule