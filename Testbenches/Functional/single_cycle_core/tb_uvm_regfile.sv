// ----------------------------------------- //
// --------- REGFILE TESTBENCH UVM --------- //
// ----------------------------------------- //

// import packages and stuff
import uvm_pkg::*;
`include "uvm_macros.svh"

// --------- TRNSACTION ---------- //
class regfile_transaction extends uvm_sequence_item;

    // regfile input signals
    rand logic [4:0]  rs1_addr;
    rand logic [4:0]  rs2_addr;
    rand logic [4:0]  rd_addr; 
    rand logic        wr_en;
    rand logic [31:0] wr_data;

    // regfile outputs
    logic [31:0] rs1_data;
    logic [31:0] rs2_data;

    // constraints to guide the random stimulus gen
    constraint valid_reg_addr {
        rs1_addr inside {[0:31]};
        rs2_addr inside {[0:31]};
        rd_addr inside {[0:31]};
    }

    // field macros - enable functiuon calls on this transaction to operate on all fields
    `uvm_object_utils_begin(regfile_transaction)
        `uvm_field_int(rs1_addr, UVM_ALL_ON)
        `uvm_field_int(rs2_addr, UVM_ALL_ON)
        `uvm_field_int(rd_addr, UVM_ALL_ON)
        `uvm_field_int(wr_en, UVM_ALL_ON)
        `uvm_field_int(wr_data, UVM_ALL_ON)
        `uvm_field_int(rs1_data, UVM_ALL_ON)
        `uvm_field_int(rs2_data, UVM_ALL_ON)
    `uvm_object_utils_end

    // constructor is required for all UVM objects - registers the class with the UVM factory
    function new(string name = "regfile_transaction");
        super.new(name);
    endfunction
endclass


// --------- SEQUENCER ---------- //
class regfile_sequencer extends uvm_sequencer #(regfile_transaction);
    `uvm_component_utils(regfile_sequencer)

    // constructor
    function new(string name = "regfile_sequencer", uvm_component parent);
        super.new(name, parent);
    endfunction
endclass

// ---------- INTERFACE ---------- //
interface regfile_if(input logic clk);

    // logic connects the driver and monitor to the DUT
    logic         reset_n;
    logic [4:0]   rs1_addr_i;
    logic [4:0]   rs2_addr_i;
    logic [4:0]   rd_addr_i;
    logic         wr_en_i;
    logic [31:0]  wr_data_i;
    logic [31:0]  rs1_data_o;
    logic [31:0]  rs2_data_o;

endinterface

// ---------- DRIVER ---------- //
class regfile_driver extends uvm_driver #(regfile_transaction);
    `uvm_component_utils(regfile_driver)

    // interface for the driver to connect to the sequencer
    virtual regfile_if vif;

    // constructor - create the driver
    function new(string name = "regfile_driver", uvm_component parent);
        super.new(name, parent);
    endfunction

    // build phase actually instantiates the driver
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // error handling if no interface is detected
        if (!uvm_config_db#(virtual regfile_if)::get(this,"","vif", vif))
            `uvm_fatal("DRIVER", "Virtual interface not found.");
    endfunction

    // run phase is the task that governs the drivers continuous behavior
    task run_phase(uvm_phase phase);
        
        // instantiate a transaction
        regfile_transaction req;

        // continually get transactions from sequencer, drive them, and then let thesequencer your done
        forever begin
            seq_item_port.get_next_item(req);
            drive_transaction(req);
            seq_item_port.item_done();
        end
    endtask

    // task for driving an individual transaction to the DUT
    task drive_transaction(regfile_transaction req);

        // at the positive edge of ethe interface clock, drive dut with transaction
        @(posedge vif.clk);
        vif.rs1_addr_i  <= req.rs1_addr;
        vif.rs2_addr_i  <= req.rs2_addr;
        vif.rd_addr_i   <= req.rd_addr;
        vif.wr_en_i     <= req.wr_en;
        vif.wr_data_i   <= req.wr_data;
    endtask
endclass

// ---------- MONITOR ---------- //
class regfile_monitor extends uvm_monitor;
    `uvm_component_utils(regfile_monitor);

    // declare the interface for output viewing
    virtual regfile_if vif;
    uvm_analysis_port #(regfile_transaction) ap;

    // build phase for the monitor 
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual regfile_if)::get(this, "", "vif", vif))
            `uvm_fatal("MONITOR", "Virtual interface not found!")

        // create an analysis port
        ap = new("ap", this);
    endfunction

    // run phase - observe the DUT outputs
    task run_phase (uvm_phase phase);

        // pointer to regfile_transaction class so that we can instantiate many of them
        regfile_transaction tr;

        // on every cycle, create a new transaction object and observe DUT values
        forever begin
            @(posedge vif.clk);
            tr = regfile_transaction::type_id::create("tr");
            tr.rs1_addr  = vif.rs1_addr_i;
            tr.rs2_addr  = vif.rs2_addr_i;
            tr.rd_addr   = vif.rd_addr_i;
            tr.wr_en     = vif.wr_en_i;
            tr.wr_data   = vif.wr_data_i;
            tr.rs1_data  = vif.rs1_data_o;
            tr.rs2_data  = vif.rs2_data_o;

            // give the transaction to the scoreboard
            ap.write(tr);
        end
    endtask

    // monitor constructor
    function new(string name = "regfile_monitor", uvm_component parent);
        super.new(name, parent);
    endfunction
endclass 

// ---------- AGENT ---------- //
class regfile_agent extends uvm_agent;
    `uvm_component_utils(regfile_agent)
    
    // instantiate driver, monitor, and sequencer
    regfile_sequencer sqr;
    regfile_driver drv;
    regfile_monitor mon;

    // build phase (assemble the driver, monitor, sequence, and DUT) 
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // always create passive components (monitor)
        mon = regfile_monitor::type_id::create("mon", this);

        // create sequencer and driver in active agents
        if (get_is_active() == UVM_ACTIVE) begin
            sqr = regfile_sequencer::type_id::create("sqr", this);
            drv = regfile_driver::type_id::create("drv", this);
        end
    endfunction

    // connect phase coordinates the components within the agent
    function connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // connect the driver to the sequencer if the agent is active
        if (get_is_active() == UVM_ACTIVE) begin
            drv.seq_item_port.connect(sqr.seq_item_export);
        end
    endfunction

    // constructor
    function new(string name = "regfile_agent", uvm_component parent);
        super.new(name, parent);
    endfunction
