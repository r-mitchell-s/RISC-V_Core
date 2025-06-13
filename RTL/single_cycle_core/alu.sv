// - - - - - EXECUTE (ALU) - - - - - //
// 
// 

module execute import riscv_pkg::*; (
  input   logic [31:0] opr_a_i,							// operand A
  input   logic [31:0] opr_b_i,							// operand B
  input   logic [3:0]  op_sel_i,						// operation select line
  output  logic [31:0] alu_res_o						// ALU output
);

  // for signed less-than operator
  logic signed [31:0] signed_opr_a;
  logic signed [31:0] signed_opr_b;

  assign signed_opr_a = opr_a_i;
  assign signed_opr_b = opr_b_i;
  
  // define ALU behavior according to the selected operation
  always @* begin
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
      LT: begin
        alu_res_o = {31'h0, opr_a_i < opr_b_i};
      end
      SLT: begin
        alu_res_o = {31'h0, signed_opr_a < signed_opr_b};
      end
      default: begin
        alu_res_o = 32'h00;
      end
    endcase
  end
endmodule