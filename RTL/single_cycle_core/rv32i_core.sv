// - - - - - RISC-V SINGLE CYCLE CORE: TOP - - - - - //
//
// Top level integration of all of the submodules in the single cycle core,
// which includes the following:
// 
// regfile.sv - 
// fetch.sv - 
// dcode.sv -
// alu.sv - 
// 

module rv32i_core import riscv_pkg::*; #(
  parameter RESET_PC = 32'h0
)(
  input   logic          clk,
  input   logic          reset_n,

  // instruction memory interface
  output  logic          instr_mem_req_o,
  output  logic [31:0]   instr_mem_addr_o,
  input   logic [31:0]   instr_mem_rd_data_i,

  // data memory interface
  output  logic          data_mem_req_o,
  output  logic [31:0]   data_mem_addr_o,
  output  logic [1:0]    data_mem_byte_en_o,
  output  logic          data_mem_zero_extnd_o,
  output  logic          data_mem_wr_o,
  output  logic [31:0]   data_mem_wr_data_o,
  input   logic [31:0]   data_mem_rd_data_i

);

  // - - - - - - - - - - - - - - - - - - - - - - - - //
  // - - - - - INTERNAL SIGNAL DECLARATION - - - - - //
  // - - - - - - - - - - - - - - - - - - - - - - - - //

  // needed for reset handling
  logic reset_observed;                               // registers initial reset

  // first needed in PC logic
  logic [31:0] pc;                                    // the program counter that addresses the IMEM
  logic [31:0] pc_next;                               // the next pc value (either branch target or pc + 4)
  logic [31:0] next_instr_pc;                         // address of then ext instruction in the program (pc + 4)

  // first needed at fetch
  logic [31:0] instr_curr;                            // instruction in IMEM at the address indexed by PC 

  // first needed at decode
  logic [4:0] rs1_addr;                               // address of rs1
  logic [4:0] rs2_addr;                               // address of rs2
  logic [4:0] rd_addr;                                // address of rd
  logic [6:0] op_code;                                // instruction op code
  logic [2:0] funct3;                                 // funct3 field of instruction
  logic [6:0] funct7;                                 // funct7 field of instruction
  logic [31:0] instr_imm;                             // instructions imediate field
  logic r_type;                                       // one-hot R-type indicator
  logic i_type;                                       // one-hot I-type indicator
  logic s_type;                                       // one-hot S-type indicator
  logic b_type;                                       // one-hot B-type indicator
  logic u_type;                                       // one-hot U-type indicator
  logic j_type;                                       // one-hot J-type indicator

  // first needed at execute
  logic [31:0] alu_src_1;                             // hooked to the output of operand 1 multiplexor
  logic [31:0] alu_src_2;                             // hooked to the output of operand 2 multiplexor
  logic [31:0] alu_result;                            // used as input to regfile writeback data sel multiplexor

  // used in register file
  logic rf_wr_en;                                     // indicates whether the RF is being written to
  logic [31:0] rf_wr_data;                            // data to be written to the RF
  logic [31:0] rs1_data;                              // contents of rs1
  logic [31:0] rs2_data;                              // contents of rs2

  // first needed in control unit
  logic pc_sel;                                       // multiplexing for next PC value determination
  logic op1_sel;                                      // decides whether op1 is rs1 or current PC 
  logic op2_sel;                                      // decides whether op2 is rs2 or immediate
  logic [3:0] alu_op_sel;                             // ALU opertion select signal
  logic ctrl_to_dmem_req;

  // first needed in branch control unit
  logic branch_taken;
  logic ctrl_to_dmem_wr;
  logic [1:0] data_byte;
  logic [1:0] rf_wb_data_sel;

  // first needed in memory interface
  logic [31:0] dmem_data;

  // - - - - - - - - - - - - - - - - - //
  // - - - - CPU CORE INSTANCE - - - - //
  // - - - - - - - - - - - - - - - - - //

  // - - - - - INITIALIZATION RESET HANDLING - - - - - //
  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      reset_observed <= 1'b0;
    end else begin
      reset_observed <= 1'b1;
    end
  end

  // - - - - - PROGRAM COUNTER - - - - - //
  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      pc <= RESET_PC;
    end else if (reset_observed) begin
      pc <= pc_next;
    end 
  end

  // logic to determine next pc based on branch control outputs
  assign next_instr_pc = pc + 32'h4;
  assign pc_next = (branch_taken | pc_sel) ? alu_result : next_instr_pc;

	// - - - - - REGISTER FILE - - - - - //
  regfile u_regfile (
    .clk                      (clk),
    .reset_n                  (reset_n),
    .rs1_addr_i               (rs1_addr),
    .rs2_addr_i               (rs2_addr),
    .rd_addr_i                (rd_addr),
    .wr_en_i                  (rf_wr_en),
    .wr_data_i                (rf_wr_data),
    .rs1_data_o               (rs1_data),
    .rs2_data_o               (rs2_data)
  );

  // multiplexing logic for regfile data write selection (.wr_data_i)
  always_comb begin
    case(rf_wb_data_sel) 
      ALU: rf_wr_data = alu_result;
      MEM: rf_wr_data = dmem_data;
      IMM: rf_wr_data = instr_imm;
      PC:  rf_wr_data = next_instr_pc;
      default: rf_wr_data = '0;
    endcase
  end

  // - - - - - FETCH - - - - - //
  fetch u_fetch (
    .clk                      (clk),
    .reset_n                  (reset_n),
    .instr_mem_pc_i           (pc),
    .instr_mem_req_o          (instr_mem_req_o),
    .instr_mem_addr_o         (instr_mem_addr_o),
    .mem_rd_data_i            (instr_mem_rd_data_i),
    .instr_mem_instr_o        (instr_curr)
  );

	// - - - - - DECODE - - - - - // 
  decode u_decode (
    .instr_i                  (instr_curr),
    .rs1_o                    (rs1_addr),
    .rs2_o                    (rs2_addr),
    .rd_o                     (rd_addr),
    .op_o                     (op_code),
    .funct3_o                 (funct3),
    .funct7_o                 (funct7),
    .r_type_instr_o           (r_type),
    .i_type_instr_o           (i_type),
    .s_type_instr_o           (s_type),
    .b_type_instr_o           (b_type),
    .u_type_instr_o           (u_type),
    .j_type_instr_o           (j_type),
    .instr_imm_o              (instr_imm)
  );

  //  - - - - - EXECUTE (ALU) - - - - - //
  alu u_alu (
    .opr_a_i                  (alu_src_1),
    .opr_b_i                  (alu_src_2),
    .op_sel_i                 (alu_op_sel),
    .alu_res_o                (alu_result)
  );

  // execution stage multiplexing logic
  assign alu_src_1 = op1_sel ? pc : rs1_data;
  assign alu_src_2 = op2_sel ? instr_imm : rs2_data;
  
  // - - - - - CONTROL UNIT - - - - - //
  ctrl_unit u_ctrl_unit (
    .instr_funct3_i           (funct3),
    .instr_funct7_bit5_i      (funct7[5]),
    .instr_opcode_i           (op_code),
    .is_r_type_i              (r_type),
    .is_i_type_i              (i_type),
    .is_s_type_i              (s_type),
    .is_b_type_i              (b_type),
    .is_u_type_i              (u_type),
    .is_j_type_i              (j_type),
    .pc_sel_o                 (pc_sel),
    .op1sel_o                 (op1_sel),
    .op2sel_o                 (op2_sel),
    .data_req_o               (ctrl_to_dmem_req),
    .data_wr_o                (ctrl_to_dmem_wr),
    .data_byte_o              (data_byte),
    .zero_extnd_o             (data_mem_zero_extnd_o),
    .rf_wr_en_o               (rf_wr_en),
    .rf_wr_data_o             (rf_wb_data_sel),
    .alu_func_o               (alu_op_sel)
  );

  //  - - - - - BRANCH CONTROL UNIT - - - - - //
  branch_ctrl u_branch_ctrl (
    .opr_a_i                  (rs1_data),
    .opr_b_i                  (rs2_data),
    .is_b_type_ctl_i          (b_type),
    .instr_func3_ctl_i        (funct3),
    .branch_taken_o           (branch_taken)
  );

  //  - - - - - DATA MEMORY INTERFACE - - - - - //
  data_mem_interface u_data_mem_interface (
    .clk                      (clk),
    .reset_n                  (reset_n),
    .data_req_i               (ctrl_to_dmem_req),
    .data_addr_i              (alu_result),
    .data_byte_en_i           (data_byte),
    .data_wr_i                (ctrl_to_dmem_wr),
    .data_wr_data_i           (rs2_data),
    .data_zero_extnd_i        (data_mem_zero_extnd_o),
    .data_mem_req_o           (data_mem_req_o),
    .data_mem_addr_o          (data_mem_addr_o),
    .data_mem_byte_en_o       (data_mem_byte_en_o),
    .data_mem_wr_o            (data_mem_wr_o),
    .data_mem_wr_data_o       (data_mem_wr_data_o),
    .mem_rd_data_i            (data_mem_rd_data_i),
    .data_mem_rd_data_o       (dmem_data)
  );

endmodule