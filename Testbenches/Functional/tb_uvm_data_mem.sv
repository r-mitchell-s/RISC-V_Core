// ----------------------------------------- //
// ----------- DATA MEM TESTBENCH ---------- //
// ----------------------------------------- //
// import riscv_package::*;
import uvm_pkg::*;
`include "uvm_macros.svh"

// macros defined in riscv_pkg for byte_en
typedef enum logic [1:0] {
    BYTE,
    HALF_WORD,
    RESERVED,
    WORD
  } mem_access_size_t;

// ---------- TRANSACTION ---------- //
class data_mem_transaction extends uvm_sequence_item;

    // INPUTS
    rand logic req;
    rand logic [31:0] addr;
    rand logic [1:0] byte_en;
    rand logic wr_en;
    rand logic [31:0] wr_data;
    rand logic zero_extnd;

    // OUTPUTS
    logic [31:0] rd_data;

    // valid byte_en constraint
    constraint valid_byte_en {
        byte_en inside {BYTE, HALF_WORD, WORD};
    }

    // valid address constraint for 1024 word memory (4096 bytes)
    constraint valid_addr {
        addr < 32'h1000;
    }

    // constrain alignmennt based on the size of access occuring
    constraint valid_addr_alignment {

        // word access must be word-aligned
        (byte_en == WORD) -> (addr[1:0] == 2'b00);
        
        // half-word access must be half-word-aligned
        (byte_en == HALF_WORD) -> (addr[0] == 1'b0);
    }

    // make sure that linkedin inputs are consistently generated
    constraint req_coherency {
        !req -> {   wr_en == 0;
                    wr_data == 0;   }
    }

    // set the generation of transactions to be 70% reads, 30% writes
    constraint read_write_dist {
        wr_en dist {0 := 70, 1 := 30};
    }

    // field macros allow builtin functions to operate on transaction fields
    `uvm_object_utils_begin(data_mem_transaction)
        `uvm_field_int(req, UVM_ALL_ON)
        `uvm_field_int(addr, UVM_ALL_ON)
        `uvm_field_int(byte_en, UVM_ALL_ON)
        `uvm_field_int(wr_en, UVM_ALL_ON)
        `uvm_field_int(wr_data, UVM_ALL_ON)
        `uvm_field_int(zero_extnd, UVM_ALL_ON)
        `uvm_field_int(rd_data, UVM_ALL_ON)
    `uvm_object_utils_end

    // constructtor
    function new(string name = "data_mem_transaction");
        super.new(name);
    endfunction
endclass

