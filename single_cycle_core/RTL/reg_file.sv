// - - - - - REGISTER FILE - - - - - //
module reg_file(
    input i_clk,
    input i_rst,
    input i_rs1,
    input i_rs2,
    input i_rd,
    input i_reg_write
    input [31:0] i_write_data,
    output [31:0] o_read_data1,
    output [31:0] o_read_data2
);
    // instantiate the registers in the regfile
    reg [31:0] reg_array [31:0];

    always @(posegde i_clk or posedge i_rst) begin
        // reset handling
        if (i_rst) begin
            o_read_data1 <= 32'd0;
            o_read_data2 <= 32'd0;
            for (integer i; i < 32; i++) begin
                reg_array[i] <= 32'd0;
            end
        // handle register writes
        end else if (i_reg_write) begin
            reg_array[i_rd] <= i_write_data;
        end
    end

    // output assigments
    assign o_read_data1 = reg_array[rs1];
    assign o_read_data2 = reg_array[rs2];
endmodule