endclass

// ---------- ENVIRONMENT ---------- // 
class regfile_env extends uvm_env;
    `uvm_component_utils(regfile_env)

    // comopnents declaration
    regfile_agent agent;
    regfile_scoreboard sb;
    
    // constructor
    function new(string name = "regfile_env", uvm_component parent);
        super.new(name, parent);
    endfunction

    // build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // create agent and scoreboard components
        agent = regfile_agent::type_id::create("agent", this);
        sb = regfile_scoreboard::type_id::create("sb", this);
    endfunction

    // connect phase
    function connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // connect the scoreboard's analysos port to that ofthe agent
        agent.mon.ap.connect(sb.ap_imp);
    endfunction
endclass

// ---------- SCOREBOARD ---------- //
class regfile_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(regfile_scoreboard)

    // analysis port to receive transaction from the monitor
    uvm_analysis_imp #(regfile_transaction, regfile_scoreboard) ap_imp;

    // stats for tracking correctness
    int transactions_checked;
    int error_count;

    // "golden" software model of the regfile
    logic [31:0] golden_regfile [32];

    // constructor
    function new(string name = "regfile_scoreboard", uvm_component parent);
        super.new(name, parent);
    endfunction

    // build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // instantiate the new analysis port
        ap_imp = new("ap_imp", this);

        // initialize the golden model
        for (int i = 0; i < 32; i++) begin
           golden_regfile[i] = 32'b0; 
        end

        // initialize stats
        transactions_checked = 0;
        error_count = 0;
    endfunction

    function void write(regfile_transaction tr);
        
        // increment transaction counter
        transactions_checked++;

        // update reference model to begin the write
        if (tr.wr_en && tr.rd_addr != 0) begin
            golden_regfile[tr.rd_addr] = tr.wr_data;
        end

        // always lock register 0 at 32'b0;
        golden_regfile[0] = 0;

        // check of the golden transaction matches the dut transaction
        check_read_data(tr);

        // occasionally print progress
        if (transactions_checked % 100 == 0) begin
            `uvm_info("SCOREBOARD", $sformatf("Checked %0d transactions, %0d errors found.", transactions_checked, error_count), UVM_MEDIUM)
        end
    endfunction

    // check that the contents of the golden regfile match that of the DUT
    function void check_read_data(regfile_transaction tr);

        // check rs1
        if (tr.rs1_data != golden_regfile[tr.rs1_addr]) begin
            `uvm_error("SCOREBOARD", $sformatf("RS1 content mismatch: addr = %0d, expected_value = %0h, actual_value = %0h", tr.rs1_addr, golden_regfile[tr.rs1_addr], tr.rs1_data))
            error_count++;
        end

        // check rs2
        if (tr.rs2_data != golden_regfile[tr.rs2_addr]) begin
            `uvm_error("SCOREBOARD", $sformatf("RS2 content mismatch: addr = %0d, expected_value = %0h, actual_value = %0h", tr.rs2_addr, golden_regfile[tr.rs2_addr], tr.rs2_data))
            error_count++;
        end


        // check rs1 is zero register
        if (tr.rs1_addr == 0 && tr.rs1_data != 0) begin
            `uvm_error("SCOREBOARD", $sformatf("ZERO REGISTER MISMATCH: RS1 read from addr %0d resulted in %0h, should be 0 ", tr.rs1_addr, tr.rs1_data))
            error_count++;
        end
        
        // check rs2 if zero register
        if (tr.rs2_addr == 0 && tr.rs2_data != 0) begin
            `uvm_error("SCOREBOARD", $sformatf("ZERO REGISTER MISMATCH: RS2 read from addr %0d resulted in %0h, should be 0 ", tr.rs2_addr, tr.rs2_data))
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

