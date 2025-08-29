// ----------------------------------------- //
// ----------- ALU TESTBENCH UVM ----------- //
// ----------------------------------------- //
// import riscv_package::*;
import uvm_pkg::*;
`include "uvm_macros.svh"

// R-type control signals in format {funct7[5] , funct3}
typedef enum logic [3:0] {
  ADD = 4'b0000,
  SLL = 4'b0001,
  SLT = 4'b0010,
  SLTU = 4'b0011,
  XOR = 4'b0100,
  SRL = 4'b0101,
  OR = 4'b0110,
  AND = 4'b0111,
  SUB = 4'b1000,
  SRA = 4'b1101
} r_type_t;

// ---------- TRANSACTION ---------- //
class alu_transaction extends uvm_sequence_item;

    // ALU inputs
    rand logic [31:0] opr_a;
    rand logic [31:0] opr_b;
    rand logic [3:0] op_sel;

    // ALU outputs
    logic [31:0] alu_res;

    // only randomly generate valid opcodes
    constraint valid_opcode_constraint {
      op_sel inside {ADD, SLL, SLT, SLTU, XOR, SRL, OR, AND, SUB, SRA};
    }

    // if the ALU is executing a shift operation, then constraint the shift amount
    constraint valid_shift_amount {
      (op_sel inside {SLL,SRL,SRA}) -> (opr_b[31:5] == 0);
    }

    // field macros
    `uvm_object_utils_begin(alu_transaction)
        `uvm_field_int(opr_a, UVM_ALL_ON)
        `uvm_field_int(opr_b, UVM_ALL_ON)
        `uvm_field_int(op_sel, UVM_ALL_ON)
        `uvm_field_int(alu_res, UVM_ALL_ON)
    `uvm_object_utils_end

    // constructtor
    function new(string name = "alu_transaction");
        super.new(name);
    endfunction
endclass

// --------- SEQUENCER ---------- //
class alu_sequencer extends uvm_sequencer #(alu_transaction);
    `uvm_component_utils(alu_sequencer)

    // constructor
    function new(string name = "alu_sequencer", uvm_component parent);
        super.new(name, parent);
    endfunction
endclass

// ---------- INTERFACE ---------- //
interface alu_if(input logic clk);

    // logic connects the driver and monitor to the DUT
    logic [31:0] opr_a_i;
    logic [31:0] opr_b_i;
    logic [3:0] op_sel_i;
    logic [31:0] alu_res_o;

endinterface

// ---------- DRIVER ---------- //
class alu_driver extends uvm_driver #(alu_transaction);
    `uvm_component_utils(alu_driver)

    // interface for the driver to connect to the sequencer
    virtual alu_if vif;

    // constructor - create the driver
    function new(string name = "alu_driver", uvm_component parent);
        super.new(name, parent);
    endfunction

    // build phase actually instantiates the driver
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // error handling if no interface is detected
        if (!uvm_config_db#(virtual alu_if)::get(this,"","vif", vif))
            `uvm_fatal("DRIVER", "Virtual interface not found.");
    endfunction

    // run phase is the task that governs the drivers continuous behavior
    task run_phase(uvm_phase phase);
        
        // instantiate a transaction
        alu_transaction req;

        // continually get transactions from sequencer, drive them, and then let thesequencer your done
        forever begin
            seq_item_port.get_next_item(req);
            drive_transaction(req);
            seq_item_port.item_done();
        end
    endtask

    // task for driving an individual transaction to the DUT
    task drive_transaction(alu_transaction req);

        // at the positive edge of ethe interface clock, drive dut with transaction
        @(posedge vif.clk);
        vif.opr_a_i  <= req.opr_a;
        vif.opr_b_i  <= req.opr_b;
        vif.op_sel_i <= req.op_sel;
    endtask
endclass

// ---------- MONITOR ---------- //
class alu_monitor extends uvm_monitor;
    `uvm_component_utils(alu_monitor)

    // declare the interface for output viewing
    virtual alu_if vif;

    // always declare an analysis port in the monitor
    uvm_analysis_port #(alu_transaction) ap;

    // monitor constructor
    function new(string name = "alu_monitor", uvm_component parent);
        super.new(name, parent);
    endfunction

    // build phase for the monitor 
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual alu_if)::get(this, "", "vif", vif))
            `uvm_fatal("MONITOR", "Virtual interface not found!")

        // always create an analysis port in the mointor
        ap = new("ap", this);
    endfunction

    // run phase - observe the DUT outputs
    task run_phase (uvm_phase phase);

        // pointer to alu_transaction class so that we can instantiate many of them
        alu_transaction tr;

        // on every cycle, create a new transaction object and observe DUT values
        forever begin
            @(posedge vif.clk);
            tr = alu_transaction::type_id::create("tr");
            tr.opr_a       = vif.opr_a_i;
            tr.opr_b       = vif.opr_b_i;
            tr.op_sel      = vif.op_sel_i;
            tr.alu_res  = vif.alu_res_o;

            // give the transaction to the scoreboard
            ap.write(tr);
        end
    endtask
