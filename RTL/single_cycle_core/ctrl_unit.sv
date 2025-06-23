// - - - - - CONTROL UNIT - - - - - //
// The control unit 
//

module ctrl_unit import riscv_pkg::*; (

  input   logic         is_r_type_i,
  input   logic         is_i_type_i,
  input   logic         is_s_type_i,
  input   logic         is_b_type_i,
  input   logic         is_u_type_i,
  input   logic         is_j_type_i,

  input   logic [2:0]   instr_funct3_i,
  input   logic         instr_funct7_bit5_i,
  input   logic [6:0]   instr_opcode_i,

  output  logic         pc_sel_o,
  output  logic         op1sel_o,
  output  logic         op2sel_o,
  output  logic [3:0]   alu_func_o,
  output  logic [1:0]   rf_wr_data_o,
  output  logic         data_req_o,
  output  logic [1:0]   data_byte_o,
  output  logic         data_wr_o,
  output  logic         zero_extnd_o,
  output  logic         rf_wr_en_o
);
 
  // create internal signals to store the driving signals for R-type and I-type control generation
  logic [3:0] r_type_alu_sel;
  logic [3:0] i_type_alu_sel;
  assign r_type_alu_sel = {instr_funct7_bit5_i, instr_funct3_i};
  assign i_type_alu_sel = {instr_opcode_i[4], instr_funct3_i};
  
  // type-dependent control signal structs
  control_t r_type_ctrls;
  control_t i_type_ctrls;
  control_t s_type_ctrls;
  control_t b_type_ctrls;
  control_t u_type_ctrls;
  control_t j_type_ctrls;
  
  // final output control signal
  control_t output_ctrls;
  
  // multiplexor tree for acquiring correct control splits based on decode stage
  always_comb begin
  	output_ctrls = is_r_type_i ? r_type_ctrls : 
    					     is_i_type_i ? i_type_ctrls : 
    					     is_s_type_i ? s_type_ctrls :
  					       is_b_type_i ? b_type_ctrls : 
  					       is_u_type_i ? u_type_ctrls : 
    					     is_j_type_i ? j_type_ctrls : '0;
  end
  
  // - - - - - R-TYPE CONTROL SIGNAL GENERATION - - - - - //
  always_comb begin
    r_type_ctrls = '0;                                    // zero out the ctrl struct to overwrite with new data
    r_type_ctrls.op1_sel = 1'b0;                          // select rs1 from register file
    r_type_ctrls.op2_sel = 1'b0;                          // select rs2 from register file
    r_type_ctrls.rf_wr_en = 1'b1;                         // enable register file writeback
    r_type_ctrls.rf_wr_data_sel = 2'b00;                  // select the ALU output for writeback
    r_type_ctrls.pc_sel = 1'b0;                           // next PC value will be PC + 4
    r_type_ctrls.data_req = 1'b0;                         // we are not trying to make a memory access
    
    // ALU operation selection
    case (r_type_alu_sel)
      ADD: r_type_ctrls.alu_funct_sel = OP_ADD;
      AND: r_type_ctrls.alu_funct_sel = OP_AND;
      OR: r_type_ctrls.alu_funct_sel = OP_OR;
      SLL: r_type_ctrls.alu_funct_sel = OP_SLL;
      SLT: r_type_ctrls.alu_funct_sel = OP_SLT;
      SLTU: r_type_ctrls.alu_funct_sel = OP_SLT;
      SRA: r_type_ctrls.alu_funct_sel = OP_SRA;
      SRL: r_type_ctrls.alu_funct_sel = OP_SRL;
      SUB: r_type_ctrls.alu_funct_sel = OP_SUB;
      XOR: r_type_ctrls.alu_funct_sel = OP_XOR;
      default: r_type_ctrls.alu_funct_sel = 0;
    endcase
  end
  
  // - - - - - I-TYPE CONTROL SIGNAL GENERATION - - - - - //
  always_comb begin
    i_type_ctrls = '0;                                    // zero out the ctrl struct to overwrite with new data
    i_type_ctrls.op1_sel = 1'b0;                          // select rs1 from register file
    i_type_ctrls.op2_sel = 1'b1;                          // select immediate for second operand
    i_type_ctrls.rf_wr_en = 1'b1;                         // enable register file writeback
    i_type_ctrls.rf_wr_data_sel = 2'b00;                  // select the ALU output for writeback
    i_type_ctrls.pc_sel = 1'b0;                           // next PC value will be PC + 4
    i_type_ctrls.data_req = 1'b0;                         // we are not trying to make a memory access
    
    case (i_type_alu_sel) 
      
      // I-type 0: ALU operations on immediate and source register
      ADDI: i_type_ctrls.alu_funct_sel = OP_ADD;
      SLTI: i_type_ctrls.alu_funct_sel = OP_SLT;
      SLTIU: i_type_ctrls.alu_funct_sel = OP_SLT;
      XORI: i_type_ctrls.alu_funct_sel = OP_XOR;
      ORI: i_type_ctrls.alu_funct_sel = OP_OR;
      ANDI: i_type_ctrls.alu_funct_sel = OP_AND;
      SLLI: i_type_ctrls.alu_funct_sel = OP_SLL;
      SRXI: i_type_ctrls.alu_funct_sel = instr_funct7_bit5_i ? OP_SRA : OP_SRL;

      // I-type 1: load operations
      LB: begin
        i_type_ctrls.alu_funct_sel = OP_ADD;
        i_type_ctrls.data_req = 1'b1;
        i_type_ctrls.data_byte = BYTE;
        i_type_ctrls.rf_wr_data_sel = MEM;
      end
      
      LH: begin
        i_type_ctrls.alu_funct_sel = OP_ADD;
        i_type_ctrls.data_req = 1'b1;
        i_type_ctrls.data_byte = HALF_WORD;
        i_type_ctrls.rf_wr_data_sel = MEM; 
      end
      
      LW: begin
        i_type_ctrls.alu_funct_sel = OP_ADD;
        i_type_ctrls.data_req = 1'b1;
        i_type_ctrls.data_byte = WORD;
        i_type_ctrls.rf_wr_data_sel = MEM;
      end
      
      LBU: begin
        i_type_ctrls.alu_funct_sel = OP_ADD;
        i_type_ctrls.data_req = 1'b1;
        i_type_ctrls.data_byte = BYTE;
        i_type_ctrls.rf_wr_data_sel = MEM;
      	i_type_ctrls.zero_extnd = 1'b1;
      end
      
      LHU: begin
        i_type_ctrls.alu_funct_sel = OP_ADD;
        i_type_ctrls.data_req = 1'b1;
        i_type_ctrls.data_byte = HALF_WORD;
        i_type_ctrls.rf_wr_data_sel = MEM;
      	i_type_ctrls.zero_extnd = 1'b1;
      end

      default: i_type_ctrls = '0;
    endcase

    // I-type 2: I-type jump operation (JALR handling)
    if (instr_opcode_i == I_TYPE2) begin
      i_type_ctrls = '0
      i_type_ctrls.alu_funct_sel = OP_ADD;                // 
      i_type_ctrls.rf_wr_data_sel = PC;                   //
      i_type_ctrls.pc_sel = 1'b1;                         //
    end
  end
    
  // - - - - - S-TYPE CONTROL SIGNAL GENERATION - - - - - // 
  always_comb begin
    s_type_ctrls = '0;                                    // zero out the control struct
    s_type_ctrls.alu_funct_sel = OP_ADD;                  // add the offset to the address to calculate storage address
    s_type_ctrls.op1_sel = 1'b0;                          // select rs1 from the register file (address)
    s_type_ctrls.op2_sel = 1'b1;                          // select the immediate (offset)
    s_type_ctrls.pc_sel = 1'b0;                           // program counter updates to PC + 4
    s_type_ctrls.rf_wr_en = 1'b0;                         // stores don't write to the register file
    s_type_ctrls.data_req = 1'b1;                         // stores are a form of memory access request
    s_type_ctrls.data_wr = 1'b1;                          // stores demand we write data to memory
    
    // determine the size of the word being stored
    case (instr_funct3_i)
      SB: s_type_ctrls.data_byte = BYTE;
      SH: s_type_ctrls.data_byte = HALF_WORD;
      SW: s_type_ctrls.data_byte = WORD;
      default: s_type_ctrls = '0;
    endcase 
  end 
    
  // - - - - - B-TYPE CONTROL SIGNAL GENERATION - - - - - // 
  always_comb begin
    b_type_ctrls = '0;
    b_type_ctrls.alu_funct_sel = OP_ADD;                  //
    b_type_ctrls.op1_sel = 1'b1;                          //
    b_type_ctrls.op2_sel = 1'b1;                          //
    b_type_ctrls.rf_wr_en = 1'b0;                         //
    b_type_ctrls.data_req = 1'b0;                         //
  end 
    
  // - - - - - U-TYPE CONTROL SIGNAL GENERATION - - - - - // 
  always_comb begin
    u_type_ctrls = '0;
    u_type_ctrls.rf_wr_en = 1'b1;                         //

    // instruction based operand selection
    case (instr_opcode_i)
      
      LUI: begin
        u_type_ctrls.rf_wr_data_sel = IMM;  							//
      end
      
      AUIPC: begin
        u_type_ctrls.op1_sel = 1'b1;                      //
        u_type_ctrls.op2_sel = 1'b1;  										//
      end
      
      default: u_type_ctrls = '0;
    endcase
  end 
    
  // - - - - - J-TYPE CONTROL SIGNAL GENERATION - - - - - // 
  always_comb begin
    j_type_ctrls = '0;
    j_type_ctrls.alu_funct_sel = OP_ADD;                  //
    j_type_ctrls.op1_sel = 1'b1;                          //
    j_type_ctrls.op2_sel = 1'b1;                          //
    j_type_ctrls.data_req = 1'b0;                         //
    j_type_ctrls.pc_sel = 1'b1;                           //
    j_type_ctrls.rf_wr_en = 1'b1;                         //
    j_type_ctrls.rf_wr_data_sel = PC;                     //
  end
      
  // final output assignments - direct the type-appropriate controls to module output
  assign pc_sel_o = output_ctrls.pc_sel;
  assign op1sel_o = output_ctrls.op1_sel;
  assign op2sel_o = output_ctrls.op2_sel;
  assign alu_func_o = output_ctrls.alu_funct_sel;
  assign rf_wr_en_o = output_ctrls.rf_wr_en;
  assign rf_wr_data_o = output_ctrls.rf_wr_data_sel;
  assign data_req_o = output_ctrls.data_req;
  assign data_wr_o = output_ctrls.data_wr;
  assign data_byte_o = output_ctrls.data_byte;
  assign zero_extnd_o = output_ctrls.zero_extnd;
  
endmodule