// --------- SEQUENCER ---------- //
class data_mem_sequencer extends uvm_sequencer #(data_mem_transaction);
    `uvm_component_utils(data_mem_sequencer)

    // constructor creates sequencer
    function new(string name = "data_mem_sequencer", uvm_component parent);
        super.new(name, parent);
    endfunction
endclass

// ---------- INTERFACE ---------- //
interface data_mem_if(input logic clk);

    // interfce signal declarations
    logic          reset_n;
    logic          data_mem_req_i;
    logic [31:0]   data_mem_addr_i;
    logic [1:0]    data_mem_byte_en_i;
    logic          data_mem_wr_i;
    logic [31:0]   data_mem_wr_data_i;
    logic          data_mem_zero_extnd_i;
    logic [31:0]   data_mem_rd_data_o;

endinterface

// ---------- DRIVER ---------- //
class data_mem_driver extends uvm_driver #(data_mem_transaction);
    `uvm_component_utils(data_mem_driver)

    // istantiate interface to connect driver to sequencer
    virtual data_mem_if vif;

    // constructor - create the driver
    function new(string name = "data_mem_driver", uvm_component parent);
        super.new(name, parent);
    endfunction

    // build phase builds driver
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // error handling if no interface is detected
        if (!uvm_config_db#(virtual data_mem_if)::get(this,"","vif", vif))
            `uvm_fatal("DRIVER", "Virtual interface not found.");
    endfunction

    // run phase is the task that governs the drivers continuous behavior
    task run_phase(uvm_phase phase);
        
        // instantiate a transaction
        data_mem_transaction req;

        // continually get transactions from sequencer, drive them, and then let thesequencer data_mem done
        forever begin
            seq_item_port.get_next_item(req);
            drive_transaction(req);
            seq_item_port.item_done();
        end
    endtask

    // task for driving an individual transaction to the DUT
    task drive_transaction(data_mem_transaction req);

        // DRIVE DUT INTERFACE WITH TRANSACTION
        @(posedge vif.clk);
        vif.data_mem_req_i          <= req.req;
        vif.data_mem_addr_i         <= req.addr;
        vif.data_mem_byte_en_i      <= req.byte_en;
        vif.data_mem_wr_i           <= req.wr_en;
        vif.data_mem_wr_data_i      <= req.wr_data;
        vif.data_mem_zero_extnd_i   <= req.zero_extnd;

    endtask
endclass

// ---------- MONITOR ---------- //
class data_mem_monitor extends uvm_monitor;
    `uvm_component_utils(data_mem_monitor)

    // declare the interface for output viewing
    virtual data_mem_if vif;

    // always declare an analysis port in the monitor
    uvm_analysis_port #(data_mem_transaction) ap;

    // monitor constructor
    function new(string name = "data_mem_monitor", uvm_component parent);
        super.new(name, parent);
    endfunction

    // build phase for the monitor 
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual data_mem_if)::get(this, "", "vif", vif))
            `uvm_fatal("MONITOR", "Virtual interface not found!")

        // always create an analysis port in the mointor
        ap = new("ap", this);
    endfunction

    // run phase - observe the DUT outputs
    task run_phase (uvm_phase phase);

        // initialize pointer to transaction class
        data_mem_transaction tr;

        // initialize signals to known values before observing transactions
        vif.data_mem_req_i          <= 0;
        vif.data_mem_addr_i         <= 0;
        vif.data_mem_byte_en_i      <= 0;
        vif.data_mem_wr_i           <= 0;
        vif.data_mem_wr_data_i      <= 0;
        vif.data_mem_zero_extnd_i   <= 0;

        // OBSERVE TRANSACTION ON DUT INTERFACE
        forever begin
            @(posedge vif.clk);
            tr = data_mem_transaction::type_id::create("tr");
            tr.req         = vif.data_mem_req_i;
            tr.addr        = vif.data_mem_addr_i;
            tr.byte_en     = vif.data_mem_byte_en_i;
            tr.wr_en       = vif.data_mem_wr_i;
            tr.wr_data     = vif.data_mem_wr_data_i;
            tr.zero_extnd  = vif.data_mem_zero_extnd_i;

            // data_mem module has registered output, so wait 1 cycle before assigning output
            @(posedge vif.clk);
            tr.rd_data     = vif.data_mem_rd_data_o;

            // give the transaction to the scoreboard
            ap.write(tr);
        end
    endtask
endclass 

// ---------- SCOREBOARD ---------- //
class data_mem_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(data_mem_scoreboard)

    // analysis port to receive transaction from the monitor
    uvm_analysis_imp #(data_mem_transaction, data_mem_scoreboard) ap_imp;

    // stats for tracking correctness
    int transactions_checked;
    int error_count;
    int read_count;
    int write_count;

    // CREATE THE GOLDEN MODEL
    logic [31:0] golden_array [1023:0];
    logic [31:0] golden_rd_data; 
    
  	// pipeline signals to create the delay present in RTL
  	logic [31:0] prev_addr;
    logic [1:0] prev_byte_en;
    logic prev_zero_extnd;
    logic prev_req;
    logic prev_wr_en;
    logic prev_read_valid;
    logic first_transaction;

    // constructor
    function new(string name = "data_mem_scoreboard", uvm_component parent);
        super.new(name, parent);
    endfunction

    // build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // instantiate the new analysis port
        ap_imp = new("ap_imp", this);

        // INITIALIZE THE GOLDEN MODEL
        golden_rd_data = '0;
        
      	// golden array initialization
      	for (int i = 0; i < 1024; i++) begin
            golden_array[i] = 32'h0;
        end
        // initialize stats
        transactions_checked = 0;
        error_count = 0;
        read_count = 0;
        write_count = 0;

      	// initialize pipeline registers
        prev_addr = 32'h0;
        prev_byte_en = 2'b00;
        prev_zero_extnd = 1'b0;
        prev_req = 1'b0;
        prev_wr_en = 1'b0;
        prev_read_valid = 1'b0;
        first_transaction = 1'b1;
      
    endfunction

    function void write(data_mem_transaction tr);
        // Declare local variables at the beginning of the function
        logic [29:0] word_addr;
        logic [1:0] byte_offset;
        logic [15:0] half_word_data;
        logic [7:0] byte_data;
      	logic [31:0] prev_read_data;
        
        // increment transaction counter
        transactions_checked++;

        // update the golden model
      	if (tr.req) begin
          if (tr.wr_en) begin
              // increment write_count
              write_count++;

              // generate the word address and byte offset from the transaction
              word_addr = tr.addr[31:2];
              byte_offset = tr.addr[1:0];
            
              // handle word writes
              if (tr.byte_en == WORD) begin
                  golden_array[word_addr] = tr.wr_data;
              end

              // handle half_word writes
              if (tr.byte_en == HALF_WORD) begin
                  if (byte_offset[1]) begin
                      golden_array[word_addr][31:16] = tr.wr_data[15:0];
                  end else begin
                      golden_array[word_addr][15:0] = tr.wr_data[15:0];
                  end
              end

              // handle byte writes
              if (tr.byte_en == BYTE) begin
                  if (byte_offset == 0) begin
                      golden_array[word_addr][7:0] = tr.wr_data[7:0];
                  end else if (byte_offset == 1) begin
                      golden_array[word_addr][15:8] = tr.wr_data[7:0];
                  end else if (byte_offset == 2) begin
                      golden_array[word_addr][23:16] = tr.wr_data[7:0];
                  end else if (byte_offset == 3) begin
                      golden_array[word_addr][31:24] = tr.wr_data[7:0];
                  end
              end

          	// read handling
            end else if (!first_transaction && prev_read_valid) begin
                // increment read counter
                read_count++;

                // generate the word address from PREVIOUS transaction (for data source)
                word_addr = prev_addr[31:2];
                byte_offset = prev_addr[1:0];

                // Get the raw data that was read in previous cycle
                prev_read_data = golden_array[word_addr];

                // Format the output using CURRENT cycle controls (like RTL)
                if (!tr.req) begin
                    golden_rd_data = 32'h0;  // Current req=0, output 0
                end else begin
                    case (tr.byte_en)  // Use CURRENT byte_en for formatting
                        WORD: begin
                            golden_rd_data = prev_read_data;
                        end

                        HALF_WORD: begin
                            if (byte_offset[1]) begin  // Use PREVIOUS address for data selection
                                half_word_data = prev_read_data[31:16];
                            end else begin
                                half_word_data = prev_read_data[15:0];
                            end

                            if (tr.zero_extnd) begin  // Use CURRENT zero_extnd for formatting
                                golden_rd_data = {16'b0, half_word_data};
                            end else begin
                                golden_rd_data = {{16{half_word_data[15]}}, half_word_data};
                            end
                        end

                        BYTE: begin
                            case (byte_offset)  // Use PREVIOUS address for data selection
                                0: byte_data = prev_read_data[7:0];
                                1: byte_data = prev_read_data[15:8];
                                2: byte_data = prev_read_data[23:16];
                                3: byte_data = prev_read_data[31:24];
                            endcase

                            if (tr.zero_extnd) begin  // Use CURRENT zero_extnd for formatting
                                golden_rd_data = {24'b0, byte_data};
                            end else begin
                                golden_rd_data = {{24{byte_data[7]}}, byte_data};
                            end
                        end
                    endcase
                end
            end     
        end else begin
          golden_rd_data = 32'b0;
        end

      
        // update the pipeline for use on next cycle
        prev_addr = tr.addr;
        prev_byte_en = tr.byte_en;
        prev_zero_extnd = tr.zero_extnd;
        prev_req = tr.req;
        prev_wr_en = tr.wr_en;
        prev_read_valid = (tr.req && !tr.wr_en);
        first_transaction = 1'b0;     
      
      	// call the check function for reads
    	check_read_data(tr);
      
    endfunction

    // check the monitored results for correctness
    function void check_read_data(data_mem_transaction tr);

        // check reads
      if (prev_read_valid && !first_transaction) begin
            if (tr.rd_data != golden_rd_data) begin
                `uvm_error("SCOREBOARD", $sformatf("ERROR: Output mismatch. DUT.rd_data: %0h, Golden.rd_data: %0h, tr.addr: %0h", tr.rd_data, golden_rd_data, tr.addr));
                error_count++;
            end
        end
    endfunction

    // report the test stats
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        // display the stats
        `uvm_info("SCOREBOARD", $sformatf("=== FINAL RESULTS ==="), UVM_LOW)
        `uvm_info("SCOREBOARD", $sformatf("Total transactions checked: %0d", transactions_checked), UVM_LOW)
        `uvm_info("SCOREBOARD", $sformatf("Total error count: %0d", error_count), UVM_LOW)
        `uvm_info("SCOREBOARD", $sformatf("Total read count: %0d", read_count), UVM_LOW)
        `uvm_info("SCOREBOARD", $sformatf("Total write count: %0d", write_count), UVM_LOW)

        // pass/fail report
        if (error_count == 0) begin
            `uvm_info("SCOREBOARD", "*** TEST PASSED ***", UVM_LOW)
        end else begin
            `uvm_error("SCOREBOARD", "*** TEST FAILED ***")
        end
    endfunction
endclass


// ---------- AGENT ---------- //
class data_mem_agent extends uvm_agent;
    `uvm_component_utils(data_mem_agent)
    
    // instantiate driver, monitor, and sequencer
    data_mem_sequencer sqr;
    data_mem_driver drv;
    data_mem_monitor mon;

    // constructor
    function new(string name = "data_mem_agent", uvm_component parent);
        super.new(name, parent);
    endfunction

    // build phase (assemble the driver, monitor, sequence, and DUT) 
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // always create passive components (monitor)
        mon = data_mem_monitor::type_id::create("mon", this);

        // create sequencer and driver in active agents
        if (get_is_active() == UVM_ACTIVE) begin
            sqr = data_mem_sequencer::type_id::create("sqr", this);
            drv = data_mem_driver::type_id::create("drv", this);
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
endclass

