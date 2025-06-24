module top import riscv_pkg::*; (
    input logic         clk,
    input logic         reset_n
);

    // - - - - - - - - - - - - - - - - - - - - - - - - //
    // - - - - - INTERNAL SIGNAL DECLARATION - - - - - //
    // - - - - - - - - - - - - - - - - - - - - - - - - //

    // instruction memory <-> rv32i core
    logic instr_mem_req;
    logic [31:0] instr_mem_addr;
    logic [31:0] instr_mem_data;

    // data memory <-> rv32i core
    logic data_mem_req;
    logic data_mem_wr;
    logic data_mem_zero_extnd;
    logic [1:0] data_mem_byte_en;
    logic [31:0] data_mem_wr_data;
    logic [31:0] data_mem_addr;
    logic [31:0] data_mem_rd_data;

    // - - - - - - - - - - - - - - - - - - - - - - - - //
    // - - - - - - - TOP LEVEL INTEGRATION - - - - - - //
    // - - - - - - - - - - - - - - - - - - - - - - - - //

    // - - - - - RISC-V CORE INSTANCE - - - - - //
    rv32i_core RV32I (
        .clk                        (clk), 
        .reset_n                    (reset_n),
        .instr_mem_req_o            (instr_mem_req),
        .instr_mem_addr_o           (instr_mem_addr),
        .instr_mem_rd_data_i        (instr_mem_data),
        .data_mem_req_o             (data_mem_req),
        .data_mem_addr_o            (data_mem_addr),
        .data_mem_wr_o              (data_mem_wr),
        .data_mem_wr_data_o         (data_mem_wr_data),
        .data_mem_byte_en_o         (data_mem_byte_en),
        .data_mem_zero_extnd_o      (data_mem_zero_extnd),
        .data_mem_rd_data_i         (data_mem_rd_data)
    );

    // - - - - - INSTRUCTION MEMORY INSTANCE - - - - - //
    instr_mem IMEM (
        .clk                        (clk),
        .reset_n                    (reset_n),
        .instr_mem_req_i            (instr_mem_req),
        .instr_mem_addr_i           (instr_mem_addr),
        .instr_mem_data_o           (instr_mem_data)
    );

    // - - - - - INSTRUCTION MEMORY INSTANCE - - - - - //
    data_mem DMEM (
        .clk                        (clk),
        .reset_n                    (reset_n),
        .data_mem_req_i             (data_mem_req),
        .data_mem_addr_i            (data_mem_addr),
        .data_mem_wr_i              (data_mem_wr),
        .data_mem_wr_data_i         (data_mem_wr_data),
        .data_mem_byte_en_i         (data_mem_byte_en),
        .data_mem_zero_extnd_i      (data_mem_zero_extnd),
        .data_mem_rd_data_o         (data_mem_rd_data)
    );

endmodule