endclass 

// ---------- SCOREBOARD ---------- //
class alu_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(alu_scoreboard)

    // analysis port to receive transaction from the monitor
    uvm_analysis_imp #(alu_transaction, alu_scoreboard) ap_imp;

    // stats for tracking correctness
    int transactions_checked;
    int error_count;

    // "golden" software model of the alu
    logic [31:0] golden_alu_res;

    // constructor
    function new(string name = "alu_scoreboard", uvm_component parent);
        super.new(name, parent);
    endfunction

    // build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // instantiate the new analysis port
        ap_imp = new("ap_imp", this);

        // initialize the golden model
        golden_alu_res = 0;

        // initialize stats
        transactions_checked = 0;
        error_count = 0;
    endfunction

    function void write(alu_transaction tr);
        
        // increment transaction counter
        transactions_checked++;

        // update the golden_alu_res based on the operands
        case (tr.op_sel)
            ADD: golden_alu_res = tr.opr_a + tr.opr_b;
            SUB: golden_alu_res = tr.opr_a - tr.opr_b;
            SLL: golden_alu_res = tr.opr_a << tr.opr_b[4:0];
            SRL: golden_alu_res = tr.opr_a >> tr.opr_b[4:0];
            SRA: golden_alu_res = $signed(tr.opr_a) >>> tr.opr_b[4:0];
            OR: golden_alu_res = tr.opr_a | tr.opr_b;
            AND: golden_alu_res = tr.opr_a & tr.opr_b;
            XOR: golden_alu_res = tr.opr_a ^ tr.opr_b;
          	SLTU: golden_alu_res = {31'h0, tr.opr_a < tr.opr_b};
          	SLT: golden_alu_res = {31'h0, $signed(tr.opr_a) < $signed(tr.opr_b)};
            default: golden_alu_res = '0;
        endcase

        // check of the golden transaction matches the dut transaction
        check_read_data(tr);

        // occasionally print progress
        //if (transactions_checked % 100 == 0) begin
        //  `uvm_info("SCOREBOARD", $sformatf("Checked %0d transactions, %0d errors found.", transactions_checked, error_count), UVM_MEDIUM)
        //end
    endfunction

    // check that the contents of the golden alu match that of the DUT
    function void check_read_data(alu_transaction tr);
        // check that the DUT output matches the golden output
        if (tr.alu_res != golden_alu_res) begin
            `uvm_error("SCOREBOARD", $sformatf("ERROR: Output mismatch. golden_alu_res: %0h, DUT alu_res: %0h, opr_a: %0d, opr_b: %0d, op_sel: %0d", golden_alu_res, tr.alu_res, tr.opr_a, tr.opr_b, tr.op_sel));
            error_count++;
        end
    endfunction

    // report the test stats
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        // display the stats
        `uvm_info("SCOREBOARD", $sformatf("=== FINAL RESULTS ==="), UVM_LOW)
        `uvm_info("SCOREBOARD", $sformatf("Total transactions checked: %0d", transactions_checked), UVM_LOW)
        `uvm_info("SCOREBOARD", $sformatf("Total error count: %0d", error_count), UVM_LOW)

        // final teste message
        if (error_count == 0) begin
            `uvm_info("SCOREBOARD", "*** TEST PASSED ***", UVM_LOW)
        end else begin
            `uvm_error("SCOREBOARD", "*** TEST FAILED ***")
        end
    endfunction
endclass


// ---------- AGENT ---------- //
class alu_agent extends uvm_agent;
    `uvm_component_utils(alu_agent)
    
    // instantiate driver, monitor, and sequencer
    alu_sequencer sqr;
    alu_driver drv;
    alu_monitor mon;

    // build phase (assemble the driver, monitor, sequence, and DUT) 
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // always create passive components (monitor)
        mon = alu_monitor::type_id::create("mon", this);

        // create sequencer and driver in active agents
        if (get_is_active() == UVM_ACTIVE) begin
            sqr = alu_sequencer::type_id::create("sqr", this);
            drv = alu_driver::type_id::create("drv", this);
        end
    endfunction

    // connect phase coordinates the components within the agent
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // connect the driver to the sequencer if the agent is active
        if (get_is_active() == UVM_ACTIVE) begin
            drv.seq_item_port.connect(sqr.seq_item_export);
        end
    endfunction

    // constructor
    function new(string name = "alu_agent", uvm_component parent);
        super.new(name, parent);
    endfunction
endclass

// ---------- COVERAGE---------- //
class alu_coverage extends uvm_subscriber #(alu_transaction);
    `uvm_component_utils(alu_coverage)

    // covergroup defines which metrics we want to reord
    covergroup alu_cg with function sample(alu_transaction tr);

        // option dictates that each instance of this covergroup gets separate tracking
        option.per_instance = 1;
        option.name = "ALU Coverage";
        
        // opration coverage
        cp_op_sel: coverpoint tr.op_sel {
            bins add_op = {ADD};
            bins sub_op = {SUB};
            bins sll_op = {SLL};
            bins srl_op = {SRL};
            bins sra_op = {SRA};
            bins or_op = {OR};
            bins and_op = {AND};
            bins xor_op = {XOR};
            bins sltu_op = {SLTU};
            bins slt_op = {SLT};
        }
    
        // cover operand A corner cases
        cp_opr_a: coverpoint tr.opr_a {
            bins zero = {32'd0};
            bins all_ones = {32'hFFFFFFFF};
            bins max_pos = {32'h7FFFFFFF};
            bins min_neg = {32'h80000000};
          	bins small_positive[] = {[1:100]};       
    		bins large_positive = {[32'h70000000:32'h7FFFFFFF]};
    		bins small_negative = {[32'hFFFFFF00:32'hFFFFFFFF]};
    		bins large_negative = {[32'h80000000:32'h8FFFFFFF]};
            bins other = default;
        }

        // cover operand B corner cases
        cp_opr_b: coverpoint tr.opr_b {
            bins zero = {32'd0};
            bins all_ones = {32'hFFFFFFFF};
            bins max_pos = {32'h7FFFFFFF};
            bins min_neg = {32'h80000000};
          	bins small_positive[] = {[1:100]};       
    		bins large_positive = {[32'h70000000:32'h7FFFFFFF]};
    		bins small_negative = {[32'hFFFFFF00:32'hFFFFFFFF]};
    		bins large_negative = {[32'h80000000:32'h8FFFFFFF]};
            bins other = default;
        }

        // shift amount coverage
        cp_shift_amt: coverpoint tr.opr_b iff (tr.op_sel inside {SLL, SRL, SRA}) {
            bins no_shift = {0};
            bins small_shift[] = {[1:7]};
            bins medium_shift[] = {[8:15]};
            bins large_shift[] = {[16:23]};
            bins max_shift[] = {[24:31]};
        }

        // cross coverage to evaluate ghow many input combinations we hit
        cx_cross_input: cross cp_op_sel, cp_opr_a, cp_opr_b {

            // ignore the "other" bins from the opr_a and opr_b coverpoints to save on sim time, targeting corners
            //ignore_bins ignore_non_corners = binsof(cp_opr_a.other) && binsof(cp_opr_b.other);
        } 

        // cross-coverage handling for shift operations with the shift_amount coverpoints
        cx_shifts: cross cp_op_sel, cp_shift_amt {
            bins sll = binsof(cp_op_sel.sll_op) && binsof(cp_shift_amt);
            bins srl = binsof(cp_op_sel.srl_op) && binsof(cp_shift_amt);
            bins sra = binsof(cp_op_sel.sra_op) && binsof(cp_shift_amt);
        }
    endgroup
    
    // constructor
    function new(string name = "alu_coverage", uvm_component parent);
        super.new(name, parent);
        alu_cg = new();
    endfunction

    // covergroup sample coverage on each transaction that occurs
    function void write(alu_transaction t);
        alu_cg.sample(t);
    endfunction

    // coverage report at the end of test
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        // print a detailed coverage report
        `uvm_info("COVERAGE", $sformatf("=== COVERAGE REPORT ==="), UVM_LOW);
        `uvm_info("COVERAGE", $sformatf("Total ALU Coverage: %.2f%%", alu_cg.get_inst_coverage()), UVM_LOW);
        `uvm_info("COVERAGE", $sformatf("Operation Coverage: %.2f%%", alu_cg.cp_op_sel.get_inst_coverage()), UVM_LOW);
        `uvm_info("COVERAGE", $sformatf("Operand A Coverage: %.2f%%", alu_cg.cp_opr_a.get_inst_coverage()), UVM_LOW);
        `uvm_info("COVERAGE", $sformatf("Operand B Coverage: %.2f%%", alu_cg.cp_opr_b.get_inst_coverage()), UVM_LOW);
        `uvm_info("COVERAGE", $sformatf("Input Cross Coverage: %.2f%%", alu_cg.cx_cross_input.get_inst_coverage()), UVM_LOW);
        `uvm_info("COVERAGE", $sformatf("Shift Operation Coverage: %.2f%%", alu_cg.cx_shifts.get_inst_coverage()), UVM_LOW);
    endfunction
endclass

// ---------- ENVIRONMENT ---------- // 
class alu_env extends uvm_env;
    `uvm_component_utils(alu_env)

    // comopnents declaration
    alu_agent agent;
    alu_scoreboard sb;
    alu_coverage cov;
    
    // constructor
    function new(string name = "alu_env", uvm_component parent);
        super.new(name, parent);
    endfunction

    // build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // create agent and scoreboard components
        agent = alu_agent::type_id::create("agent", this);
        sb = alu_scoreboard::type_id::create("sb", this);
        cov = alu_coverage::type_id::create("cov", this);
    endfunction

    // connect phase
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // connect the scoreboard's analysos port to that ofthe agent
        agent.mon.ap.connect(sb.ap_imp);
        agent.mon.ap.connect(cov.analysis_export);
    endfunction
endclass

// ---------- SEQUENCE ---------- //
class alu_sequence extends uvm_sequence #(alu_transaction);
    `uvm_object_utils(alu_sequence)

    // constructor
    function new(string name = "alu_base_sequence");
        super.new(name);
    endfunction

    // main sequence functional block
    task body();

        // call the transaction class
        alu_transaction req;

        // seqence of 10 transactions
        repeat(100000) begin

            // create a transaction
            req = alu_transaction::type_id::create("req");

            // start the transaction
            start_item(req);

            // randomize the transaction (with constraints automatically applied)
            if (!req.randomize()) begin
                `uvm_error("SEQUENCE", $sformatf("Randomization failed!"))
            end

            // send the transaction to the driver
            finish_item(req);

            // print the sequence info
            //`uvm_info("SEQUENCE", $sformatf("Generated: opr_a=%0d, opr_b=%0d, op_sel=%0d", req.opr_a, req.opr_b, req.op_sel), UVM_MEDIUM)
        end 
    endtask
endclass

// CORNER CASES
class corner_case_sequence extends uvm_sequence #(alu_transaction);
    `uvm_object_utils(corner_case_sequence)
    
    function new(string name = "corner_case_sequence");
        super.new(name);
    endfunction
    
    task body();
        alu_transaction req;
        logic [31:0] corner_values[] = {32'h00000000, 32'hFFFFFFFF, 32'h7FFFFFFF, 32'h80000000};
        
        // Use actual enum values instead of 0-9 loop
        r_type_t operations[] = {ADD, SLL, SLT, SLTU, XOR, SRL, OR, AND, SUB, SRA};
        
        // Test each corner value with each operation
        foreach(corner_values[i]) begin
            foreach(corner_values[j]) begin
                foreach(operations[k]) begin  // Use enum array instead of integer loop
                    req = alu_transaction::type_id::create("req");
                    start_item(req);
                    req.opr_a = corner_values[i];
                    req.opr_b = corner_values[j];  
                    req.op_sel = operations[k]; 
                    finish_item(req);
                end
            end
        end
    endtask
endclass

// ---------- UVM TEST ---------- //
class alu_test extends uvm_test;
    `uvm_component_utils(alu_test)

    // instantiate the environment
    alu_env env;

    // constructor
    function new(string name = "alu_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    // build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // create the alu test environment
        env = alu_env::type_id::create("env", this);
    endfunction

    // run phase
    task run_phase(uvm_phase phase);
        
        alu_sequence seq;
        corner_case_sequence seq1;

        // raise objection to keep the test running
        phase.raise_objection(this);

        // create and start test sequence
        seq = alu_sequence::type_id::create("seq");
        seq1 = corner_case_sequence::type_id::create("seq1");

        // actually run the sequence in the env on the sequencer
        seq.start(env.agent.sqr);
        seq1.start(env.agent.sqr);

        // extra delay to let the testbench finish running
        #100;

        // drop objection to end the test
        phase.drop_objection(this);
    endtask
endclass

// ----------- TOP MODULE ------------ // 
module tb_alu_top;

    // clk generation logic
    logic clk = 0;
    always #5 clk = ~clk;

    // instantiate alu interface
    alu_if alu_if_instance(.clk(clk));

    // instantiate DUT
    alu DUT(
        .opr_a_i(alu_if_instance.opr_a_i),
        .opr_b_i(alu_if_instance.opr_b_i),
        .op_sel_i(alu_if_instance.op_sel_i),
        .alu_res_o(alu_if_instance.alu_res_o)
    );

    // dumpfile creation
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_alu_top);
    end
    
    // UVM testbench
    initial begin

        // put the alu_if in the UVM configuration database
        uvm_config_db#(virtual alu_if)::set(null, "*", "vif", alu_if_instance);

        // start the UVM test
        run_test("alu_test");
    
    end
endmodule