// - - - - - FETCH - - - - - //
// 
// The fetch unit implements a simple instruction memory request. On
// every cycle, the fetch unit will request the next instruction to be executed
// (multiplexed at the top level between PC + 4 and the branch target). 
// 
// Outputs are combinatorial, but update with each instruction request, which is 
// registered one cycle after inputs are supplied.

module fetch (
  input    logic          clk,
  input    logic          reset_n,

  output   logic          instr_mem_req_o,          // signal to request the next instruction
  input    logic [31:0]   instr_mem_pc_i,           // current pc value (points to next insntruction to execute)
  output   logic [31:0]   instr_mem_addr_o,         // desired address of next instruction to execute
  input    logic [31:0]   mem_rd_data_i,            // instruction stored in imem at next pc value
  output   logic [31:0]   instr_mem_instr_o         // the instruction we are sending to decode
);

  // registred instruction request
  logic instr_mem_req_q;
  
  // sequential logic block to register request
  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      instr_mem_req_q <= 1'b0;
    end else begin
      instr_mem_req_q <= 1'b1;
    end
  end
  
  // combinatorial fetching logic
  assign instr_mem_req_o = instr_mem_req_q;
  assign instr_mem_instr_o = mem_rd_data_i;
  assign instr_mem_addr_o = instr_mem_pc_i;

endmodule