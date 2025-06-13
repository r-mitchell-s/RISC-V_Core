// - - - - - REGISTER FILE - - - - - //
// 
// 

module regfile (
  input   logic          clk,															// synchronizing clock
  input   logic          reset_n,													// negative-edge triggered reset

  input   logic [4:0]    rs1_addr_i,											// source 1 register address
  input   logic [4:0]    rs2_addr_i,											// source 2 register address
  input   logic [4:0]    rd_addr_i,												// destination register address

  input   logic          wr_en_i,													// write enable signal
  input   logic [31:0]   wr_data_i,												// data to be written into the regfile

  output  logic [31:0]   rs1_data_o,											// register 1 read data
  output  logic [31:0]   rs2_data_o												// register 2 read data
);

	// the actual 2D array of flip-flops
  logic [31:0] regfile [31:0];
  
  // sequential block for handling writes and resets
  always @(posedge clk) begin
  	if (!reset_n) begin
      for (int i = 0; i < 31; i++) begin
        regfile[i] <= 0;
      end
    end else if (wr_en_i && (rd_addr_i != 0)) begin
    	regfile[rd_addr_i] <= wr_data_i;
    end
  end
      
	// comibinatorial assignment for same-cycle reads
  always @* begin
    rs1_data_o = regfile[rs1_addr_i];
    rs2_data_o = regfile[rs2_addr_i];
  end
endmodule