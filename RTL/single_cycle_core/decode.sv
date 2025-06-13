// - - - - - DECODE - - - - - //
// 
// 

module decode import riscv_pkg::*; (
  input   logic [31:0]  instr_i,
  output  logic [4:0]   rs1_o,
  output  logic [4:0]   rs2_o,
  output  logic [4:0]   rd_o,
  output  logic [6:0]   op_o,
  output  logic [2:0]   funct3_o,
  output  logic [6:0]   funct7_o,
  output  logic         r_type_instr_o,
  output  logic         i_type_instr_o,
  output  logic         s_type_instr_o,
  output  logic         b_type_instr_o,
  output  logic         u_type_instr_o,
  output  logic         j_type_instr_o,
  output  logic [31:0]  instr_imm_o
);
  
  // signal declaration for type-dependent immediates and flags
  logic [31:0] instr_imm;
  logic r_type;
  logic i_type;
  logic s_type;
  logic b_type;
  logic u_type;
  logic j_type;
  
  // output flag logic
  always_comb begin
    r_type = 1'b0;
    i_type = 1'b0;
    s_type = 1'b0;
    b_type = 1'b0;
    u_type = 1'b0;
    j_type = 1'b0;
  	instr_imm = 32'b0;
    
    // assert the indicator bit and extract immediate accordingly
    case (instr_i[6:0])
      R_TYPE: begin
        r_type = 1'b1;	
      	instr_imm = 32'b0;
      end
      I_TYPE0, I_TYPE1, I_TYPE2: begin
        i_type = 1'b1;
      	instr_imm = {{20{instr_i[31]}}, instr_i[31:20]};
      end
      S_TYPE: begin
        s_type = 1'b1;
      	instr_imm = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
      end
      B_TYPE: begin
        b_type = 1'b1;
        instr_imm = {{20{instr_i[31]}}, instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};
      end
      U_TYPE0, U_TYPE1: begin
        u_type = 1'b1;
      	instr_imm = {{instr_i[31:12]}, 12'b0};
      end
      J_TYPE: begin
        j_type = 1'b1;
      	instr_imm = {{12{instr_i[31]}}, instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0};
      end
      default: 
        instr_imm = 32'b0;
    endcase
  end

  // instruction field assignments
  assign op_o = 			instr_i[6:0];
  assign rd_o = 			instr_i[11:7];
  assign funct3_o =		 	instr_i[14:12];
  assign rs1_o = 			instr_i[19:15];
  assign rs2_o = 			instr_i[24:20];
  assign funct7_o = 		instr_i[31:25];
    
  // type flag assignments
  assign r_type_instr_o = 	r_type;
  assign i_type_instr_o = 	i_type;
  assign s_type_instr_o = 	s_type;
  assign b_type_instr_o = 	b_type;
  assign u_type_instr_o = 	u_type;
  assign j_type_instr_o = 	j_type;
  
  // immediate assignments
  assign instr_imm_o = 		instr_imm;
endmodule