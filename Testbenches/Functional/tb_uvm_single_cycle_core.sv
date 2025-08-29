// ----------------------------------------- //
// -- RV32I (SINGLE-CYCLE) TESTBENCH UVM --- //
// ----------------------------------------- //
import uvm_pkg::*;
`include "uvm_macros.svh"

// ---------- TRANSACTION ---------- //
class rv32i_instr_transaction extends uvm_sequence_item;
    
    // program counter and instr signals
    logic [31:0] pc;
    logic [31:0] pc_next;
    logic [31:0] instruction;

    // data memory state variables
    logic [31:0] mem_addr;
    logic [31:0] mem_wr_data;
    logic [31:0] mem_rd_data;
    logic [1:0]  mem_byte_en;
    logic        mem_wr;
    logic        mem_req;

    // control flow
    logic        branch_taken;

    // field macros dictate how builtin functions operate on transaction fields
    `uvm_object_utils_begin(rv32i_instr_transaction)
        `uvm_field_int(pc, UVM_ALL_ON | UVM_HEX)               // print PC in hex
        `uvm_field_int(instruction, UVM_ALL_ON | UVM_HEX)      // print instruction in hex
        `uvm_field_int(pc_next, UVM_ALL_ON | UVM_HEX)          // print next_pc in hex
        `uvm_field_int(mem_req, UVM_ALL_ON)
        `uvm_field_int(mem_wr, UVM_ALL_ON)
        `uvm_field_int(mem_addr, UVM_ALL_ON | UVM_HEX)         // print addresses in hex
        `uvm_field_int(mem_wr_data, UVM_ALL_ON | UVM_HEX)      // print memory data in hex
        `uvm_field_int(mem_rd_data, UVM_ALL_ON | UVM_HEX)      // print memory data in hex
        `uvm_field_int(mem_byte_en, UVM_ALL_ON)
        `uvm_field_int(branch_taken, UVM_ALL_ON)
    `uvm_object_utils_end

    // consructor
    function new(string name="rv32i_instr_transaction");
        super.new(name);
    endfunction

    // helper to determine if the transaction writes to data mem
    function bit is_store();
        return (mem_req && mem_wr);
    endfunction

    // helper to detect if the transactionreads from data mem
    function bit is_load();
        return (mem_req && !mem_wr);
    endfunction
    
    // check if the instruction is a read|write
    function bit is_mem_access();
        return (mem_req);
    endfunction

    // helper to determine if transactionis a branch instr
    function bit is_branch();
        return (branch_taken || (pc_next != pc + 4));
    endfunction

endclass

// ---------- INTERFACE ---------- //
interface rv32i_if(input logic clk);

    // control signals
    logic reset_n;

    // instr memory interface signals
    logic        instr_mem_req;
    logic [31:0] instr_mem_addr;
    logic [31:0] instr_mem_data;

    // data memory interface signals
    logic        data_mem_req;
    logic        data_mem_wr;
    logic        data_mem_zero_extnd;
    logic [1:0]  data_mem_byte_en;
    logic [31:0] data_mem_wr_data;
    logic [31:0] data_mem_rd_data;
    logic [31:0] data_mem_addr;

    // enfore that driver drives reset AFTER clock edge
    clocking driver_cb @(posedge clk);
        output reset_n;
    endclocking

    // enforce that mointor samples BEFORE clk edge
    clocking monitor_cb @(posedge clk);
        input reset_n;
        input instr_mem_req;
        input instr_mem_addr;
        input instr_mem_data;
        input data_mem_req;
        input data_mem_wr;
        input data_mem_zero_extnd;
        input data_mem_byte_en;
        input data_mem_wr_data;
        input data_mem_addr;
        input data_mem_rd_data;
    endclocking

    // for connecting the driver to interface clocking block
    modport driver (
        clocking driver_cb,
        input    clk
    );

    // for connecting the monitor to interface clocking block
    modport monitor (
        clocking monitor_cb,
        input    clk
    );

    // helper task to apply reset sequence
    task apply_reset(int reset_cycles = 10);
        
        $display("[%0t] Applying reset for %0d cycles.", $time, reset_cycles);
        reset_n <= 1'b0;
        repeat(reset_cycles) @(posedge clk);
        @(posedge clk);
        reset_n <= 1'b1;
        $display("[%0t] Reset deasserted.", $time);

    endtask

    // helper task to wait for program completion/detect infinite loops
    task wait_for_program_completion(int cycle_timeout = 1000000); 

        // compare last to curr to find loops at end of test programs
        static logic [31:0] last_pc = 32'hFFFFFFFF;
        logic [31:0] curr_pc;
        
        // for tracking infinite loop progress/timeout
        static int same_pc_count = 0;
        static int cycle_count = 0;      	

        // keep checking for infinite loops until we hit timeout
        while (cycle_count < cycle_timeout) begin
          @(posedge clk);
          	cycle_count++;

            // if an instriction is issued, then increment pc tracker
            if (instr_mem_req && reset_n) begin
                curr_pc = instr_mem_addr;

                //debug
      			`uvm_info("INTERFACE", $sformatf("Current PC = %0h, last PC = %0h, current data_mem_req = %0h", curr_pc, last_pc, data_mem_req), UVM_LOW);
                
              	// check for loop
                if (last_pc == curr_pc) begin
                    same_pc_count++;

                    // at cycle 10 we'll call the loop infinite
                    if (same_pc_count == 10) begin
                        $display("[%0t] PROGRAM COMPLETED: Infinite loop detected at PC = %0h.", $time, curr_pc);
                        return;
                    end
                end else begin
                    same_pc_count = 0;
                end
                last_pc = curr_pc;
            end
        end

        // if we exhaust the timeout, then display error
        $error("[%0t] ERROR: Cycle timeout reached, program incomplete.", $time);

    endtask

    // helper to determine whether we are actively fetching instructions
    function bit is_fetching();
        return (instr_mem_req && reset_n);
    endfunction

    // check for data mem access
    function bit is_load();
        return (data_mem_req && reset_n);
    endfunction

    // obtaint he current PC value
    function logic [31:0] get_pc();

        // only return something if cpu is active
        if (instr_mem_req && reset_n) begin
            return instr_mem_addr;
        end else begin
            return 32'hXXXXXXXX;
        end

    endfunction

    // assert that the instruction addresses are byte aligned
    property instr_addr_aligned;
        @(posedge clk) disable iff(!reset_n)
            instr_mem_req |-> (instr_mem_addr[1:0] == 2'b00);
    endproperty

    assert property(instr_addr_aligned)
        else $error("ERROR: Instruction address misaligned: 0x%08h", instr_mem_addr);

    // assert that the data word addresses are byte aligned
    property data_addr_aligned;
        @(posedge clk) disable iff(!reset_n)
            (data_mem_req && data_mem_byte_en == 2'b11) |-> (data_mem_addr[1:0] == 2'b00);
    endproperty
    
    assert property(data_addr_aligned)
        else $error("ERROR: Data address misaligned: 0x%08h", data_mem_addr);

endinterface

// ---------- MONITOR ---------- //
class rv32i_monitor extends uvm_monitor;
    `uvm_component_utils(rv32i_monitor)

    // instantiate virtual interface
    virtual rv32i_if vif;

    // declare an analysis port to broadcast transactions to scoreboard
    uvm_analysis_port #(rv32i_instr_transaction) ap;

    // constructor
    function new (string name = "rv32i_monitor", uvm_component parent);
        super.new(name, parent);
    endfunction

    // build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // get vif from the config database
        if (!uvm_config_db#(virtual rv32i_if)::get(this,"", "vif", vif)) begin
            `uvm_fatal("MONITOR", "Virtual interface not found.");
        end

        // instantiate the analysis port
        ap =new("ap", this);
    endfunction


    // run phase - observe the DUT and create the transactions to pass to scoreboard
    task run_phase(uvm_phase phase);
        rv32i_instr_transaction tr;

        // create a new transaction on every cycle and capture the DUT state 
        forever begin
            @(vif.monitor_cb);

            // don't capture dring reset
            if (!vif.monitor_cb.reset_n) continue;

            // if an instruction is fetched, capture
            if (vif.monitor_cb.instr_mem_req) begin

                // create transaction instance and populate its fields
                tr = rv32i_instr_transaction::type_id::create("tr");
                
                // instr fields
                tr.pc               =   vif.monitor_cb.instr_mem_addr;
                tr.instruction      =   vif.monitor_cb.instr_mem_data;

                // data fields
                tr.mem_req          =   vif.monitor_cb.data_mem_req;
                tr.mem_byte_en      =   vif.monitor_cb.data_mem_byte_en;
                tr.mem_wr           =   vif.monitor_cb.data_mem_wr; 
                tr.mem_wr_data      =   vif.monitor_cb.data_mem_wr_data;
                tr.mem_rd_data      =   vif.monitor_cb.data_mem_rd_data;
                tr.mem_addr         =   vif.monitor_cb.data_mem_addr;
               
                // add logic later??
                tr.pc_next          =   tr.pc + 4;
                tr.branch_taken     =   1'b0;

                // write the transaction to the scoreboard
                ap.write(tr);
            end
        end
    endtask
endclass

// ---------- DRIVER ---------- //
class rv32i_driver extends uvm_driver;
    `uvm_component_utils(rv32i_driver)

    // virtual interface for controlling the DUT
    virtual rv32i_if vif;

    // constructor
    function new(string name = "rv32i_driver", uvm_component parent);
        super.new(name, parent);
    endfunction

    // build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // get the virtuak interface from the configuration database
        if (!uvm_config_db#(virtual rv32i_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("DRIVER", "Virtual interface not found");
        end
    endfunction
    
    // run phase
    task run_phase (uvm_phase phase);
        `uvm_info("DRIVER", "Beginning RISC-V test sequence", UVM_LOW)
        run_loaded_program();
        `uvm_info("DRIVER", "Finished RISC-V test sequence", UVM_LOW)
    endtask  

    task run_loaded_program ();
        `uvm_info("DRIVER", "===== LOADED PROGRAM TEST =====", UVM_LOW)
        
        // reset sequence
        `uvm_info("DRIVER", "Running reset sequence", UVM_LOW)
        vif.apply_reset(10);

        // run the pre-loaded program
        `uvm_info("DRIVER", "Waiting on program execution", UVM_LOW)
      	vif.wait_for_program_completion(1000000);

        // program conclusion
        `uvm_info("DRIVER", "Test complete", UVM_LOW)

        // check test results
        check_test_results();
        
    endtask

    task check_test_results();
    endtask
endclass

// ---------- AGENT ---------- //
class rv32i_agent extends uvm_agent;
    `uvm_component_utils(rv32i_agent)

    // declare poinyers to driver and monitor
    rv32i_driver drv;
    rv32i_monitor mon;

    // constructor
    function new(string name = "rv32i_agent", uvm_component parent);
        super.new(name, parent);
    endfunction

    // build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // instantiate the driver
        if (get_is_active() == UVM_ACTIVE) begin
            drv = rv32i_driver::type_id::create("drv", this);
        end
        
        // instantiate the monitor
        mon = rv32i_monitor::type_id::create("mon", this);
    
    endfunction
endclass

// ---------- SCOREBOARD ---------- //
class rv32i_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(rv32i_scoreboard)

    // analysis port declaration
    uvm_analysis_imp #(rv32i_instr_transaction, rv32i_scoreboard) ap_imp;

    // variables for tracking test stats
    int total_instructions = 0;
    int total_stores = 0;
    int total_loads = 0;
    int total_branches = 0;
    
    // for tracking program state
    bit program_complete = 0;
    logic [31:0] final_store_addr = 32'hXXXXXXXX;
    logic [31:0] final_store_data = 32'hXXXXXXXX;

    // for now, hard code expected test results
    logic [31:0] expected_store_addr = 32'h0;
    logic [31:0] expected_store_data = 32'h12;

    // constructor
    function new(string name = "rv32i_scoreboard", uvm_component parent);
        super.new(name, parent);
    endfunction

    // build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // create analysis import to receive trnsactions
        ap_imp = new("analysis_imp", this);

        // print the expected results
        `uvm_info("SCOREBOARD", $sformatf("Expecting result 0x%08h at address 0x%08h", expected_store_data, expected_store_addr), UVM_MEDIUM)
    endfunction

    // for writing each transaction
    function void write(rv32i_instr_transaction tr);
    
        // increment total instructions
        total_instructions++;

        // track memory operations
        if (tr.is_mem_access()) begin

            // store handling
            if (tr.is_store()) begin
                total_stores++;

                // store the address and data for final check
                final_store_addr = tr.mem_addr;
                final_store_data = tr.mem_wr_data;

                // print the store information
                `uvm_info("SCOREBOARD", $sformatf("STORE: ADDR=0x%08h, DATA=0x%08h", tr.mem_addr, tr.mem_wr_data), UVM_HIGH)

            // load handling
            end else if (tr.is_load()) begin
                total_loads++;

                // print the store information
                `uvm_info("SCOREBOARD", $sformatf("LOAD: ADDR=0x%08h, DATA=0x%08h", tr.mem_addr, tr.mem_rd_data), UVM_HIGH)
            end 
        end

        // branch handling
        if (tr.is_branch()) begin
            total_branches++;

            // print info
            `uvm_info("SCOREBOARD", $sformatf("BRANCH: PC: %0h -> %0h", tr.pc, tr.pc_next), UVM_LOW)
        end
    endfunction

    // for checking program execution resulted in correct final state
    function check_program_results();
        `uvm_info("SCOREBOARD", "=== CHECKING FINAL TEST RESULTS ===", UVM_LOW)

        // perform check on the final data
        if (final_store_data == expected_store_data && (final_store_addr == expected_store_addr)) begin
            `uvm_info("SCOREBOARD", $sformatf("=== TEST PASSED ==="), UVM_LOW)
        end else begin
            `uvm_info("SCOREBOARD", $sformatf("TEST FAILED: Expected %0d at %0h, got %0d at %0h", expected_store_data, expected_store_addr, final_store_data, final_store_data), UVM_LOW)
        end
    endfunction

    // report phase 
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        `uvm_info("SCOREBOARD", "=== EXECUTION STATISTICS ===", UVM_LOW)
        `uvm_info("SCOREBOARD", $sformatf("Total Instructions: %0d", total_instructions), UVM_LOW)
        `uvm_info("SCOREBOARD", $sformatf("Memory Stores: %0d", total_stores), UVM_LOW)
        `uvm_info("SCOREBOARD", $sformatf("Memory Loads: %0d", total_loads), UVM_LOW)
        `uvm_info("SCOREBOARD", $sformatf("Branches Taken: %0d", total_branches), UVM_LOW)
        
    endfunction
endclass

// ---------- ENVIRONMENT ---------- //
class rv32i_env extends uvm_env;
    `uvm_component_utils(rv32i_env)

    // declare pointers to components
    rv32i_agent ag;
    rv32i_scoreboard sb;

    // constructor
    function new(string name = "rv32i_env", uvm_component parent);
        super.new(name, parent);
    endfunction

    // build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // create component instances
        ag = rv32i_agent::type_id::create("ag", this);
        sb = rv32i_scoreboard::type_id::create("sb", this);
    endfunction

    // connect phase
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // connect the monitor to the analysis port
        ag.mon.ap.connect(sb.ap_imp);
    endfunction
endclass


// ---------- TEST ---------- //
class rv32i_test extends uvm_test;
    `uvm_component_utils(rv32i_test)

    // declare pointer to environment
    rv32i_env env;
    
    // constructor
    function new(string name = "rv32i_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    // build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // create the environment
        env = rv32i_env::type_id::create("env", this);

    endfunction

    // run phase
    task run_phase (uvm_phase phase);
        phase.raise_objection(this);
        #100000;
        phase.drop_objection(this);
    endtask

    // // end of elaboration phase
    // function void end_of_elaboration_phase(uvm_phase phase);
    //     super.end_of_elaboration_phase(phase);

    //     // 

    // endfunction
endclass


// ---------- TOP ---------- //
module tb_rv32i_top;

    // clock gen
    logic clk = 0;
    always #5 clk = !clk;

    // interface instance
    rv32i_if dut_if(clk);

    // DUT instance
    top DUT(.clk(clk), .reset_n(dut_if.reset_n));

    // instruction memory interface connections
    assign dut_if.instr_mem_req  = DUT.instr_mem_req;
    assign dut_if.instr_mem_addr = DUT.instr_mem_addr;
    assign dut_if.instr_mem_data = DUT.instr_mem_data;
    
    // data memory interface connections
    assign dut_if.data_mem_req        = DUT.data_mem_req;
    assign dut_if.data_mem_wr         = DUT.data_mem_wr;
    assign dut_if.data_mem_zero_extnd = DUT.data_mem_zero_extnd;
    assign dut_if.data_mem_byte_en    = DUT.data_mem_byte_en;
    assign dut_if.data_mem_wr_data    = DUT.data_mem_wr_data;
    assign dut_if.data_mem_addr       = DUT.data_mem_addr;
    assign dut_if.data_mem_rd_data    = DUT.data_mem_rd_data;

    // file dump
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_rv32i_top);
        #100000;
        $dumpoff;
    end

    // run the UVM test
    initial begin

        // register the interface with config db and start test
        uvm_config_db#(virtual rv32i_if)::set(null, "*", "vif", dut_if);
        run_test("rv32i_test");
    end

    initial begin
        // Wait a moment for DUT initialization
        #1;
        
        $display("========================================");
        $display("RISC-V CPU Testbench Starting");
        $display("========================================");
        
        // Load simple ADD test program:
        // Program: 5 + 7 = 12, store result at address 0
        $display("Loading ADD test program into instruction memory...");
        
        // Memory layout: [instruction] // assembly equivalent
        DUT.IMEM.instr_mem_array[0] = 32'h00500093;  // li x1, 5      (addi x1, x0, 5)
        DUT.IMEM.instr_mem_array[1] = 32'h00700113;  // li x2, 7      (addi x2, x0, 7)
        DUT.IMEM.instr_mem_array[2] = 32'h002081b3;  // add x3, x1, x2
        DUT.IMEM.instr_mem_array[3] = 32'h0030a023;  // sw x3, 0(x0)  (store result at address 0)
        DUT.IMEM.instr_mem_array[4] = 32'h0000006f;  // j 4           (infinite loop: j .)
        
        // Initialize remaining instruction memory to NOPs
        for (int i = 5; i < 1024; i++) begin
            DUT.IMEM.instr_mem_array[i] = 32'h00000013;  // NOP (addi x0, x0, 0)
        end
        
        // Initialize data memory to zeros
        for (int i = 0; i < 1024; i++) begin
            DUT.DMEM.data_mem_array[i] = 32'h00000000;
        end
        
        $display("Program loaded successfully!");
        $display("Expected execution sequence:");
        $display("  1. Load 5 into register x1");
        $display("  2. Load 7 into register x2");
        $display("  3. Add x1 + x2 = 12, store in x3");
        $display("  4. Store x3 (12) to memory address 0");
        $display("  5. Jump to infinite loop");
        $display("Expected result: memory[0] = 12 (0x0000000C)");
        $display("========================================");
    end
endmodule