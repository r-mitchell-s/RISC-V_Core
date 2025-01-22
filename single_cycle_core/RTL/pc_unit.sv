// - - - - - PROGRAM COUNTER - - - - - //
module program_counter(
    input i_clk,
    input i_rst,
    input [31:0] i_pc,
    output [31:0] o_pc
);

    // define reset and internal logic
    always @(posedge i_clk or posedge_rst) begin
        if (i_rst) begin
            o_pc <= 32'd0;
        end else begin
            o_pc <= i_pc;
        end
    end
endmodule