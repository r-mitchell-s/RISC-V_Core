module memory_instr(
    input i_clk,
    input i_rst,
    input [31:0] i_read_address,
    output [31:0] o_instr
);

    // memory array of width 32 and depth 64
    reg [31:0] instr_mem_array [63:0];

    // 
    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            // reset output and clear memory array
            o_instr <= 32'd0;
            for (integer i = 0; i < 64; i++) begin 
                instr_mem_array[i] <= 32'd0;
            end
        end else begin
            // read the instruction to output
            o_instr <= instr_mem_array[i_read_address];
        end
    end

endmodule