// ---------- SEQUENCE ---------- //
class regfile_sequence extends uvm_sequence #(regfile_transaction);
    `uvm_object_utils(regfile_sequence)

    // constructor
    function new(string name = "regfile_base_sequence");
        super.new(name);
    endfunction

    // main sequence functional block
    task body();

        // call the transaction class
        regfile_transaction req;

        // seqence of 10 transactions
        repeat(10) begin

            // create a transaction
            req = regfile_transaction::type_id::create("req");

            // start the transaction
            start_item(req);

            // randomize the transaction (with constraints automatically applied)
            if (!req.randomize()) begin
                `uvm_error("SEQUENCE", $sformatf("Randomization failed!"))
            end

            // send the transaction to the driver
            finish_item(req);

            // print the dequence info
            `uvm_info("SEQUENCE", $sformatf("Generated: rs1_addr=%0d, rs2_addr=%0d, rd_addr=%0d, wr_en=%0b, wr_data=0x%0h", req.rs1_addr, req.rs2_addr, req.rd_addr, req.wr_en, req.wr_data), UVM_MEDIUM)
        end 
    endtask
endclass

// ---------- UVM TEST ---------- //
class regfile_test extends uvm_test;
    `uvm_component_utils(regfile_test)

    // instantiate the environment
    regfile_env env;

    // constructor
    function new(string name = "regfile_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    // build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // create the regfile test environment
        env = regfile_env::type_id::create("env", this);
    endfunction

    // run phase
    task run_phase(uvm_phase phase);
        
        regfile_sequence seq;

        // raise objection to keep the test running
        phase.raise_objection(this);

        // create and start test sequence
        seq = regfile_sequence::type_id::create("seq");

        // actually run the sequence in the env on the sequencer
        seq.start(env.agent.sqr);

        // extra delay to let the testbench finish running
        #100;

        // drop objection to end the test
        phase.drop_objection(this);
    endtask
endclass

// ----------- TOP MODULE ------------ // 
module tb_regfile_top;

    // clk generation logic
    logic clk = 0;
    always #5 clk = ~clk;

    // instantiate regfile interface
    regfile_if regfile_if_instance(.clk(clk));

    // instantiate DUT
    regfile DUT(
        .clk(regfile_if_instance.clk),
        .reset_n(regfile_if_instance.reset_n),
        .rs1_addr_i(regfile_if_instance.rs1_addr_i),
        .rs2_addr_i(regfile_if_instance.rs2_addr_i),
        .rd_addr_i(regfile_if_instance.rd_addr_i),
        .wr_en_i(regfile_if_instance.wr_en_i),
        .wr_data_i(regfile_if_instance.wr_data_i),
        .rs1_data_o(regfile_if_instance.rs1_data_o),
        .rs2_data_o(regfile_if_instance.rs2_data_o)
    );

    // reset sequence
    initial begin
        regfile_if_instance.reset_n = 0;
        #20;
        regfile_if_instance.reset_n = 1;
    end
    
    // UVM testbench
    initial begin

        // put the regfile_if in the UVM configuration database
        uvm_config_db#(virtual regfile_if)::set(null, "*", "vif", regfile_if_instance);

        // start the UVM test
        run_test("regfile_test");
    
    end
endmodule