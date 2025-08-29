// - - - - - DATA MEMORY INTERFACE - - - - - // 
// 
// Given control signals from the CPU core's datapath, the interface generates read
// and write requests and sends them to data memory, receiving back data that ot then passes
// to the CPU.
// 
// Outputs are registered one cycle after inputs are supplied.

module data_mem_interface import riscv_pkg::*; (
  input   logic           clk,
  input   logic           reset_n,

  // Data request from current instruction
  input   logic           data_req_i,
  input   logic [31:0]    data_addr_i,
  input   logic [1:0]     data_byte_en_i,
  input   logic           data_wr_i,
  input   logic [31:0]    data_wr_data_i,

  input   logic           data_zero_extnd_i,

  // Read/Write request to memory
  output  logic           data_mem_req_o,
  output  logic  [31:0]   data_mem_addr_o,
  output  logic  [1:0]    data_mem_byte_en_o,
  output  logic           data_mem_wr_o,
  output  logic  [31:0]	  data_mem_wr_data_o,
  
  // Read data from memory
  input   logic [31:0]    mem_rd_data_i,

  // Data output
  output  logic [31:0]    data_mem_rd_data_o
);

  // internal signal declarations for sign and zero extension
  logic [31:0] data_mem_rd_sign_extnd;
  logic [31:0] data_mem_rd_zero_extnd;
  
  // multiplexing to generate correct extensions based on byte enable signal
  always_comb begin
    case (data_byte_en_i) 
      BYTE: begin
        data_mem_rd_zero_extnd = {{24{1'b0}}, mem_rd_data_i[7:0]};
        data_mem_rd_sign_extnd = {{24{mem_rd_data_i[7]}}, mem_rd_data_i[7:0]};
      end HALF_WORD: begin
        data_mem_rd_zero_extnd = {{16{1'b0}}, mem_rd_data_i[15:0]};
        data_mem_rd_sign_extnd = {{16{mem_rd_data_i[15]}}, mem_rd_data_i[15:0]};
      end WORD: begin
        data_mem_rd_zero_extnd = mem_rd_data_i;
      	data_mem_rd_sign_extnd = mem_rd_data_i;
      end default: begin
        data_mem_rd_zero_extnd = 0;
      	data_mem_rd_sign_extnd = 0;
      end
    endcase
  end
        
  // output assignments that directly interface to the memory unit
  assign data_mem_req_o = data_req_i;
  assign data_mem_addr_o = data_addr_i;
  assign data_mem_byte_en_o = data_byte_en_i;
  assign data_mem_wr_o = data_wr_i;
  assign data_mem_wr_data_o = data_wr_data_i;

  // based on the sign-extension input, load the proper destination reg output
  assign data_mem_rd_data_o = data_zero_extnd_i ? data_mem_rd_zero_extnd : data_mem_rd_sign_extnd;

endmodule