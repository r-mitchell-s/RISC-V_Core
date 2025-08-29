// - - - - - DATA MEMORY - - - - - // 
// 
// The data memory module implements a simple 4KB RAM for the CPU to load from and store to.
// In compliance with the RV32I spec, the data memory is accessible at the word, half-word, and byte levels
// 
// Outputs are registered one cycle after inputs are supplied.

module data_mem import riscv_pkg::*; #(
    parameter DMEM_WORDS = 1024
)(
  input   logic          clk,
  input   logic          reset_n,
  input   logic          data_mem_req_i,
  input   logic [31:0]   data_mem_addr_i,
  input   logic [1:0]    data_mem_byte_en_i,
  input   logic          data_mem_wr_i,
  input   logic [31:0]   data_mem_wr_data_i,
  input   logic          data_mem_zero_extnd_i,
  output  logic [31:0]   data_mem_rd_data_o
);

    // macros defined in riscv_pkg for byte_en
    typedef enum logic [1:0] {
        BYTE,
        HALF_WORD,
        RESERVED,
        WORD
    } mem_access_size_t;

    // data memory array
    logic [DMEM_WORDS - 1 : 0] [31:0] data_mem_array;

    // registered read data
    logic [31:0] read_data;
    logic [7:0] extracted_byte;

    // decode the address into the byte offset and word address
    logic [$clog2(DMEM_WORDS) - 1:0] word_address; 
    logic [1:0] byte_offset;

    // continuous assignment for the address decoding
    assign word_address = data_mem_addr_i[31:2];
    assign byte_offset = data_mem_addr_i[1:0];

    // sequential logic for read/write behavior
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            data_mem_array <= '0;
        
        // memory access condition
        end else if (data_mem_req_i) begin
            
            // write case
            if (data_mem_wr_i) begin

                // write size and address determination
                case (data_mem_byte_en_i)

                    // byte write case handling
                    BYTE: begin
                        case (byte_offset)
                            2'b00:   data_mem_array[word_address][7:0]   <= data_mem_wr_data_i[7:0];
                            2'b01:   data_mem_array[word_address][15:8]  <= data_mem_wr_data_i[7:0];
                            2'b10:   data_mem_array[word_address][23:16] <= data_mem_wr_data_i[7:0];
                            2'b11:   data_mem_array[word_address][31:24] <= data_mem_wr_data_i[7:0];
                        endcase
                    end

                    // half-word write case handling
                    HALF_WORD: begin
                        case (byte_offset[1])
                            1'b0:    data_mem_array[word_address][15:0]  <= data_mem_wr_data_i[15:0];
                            1'b1:    data_mem_array[word_address][31:16] <= data_mem_wr_data_i[15:0];
                        endcase
                    end

                    // word write - simple case
                    WORD: begin
                        data_mem_array[word_address] <= data_mem_wr_data_i;
                    end
                endcase
            end
                
            // read case handling (memory request but no write enabled)
            read_data <= data_mem_array[word_address];
        end
    end

    // combinatorial logic for extracting correct bytes from read data
    always_comb begin
      if (!data_mem_req_i) begin
        data_mem_rd_data_o = 32'b0;
      end else begin
          case (data_mem_byte_en_i)

              // byte access handling - depends on zero extension input
              BYTE: begin
                  if (data_mem_zero_extnd_i) begin
                      data_mem_rd_data_o = {24'b0, extracted_byte};
                  end else begin
                      data_mem_rd_data_o = {{24{extracted_byte[7]}}, extracted_byte};
                  end
              end

              // half word access handling - depends on zero extension input
              HALF_WORD: begin
                  if (data_mem_zero_extnd_i) begin
                      data_mem_rd_data_o = byte_offset[1] ? {16'b0, read_data[31:16]} : {16'b0, read_data[15:0]};
                  end else begin
                      data_mem_rd_data_o = byte_offset[1] ? {{16{read_data[31]}}, read_data[31:16]} : {{16{read_data[15]}}, read_data[15:0]};
                  end
              end

              // for full word, don't differentiate between zero and sign extended data
              WORD: data_mem_rd_data_o = read_data;

              // default to 0 output assignment
              default: data_mem_rd_data_o = '0;
          endcase
      end
    end

    // single byte selection block
    always_comb begin
        case (byte_offset)
            2'b00: extracted_byte = read_data[7:0];
            2'b01: extracted_byte = read_data[15:8];
            2'b10: extracted_byte = read_data[23:16];
            2'b11: extracted_byte = read_data[31:24];
            default: extracted_byte = '0; 
        endcase
    end
endmodule