// // ---------- COVERAGE---------- //
// class data_mem_coverage extends uvm_subscriber #(data_mem_transaction);
//     `uvm_component_utils(data_mem_coverage)

//     // covergroup defines which metrics we want to reord
//   covergroup data_mem_cg with function sample(data_mem_transaction tr);

//         // option dictates that each instance of this covergroup gets separate tracking
//         option.per_instance = 1;
//         option.name = "Coverage";
        
//         // opration coverage
//         cp_data_mem: coverpoint tr.data_mem_signal {
//             bins add_op = {ADD};
//         }
    
//     endgroup
    
//     // coverage constructor
//     function new(string name = "data_mem_coverage", uvm_component parent);
//         super.new(name, parent);
//         data_mem_cg = new();
//     endfunction

//     // sample coverage on each transaction (subscriber uses transaction name t)
//     function void write(data_mem_transaction t);
//         data_mem_cg.sample(t);
//     endfunction

//     // coverage report
//     function void report_phase(uvm_phase phase);
//         super.report_phase(phase);

//         // REPORT MACROS FOR COVERAGE
//         `uvm_info("COVERAGE", $sformatf("=== COVERAGE REPORT ==="), UVM_LOW);
//     endfunction
// endclass

// ---------- ENVIRONMENT ---------- // 
class data_mem_env extends uvm_env;
    `uvm_component_utils(data_mem_env)

    // comopnents declaration
    data_mem_agent agent;
    data_mem_scoreboard sb;
    // data_mem_coverage cov;
    
    // constructor
    function new(string name = "data_mem_env", uvm_component parent);
        super.new(name, parent);
    endfunction

    // build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // create agent and scoreboard components
        agent = data_mem_agent::type_id::create("agent", this);
        sb = data_mem_scoreboard::type_id::create("sb", this);
        // cov = data_mem_coverage::type_id::create("cov", this);
    endfunction

    // connect phase
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // connect the scoreboard's analysos port to that ofthe agent
        agent.mon.ap.connect(sb.ap_imp);
        // agent.mon.ap.connect(cov.analysis_export);
    endfunction
endclass

// ---------- SEQUENCE ---------- //
class data_mem_sequence extends uvm_sequence #(data_mem_transaction);
    `uvm_object_utils(data_mem_sequence)

    // constructor
    function new(string name = "data_mem_base_sequence");
        super.new(name);
    endfunction

    // main sequence functional block
    task body();

        // call the transaction class
        data_mem_transaction req;

        // seqence of 10 transactions
        repeat(1000) begin

            // create a transaction
            req = data_mem_transaction::type_id::create("req");

            // start the transaction
            start_item(req);

            // randomize the transaction (with constraints automatically applied)
            if (!req.randomize()) begin
                `uvm_error("SEQUENCE", $sformatf("Randomization failed!"))
            end

            // send the transaction to the driver
            finish_item(req);

            // PRINT SEQUNCE INFO
          `uvm_info("SEQUENCE", $sformatf("Generated: wr_data: %0h, wr: %0h, addr: %0h", req.wr_data, req.wr_en, req.addr), UVM_MEDIUM)
        end 
    endtask
