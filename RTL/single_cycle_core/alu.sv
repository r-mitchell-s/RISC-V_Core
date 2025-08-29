// - - - - - EXECUTE (ALU) - - - - - //
// 
// The arithmetic logic unit (ALU) performs computaitions using
// the contents of operand registers, generating an output to be 
// written back to the regfile.
// 
// This ALU supports the necessary operations for the RV32I base integer
// ISA, those being: ADD, SUB, SLL, SRL, SRA, OR, AND, XOR, SLT, and SLTU.
// 
// Outputs are combinatorial, not registered

module alu import riscv_pkg::*; (
  input   logic [31:0] opr_a_i,							// operand A
  input   logic [31:0] opr_b_i,							// operand B
  input   logic [3:0]  op_sel_i,						// operation select line
  output  logic [31:0] alu_res_o						// ALU output
);
  
  // define ALU behavior according to the selected operation
  always_comb begin
    case (op_sel_i) 
      ADD: begin
        alu_res_o = opr_a_i + opr_b_i;
      end
      SUB: begin
        alu_res_o = opr_a_i - opr_b_i;
      end
      SLL: begin
        alu_res_o = opr_a_i << opr_b_i[4:0];
      end
      SRL: begin
        alu_res_o = opr_a_i >> opr_b_i[4:0];
      end
      SRA: begin
        alu_res_o = $signed(opr_a_i) >>> opr_b_i[4:0];
      end
      OR: begin
        alu_res_o = opr_a_i | opr_b_i;
      end
      AND: begin
        alu_res_o = opr_a_i & opr_b_i;
      end
      XOR: begin
        alu_res_o = opr_a_i ^ opr_b_i;
      end
      SLTU: begin
        alu_res_o = {31'h0, opr_a_i < opr_b_i};
      end
      SLT: begin
        alu_res_o = {31'h0, $signed(opr_a_i) < $signed(opr_b_i)};
      end
      default: begin
        alu_res_o = 32'h00;
      end
    endcase
  end
endmodule