// - - - - - BRANCH CONTROL UNIT - - - - - // 
//
// Resolves whether or not a branch will be taken, active only when
// the cyrrent instructioni s B-type. Does so by evaluating the branch 
// condition given the two operand registers' contents.
// 
// Output is combinatorial, not registered.

module branch_ctrl import riscv_pkg::*; (
  
  input  logic [31:0] opr_a_i,						// source operand 1
  input  logic [31:0] opr_b_i,						// source operand 2
  input  logic        is_b_type_ctl_i,				// enables module if current instruction is branch
  input  logic [2:0]  instr_func3_ctl_i,			// indictes branch instruction type
  output logic        branch_taken_o				// take branch? 
);

	// register to store branch status
	logic branch_taken;

  	// decide result of branch based on the
  	always_comb begin
  	  	if (is_b_type_ctl_i) begin
			case (instr_func3_ctl_i)
				BEQ: branch_taken = opr_a_i == opr_b_i;
				BNE: branch_taken = opr_a_i != opr_b_i;
				BLT: branch_taken = $signed(opr_a_i) < $signed(opr_b_i);
				BGE: branch_taken = $signed(opr_a_i) >= $signed(opr_b_i);
				BLTU: branch_taken = opr_a_i < opr_b_i;
				BGEU: branch_taken = opr_a_i >= opr_b_i;
				default: branch_taken = 1'b0;
			endcase
		end else begin
			branch_taken = 1'b0;
		end
  	end

  // final output assignment
  assign branch_taken_o = branch_taken;
      
endmodule