endclass

// ---------- UVM TEST ---------- //
class data_mem_test extends uvm_test;
    `uvm_component_utils(data_mem_test)

    // instantiate the environment
    data_mem_env env;

    // constructor
    function new(string name = "data_mem_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    // build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // create the alu test environment
        env = data_mem_env::type_id::create("env", this);
    endfunction

    // run phase
    task run_phase(uvm_phase phase);
        
        data_mem_sequence seq;

        // raise objection to keep the test running
        phase.raise_objection(this);

        // create and start test sequence
        seq = data_mem_sequence::type_id::create("seq");

        // actually run the sequence in the env on the sequencer
        seq.start(env.agent.sqr);

        // extra delay to let the testbench finish running
        #100;

        // drop objection to end the test
        phase.drop_objection(this);
    endtask
endclass

// ----------- TOP MODULE ------------ // 
module tb_data_mem_top;

    // clk generation logic
    logic clk = 0;
    always #5 clk = ~clk;

    // instantiate alu interface
    data_mem_if data_mem_if_instance(.clk(clk));

    // DUT INSTANCE
    data_mem DUT(
        .clk(clk),
        .reset_n(data_mem_if_instance.reset_n),
        .data_mem_req_i(data_mem_if_instance.data_mem_req_i),
        .data_mem_addr_i(data_mem_if_instance.data_mem_addr_i),
        .data_mem_byte_en_i(data_mem_if_instance.data_mem_byte_en_i),
        .data_mem_wr_i(data_mem_if_instance.data_mem_wr_i),
        .data_mem_wr_data_i(data_mem_if_instance.data_mem_wr_data_i),
        .data_mem_zero_extnd_i(data_mem_if_instance.data_mem_zero_extnd_i),
        .data_mem_rd_data_o(data_mem_if_instance.data_mem_rd_data_o)
    );

    // Reset generation
    initial begin
        data_mem_if_instance.reset_n = 0;
        #20;
        data_mem_if_instance.reset_n = 1;
    end

    // dumpfile creation
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_data_mem_top);
    end
    
    // UVM testbench
    initial begin

        // put the data_mem_if in the UVM configuration database
        uvm_config_db#(virtual data_mem_if)::set(null, "*", "vif", data_mem_if_instance);

        // start the UVM test
        run_test("data_mem_test");
    
    end
endmodule