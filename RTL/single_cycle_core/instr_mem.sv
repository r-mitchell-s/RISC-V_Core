module instr_mem #(
    parameter IMEM_WORDS = 1024
)(
    input logic         clk,
    input logic         reset_n,
    input logic         instr_mem_req_i,
    input [31:0]        instr_mem_addr_i,
    output [31:0]       instr_mem_data_o
);

    // the memory array itself (4kB)
    logic [IMEM_WORDS - 1 : 0] [31:0] instr_mem_array;

    // return instructions on the same cycle that they are requested
    assign instr_mem_data_o = instr_mem_req_i ? instr_mem_array[instr_mem_addr_i[31:2]] : '0;

endmodule