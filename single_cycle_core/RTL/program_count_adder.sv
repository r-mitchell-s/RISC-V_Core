module program_count_adder(
    input i_pc_prev,
    output o_pc_next
);

    // increment the program counter in this block
    assign o_pc_next = i_pc_prev + 4;

endmodule